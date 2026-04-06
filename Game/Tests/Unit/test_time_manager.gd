extends GutTest
## TimeManager 单元测试（10.11 – 10.22）
##
## 每个测试实例化一个独立的 TimeManager（不触发 _ready），
## 手动初始化 _buffer。
## _tick_ce() 内部读取 GravityManager._zero_g_bonus_active（全局 Autoload），
## after_each 中负责复原。

const TimeManagerScript = preload("res://Scripts/Autoloads/TimeManager.gd")

var tm  # 每个测试的独立实例

# ── 最小 IRewindable mock ─────────────────────────────────────────────────────
class MockRewindable extends RefCounted:
	var rewind_id: String = "test/mock"
	var name: String      = "MockNode"   # register() 中 error 消息用到 node.name

	func capture_snapshot() -> Dictionary:
		return {"value": 42}

	func apply_snapshot(_s: Dictionary) -> void:
		pass

# 缺少 capture_snapshot 的错误对象
class BadNode extends RefCounted:
	var rewind_id: String = "test/bad"
	var name: String      = "BadNode"
	# 故意不定义 capture_snapshot / apply_snapshot

# ── Setup / Teardown ──────────────────────────────────────────────────────────
func before_each() -> void:
	tm = TimeManagerScript.new()
	# _ready() 未调用 → 需手动初始化 _buffer
	tm._buffer.resize(TimeManagerScript.MAX_FRAMES)
	tm._buffer.fill(null)
	# 恢复全局 GravityManager 的零重力加成状态
	GravityManager._zero_g_bonus_active = false

func after_each() -> void:
	tm.free()
	# 恢复全局状态
	GravityManager._zero_g_bonus_active = false

# ── 10.11 register：缺少 capture_snapshot → push_error + 拒绝注册 ────────────
func test_register_missing_capture_snapshot_rejects_node() -> void:
	var bad := BadNode.new()
	tm.register(bad)
	assert_push_error_count(1, "缺少 capture_snapshot 时应调用 push_error 一次")
	assert_eq(tm._registry.size(), 0,
		"缺少 capture_snapshot 的对象不应被加入 _registry")

# ── 10.12 register：重复 rewind_id → push_error + 拒绝二次注册 ──────────────
func test_register_duplicate_rewind_id_rejects_second() -> void:
	var mock_a := MockRewindable.new()
	mock_a.rewind_id = "test/dup"
	var mock_b := MockRewindable.new()
	mock_b.rewind_id = "test/dup"

	tm.register(mock_a)
	assert_eq(tm._registry.size(), 1, "第一次注册应成功")

	tm.register(mock_b)
	assert_push_error_count(1, "重复 rewind_id 应调用 push_error 一次")
	assert_eq(tm._registry.size(), 1, "重复 rewind_id 不应增加 _registry 大小")

# ── 10.13 post_tick 积累快照 ──────────────────────────────────────────────────
func test_post_tick_accumulates_snapshot() -> void:
	var mock := MockRewindable.new()
	mock.rewind_id = "test/a"
	tm._registry.append(mock)

	tm.post_tick()

	assert_eq(tm._valid_frame_count, 1, "_valid_frame_count 应为 1")
	var frame: Dictionary = tm._buffer[0]
	assert_true(frame != null, "buffer[0] 应已写入快照帧")
	assert_true("test/a" in frame["snapshots"],
		"快照帧应包含 rewind_id='test/a' 的条目")

# ── 10.14 失效区域内 post_tick 不积累 ────────────────────────────────────────
func test_post_tick_skips_in_rewind_free_zone() -> void:
	var mock := MockRewindable.new()
	tm._registry.append(mock)
	tm.in_rewind_free_zone = true

	tm.post_tick()

	assert_eq(tm._valid_frame_count, 0,
		"失效区域内 post_tick 不应写入帧，_valid_frame_count 应为 0")

# ── 10.15 CE 消耗——回溯状态（12 CE/s） ────────────────────────────────────────
func test_ce_drain_during_rewind() -> void:
	tm.ce            = 100.0
	tm.is_rewinding  = true
	tm._ce_cooldown_timer = 0.0

	tm._tick_ce(1.0)

	assert_almost_eq(tm.ce, 88.0, 0.001,
		"回溯时 CE 应减少 12/s，实际: %f" % tm.ce)

