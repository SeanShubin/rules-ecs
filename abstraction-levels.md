# Abstraction Levels

## Concept
Code at different levels of abstraction should be separated into distinct systems and functions. Higher-level systems orchestrate game state transitions by delegating to lower-level systems or calling helper functions. Mixing orchestration with mechanics makes code harder to understand, because modifications to physics calculations force you to re-read game state coordination logic.

## Implementation
- Separate orchestration from mechanics:
    - High-level systems coordinate game state: "when health reaches zero, trigger death sequence"
    - Low-level systems implement specifics: "apply velocity to transform, accounting for delta time"
    - High-level helper functions coordinate within a system: "resolve this combat encounter"
    - Low-level helper functions implement calculations: "calculate damage after armor reduction"
- Recognize levels through responsibility:
    - **Orchestration systems**: read game state, decide what happens next, send events or issue commands
    - **Mechanical systems**: perform calculations, update component values, apply physics
    - **Utility functions**: pure computations called by systems (damage formulas, pathfinding, collision math)
- At the system level:
    - Each system operates at a consistent abstraction level
    - A system that decides whether an enemy should attack should not also calculate projectile trajectories
    - Split mixed systems into an orchestrating system and a mechanical system
- At the function level:
    - Extract implementation details into named helper functions
    - Keep system functions focused on their ECS interactions (queries, events, commands)
    - Move pure calculations into separate functions that take values and return values

## Examples

### Violation: Orchestration mixed with mechanics
```rust
fn combat_system(
    mut health_query: Query<(&mut Health, &Armor, &Transform)>,
    attack_query: Query<(&Attack, &Transform)>,
    mut commands: Commands,
    mut events: EventWriter<DeathEvent>,
) {
    for (attack, attack_pos) in attack_query.iter() {
        for (mut health, armor, target_pos) in health_query.iter_mut() {
            // LOW-LEVEL: distance calculation
            let dx = attack_pos.translation.x - target_pos.translation.x;
            let dy = attack_pos.translation.y - target_pos.translation.y;
            let distance = (dx * dx + dy * dy).sqrt();

            if distance < attack.range {
                // LOW-LEVEL: damage formula
                let base_damage = attack.power * attack.multiplier;
                let reduction = armor.rating * 0.01;
                let final_damage = base_damage * (1.0 - reduction);

                health.current -= final_damage;

                // HIGH-LEVEL: death check
                if health.current <= 0.0 {
                    events.send(DeathEvent { /* ... */ });
                }
            }
        }
    }
}
```

### Fix: Separated levels
```rust
fn combat_system(
    mut health_query: Query<(Entity, &mut Health, &Armor, &Transform)>,
    attack_query: Query<(&Attack, &Transform)>,
    mut death_events: EventWriter<DeathEvent>,
) {
    for (attack, attack_pos) in attack_query.iter() {
        for (entity, mut health, armor, target_pos) in health_query.iter_mut() {
            if is_in_range(attack_pos, target_pos, attack.range) {
                let damage = calculate_damage(attack, armor);
                health.current -= damage;

                if health.current <= 0.0 {
                    death_events.send(DeathEvent { entity });
                }
            }
        }
    }
}

fn is_in_range(a: &Transform, b: &Transform, range: f32) -> bool {
    a.translation.distance(b.translation) < range
}

fn calculate_damage(attack: &Attack, armor: &Armor) -> f32 {
    let base_damage = attack.power * attack.multiplier;
    let reduction = armor.rating * 0.01;
    base_damage * (1.0 - reduction)
}
```

### Acceptable: Pure computation at one level
```rust
fn calculate_damage(attack: &Attack, armor: &Armor) -> f32 {
    let base_damage = attack.power * attack.multiplier;
    let armor_reduction = armor.rating * ARMOR_REDUCTION_PER_POINT;
    let clamped_reduction = armor_reduction.clamp(0.0, MAX_ARMOR_REDUCTION);
    base_damage * (1.0 - clamped_reduction)
}
```

All calculation logic at the same level. This is fine even though it has multiple steps - they're all damage calculation mechanics.

### Acceptable: System with clear single-level ECS interaction
```rust
fn apply_velocity(mut query: Query<(&mut Transform, &Velocity)>, time: Res<Time>) {
    let dt = time.delta_secs();
    for (mut transform, velocity) in query.iter_mut() {
        transform.translation += velocity.0 * dt;
    }
}
```

Simple enough that extraction would add ceremony without clarity.

## Exceptions

These patterns are NOT violations:

- **Simple systems with straightforward mechanics**: A system that applies velocity to transform is one level of abstraction. Don't extract `multiply_vector_by_scalar()`.

- **Pure helper functions with internal steps**: A damage calculation function that has 5 lines of arithmetic is cohesive at one level. Don't extract each line into its own function.

- **Query iteration with inline filtering**: `for (entity, health) in query.iter().filter(|(_, h)| h.current > 0.0)` is acceptable when the filter is simple and clear from context.

**Test:** Ask "If I extract this, does it reduce complexity or just move it?" If extraction creates a function whose name is just a description of the one line it contains (`fn subtract_health(health: &mut f32, damage: f32) { *health -= damage; }`), leave it inline.

## Rationale
"Why separate levels in ECS?" Consider a system that coordinates an enemy AI behavior tree AND calculates steering vectors AND performs ray casts. If the steering algorithm changes, you must re-read the AI coordination logic. When separated, you change the steering function without touching the AI orchestration.

"How do I know what level something is?" Systems that query game state and make decisions (attack or flee? advance to next level?) are high level. Systems that compute values (apply force, calculate path, interpolate animation) are low level. Functions that do math with no ECS interaction are the lowest level.

"When do I stop extracting?" When further splitting breaks cohesion. A 10-line damage formula at one abstraction level is clear. Extracting each arithmetic step into named functions creates noise, not clarity.

"What about systems that are inherently complex?" Complex at a single level is fine. A pathfinding system with 50 lines of A* implementation is all one level (graph traversal mechanics). The problem is when those 50 lines are interleaved with entity spawning, event sending, and state transitions.

## Pushback
This rule assumes that vertical layering aids understanding more than it costs in indirection. You might reject this if you prefer seeing all code in one place. You might disagree for simple game jam projects where systems are small enough that mixing levels doesn't cause confusion. The principle applies once systems grow complex enough that understanding the high-level flow requires skipping over implementation details.
