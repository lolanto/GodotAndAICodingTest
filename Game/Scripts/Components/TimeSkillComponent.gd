extends Node

# ── IRewindable 协议 ──────────────────────────────────────────────────────────
var rewind_id: String = "player/time-skill"
var initial_snapshot: Dictionary = {}

func _ready() -> void:
	add_to_group("rewindable")
	TimeManager.register(self)
	await get_tree().process_frame
	initial_snapshot = capture_snapshot()

func _exit_tree() -> void:
	TimeManager.unregister(self)

# ── 时间回溯 ──────────────────────────────────────────────────────────────────
func try_start_rewind() -> void:
	if TimeManager.in_rewind_free_zone:
		return
	if TimeManager._valid_frame_count == 0:
		return
	if TimeManager._ce_cooldown_timer > 0.0:
		return
	# 取消所有时间流速操控，重置为 1.0
	TimeManager._cancel_active_time_effects()
	TimeManager.time_scale = 1.0
	# 将回溯游标指向最新帧（_write_head 指向下一个写入位置，减 1 得到最新帧）
	TimeManager._rewind_cursor = (TimeManager._write_head - 1 + TimeManager.MAX_FRAMES) % TimeManager.MAX_FRAMES
	TimeManager.is_rewinding = true

func stop_rewind() -> void:
	if TimeManager.is_rewinding:
		TimeManager.is_rewinding = false
		# 回溯结束时重置 rewind_cursor 到 write_head
		TimeManager._rewind_cursor = TimeManager._write_head

# ── 慢动作 ────────────────────────────────────────────────────────────────────
func try_start_slow_motion() -> void:
	if TimeManager.in_rewind_free_zone or TimeManager._ce_cooldown_timer > 0.0:
		return
	TimeManager.start_slow_motion()

func stop_slow_motion() -> void:
	if TimeManager._is_slow_motion:
		TimeManager.stop_time_effects()

# ── 时间加速 ──────────────────────────────────────────────────────────────────
func try_start_time_rush() -> void:
	if TimeManager.in_rewind_free_zone or TimeManager._ce_cooldown_timer > 0.0:
		return
	TimeManager.start_time_rush()

func stop_time_rush() -> void:
	if TimeManager._is_time_rush:
		TimeManager.stop_time_effects()

# ── IRewindable 快照 ──────────────────────────────────────────────────────────
func capture_snapshot() -> Dictionary:
	return {"lcf_list": []}  # MVP: LCF 为空

func apply_snapshot(_s: Dictionary) -> void:
	pass  # MVP: 无需还原

func reset_to_initial() -> void:
	pass
