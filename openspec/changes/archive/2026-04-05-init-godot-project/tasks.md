# Tasks: init-godot-project

## 1. Project Directory Structure

- [x] 1.1 Create `Game/` directory at workspace root
- [x] 1.2 Create `Game/Scripts/` directory
- [x] 1.3 Create `Game/Scenes/` directory
- [x] 1.4 Create `Game/Resources/` directory
- [x] 1.5 Remove (or leave empty) the root-level `Scripts/` and `Resources/` directories, confirming they are empty before removal

## 2. Bootstrap Autoload Script

- [x] 2.1 Create `Game/Scripts/Bootstrap.gd` as a GDScript file extending `Node`
- [x] 2.2 Implement `_ready()` to print `[Bootstrap] Hello GravityRush - Engine started successfully`
- [x] 2.3 Verify Bootstrap holds no game state (no exported variables for gravity, time, or player data)

## 3. Main Scene

- [x] 3.1 Create `Game/Scenes/Main.tscn` as a minimal scene with a single root `Node`
- [x] 3.2 Verify the scene has no attached script

## 4. Godot Project Configuration

- [x] 4.1 Create `Game/project.godot` with correct Godot 4 format header (`godot-resource-header`)
- [x] 4.2 Set `application/run/main_scene` to `res://Scenes/Main.tscn`
- [x] 4.3 Register `Bootstrap` as the first Autoload singleton pointing to `res://Scripts/Bootstrap.gd`
- [x] 4.4 Verify no other Autoloads are registered at this stage

## 5. Launch Script

- [x] 5.1 Create `run.sh` at workspace root (`GravityRush/run.sh`)
- [x] 5.2 Add macOS platform note comment at the top of `run.sh`
- [x] 5.3 Implement `--editor` argument branch: invoke Godot with `-e --path Game/`
- [x] 5.4 Implement default (no argument) branch: invoke Godot with `--path Game/` (game-run mode)
- [x] 5.5 Run `chmod +x run.sh` to make the script executable

## 6. Documentation Update

- [x] 6.1 Update `AGENTS.md` directory structure section to include `Game/` layer with `project.godot`, `Scripts/`, `Scenes/`, `Resources/` sub-entries
- [x] 6.2 Update `AGENTS.md` script path conventions to reflect `Game/Scripts/` as the canonical location

## 7. Verification

- [x] 7.1 Run `./run.sh` and confirm the console outputs `[Bootstrap] Hello GravityRush - Engine started successfully`
- [x] 7.2 Run `./run.sh --editor` and confirm the Godot editor opens with the project loaded
- [x] 7.3 Confirm the Godot editor file system panel shows only game directories (no `Documents/`, `Engine/`, `openspec/`)
