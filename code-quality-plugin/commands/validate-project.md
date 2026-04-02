---
name: validate-project
description: Comprehensive code quality evaluation scaled to project size
---

# Validate Project

Perform a code quality assessment of the entire codebase against the ECS code quality rules. The depth of analysis automatically scales based on project size.

## Approach: Size-Based Strategy

The validation strategy adapts to your codebase size to maximize value within context limits:

- **Small projects** (< 50 source files): Comprehensive file-by-file analysis
- **Medium projects** (50-200 files): Strategic sampling with detailed analysis
- **Large projects** (> 200 files): High-level architectural patterns

For incremental validation of recent changes, use `/validate-changes` instead.

## Steps

### 1. Determine Project Size

Count source code files (exclude tests, generated code, vendor/target directories):
- Use `find` or `git ls-files` to count relevant Rust source files (*.rs)
- Determine which strategy to use based on count

### 2. Load Rules

Load the `code-quality-ecs:ecs` skill to understand the 9 core rules:
1. Coupling and Cohesion
2. System Dependencies
3. Event Architecture
4. Architectural Layers
5. Abstraction Levels
6. Module Hierarchy
7. Naming and Clarity
8. System Organization
9. Component and Resource Design

### 3. Execute Size-Appropriate Strategy

#### Small Projects (< 50 files): Comprehensive Analysis

**Goal**: Catch every violation while the codebase is small and fixable.

1. **Map project structure** (crates, modules, plugins)
2. **Read and analyze every source file**:
   - Load each .rs file
   - Evaluate against all 9 rules
   - Note specific violations with line numbers
3. **Check architectural patterns**:
   - Module dependencies and cycles
   - Plugin organization
   - System ordering and dependencies
4. **Report ALL violations found**:
   - Organize by severity (Always → Usually)
   - Provide file:line for each violation
   - Explain why it's a problem and how to fix
5. **Provide fix priority order**

**Benefit**: Fix problems while the codebase is small. Establishes good patterns early.

#### Medium Projects (50-200 files): Strategic Deep Dive

**Goal**: Balance comprehensive analysis with context constraints.

1. **Analyze project structure** (crates, modules, plugin organization)
2. **Identify critical areas**:
   - Core game logic systems
   - Recently changed files (`git log --name-only`)
   - Plugin entry points and main flows
3. **Detailed analysis of sampled files** (~30-40 files):
   - Load and evaluate against all 9 rules
   - Focus on core logic and recent changes
   - Note specific violations with locations
4. **Pattern scanning for entire codebase**:
   - Use Grep to find common violations across all files
   - Cyclic dependencies, undeclared dependencies, layer violations
   - Global state access patterns
5. **Report**:
   - Detailed violations in analyzed files
   - Patterns detected across codebase
   - Priority recommendations

**Benefit**: Deep analysis where it matters, pattern detection everywhere.

#### Large Projects (> 200 files): Architectural Assessment

**Goal**: Identify systemic issues and architectural problems.

1. **Analyze project architecture**:
   - Crate/module hierarchy
   - Plugin organization patterns using Explore agent
   - Identify architectural layers (input/simulation/presentation)

2. **Scan for systemic violations** (use Grep):
   - **Cyclic dependencies**: Import/use patterns
   - **Undeclared dependencies**: Global state not in system parameters
   - **Layer violations**: Simulation accessing input/rendering types
   - **Mixed abstraction**: Systems with orchestration + mechanics
   - **Implicit ordering**: Systems without `.after()` / `.before()`
   - **God resources**: Single resource with many unrelated fields

3. **Strategic sampling** (~20 files):
   - Representative files from each major plugin
   - Load and check against rules for pattern confirmation

4. **Report architectural findings**:
   - Cyclic dependencies with examples
   - Module hierarchy violations
   - Systemic patterns with example locations (2-3 each)
   - General recommendations, not exhaustive violations

**Benefit**: Understand architectural health without exhaustive analysis.

### 4. Report Format

Organize findings by priority:

#### Always Violations (Fix Immediately)
- Cyclic module dependencies
- Undeclared system dependencies (global state)
- Game logic reading raw input
- Simulation mutating presentation
- Business logic mixed with I/O
- [File:line for each, with explanation]

#### Usually Violations (Fix When Opportune)
- Large plugins with unrelated features
- Systems mixing orchestration and mechanics
- God resources
- Implicit system ordering
- Direct mutation coupling (should use events)
- [Locations with context]

#### Summary
- Files analyzed / Total files
- Violation counts by category
- Estimated fix effort
- Priority order recommendations

#### Next Steps
- Start with highest priority violations
- For incremental validation: use `/validate-changes`
- Re-run `/validate-project` after major refactoring

## Key Insight

**Small codebases have a unique opportunity**: Fix all violations before they multiply. As game code grows, violations become harder to fix. This command invests more analysis effort in small projects where comprehensive fixes are still practical.