# ── 10.16 CE 消耗——慢动作状态（10 CE/s） ──────────────────────────────────────
func test_ce_drain_during_slow_motion() -> void:
	tm.ce               = 100.0
	tm._is_slow_motion  = true
	tm._ce_cooldown_timer = 0.0

	tm._tick_ce(1.0)

	assert_almost_eq(tm.ce, 90.0, 0.001,
		"慢动作时 CE 应减少 10/s，实际: %f" % tm.ce)

# ── 10.17 CE 恢复——无消耗基础速率（5 CE/s） ──────────────────────────────────
func test_ce_recovers_at_base_rate_when_idle() -> void:
	tm.ce                 = 50.0
	tm.is_rewinding       = false
	tm._is_slow_motion    = false
	tm._is_time_rush      = false
	tm._active_lcf_count  = 0
	tm._ce_cooldown_timer = 0.0

	tm._tick_ce(1.0)

	assert_almost_eq(tm.ce, 55.0, 0.001,
		"空闲时 CE 应以 5/s 回复，实际: %f" % tm.ce)

# ── 10.18 CE 零重力 3× 加成（15 CE/s） ────────────────────────────────────────
func test_ce_recovers_at_triple_rate_in_zero_gravity() -> void:
	tm.ce                 = 50.0
	tm.is_rewinding       = false
	tm._is_slow_motion    = false
	tm._is_time_rush      = false
	tm._active_lcf_count  = 0
	tm._ce_cooldown_timer = 0.0
	# 通过全局 GravityManager 注入零重力加成标志
	GravityManager._zero_g_bonus_active = true

	tm._tick_ce(1.0)

	assert_almost_eq(tm.ce, 65.0, 0.001,
		"零重力 3× 加成时 CE 应回复 15/s，实际: %f" % tm.ce)

# ── 10.19 CE 消耗与恢复互斥（回溯 + 零重力加成不叠加） ───────────────────────
func test_ce_drain_takes_priority_over_zero_g_bonus() -> void:
	tm.ce                 = 100.0
	tm.is_rewinding       = true
	tm._ce_cooldown_timer = 0.0
	GravityManager._zero_g_bonus_active = true

	tm._tick_ce(1.0)

	# 应走消耗分支（12/s），不触发 3× 回复
	assert_almost_eq(tm.ce, 88.0, 0.001,
		"消耗分支优先：CE 应按 12/s 减少而非触发 3× 回复，实际: %f" % tm.ce)

# ── 10.20 CE 耗尽触发强制中断 ────────────────────────────────────────────────
func test_ce_exhausted_cancels_all_time_effects() -> void:
	tm.ce                 = 5.0
	tm.is_rewinding       = true
	tm._ce_cooldown_timer = 0.0

	tm._tick_ce(1.0)  # 5 - 12 < 0 → ce=0，触发 _on_ce_exhausted

	assert_almost_eq(tm.ce, 0.0, 0.001, "CE 应降至 0")
	assert_false(tm.is_rewinding, "CE 耗尽后 is_rewinding 应为 false")
	assert_eq(tm.time_scale, 1.0, "CE 耗尽后 time_scale 应重置为 1.0")
	assert_true(tm._ce_cooldown_timer > 0.0,
		"CE 耗尽后应启动冷却计时器")

# ── 10.21 enter_rewind_free_zone 清空 Buffer 并回满 CE ───────────────────────
func test_enter_rewind_free_zone_clears_buffer_and_refills_ce() -> void:
	# 手动写入 10 帧虚假快照
	var mock := MockRewindable.new()
	tm._registry.append(mock)
	for i in range(10):
		tm.post_tick()
	assert_eq(tm._valid_frame_count, 10, "前提：_valid_frame_count 应为 10")

	tm.ce = 30.0
	tm.enter_rewind_free_zone()

	assert_eq(tm._valid_frame_count, 0,
		"进入失效区域后 _valid_frame_count 应清零")
	assert_eq(tm.ce, tm.ce_max,
		"进入失效区域后 CE 应回满至 ce_max(%f)" % tm.ce_max)
	assert_true(tm.in_rewind_free_zone,
		"in_rewind_free_zone 应为 true")

# ── 10.22 get_time_scale_at MVP stub 返回全局倍率 ────────────────────────────
func test_get_time_scale_at_returns_global_time_scale() -> void:
	tm.time_scale = 0.5

	var result: float = tm.get_time_scale_at(Vector2(999.0, 999.0))

	assert_eq(result, 0.5,
		"MVP stub 应忽略位置，直接返回当前 time_scale(0.5)，实际: %f" % result)
