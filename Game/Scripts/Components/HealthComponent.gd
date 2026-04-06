extends Node

signal health_changed(new_hp: int)

# ── IRewindable 协议 ──────────────────────────────────────────────────────────
var rewind_id: String = "player/health"
var initial_snapshot: Dictionary = {}

var _hp: int     = 100
var hp_max: int  = 100

func _ready() -> void:
	add_to_group("rewindable")
	TimeManager.register(self)
	await get_tree().process_frame
	initial_snapshot = capture_snapshot()

func _exit_tree() -> void:
	TimeManager.unregister(self)

func get_hp() -> int:
	return _hp

func take_damage(amount: int) -> void:
	if TimeManager.is_rewinding:
		return  # 回溯期间拒绝所有伤害
	_hp = max(_hp - amount, 0)
	emit_signal("health_changed", _hp)

func heal(amount: int) -> void:
	_hp = min(_hp + amount, hp_max)
	emit_signal("health_changed", _hp)

# ── IRewindable 快照 ──────────────────────────────────────────────────────────
func capture_snapshot() -> Dictionary:
	return {"hp": _hp}

func apply_snapshot(s: Dictionary) -> void:
	_hp = s["hp"]
	emit_signal("health_changed", _hp)

func reset_to_initial() -> void:
	if not initial_snapshot.is_empty():
		apply_snapshot(initial_snapshot)
