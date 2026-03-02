# ClawForge Tests

This directory contains tests for the ClawForge project, including validation for the Python wrapper.

## Running Tests

### Python Wrapper Tests

**Before installation (development):**

```bash
# Set PYTHONPATH to include the project root
PYTHONPATH=. python3 tests/test_python_wrapper.py

# Or run individual component tests
python3 -m clawforge_py version
python3 -m clawforge_py help
```

**After installation:**

```bash
# All tests should pass
python3 tests/test_python_wrapper.py

# Or use pytest if installed
pytest tests/test_python_wrapper.py
```

### Bash Validation Script

```bash
# Quick validation (doesn't require installation)
./tests/validate-wrapper.sh
```

## Test Coverage

- `test_python_wrapper.py`: Python unit tests for the wrapper
  - Package import
  - Script location discovery
  - Version command
  - Help command
  - Error handling

- `validate-wrapper.sh`: Bash validation script
  - Basic command execution
  - Output verification
  - Error cases

## Development Workflow

1. Make changes to `clawforge_py/`
2. Run quick validation: `python3 -m clawforge_py version`
3. Run full tests: `PYTHONPATH=. python3 tests/test_python_wrapper.py`
4. For integration testing, install locally: `uv pip install -e .`
