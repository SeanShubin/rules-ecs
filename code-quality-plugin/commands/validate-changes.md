---
name: validate-changes
description: Evaluate git changes against ECS code quality rules
---

# Validate Changes

Evaluate all changed code (both staged and unstaged) against the ECS code quality rules.

## Steps

1. **Check git status** to see if there are any changes
   - Run `git diff` to see unstaged changes
   - Run `git diff --staged` to see staged changes

2. **If no changes found:**
   - Report: "No changes detected. Use `/validate-project` to evaluate the entire codebase."
   - Stop here

3. **If changes found:**
   - Load the rules from the `code-quality-ecs:ecs` skill
   - Evaluate ALL changed code (both staged and unstaged) against the rules
   - Focus on:
     - New code that was just written
     - Modified code that was just changed
     - Context around changes that may have been affected

4. **Report findings:**
   - Organize by severity: **Always Violations** first, then **Usually Violations**
   - For each violation, provide:
     - File path and line number (if identifiable in diff)
     - What the violation is
     - Why it's a problem in ECS context
     - Suggested fix
   - If no violations found, report: "✅ All changes comply with ECS code quality rules"

5. **If violations found:**
   - Ask: "Would you like me to fix these violations?"
   - Wait for confirmation before making changes
