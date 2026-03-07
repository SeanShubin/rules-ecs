# Architectural Layers

## Concept
Every game has three fundamental layers: **Input** (what the player does), **Simulation** (what happens in the game world), and **Presentation** (what the player sees and hears). These layers should be separated by explicit protocols — not just plugin boundaries, but contracts that define exactly what data crosses each boundary.

The test: could each layer run in a separate process? You don't need to actually run them separately, but designing as if you might forces the right abstractions. If input, simulation, and presentation could each be a standalone executable communicating over a socket, then the boundaries between them are clean. If they can't, something is leaking across a boundary.

This matters beyond architecture. In ECS, type boundaries are concurrency boundaries (see Component and Resource Design). Layer boundaries are a level above that — they define which entire categories of systems can evolve, test, and scale independently.

### Why Three Layers?
- **Input** changes when you add controller support, remap keys, or add AI players. None of these should touch game logic or rendering.
- **Simulation** changes when you add game mechanics, fix gameplay bugs, or balance difficulty. None of these should touch input handling or rendering.
- **Presentation** changes when you upgrade from 2D to 3D, add particle effects, or change art style. None of these should touch input handling or game logic.

If a change in one layer forces changes in another, the layers are coupled.

## Implementation

### The Input Layer
Translates raw input into game actions. Game logic never reads raw input directly.

```rust
// Input domain types — the protocol between input and simulation
#[derive(Event)]
enum PlayerAction {
    Move(Direction),
    Attack,
    UseItem(ItemSlot),
    Interact,
}

#[derive(Clone, Copy)]
enum Direction {
    Up, Down, Left, Right,
}

// Input system — lives in InputPlugin, knows about keyboards and gamepads
fn read_keyboard_input(
    keys: Res<ButtonInput<KeyCode>>,
    mut actions: EventWriter<PlayerAction>,
) {
    if keys.pressed(KeyCode::ArrowUp) {
        actions.send(PlayerAction::Move(Direction::Up));
    }
    if keys.just_pressed(KeyCode::Space) {
        actions.send(PlayerAction::Attack);
    }
}

// A second input source — same protocol, no game logic changes needed
fn read_gamepad_input(
    gamepads: Query<&Gamepad>,
    mut actions: EventWriter<PlayerAction>,
) {
    for gamepad in &gamepads {
        if gamepad.pressed(GamepadButton::South) {
            actions.send(PlayerAction::Attack);
        }
    }
}
```

**Key constraint:** Systems in the simulation layer read `EventReader<PlayerAction>`, never `Res<ButtonInput<KeyCode>>`. The action event is the contract.

### The Simulation Layer
Processes game actions, updates world state. Never references rendering types or raw input types.

```rust
// Simulation system — knows about game rules, not about keyboards or sprites
fn handle_player_movement(
    mut actions: EventReader<PlayerAction>,
    mut query: Query<(&mut Position, &mut Facing, &Speed), With<Player>>,
) {
    for action in actions.read() {
        if let PlayerAction::Move(direction) = action {
            for (mut position, mut facing, speed) in &mut query {
                *facing = Facing::from(*direction);
                position.0 += direction.to_vec2() * speed.0;
            }
        }
    }
}
```

**Key constraint:** Simulation components (`Position`, `Facing`, `Health`, `Inventory`) contain no rendering information. No sprite handles, no mesh references, no colors. These are pure game state.

### The Presentation Layer
Reads game state and renders. Never writes to simulation state.

```rust
// Presentation system — translates game state into visuals
fn sync_sprite_to_position(
    query: Query<(&Position, &mut Transform), Changed<Position>>,
) {
    for (position, mut transform) in &query {
        transform.translation = position.0.extend(0.0);
    }
}

fn update_player_animation(
    query: Query<(&Facing, &PlayerState, &mut Sprite), Changed<Facing>>,
    sprite_sheets: Res<SpriteSheetMap>,
) {
    for (facing, state, mut sprite) in &query {
        sprite.image = sprite_sheets.get(*facing, *state);
    }
}
```

**Key constraint:** Presentation systems read simulation components but never mutate them. If the presentation layer needs to communicate back (e.g., animation finished), it sends an event.

### The Serialization Boundary Test
For each layer boundary, ask: "What would I serialize if this crossed a network socket?"

| Boundary | Protocol | What crosses |
|----------|----------|-------------|
| Input → Simulation | Game actions | `PlayerAction` events (move, attack, use item) |
| Simulation → Presentation | Game state | Positions, facings, health values, animation states |

