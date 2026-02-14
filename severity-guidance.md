# Severity Guidance: When Rules Matter Most

This guide helps you distinguish between critical violations that must be fixed and patterns that are acceptable in Rust/Bevy context. Priority is based on structural criticality - problems affecting architecture take precedence over local readability concerns.

## High Severity (Must Fix)

These violations create problems that multiply:

### 1. Scattered Changes
- **Single feature requires editing many unrelated plugins/modules**
- **Example:** Adding a new enemy type requires changes in combat, rendering, audio, and UI plugins
- **Rule:** Coupling and Cohesion
- **Action:** Group related code into one plugin/module

### 2. Hidden System Dependencies
- **Systems access state not declared in their parameters**
- **Example:** System uses global mutable static, thread-local storage, or direct I/O
- **Rule:** System Dependencies
- **Action:** Declare all dependencies as system parameters; wrap external concerns in Resources

### 3. Intra-Crate Module Cycles
- **Modules within a crate that depend on each other circularly**
- **Example:** `combat` uses types from `inventory`, `inventory` uses types from `combat`
- **Rule:** Module Hierarchy
- **Action:** Extract shared types to a sibling module, or use events for cross-domain communication

### 4. Implicit Cross-Domain Coupling
- **Systems in one domain directly mutate components owned by another domain**
- **Example:** `CombatSystem` directly modifies `ScoreDisplay` component instead of sending an event
- **Rule:** Event Architecture
- **Action:** Use events for cross-domain communication

## Medium Severity (Should Fix)

These violations hide structure or create fragile behavior:

### 1. Systems Mixing Abstraction Levels
- **Systems with 50+ lines mixing orchestration with calculations**
- **Example:** System that coordinates game state transitions AND performs physics math inline
- **Rule:** Abstraction Levels
- **Action:** Extract calculations to named helper functions

### 2. Implicit System Ordering
- **Systems with logical dependencies but no explicit ordering constraints**
- **Example:** Movement and collision detection run in arbitrary order, causing tunneling bugs
- **Rule:** System Organization
- **Action:** Use system sets or `.before()`/`.after()` for ordering

### 3. Vertical Module Dependencies
- **Parent modules containing logic that depends on child modules, or children depending on parent logic**
- **Example:** `game/mod.rs` contains functions that import from `game/combat/`
- **Rule:** Module Hierarchy
- **Action:** Move logic to a leaf module; parent modules should only organize and re-export

### 4. God Resources
- **A single Resource struct with 10+ fields serving multiple unrelated systems**
- **Example:** `GameState { score, health, wave, timer, paused, difficulty, ... }`
- **Rule:** Component and Resource Design
- **Action:** Split into focused resources: `GameScore`, `WaveState`, `DifficultySettings`

### 5. God Components
- **A single Component struct with many fields serving multiple unrelated systems**
- **Example:** `EnemyData { health, speed, damage, sprite, patrol_path, detection_range, loot_table, ... }`
- **Rule:** Component and Resource Design
- **Action:** Split into focused components: `Health`, `Speed`, `PatrolPath`, etc.

### 6. Large Plugins with Mixed Concerns
- **A Plugin with 20+ systems spanning multiple gameplay domains**
- **Rule:** Coupling and Cohesion
- **Action:** Split into focused plugins by domain

## Low Severity (Consider Context)

### 1. Unnamed Magic Values
- **Numeric literals without named variables or constants**
- **Example:** `Transform::from_xyz(100.0, 50.0, 0.0)` - what are these numbers?
- **Rule:** Naming and Clarity
- **Action:** Extract to named constants or variables

### 2. Complex Inline Query Filters
- **Long query type signatures without type aliases**
- **Example:** `Query<(&mut Transform, &Health, &Velocity), (With<Enemy>, Without<Dead>, Without<Stunned>)>`
- **Rule:** Naming and Clarity
- **Action:** Create a type alias or extract to a named variable

