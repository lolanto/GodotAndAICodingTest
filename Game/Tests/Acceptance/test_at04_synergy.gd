extends IntegrationTestBase
## AT-04 系统联动验收测试（12.10 – 12.11）

func before_each() -> void:
	super.before_each()

func after_each() -> void:
	super.after_each()

## 工具：模拟 N 秒的 CE tick
func _simulate_ce_seconds(seconds: float) -> void:
	var frames := int(seconds * 60.0)
	var frame_dt := 1.0 / 60.0
	for _i in range(frames):
		TimeManager._tick_ce(frame_dt)

# ── 12.10 AT-04a 零重力 3× CE 加成端到端（模拟 2s） ─────────────────────────
func test_at04a_zero_g_ce_triple_bonus_over_2_seconds() -> void:
	# 激活零重力加成（模拟已持续 3s 零重力）
	GravityManager.magnitude         = 0.0
	GravityManager._target_magnitude = 0.0
	GravityManager._mag_interp_t     = 1.0
	GravityManager.tick(3.0)  # 触发 _zero_g_bonus_active = true

	assert_true(GravityManager._zero_g_bonus_active,
		"前提：3s 零重力后 _zero_g_bonus_active 应为 true")

	# 初始 CE = 50，无任何时间技能，空闲状态回复 15 CE/s
	TimeManager.ce                = 50.0
	TimeManager.is_rewinding      = false
	TimeManager._is_slow_motion   = false
	TimeManager._is_time_rush     = false
	TimeManager._active_lcf_count = 0
	TimeManager._ce_cooldown_timer = 0.0

	_simulate_ce_seconds(2.0)

	# 期望 CE 增加约 30（15/s × 2s），允许 ±3 误差
	var recovered: float = TimeManager.ce - 50.0
	assert_almost_eq(recovered, 30.0, 3.0,
		"零重力 3× 加成 2s 内 CE 应回复约 30（±3），实际回复: %.2f" % recovered)

# ── 12.11 ★ 引力时间膨胀视觉验收（手动） ─────────────────────────────────────
func test_at04b_gravity_time_dilation_visual() -> void:
	pending("【手动 ★】在 SkillTestLab 中通过调试命令设置 GravityManager.set_magnitude(3.0)\n"
		+ "确认：\n"
		+ "  · 玩家下落速度明显变慢（引力膨胀效果）\n"
		+ "  · HUD time_scale 显示值 < 1.0\n"
		+ "  · 理论值：magnitude=3 → time_scale = 1/√3 ≈ 0.577（GDD §6.3）\n"
		+ "  · 记录实际 HUD 数值并与理论值比对（允许 ±0.05 误差）")
