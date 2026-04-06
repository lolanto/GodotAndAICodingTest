extends IntegrationTestBase
## AT-02 重力系统验收测试（12.2 – 12.4）

func before_each() -> void:
	super.before_each()

func after_each() -> void:
	super.after_each()

# ── 12.2 ★ 四方向重力可视验证（手动） ────────────────────────────────────────
func test_at02a_four_direction_gravity_visual() -> void:
	pending("【手动 ★】在 SkillTestLab 中依次按 S/W/A/D 切换重力方向\n"
		+ "确认：\n"
		+ "  · 每次切换后玩家向对应方向加速下落\n"
		+ "  · 玩家被对应边界正确阻挡，无穿模\n"
		+ "  · GE 每次方向切换减少 15，HUD 数值同步更新")

# ── 12.3 AT-02b GE 消耗与方向切换冷却 ────────────────────────────────────────
func test_at02b_ge_consumed_and_cooldown_prevents_rapid_switch() -> void:
	# 确保初始状态：满 GE、无冷却、方向为 DOWN
	GravityManager.ge                   = 100.0
	GravityManager._direction_cooldown_timer = 0.0
	GravityManager.direction            = Vector2.DOWN

	# 第一次切换：DOWN → UP，GE 减少 DIRECTION_SWITCH_COST
	GravityManager.set_direction(Vector2.UP)

	assert_eq(GravityManager.direction, Vector2.UP,
		"第一次切换应成功，direction 应变为 UP")
	assert_almost_eq(GravityManager.ge, 100.0 - GravityManager.DIRECTION_SWITCH_COST, 0.001,
		"切换后 GE 应减少 DIRECTION_SWITCH_COST，实际: %f" % GravityManager.ge)
	assert_true(GravityManager._direction_cooldown_timer > 0.0,
		"切换后冷却计时器应 > 0")

	# 冷却期内立即再切换：应被拒绝
	GravityManager.set_direction(Vector2.LEFT)
	assert_eq(GravityManager.direction, Vector2.UP,
		"冷却期内切换应被拒绝，direction 应保持 UP")

	# 跳过冷却（tick 超过 DIRECTION_COOLDOWN=1.5s）
	GravityManager._direction_cooldown_timer = 0.0

	# 再次切换：应成功
	GravityManager.set_direction(Vector2.LEFT)
	assert_eq(GravityManager.direction, Vector2.LEFT,
		"冷却结束后切换应成功，direction 应变为 LEFT")

# ── 12.4 AT-02c LGF 放置后局部重力指向上方 ───────────────────────────────────
func test_at02c_lgf_changes_local_gravity_to_up() -> void:
	# 全局重力为 DOWN
	GravityManager.direction = Vector2.DOWN
	GravityManager.magnitude = 1.0

	# 放置指向 UP、完全覆盖（blend_factor=0）的 LGF
	var lgf := MockLGF.new()
	lgf.active          = true
	lgf.direction       = Vector2.UP
	lgf.magnitude       = 1.0
	lgf.blend_factor    = 0.0
	lgf._should_overlap = true
	GravityManager.register_lgf(lgf)

	# 查询玩家位置处的重力
	var gravity: Vector2 = GravityManager.get_gravity_at(Vector2.ZERO)

	assert_true(gravity.y < 0.0,
		"LGF=UP 时局部重力 y 分量应 < 0（向上），实际: %v" % gravity)
	assert_eq(gravity, Vector2.UP * 1.0,
		"局部重力应等于 Vector2.UP * 1.0，实际: %v" % gravity)

	GravityManager.unregister_lgf(lgf)
