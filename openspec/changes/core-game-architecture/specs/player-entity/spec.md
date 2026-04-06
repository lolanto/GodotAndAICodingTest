## ADDED Requirements

### Requirement: Player Entity 采用 EC 模式

系统 SHALL 在 `Game/Scenes/Player.tscn` 创建玩家主场景，根节点类型为 `CharacterBody2D`，挂载脚本 `Game/Scripts/Player.gd`。Player SHALL 使用 Entity-Component（EC）模式，各职责封装为独立子节点 Component，组件包括：`MovementComponent`、`GravityReceiverComponent`、`PlayerInputComponent`、`GravitySkillComponent`（含 6 个 LGFNode 子节点槽位）、`TimeSkillComponent`、`HealthComponent`。Player 节点 SHALL 加入 `"player"` Group。

#### Scenario: Player 场景可独立加载运行

- **WHEN** `Player.tscn` 被实例化并加入场景树
- **THEN** 所有 Component 子节点 SHALL 成功完成 `_ready()` 初始化，TimeManager._registry SHALL 包含 MovementComponent、GravityReceiverComponent、GravitySkillComponent（及其 6 个 LGFNode）、HealthComponent，不抛出任何断言错误

---

### Requirement: MovementComponent 负责物理运动

`MovementComponent`（`Node`，脚本 `Game/Scripts/Components/MovementComponent.gd`）SHALL 在 `physics_step(effective_delta: float)` 中：读取 `GravityReceiverComponent.cached_gravity`，将重力向量累加到速度，调用父节点 `move_and_slide()`。`physics_step()` 由 Player 根节点在 `_physics_process` 中以 `effective_delta` 调用。MovementComponent SHALL 实现 IRewindable（快照：`{position, velocity}`）。

#### Scenario: 重力方向影响玩家运动

- **WHEN** `GravityManager.direction` 变为 `Vector2.RIGHT`
- **THEN** 玩家 SHALL 向右加速（`velocity.x` 随帧增大），`move_and_slide()` 将玩家向右移动

#### Scenario: 物理步使用 effective_delta

- **WHEN** `TimeManager.time_scale == 0.5`（慢动作）
- **THEN** `MovementComponent.physics_step()` 接收的 `effective_delta` SHALL 等于原始 `delta × 0.5`，玩家运动速度减半

---

### Requirement: GravityReceiverComponent 缓存当前重力

`GravityReceiverComponent`（`Node`，脚本 `Game/Scripts/Components/GravityReceiverComponent.gd`）SHALL 在 `physics_step()` 中调用 `GravityManager.get_gravity_at(owner.global_position)` 并缓存为 `cached_gravity: Vector2`。GravityReceiverComponent SHALL 实现 IRewindable（快照：`{cached_gravity}`）。

#### Scenario: 每帧刷新缓存重力

- **WHEN** `GravityReceiverComponent.physics_step()` 执行
- **THEN** `cached_gravity` SHALL 等于 `GravityManager.get_gravity_at(owner.global_position)` 的当前返回值

---

### Requirement: PlayerInputComponent 处理玩家输入

`PlayerInputComponent`（`Node`，脚本 `Game/Scripts/Components/PlayerInputComponent.gd`）SHALL 监听 `_unhandled_input(event)` 并将输入事件转发给相关 Component（移动输入 → MovementComponent，技能输入 → GravitySkillComponent / TimeSkillComponent）。回溯期间（`TimeManager.is_rewinding == true`）SHALL 忽略所有输入。PlayerInputComponent **不**实现 IRewindable（输入是实时的，不参与快照）。

#### Scenario: 回溯期间锁定所有输入

- **WHEN** `TimeManager.is_rewinding == true` 且玩家按下移动键
- **THEN** MovementComponent.velocity SHALL 不受输入影响（PlayerInputComponent 不转发事件）

---

### Requirement: GravitySkillComponent 管理玩家技能 LGF 对象池

`GravitySkillComponent`（`Node`，脚本 `Game/Scripts/Components/GravitySkillComponent.gd`）SHALL 预分配 6 个 LGFNode 子节点（Slot0~5）：初始 Slot0~2 的 `unlocked=true`，Slot3~5 的 `unlocked=false`。"放置 LGF" SHALL 从 `unlocked=true && active=false` 的槽位中取一个，分配 `placement_order`，激活（`active=true`）。"移除 LGF" SHALL 将槽位 `active` 设为 `false`。GravitySkillComponent SHALL 实现 IRewindable（快照：`{active_count, next_placement_order}`）。

#### Scenario: 初始状态 3 个槽位可用

- **WHEN** Player 场景加载
- **THEN** GravitySkillComponent 下 6 个 LGFNode 中，Slot0~2 的 `unlocked == true`，Slot3~5 的 `unlocked == false`，所有 `active == false`

#### Scenario: placement_order 单调递增

- **WHEN** 玩家连续放置多个 LGF
- **THEN** 每次新放置的 LGFNode.placement_order SHALL 大于上一个放置的 LGFNode.placement_order

#### Scenario: 慢动作时精度增益（离散模式切换）

- **WHEN** `TimeManager._is_slow_motion == true` 且玩家调节 LGF 强度
- **THEN** 强度调节步进 SHALL 为 0.05×；正常模式下步进 SHALL 为 0.25×

---

### Requirement: TimeSkillComponent 负责时间技能触发

`TimeSkillComponent`（`Node`，脚本 `Game/Scripts/Components/TimeSkillComponent.gd`）SHALL 提供 `try_start_rewind()`、`try_start_slow_motion()`、`try_start_time_rush()` 接口。所有技能触发前 SHALL 检查 `TimeManager.in_rewind_free_zone`（失效则拒绝）及 CE 是否充足。触发回溯时 SHALL 先取消所有时间流速操控，将 `time_scale` 重置为 1.0，再设 `is_rewinding = true`。TimeSkillComponent SHALL 实现 IRewindable（快照：`{lcf_list 序列化}`，MVP 阶段 lcf_list 为空数组）。

#### Scenario: 失效区域内时间技能被拒绝

- **WHEN** `TimeManager.in_rewind_free_zone == true` 且调用 `try_start_rewind()`
- **THEN** `TimeManager.is_rewinding` SHALL 保持 `false`，无任何 CE 消耗

#### Scenario: 触发回溯时取消时间流速操控

- **WHEN** 当前处于慢动作（`time_scale == 0.5`）且调用 `try_start_rewind()`
- **THEN** `time_scale` SHALL 先重置为 1.0，再设 `is_rewinding = true`
