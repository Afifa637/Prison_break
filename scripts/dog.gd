# =============================================================================
# dog.gd  –  Patrol / chase / latch / alert
# Works with current Dog scene:
#   Dog (CharacterBody2D)
#   ├── AnimatedSprite2D
#   └── CollisionShape2D
# =============================================================================
class_name Dog
extends CharacterBody2D

signal player_spotted(alert_position: Vector2)

@export var patrol_speed: float = 90.0
@export var chase_speed: float = 185.0
@export var detection_radius: float = 260.0
@export var latch_distance: float = 42.0
@export var penalty_tick: float = 0.75
@export var prisoner_pull_strength: float = 55.0
@export var prisoner_offset: Vector2 = Vector2(-20, -10)

@export var patrol_radius_x: float = 250.0
@export var patrol_radius_y: float = 200.0
@export var waypoint_reach_dist: float = 20.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _target: Node2D = null
var _latched_target: Node2D = null
var _penalty_timer: float = 0.0
var _start_position: Vector2 = Vector2.ZERO
var _patrol_points: Array[Vector2] = []
var _patrol_index: int = 0


func _ready() -> void:
	add_to_group("dogs")
	_start_position = global_position
	_build_patrol_points()


func _physics_process(delta: float) -> void:
	if _latched_target != null:
		if not _is_player_still_active(_latched_target):
			reset_to_start()
			return
		_handle_latched_target(delta)
		return

	_target = _find_nearest_player_in_radius(detection_radius)

	if _target != null:
		_chase_target(delta)
	else:
		_patrol(delta)


func _build_patrol_points() -> void:
	_patrol_points.clear()
	_patrol_points.append(_start_position + Vector2(-patrol_radius_x, 0))
	_patrol_points.append(_start_position + Vector2(0, -patrol_radius_y))
	_patrol_points.append(_start_position + Vector2(patrol_radius_x, 0))
	_patrol_points.append(_start_position + Vector2(0, patrol_radius_y))


func _find_nearest_player_in_radius(radius: float) -> Node2D:
	var best: Node2D = null
	var best_dist: float = radius

	for player in get_tree().get_nodes_in_group("players"):
		var p: Node2D = player as Node2D
		if not _is_player_still_active(p):
			continue

		var d: float = global_position.distance_to(p.global_position)
		if d <= best_dist:
			best_dist = d
			best = p

	return best


func _patrol(_delta: float) -> void:
	if _patrol_points.is_empty():
		velocity = Vector2.ZERO
		move_and_slide()
		_play_idle()
		return

	var goal: Vector2 = _patrol_points[_patrol_index]
	var to_goal: Vector2 = goal - global_position

	if to_goal.length() <= waypoint_reach_dist:
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()
		goal = _patrol_points[_patrol_index]
		to_goal = goal - global_position

	var dir: Vector2 = to_goal.normalized()
	velocity = dir * patrol_speed
	move_and_slide()
	_face_dir(dir)

	# user asked patrol in idle mode
	_play_idle()


func _chase_target(delta: float) -> void:
	if _target == null or not _is_player_still_active(_target):
		_target = null
		velocity = Vector2.ZERO
		_play_idle()
		return

	emit_signal("player_spotted", _target.global_position)

	var dir: Vector2 = (_target.global_position - global_position).normalized()
	velocity = dir * chase_speed
	move_and_slide()
	_face_dir(dir)
	_play_run()

	if global_position.distance_to(_target.global_position) <= latch_distance:
		_latch_to_target(_target)
		return

	_penalty_timer += delta
	if _penalty_timer >= penalty_tick:
		_penalty_timer = 0.0
		_apply_prisoner_penalty(_target, true)


func _handle_latched_target(delta: float) -> void:
	if _latched_target == null or not _is_player_still_active(_latched_target):
		reset_to_start()
		return

	emit_signal("player_spotted", _latched_target.global_position)

	global_position = _latched_target.global_position + prisoner_offset
	velocity = Vector2.ZERO

	var dir_from_dog_to_prisoner: Vector2 = (_latched_target.global_position - global_position).normalized()
	if dir_from_dog_to_prisoner == Vector2.ZERO:
		dir_from_dog_to_prisoner = Vector2.RIGHT

	# simulate slowdown without touching prisoner script
	_latched_target.global_position -= dir_from_dog_to_prisoner * prisoner_pull_strength * delta

	_face_dir(dir_from_dog_to_prisoner)
	_play_idle()

	_penalty_timer += delta
	if _penalty_timer >= penalty_tick:
		_penalty_timer = 0.0
		_apply_prisoner_penalty(_latched_target, true)


func _latch_to_target(player: Node2D) -> void:
	if player == null:
		return

	_latched_target = player
	_target = player
	velocity = Vector2.ZERO
	_penalty_timer = 0.0

	# one-time dog area penalty
	_apply_prisoner_penalty(player, false)


func release_player(player: Node2D) -> void:
	if player == null:
		return

	if _latched_target == player or _target == player:
		reset_to_start()


func reset_to_start() -> void:
	_latched_target = null
	_target = null
	_penalty_timer = 0.0
	velocity = Vector2.ZERO
	global_position = _start_position
	_patrol_index = 0
	_play_idle()


func _is_player_still_active(player: Node2D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if not player.is_in_group("players"):
		return false
	if "is_active" in player and not bool(player.get("is_active")):
		return false
	return true


func _apply_prisoner_penalty(player: Node2D, over_time: bool) -> void:
	var gm: Node = get_node_or_null("/root/Game/GameManager")
	if gm != null and gm.has_method("apply_dog_penalty"):
		gm.call("apply_dog_penalty", (player as Node).name, over_time)


func _face_dir(dir: Vector2) -> void:
	if dir.x > 0.01:
		anim.flip_h = false
	elif dir.x < -0.01:
		anim.flip_h = true


func _play_idle() -> void:
	if anim.animation != "idle":
		anim.play("idle")


func _play_run() -> void:
	if anim.animation != "run":
		anim.play("run")
