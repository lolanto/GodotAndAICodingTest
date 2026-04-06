extends GutTest
## GravityManager 单元测试（10.1 – 10.10）
##
## 每个测试实例化一个独立的 GravityManager（不触发 _ready，
## 因此不向全局 TimeManager 注册），直接测试纯业务逻辑。
## tick() 内部会写入全局 TimeManager.time_scale，
## after_each 中负责恢复该全局状态。

const GravityManagerScript = preload("res://Scripts/Autoloads/GravityManager.gd")

var gm  # 每个测试的独立实例

# ── Mock LGF ──────────────────────────────────────────────────────────────────
# 仅实现 get_gravity_at() 和 tick() 所需的最小接口
class MockLGF extends RefCounted:
	var active: bool          = true
	var source: String        = "player_skill"
	var direction: Vector2    = Vector2.RIGHT
	var magnitude: float      = 2.0
	var blend_factor: float   = 0.0
	var placement_order: int  = 1
	var _should_overlap: bool = true

	func overlaps_point(_pos: Vector2) -> bool:
		return _should_overlap

# ── Setup / Teardown ──────────────────────────────────────────────────────────
func before_each() -> void:
	gm = GravityManagerScript.new()
	# _ready() 未调用 → TimeManager.register(self) 未调用
	# 手动复位全局 TimeManager 到已知状态
	TimeManager.time_scale       = 1.0
	TimeManager._is_slow_motion  = false
	TimeManager._is_time_rush    = false

func after_each() -> void:
	gm.free()
	# 恢复全局 TimeManager 状态
	TimeManager.time_scale      = 1.0
	TimeManager._is_slow_motion = false
	TimeManager._is_time_rush   = false

# ── 10.1 GE 初始值 ────────────────────────────────────────────────────────────
func test_ge_initial_values() -> void:
	assert_eq(gm.ge,     100.0, "ge 初始值应为 100")
	assert_eq(gm.ge_max, 100.0, "ge_max 初始值应为 100")

# ── 10.2 方向瞬切 ─────────────────────────────────────────────────────────────
func test_direction_instant_switch() -> void:
	# 确保有足够 GE 且无冷却
	gm.ge = 100.0
	gm._direction_cooldown_timer = 0.0

	gm.set_direction(Vector2.RIGHT)

	assert_eq(gm.direction, Vector2.RIGHT, "方向应立即切换到 RIGHT")

# ── 10.3 强度插值（0.2s 内完成） ─────────────────────────────────────────────
func test_magnitude_linear_interpolation() -> void:
	gm.set_magnitude(0.0)

	# 第 1 帧（0.05s < 0.2s）：插值尚未完成
	gm.tick(0.05)
	assert_true(gm.magnitude > 0.0 and gm.magnitude < 1.0,
		"第1帧 magnitude 应处于插值中间值（0, 1）之间，实际: %f" % gm.magnitude)

	# 继续 4 帧（累积 0.25s > 0.2s）：插值应完成
	gm.tick(0.05)
	gm.tick(0.05)
	gm.tick(0.05)
	gm.tick(0.05)
	assert_almost_eq(gm.magnitude, 0.0, 0.001,
		"5帧后(0.25s) magnitude 应插值到 0.0，实际: %f" % gm.magnitude)

# ── 10.4 GE 消耗/恢复互斥 ────────────────────────────────────────────────────
func test_ge_drain_and_recover_mutex() -> void:
	gm.ge = 40.0  # 远离 ge_max(100)，避免回复时触发截断
	var mock_lgf := MockLGF.new()
	gm._lgf_registry.append(mock_lgf)

	# 有 LGF 时：GE 消耗
	gm.tick(1.0)
	var expected_ge_after_drain := 40.0 - GravityManagerScript.LGF_DRAIN_PER_SEC * 1.0
	assert_almost_eq(gm.ge, expected_ge_after_drain, 0.001,
		"有活跃 LGF 时 GE 应按 LGF_DRAIN_PER_SEC 扣除，实际: %f" % gm.ge)

	# 移除 LGF：GE 恢复
	gm._lgf_registry.erase(mock_lgf)
	var ge_before_recover: float = gm.ge
	gm.tick(1.0)
	assert_almost_eq(gm.ge, ge_before_recover + GravityManagerScript.GE_RECOVERY_RATE * 1.0, 0.001,
		"无活跃 LGF 时 GE 应按 GE_RECOVERY_RATE 回复，实际: %f" % gm.ge)

