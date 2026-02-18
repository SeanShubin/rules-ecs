# Component and Resource Design

## Concept
Components and Resources are the data model of an ECS game. Components define what entities are and what properties they have. Resources define shared game state. Both should be focused, well-named, and designed so that systems can query exactly what they need without pulling in unrelated data. Poor component/resource design leads to the ECS equivalents of god objects and tight coupling.

### Type Boundaries Are Concurrency Boundaries
In OO systems, type boundaries are primarily about abstraction and code organization — you draw them where the domain model is cleanest. In ECS, type boundaries serve a second role: they are the boundaries the scheduler uses to determine what can run in parallel. Every component boundary is a potential parallelism boundary. Every marker component is a filter that can partition entities into non-overlapping sets for concurrent access.

This means type design in ECS has consequences at two levels:
- **Architectural** — how clear, cohesive, and maintainable the data model is (same as any paradigm)
- **Runtime** — how much parallelism the scheduler can extract, because it can only parallelize systems whose data access doesn't overlap

These two levels usually align: small, focused components with clear responsibilities are both good design and good for parallelism. But when they diverge — when a "clean" abstraction bundles unrelated data into one component — the runtime cost is real. Systems that touch different fields of the same component still conflict in the scheduler's eyes, forcing sequential execution. Design types with both levels in mind.

## Implementation

### Components
- Each component represents one concept:
    - `Health { current: f32, max: f32 }` - one concept: how alive something is
    - `Velocity(Vec2)` - one concept: how fast and in what direction
    - Not `EnemyData { health: f32, speed: f32, damage: f32, sprite: Handle<Image> }` - multiple concerns
- Use marker components for entity classification:
    - `#[derive(Component)] struct Player;` - marks an entity as the player
    - `#[derive(Component)] struct Enemy;` - marks an entity as an enemy
    - Enables queries like `Query<&Transform, With<Player>>` - clear intent
- Use bundles to group components that are always spawned together:
    - A bundle is a convenience for spawning, not an architectural unit
    - Systems should query individual components, not bundles
    - Bundles can nest other bundles
- Components hold data, not behavior:
    - Components may have methods for data access (getters, calculated properties)
    - Components should not perform I/O, send events, or mutate other components
    - Pure transformation methods are fine: `impl Health { fn is_alive(&self) -> bool { self.current > 0.0 } }`
- Prefer many small components over few large ones:
    - Systems declare exactly what they need via queries
    - Small components allow fine-grained queries and better parallelism
    - Large components force systems to access data they don't need

### Resources
- Each resource owns one piece of shared state:
    - `GameScore { value: u32 }` - clear, focused
    - `WaveConfig { enemies_per_wave: u32, wave_interval: Duration }` - cohesive configuration
    - Not `GameState { score: u32, level: u32, enemies_spawned: u32, timer: f32, paused: bool, ... }` - god resource
- Resources for external boundaries:
    - Wrap external concerns in Resources for testability
    - `Res<Clock>` instead of calling `Instant::now()` directly
    - `Res<RandomSource>` instead of calling `rand::random()` directly
    - In tests, insert controlled implementations
- Resources for configuration:
    - Game settings, difficulty parameters, level data
    - Inserted at startup or when entering a new state
    - Systems read with `Res<T>`, startup systems write with `Commands::insert_resource()`
- Avoid mutable resources when events suffice:
    - If multiple systems write to a resource to communicate, use events instead
    - `ResMut<T>` signals exclusive access and prevents parallelism
    - Reserve `ResMut<T>` for state that genuinely needs in-place mutation (timers, accumulators)

### Enums for State
- Use Rust enums for component state that has distinct variants:
    ```rust
    #[derive(Component)]
    enum EnemyBehavior {
        Patrol { path: Vec<Vec2>, current_index: usize },
        Chase { target: Entity },
        Flee { from: Vec2 },
        Idle { duration: Timer },
    }
    ```
- This leverages Rust's type system: each variant carries only relevant data
- Systems pattern-match on the variant, making state transitions explicit

## Anti-Patterns

### God Resource
```rust
// Bad: one resource holding everything
struct GameData {
    score: u32,
    player_health: f32,
    enemy_count: u32,
    current_wave: u32,
    time_remaining: f32,
    difficulty: f32,
    is_paused: bool,
    high_scores: Vec<u32>,
}
```

Every system that needs any of this data requires `Res<GameData>` or `ResMut<GameData>`. Systems that only need the score conflict with systems that only need the timer. Split into focused resources: `GameScore`, `WaveState`, `DifficultySettings`, etc.

