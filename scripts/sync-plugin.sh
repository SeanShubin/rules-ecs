#!/bin/bash
# sync-plugin.sh
# Synchronizes rule files to plugin and checks if reinstall is needed

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
INSTALLED="$HOME/.claude/plugins/cache/seanshubin/code-quality-ecs/1.0.0"

cd "$REPO_ROOT"

echo "Syncing rule files to plugin..."
cp coupling-and-cohesion.md \
   system-dependencies.md \
   event-architecture.md \
   architectural-layers.md \
   abstraction-levels.md \
   module-hierarchy.md \
   naming-and-clarity.md \
   system-organization.md \
   component-and-resource-design.md \
   quick-reference.md \
   severity-guidance.md \
   tooling-and-ai.md \
   test-patterns.md \
   README.md \
   code-quality-plugin/rules/

echo "Note: hooks/ and commands/ directories are maintained directly in plugin"
# These directories already exist in code-quality-plugin/, no copy needed

echo "Validating plugin..."
cd code-quality-plugin
claude plugin validate .

echo ""
echo "✅ Plugin synchronized and validated"
echo ""

# Check if plugin is installed and compare
if [ -d "$INSTALLED" ]; then
    echo "Checking installed plugin..."
    cd "$REPO_ROOT"

    # Compare directories, excluding common non-essential files
    if diff -r "$INSTALLED" code-quality-plugin/ \
        --exclude=".git" \
        --exclude=".DS_Store" \
        --exclude="*.swp" \
        > /dev/null 2>&1; then
        echo "✅ Installed plugin matches source - no reinstall needed"
    else
        echo "⚠️  Installed plugin differs from source"
        echo ""
        echo "Differences found. To update installed plugin:"
        echo "  claude plugin install code-quality-ecs@seanshubin"
        echo ""
        echo "Or uninstall and reinstall:"
        echo "  claude plugin uninstall code-quality-ecs@seanshubin"
        echo "  claude plugin marketplace add $REPO_ROOT"
        echo "  claude plugin install code-quality-ecs@seanshubin"
    fi
else
    echo "ℹ️  Plugin not yet installed"
    echo ""
    echo "To install:"
    echo "  claude plugin marketplace add $REPO_ROOT"
    echo "  claude plugin install code-quality-ecs@seanshubin"
fi
