# Naming and Clarity

## Concept
The intent of logic is easier to understand when it has a name. In ECS, this applies to system functions, components, resources, events, query filters, and helper functions. Names should communicate game domain concepts, not ECS mechanics. When code appears inline without a name describing its purpose, readers must mentally parse the mechanics to infer the intent.

## Implementation
- Name systems for what they do in game terms:
    - `apply_gravity`, `check_collisions`, `spawn_enemies` - clear domain actions
    - Not `system_1`, `update`, `process` - meaningless without context
- Name components for what they represent in the game:
    - `Health`, `Velocity`, `Inventory`, `PlayerTag` - domain concepts
    - Not `Data`, `Info`, `Component1` - implementation artifacts
- Name events for what happened:
    - `EnemyDefeated`, `ItemCollected`, `LevelCompleted` - past tense, domain events
    - Not `DoAttack`, `ProcessItem` - imperative commands leak implementation
- Name resources for what state they hold:
    - `GameScore`, `WaveTimer`, `DifficultySettings` - clear ownership
    - Not `GlobalState`, `Misc`, `GameData` - vague catch-alls
- No unnamed magic values:
    - `let gravity = Vec3::new(0.0, -9.81, 0.0);` not `Vec3::new(0.0, -9.81, 0.0)` inline
    - `const MAX_ENEMIES: usize = 50;` not `50` in a comparison
    - `let spawn_interval = Duration::from_secs(3);` not `3.0` in a timer
- No expressions with operators in function arguments:
    - `let spawn_position = base + offset;` then `commands.spawn(... spawn_position ...)`
    - Not `commands.spawn(... base + offset ...)`
- Extract complex query filters:
    - Name type aliases for complex queries: `type ActiveEnemies<'w, 's> = Query<'w, 's, (&'static Transform, &'static Health), (With<Enemy>, Without<Dead>)>;`
    - Or use descriptive variable names after querying
- Comments explain why, not what:
    - Use a named function instead of a comment explaining what code does
    - Comments for external references (game design document, algorithm source) remain valuable
    - `// Using Verlet integration for stability` - explains why this algorithm, good
    - `// subtract health` above `health.current -= damage` - restates code, bad

## Rust-Specific Naming Conventions

Follow Rust community conventions:
- **Types**: `PascalCase` - `PlayerHealth`, `DamageEvent`, `CombatPlugin`
- **Functions/systems**: `snake_case` - `apply_damage`, `spawn_player`, `update_score`
- **Constants**: `SCREAMING_SNAKE_CASE` - `MAX_HEALTH`, `GRAVITY`, `TILE_SIZE`
- **Modules**: `snake_case` - `combat`, `movement`, `ui`
- **Marker components**: suffix with descriptive noun - `Player`, `Enemy`, `Projectile` (not `IsPlayer`, `EnemyMarker`)
- **System sets**: `PascalCase` matching the phase - `CombatSet`, `MovementSet`, `PhysicsSet`

## Examples

### Violation: unnamed inline values
```rust
fn spawn_enemy(mut commands: Commands) {
    commands.spawn((
        Transform::from_xyz(100.0 + rand::random::<f32>() * 500.0, 0.0, 0.0),
        Health { current: 50.0, max: 50.0 },
        Velocity(Vec2::new(-2.0, 0.0)),
        Enemy,
    ));
}
```

What is 100.0? 500.0? 50.0? -2.0?

### Fix: named values
```rust
fn spawn_enemy(mut commands: Commands) {
    let spawn_x_min = 100.0;
    let spawn_x_range = 500.0;
    let spawn_x = spawn_x_min + rand::random::<f32>() * spawn_x_range;
    let spawn_position = Transform::from_xyz(spawn_x, 0.0, 0.0);
    let starting_health = 50.0;
    let patrol_speed = Vec2::new(-2.0, 0.0);

    commands.spawn((
        spawn_position,
        Health { current: starting_health, max: starting_health },
        Velocity(patrol_speed),
        Enemy,
    ));
}
```

### Acceptable: simple trailing closures
```rust
// Simple filter predicates are readable inline
let alive_enemies: Vec<_> = enemies.iter()
    .filter(|(_, health)| health.current > 0.0)
    .collect();
```

### Acceptable: obvious zero/unit values
```rust
let origin = Transform::from_xyz(0.0, 0.0, 0.0);
```

Zero as origin is universally understood and doesn't need a named constant.

## Rationale
"Doesn't extracting everything create clutter?" Only if you extract values where the mechanics ARE the intent. `Transform::from_xyz(0.0, 0.0, 0.0)` is clear - it's the origin. But `Transform::from_xyz(100.0, 50.0, 0.0)` is unclear - why those numbers? Name them: `let ui_panel_position = Transform::from_xyz(...)`.

"What about performance-critical inner loops?" Named variables in Rust have zero runtime cost - the compiler optimizes them away. Naming is purely for human readers. There is no performance reason to avoid named locals.

"Why name query type aliases?" Complex Bevy queries like `Query<(&Transform, &Health, &mut Velocity), (With<Enemy>, Without<Dead>, Without<Stunned>)>` are hard to parse at a glance. A type alias `ActiveEnemyMotion` communicates the intent. However, simple queries like `Query<&Transform>` don't need aliases.

"Why past tense for events?" Events represent things that have happened: `EnemyDefeated`, `ItemCollected`. Imperative names like `DefeatEnemy` suggest a command, which misleads readers into thinking the event causes the action rather than reporting it.

## Pushback
This rule assumes that explicit naming is worth the verbosity. You might reject this for rapid prototyping or game jams where speed matters more than clarity. You might disagree that magic numbers need names when you're the only developer and you know what they mean. The principle applies once you or someone else needs to read the code later and understand the game design decisions embedded in the values.
