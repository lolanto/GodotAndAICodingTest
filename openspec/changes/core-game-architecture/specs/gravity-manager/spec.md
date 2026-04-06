## ADDED Requirements

### Requirement: GravityManager Autoload 作为全局重力状态入口

系统 SHALL 在 `Game/Scripts/Autoloads/GravityManager.gd` 创建 Autoload 单例 `GravityManager`，并在 `Game/project.godot` 中注册。GravityManager SHALL 持有全局重力状态：`direction: Vector2`（瞬时切换）与 `magnitude: float`（0.2 秒线性插值过渡）。GravityManager SHALL 实现 IRewindable 协议（`capture_snapshot` / `apply_snapshot` + `rewind_id = "sys/gravity"`），并在 `_ready()` 中向 TimeManager 注册。

#### Scenario: 重力方向瞬间切换

- **WHEN** 调用 `GravityManager.set_direction(new_dir: Vector2)` 设置新方向
- **THEN** `GravityManager.direction` SHALL 立即等于 `new_dir`，不产生任何插值过渡

#### Scenario: 重力强度线性插值过渡

- **WHEN** 调用 `GravityManager.set_magnitude(target: float)` 设置新强度目标
- **THEN** `GravityManager.magnitude` SHALL 在约 0.2 秒内线性插值到目标值，物理层始终使用插值中间值

#### Scenario: GravityManager 在启动时注册到 TimeManager

- **WHEN** 游戏启动，GravityManager `_ready()` 执行
- **THEN** TimeManager._registry SHALL 包含 GravityManager 实例，且 `rewind_id` 为 `"sys/gravity"`

---

### Requirement: GE（重力能量）资源管理

GravityManager SHALL 持有 GE 资源：`ge: float`（上限 100，初始值 100）。每帧 GE 消耗与 GE 恢复互斥：若当前帧有活跃 LGF 产生 GE 消耗，SHALL 不执行恢复；否则以 8 CE/秒速率回复，不超过上限。GE SHALL 纳入 `capture_snapshot` 快照，随时间回溯还原。

#### Scenario: LGF 活跃时 GE 持续消耗

- **WHEN** 存在 `source="player_skill"` 且 `active=true` 的 LGFNode
- **THEN** 每帧 `ge` SHALL 按 `LGF_DRAIN_PER_SEC × active_count × effective_delta` 递减，最低减至 0

#### Scenario: 无 LGF 时 GE 自然回复

- **WHEN** 当前帧无活跃玩家技能 LGF（或 GE 消耗为 0）
- **THEN** 每帧 `ge` SHALL 按 8 CE/秒 × effective_delta 递增，不超过 `ge_max`（100）

#### Scenario: GE 随回溯还原

- **WHEN** 玩家触发时间回溯，回溯到 T 时刻
- **THEN** `GravityManager.ge` SHALL 恢复为 T 时刻快照中记录的值

---

### Requirement: LGF 注册表与重力查询

GravityManager SHALL 维护 LGF 注册表 `_lgf_registry: Array[LGFNode]`，提供 `register_lgf(node)` 与 `unregister_lgf(node)` 接口。`get_gravity_at(pos: Vector2) -> Vector2` SHALL 遍历注册表中所有 `active=true` 且覆盖 `pos` 的 LGF，按 `placement_order` 降序取最高优先级的 LGF，通过 `blend_factor` 插值返回最终重力向量；若无活跃 LGF 覆盖，则返回全局重力 `direction × magnitude`。

#### Scenario: 无活跃 LGF 时返回全局重力

- **WHEN** 调用 `get_gravity_at(pos)` 且注册表中无 `active=true` 的 LGF 覆盖该点
- **THEN** 返回值 SHALL 等于 `direction * magnitude`

#### Scenario: 后置优先级覆盖

- **WHEN** 多个活跃 LGF 同时覆盖同一点，其 `placement_order` 各不相同
- **THEN** `get_gravity_at()` SHALL 使用 `placement_order` 最大的 LGF（最后放置）作为主导，通过其 `blend_factor` 与全局重力插值

#### Scenario: LGFNode 自动注册与注销

- **WHEN** `LGFNode._ready()` 执行时
- **THEN** GravityManager._lgf_registry SHALL 包含该节点；当该节点 `_exit_tree()` 时 SHALL 从注册表中移除

---

### Requirement: 联动效果——引力时间膨胀与零重力 CE 加成

GravityManager.tick() SHALL 在每物理帧计算联动效果：当 `magnitude` 超出正常范围（1.0×）时，写入 `TimeManager.time_scale` 以产生引力时间膨胀效果（具体映射曲线由 GDD §4 定义，MVP 阶段可先实现线性近似）。当 `magnitude == 0.0` 时 SHALL 维护 `_zero_g_timer` 累积游戏时间，超过 3.0 秒后将 `_zero_g_bonus_active` 置为 `true`，供 TimeManager 在 CE 恢复时读取（3× 加成）。`_zero_g_timer` 与 `_zero_g_bonus_active` SHALL 纳入快照。

#### Scenario: 零重力超时激活 CE 加成

- **WHEN** `magnitude == 0.0` 持续超过 3.0 游戏秒（`effective_delta` 累积）
- **THEN** `GravityManager._zero_g_bonus_active` SHALL 为 `true`，且 TimeManager 在 CE 恢复分支中将恢复速率 × 3

#### Scenario: 非零重力重置零重力计时器

- **WHEN** `magnitude` 变为非零值
- **THEN** `_zero_g_timer` SHALL 重置为 0.0，`_zero_g_bonus_active` SHALL 为 `false`

#### Scenario: 发射重力变化信号

- **WHEN** `direction` 发生改变
- **THEN** GravityManager SHALL 发射 `gravity_direction_changed` 信号；`magnitude` 插值完成时 SHALL 发射 `magnitude_changed` 信号
