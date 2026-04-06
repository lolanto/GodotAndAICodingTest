extends Node

# ── IRewindable 协议 ──────────────────────────────────────────────────────────
var rewind_id: String = "player/movement"
var initial_snapshot: Dictionary = {}

# 由 Player.gd 在组装时注入
var gravity_receiver: Node = null

func _ready() -> void:
	add_to_group("rewindable")
	TimeManager.register(self)
	await get_tree().process_frame
	initial_snapshot = capture_snapshot()

func _exit_tree() -> void:
	TimeManager.unregister(self)

func physics_step(effective_delta: float) -> void:
	var body: CharacterBody2D = get_parent() as CharacterBody2D
	if body == null:
		return

	# 获取本帧重力向量
	var gravity_vec: Vector2 = Vector2.DOWN * 980.0
	if gravity_receiver != null:
		gravity_vec = gravity_receiver.cached_gravity * 980.0

	body.velocity += gravity_vec * effective_delta
	body.move_and_slide()

# ── IRewindable 快照 ──────────────────────────────────────────────────────────
func capture_snapshot() -> Dictionary:
	var body: CharacterBody2D = get_parent() as CharacterBody2D
	if body == null:
		return {}
	return {
		"position": body.global_position,
		"velocity": body.velocity
	}

func apply_snapshot(s: Dictionary) -> void:
	if s.is_empty():
		return
	var body: CharacterBody2D = get_parent() as CharacterBody2D
	if body == null:
		return
	body.global_position = s["position"]
	body.velocity        = s["velocity"]

func reset_to_initial() -> void:
	if not initial_snapshot.is_empty():
		apply_snapshot(initial_snapshot)