# ── 10.5 GE 不超过上限 ───────────────────────────────────────────────────────
func test_ge_does_not_exceed_max() -> void:
	gm.ge = 99.0
	# 无 LGF，大量 tick
	gm.tick(10.0)
	assert_eq(gm.ge, gm.ge_max, "GE 不应超过 ge_max(%f)" % gm.ge_max)

# ── 10.6 零重力计时器激活 ─────────────────────────────────────────────────────
func test_zero_gravity_bonus_activates_after_3_seconds() -> void:
	# 直接强制 magnitude = 0
	gm.magnitude         = 0.0
	gm._target_magnitude = 0.0
	gm._mag_interp_t     = 1.0

	gm.tick(1.0)
	assert_false(gm._zero_g_bonus_active, "1s 时尚未超过阈值，bonus 应为 false")

	gm.tick(1.0)
	assert_false(gm._zero_g_bonus_active, "2s 时尚未超过阈值，bonus 应为 false")

	gm.tick(1.0)
	assert_true(gm._zero_g_bonus_active, "累积 3s 后 _zero_g_bonus_active 应为 true")

# ── 10.7 零重力计时器重置 ─────────────────────────────────────────────────────
func test_zero_gravity_bonus_resets_on_nonzero_magnitude() -> void:
	# 先激活 bonus
	gm.magnitude         = 0.0
	gm._target_magnitude = 0.0
	gm._mag_interp_t     = 1.0
	gm._zero_g_timer     = 3.0
	gm._zero_g_bonus_active = true

	# 设置目标强度为 1.0（触发插值）
	gm.set_magnitude(1.0)
	# 推进 0.3s（> MAG_INTERP_DURATION=0.2s），插值完成
	gm.tick(0.3)

	assert_almost_eq(gm._zero_g_timer, 0.0, 0.001,
		"非零重力后 _zero_g_timer 应重置为 0，实际: %f" % gm._zero_g_timer)
	assert_false(gm._zero_g_bonus_active,
		"非零重力后 _zero_g_bonus_active 应为 false")

# ── 10.8 get_gravity_at 无 LGF ───────────────────────────────────────────────
func test_get_gravity_at_returns_global_when_no_lgf() -> void:
	gm.direction = Vector2.DOWN
	gm.magnitude = 1.5
	var result: Vector2 = gm.get_gravity_at(Vector2.ZERO)
	assert_eq(result, Vector2.DOWN * 1.5,
		"无活跃 LGF 时应返回 direction × magnitude")

# ── 10.9 get_gravity_at 后置优先级 ───────────────────────────────────────────
func test_get_gravity_at_uses_highest_placement_order() -> void:
	gm.direction = Vector2.DOWN
	gm.magnitude = 1.0

	# LGF A：order=1，指向 RIGHT
	var lgf_a := MockLGF.new()
	lgf_a.direction       = Vector2.RIGHT
	lgf_a.magnitude       = 1.0
	lgf_a.blend_factor    = 0.0
	lgf_a.placement_order = 1
	lgf_a._should_overlap = true

	# LGF B：order=3（后置），指向 UP
	var lgf_b := MockLGF.new()
	lgf_b.direction       = Vector2.UP
	lgf_b.magnitude       = 1.0
	lgf_b.blend_factor    = 0.0
	lgf_b.placement_order = 3
	lgf_b._should_overlap = true

	gm._lgf_registry.append(lgf_a)
	gm._lgf_registry.append(lgf_b)

	var result: Vector2 = gm.get_gravity_at(Vector2.ZERO)
	# blend_factor=0 → 完全采用 LGF 的重力，lerp(UP*1, DOWN*1, 0) = UP
	var expected := lgf_b.direction * lgf_b.magnitude  # Vector2.UP * 1.0
	assert_eq(result, expected,
		"后置优先：order=3 的 LGF 应主导，结果应为 %v，实际: %v" % [expected, result])

# ── 10.10 gravity_direction_changed 信号 ─────────────────────────────────────
func test_gravity_direction_changed_signal_emitted() -> void:
	gm.ge = 100.0
	gm._direction_cooldown_timer = 0.0
	gm.direction = Vector2.DOWN  # 确保初始方向不同于 UP

	watch_signals(gm)
	gm.set_direction(Vector2.UP)

	assert_signal_emitted(gm, "gravity_direction_changed",
		"set_direction 应发射 gravity_direction_changed 信号")
	assert_eq(gm.direction, Vector2.UP, "direction 应已切换为 UP")
