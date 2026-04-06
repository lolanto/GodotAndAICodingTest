class_name IntegrationTestBase
extends GutTest
## 集成测试公共基类
##
## 保存/恢复全局 TimeManager 和 GravityManager 的完整状态，
## 禁用 TimeManager 的自动 _physics_process，使每个测试可手动驱动帧。
##
## 用法：
##   extends IntegrationTestBase
##   func before_each(): super.before_each()
##   func after_each():  super.after_each()

# ── 快照变量 ──────────────────────────────────────────────────────────────────
var _saved_tm: Dictionary = {}
var _saved_gm: Dictionary = {}
var _saved_registry: Array = []
var _saved_buffer: Array = []

# ── 通用 Mock ─────────────────────────────────────────────────────────────────
class MockRewindable extends RefCounted:
	var rewind_id: String = "test/mock"
	var name: String      = "MockRewindable"
	var position: Vector2 = Vector2.ZERO

	func capture_snapshot() -> Dictionary:
		return {"position": position}

	func apply_snapshot(s: Dictionary) -> void:
		position = s["position"]


class MockLGF extends RefCounted:
	var rewind_id: String    = "test/lgf"
	var name: String         = "MockLGF"
	var active: bool         = false
	var source: String       = "player_skill"
	var direction: Vector2   = Vector2.DOWN
	var magnitude: float     = 1.0
	var blend_factor: float  = 0.0
	var placement_order: int = 1
	var _should_overlap: bool = true

	func overlaps_point(_pos: Vector2) -> bool:
		return _should_overlap

	func capture_snapshot() -> Dictionary:
		return {
			"active":          active,
			"direction":       direction,
			"magnitude":       magnitude,
			"blend_factor":    blend_factor,
			"remaining_time":  -1.0,
			"placement_order": placement_order,
		}

	func apply_snapshot(s: Dictionary) -> void:
		active          = s["active"]
		direction       = s["direction"]
		magnitude       = s["magnitude"]
		blend_factor    = s["blend_factor"]
		placement_order = s["placement_order"]

# ── 公共 Setup / Teardown ─────────────────────────────────────────────────────
func before_each() -> void:
	TimeManager.set_physics_process(false)

	# 保存 TimeManager 状态
	_saved_registry = TimeManager._registry.duplicate()
	_saved_buffer   = TimeManager._buffer.duplicate()
	_saved_tm = {
		"time_scale":          TimeManager.time_scale,
		"effective_delta":     TimeManager.effective_delta,
		"_is_slow_motion":     TimeManager._is_slow_motion,
		"_is_time_rush":       TimeManager._is_time_rush,
		"_ce_cooldown_timer":  TimeManager._ce_cooldown_timer,
		"is_rewinding":        TimeManager.is_rewinding,
		"in_rewind_free_zone": TimeManager.in_rewind_free_zone,
		"ce":                  TimeManager.ce,
		"_active_lcf_count":   TimeManager._active_lcf_count,
		"_game_time":          TimeManager._game_time,
		"_write_head":         TimeManager._write_head,
		"_rewind_cursor":      TimeManager._rewind_cursor,
		"_valid_frame_count":  TimeManager._valid_frame_count,
	}

	# 保存 GravityManager 状态
	_saved_gm = GravityManager.capture_snapshot()
	_saved_gm["_direction_cooldown_timer"] = GravityManager._direction_cooldown_timer
	_saved_gm["_lgf_place_cooldown_timer"] = GravityManager._lgf_place_cooldown_timer
	_saved_gm["_lgf_registry"]             = GravityManager._lgf_registry.duplicate()

	# 重置为干净状态（保留 GravityManager 的注册）
	TimeManager._buffer.fill(null)
	TimeManager._write_head        = 0
	TimeManager._rewind_cursor     = 0
	TimeManager._valid_frame_count = 0
	TimeManager._game_time         = 0.0
	TimeManager.is_rewinding       = false
	TimeManager.in_rewind_free_zone = false
	TimeManager.ce                 = 100.0
	TimeManager.time_scale         = 1.0
	TimeManager._is_slow_motion    = false
	TimeManager._is_time_rush      = false
	TimeManager._ce_cooldown_timer = 0.0
	TimeManager._active_lcf_count  = 0
	TimeManager._registry          = _saved_registry.duplicate()

	GravityManager.apply_snapshot(GravityManager.initial_snapshot)
	GravityManager._direction_cooldown_timer = 0.0
	GravityManager._lgf_place_cooldown_timer = 0.0
	GravityManager._lgf_registry            = []


func after_each() -> void:
	# 恢复 TimeManager
	TimeManager._buffer            = _saved_buffer
	TimeManager._registry          = _saved_registry
	TimeManager.time_scale         = _saved_tm["time_scale"]
	TimeManager.effective_delta    = _saved_tm["effective_delta"]
	TimeManager._is_slow_motion    = _saved_tm["_is_slow_motion"]
	TimeManager._is_time_rush      = _saved_tm["_is_time_rush"]
	TimeManager._ce_cooldown_timer = _saved_tm["_ce_cooldown_timer"]
	TimeManager.is_rewinding       = _saved_tm["is_rewinding"]
	TimeManager.in_rewind_free_zone = _saved_tm["in_rewind_free_zone"]
	TimeManager.ce                 = _saved_tm["ce"]
	TimeManager._active_lcf_count  = _saved_tm["_active_lcf_count"]
	TimeManager._game_time         = _saved_tm["_game_time"]
	TimeManager._write_head        = _saved_tm["_write_head"]
	TimeManager._rewind_cursor     = _saved_tm["_rewind_cursor"]
	TimeManager._valid_frame_count = _saved_tm["_valid_frame_count"]

	# 恢复 GravityManager
	GravityManager.apply_snapshot(_saved_gm)
	GravityManager._direction_cooldown_timer = _saved_gm["_direction_cooldown_timer"]
	GravityManager._lgf_place_cooldown_timer = _saved_gm["_lgf_place_cooldown_timer"]
	GravityManager._lgf_registry            = _saved_gm["_lgf_registry"]

	TimeManager.set_physics_process(true)

# ── 辅助方法 ──────────────────────────────────────────────────────────────────
## 向 Ring Buffer 写入一帧（同时推进游戏时间计数器）
func _write_frame(game_time: float) -> void:
	TimeManager._game_time = game_time
	TimeManager.post_tick()

## 从最新帧开始执行回溯，指定真实帧时长（real_delta）
func _start_rewind_from_latest() -> void:
	if TimeManager._valid_frame_count == 0:
		return
	TimeManager._rewind_cursor = (TimeManager._write_head - 1 + TimeManager.MAX_FRAMES) % TimeManager.MAX_FRAMES
	TimeManager.is_rewinding   = true
