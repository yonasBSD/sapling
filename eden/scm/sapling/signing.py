# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

"""
Commit signing support (GPG, SSH, and X.509).

Provides a pluggable signing abstraction with these backends:
- GPG (OpenPGP): uses gpg to create detached armored signatures
- SSH: uses ssh-keygen -Y sign to create SSH signatures
- X.509 (S/MIME): uses openssl or gpgsm to create detached CMS signatures

Configuration:

New-style [signing] config (preferred for new users)::

    [signing]
    backend = ssh          # "gpg", "ssh", or "x509"
    key = ~/.ssh/id_ed25519
    # ssh.program = ssh-keygen   (default)
    # gpg.program = gpg          (default)
    # x509.program = openssl     (auto-detects openssl or gpgsm)
    # x509.format = openssl      (explicit tool format: "openssl" or "gpgsm")
    # x509.certfile = cert.pem   (optional, for openssl with separate cert/key)
    # enabled = true             (default)

Legacy [gpg] config (still works, no migration needed)::

    [gpg]
    enabled = true
    key = ABCDEF1234567890
"""

import abc
import os
import shutil
import subprocess
import tempfile
import textwrap
from typing import Dict, List, Optional, Tuple, Type

from . import error
from .i18n import _


class SigningBackend(abc.ABC):
    """Abstract base class for commit signing backends."""

    @abc.abstractmethod
    def sign(self, commit_text: bytes) -> str:
        """Sign commit_text and return the armored signature string."""

    @abc.abstractmethod
    def git_signing_args(self) -> Tuple[List[str], List[str]]:
        """Return (config_flags, sign_args) for git CLI commands like commit-tree."""

    @classmethod
    @abc.abstractmethod
    def from_config(cls, ui, key: str) -> "SigningBackend":
        """Construct a backend from the [signing] config section."""


class GpgBackend(SigningBackend):
    """GPG (OpenPGP) signing backend — uses gpg to create detached armored signatures."""

    def __init__(self, key: str, program: str = "gpg") -> None:
        self.key = key
        self.program = program

    @classmethod
    def from_config(cls, ui, key: str) -> "GpgBackend":
        program = ui.config("signing", "gpg.program") or "gpg"
        return cls(key=key, program=program)

    def sign(self, commit_text: bytes) -> str:
        try:
            # This should match how Git signs commits:
            # https://github.com/git/git/blob/2e71cbbddd64695d43383c25c7a054ac4ff86882/gpg-interface.c#L956-L960
            # Long-form arguments for `gpg` are used for clarity.
            sig_bytes = subprocess.check_output(
                [
                    self.program,
                    "--status-fd=2",
                    "--detach-sign",
                    "--sign",
                    "--armor",
                    "--always-trust",
                    "--yes",
                    "--local-user",
                    self.key,
                ],
                stderr=subprocess.PIPE,
                input=commit_text,
            )
        except subprocess.CalledProcessError as ex:
            indented_stderr = textwrap.indent(ex.stderr.decode(errors="ignore"), "  ")
            raise error.Abort(
                _("error when running gpg with gpgkeyid %s:\n%s")
                % (self.key, indented_stderr)
            )
        except FileNotFoundError:
            raise error.Abort(
                _("gpg not found — install GnuPG to use GPG commit signing")
            )

        return sig_bytes.replace(b"\r", b"").decode()

    def git_signing_args(self) -> Tuple[List[str], List[str]]:
        config_flags = ["-c", "gpg.format=openpgp"]
        if self.program != "gpg":
            config_flags += ["-c", f"gpg.program={self.program}"]
        return config_flags, [f"-S{self.key}"]


