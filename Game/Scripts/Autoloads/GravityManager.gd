extends Node

signal gravity_direction_changed(new_direction: Vector2)
signal magnitude_changed(new_magnitude: float)

# ── 常量 ──────────────────────────────────────────────────────────────────────
const MAG_INTERP_DURATION: float  = 0.2
const GE_RECOVERY_RATE: float     = 8.0
const LGF_DRAIN_PER_SEC: float    = 6.0
const DIRECTION_SWITCH_COST: float = 15.0
const DIRECTION_COOLDOWN: float   = 1.5
const LGF_PLACE_COOLDOWN: float   = 0.3

# ── 重力状态 ──────────────────────────────────────────────────────────────────
var direction: Vector2       = Vector2.DOWN
var magnitude: float         = 1.0
var _target_magnitude: float = 1.0
var _mag_interp_t: float     = 1.0

# ── GE 资源 ───────────────────────────────────────────────────────────────────
var ge: float     = 100.0
var ge_max: float = 100.0
var _direction_cooldown_timer: float = 0.0
var _lgf_place_cooldown_timer: float = 0.0

# ── 零重力联动 ────────────────────────────────────────────────────────────────
var _zero_g_timer: float       = 0.0
var _zero_g_bonus_active: bool = false

# ── LGF 注册表 ────────────────────────────────────────────────────────────────
var _lgf_registry: Array = []

# ── IRewindable 协议 ──────────────────────────────────────────────────────────
var rewind_id: String = "sys/gravity"
var initial_snapshot: Dictionary = {}

func _ready() -> void:
	# Task 3.7: 向 TimeManager 注册
	TimeManager.register(self)
	initial_snapshot = capture_snapshot()
	print("[GravityManager] Initialized. Registered to TimeManager.")

func _exit_tree() -> void:
	TimeManager.unregister(self)

# ── Task 3.1/3.2: 方向与强度接口 ─────────────────────────────────────────────
func set_direction(new_dir: Vector2) -> void:
	if _direction_cooldown_timer > 0.0:
		return
	if new_dir == direction:
		return
	if ge < DIRECTION_SWITCH_COST:
		return
	ge -= DIRECTION_SWITCH_COST
	direction = new_dir.normalized()
	_direction_cooldown_timer = DIRECTION_COOLDOWN
	emit_signal("gravity_direction_changed", direction)

func set_magnitude(target: float) -> void:
	_target_magnitude = clampf(target, 0.0, 3.0)
	_mag_interp_t = 0.0

func _update_magnitude(effective_delta: float) -> void:
	if is_equal_approx(magnitude, _target_magnitude):
		return
	_mag_interp_t = minf(_mag_interp_t + effective_delta / MAG_INTERP_DURATION, 1.0)
	magnitude = lerpf(magnitude, _target_magnitude, _mag_interp_t)
	if _mag_interp_t >= 1.0:
		magnitude = _target_magnitude
		emit_signal("magnitude_changed", magnitude)

# ── Task 3.3: LGF 注册表与 get_gravity_at ─────────────────────────────────────
func register_lgf(node) -> void:
	if not _lgf_registry.has(node):
		_lgf_registry.append(node)

func unregister_lgf(node) -> void:
	_lgf_registry.erase(node)

func get_gravity_at(pos: Vector2) -> Vector2:
	var hits: Array = []
	for n in _lgf_registry:
		if n.active and n.has_method("overlaps_point") and n.overlaps_point(pos):
			hits.append(n)
	if hits.is_empty():
		return direction * magnitude
	hits.sort_custom(func(a, b): return a.placement_order > b.placement_order)
	var top = hits[0]
	return lerp(top.direction * top.magnitude, direction * magnitude, top.blend_factor)

# ── Task 3.4/3.5: tick() GE + 零重力联动 ──────────────────────────────────────
func tick(effective_delta: float) -> void:
	# 冷却倒计时
	if _direction_cooldown_timer > 0.0:
		_direction_cooldown_timer -= effective_delta
	if _lgf_place_cooldown_timer > 0.0:
		_lgf_place_cooldown_timer -= effective_delta

	# 强度插值
	_update_magnitude(effective_delta)

	# 引力时间膨胀联动（magnitude > 1.0 时减慢时间，< 1.0 时加快）
	if not is_equal_approx(magnitude, 1.0):
		var dilation: float = 1.0 / maxf(sqrt(magnitude), 0.3)
		var ts: float = clampf(dilation, TimeManager.MIN_TIME_SCALE, TimeManager.MAX_TIME_SCALE)
		TimeManager.time_scale = ts
		Engine.time_scale = ts
	elif not TimeManager._is_slow_motion and not TimeManager._is_time_rush:
		TimeManager.time_scale = 1.0
		Engine.time_scale = 1.0

	# 零重力计时器
	if is_equal_approx(magnitude, 0.0):
		_zero_g_timer += effective_delta
		_zero_g_bonus_active = (_zero_g_timer >= 3.0)
	else:
		_zero_g_timer = 0.0
		_zero_g_bonus_active = false

	# GE 消耗/恢复互斥
	var ge_drain: float = 0.0
	for lgf in _lgf_registry:
		if lgf.active and lgf.source == "player_skill":
			ge_drain += LGF_DRAIN_PER_SEC

	if ge_drain > 0.0:
		ge = maxf(ge - ge_drain * effective_delta, 0.0)
	else:
		ge = minf(ge + GE_RECOVERY_RATE * effective_delta, ge_max)

# ── Task 3.6: IRewindable 快照 ────────────────────────────────────────────────
func capture_snapshot() -> Dictionary:
	return {
		"direction":           direction,
		"magnitude":           magnitude,
		"target_magnitude":    _target_magnitude,
		"mag_interp_t":        _mag_interp_t,
		"ge":                  ge,
		"zero_g_timer":        _zero_g_timer,
		"zero_g_bonus_active": _zero_g_bonus_active
	}

func apply_snapshot(s: Dictionary) -> void:
	direction            = s["direction"]
	magnitude            = s["magnitude"]
	_target_magnitude    = s["target_magnitude"]
	_mag_interp_t        = s["mag_interp_t"]
	ge                   = s["ge"]
	_zero_g_timer        = s["zero_g_timer"]
	_zero_g_bonus_active = s["zero_g_bonus_active"]

func reset_to_initial() -> void:
	if not initial_snapshot.is_empty():
		apply_snapshot(initial_snapshot)

# LGF 放置冷却工具方法（供 GravitySkillComponent 调用）
func can_place_lgf() -> bool:
	return _lgf_place_cooldown_timer <= 0.0

func start_lgf_place_cooldown() -> void:
	_lgf_place_cooldown_timer = LGF_PLACE_COOLDOWN