If you can't clearly define what would cross, the boundary is muddled. If a rendering type appears in the simulation layer, or a raw input type appears in game logic, something is crossing that shouldn't be.

## What This Enables

These separations aren't theoretical — each unlocks concrete capabilities:

- **Input protocol** → Input replay (record actions, play back for testing or demos), AI agents (emit `PlayerAction` events without a keyboard), control remapping (change key bindings without touching game logic)
- **Simulation independence** → Deterministic testing (feed scripted actions, assert world state, no renderer needed), headless server (multiplayer-ready architecture), fixed-timestep simulation (game logic ticks at consistent rate regardless of frame rate)
- **Presentation contract** → Visual style swaps (2D sprites today, 3D models tomorrow, same game), multiple views (minimap, debug overlay, spectator camera all reading the same state), replay visualization (render recorded state without re-simulating)

## Anti-Patterns

### Raw Input in Game Logic
```rust
// Bad: game logic directly reads keyboard state
fn move_player(
    keys: Res<ButtonInput<KeyCode>>,
    mut query: Query<&mut Position, With<Player>>,
) {
    if keys.pressed(KeyCode::ArrowUp) {
        // What about gamepad? What about AI? What about replay?
    }
}
```

Adding gamepad support requires modifying the movement system. Adding an AI player requires faking keyboard input. Adding replay requires recording keyboard state. All of these are symptoms of a missing input protocol.

### Rendering Types in Simulation Components
```rust
// Bad: game component contains rendering data
#[derive(Component)]
struct Enemy {
    health: f32,
    damage: f32,
    sprite: Handle<Image>,      // rendering concern
    animation_timer: Timer,     // rendering concern
}
```

Changing art style requires modifying game logic components. Testing game logic requires loading image assets. The simulation layer can't run headless.

### Game Logic in Presentation Systems
```rust
// Bad: rendering system modifies game state
fn render_health_bar(
    mut query: Query<(&mut Health, &Transform)>,
) {
    for (mut health, transform) in &mut query {
        // Rendering code that also clamps health
        health.current = health.current.clamp(0.0, health.max);
        // ... draw health bar ...
    }
}
```

Health clamping is game logic. It should happen in the simulation layer, not as a side effect of rendering.

## Exceptions

- **Prototyping:** When exploring a mechanic, reading raw input directly is fine. Extract the input protocol once the mechanic is proven. The cost of wrong abstractions during exploration exceeds the cost of a later refactor.

- **Single-concern games:** A pong clone where input is "move paddle up/down" may not benefit from a formal action protocol. Use judgment — if the input mapping is trivial and unlikely to change, inline it.

- **Performance-critical paths:** If translating through an event adds measurable latency for a frame-critical input (e.g., precise timing in a rhythm game), direct access may be justified. Profile first.

- **Bevy's built-in presentation components:** `Transform` is used by both simulation and rendering. This is acceptable — it's Bevy's shared coordinate system. The rule applies to your own game-specific components, not to engine primitives.

## Rationale
"Why not just use plugins for separation?" Plugins provide code organization but don't enforce a protocol. A `RenderPlugin` that directly queries 15 simulation components is organized into a plugin but tightly coupled to simulation internals. The architectural layer concept adds the question: what is the minimal, explicit contract between these layers?

"Isn't this over-engineering for a small game?" The input protocol (action events instead of raw keys) is ~20 lines of code and pays for itself the moment you want remappable controls or a second input method. The simulation/presentation split is more work but prevents the class of bugs where rendering side effects corrupt game state. Both are proportional investments.

"How is this different from Abstraction Levels?" Abstraction Levels separates orchestration from mechanics within a system — high-level coordination vs low-level calculation. Architectural Layers separates entire domains of responsibility — input, game world, and visuals. You can have well-separated abstraction levels within a presentation system that is still wrongly coupled to simulation internals.

"Do I need a formal view model?" Not necessarily. If the presentation layer reads simulation components directly (read-only), that's a lightweight contract. A formal view model (separate components that the simulation layer populates for the presentation layer) is warranted when the visual representation diverges significantly from the simulation state, or when you want the simulation to run without presentation components existing at all.

## Pushback
This rule assumes that layer separation is worth the upfront cost of defining protocols and maintaining the discipline of not reaching across boundaries. You might reject this for game jams or throwaway prototypes. You might find the input protocol unnecessary for a single-input game. The principle applies once you want any of: multiple input sources, deterministic testing, visual style flexibility, or multiplayer readiness. Since these capabilities are difficult to retrofit and easy to design in from the start, the rule favors early adoption over deferred refactoring.
