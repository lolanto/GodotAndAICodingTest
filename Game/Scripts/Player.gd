extends CharacterBody2D

@export var move_speed: float = 200.0

@onready var movement:        Node = $MovementComponent
@onready var gravity_receiver:Node = $GravityReceiverComponent
@onready var input_component: Node = $PlayerInputComponent
@onready var gravity_skill:   Node = $GravitySkillComponent
@onready var time_skill:      Node = $TimeSkillComponent
@onready var health:          Node = $HealthComponent

func _ready() -> void:
	add_to_group("player")
	# 注入引用
	if movement and gravity_receiver:
		movement.gravity_receiver = gravity_receiver
	if input_component:
		input_component.gravity_skill = gravity_skill
		input_component.time_skill    = time_skill

func _physics_process(delta: float) -> void:
	var effective_delta: float = TimeManager.effective_delta

	if TimeManager.is_rewinding:
		return  # 回溯时位置由快照还原，不走物理

	# 主循环顺序：GravityManager.tick → GravityReceiver → Movement
	GravityManager.tick(effective_delta)

	if gravity_receiver:
		gravity_receiver.physics_step(effective_delta)

	# 水平移动输入
	if input_component:
		var move_input: Vector2 = input_component.get_move_input()
		# 将输入方向投影到当前重力的切向平面
		var grav_dir: Vector2 = GravityManager.direction
		var tangent: Vector2  = Vector2(-grav_dir.y, grav_dir.x)
		velocity += tangent * move_input.x * move_speed * effective_delta

	if movement:
		movement.physics_step(effective_delta)

	# 推动碰撞到的刚体（CharacterBody2D 不会自动推 RigidBody2D）
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_collider() is RigidBody2D:
			var rb := col.get_collider() as RigidBody2D
			var push_force := velocity.length() * 0.4
			rb.apply_central_impulse(-col.get_normal() * push_force)
