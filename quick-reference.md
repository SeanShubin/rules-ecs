# Quick Reference: Is This A Violation?

Fast lookup guide for ECS (examples use Rust/Bevy). For details, see the full rules.

## Always Violations (Fix Immediately)

| Pattern | Example | Fix |
|---------|---------|-----|
| Intra-crate module cycle | `combat` uses `inventory`, `inventory` uses `combat` | Extract shared types to sibling module or use events |
| Hidden system dependencies | System reads global mutable static | Declare as system parameter; wrap in Resource |
| Cross-domain direct mutation | Combat system writes to UI component | Use events |
| Scattered feature changes | New enemy requires changes in 5 unrelated plugins | Improve plugin cohesion |

## Usually Violations (Fix When Opportune)

| Pattern | Test | Fix |
|---------|------|-----|
| God resource (10+ fields) | Do unrelated systems access it? | Split into focused resources |
| God component (8+ fields) | Do systems only need some fields? | Split into focused components |
| Long system mixing levels | Does it mix game logic with math? | Extract calculations to helpers |
| Implicit system ordering | Could reordering cause bugs? | Add `.before()`/`.after()` or system sets |
| Large plugin (20+ systems) | Do unrelated features touch it? | Split by domain |
| Vertical module dependency | Does `mod.rs` contain logic? | Move logic to leaf modules |

## Acceptable Patterns (Not Violations)

| Pattern | Why Acceptable |
|---------|---------------|
| Free-standing system functions | Required by Bevy's scheduler |
| Concrete types in queries | Components are data, not behavioral abstractions |
| `Res<Time>` and other global resources | Declared in system signature = explicit dependency |
| No constructor injection | System parameters ARE dependency declarations |
| Components without methods | Data/behavior separation is intentional in ECS |
| One-direction events (no return) | ECS event design; consumer sends different event if needed |
| Direct mutation within a domain | Events are for cross-domain, not intra-domain |
| Simple inline filter closures | `.filter(\|(_, h)\| h.current > 0.0)` is readable |
| Marker components with no fields | `struct Player;` enables `With<Player>` queries |

## Quick Decision Tree

```
Module cycle? → Fix immediately
Hidden state? → Wrap in Resource, declare as parameter
Scattered changes? → Improve plugin cohesion
Cross-domain mutation? → Use events
Mixing abstraction levels? → Extract helpers
God resource/component? → Split
Unnamed magic numbers? → Name them
Follows Bevy idioms? → Acceptable
```

## Crate vs Module

| Concern | Crate Boundary | Module Boundary |
|---------|---------------|-----------------|
| Cycles | Impossible (compiler) | Possible, must prevent |
| Purpose | Architectural separation | Organizational navigation |
| Strictness | Enforced by Cargo | Enforced by convention + tooling |
| When to split | Reusable library, enforced deps | Large module, mixed concerns |

## Priority Order

1. **Coupling and Cohesion** - Localize changes to plugins
2. **System Dependencies** - Declare everything in parameters
3. **Event Architecture** - Explicit cross-domain communication
4. **Abstraction Levels** - Separate orchestration from mechanics
5. **Module Hierarchy** - No cycles, domain-first
6. **System Organization** - Explicit ordering
7. **Naming and Clarity** - Meaningful names
8. **Component and Resource Design** - Focused data types

## Common False Alarms

### "Free-floating functions" - NOT a violation
```rust
// This is correct Bevy. Systems MUST be free functions.
fn move_player(
    mut query: Query<&mut Transform, With<Player>>,
    input: Res<ButtonInput<KeyCode>>,
    time: Res<Time>,
) { /* ... */ }
```

### "No dependency injection" - NOT a violation
```rust
// System parameters ARE dependency declaration.
// The scheduler IS the injector.
fn apply_damage(
    mut health_query: Query<&mut Health>,
    mut damage_events: EventReader<DamageEvent>,
) { /* ... */ }
```

### "Concrete types everywhere" - NOT a violation
```rust
// Components are data. No interface abstraction needed.
Query<(&Transform, &Health, &Velocity), With<Enemy>>
```

### "Anemic components" - NOT a violation
```rust
// Components hold data. Systems provide behavior. This is correct ECS.
#[derive(Component)]
struct Health {
    current: f32,
    max: f32,
}
```

## Do NOT Apply These OOP Rules

These rules from the OOP rule set do not apply to ECS code:

| OOP Rule | Why It Doesn't Apply |
|----------|---------------------|
| Constructor injection | ECS has no constructors; system params declare deps |
| Free-floating functions | Systems must be free functions |
| Language separation (HTML/CSS/SQL) | Not relevant in pure Rust game dev |
| Staged dependency injection | Bevy States and startup systems handle initialization |
| Interface-based abstractions | Components are data; trait objects are rare in ECS |
| Composition root purity checklist | App builder serves this role differently |

**When in doubt: is this an ECS pattern or an OOP habit?**
