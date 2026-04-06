extends IntegrationTestBase
## GravityManager ↔ TimeManager 联动集成测试（11.6 – 11.8）

func before_each() -> void:
	super.before_each()

func after_each() -> void:
	super.after_each()

# ── 共用：强制进入零重力状态并积累 3 秒 ──────────────────────────────────────
func _activate_zero_g_bonus() -> void:
	GravityManager.magnitude         = 0.0
	GravityManager._target_magnitude = 0.0
	GravityManager._mag_interp_t     = 1.0
	GravityManager.tick(3.0)  # _zero_g_timer += 3.0 → _zero_g_bonus_active = true

# ── 11.6 零重力 3× CE 加成端到端 ──────────────────────────────────────────────
func test_zero_g_ce_bonus_end_to_end() -> void:
	_activate_zero_g_bonus()
	assert_true(GravityManager._zero_g_bonus_active,
		"前提：3s 零重力后 _zero_g_bonus_active 应为 true")

	TimeManager.ce                = 50.0
	TimeManager.is_rewinding      = false
	TimeManager._is_slow_motion   = false
	TimeManager._is_time_rush     = false
	TimeManager._active_lcf_count = 0
	TimeManager._ce_cooldown_timer = 0.0

	TimeManager._tick_ce(1.0)

	assert_almost_eq(TimeManager.ce, 65.0, 0.001,
		"零重力 3× 加成：1s 内 CE 应从 50 回复至 65（+15），实际: %f" % TimeManager.ce)

# ── 11.7 使用时间技能时零重力加成不触发 ───────────────────────────────────────
func test_zero_g_bonus_suppressed_when_slow_motion_active() -> void:
	_activate_zero_g_bonus()
	assert_true(GravityManager._zero_g_bonus_active, "前提：加成应已激活")

	TimeManager.ce                = 100.0
	TimeManager._is_slow_motion   = true   # 慢动作：10 CE/s 消耗
	TimeManager._ce_cooldown_timer = 0.0

	TimeManager._tick_ce(1.0)

	# 慢动作消耗分支优先，CE 减少 10，而非零重力加成回复 +15
	assert_almost_eq(TimeManager.ce, 90.0, 0.001,
		"慢动作激活时应走消耗分支（−10 CE/s），实际: %f" % TimeManager.ce)

# ── 11.8 引力时间膨胀写入 time_scale ──────────────────────────────────────────
func test_gravity_time_dilation_writes_time_scale() -> void:
	# 将目标强度设为 3.0 并完成插值
	GravityManager.set_magnitude(3.0)
	GravityManager.tick(0.3)  # 0.3s > MAG_INTERP_DURATION=0.2s，插值完成

	assert_almost_eq(GravityManager.magnitude, 3.0, 0.001,
		"前提：插值应完成，magnitude 应为 3.0")

	# 预期 time_scale = 1/sqrt(3)，钳制到 [0.5, 2.0]
	var expected: float = clampf(
		1.0 / maxf(sqrt(GravityManager.magnitude), 0.3),
		TimeManager.MIN_TIME_SCALE,
		TimeManager.MAX_TIME_SCALE
	)  # ≈ 0.577

	assert_almost_eq(TimeManager.time_scale, expected, 0.001,
		"magnitude=3 时 time_scale 应为 ≈%.3f（引力时间膨胀），实际: %f" % [expected, TimeManager.time_scale])
