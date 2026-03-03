"""ClawForge CLI entry point for pip/uv installation."""
import os
import sys
import subprocess

def main():
    """Delegate to the real shell-based clawforge CLI."""
    clawforge_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    clawforge_bin = os.path.join(clawforge_dir, "bin", "clawforge")

    if not os.path.exists(clawforge_bin):
        # Fallback: try PATH
        clawforge_bin = "clawforge"

    try:
        result = subprocess.run([clawforge_bin] + sys.argv[1:])
        sys.exit(result.returncode)
    except FileNotFoundError:
        print("Error: clawforge binary not found. Install from source:")
        print("  git clone https://github.com/cyperx84/clawforge.git && cd clawforge && ./install.sh")
        sys.exit(1)

if __name__ == "__main__":
    main()
