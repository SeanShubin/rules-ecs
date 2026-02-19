# Code Quality Rules for ECS

This directory contains architectural and code quality rules for game development using the ECS (Entity Component System) paradigm. These rules are adapted from OOP business application standards, preserving the spirit of disciplined, maintainable code while respecting the fundamentally different design constraints of data-oriented game development. Examples use Rust and Bevy, but the architectural principles apply to ECS in general.

## Context

ECS is not "less disciplined OOP." It is a different paradigm optimized for different constraints. Business applications optimize for isolation, testability, and change locality. Game engines optimize for throughput, cache coherence, and frame-budget predictability. Discipline and quality take different forms in each context.

These rules encode what discipline means in ECS specifically.

## The Rules

1. **[Coupling and Cohesion](coupling-and-cohesion.md)** - Group code that changes together; separate code that changes for different reasons; Plugins are the primary cohesion boundary
2. **[System Dependencies](system-dependencies.md)** - Systems declare dependencies through parameters; the scheduler provides them; Resources and Components are the injection mechanism
3. **[Event Architecture](event-architecture.md)** - Use Bevy's typed events for cross-domain communication; events are the primary decoupling mechanism
4. **[Abstraction Levels](abstraction-levels.md)** - Separate orchestration systems from mechanical systems; each system operates at a consistent level
5. **[Module Hierarchy](module-hierarchy.md)** - Organize by game domain; no cycles; crate boundaries are architectural, module boundaries are organizational
6. **[Naming and Clarity](naming-and-clarity.md)** - Logic should have meaningful names; system parameters, components, and resources communicate intent through names
7. **[System Organization](system-organization.md)** - Explicit ordering, logical grouping via system sets, deterministic behavior across frames
8. **[Component and Resource Design](component-and-resource-design.md)** - Focused components, no god resources, bundles for logical grouping, marker components for queries

## Testing Practice

**[Test Patterns for ECS](test-patterns.md)** - Use World-based testing to verify systems in isolation; hide ECS infrastructure behind domain-focused test helpers

## Tooling and Process

**[Tooling and AI Integration](tooling-and-ai.md)** - Static analysis provides objective measurement; AI assists understanding; zero violations is optimal; adapt analysis to Rust's module system

## Start Here: [Severity Guidance](severity-guidance.md)

Before diving into individual rules, read the **Severity Guidance** to understand:
- Which violations must be fixed immediately (cycles, untestable systems, scattered changes)
- Which violations should be fixed when opportune (system ordering ambiguity, large plugins)
- Which patterns are acceptable in context (free-standing systems, concrete types in queries)
- Practical tests to determine if something is actually a problem

## Philosophy

These rules target **real maintainability problems in ECS codebases**, not OOP aesthetic preferences applied to the wrong paradigm.

### Problems That Multiply

When adding a game feature requires modifying systems across unrelated plugins, the plugin boundaries are wrong. When a single gameplay change touches combat, rendering, UI, and audio systems, cohesion is insufficient. (Coupling and Cohesion)

When systems depend on global mutable state that isn't declared in their parameters, behavior becomes unpredictable and untestable. When a system's actual dependencies differ from its declared parameters, you cannot reason about what it needs. (System Dependencies)

When systems communicate by mutating shared resources instead of sending events, implicit coupling grows invisibly. When adding a new response to a game action requires modifying the system that initiates it, the domains are coupled. (Event Architecture)

### Problems That Hide Structure

When a system mixes game state coordination with physics calculations, understanding the high-level flow requires parsing low-level math. When orchestration systems know about pixel coordinates and collision normals, changing how something works requires changing what coordinates it. (Abstraction Levels)

When modules have circular dependencies, you cannot understand one without understanding all others in the cycle. When parent modules contain code alongside child modules, the hierarchy becomes a dumping ground. (Module Hierarchy)

### Problems That Hide Intent

When system parameters use raw types without context, readers must trace through code to understand what entities are being queried. When components are named after implementation rather than domain concepts, the ECS data model doesn't communicate the game design. (Naming and Clarity)

When system execution order is implicit and depends on registration sequence, behavior changes when you reorder plugin setup. When systems that must run in sequence have no explicit ordering, frame-to-frame inconsistencies appear as subtle bugs. (System Organization)

