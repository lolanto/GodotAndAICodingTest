extends GutTest
## IRewindable / Component 单元测试（10.23 – 10.27）
##
## LGFNode   ：直接用 Script.new()（不触发 _ready，不注册 Autoload）
## MovementComponent：需加入场景树才能让 get_parent() 返回 CharacterBody2D
## HealthComponent：直接用 Script.new()，take_damage 读取全局 TimeManager

const LGFScript        = preload("res://Scripts/Components/LGFNode.gd")
const MovementScript   = preload("res://Scripts/Components/MovementComponent.gd")
const HealthScript     = preload("res://Scripts/Components/HealthComponent.gd")

# ── Setup / Teardown ──────────────────────────────────────────────────────────
func before_each() -> void:
	# 确保全局 TimeManager 回溯状态干净
	TimeManager.is_rewinding = false

func after_each() -> void:
	TimeManager.is_rewinding = false

# ─────────────────────────────────────────────────────────────────────────────
# LGFNode 快照测试
# ─────────────────────────────────────────────────────────────────────────────

# ── 10.23 LGFNode capture/apply 对称性 ───────────────────────────────────────
func test_lgfnode_capture_apply_symmetric() -> void:
	var lgf := LGFScript.new()
	# 注意：LGFNode 继承 Area2D，new() 不触发 _ready，不注册 Autoload

	# 设置所有参与快照的字段
	lgf.active          = true
	lgf.direction       = Vector2.LEFT
	lgf.magnitude       = 2.5
	lgf.blend_factor    = 0.3
	lgf.remaining_time  = 5.0
	lgf.placement_order = 7

	var snap := lgf.capture_snapshot()

	# 修改字段
	lgf.active          = false
	lgf.direction       = Vector2.DOWN
	lgf.magnitude       = 1.0
	lgf.blend_factor    = 0.0
	lgf.remaining_time  = -1.0
	lgf.placement_order = 0

	# 还原
	lgf.apply_snapshot(snap)

	assert_eq(lgf.active,          true,          "active 应还原为 true")
	assert_eq(lgf.direction,       Vector2.LEFT,  "direction 应还原为 LEFT")
	assert_almost_eq(lgf.magnitude,    2.5, 0.001, "magnitude 应还原为 2.5")
	assert_almost_eq(lgf.blend_factor, 0.3, 0.001, "blend_factor 应还原为 0.3")
	assert_almost_eq(lgf.remaining_time, 5.0, 0.001, "remaining_time 应还原为 5.0")
	assert_eq(lgf.placement_order, 7,             "placement_order 应还原为 7")

	# unlocked 不应出现在快照字典中
	assert_false("unlocked" in snap,
		"capture_snapshot 不应包含 'unlocked' 键")

	lgf.free()

# ── 10.24 LGFNode unlocked 不随 apply_snapshot 变更 ─────────────────────────
func test_lgfnode_unlocked_not_affected_by_apply_snapshot() -> void:
	var lgf := LGFScript.new()
	lgf.unlocked = true

	# 即使快照中包含 unlocked=false 的键，apply 也不应写入
	var snap_with_unlocked := {
		"active":          false,
		"direction":       Vector2.DOWN,
		"magnitude":       1.0,
		"blend_factor":    0.0,
		"remaining_time":  -1.0,
		"placement_order": 0,
		"unlocked":        false   # 不应被读取
	}

	lgf.apply_snapshot(snap_with_unlocked)

	assert_true(lgf.unlocked,
		"apply_snapshot 不应修改 unlocked 字段，应保持 true")

	lgf.free()

# ─────────────────────────────────────────────────────────────────────────────
# MovementComponent 快照测试
# ─────────────────────────────────────────────────────────────────────────────

# ── 10.25 MovementComponent apply_snapshot 直接赋值（不走物理模拟） ──────────
func test_movement_apply_snapshot_directly_assigns_position_and_velocity() -> void:
	# 需要场景树：让 get_parent() 返回 CharacterBody2D
	var body := CharacterBody2D.new()
	var mc   := MovementScript.new()
	# 使用唯一 rewind_id 避免与全局 registry 中已有条目冲突
	mc.rewind_id = "test/mc-unit-%d" % randi()

	add_child_autofree(body)
	body.add_child(mc)
	# 等待 _ready 执行（MovementComponent._ready 内有 await process_frame）
	await get_tree().process_frame

	var target_pos := Vector2(100.0, 200.0)
	var target_vel := Vector2(5.0, 0.0)

	mc.apply_snapshot({"position": target_pos, "velocity": target_vel})

	assert_eq(body.global_position, target_pos,
		"apply_snapshot 应直接赋值 global_position，实际: %v" % body.global_position)
	assert_eq(body.velocity, target_vel,
		"apply_snapshot 应直接赋值 velocity，实际: %v" % body.velocity)

# ─────────────────────────────────────────────────────────────────────────────
# HealthComponent 快照与伤害测试
# ─────────────────────────────────────────────────────────────────────────────

# ── 10.26 HealthComponent 回溯期间拒绝伤害 ───────────────────────────────────
func test_health_take_damage_rejected_during_rewind() -> void:
	var hc := HealthScript.new()
	# _ready 未调用 → 未注册 TimeManager；直接操作字段
	hc._hp = 80

	# 注入回溯状态（读取全局 TimeManager）
	TimeManager.is_rewinding = true

	watch_signals(hc)
	hc.take_damage(20)

	assert_eq(hc._hp, 80,
		"回溯期间 take_damage 应被忽略，hp 应保持 80，实际: %d" % hc._hp)
	assert_signal_not_emitted(hc, "health_changed",
		"回溯期间 health_changed 信号不应发射")

	hc.free()

# ── 10.27 HealthComponent 正常伤害生效 ───────────────────────────────────────
func test_health_take_damage_works_when_not_rewinding() -> void:
	var hc := HealthScript.new()
	hc._hp = 80
	TimeManager.is_rewinding = false

	watch_signals(hc)
	hc.take_damage(20)

	assert_eq(hc._hp, 60,
		"正常状态下 take_damage(20) 应使 hp 从 80 降至 60，实际: %d" % hc._hp)
	assert_signal_emit_count(hc, "health_changed", 1,
		"health_changed 信号应发射恰好 1 次")

	hc.free()
