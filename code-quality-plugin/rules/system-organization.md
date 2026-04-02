# System Organization

## Concept
Systems must execute in a deterministic, understandable order. When system ordering is implicit (depending on registration sequence), behavior changes when you refactor plugin setup. When systems that must run in sequence have no explicit ordering constraints, frame-to-frame inconsistencies appear as subtle, hard-to-reproduce bugs. Explicit ordering makes the execution flow visible and maintainable.

## Implementation
- Use system sets to group related systems:
    - Define sets per gameplay phase: `CombatSet`, `MovementSet`, `PhysicsSet`
    - Configure set ordering: `CombatSet.before(DeathCleanupSet)`
    - Individual systems within a set run in parallel unless further constrained
- Use explicit ordering when systems have data dependencies:
    - `.before()` and `.after()` for direct ordering
    - System sets for phase-level ordering
    - Schedules for lifecycle-level separation (Startup, Update, FixedUpdate)
- Choose the right schedule:
    - `Startup` - runs once at launch (load assets, spawn initial entities, insert resources)
    - `Update` - runs every frame (input handling, UI updates, rendering prep)
    - `FixedUpdate` - runs at fixed time steps (physics, game logic that needs deterministic timing)
    - `OnEnter(State)` / `OnExit(State)` - runs on state transitions (level loading, menu setup)
- Use run conditions for conditional execution:
    - `.run_if(in_state(GameState::Playing))` - only run during gameplay
    - `.run_if(resource_exists::<Configuration>)` - only run after initialization
    - Custom conditions: `.run_if(enemies_remaining)` where `fn enemies_remaining(query: Query<&Enemy>) -> bool { !query.is_empty() }`
- Keep system functions focused:
    - One system, one responsibility
    - If a system needs ordering constraints with many other systems, it may be doing too much
    - Split systems that serve multiple ordering relationships

## System Sets

```rust
#[derive(SystemSet, Debug, Clone, PartialEq, Eq, Hash)]
enum GameSet {
    Input,
    Movement,
    Combat,
    Physics,
    Cleanup,
    Render,
}

app.configure_sets(Update, (
    GameSet::Input,
    GameSet::Movement.after(GameSet::Input),
    GameSet::Combat.after(GameSet::Movement),
    GameSet::Physics.after(GameSet::Combat),
    GameSet::Cleanup.after(GameSet::Physics),
    GameSet::Render.after(GameSet::Cleanup),
));

app.add_systems(Update, (
    read_keyboard_input.in_set(GameSet::Input),
    move_player.in_set(GameSet::Movement),
    move_enemies.in_set(GameSet::Movement),
    check_attacks.in_set(GameSet::Combat),
    apply_gravity.in_set(GameSet::Physics),
    despawn_dead_entities.in_set(GameSet::Cleanup),
    update_health_bars.in_set(GameSet::Render),
));
```

Systems within the same set (like `move_player` and `move_enemies`) can run in parallel because they don't conflict. Systems in different sets run in the declared order.

## When Ordering Matters

| Scenario | Required Ordering | Why |
|----------|------------------|-----|
| Input → Movement | Input before Movement | Movement reads input state set by input system |
| Movement → Collision | Movement before Collision | Collision detects overlaps after positions update |
| Damage → Death check | Damage before Death | Death check reads health modified by damage |
| Spawn → Initialize | Spawn before Initialize | Initialization needs entities to exist |
| Any → Cleanup | Cleanup last | Despawning entities must happen after all systems read them |

## When Ordering Doesn't Matter

- Independent visual effects (particles, screen shake, UI animations)
- Logging / diagnostic systems that only read state
- Systems that write to different components with no shared readers
- Audio systems that react to events

Don't over-constrain. Unnecessary ordering prevents Bevy from parallelizing systems.

## States for Game Phases

```rust
#[derive(States, Debug, Clone, PartialEq, Eq, Hash, Default)]
enum GameState {
    #[default]
    Loading,
    MainMenu,
    Playing,
    Paused,
    GameOver,
}

app
    .init_state::<GameState>()
    .add_systems(OnEnter(GameState::Loading), start_asset_loading)
    .add_systems(OnEnter(GameState::Playing), spawn_level)
    .add_systems(OnExit(GameState::Playing), despawn_level)
    .add_systems(Update, gameplay_systems.run_if(in_state(GameState::Playing)))
    .add_systems(Update, pause_menu_systems.run_if(in_state(GameState::Paused)));
```

States replace the staged dependency injection pattern. Loading state initializes resources. Playing state runs gameplay. Transitions are explicit and observable.

## Rationale
"Why not let Bevy figure out the order?" Bevy parallelizes systems that don't conflict. But "don't conflict" means no overlapping mutable access, not "logically independent." Two systems might not conflict at the type level but have a logical dependency (movement must happen before collision detection). Without explicit ordering, which runs first is non-deterministic.

"Why system sets instead of individual .before()/.after()?" Individual ordering creates a web of pairwise constraints that's hard to visualize. System sets create named phases that communicate the overall execution architecture. "Combat happens after Movement" is clearer than 15 individual before/after constraints between systems.

"Doesn't explicit ordering prevent parallelism?" Only between ordered groups. Systems within the same set still run in parallel. The goal is to constrain where necessary (logical dependencies) and leave unconstrained where possible (independent work).

"When should I use FixedUpdate vs Update?" FixedUpdate runs at a fixed time step regardless of frame rate. Use it for physics and game logic where consistent timing matters (movement, collision, simulation). Use Update for frame-rate-dependent work (input reading, UI updates, camera smoothing, rendering preparation).

"How many system sets is too many?" If every system has its own set, you've over-constrained. If one set has 30 systems that need internal ordering, it's too coarse. Aim for sets that represent logical phases of your game loop (input, simulation, rendering) with systems within each set running in parallel.

## Pushback
This rule assumes that explicit ordering is worth the configuration overhead. You might skip this for very simple games where all systems are independent. You might prefer implicit ordering if your systems truly have no logical dependencies. The principle applies once you encounter a bug that only reproduces under specific system execution orders - at that point, explicit ordering becomes essential.
