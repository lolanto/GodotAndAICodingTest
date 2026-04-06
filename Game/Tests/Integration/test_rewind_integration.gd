extends IntegrationTestBase
## Ring Buffer 回溯集成测试（11.1 – 11.5）

func before_each() -> void:
	super.before_each()

func after_each() -> void:
	super.after_each()

# ── 11.1 回溯还原玩家位置 ──────────────────────────────────────────────────────
func test_rewind_restores_player_position() -> void:
	var body := MockRewindable.new()
	body.rewind_id = "test/body-pos"
	TimeManager.register(body)

	body.position = Vector2(0.0, 0.0)
	_write_frame(0.0)           # 帧0：P0

	body.position = Vector2(100.0, 0.0)
	_write_frame(0.016)         # 帧1：P1

	body.position = Vector2(200.0, 0.0)
	_write_frame(0.032)         # 帧2：P2（当前）

	# 从最新帧开始回溯，预算 2.0s >> 0.032s，一次 pre_tick 可回溯到最早帧
	_start_rewind_from_latest()
	TimeManager.pre_tick(1.0)

	assert_almost_eq(body.position.x, 0.0, 1.0,
		"回溯后位置应还原为 P0，实际: %v" % body.position)

	TimeManager.unregister(body)

# ── 11.2 回溯还原 GE 值 ────────────────────────────────────────────────────────
func test_rewind_restores_ge() -> void:
	# GravityManager 已在 _registry 中，capture_snapshot 会保存 ge
	GravityManager.ge = 100.0
	_write_frame(0.0)   # 帧0：ge=100

	GravityManager.ge = 70.0
	_write_frame(0.016) # 帧1：ge=70

	GravityManager.ge = 40.0
	_write_frame(0.032) # 帧2：ge=40（当前）

	_start_rewind_from_latest()
	TimeManager.pre_tick(1.0)   # 回溯到帧0

	assert_almost_eq(GravityManager.ge, 100.0, 1.0,
		"回溯后 GE 应还原为 100，实际: %f" % GravityManager.ge)

# ── 11.3 回溯期间玩家输入被锁定 ───────────────────────────────────────────────
func test_input_locked_while_rewinding() -> void:
	# PlayerInputComponent.get_move_input() 和 _unhandled_input() 都检查
	# TimeManager.is_rewinding，返回 Vector2.ZERO / 提前 return
	TimeManager.is_rewinding = true

	# 使用真实 PlayerInputComponent 脚本验证
	var pic := preload("res://Scripts/Components/PlayerInputComponent.gd").new()
	# 不加入场景树，直接调用 get_move_input
	var move := pic.get_move_input()

	assert_eq(move, Vector2.ZERO,
		"回溯中 get_move_input 应返回 Vector2.ZERO")

	pic.free()
	TimeManager.is_rewinding = false

# ── 11.4 Ring Buffer 满后旧帧被覆盖，上限 = MAX_FRAMES ───────────────────────
func test_ring_buffer_clamps_to_max_frames() -> void:
	var mock := MockRewindable.new()
	mock.rewind_id = "test/buf-overflow"
	TimeManager.register(mock)

	# 写入 MAX_FRAMES + 1 帧
	var total := TimeManager.MAX_FRAMES + 1
	for i in range(total):
		_write_frame(i * 0.016)

	assert_eq(TimeManager._valid_frame_count, TimeManager.MAX_FRAMES,
		"写入 %d 帧后 _valid_frame_count 应钳制在 MAX_FRAMES=%d" % [total, TimeManager.MAX_FRAMES])

	TimeManager.unregister(mock)

# ── 11.5 回溯耗尽有效帧后自动停止 ────────────────────────────────────────────
func test_rewind_auto_stops_when_buffer_exhausted() -> void:
	var mock := MockRewindable.new()
	mock.rewind_id = "test/exhaust"
	TimeManager.register(mock)

	# 仅积累 10 帧历史
	for i in range(10):
		mock.position = Vector2(i * 10.0, 0.0)
		_write_frame(i * 0.016)

	_start_rewind_from_latest()
	assert_true(TimeManager.is_rewinding, "前提：is_rewinding 应为 true")

	# 第 1 次 pre_tick：budget=20s >> 0.144s，遍历所有帧；
	# 到达最老帧时 prev=null → _valid_frame_count=0
	TimeManager.pre_tick(10.0)

	# 第 2 次 pre_tick：检测到 _valid_frame_count==0 → is_rewinding=false
	TimeManager.pre_tick(0.016)

	assert_false(TimeManager.is_rewinding,
		"回溯耗尽有效帧后 is_rewinding 应自动变为 false")

	TimeManager.unregister(mock)
