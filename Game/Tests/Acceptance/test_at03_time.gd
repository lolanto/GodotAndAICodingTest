extends IntegrationTestBase
## AT-03 时间系统验收测试（12.5 – 12.9）
##
## 注：12.5/12.6/12.10 使用模拟时间步进（120帧 × 1/60s = 2s）
## 以保证测试速度快且结果确定性高，等价于"等待 2 真实秒"。

func before_each() -> void:
	super.before_each()

func after_each() -> void:
	super.after_each()

## 工具：模拟 N 秒的 CE tick（在测试内替代真实等待）
func _simulate_ce_seconds(seconds: float) -> void:
	var frames := int(seconds * 60.0)
	var frame_dt := 1.0 / 60.0
	for _i in range(frames):
		TimeManager._tick_ce(frame_dt)

# ── 12.5 AT-03a 慢动作 CE 消耗率（10 CE/s × 2s ≈ 20） ────────────────────────
func test_at03a_slow_motion_ce_drain_rate() -> void:
	TimeManager.ce                = 100.0
	TimeManager._is_slow_motion   = true
	TimeManager._ce_cooldown_timer = 0.0

	_simulate_ce_seconds(2.0)

	var drained: float = 100.0 - TimeManager.ce
	assert_almost_eq(drained, 20.0, 2.0,
		"慢动作 2s CE 消耗应约为 20（±2），实际消耗: %.2f" % drained)

# ── 12.6 AT-03b 时间加速 CE 消耗率（5 CE/s × 2s ≈ 10） ──────────────────────
func test_at03b_time_rush_ce_drain_rate() -> void:
	TimeManager.ce                = 100.0
	TimeManager._is_time_rush     = true
	TimeManager._ce_cooldown_timer = 0.0

	_simulate_ce_seconds(2.0)

	var drained: float = 100.0 - TimeManager.ce
	assert_almost_eq(drained, 10.0, 2.0,
		"时间加速 2s CE 消耗应约为 10（±2），实际消耗: %.2f" % drained)

# ── 12.7 ★ 回溯视觉蓝色滤镜（手动） ─────────────────────────────────────────
func test_at03c_rewind_blue_filter_visual() -> void:
	pending("【手动 ★】在 SkillTestLab 中按住 R 键触发时间回溯\n"
		+ "确认：\n"
		+ "  · 画面出现蓝色滤镜覆盖层\n"
		+ "  · 玩家和木箱的运动轨迹反向播放\n"
		+ "  · HUD 显示「REWINDING」回溯状态标识\n"
		+ "  · 松开 R 键后蓝色滤镜消失，时间恢复正常")

# ── 12.8 AT-03d 回溯还原木箱位置（模拟 3s 历史） ────────────────────────────
func test_at03d_rewind_restores_crate_position() -> void:
	# 用 MockRewindable 模拟场景中的木箱
	var crate := MockRewindable.new()
	crate.rewind_id = "test/crate-at"
	TimeManager.register(crate)

	# 写入 3 秒历史（180 帧 × 0.016s）：
	# 前 60 帧：木箱静止在初始位置 P0=(0,0)
	# 中 60 帧：木箱被推动，匀速移动到 P1=(100,0)
	# 后 60 帧：木箱停在 P1
	var initial_pos := Vector2(0.0, 0.0)
	for i in range(180):
		if i < 60:
			crate.position = initial_pos
		elif i < 120:
			crate.position = Vector2(lerp(0.0, 100.0, (i - 60) / 60.0), 0.0)
		else:
			crate.position = Vector2(100.0, 0.0)
		_write_frame(i * 0.016)

	assert_almost_eq(crate.position.x, 100.0, 0.001, "前提：当前位置应为 P1=100")

	# 触发回溯，倒回到最初帧（P0）
	_start_rewind_from_latest()
	TimeManager.pre_tick(10.0)  # 预算远大于 3s 历史，一次性回溯到底

	assert_almost_eq(crate.position.x, initial_pos.x, 5.0,
		"回溯后木箱位置应接近初始位置 P0（误差 ≤ 5px），实际: %.2f" % crate.position.x)

	TimeManager.unregister(crate)

# ── 12.9 AT-03e CE 耗尽自动停止所有时间技能 ──────────────────────────────────
func test_at03e_ce_exhaustion_cancels_all_time_effects() -> void:
	# 激活慢动作
	TimeManager._is_slow_motion   = true
	TimeManager.time_scale        = TimeManager.MIN_TIME_SCALE  # 0.5
	TimeManager.ce                = 3.0   # 极少 CE，约 0.3s 内耗尽
	TimeManager._ce_cooldown_timer = 0.0

	# 触发 CE 耗尽（一次 tick 消耗 10×(1/60)≈0.167 CE，20 次后 CE≈0）
	for _i in range(30):
		TimeManager._tick_ce(1.0 / 60.0)
		if TimeManager.ce == 0.0:
			break

	assert_almost_eq(TimeManager.ce, 0.0, 0.001,
		"CE 应耗尽为 0，实际: %f" % TimeManager.ce)
	assert_false(TimeManager._is_slow_motion,
		"CE 耗尽后 _is_slow_motion 应自动变为 false")
	assert_almost_eq(TimeManager.time_scale, 1.0, 0.001,
		"CE 耗尽后 time_scale 应恢复为 1.0，实际: %f" % TimeManager.time_scale)
	assert_true(TimeManager._ce_cooldown_timer > 0.0,
		"CE 耗尽后冷却计时器应被激活")
