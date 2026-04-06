# Change Proposal: core-game-architecture

## Why

GravityRush 的 GDD 已完整定义了重力系统、时间系统与联动机制，但代码层目前几乎空白（仅有 Bootstrap 启动日志）。在推进任何技能测试场景之前，需要先确立：

1. **游戏主循环的执行顺序**：各系统在每一物理帧内的职责边界与调用顺序
2. **代码整体架构模式**：采用 Entity-Component（EC）模式，以 Godot 子节点为 Component 载体
3. **时间回溯的实现方案**：采用帧快照（Frame Snapshot）模式，由每个 Component 自持快照逻辑
4. **技能测试场景的前置依赖**：明确测试场景需要哪些系统处于可运行状态

## What Changes

- **新建** `Game/Scripts/Autoloads/GravityManager.gd` — 全局重力状态管理单例
- **新建** `Game/Scripts/Autoloads/TimeManager.gd` — 时间流速控制 + 帧快照 Ring Buffer
- **新建** `Game/Scripts/Autoloads/ZoneManager.gd` — 区域子场景加载/卸载调度
- **新建** `Game/Scripts/Components/` — Component 脚本目录（MovementComponent、GravityReceiverComponent 等）
- **新建** `Game/Scripts/Components/LGFNode.gd` — 局部重力场节点（场景机制 & 玩家技能两用）
- **新建** `Game/Scenes/Player.tscn` — 玩家 Entity，挂载各 Component 子节点
- **新建** `Game/Scenes/SkillTestLab.tscn` — 技能测试场景
- **更新** `Game/project.godot` — 注册新的 Autoload 单例
- **更新** `Documents/ImplementDesign/` — 补充架构设计文档（本 change 的核心产出之一）

## Capabilities

### New Capabilities

- **gravity-manager** — 全局重力方向/强度状态机，管理 GE 资源，提供 `get_gravity_at(pos)` 查询接口
- **time-manager** — 时间流速控制、CE 资源管理、帧快照 Ring Buffer、回溯调度
- **rewindable-component** — Component 通用快照接口（`capture_snapshot` / `apply_snapshot`）
- **player-entity** — 基础玩家 Entity，携带 MovementComponent + GravityReceiverComponent + 技能 Component
- **skill-test-lab** — 可运行的技能测试场景，包含 HUD（GE/CE 条、重力向量、time_scale 显示）

### Modified Capabilities

- **godot-project-bootstrap** — 扩展 Autoload 注册，新增 GravityManager 与 TimeManager

## Non-Goals（本次不涉及）

- 完整的关卡/区域系统（Zone 划分、隔离屏障）
- 敌人 AI 与战斗系统
- 液体物理模拟
- 存档/读档系统
- 完整的数值升级系统（LGF 数量上限升级等）

## Impact

- 所有游戏 Entity 均应遵循 EC 模式，Component 作为子节点挂载
- 所有需要参与时间回溯的 Component，必须实现 `capture_snapshot` / `apply_snapshot` 接口并向 TimeManager 注册
- GravityManager 与 TimeManager 作为 Autoload，是全局唯一访问入口，不应在 Component 内绕过它们直接操作物理属性

## Open Questions（待讨论，详见 design.md）

| # | 问题 | 当前倾向 |
|---|------|----------|
| Q5 | 动态生成物体的存在性快照 | MVP 阶段回避：测试场景中所有物体在加载时已存在，不动态生成；记录为未来 SpawnManager 的需求 |

> 原有开放问题 Q1–Q4、Q6–Q7 均已在 design.md 各系统设计小节中确认决策。
