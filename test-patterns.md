# Test Patterns for ECS

## Concept
Tests should verify system behavior in isolation using a minimal World containing only the components, resources, and entities the system needs. ECS infrastructure (World setup, Schedule creation, query execution) should be hidden behind domain-focused test helpers, following the same principle as the Test Orchestrator pattern: tests read like game specifications, not ECS plumbing.

## The Pattern

### Structure

1. **Create a test helper** (Tester struct or module) that:
    - Constructs a minimal World with controlled state
    - Hides Schedule creation, system registration, and World mutation
    - Exposes **setup methods** for configuring game state (spawn entities, insert resources)
    - Exposes **action methods** for running systems (tick the world, simulate a frame)
    - Exposes **query methods** for making assertions (read component values, count entities)
2. **Tests use the helper** in given-when-then style
3. **Tests read as game behavior descriptions**, not ECS API calls

### Benefits

- **Tests are readable:** Domain language, not ECS mechanics
- **Tests are resilient:** Bevy API changes only affect the test helper, not every test
- **Tests are maintainable:** Common setup in one place
- **Tests document behavior:** Reading tests shows what the game does

## Example: Direct World Testing

For simple cases, direct World manipulation is acceptable:

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use bevy::prelude::*;

    #[test]
    fn gravity_decreases_vertical_velocity() {
        // given
        let mut world = World::new();
        let gravity = Gravity(Vec2::new(0.0, -9.81));
        world.insert_resource(gravity);
        world.insert_resource(Time::default());
        let entity = world.spawn((
            Velocity(Vec2::new(5.0, 10.0)),
        )).id();

        // when
        let mut schedule = Schedule::default();
        schedule.add_systems(apply_gravity);
        schedule.run(&mut world);

        // then
        let velocity = world.get::<Velocity>(entity).unwrap();
        assert!(velocity.0.y < 10.0, "Gravity should reduce vertical velocity");
    }
}
```

## Example: Test Helper for Complex Scenarios

```rust
#[cfg(test)]
mod tests {
    use super::*;

    struct CombatTester {
        world: World,
        schedule: Schedule,
    }

    impl CombatTester {
        fn new() -> Self {
            let mut world = World::new();
            world.init_resource::<Events<DamageEvent>>();
            world.init_resource::<Events<DeathEvent>>();

            let mut schedule = Schedule::default();
            schedule.add_systems((apply_damage, check_death).chain());

            CombatTester { world, schedule }
        }

        fn spawn_entity_with_health(&mut self, health: f32) -> Entity {
            self.world.spawn(Health { current: health, max: health }).id()
        }

        fn spawn_entity_with_health_and_armor(&mut self, health: f32, armor: f32) -> Entity {
            self.world.spawn((
                Health { current: health, max: health },
                Armor { rating: armor },
            )).id()
        }

        fn send_damage(&mut self, target: Entity, amount: f32) {
            self.world.send_event(DamageEvent {
                target,
                amount,
                damage_type: DamageType::Physical,
            });
        }

        fn tick(&mut self) {
            self.schedule.run(&mut self.world);
        }

        fn health_of(&self, entity: Entity) -> f32 {
            self.world.get::<Health>(entity).unwrap().current
        }

        fn is_alive(&self, entity: Entity) -> bool {
            self.world.get::<Health>(entity)
                .map(|h| h.current > 0.0)
                .unwrap_or(false)
        }

        fn death_events(&self) -> Vec<DeathEvent> {
            let events = self.world.resource::<Events<DeathEvent>>();
            let mut reader = events.get_cursor();
            reader.read(events).cloned().collect()
        }
    }

    #[test]
    fn damage_reduces_health() {
        // given
        let mut tester = CombatTester::new();
        let entity = tester.spawn_entity_with_health(100.0);

        // when
        tester.send_damage(entity, 30.0);
        tester.tick();

        // then
        assert_eq!(tester.health_of(entity), 70.0);
    }

