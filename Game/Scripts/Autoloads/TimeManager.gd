extends Node

# ── 常量 ──────────────────────────────────────────────────────────────────────
const REWIND_SPEED: float        = 2.0
const MIN_TIME_SCALE: float      = 0.5
const MAX_TIME_SCALE: float      = 2.0
const MAX_REWIND_GAME_SEC: float = 10.0
const MAX_FRAMES: int            = 1200
const CE_RECOVERY_RATE: float    = 5.0
const CE_EXHAUSTED_COOLDOWN: float = 2.0

# ── 时间流速 ──────────────────────────────────────────────────────────────────
var time_scale: float = 1.0
var effective_delta: float = 0.0
var _is_slow_motion: bool = false
var _is_time_rush: bool = false
var _ce_cooldown_timer: float = 0.0

# ── 回溯状态 ──────────────────────────────────────────────────────────────────
var is_rewinding: bool = false
var in_rewind_free_zone: bool = false

# ── CE 资源 ───────────────────────────────────────────────────────────────────
var ce: float = 100.0
var ce_max: float = 100.0
var _active_lcf_count: int = 0

# ── 游戏时间累积 ──────────────────────────────────────────────────────────────
var _game_time: float = 0.0

# ── Ring Buffer ───────────────────────────────────────────────────────────────
var _registry: Array = []
var _buffer: Array = []
var _write_head: int = 0
var _rewind_cursor: int = 0
var _valid_frame_count: int = 0

func _ready() -> void:
	_buffer.resize(MAX_FRAMES)
	_buffer.fill(null)
	print("[TimeManager] Initialized. MAX_FRAMES=%d" % MAX_FRAMES)

func _physics_process(delta: float) -> void:
	# real_delta：不受 Engine.time_scale 影响的真实物理步长
	# CE 资源消耗和冷却必须以真实时间计算，与游戏快慢无关
	var real_delta: float = delta / maxf(Engine.time_scale, 0.001)

	if _ce_cooldown_timer > 0.0:
		_ce_cooldown_timer -= real_delta

	pre_tick(delta)

	if is_rewinding:
		_tick_ce(real_delta)
		return  # 回溯时跳过世界步进

	_game_time += effective_delta
	_tick_ce(real_delta)
	post_tick()

# ── Task 2.1: register / unregister ──────────────────────────────────────────
func register(node) -> void:
	if not node.has_method("capture_snapshot"):
		push_error("[TimeManager] Missing capture_snapshot on: %s" % node.name)
		return
	if not node.has_method("apply_snapshot"):
		push_error("[TimeManager] Missing apply_snapshot on: %s" % node.name)
		return
	if node.get("rewind_id") == null:
		push_error("[TimeManager] Missing rewind_id on: %s" % node.name)
		return
	for r in _registry:
		if r.rewind_id == node.rewind_id:
			push_error("[TimeManager] Duplicate rewind_id: %s" % node.rewind_id)
			return
	_registry.append(node)

func unregister(node) -> void:
	_registry.erase(node)

# ── Task 2.2: Ring Buffer + post_tick ────────────────────────────────────────
func post_tick() -> void:
	if in_rewind_free_zone:
		return
	var frame: Dictionary = {"game_time": _game_time, "snapshots": {}}
	for r in _registry:
		frame["snapshots"][r.rewind_id] = r.capture_snapshot()
	_buffer[_write_head] = frame
	_write_head = (_write_head + 1) % MAX_FRAMES
	_valid_frame_count = min(_valid_frame_count + 1, MAX_FRAMES)

