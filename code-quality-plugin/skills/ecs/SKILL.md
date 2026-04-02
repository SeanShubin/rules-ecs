---
name: Sean's ECS rules
description: Apply these rules when writing, modifying, reviewing, or designing ECS game code. Covers coupling/cohesion, system dependencies, event architecture, architectural layers, abstraction levels, module hierarchy, naming, system organization, and component/resource design for maintainable game development.
---

# Code Quality Rules for ECS

**IMPORTANT**: This skill includes detailed reference documents in the `rules/` directory. Consult these for comprehensive guidance:
- `rules/quick-reference.md` - Fast violation lookup
- `rules/severity-guidance.md` - What to fix first
- `rules/README.md` - Overview and philosophy
- Individual rule files for deep context and edge cases

## Quick Decision Process

1. **Start with quick-reference.md** - Use the decision tree for fast violation checks
2. **Check structural foundation first** - Coupling and cohesion (scattered changes), system dependencies (undeclared state)
3. **Check ECS-specific issues next** - System ordering, event architecture, architectural layers
4. **Check structural organization** - Abstraction levels (mixing levels), module hierarchy (cycles)
5. **Consider local clarity** - Naming, component/resource design
6. **Consult detailed rules** - For nuanced situations, read the full rule documents
7. **Consider the Exceptions** - Not everything that looks like a violation is one
8. **Provide context** - Explain WHY something is a problem, not just THAT it violates a rule
9. **Follow priority order** - When rules conflict, higher priority wins (coupling/cohesion beats naming)

## ❌ Always Violations (Fix Immediately)

| Pattern | Example | Why Bad | Fix |
|---------|---------|---------|-----|
| Cyclic module dependencies | `combat` imports `ui`, `ui` imports `combat` | Cannot understand in isolation | Extract shared concept or use events |
| Undeclared dependencies | System accesses global state not in parameters | Cannot test or reason about behavior | Declare all dependencies as system parameters |
| Game logic reads raw input | Movement system reads `KeyCode::W` | Cannot add gamepad support without modifying logic | Use action events (`MoveAction`) |
| Simulation mutates presentation | Collision system sets sprite color | Testing collision requires renderer | Emit events, let presentation systems respond |
| Business + I/O mixed in system | System validates AND writes to file | Cannot test logic alone | Separate orchestration from execution |
| Plugin with scattered changes | Adding feature touches multiple unrelated plugins | Plugin boundaries are wrong | Group code that changes together |

## ⚠️ Usually Violations (Fix When Opportune)

| Pattern | When It's A Problem | Test | Fix |
|---------|-------------------|------|-----|
| Large plugin | 30+ systems, unrelated features | Do unrelated features touch it? | Split by game domain or reason-to-change |
| System mixing levels | Orchestration + physics math in same system | Business change requires understanding details? | Extract mechanics to separate systems |
| God resource | Single resource with fields for all subsystems | Changes to one feature break another? | Split by domain responsibility |
| Implicit system ordering | Systems depend on execution order but no `.after()` | Bugs from plugin registration order? | Add explicit `.after()` / `.before()` constraints |
| Direct mutation coupling | System mutates shared resource; others read it | Hard to track who changed what? | Use events for cross-domain changes |
| Entity bundles with unrelated components | `PlayerBundle` has rendering + audio + inventory | Spawning requires unrelated knowledge? | Create focused bundles by concern |

## ✅ Acceptable Patterns (Not Violations)

| Pattern | Example | Why Acceptable |
|---------|---------|---------------|
| Free-standing system functions | `fn update_velocity(mut query: Query<...>)` | Required by ECS scheduler; not "free-floating functions" |
| Concrete types in queries | `Query<&Transform, With<Player>>` | Data access patterns, not behavioral abstractions |
| Global resources declared | `Res<Time>` in system parameters | Explicit dependency declaration; testable |
| Private cohesive helper functions | `fn calculate_damage(...)` used only by combat systems | Serves module's single responsibility |
| Performance-motivated patterns | Systems iterate components directly | Cache coherence and throughput requirements |
| Runtime-calculated values | `style: Style { width: Val::Px(health_percent * 200.0) }` | Values only known at runtime |
| Marker components | `#[derive(Component)] struct Player;` | Standard ECS pattern for entity categorization |

## Rule Priority Order

When multiple issues exist or rules conflict, use this priority order:

1. **Coupling and Cohesion** - Foundational principle; changes should be localized to plugins
2. **System Dependencies** - Structurally critical; systems must declare what they use
3. **Event Architecture** - Cross-domain communication must be explicit
4. **Architectural Layers** - Input, simulation, presentation separated by protocols
5. **Abstraction Levels** - Structural organization; separate orchestration from mechanics
6. **Module Hierarchy** - Module-level architecture (no cycles)
7. **System Organization** - Explicit ordering, deterministic behavior
8. **Naming and Clarity** - Local readability; communicating intent
9. **Component and Resource Design** - Focused data types

## The Nine Rules (Summary)

For nuanced situations, consult the detailed rule documents in `rules/`:

### 1. Coupling and Cohesion → `rules/coupling-and-cohesion.md`
Group code that changes together; separate code that changes for different reasons; Plugins are the primary cohesion boundary.
- **Problem**: When adding a game feature requires modifying unrelated plugins, plugin boundaries are wrong
- **Test**: Does adding a feature require changing unrelated plugins?
- **Details**: See the full document for plugin granularity, module vs crate boundaries

