# System Dependencies

## Concept
Systems declare their dependencies through function parameters. The Bevy scheduler reads these declarations and provides the requested data. This is inversion of control: the system says what it needs, the framework provides it. A system's parameter list is its dependency contract. If a system accesses state not declared in its parameters, it has hidden dependencies that make reasoning and testing impossible.

## Implementation
- Systems declare all dependencies as function parameters:
    - `Query<&Component>` for entity data reads
    - `Query<&mut Component>` for entity data writes
    - `Res<MyResource>` for shared state reads
    - `ResMut<MyResource>` for shared state writes
    - `EventReader<MyEvent>` for receiving events
    - `EventWriter<MyEvent>` for sending events
    - `Commands` for deferred entity/resource mutations
- No hidden state access:
    - No global mutable statics
    - No `unsafe` blocks to access shared state outside the parameter system
    - No thread-local storage for game state
    - No file I/O or network calls within systems without going through a Resource
- Resources are the "injected dependencies" of ECS:
    - Wrap external concerns in Resources: `Res<Clock>`, `Res<AudioOutput>`, `Res<NetworkClient>`
    - For testing, insert different Resource values into the World
    - Resources make external boundaries explicit and swappable
- Components are data, not behavior:
    - Components hold state; systems provide behavior
    - A Component should not contain methods that perform I/O or side effects
    - Components can have helper methods for data access and transformation (pure functions)
- The App builder is the composition root:
    - `App::new()` with `.add_plugins()`, `.add_systems()`, `.insert_resource()` wires everything together
    - Plugin `build()` methods register systems, resources, and events
    - No game logic in the App builder or Plugin build methods - only registration

## Mapping from OOP Dependency Injection

| OOP Concept | ECS Equivalent | Why It Works |
|-------------|---------------|--------------|
| Constructor injection | System function parameters | System declares what it needs; scheduler provides it |
| Interface / trait object | Concrete component/resource types | ECS queries are data access, not behavioral abstraction |
| Composition root | `App::new().add_plugins().add_systems()` | Single place that wires systems to schedules |
| Staged DI | Startup systems → State transitions → Runtime systems | Initialization stages are explicit in schedule configuration |
| Integrations boundary | Resources wrapping external concerns | `Res<Clock>`, `Res<FileSystem>` make boundaries explicit |
| Faking for tests | Insert test Resources into World | `world.insert_resource(TestClock::new())` replaces production resource |

## Why Concrete Types Are Correct

In OOP, you inject interfaces so you can substitute implementations. In ECS, you use concrete types in queries because:

- **Components ARE the interface.** `Query<&Health>` means "give me all Health data." There is no `HealthInterface` because Health is pure data with no behavior to abstract.
- **Resources can use trait objects when needed.** If you need swappable behavior (e.g., different audio backends), `Res<Box<dyn AudioBackend>>` works. But most Resources are concrete because they're configuration or state, not behavior.
- **The substitution point is the World, not the type.** To test differently, you insert different values into the World, not different types into the system signature.

## Startup and Initialization

Bevy handles staging through schedules and states:

```rust
app
    // Startup: runs once at the beginning
    .add_systems(Startup, (
        load_configuration,
        initialize_game_state,
        spawn_initial_entities,
    ))
    // Runtime: runs every frame
    .add_systems(Update, (
        handle_input,
        move_entities,
        check_collisions,
        update_ui,
    ));
```

For multi-stage initialization where later stages depend on earlier results:
- Use startup system ordering: `.add_systems(Startup, (load_config, init_game.after(load_config)))`
- Use States for phase transitions: `OnEnter(GameState::Loading)`, `OnEnter(GameState::Playing)`
- Use run conditions for conditional execution: `.run_if(resource_exists::<Configuration>)`

## Rationale
"Why not abstract components behind traits?" Components are data. You don't abstract data behind interfaces in a relational database - you query concrete tables. ECS components are the same: concrete data types that systems query. Abstracting them adds indirection without benefit because there's no behavior to swap.

"What about testing without real I/O?" Wrap I/O boundaries in Resources. `Res<Clock>` in production wraps `std::time::Instant`. In tests, insert a `Clock` that returns controlled values. The system code is identical - only the Resource value differs. This is the same principle as OOP dependency injection, just expressed through the World instead of constructors.

"Why is the App builder allowed to have no logic?" The App builder IS the composition root. Its job is to wire systems to schedules and register resources. Like OOP composition roots, it should contain only registration, not logic. Plugin `build()` methods should register, not compute.

"What about systems that need configuration?" Insert configuration as a Resource. A system that needs database connection details should declare `Res<DatabaseConfig>`, not read from environment variables. The startup system or App builder inserts the configuration Resource.

"Doesn't declaring everything as parameters get verbose?" Yes, and that's valuable. A system with 8 parameters is telling you it has 8 dependencies. In OOP, a constructor with 8 parameters signals too many responsibilities. The same signal applies here - consider splitting the system.

## Pushback
This rule assumes that explicit dependency declaration is worth the verbosity. You might reject this for rapid prototyping where hidden state access is faster to write. You might disagree if you believe Rust's ownership system provides sufficient safety guarantees without explicit parameter declarations. The principle applies once the codebase needs to be understood and maintained by others (including your future self).
