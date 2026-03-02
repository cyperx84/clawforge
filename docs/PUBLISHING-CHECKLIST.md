# Publishing Checklist

Step-by-step checklist for releasing ClawForge across all registries. Complete each section in order.

## Pre-publish

- [ ] All tests pass: `./tests/run-all-tests.sh`
- [ ] Version is bumped in `VERSION`
- [ ] Version is consistent in `registry/npm/package.json`
- [ ] Version is consistent in `registry/uv/pyproject.toml`
- [ ] `clawforge version` outputs the new version
- [ ] Changes are committed and pushed to `main`
- [ ] Git tag created: `git tag v<VERSION> && git push origin v<VERSION>`

## GitHub Release

- [ ] Create release: `gh release create v<VERSION> --title "v<VERSION>" --generate-notes`
- [ ] Release notes reviewed and edited if needed
- [ ] Release tarball URL noted for Homebrew formula

## Homebrew

- [ ] Compute tarball SHA: `shasum -a 256 <tarball>`
- [ ] Update formula in `cyperx84/homebrew-tap` repo (url, sha256, version)
- [ ] Push formula update
- [ ] Validate: `brew update && brew install cyperx84/tap/clawforge`
- [ ] Verify: `clawforge version` outputs correct version
- [ ] Verify: `clawforge help` works

## npm

- [ ] `cd registry/npm`
- [ ] Confirm `npm whoami` shows correct account
- [ ] Dry run: `npm publish --dry-run` — review included files
- [ ] Publish: `npm publish --access public`
- [ ] Validate: `npm info @cyperx84/clawforge` shows new version
- [ ] Test install: `npm install -g @cyperx84/clawforge && clawforge version`

## PyPI (uv)

- [ ] `cd registry/uv`
- [ ] Build: `uv build`
- [ ] Dry run / inspect: verify `dist/` contents look correct
- [ ] Publish: `uv publish`
- [ ] Validate: package appears on PyPI with correct version
- [ ] Test install: `uv tool install clawforge && clawforge version`

## bun

- [ ] bun uses the same npm package — verify: `bun install -g @cyperx84/clawforge`
- [ ] Verify: `clawforge version` outputs correct version

## Post-publish Validation

- [ ] All four install methods tested from a clean environment
- [ ] `clawforge version` returns the correct version for each method
- [ ] `clawforge help` works for each method
- [ ] `clawforge sprint --dry-run "test task"` succeeds for each method
- [ ] No error reports in first 24 hours

## Rollback Procedures

If issues are found after publishing:

### npm rollback

```bash
# Unpublish within 72 hours (npm policy)
npm unpublish @cyperx84/clawforge@<VERSION>

# Or deprecate the version
npm deprecate @cyperx84/clawforge@<VERSION> "Known issue — use <PREV_VERSION>"
```

### PyPI rollback

```bash
# PyPI does not allow re-upload of the same version.
# Yank the release (marks as not recommended):
# Use the PyPI web UI or:
pip install twine
twine upload --skip-existing  # won't help for same version

# Best approach: publish a patch version with the fix
```

### Homebrew rollback

```bash
# Revert the formula in homebrew-tap to the previous version
# Users can also pin: brew pin clawforge
```

### GitHub Release rollback

```bash
# Delete the release and tag
gh release delete v<VERSION> --yes
git push origin --delete v<VERSION>
git tag -d v<VERSION>
```

## Notes

- bun shares the npm registry, so publishing to npm automatically makes the package available via bun
- Always publish to npm before testing with bun
- Keep the `VERSION` file as the single source of truth for the version number
