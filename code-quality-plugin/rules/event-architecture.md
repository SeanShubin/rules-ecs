# Event Architecture

## Concept
Events are the primary decoupling mechanism in Bevy. When one gameplay domain needs to trigger behavior in another, it sends a typed event rather than directly mutating the other domain's state. Events make cross-domain communication explicit, testable, and extensible. Adding a new response to a game action should require adding a new event reader, not modifying the system that initiated the action.

## Implementation
- Use Bevy's typed event system for cross-domain communication:
    - Define event structs with structured data: `struct DamageEvent { target: Entity, amount: f32, source: DamageSource }`
    - Send events with `EventWriter<T>`: `damage_events.send(DamageEvent { ... })`
    - Receive events with `EventReader<T>`: `for event in damage_events.read() { ... }`
    - Register events in the App: `.add_event::<DamageEvent>()`
- Events carry structured data, not formatted strings:
    - Include entity references, enum variants, and domain values
    - The event producer should not decide how the data is used
    - Different consumers handle the same event differently (audio plays sound, UI shows text, analytics records stat)
- Events flow in one direction:
    - A `CombatPlugin` sends `DamageEvent`; a `HealthPlugin` reads it and applies damage; an `AudioPlugin` reads it and plays a sound
    - No return values from events - if a response is needed, the consumer sends a different event
    - This prevents implicit coupling between producer and consumer
- Events for observability (logging, metrics, debugging):
    - Gameplay-significant events (damage dealt, item picked up, level completed) should be event types
    - A diagnostic system can subscribe to events for logging without the gameplay systems knowing
    - This replaces the OOP pattern of injected notification interfaces
- Within a single plugin, direct component mutation is fine:
    - Events are for cross-domain communication
    - A combat system that reads `Attack` components and writes `Health` components within the combat domain doesn't need events
    - Use events when the producer and consumer are in different plugins

## When to Use Events vs Direct Access

| Scenario | Mechanism | Rationale |
|----------|-----------|-----------|
| System modifies components it owns | Direct `Query<&mut T>` | Same domain, same plugin |
| System triggers behavior in another domain | `EventWriter<T>` | Cross-domain decoupling |
| System needs to spawn/despawn entities | `Commands` | Deferred mutation |
| System needs to notify multiple listeners | `EventWriter<T>` | Multiple readers subscribe independently |
| System reads shared game state | `Res<T>` | Read-only shared state |
| Frame-critical communication | Direct `Query` | Events have one-frame delay |

## Event Design

Events should be:
- **Named for what happened**, not what should happen next: `EnemyDefeated`, not `PlayDeathAnimation`
- **Domain-typed**: Use enums and structs, not strings: `DamageSource::Fire`, not `"fire"`
- **Self-contained**: Include enough data for consumers to act without querying: include the damage amount, don't make the consumer look it up
- **Focused**: One event per distinct game action, not a generic `GameEvent { kind: String, data: HashMap }`

```rust
// Good: structured, focused, domain-typed
#[derive(Event)]
struct ProjectileHitEvent {
    projectile: Entity,
    target: Entity,
    damage: f32,
    damage_type: DamageType,
    hit_position: Vec3,
}

// Bad: generic, stringly-typed
#[derive(Event)]
struct GameEvent {
    kind: String,
    data: HashMap<String, String>,
}
```

## Event Timing

Bevy events persist for two frames (current frame and next frame), then are dropped. This means:
- Events sent in one system are available to readers in the same frame (if ordered after the sender) or the next frame
- System ordering matters for same-frame event processing: use `.after()` or system sets
- If an event must be processed in the same frame it's sent, ensure explicit ordering
- If timing doesn't matter (audio, particles, logging), ordering is less critical

## Rationale
"Why not just have systems directly modify each other's components?" Direct cross-domain mutation creates invisible coupling. When `CombatSystem` directly modifies `Health` components, adding a damage resistance system requires modifying `CombatSystem`. When `CombatSystem` sends a `DamageEvent` instead, a `DamageResistanceSystem` can intercept and modify the damage independently.

"Why not use a generic event type with dynamic data?" Structured event types enable compile-time checking. If `DamageEvent` requires a `target: Entity`, every sender must provide one. With `HashMap<String, String>`, missing fields become runtime errors. Typed events also enable Bevy's scheduler to track data flow and parallelize correctly.

"When are events overkill?" Within a single domain where systems share the same components and the same reason to change, direct mutation is simpler and has no frame-delay consideration. Events add value at domain boundaries, not within them.

"What about events for debugging/logging?" This is where ECS events elegantly replace the OOP injected notification pattern. Define gameplay events for significant actions. A diagnostic plugin subscribes to these events and logs them. The gameplay systems never know about logging - they just emit domain events. This provides the same testability benefit as injected event interfaces in OOP.

"What about performance? Are events expensive?" Bevy events are efficiently buffered. For most games, event overhead is negligible compared to rendering and physics. Profile before optimizing. If a specific high-frequency event (e.g., per-particle) becomes a bottleneck, consider direct mutation for that case specifically.

## Pushback
This rule assumes that explicit cross-domain communication is worth the overhead of defining event types. You might reject this for very small games where all systems share the same small set of components. You might prefer direct mutation for performance-critical paths where the one-frame event delay is unacceptable. The principle applies once the codebase has multiple gameplay domains that evolve independently.
