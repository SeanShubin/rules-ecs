# Tooling and AI Integration

## Concept
Static analysis tools provide objective, deterministic quality measurement. AI assists developers in understanding and responding to tool findings, but cannot override tool authority. The goal is always zero violations. This philosophy is unchanged from OOP - only the tools and what they measure change for ECS.

## Philosophy

The core philosophy is identical to the OOP rules and is not repeated here in full. See the original `tooling-and-ai.md` for:
- Zero Violations Is Optimal
- The Ignore List Trap
- Mechanical Detection Maintains Objectivity
- Governance Model
- Petition Process

This document focuses on what changes for ECS development.

## Rust's Built-In Tooling

Rust's ecosystem provides strong baseline quality enforcement:

### Compiler (`rustc`)
- **Ownership and borrowing** enforced at compile time - entire categories of bugs are impossible
- **Exhaustive pattern matching** - the compiler ensures all enum variants are handled
- **No null** - `Option<T>` forces explicit handling of absent values
- **Cross-crate cycles impossible** - Cargo rejects them

### Clippy (`cargo clippy`)
- Rust's official linter with hundreds of lint rules
- Enforces idiomatic Rust patterns
- Categories: correctness, style, complexity, performance, pedantic
- Run with `cargo clippy -- -D warnings` to treat warnings as errors
- **Zero clippy warnings is the standard.** Same as zero violations in custom tooling.

### Rustfmt (`cargo fmt`)
- Deterministic code formatting
- Eliminates style debates
- Run with `cargo fmt --check` in CI to enforce

### Miri (`cargo miri`)
- Detects undefined behavior in unsafe code
- Use when working with raw pointers or FFI

## Custom Static Analysis for Rust

### What Cargo and Clippy Don't Detect

| Problem | Why Built-In Tools Miss It |
|---------|--------------------------|
| Intra-crate module cycles | Compiler allows them; only inter-crate cycles are rejected |
| Vertical module dependencies | Parent modules depending on children is legal Rust |
| God resources | A 20-field Resource struct compiles fine |
| Plugin cohesion violations | No tool measures if a Plugin's systems are related |
| System ordering gaps | Missing `.before()`/`.after()` constraints are not errors |
| Implicit shared state | Global mutable statics are `unsafe` but legal |

### Porting code-structure Concepts

The four metrics from the JVM code-structure tool map to Rust:

| Metric | JVM Implementation | Rust Implementation |
|--------|-------------------|---------------------|
| **IN_DIRECT_CYCLE** | Bytecode constant pool references | `use` statements + AST type references |
| **IN_GROUP_CYCLE** | Package-level aggregation of class dependencies | Module-level aggregation of item dependencies |
| **ANCESTOR_DEPENDS_ON_DESCENDANT** | Package hierarchy prefix matching | Module path prefix matching |
| **DESCENDANT_DEPENDS_ON_ANCESTOR** | Package hierarchy prefix matching | Module path prefix matching |

### Implementation Strategy

**Phase 1: Name extraction**
- Parse Rust source files using the `syn` crate
- Extract module declarations (`mod`), public items (`pub struct`, `pub fn`, `pub enum`, `pub trait`)
- Build hierarchical name tree from module paths

**Phase 2: Dependency extraction**
- Parse `use` statements to determine what each module imports
- Track type references in function signatures and struct fields
- Map dependencies between modules (not just items)

**Phase 3: Analysis**
- Tarjan's algorithm for cycle detection (reuse from code-structure)
- Module path prefix matching for ancestor/descendant checks
- Scoped analysis at multiple module depths

**Phase 4: Integration**
- Cargo custom command (`cargo code-structure`) or build script
- JSON output for CI integration
- Report generation (same concepts as JVM version)

### What Rust Gives You for Free

- **Cross-crate cycles: impossible.** Cargo enforces this. No need to detect.
- **Visibility enforcement: compiler-checked.** `pub`, `pub(crate)`, `pub(super)` are enforced.
- **Unused imports: compiler warning.** Dead code detection is built in.
- **Type safety: guaranteed.** No runtime type errors (outside `unsafe`).

Focus custom tooling on what the compiler doesn't enforce: intra-crate module cycles, vertical dependencies, and organizational metrics.

## AI's Role (Unchanged)

**AI can and should:**
- Explain why a tool detected a violation
- Evaluate whether a violation is a real problem or a legitimate pattern
- Suggest refactorings to achieve zero violations
- Help formulate arguments for tool refinement
- Challenge tool findings if they seem unreasonable
- **Apply these ECS rules, not OOP rules, when reviewing game code**

**AI cannot:**
- Add violations to ignore lists
- Override tool maintainer decisions
- Make subjective exceptions to quality standards
- Apply OOP architectural patterns where ECS patterns are appropriate

**Critical reminder from OOP tooling rule:** AI has access to loaded rules but does NOT automatically consult them when making evaluative judgments. When asking for code evaluation, always append "according to my ECS rules" or follow up with "does this comply with my architectural standards?"

## Quality Metrics Structure

Same structure as OOP - whole numbers, zero-optimal, granular:

```json
{
  "inDirectCycle": 0,
  "inGroupCycle": 0,
  "ancestorDependsOnDescendant": 0,
  "descendantDependsOnAncestor": 0,
  "clippyWarnings": 0,
  "fmtDifferences": 0
}
```

## CI Pipeline

```bash
# Format check
cargo fmt --check

# Lint check (zero warnings)
cargo clippy -- -D warnings

# Tests
cargo test

# Custom structure analysis (when implemented)
cargo code-structure --fail-on-violations
```

All checks must pass. Zero tolerance for warnings.

## Rationale
"Why zero clippy warnings?" Same reason as zero violations in custom tooling. Going from 0 to 1 is immediately visible. Going from 15 to 16 is hidden. Clippy warnings are individually small but collectively signal declining attention to quality. Treat them as errors from the start and you never accumulate debt.

"Why not use `#[allow(clippy::...)]`?" Same as ignore lists - it masks signal. If a clippy lint is genuinely wrong for your pattern, petition the clippy team or restructure the code. The rare exception: a lint that fires on Bevy-generated code you cannot control. Document these explicitly.

"Is custom static analysis worth building for a learning project?" Not initially. Start with Cargo + Clippy + Rustfmt. Build custom analysis when:
- The codebase grows large enough that module organization matters
- You want to enforce the same structural discipline you have in JVM projects
- You want to practice building Rust tooling (which is itself valuable learning)

## Pushback
This rule assumes that objective measurement is more valuable than flexible judgment. The philosophy is identical to OOP - see the original tooling-and-ai.md for full pushback discussion. The only new consideration: Rust's compiler already enforces more quality constraints than the JVM, so custom tooling can focus on a narrower set of concerns.
