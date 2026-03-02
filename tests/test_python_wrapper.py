"""Tests for the ClawForge Python wrapper."""

import subprocess
import sys
from pathlib import Path


def test_package_imports():
    """The clawforge package should import without error."""
    import clawforge

    assert clawforge.__version__
    assert isinstance(clawforge.__version__, str)


def test_version_matches():
    """__version__ should match the VERSION file."""
    import clawforge

    version_file = Path(__file__).resolve().parent.parent / "VERSION"
    if version_file.exists():
        file_version = version_file.read_text().strip()
        assert clawforge.__version__ == file_version


def test_cli_module_has_main():
    """cli.py should expose a main() callable."""
    from clawforge.cli import main

    assert callable(main)


def test_find_bash_script():
    """The wrapper should locate the bash CLI script."""
    from clawforge.cli import _find_bash_script

    script = _find_bash_script()
    assert script.exists()
    assert script.name == "clawforge"


def test_clawforge_help():
    """Running 'clawforge --help' via the wrapper should succeed."""
    result = subprocess.run(
        [sys.executable, "-c", "from clawforge.cli import main; main()", "--help"],
        capture_output=True,
        text=True,
        timeout=10,
    )
    assert result.returncode == 0
    assert "clawforge" in result.stdout.lower()
