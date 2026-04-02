#!/bin/bash
# verify-plugin.sh
# Compare installed plugin to source

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
INSTALLED="$HOME/.claude/plugins/cache/seanshubin/code-quality-ecs/1.0.0"
SOURCE="$REPO_ROOT/code-quality-plugin"

echo "Verifying installed plugin..."
echo ""

# Check if plugin is installed
if [ ! -d "$INSTALLED" ]; then
    echo "❌ Plugin not installed at: $INSTALLED"
    echo ""
    echo "To install:"
    echo "  claude plugin marketplace add $REPO_ROOT"
    echo "  claude plugin install code-quality-ecs@seanshubin"
    exit 1
fi

# Check if source exists
if [ ! -d "$SOURCE" ]; then
    echo "❌ Source not found at: $SOURCE"
    exit 1
fi

echo "Installed: $INSTALLED"
echo "Source:    $SOURCE"
echo ""

# Compare directories
if diff -r "$INSTALLED" "$SOURCE" \
    --exclude=".git" \
    --exclude=".DS_Store" \
    --exclude="*.swp" \
    > /dev/null 2>&1; then
    echo "✅ Installed plugin matches source"
    exit 0
else
    echo "⚠️  Differences found between installed plugin and source"
    echo ""
    echo "Showing differences:"
    diff -r "$INSTALLED" "$SOURCE" \
        --exclude=".git" \
        --exclude=".DS_Store" \
        --exclude="*.swp" \
        --brief || true
    echo ""
    echo "To sync and reinstall:"
    echo "  ./scripts/sync-plugin.sh"
    echo "  claude plugin install code-quality-ecs@seanshubin"
    exit 1
fi
