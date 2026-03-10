class_name Dog
extends CharacterBody2D

@export var move_speed: float = 500.0
@export var idle_time: float = 5.0
@export var walk_time: float = 1.0

@onready var anim = $AnimatedSprite2D

var timer: float = 0.0
var is_walking: bool = false
var move_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	randomize()
	start_idle()

func _physics_process(delta: float) -> void:
	timer -= delta

	if is_walking:
		velocity = move_direction * move_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	# Change state when timer ends
	if timer <= 0.0:
		if is_walking:
			start_idle()
		else:
			start_walk()

	# Flip left/right
	if move_direction.x > 0:
		anim.flip_h = false
	elif move_direction.x < 0:
		anim.flip_h = true

	# Animation
	if is_walking:
		if anim.animation != "run":
			anim.play("run")
	else:
		if anim.animation != "idle":
			anim.play("idle")

func start_idle() -> void:
	is_walking = false
	timer = idle_time
	move_direction = Vector2.ZERO

func start_walk() -> void:
	is_walking = true
	timer = walk_time

	var directions = [
		Vector2.LEFT,
		Vector2.RIGHT,
		Vector2.UP,
		Vector2.DOWN
	]

	move_direction = directions[randi() % directions.size()]