# ── Task 2.3: pre_tick + 回溯调度 ─────────────────────────────────────────────
func pre_tick(delta: float) -> void:
	# Engine.time_scale 已经缩放了 delta，effective_delta 直接使用即可
	# time_scale 仅保留用于 HUD 显示和回溯速度计算
	effective_delta = delta

	if not is_rewinding:
		return

	if in_rewind_free_zone or _valid_frame_count == 0:
		is_rewinding = false
		return

	var game_time_budget: float = REWIND_SPEED * delta

	while game_time_budget > 0.0 and _valid_frame_count > 0:
		var cur_frame = _buffer[_rewind_cursor]
		if cur_frame == null:
			break
		var prev_idx: int = (_rewind_cursor - 1 + MAX_FRAMES) % MAX_FRAMES
		var prev_frame = _buffer[prev_idx]
		if prev_frame == null:
			_valid_frame_count = 0  # 已到达历史起点，标记耗尽；下次 pre_tick 将停止回溯
			break
		var frame_dt: float = cur_frame["game_time"] - prev_frame["game_time"]
		if frame_dt <= 0.0:
			break
		game_time_budget -= frame_dt
		_rewind_cursor = prev_idx
		_valid_frame_count -= 1

	var target_frame = _buffer[_rewind_cursor]
	if target_frame != null:
		_apply_rewind_frame(target_frame)

func _apply_rewind_frame(frame: Dictionary) -> void:
	for r in _registry:
		if r.rewind_id in frame["snapshots"]:
			r.apply_snapshot(frame["snapshots"][r.rewind_id])
		elif r.has_method("reset_to_initial"):
			r.reset_to_initial()

# ── Task 2.4: Rewind-Free Zone ────────────────────────────────────────────────
func enter_rewind_free_zone() -> void:
	in_rewind_free_zone = true
	is_rewinding = false
	_cancel_active_time_effects()
	_clear_buffer()
	ce = ce_max
	print("[TimeManager] Entered rewind-free zone. CE refilled.")

func exit_rewind_free_zone() -> void:
	in_rewind_free_zone = false
	print("[TimeManager] Exited rewind-free zone. Buffer accumulating.")

func _clear_buffer() -> void:
	_buffer.fill(null)
	_write_head = 0
	_rewind_cursor = 0
	_valid_frame_count = 0

func _cancel_active_time_effects() -> void:
	Engine.time_scale = 1.0
	time_scale = 1.0
	_is_slow_motion = false
	_is_time_rush = false

# ── Task 2.5: CE 资源管理 ─────────────────────────────────────────────────────
func _tick_ce(real_delta: float) -> void:
	if _ce_cooldown_timer > 0.0:
		return  # 冷却中，不消耗也不回复

	var ce_drain: float = 0.0
	if is_rewinding:
		ce_drain += 12.0
	elif _is_slow_motion:
		ce_drain += 10.0
	elif _is_time_rush:
		ce_drain += 5.0
	ce_drain += _active_lcf_count * 8.0

	if ce_drain > 0.0:
		ce = max(ce - ce_drain * real_delta, 0.0)
		if ce == 0.0:
			_on_ce_exhausted()
	else:
		var recovery: float = CE_RECOVERY_RATE
		# 读取 GravityManager 的零重力加成
		if GravityManager._zero_g_bonus_active:
			recovery *= 3.0
		ce = min(ce + recovery * real_delta, ce_max)

func _on_ce_exhausted() -> void:
	is_rewinding = false
	_cancel_active_time_effects()
	_ce_cooldown_timer = CE_EXHAUSTED_COOLDOWN
	print("[TimeManager] CE exhausted! All time effects cancelled. Cooldown: %.1fs" % CE_EXHAUSTED_COOLDOWN)

# ── Task 2.6: MVP LCF stub ────────────────────────────────────────────────────
func get_time_scale_at(_world_position: Vector2) -> float:
	return time_scale

func get_effective_delta(base_delta: float) -> float:
	return base_delta * time_scale

# ── 辅助：设置慢动作 ──────────────────────────────────────────────────────────
func start_slow_motion() -> void:
	if in_rewind_free_zone or _ce_cooldown_timer > 0.0:
		return
	is_rewinding = false
	_is_time_rush = false
	_is_slow_motion = true
	time_scale = MIN_TIME_SCALE       # HUD 显示
	Engine.time_scale = MIN_TIME_SCALE  # 真正减慢物理引擎

func start_time_rush() -> void:
	if in_rewind_free_zone or _ce_cooldown_timer > 0.0:
		return
	is_rewinding = false
	_is_slow_motion = false
	_is_time_rush = true
	time_scale = MAX_TIME_SCALE
	Engine.time_scale = MAX_TIME_SCALE

func stop_time_effects() -> void:
	_cancel_active_time_effects()
