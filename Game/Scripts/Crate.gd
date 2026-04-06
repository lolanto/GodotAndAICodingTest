extends RigidBody2D
## Crate — 受重力系统控制的可回溯刚体。
## 禁用引擎内置重力，改由 GravityManager 提供方向与强度。
## 实现 IRewindable 协议，注册至 TimeManager 参与时间回溯。

const GRAVITY_PIXELS_PER_SEC2: float = 980.0

## IRewindable 协议字段
@export var rewind_id: String = "obj/crate-0"
var initial_snapshot: Dictionary = {}

func _ready() -> void:
	gravity_scale     = 0.0                        # 禁用引擎默认重力
	linear_damp_mode  = RigidBody2D.DAMP_MODE_REPLACE  # 覆盖全局阻尼（默认 0.1）
	linear_damp       = 0.0
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp      = 0.0
	TimeManager.register(self)
	initial_snapshot = capture_snapshot()

func _exit_tree() -> void:
	TimeManager.unregister(self)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if TimeManager.is_rewinding:
		# 回溯期间：TimeManager.pre_tick 已通过 apply_snapshot 写入
		# linear_velocity / rotation，这里同步到物理引擎状态
		state.linear_velocity = linear_velocity
		state.angular_velocity = angular_velocity
		state.transform = Transform2D(rotation, global_position)
		return

	# 正常帧：按 GravityManager 方向施加重力，并尊重 time_scale
	var g: Vector2 = GravityManager.get_gravity_at(global_position)
	state.linear_velocity += g * GRAVITY_PIXELS_PER_SEC2 * TimeManager.effective_delta

# ── IRewindable ───────────────────────────────────────────────────────────────

func capture_snapshot() -> Dictionary:
	return {
		"position":         global_position,
		"rotation":         rotation,
		"linear_velocity":  linear_velocity,
		"angular_velocity": angular_velocity,
	}

func apply_snapshot(s: Dictionary) -> void:
	global_position   = s["position"]
	rotation          = s["rotation"]
	linear_velocity   = s["linear_velocity"]
	angular_velocity  = s["angular_velocity"]
	sleeping          = false

func reset_to_initial() -> void:
	if not initial_snapshot.is_empty():
		apply_snapshot(initial_snapshot)
