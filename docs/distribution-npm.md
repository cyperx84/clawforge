# npm/bun Distribution

ClawForge is published to npm for easy installation via npm or bun.

## Installation

### npm

```bash
npm install -g clawforge
```

### bun

```bash
bun install -g clawforge
```

### Verify

```bash
clawforge version
clawforge help
```

## Package Structure

The npm package includes:

- `bin/` — All CLI executables and workflow scripts
- `lib/` — Shared shell libraries
- `config/` — Default configuration files
- `VERSION` — Current version string
- `LICENSE` — MIT license
- `README.md` — Main documentation
- `SKILL.md` — OpenClaw integration skill definition

## Publishing (Maintainers)

### Prerequisites

1. Ensure you're logged in to npm:
   ```bash
   npm login
   ```

2. Validate package structure:
   ```bash
   npm run validate
   npm pack --dry-run
   ```

### Release Process

1. Update version in `VERSION` file
2. Update version in `package.json`
3. Commit version bump:
   ```bash
   git commit -am "chore: bump version to X.Y.Z"
   git tag vX.Y.Z
   ```

4. Publish to npm:
   ```bash
   npm publish
   ```

5. Push tags:
   ```bash
   git push --tags
   ```

### Version Strategy

- **Patch** (0.4.x): Bug fixes, minor tweaks
- **Minor** (0.x.0): New features, backward-compatible changes
- **Major** (x.0.0): Breaking changes

## bun Compatibility

ClawForge is fully compatible with bun. The package uses standard Node.js semantics and can be installed/run with either package manager.

## Validation Scripts

- `npm run validate` — Syntax check all shell scripts
- `npm run test` — Run full test suite (requires tmux, git, gh, claude/codex)
- `npm run prepack` — Auto-runs before `npm pack` or `npm publish`

## Troubleshooting

### Permission issues after install

If `clawforge` isn't executable after install:

```bash
chmod +x $(npm root -g)/clawforge/bin/clawforge
```

### Command not found

Ensure npm global bin directory is in your PATH:

```bash
echo $PATH | grep -q "$(npm bin -g)" || echo 'export PATH="$(npm bin -g):$PATH"' >> ~/.bashrc
```

For bun:

```bash
echo $PATH | grep -q "$HOME/.bun/bin" || echo 'export PATH="$HOME/.bun/bin:$PATH"' >> ~/.bashrc
```

## Alternative Distributions

- **Homebrew**: `brew install cyperx84/tap/clawforge` (recommended for macOS)
- **Source**: Clone repo and run `./install.sh --standalone`
