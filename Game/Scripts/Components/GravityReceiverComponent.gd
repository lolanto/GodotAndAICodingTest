extends Node

# ── IRewindable 协议 ──────────────────────────────────────────────────────────
var rewind_id: String = "player/gravity-receiver"
var initial_snapshot: Dictionary = {}

# 缓存的重力方向向量（归一化，magnitude 已乘入）
var cached_gravity: Vector2 = Vector2.DOWN

func _ready() -> void:
	add_to_group("rewindable")
	TimeManager.register(self)
	await get_tree().process_frame
	initial_snapshot = capture_snapshot()

func _exit_tree() -> void:
	TimeManager.unregister(self)

func physics_step(_effective_delta: float) -> void:
	var body: Node = get_parent()
	if body == null:
		return
	cached_gravity = GravityManager.get_gravity_at(body.global_position)

# ── IRewindable 快照 ──────────────────────────────────────────────────────────
func capture_snapshot() -> Dictionary:
	return {"cached_gravity": cached_gravity}

func apply_snapshot(s: Dictionary) -> void:
	cached_gravity = s["cached_gravity"]

func reset_to_initial() -> void:
	if not initial_snapshot.is_empty():
		apply_snapshot(initial_snapshot)
