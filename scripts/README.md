# Plugin Management Scripts

This directory contains scripts for managing the code-quality-ecs plugin.

## Plugin Structure

The `code-quality-plugin/` contains:
- **`rules/`** - Rule markdown files (synced from repo root via sync-plugin.sh)
- **`skills/ecs/`** - The main skill that loads the rules into context
- **`commands/`** - Manual validation commands:
  - `validate-changes.md` - Evaluate git diffs on demand
  - `validate-project.md` - Comprehensive codebase assessment
- **`hooks/`** - Automatic validation hooks:
  - `validate-changes.md` - PostToolUse hook that runs after Write/Edit operations
- **`.claude-plugin/`** - Plugin metadata (plugin.json)

**Note**: Skills, commands, and hooks are all installed together when users run `claude plugin install code-quality-ecs@seanshubin`. No separate installation or activation is needed for individual components.

## How They Work Together

- **Command** (`commands/validate-changes.md`): Contains validation logic - evaluates git diffs against rules
- **Hook** (`hooks/validate-changes.md`): Automatically invokes `/validate-changes` after Write/Edit operations
- **Command** (`commands/validate-project.md`): Different scope - comprehensive codebase assessment
- **Skill** (`skills/ecs/`): Provides the rules that all validation uses; auto-triggers during code work

**Architecture**: The hook delegates to the command. This means:
- Single source of truth for validation logic (the command)
- Consistent behavior between automatic (hook) and manual (user-invoked) validation
- Update validation logic in one place

## Scripts

### sync-plugin.sh
Synchronizes rule files from the repository root to `code-quality-plugin/rules/` and validates the plugin structure.

**Usage:**
```bash
./scripts/sync-plugin.sh
```

**What it does:**
- Copies all rule markdown files to the plugin directory
- Validates the plugin with `claude plugin validate`
- Compares installed plugin with source to check if reinstall is needed

### update-plugin.sh
Checks if the installed plugin is out of date and automatically installs/updates it.

**Usage:**
```bash
./scripts/update-plugin.sh
```

**What it does:**
- Checks if plugin is installed and up to date
- If not, installs or updates the plugin automatically
- Verifies the installation matches the source

### verify-plugin.sh
Compares the installed plugin to the source to verify they match.

**Usage:**
```bash
./scripts/verify-plugin.sh
```

**What it does:**
- Checks if plugin is installed
- Compares installed version to source
- Reports any differences found

### test-github-distribution.sh
Tests what users will receive when installing the plugin from GitHub.

**Usage:**
```bash
./scripts/test-github-distribution.sh
```

**What it does:**
- Warns if there are uncommitted or unpushed changes
- Installs the plugin from GitHub (not local)
- Compares the GitHub version to local source
- Restores local marketplace for continued development

**Note:** This simulates the end-user experience and helps ensure your GitHub repository contains the correct plugin distribution.

## Typical Workflow

### Local Development
1. **After modifying rules:** `./scripts/sync-plugin.sh`
2. **To install/update locally:** `./scripts/update-plugin.sh`
3. **To verify installation:** `./scripts/verify-plugin.sh`

### Releasing to Users

1. **Test the GitHub distribution:**
   ```bash
   ./scripts/test-github-distribution.sh
   ```

2. **Update version (if needed):**
   - Edit `code-quality-plugin/.claude-plugin/plugin.json`
   - Bump the `version` field (e.g., `1.0.0` → `1.0.1`)

3. **Commit and push changes:**
   ```bash
   git add .
   git commit -m "Release version X.Y.Z"
   git push origin master
   ```

4. **Users install with:**
   ```bash
   claude plugin marketplace add SeanShubin/rules-ecs
   claude plugin install code-quality-ecs@seanshubin
   ```

That's it! The plugin is distributed directly from your GitHub repository. When you push changes, users can update by running `claude plugin install code-quality-ecs@seanshubin` again.
