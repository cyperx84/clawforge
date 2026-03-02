"""Thin Python wrapper that delegates to the ClawForge bash CLI."""

import os
import subprocess
import sys
from pathlib import Path


def _find_bash_script() -> Path:
    """Locate the clawforge bash entry point.

    Resolution order:
      1. Bundled alongside this package (installed via wheel shared-data)
      2. Sibling to the package source tree (development / editable install)
      3. Fall back to PATH lookup
    """
    # 1. Shared-data install: the wheel places bin/ into the tool's data dir.
    #    With uv tool install the data dir is the tool's virtualenv prefix.
    data_dir = Path(sys.prefix) / "clawforge" / "bin" / "clawforge"
    if data_dir.is_file():
        return data_dir

    # 2. Development layout: src/clawforge/cli.py -> ../../bin/clawforge
    dev_dir = Path(__file__).resolve().parent.parent.parent / "bin" / "clawforge"
    if dev_dir.is_file():
        return dev_dir

    # 3. Already on PATH (e.g. installed via install.sh or Homebrew)
    from shutil import which

    on_path = which("clawforge")
    if on_path:
        return Path(on_path)

    print(
        "error: could not locate the clawforge bash script.\n"
        "Install it with: curl -fsSL https://raw.githubusercontent.com/"
        "cyperx84/clawforge/main/install.sh | bash",
        file=sys.stderr,
    )
    sys.exit(1)


def main() -> None:
    """Entry point — exec the bash CLI with all arguments forwarded."""
    script = _find_bash_script()
    os.execvp(str(script), [str(script)] + sys.argv[1:])