### 2. System Dependencies → `rules/system-dependencies.md`
Systems declare dependencies through parameters; the scheduler provides them; Resources and Components are the injection mechanism.
- **Problem**: Cannot test code when systems access global state not declared in parameters
- **Test**: Can you test the system with a minimal World?
- **Details**: See the full document for what should be a resource vs component, legitimate direct dependencies

### 3. Event Architecture → `rules/event-architecture.md`
Use Bevy's typed events for cross-domain communication; events are the primary decoupling mechanism.
- **Problem**: Implicit coupling when systems communicate by mutating shared resources
- **Test**: Can you add new responses to a game action without modifying the initiating system?
- **Details**: See the full document for event patterns, when to use events vs direct mutation

### 4. Architectural Layers → `rules/architectural-layers.md`
Separate input, simulation, and presentation into layers with explicit protocols; game logic never reads raw input or references rendering types.
- **Problem**: Adding gamepad support requires modifying movement systems; changing art style requires modifying game logic
- **Test**: Can you test simulation without input devices or renderer?
- **Details**: See the full document with extensive examples of layer violations and protocols

### 5. Abstraction Levels → `rules/abstraction-levels.md`
Separate orchestration systems from mechanical systems; each system operates at a consistent level.
- **Problem**: Systems mixing game state coordination with physics calculations hide high-level flow
- **Test**: Does understanding the flow require parsing low-level mechanics?
- **Details**: See the full document with examples of system level separation

### 6. Module Hierarchy → `rules/module-hierarchy.md`
Organize by game domain; no cycles; crate boundaries are architectural, module boundaries are organizational.
- **Problem**: Circular dependencies mean you cannot understand one module without understanding all others
- **Test**: Can you understand modules in isolation?
- **Details**: See the full document for crate vs module distinction and acceptable patterns

### 7. Naming and Clarity → `rules/naming-and-clarity.md`
Logic should have meaningful names; system parameters, components, and resources communicate intent through names.
- **Problem**: Components named after implementation rather than domain concepts make the ECS data model unclear
- **Test**: Do component/resource names communicate game design or just data structures?
- **Details**: See the full document for naming conventions and examples

### 8. System Organization → `rules/system-organization.md`
Explicit ordering, logical grouping via system sets, deterministic behavior across frames.
- **Problem**: Implicit system ordering causes bugs when plugin registration sequence changes
- **Test**: Does system behavior depend on plugin registration order?
- **Details**: See the full document for system sets, ordering patterns, and determinism

### 9. Component and Resource Design → `rules/component-and-resource-design.md`
Focused components, no god resources, bundles for logical grouping, marker components for queries.
- **Problem**: God resources mean changes to one domain risk breaking another
- **Test**: Does changing one feature require understanding unrelated resource fields?
- **Details**: See the full document for component granularity, resource design, bundle patterns

## Working With Static Analysis Tooling

When static analysis tools detect violations:

### ✅ Correct Response Pattern
1. **Tool reports violation** → Take finding seriously
2. **Evaluate legitimacy** → Is this a real problem or legitimate ECS pattern?
3. **If real problem** → Restructure code to achieve zero violations
4. **If legitimate pattern** → Petition tool maintainers to refine tool (not add to ignore list)

### Key Principles
- **Zero is optimal** - Quality metrics designed so zero is always the goal
- **Clear signal** - 0 → 1 is immediately visible, 15 → 16 is hidden
- **No masking** - New problems obvious when baseline is zero
- **No ignore lists** - Systemic incentive failure

### AI's Role
- ✅ Explain why tool detected violation
- ✅ Evaluate if violation is real problem or legitimate ECS pattern
- ✅ Suggest refactorings to achieve zero violations
- ✅ Help formulate petition for tool maintainers
- ❌ Never add violations to ignore lists
- ❌ Never make subjective exceptions to quality standards

## Additional Resources

- **Test Patterns for ECS** → `rules/test-patterns.md`
  - How to use World-based testing to verify systems in isolation
  - Hide ECS infrastructure behind domain-focused test helpers
  - Make tests readable, maintainable, and resilient to implementation changes

- **Tooling and AI Integration** → `rules/tooling-and-ai.md`
  - Complete guidance on working with static analysis tools
  - Zero violations philosophy and AI's role
  - Adapting to Rust's module system

## Remember

- **The goal is maintainable game code, not OOP compliance in a different paradigm**
- **Fix problems, not patterns** - If it works and is idiomatic ECS, it might be fine
- **Context matters** - Crate boundaries ≠ module boundaries; performance requirements matter
- **ECS patterns are OK** - Free-standing systems, concrete types in queries, declared global resources
- **Test pragmatically** - Ask: "Does this cause actual confusion or bugs? Do changes scatter? Hard to test?"
- **Respect tooling** - Zero violations is the goal
- **Consult detailed rules** - When situations are nuanced, read the full rule documents in `rules/`

**When in doubt, ask: "Is this making the game code genuinely harder to maintain, or just different from what I'm used to?"**

If the code is testable, changeable, performant, and understandable, it's probably fine.

---

**For comprehensive guidance, see:**
- `rules/quick-reference.md` - Fast violation lookup with decision tree
- `rules/severity-guidance.md` - Priority order for fixing violations
- `rules/README.md` - Philosophy and how to use these rules
- Individual rule files for detailed context, rationale, and edge cases
