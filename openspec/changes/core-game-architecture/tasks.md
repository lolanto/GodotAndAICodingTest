## 1. 项目配置与 Autoload 注册

- [x] 1.1 在 `Game/project.godot` 中注册 `GravityManager`、`TimeManager`、`ZoneManager` 三个 Autoload，顺序在 `Bootstrap` 之后，依次为 GravityManager → TimeManager → ZoneManager
- [x] 1.2 创建 `Game/Scripts/Autoloads/` 目录，为三个新 Autoload 创建占位脚本文件（`GravityManager.gd`、`TimeManager.gd`、`ZoneManager.gd`）并确保游戏可正常启动无报错

## 2. IRewindable 协议基础设施

- [x] 2.1 在 `TimeManager.gd` 中实现 `_registry: Array`、`register(node)`（含接口断言校验）、`unregister(node)` 接口
- [x] 2.2 在 `TimeManager.gd` 中实现帧快照 Ring Buffer（`MAX_FRAMES=1200`，`_buffer`、`_write_head`、`_valid_frame_count`）及 `post_tick()` 快照积累逻辑
- [x] 2.3 在 `TimeManager.gd` 中实现 `pre_tick(delta)` 回溯调度逻辑（`REWIND_SPEED=2.0`，按游戏时间步长反向读帧，分发 `apply_snapshot()`）
- [x] 2.4 在 `TimeManager.gd` 中实现 `enter_rewind_free_zone()` 和 `exit_rewind_free_zone()`（含 Buffer 清空、CE 回满、强制停止回溯）
- [x] 2.5 在 `TimeManager.gd` 中实现 CE 资源管理（`_tick_ce(real_delta)`，含消耗/恢复互斥、CE 耗尽强制中断逻辑、零重力 3× 加成读取）
- [x] 2.6 在 `TimeManager.gd` 中实现 MVP LCF stub：`get_time_scale_at(world_position) -> float` 返回全局 `time_scale`；`get_effective_delta(base_delta) -> float`
- [x] 2.7 在 `TimeManager.gd` 中接入 `_physics_process`，按主循环顺序调度：`pre_tick(delta)` → （返回后跳过）→ 供其他系统使用的 `effective_delta` → `post_tick()`

## 3. GravityManager 实现

- [x] 3.1 实现 `GravityManager.gd` 基础字段与状态机：`direction: Vector2`、`magnitude: float`、`_target_magnitude: float`、`_mag_interp_t: float`，以及 `set_direction()` 和 `set_magnitude()` 接口
- [x] 3.2 实现 `GravityManager.tick(effective_delta)` 中的强度 0.2s 线性插值逻辑（`MAG_INTERP_DURATION=0.2`）
- [x] 3.3 实现 LGF 注册表：`_lgf_registry: Array[LGFNode]`、`register_lgf(node)`、`unregister_lgf(node)`、`get_gravity_at(pos) -> Vector2`（后置优先 placement_order 排序 + blend_factor 插值）
- [x] 3.4 实现 GE 资源管理：`ge: float`（上限 100，回复 8/秒），GE 消耗/恢复互斥逻辑，GE 扣除冷却（全局方向切换 1.5s、LGF 放置 0.3s）
- [x] 3.5 实现零重力联动：`_zero_g_timer`、`_zero_g_bonus_active`，超 3s 激活，非零重力时重置
- [x] 3.6 实现 IRewindable 协议：`rewind_id = "sys/gravity"`，`capture_snapshot()`（含 direction、magnitude、target_magnitude、mag_interp_t、ge、zero_g_timer、zero_g_bonus_active），`apply_snapshot()`
- [x] 3.7 GravityManager 在 `_ready()` 中向 TimeManager 注册自身；发射 `gravity_direction_changed` 和 `magnitude_changed` 信号

## 4. Component 基础实现

