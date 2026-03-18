# =============================================================================
# player_red.gd  –  Autonomous Red Prisoner  (Minimax AI)
# =============================================================================
class_name Player_red
extends CharacterBody2D

@export var move_speed:        float = 400.0
@export var decision_interval: float = 0.5
@export var stuck_threshold:   float = 20.0
@export var history_length:    int   = 12

@onready var anim = $AnimatedSprite2D

var ai_direction:   Vector2 = Vector2.ZERO
var decision_timer: float   = 0.0
var is_active:      bool    = true
var minimax := Minimax.new()

var _pos_last:         Vector2    = Vector2.ZERO
var _position_history: Array     = []
var _cell_blocked:     Dictionary = {}


func _ready() -> void:
	_pos_last = global_position


func _physics_process(delta: float) -> void:
	if not is_active:
		velocity = Vector2.ZERO
		if anim.animation != "idle":
			anim.play("idle")
		return

	decision_timer += delta
	if decision_timer >= decision_interval:
		var cell   := _snap(global_position)
		var travel := global_position.distance_to(_pos_last)

		if travel < stuck_threshold and ai_direction != Vector2.ZERO:
			if not _cell_blocked.has(cell):
				_cell_blocked[cell] = []
			var b: Array = _cell_blocked[cell]
			if not b.has(ai_direction):
				b.append(ai_direction)

		if _position_history.is_empty() or _position_history.back() != cell:
			_position_history.append(cell)
			if _position_history.size() > history_length:
				_position_history.pop_front()

		_pos_last = global_position
		_make_ai_decision()
		decision_timer = 0.0

	var direction := ai_direction.normalized()
	velocity = direction * move_speed
	move_and_slide()

	if direction.x > 0.0:   anim.flip_h = false
	elif direction.x < 0.0: anim.flip_h = true

	if direction != Vector2.ZERO:
		if anim.animation != "run":  anim.play("run")
	else:
		if anim.animation != "idle": anim.play("idle")


func _make_ai_decision() -> void:
	var cell     := _snap(global_position)
	var all_dirs := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]

	var blocked: Array = _cell_blocked.get(cell, [])
	var free_dirs: Array = []
	for d in all_dirs:
		if not blocked.has(d):
			free_dirs.append(d)
	if free_dirs.is_empty():
		_cell_blocked.erase(cell)
		free_dirs = all_dirs.duplicate()

	var state = GameState.new()
	state.player_pos        = global_position
	state.visited_positions = _position_history.duplicate()

	var exit_node := get_node_or_null("/root/Game/Exit")
	state.exit_pos = exit_node.global_position if exit_node != null else Vector2.ZERO

	var guard_node := get_node_or_null("/root/Game/Police")
	if guard_node != null:
		state.guard_pos = guard_node.global_position

	for dog  in get_tree().get_nodes_in_group("dogs"):
		state.dog_positions.append((dog as Node2D).global_position)
	for fire in get_tree().get_nodes_in_group("fires"):
		state.fire_positions.append((fire as Node2D).global_position)
	for wall in get_tree().get_nodes_in_group("walls"):
		state.wall_positions.append((wall as Node2D).global_position)

	ai_direction = minimax.get_best_move_from(state, free_dirs)


static func _snap(pos: Vector2) -> Vector2:
	return pos.snapped(Vector2(64, 64))
