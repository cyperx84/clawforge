# npm Publishing Guide

How to publish and install ClawForge via npm.

## Prerequisites

- Node.js >= 18
- npm account with access to the `@cyperx84` scope
- `npm login` completed

## Install (for users)

```bash
# npm (global)
npm install -g @cyperx84/clawforge

# pnpm
pnpm add -g @cyperx84/clawforge

# bun
bun add -g @cyperx84/clawforge
```

After install, `clawforge` is available globally:

```bash
clawforge --help
clawforge sprint
clawforge swarm plan.md
```

## Pre-Publish Checklist

1. **Ensure tests pass**
   ```bash
   bash tests/run-tests.sh
   ```

2. **Verify VERSION file matches package.json**
   ```bash
   cat VERSION
   node -p "require('./package.json').version"
   ```

3. **Inspect the tarball contents**
   ```bash
   npm pack --dry-run
   ```
   Confirm only intended files are included (bin/, lib/, config/, LICENSE, README.md, VERSION, SKILL.md, install.sh). Confirm tests/, docs/IMPLEMENTATION*, registry/, and *.pid are excluded.

4. **Test locally with npm link**
   ```bash
   npm link
   clawforge --help
   # verify everything works
   npm unlink -g @cyperx84/clawforge
   ```

5. **Test the tarball in isolation**
   ```bash
   npm pack
   # Install tarball in a temp location
   mkdir /tmp/cf-test && cd /tmp/cf-test
   npm install ~/path/to/cyperx84-clawforge-0.4.0.tgz
   npx clawforge --help
   ```

## Version Bump Workflow

Use npm version to bump, which also updates the VERSION file (via the `version` script in package.json):

```bash
# Patch release (0.4.0 -> 0.4.1)
npm version patch

# Minor release (0.4.0 -> 0.5.0)
npm version minor

# Major release (0.4.0 -> 1.0.0)
npm version major
```

This will:
- Update `version` in package.json
- Update the `VERSION` file
- Create a git commit and tag

## Publishing

```bash
# Dry run first (always!)
npm publish --dry-run

# Publish to npm (scoped packages are private by default)
npm publish --access public
```

## Post-Publish Verification

```bash
# Check the package on npm
npm info @cyperx84/clawforge

# Install from registry to verify
npm install -g @cyperx84/clawforge
clawforge --help
```

## Unpublish / Deprecate

```bash
# Deprecate a version (preferred over unpublish)
npm deprecate @cyperx84/clawforge@"0.3.0" "Use >= 0.4.0"

# Unpublish a specific version (within 72 hours)
npm unpublish @cyperx84/clawforge@0.3.0
```
