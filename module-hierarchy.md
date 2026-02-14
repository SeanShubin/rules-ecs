# Module Hierarchy

## Concept
Rust's module system provides hierarchical namespacing enforced by the compiler. Crate boundaries are architectural (Cargo prevents cycles between crates). Module boundaries within a crate are organizational (they control visibility and aid navigation). Code should be organized by game domain, with parent modules serving as organizing containers and leaf modules containing code.

## Implementation
- Two module types:
    - **Organizing modules**: contain only `mod` declarations and `pub use` re-exports, zero logic
    - **Code modules**: contain structs, enums, functions, systems - the actual implementation
- Organization priority: game domain first
    - `combat/`, `movement/`, `inventory/`, `ui/`, `audio/`
    - Not by ECS role: `systems/`, `components/`, `resources/`
- Default to flat: keep hierarchy shallow until organizational needs require depth
- All parent modules should be organizing modules
- No vertical dependencies:
    - Parent modules must not contain logic that depends on child modules
    - Child modules should not depend on parent module logic
    - Use `pub use` re-exports in parent modules to surface child types (this is re-exporting, not depending)
- Shared code between sibling modules goes in explicitly-named sibling modules (e.g., `shared`, `common`, `types`)
- No cyclic dependencies between modules within a crate:
    - Cargo prevents cycles between crates (compiler-enforced)
    - Within a crate, design modules so dependencies flow in one direction
    - If module A uses types from module B and vice versa, extract shared types to a sibling module

## Crate vs Module Boundaries

| Boundary | Enforcement | Impact | Strictness |
|----------|-------------|--------|------------|
| **Crate** | Compiler (Cargo) | Compilation, versioning, publishing | Cycles impossible; dependency direction enforced |
| **Module** | Convention + visibility | Navigation, organization | Cycles possible but should be avoided |
| **Plugin** | Logical (your design) | Cohesion, feature grouping | May span modules or align 1:1 with modules |

### When to use separate crates
- Reusable game library (physics helpers, procedural generation)
- Clean separation between game logic and engine extensions
- When you want enforced dependency direction between major subsystems
- When different parts have different dependency trees

### When modules within one crate suffice
- Most game projects, especially during development
- When all code deploys together
- When the team is small (including solo)
- When crate compilation overhead isn't a concern

## Example Structure

```
src/
├── main.rs              // Entry point: App builder, plugin registration
├── combat/
│   ├── mod.rs           // Organizing: pub mod + pub use re-exports
│   ├── plugin.rs        // CombatPlugin: registers systems, events, resources
│   ├── components.rs    // Health, Attack, Armor, DamageType
│   ├── events.rs        // DamageEvent, DeathEvent
│   ├── systems.rs       // combat systems
│   └── damage.rs        // pure damage calculation functions
├── movement/
│   ├── mod.rs
│   ├── plugin.rs        // MovementPlugin
│   ├── components.rs    // Velocity, Acceleration, Friction
│   └── systems.rs       // movement systems
├── ui/
│   ├── mod.rs
│   ├── plugin.rs        // UiPlugin
│   ├── health_bar.rs    // health bar display systems
│   └── score.rs         // score display systems
└── shared/
    ├── mod.rs
    └── types.rs         // types used across multiple domains
```

**Why `components.rs` within a domain module is acceptable:** This is technical organization WITHIN a domain, not across domains. `combat/components.rs` contains only combat components. This is different from a top-level `components/` that mixes all domains.

## Re-exports

Parent `mod.rs` files should re-export the public API of their children for ergonomic imports:

```rust
// combat/mod.rs
mod components;
mod damage;
mod events;
mod plugin;
mod systems;

pub use components::*;
pub use events::*;
pub use plugin::CombatPlugin;
```

This is organizing, not logic. The parent module contains no behavior - it controls what's visible and how it's accessed.

## Rationale
"Why not organize by ECS role?" When adding a new enemy type, you want all enemy-related code in one place: its components, its systems, its events. Organizing by role (`systems/combat_system.rs`, `components/health.rs`, `events/damage_event.rs`) scatters a single feature across the entire tree. Domain-first keeps related changes together.

"Why avoid cycles between modules?" Cycles mean you cannot understand module A without understanding module B, and vice versa. There's no starting point. Even though the Rust compiler allows intra-crate cycles (unlike inter-crate), they still indicate tight coupling that makes code harder to navigate and change.

"What about a `prelude` module?" A `prelude` module that re-exports commonly used types is a Rust convention. This is acceptable as an organizing convenience. Keep it to types that are genuinely used across the entire codebase.

"When does a module become a crate?" When it has independent consumers (other projects want to use it), when it has a different release cadence, or when you want compiler-enforced dependency direction. For most games, modules within one crate are sufficient.

"Why is `components.rs` within a domain acceptable but `components/` at the root level isn't?" Scope. `combat/components.rs` is technical organization within a cohesive domain - all those components change when combat changes. A root-level `components/` mixes combat components with UI components with movement components - they change for different reasons and should not be grouped.

## Pushback
This rule assumes that domain-first organization aids navigation more than ECS-role organization. You might prefer role-based organization if you frequently need to see all systems or all components together. You might skip module hierarchy entirely for small games where a flat `src/` with a few files is perfectly navigable. The principle applies once the codebase is large enough that finding code by domain is faster than browsing a flat list.
