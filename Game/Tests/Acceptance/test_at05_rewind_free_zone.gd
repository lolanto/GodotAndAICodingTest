extends IntegrationTestBase
## AT-05 失效区域端到端验收测试（12.12）

func before_each() -> void:
	super.before_each()

func after_each() -> void:
	super.after_each()

# ── 12.12 AT-05 进出失效区域完整流程 ─────────────────────────────────────────
func test_at05_enter_and_exit_rewind_free_zone_full_flow() -> void:
	var mock := MockRewindable.new()
	mock.rewind_id = "test/at05-mock"
	TimeManager.register(mock)

	# ── Phase 1: 失效区域前，正常积累帧 ────────────────────────────────────
	TimeManager.ce                 = 60.0
	TimeManager.in_rewind_free_zone = false

	for i in range(10):
		_write_frame(i * 0.016)

	assert_eq(TimeManager._valid_frame_count, 10,
		"前提：进入失效区域前应已积累 10 帧")

	# ── Phase 2: 进入失效区域 ───────────────────────────────────────────────
	TimeManager.enter_rewind_free_zone()

	assert_true(TimeManager.in_rewind_free_zone,
		"进入失效区域后 in_rewind_free_zone 应为 true")
	assert_eq(TimeManager._valid_frame_count, 0,
		"进入失效区域后 Ring Buffer 应清空（_valid_frame_count=0）")
	assert_almost_eq(TimeManager.ce, TimeManager.ce_max, 0.001,
		"进入失效区域后 CE 应回满，实际: %f" % TimeManager.ce)
	assert_false(TimeManager.is_rewinding,
		"进入失效区域后回溯应被强制停止")

	# 失效区域内 post_tick 不应写入帧
	for i in range(5):
		_write_frame((10 + i) * 0.016)

	assert_eq(TimeManager._valid_frame_count, 0,
		"失效区域内 post_tick 不应写入帧，_valid_frame_count 应保持 0")

	# ── Phase 3: 离开失效区域 ───────────────────────────────────────────────
	TimeManager.exit_rewind_free_zone()

	assert_false(TimeManager.in_rewind_free_zone,
		"离开失效区域后 in_rewind_free_zone 应为 false")

	# 离开后正常积累 5 帧
	for i in range(5):
		_write_frame((15 + i) * 0.016)

	assert_eq(TimeManager._valid_frame_count, 5,
		"离开失效区域后 Ring Buffer 应重新积累 5 帧，_valid_frame_count 应为 5")

	TimeManager.unregister(mock)
