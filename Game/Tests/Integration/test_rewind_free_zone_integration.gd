extends IntegrationTestBase
## 失效区域（Rewind-Free Zone）集成测试（11.12 – 11.14）

func before_each() -> void:
	super.before_each()

func after_each() -> void:
	super.after_each()

# ── 11.12 进入失效区域中断正在进行的回溯 ─────────────────────────────────────
func test_enter_rewind_free_zone_stops_active_rewind() -> void:
	# 手动制造回溯状态（写入几帧再启动回溯）
	var mock := MockRewindable.new()
	mock.rewind_id = "test/rfz-stop"
	TimeManager.register(mock)

	_write_frame(0.0)
	_write_frame(0.016)
	_start_rewind_from_latest()
	assert_true(TimeManager.is_rewinding, "前提：is_rewinding 应为 true")

	# 触发失效区域
	TimeManager.enter_rewind_free_zone()

	assert_false(TimeManager.is_rewinding,
		"进入失效区域应中断回溯，is_rewinding 应变为 false")
	assert_eq(TimeManager._valid_frame_count, 0,
		"进入失效区域应清空 Ring Buffer，_valid_frame_count 应为 0")
	assert_almost_eq(TimeManager.ce, TimeManager.ce_max, 0.001,
		"进入失效区域后 CE 应回满至 ce_max，实际: %f" % TimeManager.ce)

	TimeManager.unregister(mock)

# ── 11.13 失效区域内无法触发回溯 ─────────────────────────────────────────────
func test_cannot_start_rewind_inside_rewind_free_zone() -> void:
	TimeManager.in_rewind_free_zone = true
	TimeManager._valid_frame_count  = 5   # 假装有历史帧

	var ce_before: float = TimeManager.ce

	# 直接调用 TimeSkillComponent.try_start_rewind 的逻辑路径
	var tsc := preload("res://Scripts/Components/TimeSkillComponent.gd").new()
	tsc.try_start_rewind()

	assert_false(TimeManager.is_rewinding,
		"失效区域内 try_start_rewind 不应触发回溯")
	assert_almost_eq(TimeManager.ce, ce_before, 0.001,
		"CE 不应因失效区域内的触发尝试而变化")

	tsc.free()

# ── 11.14 离开失效区域后 Ring Buffer 重新积累 ─────────────────────────────────
func test_buffer_resumes_after_exiting_rewind_free_zone() -> void:
	var mock := MockRewindable.new()
	mock.rewind_id = "test/rfz-resume"
	TimeManager.register(mock)

	# 进入失效区域：任何 post_tick 都应被忽略
	TimeManager.enter_rewind_free_zone()
	_write_frame(0.016)
	assert_eq(TimeManager._valid_frame_count, 0,
		"失效区域内 post_tick 不应写入帧")

	# 离开失效区域
	TimeManager.exit_rewind_free_zone()

	# 写入 5 帧
	for i in range(5):
		_write_frame((i + 1) * 0.016)

	assert_eq(TimeManager._valid_frame_count, 5,
		"离开失效区域后应正常积累 5 帧，_valid_frame_count 应为 5")

	TimeManager.unregister(mock)
