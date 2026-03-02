#!/usr/bin/env python3
"""Test the Python wrapper for ClawForge.

This test validates that:
1. The Python package can be imported
2. The wrapper can find the bash script
3. Basic commands execute correctly
4. Arguments are passed through properly
"""

import subprocess
import sys
from pathlib import Path


def run_command(args):
    """Run clawforge via Python module and return result."""
    cmd = [sys.executable, "-m", "clawforge_py"] + args
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
    )
    return result


def test_version():
    """Test that version command works."""
    result = run_command(["version"])
    assert result.returncode == 0, f"version failed: {result.stderr}"
    assert "clawforge v" in result.stdout, f"Unexpected output: {result.stdout}"
    print("✓ Version command works")


def test_help():
    """Test that help command works."""
    result = run_command(["help"])
    assert result.returncode == 0, f"help failed: {result.stderr}"
    assert "Usage: clawforge" in result.stdout, f"Unexpected output: {result.stdout}"
    assert "sprint" in result.stdout, "help should mention sprint"
    assert "swarm" in result.stdout, "help should mention swarm"
    print("✓ Help command works")


def test_help_all():
    """Test that help --all command works."""
    result = run_command(["help", "--all"])
    assert result.returncode == 0, f"help --all failed: {result.stderr}"
    assert "Direct Module Access" in result.stdout, "help --all should show modules"
    print("✓ Help --all command works")


def test_unknown_command():
    """Test that unknown commands fail appropriately."""
    result = run_command(["nonexistent-command"])
    assert result.returncode != 0, "Unknown command should fail"
    assert "Unknown command" in result.stderr, f"Unexpected error: {result.stderr}"
    print("✓ Unknown command handling works")


def test_import():
    """Test that the package can be imported."""
    try:
        import clawforge_py
        assert hasattr(clawforge_py, "__version__")
        assert clawforge_py.__version__ == "0.4.0"
        print("✓ Package import works")
    except ImportError as e:
        raise AssertionError(f"Failed to import clawforge_py: {e}")


def test_script_location():
    """Test that the wrapper can find the bash script."""
    try:
        from clawforge_py.__main__ import find_clawforge_script
        script_path = find_clawforge_script()
        assert script_path.exists(), f"Script not found at {script_path}"
        assert script_path.name == "clawforge", f"Wrong script: {script_path.name}"
        print(f"✓ Bash script found at: {script_path}")
    except Exception as e:
        raise AssertionError(f"Failed to locate script: {e}")


def main():
    """Run all tests."""
    print("Testing ClawForge Python wrapper...\n")

    tests = [
        test_import,
        test_script_location,
        test_version,
        test_help,
        test_help_all,
        test_unknown_command,
    ]

    failed = []
    for test in tests:
        try:
            test()
        except AssertionError as e:
            print(f"✗ {test.__name__} failed: {e}")
            failed.append(test.__name__)
        except Exception as e:
            print(f"✗ {test.__name__} error: {e}")
            failed.append(test.__name__)

    print(f"\n{'='*60}")
    if failed:
        print(f"FAILED: {len(failed)} test(s) failed:")
        for name in failed:
            print(f"  - {name}")
        sys.exit(1)
    else:
        print(f"SUCCESS: All {len(tests)} tests passed!")
        sys.exit(0)


if __name__ == "__main__":
    main()
