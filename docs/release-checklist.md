# ClawForge Release Checklist

This checklist covers the complete release and publish process for ClawForge across all supported package registries.

## Pre-Release

### Version & Testing

- [ ] Update `VERSION` file with new version number (e.g., `0.4.0`)
- [ ] Update version references in:
  - [ ] `README.md` (if version is mentioned)
  - [ ] `SKILL.md` (if version is mentioned)
  - [ ] `bin/clawforge` (version command output)
- [ ] Run full test suite: `./tests/run-all-tests.sh`
- [ ] Verify all tests pass (118+ tests expected)
- [ ] Manual smoke test of core workflows:
  - [ ] `clawforge sprint` (basic flow)
  - [ ] `clawforge status`
  - [ ] `clawforge --help`

### Documentation

- [ ] Update `CHANGELOG.md` with release notes
  - [ ] New features
  - [ ] Bug fixes
  - [ ] Breaking changes (if any)
  - [ ] Migration guide (if needed)
- [ ] Review `README.md` for accuracy
- [ ] Update install instructions if needed
- [ ] Verify all command examples in README still work

### Code Quality

- [ ] Run linting/formatting (if applicable)
- [ ] Check for TODOs or FIXMEs that should be resolved
- [ ] Review recent commits for quality
- [ ] Ensure no debug code or console logs left in

## Git Release

### Branch & Tag

- [ ] Merge all feature branches to `main`
- [ ] Ensure `main` branch is clean and up to date
- [ ] Create git tag: `git tag -a v0.x.x -m "Release v0.x.x"`
- [ ] Push tag: `git push origin v0.x.x`
- [ ] Push main: `git push origin main`

### GitHub Release

- [ ] Create GitHub release from tag
- [ ] Copy changelog to release notes
- [ ] Attach release artifacts (if any)
- [ ] Mark as pre-release if beta/RC
- [ ] Publish GitHub release

## Package Registry Publishing

### Homebrew (cyperx84/tap)

- [ ] Update formula in `homebrew-tap` repo
  - [ ] Update version number
  - [ ] Update SHA256 checksum of source tarball
  - [ ] Update dependencies if changed
- [ ] Test formula locally: `brew install --build-from-source ./clawforge.rb`
- [ ] Commit and push to `cyperx84/homebrew-tap`
- [ ] Verify install: `brew install cyperx84/tap/clawforge`

**Formula template reference:**
```ruby
class Clawforge < Formula
  desc "Multi-mode coding workflow CLI for agent orchestration"
  homepage "https://github.com/cyperx84/clawforge"
  url "https://github.com/cyperx84/clawforge/archive/v0.x.x.tar.gz"
  sha256 "..."
  license "MIT"

  depends_on "bash"
  depends_on "jq"
  depends_on "git"
  depends_on "tmux"
  depends_on "gh"
end
```

### npm (Node.js)

- [ ] Ensure `package.json` is up to date:
  - [ ] Version matches `VERSION` file
  - [ ] Description, keywords, repository URLs correct
  - [ ] Dependencies are current
  - [ ] `bin` entry points to correct script
- [ ] Test install locally: `npm install -g .`
- [ ] Verify command works: `clawforge --version`
- [ ] Login to npm: `npm login`
- [ ] Publish: `npm publish`
- [ ] Verify on npmjs.com: https://www.npmjs.com/package/clawforge
- [ ] Test install from registry: `npm install -g clawforge`

**Required package.json fields:**
```json
{
  "name": "clawforge",
  "version": "0.x.x",
  "description": "Multi-mode coding workflow CLI",
  "bin": {
    "clawforge": "./bin/clawforge"
  },
  "repository": "github:cyperx84/clawforge",
  "license": "MIT"
}
```

### bun

- [ ] Verify `package.json` compatibility with Bun
- [ ] Test install locally: `bun install -g .`
- [ ] Verify command works: `clawforge --version`
- [ ] Publish via npm (Bun uses npm registry)
- [ ] Test install from Bun: `bun install -g clawforge`

**Note:** Bun uses the npm registry, so publishing to npm automatically makes it available for `bun install`.

### uv / PyPI (Python)

- [ ] Ensure `pyproject.toml` is up to date:
  - [ ] Version matches `VERSION` file
  - [ ] Description, keywords, URLs correct
  - [ ] Dependencies are current
  - [ ] Scripts entry point is correct
- [ ] Build distribution: `uv build` or `python -m build`
- [ ] Test install locally: `uv tool install .`
- [ ] Verify command works: `clawforge --version`
- [ ] Login to PyPI: `uv publish --token $PYPI_TOKEN` or `twine upload`
- [ ] Publish: `uv publish` or `twine upload dist/*`
- [ ] Verify on PyPI: https://pypi.org/project/clawforge/
- [ ] Test install from registry: `uv tool install clawforge`

