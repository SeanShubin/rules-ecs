#!/bin/bash
# test-github-distribution.sh
# Test what users will get when installing from GitHub

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
GITHUB_REPO="SeanShubin/rules-ecs"
INSTALLED="$HOME/.claude/plugins/cache/seanshubin/code-quality-ecs/1.0.0"
SOURCE="$REPO_ROOT/code-quality-plugin"

echo "Testing GitHub distribution..."
echo "This simulates what other users will get when they install from GitHub"
echo ""

# Check if local changes are uncommitted
cd "$REPO_ROOT"
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "⚠️  WARNING: You have uncommitted changes"
    echo "The GitHub version will differ from your local version"
    echo ""
    git status --short
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted"
        exit 1
    fi
fi

# Check if local commits are not pushed
if git log --branches --not --remotes | grep -q .; then
    echo "⚠️  WARNING: You have unpushed commits"
    echo "The GitHub version will not include these commits"
    echo ""
    git log --branches --not --remotes --oneline
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted"
        exit 1
    fi
fi

echo "Removing local marketplace if present..."
claude plugin marketplace remove seanshubin 2>/dev/null || true

echo "Adding marketplace from GitHub..."
if claude plugin marketplace add "$GITHUB_REPO"; then
    echo "✅ Marketplace added from GitHub"
else
    echo "❌ Failed to add marketplace from GitHub"
    echo ""
    echo "Possible issues:"
    echo "  - Repository is not public"
    echo "  - Repository name is incorrect"
    echo "  - No internet connection"
    exit 1
fi

echo ""
echo "Installing plugin from GitHub..."
if claude plugin install code-quality-ecs@seanshubin; then
    echo "✅ Plugin installed from GitHub"
else
    echo "❌ Failed to install plugin from GitHub"
    exit 1
fi

echo ""
echo "Comparing GitHub version to local source..."
echo ""

if diff -r "$INSTALLED" "$SOURCE" \
    --exclude=".git" \
    --exclude=".DS_Store" \
    --exclude="*.swp" \
    --exclude=".orphaned_at" \
    > /dev/null 2>&1; then
    echo "✅ GitHub distribution matches local source"
    echo ""
    echo "Users will get exactly what you have locally (after you push)"
else
    echo "⚠️  GitHub distribution differs from local source"
    echo ""
    echo "Showing differences:"
    diff -r "$INSTALLED" "$SOURCE" \
        --exclude=".git" \
        --exclude=".DS_Store" \
        --exclude="*.swp" \
        --exclude=".orphaned_at" \
        --brief || true
    echo ""
    echo "This is expected if you have local changes not yet pushed to GitHub"
    echo ""
    echo "To fix:"
    echo "  1. Commit your changes: git add . && git commit -m 'Update rules'"
    echo "  2. Push to GitHub: git push"
    echo "  3. Run this script again to verify"
fi

echo ""
echo "Restoring local marketplace for development..."
claude plugin marketplace remove seanshubin 2>/dev/null || true
claude plugin marketplace add "$REPO_ROOT" > /dev/null 2>&1 || true

echo "✅ Test complete"
echo ""
echo "To continue local development, reinstall from local:"
echo "  ./scripts/update-plugin.sh"
