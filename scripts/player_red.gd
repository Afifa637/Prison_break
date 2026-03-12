class_name Player_red extends CharacterBody2D

@export var move_speed: float = 400.0
@export var jump_force: float = 1200.0
@export var gravity: float = 2600.0

@onready var anim = $AnimatedSprite2D

var jump_velocity: float = 0.0
var height_offset: float = 0.0
var is_jumping: bool = false
var base_position_y: float = 0.0

func _ready() -> void:
	base_position_y = $AnimatedSprite2D.position.y

func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO

	direction.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	direction.y = Input.get_action_strength("down") - Input.get_action_strength("up")

	direction = direction.normalized()
	velocity = direction * move_speed
	move_and_slide()

	if direction.x > 0:
		anim.flip_h = false
	elif direction.x < 0:
		anim.flip_h = true

	# Jump start
	if Input.is_action_just_pressed("jump") and not is_jumping:
		is_jumping = true
		jump_velocity = -jump_force

	# Jump physics
	if is_jumping:
		jump_velocity += gravity * delta
		height_offset += jump_velocity * delta

		if height_offset >= 0:
			height_offset = 0
			jump_velocity = 0
			is_jumping = false

		anim.position.y = base_position_y + height_offset
	else:
		anim.position.y = base_position_y

	# Animation priority
	if is_jumping:
		if anim.animation != "jump":
			anim.play("jump")
	elif direction != Vector2.ZERO:
		if anim.animation != "run":
			anim.play("run")
	else:
		if anim.animation != "idle":
			anim.play("idle")
