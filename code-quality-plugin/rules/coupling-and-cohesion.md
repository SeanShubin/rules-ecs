# Coupling and Cohesion

## Concept
Code should be organized so that elements that change together are grouped together, and elements that change for different reasons are kept separate. In Bevy, the **Plugin** is the primary cohesion boundary. A Plugin groups related systems, components, resources, and events that serve one gameplay domain. When a feature changes, modifications should be localized to one Plugin and its module, not scattered across the codebase.

## Implementation
- Group code that changes together into the same Plugin and module:
    - Systems that operate on the same components for the same gameplay reason
    - Components that define a single game concept (e.g., health, velocity, inventory slot)
    - Events that represent actions within one domain (e.g., combat events, UI events)
    - Resources that hold state for one subsystem
- Separate code that changes for different reasons into different Plugins:
    - Different gameplay domains: `CombatPlugin`, `MovementPlugin`, `InventoryPlugin`
    - Different technical concerns: `PhysicsPlugin`, `AudioPlugin`, `RenderingPlugin`
    - Not by ECS role: avoid `SystemsPlugin`, `ComponentsPlugin`, `ResourcesPlugin`
- Test by asking: "If X changes, what code needs to change?"
    - If unrelated plugins would need changes, separation is insufficient
    - If the same change scatters across many modules, cohesion is insufficient
- At the Plugin level: organize by gameplay domain first
    - Group by feature: `combat/`, `movement/`, `inventory/`, `ui/`
    - Not by ECS concept: `systems/`, `components/`, `resources/`
- At the module level: group related types that share a reason to change
- At the system level: each system should have one reason to change

## Context and Scale

Apply these guidelines with judgment:

- **Plugin granularity matters**: A Plugin with 5-10 systems is manageable. A Plugin with 40 systems likely has mixed concerns. Use system count and change patterns, not strict rules.

- **Technical plugins are acceptable**: Cross-cutting concerns like physics, audio, and rendering are technical by nature. A `PhysicsPlugin` that serves multiple gameplay domains is appropriate. The key test: does it serve one gameplay domain or many?

- **Crate boundaries matter more than module boundaries**: Dependencies between modules in the same crate are less concerning than dependencies between crates. Within a crate, modules provide organizational convenience. Between crates, dependencies create compilation constraints.

- **Small games don't need many plugins**: A pong clone with one `GamePlugin` is fine. Don't create `PaddlePlugin`, `BallPlugin`, `ScorePlugin` for 6 systems. Add plugins when the single plugin becomes hard to navigate or when changes start scattering.

**Test:** Track actual changes over time. Do changes scatter across unrelated plugins? That's genuine coupling. Do unrelated features touch the same systems? That's low cohesion. But if the organization works and changes stay localized, don't refactor based on theoretical concerns.

## Rationale
"How do I know what belongs in a plugin?" Ask what changes together. If changing how combat damage works requires updating damage calculation, health display, and death handling, those belong in the same plugin. If adding a new weapon type only affects the combat module, that concern is properly isolated.

"Why organize by domain instead of ECS role?" When you add a new enemy behavior, you want all enemy logic in one place. Organizing by ECS role (all systems in `systems/`, all components in `components/`) scatters a single feature across multiple directories. Domain-first organization keeps related changes together.

"Can plugins be too small?" Yes. If a plugin has one system and one component, it might not justify the overhead of a separate module. Group small related concerns until they grow large enough to warrant separation.

"What about shared components like Transform?" Components from Bevy's standard library (Transform, Visibility, etc.) are cross-cutting by design. Your domain plugins use them freely. The concern is your own game-specific components - those should have clear homes.

"When should I split a plugin?" When it has multiple unrelated reasons to change. If `GameplayPlugin` changes when you modify combat AND when you modify inventory AND when you modify dialogue, it's three plugins pretending to be one.

## Pushback
This rule assumes that change locality is worth the cost of additional plugin structure. You might reject this for game jams, prototypes, or very small games where a flat structure is navigable. You might prefer ECS-role organization if you value seeing all systems or all components together. The principle applies once the codebase is large enough that scattered changes cause real confusion.
