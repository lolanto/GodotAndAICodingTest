extends IntegrationTestBase
## LGF 优先级与回溯集成测试（11.9 – 11.11）

func before_each() -> void:
	super.before_each()

func after_each() -> void:
	super.after_each()

# ── 11.9 LGF 放置后 get_gravity_at 覆盖全局重力 ───────────────────────────────
func test_lgf_overrides_global_gravity_at_position() -> void:
	GravityManager.direction = Vector2.DOWN
	GravityManager.magnitude = 1.0

	var lgf := MockLGF.new()
	lgf.active          = true
	lgf.direction       = Vector2.LEFT
	lgf.magnitude       = 2.0
	lgf.blend_factor    = 0.0    # 完全覆盖
	lgf._should_overlap = true
	GravityManager.register_lgf(lgf)

	var result: Vector2 = GravityManager.get_gravity_at(Vector2.ZERO)
	# lerp(LEFT*2, DOWN*1, 0) = LEFT*2
	assert_eq(result, Vector2.LEFT * 2.0,
		"活跃 LGF 应完全覆盖全局重力，结果应为 %v，实际: %v" % [Vector2.LEFT * 2.0, result])

	GravityManager.unregister_lgf(lgf)

# ── 11.10 LGF 放置后回溯还原为放置前状态 ─────────────────────────────────────
func test_lgf_restored_to_inactive_after_rewind() -> void:
	var lgf := MockLGF.new()
	lgf.rewind_id = "test/lgf-rewind"
	lgf.active    = false
	TimeManager.register(lgf)
	GravityManager.register_lgf(lgf)

	# 帧0：lgf inactive
	_write_frame(0.0)

	# 激活 LGF
	lgf.active = true

	# 帧1-2：lgf active
	_write_frame(0.016)
	_write_frame(0.032)

	# 从最新帧回溯到最早帧（lgf 为 inactive 时）
	_start_rewind_from_latest()
	TimeManager.pre_tick(1.0)

	assert_false(lgf.active,
		"回溯后 LGF 应还原为 active=false（放置前状态）")

	TimeManager.unregister(lgf)
	GravityManager.unregister_lgf(lgf)

# ── 11.11 槽位复用——回溯后 placement_order 精确还原 ──────────────────────────
func test_lgf_placement_order_restored_after_rewind() -> void:
	var lgf := MockLGF.new()
	lgf.rewind_id       = "test/lgf-order"
	lgf.active          = false
	lgf.placement_order = 0
	TimeManager.register(lgf)
	GravityManager.register_lgf(lgf)

	# 帧0：inactive，order=0（放置前基准）
	_write_frame(0.0)

	# 第一次激活：Slot0 order=1
	lgf.active          = true
	lgf.placement_order = 1
	_write_frame(0.016)

	# 到期失效：order 不变，active=false
	lgf.active = false
	_write_frame(0.032)

	# 第二次激活：order=4（复用槽位）
	lgf.active          = true
	lgf.placement_order = 4
	_write_frame(0.048)  # 帧3（最新帧）

	# 回溯到帧0（放置前：active=false，order=0）
	_start_rewind_from_latest()
	TimeManager.pre_tick(1.0)

	assert_false(lgf.active,
		"回溯后 active 应还原为 false")
	assert_eq(lgf.placement_order, 0,
		"回溯后 placement_order 应还原为 0（放置前值），实际: %d" % lgf.placement_order)

	TimeManager.unregister(lgf)
	GravityManager.unregister_lgf(lgf)
