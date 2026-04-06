extends Area2D

# ── IRewindable 协议 ──────────────────────────────────────────────────────────
var rewind_id: String = ""
var initial_snapshot: Dictionary = {}

# ── LGF 属性 ──────────────────────────────────────────────────────────────────
var direction: Vector2    = Vector2.DOWN
var magnitude: float      = 1.0
var blend_factor: float   = 0.0      # 0 = 完全覆盖全局重力
var source: String        = "scene"  # "scene" | "player_skill"
var active: bool          = false
var unlocked: bool        = true
var remaining_time: float = -1.0     # -1 = 外部控制（scene 类型）
var placement_order: int  = 0

# ── 可视化常量 ────────────────────────────────────────────────────────────────
const INACTIVE_FILL   := Color(0.5, 0.5, 0.5, 0.06)
const INACTIVE_EDGE   := Color(0.5, 0.5, 0.5, 0.20)
const ARROW_HEAD_SIZE := 10.0
const RING_WIDTH      := 3.5
const EDGE_WIDTH      := 1.5

func _ready() -> void:
	add_to_group("rewindable")
	if rewind_id.is_empty():
		rewind_id = "zone_default/lgf-%d" % get_instance_id()
	GravityManager.register_lgf(self)
	TimeManager.register(self)
	initial_snapshot = capture_snapshot()

func _exit_tree() -> void:
	GravityManager.unregister_lgf(self)
	TimeManager.unregister(self)

func _physics_process(delta: float) -> void:
	if active and remaining_time > 0.0:
		remaining_time -= TimeManager.effective_delta
		if remaining_time <= 0.0:
			remaining_time = 0.0
			active = false
	queue_redraw()

func _draw() -> void:
	var r := _get_radius()
	if not active:
		draw_circle(Vector2.ZERO, r, INACTIVE_FILL)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, INACTIVE_EDGE, EDGE_WIDTH)
		return

	var col := _direction_color()
	var fill := Color(col.r, col.g, col.b, 0.10)

	# ── 填充圆 ──
	draw_circle(Vector2.ZERO, r, fill)
	# ── 边框圆 ──
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, col, EDGE_WIDTH)

	# ── 剩余时间弧（在边框外侧） ──
	if remaining_time > 0.0:
		var frac: float = remaining_time / 8.0   # 8.0 = GravitySkillComponent.LGF_DURATION
		var end_angle: float = -PI * 0.5 + TAU * frac
		draw_arc(Vector2.ZERO, r + 5.0, -PI * 0.5, end_angle, 64, col, RING_WIDTH)

	# ── 方向箭头 ──
	var dir_n := direction.normalized()
	var tip   := dir_n * r * 0.55
	var tail  := -dir_n * r * 0.20
	var perp  := Vector2(-dir_n.y, dir_n.x) * ARROW_HEAD_SIZE
	draw_line(tail, tip, col, 2.5)
	draw_line(tip, tip - dir_n * ARROW_HEAD_SIZE + perp, col, 2.5)
	draw_line(tip, tip - dir_n * ARROW_HEAD_SIZE - perp, col, 2.5)

# ── 辅助：从 CollisionShape2D 读取半径 ────────────────────────────────────────
func _get_radius() -> float:
	for child in get_children():
		if child is CollisionShape2D:
			var s = child.shape
			if s is CircleShape2D:
				return (s as CircleShape2D).radius
	return 80.0

# ── 辅助：根据方向映射颜色 ────────────────────────────────────────────────────
func _direction_color() -> Color:
	if direction.is_equal_approx(Vector2.DOWN):  return Color(0.20, 0.85, 1.00)  # 青色
	if direction.is_equal_approx(Vector2.UP):    return Color(0.75, 0.25, 1.00)  # 紫色
	if direction.is_equal_approx(Vector2.LEFT):  return Color(1.00, 0.55, 0.10)  # 橙色
	return Color(0.25, 1.00, 0.45)                                                # 绿色（右）

# ── IRewindable 快照 ──────────────────────────────────────────────────────────
func capture_snapshot() -> Dictionary:
	return {
		"active":          active,
		"direction":       direction,
		"magnitude":       magnitude,
		"blend_factor":    blend_factor,
		"remaining_time":  remaining_time,
		"placement_order": placement_order
	}

func apply_snapshot(s: Dictionary) -> void:
	active          = s["active"]
	direction       = s["direction"]
	magnitude       = s["magnitude"]
	blend_factor    = s["blend_factor"]
	remaining_time  = s["remaining_time"]
	placement_order = s["placement_order"]
	queue_redraw()

func reset_to_initial() -> void:
	if not initial_snapshot.is_empty():
		apply_snapshot(initial_snapshot)
