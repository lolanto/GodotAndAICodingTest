# Change Proposal: init-godot-project

## Why

GravityRush 目前只有文档与目录骨架，尚无任何可运行的 Godot 工程文件。需要搭建一个最小化的初始工程，验证引擎能够顺利启动并执行脚本，为后续所有功能开发奠定基础。

## What Changes

- **新建** `Game/` 子目录作为 Godot 项目根，将游戏文件与文档/工具目录完全隔离
- **新建** `Game/project.godot` — Godot 项目配置，注册 Autoload 单例与主场景
- **新建** `Game/Scripts/bootstrap.gd` — Autoload 单例，在引擎启动阶段打印 `Hello GravityRush`
- **新建** `Game/Scenes/Main.tscn` — 最小主场景（空 Node）
- **迁移** 根目录下现有的 `Scripts/` 和 `Resources/` 空目录至 `Game/` 内部
- **更新** `AGENTS.md` 中的目录结构说明，补充 `Game/` 层级

## Capabilities

### New Capabilities

- **godot-project-bootstrap** — 可运行的 Godot 4 最小工程，引擎启动时通过 Autoload 输出启动确认信息

### Modified Capabilities

（无）

## Impact

- 所有后续的 GDScript 脚本均应放置于 `Game/Scripts/` 下
- 所有游戏资源均应放置于 `Game/Resources/` 下
- 所有场景文件均应放置于 `Game/Scenes/` 下
- `AGENTS.md` 中的路径约定需同步更新
- 不影响 `Documents/`、`Engine/`、`openspec/` 等非游戏目录