    #[test]
    fn lethal_damage_triggers_death_event() {
        // given
        let mut tester = CombatTester::new();
        let entity = tester.spawn_entity_with_health(20.0);

        // when
        tester.send_damage(entity, 50.0);
        tester.tick();

        // then
        let deaths = tester.death_events();
        assert_eq!(deaths.len(), 1);
        assert_eq!(deaths[0].entity, entity);
    }

    #[test]
    fn zero_damage_does_not_change_health() {
        // given
        let mut tester = CombatTester::new();
        let entity = tester.spawn_entity_with_health(100.0);

        // when
        tester.send_damage(entity, 0.0);
        tester.tick();

        // then
        assert_eq!(tester.health_of(entity), 100.0);
    }
}
```

**What the Tester hides:**
- World creation and resource initialization
- Schedule creation and system registration
- Event system setup
- Component querying mechanics

**What tests see:**
- `spawn_entity_with_health(100.0)`
- `send_damage(entity, 30.0)`
- `tick()`
- `health_of(entity)`
- `death_events()`

## Testing Pure Functions

Systems often delegate to pure helper functions. Test these directly without ECS infrastructure:

```rust
#[test]
fn damage_calculation_respects_armor() {
    let attack = Attack { power: 50.0, multiplier: 1.0 };
    let armor = Armor { rating: 20.0 };

    let damage = calculate_damage(&attack, &armor);

    assert_eq!(damage, 40.0); // 50 * (1 - 0.2)
}

#[test]
fn damage_cannot_go_negative() {
    let attack = Attack { power: 10.0, multiplier: 1.0 };
    let armor = Armor { rating: 200.0 }; // more armor than damage

    let damage = calculate_damage(&attack, &armor);

    assert!(damage >= 0.0);
}
```

No World, no Schedule, no ECS overhead. This is the benefit of separating abstraction levels - pure calculation functions are trivially testable.

## When to Use Each Approach

| Scenario | Approach |
|----------|----------|
| Pure calculation (damage formula, pathfinding) | Direct function test, no ECS |
| Single system with simple state | Direct World test |
| Multiple interacting systems | Test helper / Tester struct |
| Cross-plugin behavior | Integration test with multiple plugins |
| Visual/rendering behavior | Manual testing or screenshot comparison |

## Testing Resources as Boundaries

```rust
// Production: wraps real time
struct GameClock {
    start: Instant,
}

impl GameClock {
    fn elapsed(&self) -> Duration {
        self.start.elapsed()
    }
}

// Test: controlled time
struct TestClock {
    elapsed: Duration,
}

impl TestClock {
    fn advance(&mut self, duration: Duration) {
        self.elapsed += duration;
    }
}
```

If the system needs time, use a trait or generic approach so both production and test clocks satisfy the same interface. Or use Bevy's built-in `Time` resource, which can be manually advanced in tests.

## Rationale
"Why not just test the whole App?" Integration tests have their place, but they're slow and test everything at once. When a test fails, you don't know which system broke. Unit testing individual systems with minimal Worlds gives fast, focused feedback.

"Why create test helpers instead of inline setup?" The same reason as in OOP: DRY and resilience. If Bevy's event API changes, you update the helper once, not every test. If your component structure changes, setup methods change in one place.

"Why test pure functions separately?" Because you can. Pure functions need no ECS infrastructure, so testing them through a World adds overhead and obscures what's being tested. Test the calculation directly. Test the system's ECS integration separately.

"When are tests not worth writing?" Visual behavior (does the sprite look right?), audio (does the sound play?), and feel (is the movement smooth?) are hard to test automatically. Use manual playtesting for these. Focus automated tests on game logic: health, scoring, state transitions, collision responses.

## Pushback
This rule assumes that testability is worth the effort of creating test helpers. You might skip test infrastructure for game jams or prototypes. You might prefer integration tests if your systems are tightly coupled and unit testing them in isolation doesn't reflect real behavior. The principle applies once you need confidence that game logic is correct and want fast feedback during development.
