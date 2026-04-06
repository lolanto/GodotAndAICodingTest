extends Node

# ── IRewindable 协议 ──────────────────────────────────────────────────────────
var rewind_id: String = "player/gravity-skill"
var initial_snapshot: Dictionary = {}

# ── LGF 对象池（6 个槽位，始终在场景树中） ──────────────────────────────────
var _lgf_slots: Array = []   # 由 Player.tscn 的子节点填充
var active_count: int = 0
var _next_order: int  = 1

const LGF_DURATION: float = 8.0   # 玩家技能 LGF 存续时长（秒）

func _ready() -> void:
	add_to_group("rewindable")
	# 收集子节点中的 LGFNode 槽位
	for child in get_children():
		if child.has_method("capture_snapshot") and child.get("source") != null:
			_lgf_slots.append(child)
	TimeManager.register(self)
	await get_tree().process_frame
	initial_snapshot = capture_snapshot()

func _exit_tree() -> void:
	TimeManager.unregister(self)

# ── 重力方向切换 ──────────────────────────────────────────────────────────────
func set_global_direction(new_dir: Vector2) -> void:
	GravityManager.set_direction(new_dir)

# ── LGF 放置与移除 ────────────────────────────────────────────────────────────
func place_lgf() -> void:
	if not GravityManager.can_place_lgf():
		return
	var player: Node = get_parent()
	if player == null:
		return

	# 找一个 unlocked=true && active=false 的槽位
	var slot = null
	for s in _lgf_slots:
		if s.unlocked and not s.active:
			slot = s
			break
	if slot == null:
		return  # 无可用槽位

	# 配置并激活
	slot.global_position  = player.global_position
	slot.direction        = GravityManager.direction
	slot.magnitude        = GravityManager.magnitude
	slot.blend_factor     = 0.0
	slot.remaining_time   = LGF_DURATION
	slot.placement_order  = _next_order
	slot.active           = true
	_next_order          += 1
	active_count         += 1

	GravityManager.start_lgf_place_cooldown()

func remove_last_lgf() -> void:
	# 移除 placement_order 最大的活跃槽位
	var last_slot = null
	var max_order: int = -1
	for s in _lgf_slots:
		if s.active and s.placement_order > max_order:
			max_order = s.placement_order
			last_slot = s
	if last_slot == null:
		return
	last_slot.active = false
	active_count     = max(active_count - 1, 0)
	GravityManager.start_lgf_place_cooldown()

# ── 强度调节（慢动作精度增益） ────────────────────────────────────────────────
func adjust_magnitude(delta_step: float) -> void:
	var step: float
	if TimeManager._is_slow_motion:
		step = 0.05
	else:
		step = 0.25
	GravityManager.set_magnitude(GravityManager._target_magnitude + delta_step * step)

# ── IRewindable 快照 ──────────────────────────────────────────────────────────
func capture_snapshot() -> Dictionary:
	return {
		"active_count":         active_count,
		"next_placement_order": _next_order
	}

func apply_snapshot(s: Dictionary) -> void:
	active_count = s["active_count"]
	_next_order  = s["next_placement_order"]

func reset_to_initial() -> void:
	if not initial_snapshot.is_empty():
		apply_snapshot(initial_snapshot)
