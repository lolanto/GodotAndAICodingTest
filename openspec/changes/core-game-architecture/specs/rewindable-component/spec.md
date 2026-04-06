## ADDED Requirements

### Requirement: IRewindable 协议约定

所有参与时间回溯的 Component 和系统 SHALL 以约定方式实现以下三个协议成员（GDScript 无强制接口，以约定+断言校验代替）：

- `var rewind_id: String`：全局唯一标识符，命名规范：`sys/<name>`（Autoload 系统）、`player/<name>`（玩家 Component）、`zone_<id>/<name>`（区域节点）
- `func capture_snapshot() -> Dictionary`：返回当前状态快照字典
- `func apply_snapshot(snapshot: Dictionary) -> void`：从快照字典恢复状态

实现 IRewindable 的 Component SHALL 在 `_ready()` 中调用 `TimeManager.register(self)` 并加入 `"rewindable"` Group，在 `_exit_tree()` 中调用 `TimeManager.unregister(self)`。

#### Scenario: Component 自注册到 TimeManager

- **WHEN** 实现 IRewindable 的节点 `_ready()` 执行
- **THEN** TimeManager._registry SHALL 包含该节点，且该节点在 Godot Remote 面板中可见于 "rewindable" Group

#### Scenario: Component 退出场景树时自动注销

- **WHEN** 实现 IRewindable 的节点从场景树移除（`_exit_tree()`）
- **THEN** TimeManager._registry SHALL 不再包含该节点

---

### Requirement: initial_snapshot 支持回溯到节点加载前

每个 RewindableComponent SHALL 持有 `initial_snapshot: Dictionary` 字段。节点 `_ready()` 完成后 SHALL 调用一次 `capture_snapshot()` 并存为 `initial_snapshot`。当 TimeManager 回溯到该节点尚未加载的时刻时，SHALL 调用 `reset_to_initial()` 使节点恢复到加载时的初始状态。

#### Scenario: 回溯到节点加载之前时使用初始快照

- **WHEN** Ring Buffer 中某帧不包含某节点的 `rewind_id`（该节点在此帧之后才加载）
- **THEN** TimeManager SHALL 调用该节点的 `reset_to_initial()`，而非 `apply_snapshot()`

---

### Requirement: LGFNode 实现 IRewindable

`LGFNode`（继承 `Area2D`）SHALL 实现 IRewindable 协议，`rewind_id` 命名规范为：场景机制 LGF 使用 `zone_<zone_id>/lgf-<name>`，玩家技能槽位使用 `player/lgf-slot-<index>`。LGFNode 快照 SHALL 包含以下字段：`active`、`direction`、`magnitude`、`blend_factor`、`remaining_time`、`placement_order`。`unlocked` 字段 SHALL **不**纳入快照（持久进度，不随回溯还原）。

#### Scenario: LGFNode 快照包含活跃状态与优先级

- **WHEN** `LGFNode.capture_snapshot()` 被调用
- **THEN** 返回字典 SHALL 包含键 `active`、`direction`、`magnitude`、`blend_factor`、`remaining_time`、`placement_order`，且不包含 `unlocked`

#### Scenario: LGFNode 回溯后正确还原优先级

- **WHEN** 时间回溯将 LGFNode 还原到 T 时刻快照
- **THEN** `placement_order` SHALL 等于 T 时刻记录的值，`get_gravity_at()` 的后置优先顺序 SHALL 与 T 时刻完全一致

---

### Requirement: MovementComponent 实现 IRewindable

`MovementComponent`（继承 `Node`，挂载在 Player 或 Entity 下）SHALL 实现 IRewindable，`rewind_id` 为 `player/movement`。快照 SHALL 包含 `position`（`owner.global_position`）和 `velocity`（`owner.velocity`）。`apply_snapshot()` SHALL 直接赋值而不走物理模拟，确保回溯帧位置精确还原。

#### Scenario: 回溯后位置与速度精确还原

- **WHEN** `apply_snapshot(s)` 被调用
- **THEN** `owner.global_position` SHALL 等于 `s["position"]`，`owner.velocity` SHALL 等于 `s["velocity"]`，无物理模拟介入

---

### Requirement: HealthComponent 实现 IRewindable

`HealthComponent`（继承 `Node`）SHALL 实现 IRewindable，快照仅包含 `hp: int`。`take_damage()` SHALL 在 `TimeManager.is_rewinding == true` 时立即返回，不修改 HP 也不发射信号。

#### Scenario: 回溯期间拒绝伤害

- **WHEN** `TimeManager.is_rewinding == true` 且 `take_damage(amount)` 被调用
- **THEN** `_hp` SHALL 保持不变，`health_changed` 信号 SHALL 不被发射
