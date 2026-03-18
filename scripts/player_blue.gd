# =============================================================================
# player_blue.gd  –  Autonomous Blue Prisoner  (Monte Carlo AI)
#
# At each decision tick, every candidate direction is scored by running
# `num_simulations` random rollouts of depth `rollout_depth`.
# The direction whose average rollout score is highest is chosen.
# Same per-cell wall-registry as player_red so the player never hammers
# a blocked direction indefinitely.
# =============================================================================
class_name Player_blue
extends CharacterBody2D

# ── Tuning ────────────────────────────────────────────────────────────────────
@export var move_speed:        float = 400.0
@export var decision_interval: float = 0.5
@export var stuck_threshold:   float = 20.0
@export var history_length:    int   = 12
@export var num_simulations:   int   = 25   # rollouts per candidate direction
@export var rollout_depth:     int   = 12   # random steps per rollout

# ── Internal ──────────────────────────────────────────────────────────────────
@onready var anim = $AnimatedSprite2D

var ai_direction:   Vector2 = Vector2.ZERO
var decision_timer: float   = 0.0
var is_active:      bool    = true   # set false by GameManager when caught

var _pos_last:        Vector2    = Vector2.ZERO
var _position_history: Array    = []
var _cell_blocked:    Dictionary = {}

const GRID: float = 64.0


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

		# Register blocked direction if we didn't move
		if travel < stuck_threshold and ai_direction != Vector2.ZERO:
			if not _cell_blocked.has(cell):
				_cell_blocked[cell] = []
			var b: Array = _cell_blocked[cell]
			if not b.has(ai_direction):
				b.append(ai_direction)

		# Rolling position history for revisit penalty
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

	# ── Gather world state for rollouts ──────────────────────────────────────
	var exit_pos := Vector2.ZERO
	var exit_node := get_node_or_null("/root/Game/Exit")
	if exit_node != null:
		exit_pos = exit_node.global_position

	# Hazard list: Array of {pos, radius, penalty}
	var hazards: Array = []

	var guard_node := get_node_or_null("/root/Game/Police")
	if guard_node != null:
		hazards.append({"pos": guard_node.global_position, "r": 220.0, "p": 350.0})

	for dog in get_tree().get_nodes_in_group("dogs"):
		hazards.append({"pos": (dog as Node2D).global_position, "r": 160.0, "p": 180.0})

	for fire in get_tree().get_nodes_in_group("fires"):
		hazards.append({"pos": (fire as Node2D).global_position, "r": GRID, "p": 450.0})

	# ── Score each free direction via Monte Carlo rollouts ────────────────────
	var best_score := -INF
	var best_dir: Vector2 = free_dirs[0]

	for dir in free_dirs:
		var score := _monte_carlo_score(dir, exit_pos, hazards)
		if score > best_score:
			best_score = score
			best_dir   = dir

	ai_direction = best_dir


func _monte_carlo_score(initial_dir: Vector2, exit_pos: Vector2,
		hazards: Array) -> float:

	var total := 0.0
	var dirs  := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]

	for _i in num_simulations:
		var pos   := global_position + initial_dir * GRID
		var score := 0.0

		for _step in rollout_depth:
			# Reward: proximity to exit
			var dist_exit := pos.distance_to(exit_pos)
			score -= dist_exit * 0.08

			# Penalty: near hazards
			for h in hazards:
				var d := pos.distance_to(h["pos"])
				if d < h["r"]:
					score -= h["p"] * (1.0 - d / h["r"])

			# Penalty: revisit
			if _position_history.has(pos.snapped(Vector2(GRID, GRID))):
				score -= 90.0

			# Big reward for reaching exit
			if dist_exit < GRID:
				score += 1200.0
				break

			# Random next step
			dirs.shuffle()
			pos += dirs[0] * GRID

		total += score

	return total / num_simulations


static func _snap(pos: Vector2) -> Vector2:
	return pos.snapped(Vector2(GRID, GRID))
