#!/usr/bin/env python3
"""ClawForge entrypoint - executes the bash CLI.

This module finds and executes the bin/clawforge bash script,
passing through all arguments and preserving exit codes.
"""

import sys
import subprocess
from pathlib import Path


def find_clawforge_script():
    """Locate the clawforge bash script relative to this package."""
    # When installed via uv/pip, bin/ is bundled inside the package
    # This file is in clawforge_py/__main__.py
    package_dir = Path(__file__).parent

    # First try: installed location (bin/ inside package)
    clawforge_script = package_dir / "bin" / "clawforge"

    # Fallback: development/local installation (bin/ at project root)
    if not clawforge_script.exists():
        project_root = package_dir.parent
        clawforge_script = project_root / "bin" / "clawforge"

    if not clawforge_script.exists():
        raise FileNotFoundError(
            f"ClawForge bash script not found.\n"
            "Expected locations:\n"
            f"  - {package_dir / 'bin' / 'clawforge'} (installed)\n"
            f"  - {package_dir.parent / 'bin' / 'clawforge'} (local)"
        )

    return clawforge_script


def main():
    """Execute the clawforge bash script with all arguments."""
    try:
        script_path = find_clawforge_script()

        # Execute the bash script with all arguments
        # Use execvp to replace this process with the bash script
        # This preserves signals, exit codes, and stdio properly
        import os
        os.execv(str(script_path), [str(script_path)] + sys.argv[1:])

    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
