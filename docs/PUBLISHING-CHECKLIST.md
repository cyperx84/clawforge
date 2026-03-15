# Publishing Checklist

Step-by-step checklist for releasing ClawForge.

## Pre-publish

- [ ] All fleet tests pass: `./tests/run-all-tests.sh`
- [ ] Version bumped in `VERSION`
- [ ] Version consistent in `package.json` and `pyproject.toml`
- [ ] `clawforge version` outputs the new version
- [ ] `CHANGELOG.md` updated with release notes
- [ ] Changes committed and pushed to `main`
- [ ] Git tag created: `git tag v<VERSION> && git push origin v<VERSION>`

## GitHub Release

- [ ] Create release: `gh release create v<VERSION> --title "v<VERSION>" --generate-notes`
- [ ] Review and edit release notes
- [ ] Note tarball URL for Homebrew formula

## Homebrew

- [ ] Compute SHA: `curl -sL <tarball_url> | shasum -a 256`
- [ ] Update `Formula/clawforge.rb` — url, sha256
- [ ] Push formula update
- [ ] Validate: `brew update && brew install cyperx84/tap/clawforge`
- [ ] Verify: `clawforge version` and `clawforge help`

## npm

- [ ] `cd registry/npm`
- [ ] `npm whoami` — confirm account
- [ ] `npm publish --dry-run` — review included files
- [ ] `npm publish --access public`
- [ ] Validate: `npm info @cyperx84/clawforge`

## PyPI (uv)

- [ ] `cd registry/uv`
- [ ] `uv build`
- [ ] `uv publish`
- [ ] Validate on PyPI

## Post-publish

- [ ] Homebrew install tested from clean environment
- [ ] npm install tested
- [ ] `clawforge doctor` passes
- [ ] `clawforge list` works

## Rollback

### npm
```bash
npm deprecate @cyperx84/clawforge@<VERSION> "Known issue — use <PREV>"
```

### Homebrew
```bash
# Revert Formula/clawforge.rb to previous version
```

### GitHub
```bash
gh release delete v<VERSION> --yes
git push origin --delete v<VERSION>
```
