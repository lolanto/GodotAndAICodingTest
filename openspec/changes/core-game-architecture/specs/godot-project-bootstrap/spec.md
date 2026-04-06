## MODIFIED Requirements

### Requirement: Multiple Autoloads registered in dependency order

The `project.godot` SHALL register Autoload singletons in the following order: `Bootstrap` first, then `GravityManager`, then `TimeManager`, then `ZoneManager`. Each Autoload SHALL have a single, well-defined responsibility. The order SHALL guarantee that GravityManager and TimeManager are initialized before any game scene node `_ready()` executes, and that TimeManager is initialized after GravityManager (as TimeManager reads `GravityManager._zero_g_bonus_active` during CE tick).

#### Scenario: Bootstrap initializes first

- **WHEN** the engine starts
- **THEN** `Bootstrap._ready()` SHALL be called before `_ready()` of any game scene node

#### Scenario: GravityManager initializes before TimeManager

- **WHEN** the engine starts
- **THEN** `GravityManager._ready()` SHALL complete before `TimeManager._ready()` begins, ensuring TimeManager can safely reference GravityManager at startup

#### Scenario: All four Autoloads accessible globally

- **WHEN** any GDScript accesses `GravityManager`, `TimeManager`, `ZoneManager`, or `Bootstrap` by name
- **THEN** the access SHALL succeed without null reference, as all four are registered in `project.godot` and injected into the scene tree root by Godot's Autoload mechanism
