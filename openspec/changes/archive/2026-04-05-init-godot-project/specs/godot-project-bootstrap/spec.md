## ADDED Requirements

### Requirement: Godot project structure under Game/ directory
The system SHALL use `Game/` as the Godot project root. The `project.godot` file SHALL reside at `Game/project.godot`. Game scripts SHALL be placed under `Game/Scripts/`, game scenes under `Game/Scenes/`, and game resources under `Game/Resources/`. Non-game directories (`Documents/`, `Engine/`, `openspec/`) SHALL remain outside the Godot project root and SHALL NOT appear in the Godot editor file system view.

#### Scenario: Editor file system view is clean
- **WHEN** the Godot editor is opened with `--path Game/`
- **THEN** the editor file system panel SHALL only show `Scripts/`, `Scenes/`, `Resources/` and other game-relevant directories, with no `Documents/`, `Engine/`, or `openspec/` directories visible

#### Scenario: Project loads from Game/ path
- **WHEN** the Godot binary is invoked with `--path Game/`
- **THEN** the engine SHALL locate `Game/project.godot` and load the project successfully

---

### Requirement: Bootstrap Autoload prints startup confirmation
The system SHALL register a GDScript Autoload singleton named `Bootstrap` (at `Game/Scripts/Bootstrap.gd`). During engine startup, `Bootstrap._ready()` SHALL execute before the main scene and SHALL print exactly the following string to the console:

```
[Bootstrap] Hello GravityRush - Engine started successfully
```

#### Scenario: Startup message appears before main scene
- **WHEN** the game is launched via `./run.sh` or directly with Godot CLI
- **THEN** the console SHALL output `[Bootstrap] Hello GravityRush - Engine started successfully` before any output from the main scene

#### Scenario: Bootstrap does not hold game state
- **WHEN** any game script accesses the `Bootstrap` singleton
- **THEN** Bootstrap SHALL expose no game state (no gravity data, no time data, no player data)

---

### Requirement: Multiple Autoloads registered in dependency order
The `project.godot` SHALL register Autoload singletons in the following order: `Bootstrap` first. Future singletons (`GravitySystem`, `TimeSystem`, etc.) SHALL be appended after `Bootstrap`. Each Autoload SHALL have a single, well-defined responsibility.

#### Scenario: Bootstrap initializes first
- **WHEN** the engine starts
- **THEN** `Bootstrap._ready()` SHALL be called before `_ready()` of any game scene node

---

### Requirement: Log messages use [ModuleName] prefix format
All Autoload singletons and system-level scripts SHALL format their log output as `[ModuleName] message`. The module name SHALL match the singleton or class name exactly.

#### Scenario: Log output is consistently prefixed
- **WHEN** any Autoload singleton prints a log message
- **THEN** the message SHALL begin with `[ModuleName]` where `ModuleName` is the exact name of that singleton

---

### Requirement: run.sh script enables quick project launch on macOS
A shell script `run.sh` SHALL exist at the workspace root (`GravityRush/run.sh`). It SHALL be executable (`chmod +x`). It SHALL support two modes:
- Invoked without arguments: launches the game directly (no editor window)
- Invoked with `--editor` argument: opens the Godot editor

The script SHALL be macOS-only in its current form, using `Engine/Godot.app/Contents/MacOS/Godot` as the binary path.

#### Scenario: Run game without editor
- **WHEN** the user executes `./run.sh` from the workspace root
- **THEN** Godot SHALL launch the project at `Game/` in game-run mode (no editor UI)

#### Scenario: Open editor
- **WHEN** the user executes `./run.sh --editor` from the workspace root
- **THEN** Godot SHALL open the project at `Game/` in editor mode

#### Scenario: Script is executable
- **WHEN** the repository is cloned on macOS
- **THEN** `run.sh` SHALL have executable permission (`-rwxr-xr-x` or equivalent)