When a single Resource struct accumulates fields for every subsystem, changes to one domain risk breaking another. When entities have dozens of components with no logical grouping, spawning and querying become error-prone. (Component and Resource Design)

### Patterns That Are Fine

Some patterns look like violations of OOP rules but are correct in ECS:
- **Free-standing system functions** - systems must be free functions for the scheduler; this is not "free-floating functions"
- **Concrete types in queries** - `Query<&Transform, With<Player>>` uses concrete types because ECS queries are data access patterns, not behavioral abstractions
- **Global Resources** - `Res<Time>` is global state, but it's declared in the system signature, making it explicit and testable
- **No constructor injection** - system parameter declaration IS dependency declaration; the scheduler IS the injector

## How to Use These Rules

### For Developers

1. **Read [Severity Guidance](severity-guidance.md) first** to calibrate judgment
2. **Consult specific rules** when encountering situations they address
3. **Use practical tests** before refactoring:
   - Does this cause actual confusion or bugs?
   - Do changes scatter across unrelated plugins?
   - Can you test this system with a minimal World?
   - Would refactoring make it clearer or just move complexity?

### For AI Assistants

When checking code against these rules:

1. **Start with [Severity Guidance](severity-guidance.md)** to understand what matters most
2. **Do not apply OOP rules to ECS code** - these rules replace, not supplement, OOP architectural standards
3. **Check structural foundation first** - Coupling/cohesion (scattered changes), system dependencies (undeclared state)
4. **Check ECS-specific issues next** - System ordering, component/resource design, event usage
5. **Consider the Exceptions sections** in each rule
6. **Provide context** - Explain WHY something is a problem, not just THAT it violates a rule
7. **Respect [Tooling and AI Integration](tooling-and-ai.md)** - When static analysis detects violations, take findings seriously

## Key Distinctions

### Crate vs Module Boundaries
- **Crate boundaries** are architectural - dependencies create compilation constraints and are enforced by Cargo (cycles impossible)
- **Module boundaries** within a crate are organizational - they aid navigation and enforce visibility
- Apply rules more strictly across crates than within them

### ECS Patterns vs OOP Patterns
- **OOP**: Classes encapsulate behavior; interfaces abstract it; constructors inject dependencies
- **ECS**: Components hold data; systems provide behavior; function parameters declare dependencies
- Don't force OOP patterns onto ECS; use the patterns native to the paradigm

### Performance-Motivated vs Arbitrary Design
- **Performance-motivated**: Using concrete types in queries (enables cache-efficient iteration), free-standing system functions (enables parallel scheduling)
- **Arbitrary**: God resources, unnamed magic numbers, implicit system ordering
- Accept performance-motivated patterns; reject arbitrary ones

## When Rules Conflict

Use this priority order based on structural criticality:

1. **Coupling and Cohesion** - Foundational; changes should be localized to plugins
2. **System Dependencies** - Structural; systems must declare what they use
3. **Event Architecture** - Cross-domain communication must be explicit
4. **Abstraction Levels** - Separate orchestration from mechanics
5. **Module Hierarchy** - No cycles, domain-first organization
6. **System Organization** - Explicit ordering, deterministic behavior
7. **Naming and Clarity** - Intent communicated through names
8. **Component and Resource Design** - Focused data types

If following one rule would violate a higher-priority rule, follow the higher-priority rule.

## Evolution

These rules reflect initial understanding of maintainable ECS code from the perspective of a business application developer learning game development. They should evolve based on:
- **Actual problems encountered** in Bevy projects
- **False alarms** that waste development time
- **Bevy idioms** that prove their value in practice
- **Performance discoveries** that change what's acceptable

If a rule consistently conflicts with practical game development reality, the rule should be refined.

## Summary

**The goal is maintainable game code, not OOP compliance in a different paradigm.**

Rules should help you:
- Prevent genuine problems (cycles, implicit coupling, untestable systems, scattered changes)
- Make informed trade-offs (plugin granularity, system ordering, event vs direct mutation)
- Focus effort on high-impact improvements

Rules should not:
- Create false alarms for idiomatic ECS patterns
- Force OOP structure onto data-oriented design
- Prioritize theoretical purity over frame-budget reality

When in doubt, ask: **"Is this making the game code genuinely harder to maintain, or just different from what I'm used to?"**

If the code is testable, changeable, performant, and understandable, it's probably fine.
