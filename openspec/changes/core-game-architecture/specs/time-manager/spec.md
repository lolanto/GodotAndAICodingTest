## ADDED Requirements

### Requirement: TimeManager Autoload 作为时间流速与快照调度中枢

系统 SHALL 在 `Game/Scripts/Autoloads/TimeManager.gd` 创建 Autoload 单例 `TimeManager`，并在 `Game/project.godot` 中注册（顺序在 GravityManager 之后）。TimeManager SHALL 持有 `time_scale: float`（默认 1.0）、`is_rewinding: bool`（默认 false）、`in_rewind_free_zone: bool`（默认 false）。TimeManager SHALL 在每物理帧的 `_physics_process` 中调度 `pre_tick(delta)` 和 `post_tick()`。

#### Scenario: TimeManager 在启动时优先于主场景初始化

- **WHEN** 游戏启动
- **THEN** TimeManager._ready() SHALL 在主场景任意节点的 _ready() 前执行（Autoload 保证）

#### Scenario: effective_delta 由 time_scale 决定

- **WHEN** 物理帧 `_physics_process(delta)` 执行
- **THEN** `effective_delta SHALL 等于 delta × time_scale`，并可通过 `get_effective_delta(delta)` 获取

---

### Requirement: CE（时间能量）资源管理

TimeManager SHALL 持有 CE 资源：`ce: float`（上限 100，初始值 100）。CE 消耗以**真实时间**计（与 time_scale 无关）：时间回溯 12 CE/秒、慢动作 10 CE/秒、时间加速 5 CE/秒、每个活跃 LCF 8 CE/秒。每帧消耗与恢复互斥：有消耗则不恢复；无消耗时以基础 5 CE/秒回复（若 `GravityManager._zero_g_bonus_active` 为 true 则 × 3）。CE 耗尽时 SHALL 强制中断所有时间操控并启动 2 秒冷却。CE **不参与**帧快照，不随回溯还原。

#### Scenario: 时间回溯期间 CE 持续消耗

- **WHEN** `is_rewinding == true`
- **THEN** 每真实秒 `ce` SHALL 减少 12.0，降至 0 时强制停止回溯

#### Scenario: CE 耗尽时强制中断时间操控

- **WHEN** `ce` 减少至 0
- **THEN** 所有时间技能（回溯、慢动作、加速）SHALL 立即取消，`time_scale` 恢复为 1.0，并启动 2 秒技能冷却

#### Scenario: 零重力 CE 3× 加成（消耗互斥时触发）

- **WHEN** 当前帧无任何 CE 消耗 且 `GravityManager._zero_g_bonus_active == true`
- **THEN** CE 回复速率 SHALL 为 15.0 CE/秒（5 × 3），不超过上限 100

---

### Requirement: 帧快照 Ring Buffer

TimeManager SHALL 维护一个固定大小为 1200 帧的 Ring Buffer（`MAX_FRAMES = 1200`，保证 60fps × 0.5× 慢动作下覆盖 10 游戏秒历史）。每帧 `post_tick()` SHALL 遍历所有注册者调用 `capture_snapshot()`，以 `rewind_id` 为键存入当帧快照字典，压入 Ring Buffer。进入失效区域时 `post_tick()` SHALL 跳过积累。

#### Scenario: 每帧快照包含所有注册者状态

- **WHEN** `post_tick()` 在正常游戏帧执行（非失效区域）
- **THEN** Ring Buffer 当帧快照 SHALL 包含所有已注册 IRewindable 实现者的快照，以 `rewind_id` 为键

#### Scenario: 失效区域内不积累历史帧

- **WHEN** `in_rewind_free_zone == true`
- **THEN** `post_tick()` SHALL 立即返回，不向 Ring Buffer 写入任何快照

---

### Requirement: 时间回溯调度

`pre_tick(delta)` SHALL 在物理帧开始时检查 `is_rewinding`；若为 true，SHALL 按 `REWIND_SPEED（2.0）× delta` 的游戏时间步长从 Ring Buffer 反向读取快照，调用所有注册者的 `apply_snapshot()`，然后 return（跳过本帧后续所有物理步骤）。当 Ring Buffer 无有效帧时 SHALL 自动停止回溯（`is_rewinding = false`）。

#### Scenario: 回溯时历史状态被还原

- **WHEN** `is_rewinding == true` 且 Ring Buffer 有有效帧
- **THEN** 本物理帧所有注册者 SHALL 由 `apply_snapshot()` 还原状态，物理模拟不执行，玩家输入不响应

#### Scenario: 历史帧耗尽时自动停止回溯

- **WHEN** Ring Buffer `_valid_frame_count == 0`
- **THEN** `is_rewinding` SHALL 自动设置为 `false`

---

### Requirement: IRewindable 注册与注销

TimeManager SHALL 提供 `register(node)` 和 `unregister(node)` 接口。`register()` SHALL 断言注册者实现了 `capture_snapshot`、`apply_snapshot` 方法及 `rewind_id` 字段，并断言 `rewind_id` 全局唯一。`unregister()` SHALL 从 `_registry` 中移除对应节点。

#### Scenario: 注册时接口校验

- **WHEN** 调用 `TimeManager.register(node)`，且 `node` 未实现 `capture_snapshot` 或缺少 `rewind_id`
- **THEN** 系统 SHALL 抛出断言错误（`assert` 失败），在调试模式下终止并输出错误信息

#### Scenario: 重复 rewind_id 被拒绝

- **WHEN** 调用 `TimeManager.register(node)`，且已有注册者持有相同 `rewind_id`
- **THEN** 系统 SHALL 抛出断言错误，提示 `"Duplicate rewind_id: <id>"`

---

### Requirement: 失效区域（Rewind-Free Zone）状态切换

TimeManager SHALL 提供 `enter_rewind_free_zone()` 和 `exit_rewind_free_zone()` 接口。`enter_rewind_free_zone()` SHALL：强制停止任何正在进行的回溯、取消所有时间流速操控（`time_scale → 1.0`）、清空整个 Ring Buffer、将 `ce` 回满至上限（100）。`exit_rewind_free_zone()` SHALL 仅将 `in_rewind_free_zone` 置为 false，Ring Buffer 从当前帧起重新积累。

#### Scenario: 进入失效区域时 CE 回满

- **WHEN** `enter_rewind_free_zone()` 被调用
- **THEN** `ce` SHALL 等于 `ce_max`（100），Ring Buffer 全部清空，`_valid_frame_count == 0`

#### Scenario: 失效区域内技能触发被拒绝

- **WHEN** `in_rewind_free_zone == true` 且玩家尝试触发时间回溯
- **THEN** 操作 SHALL 被拒绝，`is_rewinding` 保持 `false`

---

### Requirement: MVP LCF stub（get_time_scale_at 接口预留）

TimeManager SHALL 提供 `get_time_scale_at(world_position: Vector2) -> float` 接口。MVP 阶段 SHALL 忽略 `world_position`，仅返回当前全局 `time_scale`。后续迭代引入 LCFNode 后扩展此函数查询 LCF 列表。

#### Scenario: MVP 阶段 get_time_scale_at 返回全局倍率

- **WHEN** 调用 `TimeManager.get_time_scale_at(any_position)`
- **THEN** 返回值 SHALL 等于 `TimeManager.time_scale`，与传入位置无关