### 3. Clippy Warnings (if not yet treating as errors)
- **Any clippy warning during transition period**
- **Rule:** Tooling and AI Integration
- **Action:** Fix the warning; transition to `cargo clippy -- -D warnings`

### 4. Missing Tests for Game Logic
- **Non-trivial game logic systems without test coverage**
- **Rule:** Test Patterns
- **Action:** Add tests using World-based testing or test helpers

### 5. Overly Broad System Parameters
- **System declares `Query<&mut AllComponents>` when it only needs one field**
- **Rule:** Component and Resource Design
- **Action:** Query only what's needed for better parallelism and clarity

## Not Violations

These patterns are explicitly acceptable and should NOT be flagged:

### 1. Free-Standing System Functions
- Systems MUST be free functions for Bevy's scheduler. This is not "free-floating functions."
- `fn move_player(query: Query<&mut Transform, With<Player>>, time: Res<Time>)` is correct.

### 2. Concrete Types in Queries
- `Query<&Transform, With<Player>>` uses concrete types because ECS queries are data access patterns.
- No need for `dyn TransformInterface`. Components are data, not behavior.

### 3. Global Resources Accessed via System Parameters
- `Res<Time>`, `Res<AssetServer>`, `Res<Input<KeyCode>>` are global state declared explicitly in the system signature.
- This IS dependency declaration, just expressed through the ECS mechanism instead of constructors.

### 4. No Constructor Injection
- ECS systems don't have constructors. System parameters ARE the dependency declarations.
- Don't force OOP DI patterns onto ECS code.

### 5. Components Without Methods
- Plain data structs with `#[derive(Component)]` and no methods are correct ECS design.
- Components hold data; systems provide behavior. This is intentional, not "anemic."

### 6. Events Without Return Values
- Events flow one direction. No request-response pattern. This is by design.
- If a response is needed, the consumer sends a different event type.

### 7. Direct Component Mutation Within a Domain
- A combat system that reads `Attack` and writes `Health` within the combat plugin doesn't need events.
- Events are for cross-domain communication, not intra-domain data flow.

### 8. Simple Inline Filter Closures
- `query.iter().filter(|(_, h)| h.current > 0.0)` is readable for simple predicates.
- Extract only when the closure is complex or reused.

## Quick Decision Tree

```
Is there a module cycle?
  YES → Fix immediately
  NO ↓

Does the system declare all its dependencies as parameters?
  NO → Fix: remove hidden state access
  YES ↓

Does adding a feature scatter changes across unrelated plugins?
  YES → Fix: improve plugin cohesion
  NO ↓

Do systems in different domains communicate via direct mutation?
  YES → Fix: use events
  NO ↓

Is it a long system mixing orchestration with calculations?
  YES → Consider extracting helper functions
  NO ↓

Is it a god resource or god component?
  YES → Consider splitting
  NO ↓

Is it unnamed magic numbers?
  YES → Name them
  NO ↓

Does it follow Bevy idioms?
  YES → Acceptable
  NO → Evaluate against these rules, not OOP rules
```

## Priority Order

When multiple issues exist, fix in this order:

1. **Coupling and Cohesion** - Changes should be localized to plugins
2. **System Dependencies** - Systems must declare what they use
3. **Event Architecture** - Cross-domain communication must be explicit
4. **Abstraction Levels** - Separate orchestration from mechanics
5. **Module Hierarchy** - No cycles, domain-first organization
6. **System Organization** - Explicit ordering, deterministic behavior
7. **Naming and Clarity** - Intent communicated through names
8. **Component and Resource Design** - Focused data types

## Remember

- **These are ECS rules, not OOP rules.** Don't flag idiomatic Bevy patterns.
- **Fix problems, not patterns.** If it works, tests pass, and changes are localized, it's probably fine.
- **Context matters.** A pong clone doesn't need the same rigor as a 50-system RPG.
- **Rust's compiler catches more than JVM.** Focus energy on what the compiler doesn't enforce.

**The goal is maintainable game code, not compliance with rules from a different paradigm.**