- [x] 4.1 创建 `Game/Scripts/Components/` 目录；实现 `LGFNode.gd`（继承 `Area2D`）：完整字段（direction、magnitude、blend_factor、source、active、unlocked、remaining_time、placement_order）、`_ready()`/`_exit_tree()` 自注册到 GravityManager、IRewindable 协议（快照不含 unlocked）
- [x] 4.2 实现 `MovementComponent.gd`：`physics_step(effective_delta)` 读取 `GravityReceiverComponent.cached_gravity` 累加速度并调用 `owner.move_and_slide()`；IRewindable（快照：`{position, velocity}`，apply 直接赋值不走物理）；`_ready()`/`_exit_tree()` 注册 TimeManager
- [x] 4.3 实现 `GravityReceiverComponent.gd`：`physics_step()` 调用 `GravityManager.get_gravity_at(owner.global_position)` 缓存为 `cached_gravity`；IRewindable（快照：`{cached_gravity}`）；注册 TimeManager
- [x] 4.4 实现 `PlayerInputComponent.gd`：`_unhandled_input()` 转发移动/技能输入；`is_rewinding` 时 return 锁定所有输入；**不**实现 IRewindable（不注册 TimeManager）
- [x] 4.5 实现 `GravitySkillComponent.gd`：6 个 LGFNode 子节点预分配对象池（Slot0~2 unlocked=true，Slot3~5 unlocked=false）；`place_lgf()`/`remove_lgf()` 逻辑；`_next_order` 单调递增；慢动作精度模式切换（步进 0.05× vs 0.25×）；IRewindable（快照：`{active_count, next_placement_order}`）；注册 TimeManager
- [x] 4.6 实现 `TimeSkillComponent.gd`：`try_start_rewind()`（失效区域检查、取消时间流速操控、重置 time_scale 为 1.0）、`try_start_slow_motion()`、`try_start_time_rush()`；IRewindable（快照：`{lcf_list: []}`）；注册 TimeManager
- [x] 4.7 实现 `HealthComponent.gd`：`take_damage()` 在 `is_rewinding` 时 return；IRewindable（快照：`{hp}`）；注册 TimeManager

## 5. Player Entity 场景组装

- [x] 5.1 创建 `Game/Scenes/Player.tscn`：根节点 `CharacterBody2D`，挂载 `Player.gd`，加入 `"player"` Group，按设计文档层级挂载所有 Component 子节点（含 GravitySkillComponent 下的 6 个 LGFNode 槽位）
- [x] 5.2 编写 `Game/Scripts/Player.gd`：`_physics_process(delta)` 中获取 `effective_delta`，依序调用 GravityReceiverComponent → MovementComponent 的 `physics_step(effective_delta)`，确保主循环顺序正确

## 6. ZoneManager 基础实现

- [x] 6.1 实现 `ZoneManager.gd`：`_loaded_zones`、`_zone_exit_timestamps`；`player_entered_zone(zone_id)` 和 `player_exited_zone(zone_id)` 接口；`_check_safe_to_unload()`（真实时间阈值 20.0s）；`_load_zone()` 和 `_unload_zone()` 基本逻辑

## 7. SkillTestLab 场景

- [x] 7.1 创建 `Game/Scenes/SkillTestLab.tscn`：四面封闭边界（StaticBody2D × 4）、若干不同高度静态平台、Player 实例（中心初始位置）
- [x] 7.2 添加至少 1 个木箱（`RigidBody2D`，挂载 `HealthComponent` 或最小 IRewindable 实现，注册 TimeManager 参与回溯）
- [x] 7.3 实现 HUD CanvasLayer：GE 条、CE 条、time_scale 显示、重力向量显示、回溯状态指示（蓝色视觉反馈）；每帧通过 `_process` 更新
- [x] 7.4 实现调试 Label 面板：显示 GE/CE 精确值、time_scale、direction、magnitude、is_rewinding、in_rewind_free_zone、Ring Buffer `_valid_frame_count`；面板可通过 `visible = false` 关闭

## 8. 输入映射配置

