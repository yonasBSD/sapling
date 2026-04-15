# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

"""
Commit signing support (GPG and SSH).

Provides a pluggable signing abstraction with two backends:
- GPG (OpenPGP): uses gpg to create detached armored signatures
- SSH: uses ssh-keygen -Y sign to create SSH signatures

Configuration:

New-style [signing] config (preferred for new users)::

    [signing]
    backend = ssh          # "gpg" or "ssh"
    key = ~/.ssh/id_ed25519
    # ssh.program = ssh-keygen   (default)
    # gpg.program = gpg          (default)
    # enabled = true             (default)

Legacy [gpg] config (still works, no migration needed)::

    [gpg]
    enabled = true
    key = ABCDEF1234567890
"""

import abc
import os
import subprocess
import tempfile
import textwrap
from typing import List, Optional, Tuple

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


class GpgBackend(SigningBackend):
    """GPG (OpenPGP) signing backend — uses gpg to create detached armored signatures."""

    def __init__(self, key: str, program: str = "gpg") -> None:
        self.key = key
        self.program = program

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


def get_signing_backend(ui) -> Optional[SigningBackend]:
    """Read signing config and return the appropriate backend, or None if disabled.

    Resolution logic:
    1. If signing.backend is set -> use [signing] config entirely.
    2. Else if gpg.enabled is true and gpg.key is set -> GPG via legacy config.
    3. Otherwise -> None (no signing).
    """
    backend = ui.config("signing", "backend")

    if backend:
        enabled = ui.configbool("signing", "enabled", default=True)
        if not enabled:
            return None

        key = ui.config("signing", "key")
        if not key:
            raise error.Abort(_("signing.backend is set but signing.key is not"))

        if backend == "ssh":
            program = ui.config("signing", "ssh.program") or "ssh-keygen"
            return SshBackend(key=key, program=program)
        elif backend == "gpg":
            program = ui.config("signing", "gpg.program") or "gpg"
            return GpgBackend(key=key, program=program)
        else:
            raise error.Abort(
                _("unsupported signing backend: %s (expected 'gpg' or 'ssh')") % backend
            )

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