**Required pyproject.toml fields:**
```toml
[project]
name = "clawforge"
version = "0.x.x"
description = "Multi-mode coding workflow CLI"
license = { text = "MIT" }
readme = "README.md"
requires-python = ">=3.8"

[project.scripts]
clawforge = "clawforge.cli:main"

[project.urls]
Homepage = "https://github.com/cyperx84/clawforge"
Repository = "https://github.com/cyperx84/clawforge"
```

## Post-Release

### Verification

- [ ] Verify install from each registry:
  - [ ] Homebrew: `brew install cyperx84/tap/clawforge`
  - [ ] npm: `npm install -g clawforge`
  - [ ] bun: `bun install -g clawforge`
  - [ ] uv: `uv tool install clawforge`
- [ ] Test basic commands from each install method
- [ ] Check version output matches release

### Documentation & Communication

- [ ] Update main repository README badges (if any)
- [ ] Post release announcement:
  - [ ] GitHub Discussions (if enabled)
  - [ ] Twitter/X
  - [ ] Discord server (if applicable)
  - [ ] HackerNews/Reddit (for major releases)
- [ ] Update any external documentation sites
- [ ] Notify active contributors/users

### Cleanup

- [ ] Delete any temporary release branches
- [ ] Archive old release artifacts (if applicable)
- [ ] Update project board/roadmap for next version
- [ ] Create milestone for next release

## Rollback Procedure

If a critical issue is found after release:

### Quick Hotfix

1. [ ] Create hotfix branch from release tag
2. [ ] Fix the issue
3. [ ] Bump patch version (e.g., 0.4.0 → 0.4.1)
4. [ ] Follow full release checklist for hotfix version
5. [ ] Mark previous version as deprecated (if needed)

### Full Rollback (if unfixable)

1. [ ] Yank/unpublish from package registries:
   - npm: `npm unpublish clawforge@0.x.x`
   - PyPI: Use web interface to yank release
   - Homebrew: Revert formula commit
2. [ ] Delete GitHub release
3. [ ] Delete git tag: `git tag -d v0.x.x && git push --delete origin v0.x.x`
4. [ ] Post communication about rollback
5. [ ] Fix issues and prepare new release

## Registry-Specific Notes

### Homebrew

- Homebrew formula lives in separate repo: `cyperx84/homebrew-tap`
- SHA256 checksum: `shasum -a 256 clawforge-0.x.x.tar.gz`
- Test with: `brew install --build-from-source ./formula.rb`
- Audit with: `brew audit --strict clawforge`

### npm

- Requires `.npmignore` or `files` field in `package.json` to control what's published
- Use `npm pack` to preview what will be published
- Can unpublish within 72 hours (after that, can only deprecate)
- Two-factor auth recommended for publishing

### bun

- Shares npm registry, no separate publish step needed
- Test Bun-specific features/compatibility
- Verify `bun run` commands work if package has scripts

### uv / PyPI

- Requires Python wrapper/entrypoint for shell-based tool
- Consider `[tool.uv.sources]` for development dependencies
- Use `uv build` to create wheel and sdist
- Test with: `uv tool install --preview dist/clawforge-0.x.x-*.whl`

## Environment Variables & Secrets

Ensure these are set for publishing:

- [ ] `HOMEBREW_GITHUB_API_TOKEN` — for Homebrew tap pushes
- [ ] `NPM_TOKEN` — for npm publish
- [ ] `PYPI_TOKEN` — for PyPI/uv publish
- [ ] `GITHUB_TOKEN` — for GitHub releases

## Automation Considerations

Future improvements for CI/CD automation:

- GitHub Actions workflow for release automation
- Automated version bumping from git tags
- Parallel publishing to all registries
- Automated smoke tests post-publish
- Slack/Discord notifications on release

## Support & Troubleshooting

### Common Issues

**Homebrew formula fails to install:**
- Check dependencies are available
- Verify SHA256 checksum matches
- Test formula syntax: `brew audit`

**npm publish fails:**
- Ensure version not already published
- Check npm login status: `npm whoami`
- Verify package.json is valid: `npm pack --dry-run`

**PyPI upload rejected:**
- Ensure version not already used
- Check wheel/sdist build: `uv build --wheel`
- Verify metadata: `twine check dist/*`

**Version mismatch across registries:**
- Always update `VERSION` file first
- Keep package.json and pyproject.toml in sync
- Use automation to prevent drift

## Checklist Version

**Last updated:** 2026-03-02
**For ClawForge version:** 0.4.0+
**Maintained by:** ClawForge maintainers

---

**Note:** This checklist assumes multi-registry support is implemented. For versions prior to full multi-registry support, skip inapplicable sections.
