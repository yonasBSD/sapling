# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

"""
Commit signing support.

Provides a pluggable signing abstraction. Currently supports GPG (OpenPGP),
with the design allowing additional backends (e.g. SSH) to be added.

Configuration:

New-style [signing] config (preferred for new users)::

    [signing]
    backend = gpg
    key = ABCDEF1234567890
    # gpg.program = gpg          (default)
    # enabled = true             (default)

Legacy [gpg] config (still works, no migration needed)::

    [gpg]
    enabled = true
    key = ABCDEF1234567890
"""

import dataclasses
import subprocess
import textwrap
from typing import List, Optional, Tuple

from . import error
from .i18n import _


@dataclasses.dataclass
class SigningConfig:
    backend: str  # "gpg" (more backends planned)
    key: str  # key id / path
    program: str  # path to signing program


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

        if backend == "gpg":
            program = ui.config("signing", "gpg.program") or "gpg"
        else:
            raise error.Abort(
                _("unsupported signing backend: %s (expected 'gpg')") % backend
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
    else:
        raise error.Abort(_("unsupported signing backend: %s") % config.backend)


def git_signing_args(
    config: Optional[SigningConfig],
) -> Tuple[List[str], List[str]]:
    """Return (config_flags, sign_args) for git CLI commands like commit-tree."""
    if not config:
        return [], []
    sign_args = [f"-S{config.key}"]
    config_flags = ["-c", "gpg.format=openpgp"]
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
