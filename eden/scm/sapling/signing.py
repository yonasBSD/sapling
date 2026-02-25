# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

"""
Commit signing support (GPG and SSH).

Provides a unified signing abstraction with two backends:
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

import dataclasses
import os
import subprocess
import tempfile
import textwrap
from typing import List, Optional, Tuple

from . import error
from .i18n import _


@dataclasses.dataclass
class SigningConfig:
    backend: str  # "gpg" or "ssh"
    key: str  # key id / path / literal
    program: str  # path to gpg or ssh-keygen


def get_signing_config(ui) -> Optional[SigningConfig]:
    """Read signing config, returning None if signing is not configured.

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
        elif backend == "gpg":
            program = ui.config("signing", "gpg.program") or "gpg"
        else:
            raise error.Abort(
                _("unsupported signing backend: %s (expected 'gpg' or 'ssh')") % backend
            )

        return SigningConfig(backend=backend, key=key, program=program)

    # Fall back to legacy [gpg] config.
    if ui.configbool("gpg", "enabled"):
        key = ui.config("gpg", "key")
        if key:
            return SigningConfig(backend="gpg", key=key, program="gpg")

    return None


def sign(commit_text: bytes, config: SigningConfig) -> str:
    """Sign commit_text using the configured backend. Returns the armored signature."""
    if config.backend == "gpg":
        return _sign_gpg(commit_text, config.key, config.program)
    elif config.backend == "ssh":
        return _sign_ssh(commit_text, config.key, config.program)
    else:
        raise error.Abort(_("unsupported signing backend: %s") % config.backend)


def git_signing_args(
    config: Optional[SigningConfig],
) -> Tuple[List[str], List[str]]:
    """Return (config_flags, sign_args) for git CLI commands like commit-tree."""
    if not config:
        return [], []
    sign_args = [f"-S{config.key}"]
    config_flags = []
    if config.backend == "ssh":
        config_flags += ["-c", "gpg.format=ssh"]
        if config.program != "ssh-keygen":
            config_flags += ["-c", f"gpg.ssh.program={config.program}"]
    else:
        config_flags += ["-c", "gpg.format=openpgp"]
        if config.program != "gpg":
            config_flags += ["-c", f"gpg.program={config.program}"]
    return config_flags, sign_args


def _sign_gpg(commit_text: bytes, key: str, program: str) -> str:
    try:
        # This should match how Git signs commits:
        # https://github.com/git/git/blob/2e71cbbddd64695d43383c25c7a054ac4ff86882/gpg-interface.c#L956-L960
        # Long-form arguments for `gpg` are used for clarity.
        sig_bytes = subprocess.check_output(
            [
                program,
                "--status-fd=2",
                "--detach-sign",
                "--sign",
                "--armor",
                "--always-trust",
                "--yes",
                "--local-user",
                key,
            ],
            stderr=subprocess.PIPE,
            input=commit_text,
        )
    except subprocess.CalledProcessError as ex:
        indented_stderr = textwrap.indent(ex.stderr.decode(errors="ignore"), "  ")
        raise error.Abort(
            _("error when running gpg with gpgkeyid %s:\n%s") % (key, indented_stderr)
        )

    return sig_bytes.replace(b"\r", b"").decode()


def _sign_ssh(commit_text: bytes, key: str, program: str) -> str:
    with tempfile.NamedTemporaryFile(
        delete=False, prefix=".sl_signing_buffer_"
    ) as buf_f:
        buf_f.write(commit_text)
        buf_path = buf_f.name

    key_tmpfile = None
    try:
        cmd = [program, "-Y", "sign", "-n", "git"]

        if key.startswith("key::"):
            literal_key = key[5:]
            key_tmpfile = _write_key_tmpfile(literal_key)
            cmd += ["-f", key_tmpfile, "-U"]
        elif key.startswith("ssh-"):
            # Legacy literal key format (deprecated in git, but supported).
            key_tmpfile = _write_key_tmpfile(key)
            cmd += ["-f", key_tmpfile, "-U"]
        else:
            expanded = os.path.expanduser(key)
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
