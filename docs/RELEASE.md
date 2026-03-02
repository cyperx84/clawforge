# Release Workflow

This document describes how to cut a new ClawForge release and publish it to all distribution registries.

## Versioning Strategy

ClawForge follows [Semantic Versioning](https://semver.org/):

- **MAJOR** — breaking changes to CLI interface or config format
- **MINOR** — new commands, flags, or workflow modes
- **PATCH** — bug fixes, documentation, internal improvements

The canonical version lives in `VERSION` at the repository root. All packaging files reference this value.

## Version Bump Workflow

### Files to update

1. **`VERSION`** — the single source of truth (e.g. `0.4.0`)
2. **`registry/npm/package.json`** — `"version"` field must match
3. **`registry/uv/pyproject.toml`** — `version` field must match
4. **`CHANGELOG.md`** — add a section for the new version (if maintained)

### Bump procedure

```bash
# 1. Decide the new version
NEW_VERSION="0.5.0"

# 2. Update VERSION file
echo "$NEW_VERSION" > VERSION

# 3. Update npm package.json
cd registry/npm
# Update "version" field in package.json to match NEW_VERSION
cd ../..

# 4. Update pyproject.toml
cd registry/uv
# Update version field in pyproject.toml to match NEW_VERSION
cd ../..

# 5. Commit the version bump
git add VERSION registry/npm/package.json registry/uv/pyproject.toml
git commit -m "chore: bump version to $NEW_VERSION"
```

## Pre-release Checklist

Before tagging a release, verify:

- [ ] All tests pass: `./tests/run-all-tests.sh`
- [ ] Version is consistent across `VERSION`, `package.json`, and `pyproject.toml`
- [ ] `clawforge version` outputs the correct version
- [ ] README install instructions are current
- [ ] Any new commands or flags are documented

## Publishing to Each Registry

### 1. Homebrew Tap

The Homebrew formula lives in the [cyperx84/homebrew-tap](https://github.com/cyperx84/homebrew-tap) repository.

```bash
# 1. Create a GitHub release with the new tag
git tag "v$NEW_VERSION"
git push origin "v$NEW_VERSION"

# 2. Create GitHub release (triggers tap update if automated, or update manually)
gh release create "v$NEW_VERSION" --title "v$NEW_VERSION" --generate-notes

# 3. Update the formula in homebrew-tap repo
#    - Update `url` to point to the new release tarball
#    - Update `sha256` with: shasum -a 256 <tarball>
#    - Update `version` if not derived from URL

# 4. Test the tap
brew update
brew install cyperx84/tap/clawforge
clawforge version
```

### 2. npm Registry

Publishing the npm package from `registry/npm/`:

```bash
cd registry/npm

# 1. Verify package.json version matches VERSION
# 2. Ensure you are logged in
npm whoami

# 3. Do a dry run first
npm publish --dry-run

# 4. Publish
npm publish --access public

# 5. Verify
npm info @cyperx84/clawforge
```

### 3. PyPI (via uv)

Publishing the Python wrapper from `registry/uv/`:

```bash
cd registry/uv

# 1. Verify pyproject.toml version matches VERSION
# 2. Build the distribution
uv build

# 3. Publish to PyPI (requires PYPI_TOKEN or ~/.pypirc)
uv publish

# 4. Verify
uv pip install clawforge --dry-run
```

## Post-release Tasks

After publishing to all registries:

1. **GitHub Release** — ensure the release is created with auto-generated notes:
   ```bash
   gh release create "v$NEW_VERSION" --title "v$NEW_VERSION" --generate-notes
   ```

2. **Verify each install method** — test from a clean environment:
   ```bash
   brew install cyperx84/tap/clawforge && clawforge version
   npm install -g @cyperx84/clawforge && clawforge version
   uv tool install clawforge && clawforge version
   ```

3. **Announce** — post to relevant channels (Discord, GitHub Discussions, etc.)

4. **Monitor** — watch for installation issues reported in the first 24 hours

## Hotfix Process

For urgent patches after a release:

1. Branch from the release tag: `git checkout -b hotfix/description v$CURRENT_VERSION`
2. Apply the fix, bump PATCH version
3. Follow the full release process above
4. Cherry-pick back to `main` if needed