### Component Soup
```rust
// Bad: entity with many unrelated components, no logical grouping
commands.spawn((
    Transform::default(),
    Visibility::default(),
    Health { current: 100.0, max: 100.0 },
    Velocity(Vec2::ZERO),
    Acceleration(Vec2::ZERO),
    Friction(0.8),
    CollisionBox { width: 32.0, height: 32.0 },
    Sprite { ... },
    AnimationState { ... },
    Enemy,
    DamageOnContact { amount: 10.0 },
    DropTable { items: vec![...] },
    ExperienceValue(50),
    PatrolPath { ... },
    DetectionRange(200.0),
));
```

Use bundles to group related components:

```rust
#[derive(Bundle)]
struct PhysicsBundle {
    velocity: Velocity,
    acceleration: Acceleration,
    friction: Friction,
    collision_box: CollisionBox,
}

#[derive(Bundle)]
struct EnemyBundle {
    marker: Enemy,
    health: Health,
    physics: PhysicsBundle,
    damage: DamageOnContact,
    drops: DropTable,
    xp: ExperienceValue,
    behavior: PatrolPath,
    detection: DetectionRange,
}
```

The bundle communicates the logical grouping. Spawning is clearer. Systems still query individual components.

### Stringly-Typed Components
```rust
// Bad: using strings where enums belong
#[derive(Component)]
struct EntityType(String);  // "enemy", "player", "projectile"

// Good: use the type system
#[derive(Component)] struct Enemy;
#[derive(Component)] struct Player;
#[derive(Component)] struct Projectile;
```

Marker components enable `With<T>` / `Without<T>` query filters. String comparisons are slower, error-prone, and invisible to the type checker.

## Rationale

### How the Scheduler Sees Your Types
Bevy's scheduler builds a dependency graph from system parameter signatures. It applies Rust's borrowing rules at the component level: multiple readers OR one writer. Two systems can run in parallel if and only if their access is compatible — no shared `&mut` on the same component or resource type. The scheduler does not see inside a component; it cannot tell that two systems use different fields of the same struct. It only sees the type.

This has concrete design implications:
- **Component granularity controls parallelism.** A single `Stats { health: f32, speed: f32, damage: f32 }` component means any system that mutates health conflicts with any system that reads speed. Three separate components (`Health`, `Speed`, `Damage`) let those systems run concurrently.
- **Marker components control query partitioning.** `Query<&mut Transform>` conflicts with every other `Transform` writer. `Query<&mut Transform, With<Player>>` and `Query<&mut Transform, With<Enemy>>` access disjoint archetype sets, so the scheduler can parallelize them. The marker types are what make this partition visible.
- **Resource access is coarse-grained.** `Res<T>` and `ResMut<T>` operate on the entire resource. There is no way to borrow one field of a resource. A god resource with 10 fields forces exclusive access for any mutation, blocking all other readers and writers of that resource.
- **Ordering constraints compound the problem.** If you overconstrain system ordering (e.g., unnecessary `.chain()` or `.before()`/`.after()`), you eliminate parallelism the scheduler could otherwise provide. But if your types are too coarse, the scheduler eliminates parallelism for you — silently, with no explicit ordering in your code.

The last point is especially important: overconstraining via ordering is visible in code and easy to audit. Overconstraining via coarse types is invisible — the scheduler quietly serializes systems and you never see a warning.

"Why many small components instead of fewer larger ones?" ECS parallelism depends on non-overlapping access. If `MovementSystem` needs `Query<&mut BigComponent>` and `RenderSystem` needs `Query<&BigComponent>`, they cannot run in parallel. If movement only mutates `Velocity` and rendering only reads `Sprite`, they parallelize naturally. Smaller components enable more parallelism.

"Why not just use Rust structs with methods for game objects?" That's OOP, not ECS. A `Player` struct with `move()`, `attack()`, and `take_damage()` methods couples behavior to data. ECS separates them: data in components, behavior in systems. This enables composition (attach Health to any entity), reuse (one damage system handles all entities), and parallelism (systems that don't share data run concurrently).

"When is a component too small?" When splitting it forces systems to always query both halves together. If every system that reads `HealthCurrent` also reads `HealthMax`, they should be one `Health` component. The test: do any systems need one without the other?

"Why wrap external concerns in Resources?" Same reason as OOP dependency injection: testability. A system calling `Instant::now()` directly cannot be tested with controlled time. A system reading `Res<Clock>` can be tested by inserting a fake clock into the World.

"Why prefer events over mutable shared resources for communication?" `ResMut<T>` requires exclusive access, preventing any other system from reading or writing that resource concurrently. Events are buffered and don't block parallel execution. Events also make the communication explicit - you can see what's sent and who reads it.

## Pushback
This rule assumes that fine-grained data design is worth the cost of more types and more query parameters. You might prefer larger components for simplicity in small games. You might skip bundles when spawning is infrequent and the component list is short. The principle applies once you have enough entities and systems that parallelism matters and query clarity affects readability.