class SshBackend(SigningBackend):
    """SSH signing backend — uses ssh-keygen -Y sign to create SSH signatures."""

    def __init__(self, key: str, program: str = "ssh-keygen") -> None:
        self.key = key
        self.program = program

    @classmethod
    def from_config(cls, ui, key: str) -> "SshBackend":
        program = ui.config("signing", "ssh.program") or "ssh-keygen"
        return cls(key=key, program=program)

    def sign(self, commit_text: bytes) -> str:
        with tempfile.NamedTemporaryFile(
            delete=False, prefix=".sl_signing_buffer_"
        ) as buf_f:
            buf_f.write(commit_text)
            buf_path = buf_f.name

        key_tmpfile = None
        try:
            cmd = [self.program, "-Y", "sign", "-n", "git"]

            if self.key.startswith("key::"):
                literal_key = self.key[5:]
                key_tmpfile = _write_key_tmpfile(literal_key)
                cmd += ["-f", key_tmpfile, "-U"]
            elif self.key.startswith("ssh-"):
                # Legacy literal key format (deprecated in git, but supported).
                key_tmpfile = _write_key_tmpfile(self.key)
                cmd += ["-f", key_tmpfile, "-U"]
            else:
                expanded = os.path.expanduser(self.key)
                if not os.path.isfile(expanded):
                    raise error.Abort(
                        _("signing key file not found: %s") % expanded,
                        hint=_(
                            "ensure signing.key points to a valid SSH private key file"
                        ),
                    )
                cmd += ["-f", expanded]

            cmd.append(buf_path)

            result = subprocess.run(cmd, capture_output=True)
            if result.returncode != 0:
                stderr = result.stderr.decode(errors="ignore")
                if "usage:" in stderr:
                    raise error.Abort(
                        _("ssh-keygen -Y sign requires OpenSSH 8.2p1 or later")
                    )
                raise error.Abort(
                    _("error when running ssh-keygen for signing:\n%s")
                    % textwrap.indent(stderr, "  ")
                )

            sig_path = buf_path + ".sig"
            with open(sig_path, "rb") as f:
                sig = f.read()

            return sig.replace(b"\r", b"").decode()
        finally:
            _try_unlink(buf_path)
            _try_unlink(buf_path + ".sig")
            if key_tmpfile:
                _try_unlink(key_tmpfile)

    def git_signing_args(self) -> Tuple[List[str], List[str]]:
        config_flags = ["-c", "gpg.format=ssh"]
        if self.program != "ssh-keygen":
            config_flags += ["-c", f"gpg.ssh.program={self.program}"]
        return config_flags, [f"-S{self.key}"]


class X509Backend(SigningBackend):
    """X.509 (S/MIME) signing backend — uses openssl or gpgsm to create detached CMS signatures.

    Auto-detects the available tool (openssl preferred, gpgsm fallback) unless
    signing.x509.program is set explicitly.
    """

    def __init__(
        self,
        key: str,
        program: str,
        certfile: Optional[str] = None,
        x509_format: Optional[str] = None,
    ) -> None:
        self.key = key
        self.program = program
        self.certfile = certfile
        self.x509_format = x509_format

    @classmethod
    def from_config(cls, ui, key: str) -> "X509Backend":
        program = ui.config("signing", "x509.program") or cls.find_program()
        certfile = ui.config("signing", "x509.certfile")
        x509_format = ui.config("signing", "x509.format")
        if x509_format and x509_format not in ("openssl", "gpgsm"):
            raise error.Abort(
                _("unsupported signing.x509.format: %s (expected 'openssl' or 'gpgsm')")
                % x509_format
            )
        return cls(key=key, program=program, certfile=certfile, x509_format=x509_format)

    def sign(self, commit_text: bytes) -> str:
        fmt = self.x509_format or self._infer_format(self.program)
        if fmt == "openssl":
            return self._sign_openssl(commit_text)
        return self._sign_gpgsm(commit_text)

    def git_signing_args(self) -> Tuple[List[str], List[str]]:
        fmt = self.x509_format or self._infer_format(self.program)
        if fmt == "openssl":
            # Git's x509 support only understands gpgsm-style key identifiers,
            # not openssl PEM file paths. Raise early rather than passing a PEM
            # path as a gpgsm key ID, which would produce a confusing gpgsm error.
            raise error.Abort(
                _(
                    "X.509 signing with openssl is not supported for git commit-tree operations; "
                    "use signing.x509.program = gpgsm instead"
                )
            )
        config_flags = ["-c", "gpg.format=x509"]
        if self.program != "gpgsm":
            config_flags += ["-c", f"gpg.x509.program={self.program}"]
        return config_flags, [f"-S{self.key}"]

    def _sign_openssl(self, commit_text: bytes) -> str:
        expanded_key = os.path.expanduser(self.key)
        if not os.path.isfile(expanded_key):
            raise error.Abort(
                _("signing key file not found: %s") % expanded_key,
                hint=_(
                    "ensure signing.key points to a valid PEM file containing your certificate and private key"
                ),
            )
        cmd = [self.program, "cms", "-sign", "-binary", "-noattr", "-outform", "pem"]
        expanded_cert = (
            os.path.expanduser(self.certfile) if self.certfile else expanded_key
        )
        if self.certfile and not os.path.isfile(expanded_cert):
            raise error.Abort(
                _("signing certificate file not found: %s") % expanded_cert,
                hint=_(
                    "ensure signing.x509.certfile points to a valid PEM certificate file"
                ),
            )
        cmd += ["-signer", expanded_cert, "-inkey", expanded_key]
        try:
            sig_bytes = subprocess.check_output(
                cmd, stderr=subprocess.PIPE, input=commit_text
            )
        except subprocess.CalledProcessError as ex:
            indented_stderr = textwrap.indent(
                ex.stderr.decode(errors="ignore").rstrip(), "  "
            )
            raise error.Abort(
                _("error when running openssl cms signing with key %s:\n%s")
                % (expanded_key, indented_stderr)
            )
        except FileNotFoundError:
            raise error.Abort(
                _("openssl not found — install OpenSSL to use X.509 commit signing")
            )
        return sig_bytes.replace(b"\r", b"").decode()

    def _sign_gpgsm(self, commit_text: bytes) -> str:
        try:
            sig_bytes = subprocess.check_output(
                [self.program, "--detach-sign", "--armor", "--local-user", self.key],
                stderr=subprocess.PIPE,
                input=commit_text,
            )
        except subprocess.CalledProcessError as ex:
            indented_stderr = textwrap.indent(
                ex.stderr.decode(errors="ignore").rstrip(), "  "
            )
            raise error.Abort(
                _("error when running gpgsm with key %s:\n%s")
                % (self.key, indented_stderr)
            )
        except FileNotFoundError:
            raise error.Abort(
                _(
                    "gpgsm not found — install GnuPG (which includes gpgsm) "
                    "to use X.509 commit signing"
                )
            )
        return sig_bytes.replace(b"\r", b"").decode()

    @staticmethod
    def find_program() -> str:
        """Auto-detect the best available X.509 signing tool."""
        if shutil.which("openssl"):
            return "openssl"
        if shutil.which("gpgsm"):
            return "gpgsm"
        return "openssl"  # default; will produce a clear error at signing time

    @staticmethod
    def _infer_format(program: str) -> str:
        """Infer the x509 tool format from the program name."""
        basename = os.path.basename(program)
        if basename in ("openssl", "libressl"):
            return "openssl"
        return "gpgsm"