- [x] 8.1 在 `Game/project.godot` 中配置输入动作：`gravity_flip_down`/`up`/`left`/`right`（全局重力切换）、`time_rewind`（回溯）、`time_slow`（慢动作）、`time_rush`（加速）、`place_lgf`（放置局部重力场）、`remove_lgf`（移除局部重力场）

## 9. 文档同步

- [x] 9.1 在 `Documents/ImplementDesign/` 下创建架构总览文档（`ImplDesign_CoreArchitecture.md`），内容同步 design.md 中的系统架构、主循环设计、各系统职责摘要，并附 PlantUML 类图/时序图

---

## 10. 单元测试（GUT 脚本，`Game/Tests/Unit/`）

> 使用 [GUT（Godot Unit Test）](https://github.com/bitwes/Gut) 框架，每个测试文件以 `test_` 前缀命名，放置于 `Game/Tests/Unit/` 下。
> 所有单元测试在**不依赖完整场景树**的前提下直接实例化被测脚本，模拟依赖。

### GravityManager 单元测试（`test_gravity_manager.gd`）

- [x] 10.1 **GE 初始值**：实例化 GravityManager，断言 `ge == 100` 且 `ge_max == 100`
- [x] 10.2 **方向瞬切**：调用 `set_direction(Vector2.RIGHT)` 后，断言 `direction == Vector2.RIGHT`（无需等待帧）
- [x] 10.3 **强度插值**：调用 `set_magnitude(0.0)` 后连续调用 `tick(0.05)` × 5 帧，断言第 1 帧 `magnitude` 仍处于插值中间值（`0 < magnitude < 1.0`），第 5 帧（累积 0.25s > 0.2s）`magnitude == 0.0`
- [x] 10.4 **GE 消耗/恢复互斥**：向 `_lgf_registry` 注入一个 `active=true, source="player_skill"` 的 mock LGF，调用 `tick(1.0)`，断言 `ge < 100`（消耗）且 `ge` 下降量等于 `LGF_DRAIN_PER_SEC × 1.0`；移除 mock LGF 后再调用 `tick(1.0)`，断言 `ge` 回升 8.0
- [x] 10.5 **GE 不超过上限**：`ge = 99.0`，无活跃 LGF，调用 `tick(10.0)`，断言 `ge == 100`（不溢出）
- [x] 10.6 **零重力计时器激活**：`set_magnitude(0.0)` 使 `magnitude == 0.0`，连续调用 `tick(1.0)` × 3 次（累积 3.0s），断言 `_zero_g_bonus_active == true`
- [x] 10.7 **零重力计时器重置**：在 `_zero_g_bonus_active == true` 状态下调用 `set_magnitude(1.0)` 并 `tick(0.3)`（完成插值），断言 `_zero_g_timer == 0.0` 且 `_zero_g_bonus_active == false`
- [x] 10.8 **get_gravity_at 无 LGF**：注册表为空，调用 `get_gravity_at(Vector2.ZERO)`，断言返回值等于 `direction * magnitude`
- [x] 10.9 **get_gravity_at 后置优先**：注册 2 个 `active=true` 且覆盖测试点的 mock LGF（`placement_order` 分别为 1 和 3），调用 `get_gravity_at()`，断言结果由 `order=3` 的 LGF 主导（取其 `direction * magnitude` 与全局重力以 `blend_factor` 插值）
- [x] 10.10 **gravity_direction_changed 信号**：连接 `gravity_direction_changed` 信号，调用 `set_direction(Vector2.UP)`，断言信号被发射恰好 1 次

### TimeManager 单元测试（`test_time_manager.gd`）

- [x] 10.11 **register 接口校验——缺失 capture_snapshot**：尝试向 `TimeManager.register()` 传入一个没有 `capture_snapshot` 方法的 Object，断言触发 `assert` 失败（在 `push_error` 或 assert 层捕获）
- [x] 10.12 **register 重复 rewind_id 被拒绝**：注册两个 `rewind_id` 相同的 mock 对象，断言第二次 `register()` 触发断言错误
- [x] 10.13 **post_tick 积累快照**：注册 1 个 mock IRewindable（`rewind_id="test/a"`），调用 `post_tick()`，断言 `_valid_frame_count == 1` 且 `_buffer[0]["snapshots"]["test/a"]` 非空
- [x] 10.14 **失效区域内 post_tick 不积累**：`enter_rewind_free_zone()` 后调用 `post_tick()`，断言 `_valid_frame_count == 0`
- [x] 10.15 **CE 消耗——回溯状态**：设置 `is_rewinding = true`，调用 `_tick_ce(1.0)`，断言 `ce == 88.0`（100 - 12）
- [x] 10.16 **CE 消耗——慢动作状态**：设置 `_is_slow_motion = true`，调用 `_tick_ce(1.0)`，断言 `ce == 90.0`（100 - 10）
- [x] 10.17 **CE 恢复——无消耗基础速率**：所有技能关闭，`ce = 50.0`，调用 `_tick_ce(1.0)`，断言 `ce == 55.0`
- [x] 10.18 **CE 零重力 3× 加成**：所有技能关闭，`ce = 50.0`，设置 `GravityManager._zero_g_bonus_active = true`（注入 mock），调用 `_tick_ce(1.0)`，断言 `ce == 65.0`（50 + 5 × 3）
- [x] 10.19 **CE 消耗与恢复互斥**：`is_rewinding = true` 且 `_zero_g_bonus_active = true`，调用 `_tick_ce(1.0)`，断言 `ce` 按 12 CE/秒减少（消耗分支优先，不触发 3× 加成）
- [x] 10.20 **CE 耗尽触发强制中断**：`ce = 5.0`，`is_rewinding = true`，调用 `_tick_ce(1.0)`，断言 `ce == 0.0`，`is_rewinding == false`，`time_scale == 1.0`
- [x] 10.21 **enter_rewind_free_zone 清空 Buffer 并回满 CE**：先积累 10 帧快照（`_valid_frame_count == 10`），再调用 `enter_rewind_free_zone()`，断言 `_valid_frame_count == 0` 且 `ce == 100`
- [x] 10.22 **get_time_scale_at MVP stub**：`time_scale = 0.5`，调用 `get_time_scale_at(Vector2(999, 999))`，断言返回值 `== 0.5`（与位置无关）

### IRewindable / Component 单元测试（`test_rewindable.gd`）

- [x] 10.23 **LGFNode capture/apply 对称性**：实例化 `LGFNode`，设置所有字段后调用 `capture_snapshot()`，再修改字段，调用 `apply_snapshot(snapshot)`，断言所有快照字段还原；断言 `unlocked` 不在快照字典中
- [x] 10.24 **LGFNode unlocked 不随 apply_snapshot 变更**：`unlocked = true`，调用含 `"unlocked": false` 键的快照（即使传入），断言 `unlocked` 保持 `true`（apply 不写入 unlocked）
- [x] 10.25 **MovementComponent apply_snapshot 直接赋值**：创建 mock owner（带 `global_position` 和 `velocity`），调用 `apply_snapshot({"position": Vector2(100,200), "velocity": Vector2(5,0)})`，断言 `owner.global_position == Vector2(100,200)` 且 `owner.velocity == Vector2(5,0)`
- [x] 10.26 **HealthComponent 回溯期间拒绝伤害**：`TimeManager.is_rewinding = true`（注入 mock），`hp = 80`，调用 `take_damage(20)`，断言 `hp` 仍为 80，`health_changed` 信号未发射
- [x] 10.27 **HealthComponent 正常伤害生效**：`is_rewinding = false`，`hp = 80`，调用 `take_damage(20)`，断言 `hp == 60`，`health_changed` 信号发射 1 次

---

## 11. 集成测试（GUT 场景，`Game/Tests/Integration/`）

> 集成测试在**完整的 Godot 场景树**中运行，通过 `add_child()` 加载真实 Autoload 和场景，每个测试结束后 `free()` 清理。
> 测试文件放置于 `Game/Tests/Integration/`，以 `test_` 前缀命名。

### Ring Buffer 回溯集成（`test_rewind_integration.gd`）

- [x] 11.1 **回溯还原玩家位置**：加载 Player 和两个 Autoload，记录初始位置 P0，模拟 60 帧物理步（玩家向右移动到 P1），触发回溯，等待回溯完成，断言玩家 `global_position` 约等于 P0（误差 ≤ 1px）
- [x] 11.2 **回溯还原 GE 值**：初始 `ge = 100`，激活 1 个 LGF 消耗 GE（记录 T 时刻 ge = 80）再等待 30 帧，触发回溯到 T 时刻，断言 `GravityManager.ge ≈ 80`
- [x] 11.3 **回溯期间玩家输入被锁定**：回溯进行中，通过 `Input.parse_input_event()` 模拟移动输入，等待 10 帧，断言玩家位置未因输入改变（仅随快照回溯移动）
- [x] 11.4 **Ring Buffer 满后旧帧被覆盖**：积累 1201 帧快照（超过 `MAX_FRAMES=1200`），检查 `_valid_frame_count == 1200`（上限），回溯时最早可达帧不超过 1200 帧前
- [x] 11.5 **回溯耗尽有效帧后自动停止**：仅积累 10 帧历史，触发回溯，等待足够时间，断言 `is_rewinding` 自动变为 `false` 且无报错

### GravityManager ↔ TimeManager 联动集成（`test_gravity_time_synergy.gd`）

- [x] 11.6 **零重力 3× CE 加成端到端**：设置 `GravityManager.magnitude = 0.0`，等待 3 秒游戏时间（模拟 `tick()` 调用），此后无时间技能激活，等待 1 秒真实帧，断言 CE 回复量约为 15 CE（5 × 3），而非基础 5 CE
- [x] 11.7 **使用时间技能时零重力加成不触发**：`_zero_g_bonus_active = true`，同时 `_is_slow_motion = true`，等待 1 秒真实帧，断言 CE 按慢动作消耗（10 CE/秒），不产生 +15 回复
- [x] 11.8 **引力时间膨胀写入 time_scale**：`GravityManager.set_magnitude(3.0)` 并经过插值完成，调用 `GravityManager.tick(1.0)`，断言 `TimeManager.time_scale` 被写入为对应引力时间膨胀值（≤ 1.0，具体值依联动曲线）

### LGF 优先级与回溯集成（`test_lgf_rewind_integration.gd`）

- [x] 11.9 **LGF 放置后 get_gravity_at 覆盖全局重力**：放置 1 个 `active=true`、`direction=Vector2.LEFT`、`blend_factor=0.0` 的玩家技能 LGF 覆盖玩家位置，断言 `get_gravity_at(player_pos) == Vector2.LEFT * lgf.magnitude`
- [x] 11.10 **LGF 放置后回溯还原为放置前状态**：放置 LGF（`active=true`）积累 30 帧，回溯到放置前时刻，断言该 LGFNode 的 `active == false`
- [x] 11.11 **槽位复用——回溯后 placement_order 精确还原**：Slot0 先激活（order=1）后到期（active=false），Slot0 再次激活（order=4），此时回溯到 order=4 激活前，断言 Slot0 的 `placement_order` 还原为激活前的值（active=false 时的最后快照值）

### 失效区域（Rewind-Free Zone）集成（`test_rewind_free_zone_integration.gd`）

- [x] 11.12 **进入失效区域中断回溯**：回溯进行中调用 `enter_rewind_free_zone()`，断言 `is_rewinding == false` 且 `_valid_frame_count == 0`，`ce == 100`
- [x] 11.13 **失效区域内无法触发回溯**：`in_rewind_free_zone = true`，调用 `TimeSkillComponent.try_start_rewind()`，断言 `is_rewinding == false` 且 CE 无变化
- [x] 11.14 **离开失效区域后 Ring Buffer 重新积累**：`exit_rewind_free_zone()` 后等待 5 帧，断言 `_valid_frame_count == 5`，新帧正常写入

---

## 12. 验收测试（手动 + 自动化，`Game/Tests/Acceptance/`）

> 验收测试直接在 `SkillTestLab.tscn` 中运行，以端到端玩家视角验证功能。
> 自动化验收测试通过 GUT 场景加载 `SkillTestLab.tscn`，脚本模拟输入序列并断言结果；
> 带 ★ 标记的测试同时需要**人工视觉确认**。

### AT-01 系统启动验收

- [x] 12.1 **AT-01 启动无报错**：通过 `./run.sh` 启动游戏，加载 SkillTestLab.tscn，等待 3 秒，断言 Godot 输出窗口**无** `ERROR`/`SCRIPT ERROR` 条目，HUD 所有数值正常显示（GE=100，CE=100，×1.0，↓1.0）

### AT-02 重力系统验收

- [x] 12.2 ★ **AT-02a 四方向重力可视验证**：依次触发上/下/左/右重力切换，断言玩家在每次切换后向对应方向加速落下并被边界正确挡住（人工目视确认方向正确，无穿模）
- [x] 12.3 **AT-02b GE 消耗与冷却**：触发全局方向切换，断言 GE 立即减少且切换冷却期内（1.5s）`set_direction` 无响应；等待 1.5s 后再次切换成功
- [x] 12.4 **AT-02c LGF 放置改变局部重力**：玩家站在平台上放置 1 个 LGF（`direction=Vector2.UP`，`blend_factor=0.0`），进入 LGF 覆盖区域，断言玩家开始向上加速（`GravityReceiverComponent.cached_gravity.y < 0`）

### AT-03 时间系统验收

- [x] 12.5 **AT-03a 慢动作 CE 消耗率**：记录 CE 初始值，激活慢动作并等待 2.0 真实秒，断言 CE 减少量约为 20（10 CE/秒 × 2s），允许 ±2 误差
- [x] 12.6 **AT-03b 时间加速 CE 消耗率**：激活时间加速（2.0×）并等待 2.0 真实秒，断言 CE 减少量约为 10（5 CE/秒 × 2s），允许 ±2 误差
- [x] 12.7 ★ **AT-03c 回溯视觉蓝色滤镜**：触发时间回溯，目视确认画面蓝色滤镜出现，玩家运动轨迹反向播放，HUD 显示回溯状态标识
- [x] 12.8 **AT-03d 回溯还原木箱位置**：将木箱推离初始位置约 100px，积累 3 秒历史，触发回溯直至 CE 耗尽或手动停止，断言木箱 `global_position` 接近初始位置（误差 ≤ 5px）
- [x] 12.9 **AT-03e CE 耗尽自动停止所有技能**：慢动作激活中将 CE 强制降至 0（调试修改或等待自然耗尽），断言 `time_scale` 自动恢复为 1.0，`_is_slow_motion == false`

### AT-04 系统联动验收

- [x] 12.10 **AT-04a 零重力 CE 3× 加成验收**：设置 `magnitude = 0.0`，等待 3 秒（触发 `_zero_g_bonus_active`），确保无时间技能激活，等待 2 真实秒，断言 CE 回复量约为 30（15 CE/秒 × 2s），允许 ±3 误差
- [x] 12.11 ★ **AT-04b 引力时间膨胀视觉验收**：设置 `magnitude = 3.0`，目视确认玩家动作（如下落速度）发生变化；同时 HUD `time_scale` 显示值应小于 1.0（引力膨胀效果），人工记录具体数值与理论值（GDD §6.3：3× → τ=0.73）比对

### AT-05 失效区域验收

- [x] 12.12 **AT-05 进出失效区域端到端**：在 SkillTestLab 中添加 `RewindFreeZoneTrigger` 测试节点，驱动 Player 进入覆盖区域，断言 CE=100、Buffer 清空；再驱动 Player 离开，等待 5 帧，断言 Buffer 开始重新积累（`_valid_frame_count == 5`）
