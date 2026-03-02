# Publishing ClawForge via uv (PyPI)

ClawForge is distributed as a thin Python wrapper that delegates to the
bundled bash CLI. This document covers local testing, publishing to PyPI,
and end-user installation with `uv`.

## Prerequisites

| Tool | Minimum version |
|------|----------------|
| uv   | 0.4+           |
| bash | 4.0+           |
| jq   | 1.6+           |
| tmux | 3.0+           |
| git  | 2.30+          |

> Python dependencies are **not** required at runtime. The Python package
> is a thin wrapper; all real work is done by the bash scripts and the
> shell tools listed above.

## Local development & testing

### Editable install (recommended during development)

```bash
uv tool install --editable .
```

Verify it works:

```bash
clawforge version          # should print "clawforge v0.4.0"
clawforge --help           # full help text
```

To uninstall the dev version:

```bash
uv tool uninstall clawforge
```

### Run tests

```bash
uv run pytest tests/test_python_wrapper.py -v
```

## Building the package

```bash
uv build
```

This produces `dist/clawforge-0.4.0.tar.gz` and
`dist/clawforge-0.4.0-py3-none-any.whl`.

## Publishing to PyPI

### First-time setup

1. Create an account at <https://pypi.org/account/register/>
2. Create an API token at <https://pypi.org/manage/account/token/>

### Test publish (TestPyPI)

```bash
uv publish --index-url https://test.pypi.org/legacy/ --token "$TEST_PYPI_TOKEN"
```

Verify with:

```bash
uv tool install --index-url https://test.pypi.org/simple/ clawforge
clawforge version
```

### Production publish

```bash
uv publish --token "$PYPI_TOKEN"
```

## End-user installation

```bash
# Install from PyPI
uv tool install clawforge

# Verify
clawforge version
```

## How the wrapper works

The Python package (`src/clawforge/`) contains only two files:

- `__init__.py` — exposes `__version__`
- `cli.py` — `main()` locates the bundled bash script and `exec`s it

The bash scripts, library files, config, and VERSION file are bundled
into the wheel via hatch shared-data and installed alongside the
virtualenv that `uv tool install` creates.

Resolution order for the bash script:

1. **Shared-data install** — `$PREFIX/clawforge/bin/clawforge`
   (standard `uv tool install` path)
2. **Development layout** — `../../bin/clawforge` relative to `cli.py`
   (editable install)
3. **PATH lookup** — falls back to `which clawforge`
   (installed via `install.sh` or Homebrew)

## Version bump checklist

When releasing a new version:

1. Update `VERSION` file
2. Update `version` in `pyproject.toml`
3. Update `__version__` in `src/clawforge/__init__.py`
4. Commit, tag, and push: `git tag v0.X.0 && git push --tags`
5. Build and publish: `uv build && uv publish --token "$PYPI_TOKEN"`
