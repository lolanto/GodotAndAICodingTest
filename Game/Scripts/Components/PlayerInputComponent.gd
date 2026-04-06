extends Node

# 不参与快照（输入是实时的，不需要回溯）

# 由外部注入引用
var gravity_skill: Node = null
var time_skill: Node    = null

var _move_input: Vector2 = Vector2.ZERO

func _ready() -> void:
	pass  # 不注册 TimeManager

func _unhandled_input(event: InputEvent) -> void:
	if TimeManager.is_rewinding:
		return  # 回溯期间锁定所有输入

	# 时间技能
	if event.is_action_pressed("time_rewind") and time_skill:
		time_skill.try_start_rewind()
	elif event.is_action_released("time_rewind") and time_skill:
		time_skill.stop_rewind()

	if event.is_action_pressed("time_slow") and time_skill:
		time_skill.try_start_slow_motion()
	elif event.is_action_released("time_slow") and time_skill:
		time_skill.stop_slow_motion()

	if event.is_action_pressed("time_rush") and time_skill:
		time_skill.try_start_time_rush()
	elif event.is_action_released("time_rush") and time_skill:
		time_skill.stop_time_rush()

	# 重力方向切换
	if event.is_action_pressed("gravity_flip_down") and gravity_skill:
		gravity_skill.set_global_direction(Vector2.DOWN)
	elif event.is_action_pressed("gravity_flip_up") and gravity_skill:
		gravity_skill.set_global_direction(Vector2.UP)
	elif event.is_action_pressed("gravity_flip_left") and gravity_skill:
		gravity_skill.set_global_direction(Vector2.LEFT)
	elif event.is_action_pressed("gravity_flip_right") and gravity_skill:
		gravity_skill.set_global_direction(Vector2.RIGHT)

	# LGF 放置/移除
	if event.is_action_pressed("place_lgf") and gravity_skill:
		gravity_skill.place_lgf()
	elif event.is_action_pressed("remove_lgf") and gravity_skill:
		gravity_skill.remove_last_lgf()

func get_move_input() -> Vector2:
	if TimeManager.is_rewinding:
		return Vector2.ZERO
	return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