# Registry mapping backend names to their classes. To add a new backend:
# 1. Implement a SigningBackend subclass with a from_config() classmethod.
# 2. Add one entry here.
# 3. Update the expected-backends list in the error.Abort below.
_BACKENDS: Dict[str, Type[SigningBackend]] = {
    "gpg": GpgBackend,
    "ssh": SshBackend,
    "x509": X509Backend,
}


def get_signing_backend(ui) -> Optional[SigningBackend]:
    """Read signing config and return the appropriate backend, or None if disabled.

    Resolution logic:
    1. If signing.backend is set -> use [signing] config entirely.
    2. Else if gpg.enabled is true and gpg.key is set -> GPG via legacy config.
    3. Otherwise -> None (no signing).
    """
    backend_name = ui.config("signing", "backend")

    if backend_name:
        enabled = ui.configbool("signing", "enabled", default=True)
        if not enabled:
            return None

        key = ui.config("signing", "key")
        if not key:
            raise error.Abort(_("signing.backend is set but signing.key is not"))

        backend_cls = _BACKENDS.get(backend_name)
        if backend_cls is None:
            raise error.Abort(
                _("unsupported signing backend: %s (expected 'gpg', 'ssh', or 'x509')")
                % backend_name
            )
        return backend_cls.from_config(ui, key)

    # Fall back to legacy [gpg] config.
    if ui.configbool("gpg", "enabled"):
        key = ui.config("gpg", "key")
        if key:
            return GpgBackend(key=key)

    return None


def _try_unlink(path: str) -> None:
    """Try to remove a file, ignoring errors."""
    try:
        os.unlink(path)
    except OSError:
        pass


def _write_key_tmpfile(key_content: str) -> str:
    """Write a literal SSH key to a temp file. Returns the path."""
    with tempfile.NamedTemporaryFile(
        delete=False, prefix=".sl_signing_key_", mode="w"
    ) as f:
        f.write(key_content)
        f.write("\n")
        return f.name
