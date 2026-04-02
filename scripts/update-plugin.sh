#!/bin/bash
# update-plugin.sh
# Check if installed plugin is out of date, auto-install if needed, then verify

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
INSTALLED="$HOME/.claude/plugins/cache/seanshubin/code-quality-ecs/1.0.0"
SOURCE="$REPO_ROOT/code-quality-plugin"

echo "Checking installed plugin status..."
echo ""

# Function to check if installed matches source
check_match() {
    if [ ! -d "$INSTALLED" ]; then
        return 1  # Not installed
    fi

    if diff -r "$INSTALLED" "$SOURCE" \
        --exclude=".git" \
        --exclude=".DS_Store" \
        --exclude="*.swp" \
        --exclude=".orphaned_at" \
        > /dev/null 2>&1; then
        return 0  # Match
    else
        return 1  # Mismatch
    fi
}

# First check
if ! check_match; then
    if [ ! -d "$INSTALLED" ]; then
        echo "❌ Plugin not installed"
    else
        echo "⚠️  Installed plugin is out of date"
    fi

    echo ""
    echo "Installing plugin..."

    # Ensure marketplace is added
    claude plugin marketplace add "$REPO_ROOT" > /dev/null 2>&1 || true

    # Install/update the plugin
    if claude plugin install code-quality-ecs@seanshubin; then
        echo "✅ Plugin installed"
        echo ""

        # Verify the installation
        echo "Verifying installation..."
        if check_match; then
            echo "✅ Plugin is now up to date"
            exit 0
        else
            echo "⚠️  Plugin installed but still differs from source"
            echo ""
            echo "This might indicate:"
            echo "  - Version mismatch in plugin.json"
            echo "  - Claude Code is caching an old version"
            echo ""
            echo "Try:"
            echo "  claude plugin uninstall code-quality-ecs@seanshubin"
            echo "  claude plugin install code-quality-ecs@seanshubin"
            exit 1
        fi
    else
        echo "❌ Failed to install plugin"
        exit 1
    fi
else
    echo "✅ Plugin is up to date"
    exit 0
fi
