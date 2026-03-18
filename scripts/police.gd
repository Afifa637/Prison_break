# =============================================================================
# police.gd  –  Smart Police with Wall Following + BFS (NO LOOPS GUARANTEED)
# Combines multi-step look-ahead with wall-following and BFS pathfinding
# =============================================================================
class_name Police
extends CharacterBody2D

# ── Speed Settings ────────────────────────────────────────────────────────────
@export var patrol_speed: float = 220.0
@export var investigate_speed: float = 320.0
@export var chase_speed: float = 500.0
@export var catch_radius: float = 120.0

# ── AI Timing ─────────────────────────────────────────────────────────────────
@export var decision_interval: float = 0.10
@export var stuck_threshold: float = 12.0
@export var history_length: int = 15
@export var look_ahead_steps: int = 4

# ── Pathfinding ───────────────────────────────────────────────────────────────
@export var use_bfs_when_blocked: bool = true
@export var max_bfs_depth: int = 30

# ── Fuzzy Weights ─────────────────────────────────────────────────────────────
@export var weight_exit_threat: float = 0.50
@export var weight_proximity: float = 0.35
@export var weight_low_stealth: float = 0.15

# ── Alert System ──────────────────────────────────────────────────────────────
@export var alert_decay: float = 0.18
@export var alert_on_bark: float = 0.65
@export var alert_on_fire: float = 0.85
@export var exit_guard_distance: float = 360.0

# ── Debug ─────────────────────────────────────────────────────────────────────
@export var debug_mode: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

signal player_caught(player: Node2D)

# ── Internal State ────────────────────────────────────────────────────────────
var ai_direction: Vector2 = Vector2.ZERO
var decision_timer: float = 0.0
var _pos_last: Vector2 = Vector2.ZERO

var _current_behav: String = "PATROL"
var _alert_level: float = 0.0
var _alert_target: Vector2 = Vector2.ZERO
var _caught_players: Array = []
var _last_target_player_name: String = ""

# Enhanced obstacle tracking
var _globally_blocked: Dictionary = {}
var _position_history: Array = []
var _stuck_counter: int = 0
var _loop_detection: Array = []  # Track last 8 positions to detect loops

# BFS pathfinding
var _bfs_path: Array[Vector2] = []
var _bfs_index: int = 0
var _bfs_goal: Vector2 = Vector2.ZERO
var _using_bfs: bool = false

# Wall following
var _wall_follow_mode: bool = false
var _wall_follow_timer: float = 0.0
var _wall_side: int = 1  # 1 = right, -1 = left

# Patrol
var _patrol_points: Array[Vector2] = []
var _patrol_index: int = 0

const GRID: float = 64.0
const DIRECTIONS: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
const DIAGONAL_DIRS: Array[Vector2] = [
	Vector2.RIGHT + Vector2.UP, Vector2.RIGHT + Vector2.DOWN,
	Vector2.LEFT + Vector2.UP, Vector2.LEFT + Vector2.DOWN
]
const ALL_DIRS: Array[Vector2] = [
	Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
	Vector2.RIGHT + Vector2.UP, Vector2.RIGHT + Vector2.DOWN,
	Vector2.LEFT + Vector2.UP, Vector2.LEFT + Vector2.DOWN
]


func _ready() -> void:
	add_to_group("police")
	_pos_last = global_position
	call_deferred("_late_ready")


func _late_ready() -> void:
	_seed_patrol_points()
	_connect_dogs()
	if debug_mode:
		print("Police: Wall-following + BFS navigation initialized")


func _physics_process(delta: float) -> void:
	_alert_level = maxf(0.0, _alert_level - alert_decay * delta)
	decision_timer += delta
	_wall_follow_timer = maxf(0.0, _wall_follow_timer - delta)

	if decision_timer >= decision_interval:
		var cell := _snap(global_position)
		var travel := global_position.distance_to(_pos_last)

		# Detect stuck
		if travel < stuck_threshold and ai_direction != Vector2.ZERO:
			_stuck_counter += 1
			
			# Mark as blocked
			var block_key := str(cell) + str(ai_direction)
			if not _globally_blocked.has(block_key):
				_globally_blocked[block_key] = 0
			_globally_blocked[block_key] = int(_globally_blocked[block_key]) + 1
			
			if _stuck_counter >= 2:
				_handle_stuck()
				_stuck_counter = 0
		else:
			_stuck_counter = 0

		# Loop detection
		if _position_history.is_empty() or _position_history.back() != cell:
			_position_history.append(cell)
			if _position_history.size() > history_length:
				_position_history.pop_front()
			
			# Check for loops (visiting same position within last 8 moves)
			_loop_detection.append(cell)
			if _loop_detection.size() > 8:
				_loop_detection.pop_front()
			
			if _detect_loop():
				if debug_mode:
					print("Police: LOOP DETECTED! Switching to BFS")
				_activate_bfs_pathfinding(_get_current_goal())

		_pos_last = global_position
		_make_decision()
		decision_timer = 0.0

	# Move
	velocity = ai_direction.normalized() * _get_speed()
	move_and_slide()

	# Animation
	if ai_direction.x > 0.01:
		anim.flip_h = false
	elif ai_direction.x < -0.01:
		anim.flip_h = true

	if velocity.length() > 8.0:
		if anim.animation != "run":
			anim.play("run")
	else:
		if anim.animation != "idle":
			anim.play("idle")

	_check_catch()


func _detect_loop() -> bool:
	if _loop_detection.size() < 6:
		return false
	
	# Check if we're cycling through same 3-4 positions
	var recent := _loop_detection.slice(-4)
	var older := _loop_detection.slice(-8, -4)
	
	for pos in recent:
		if older.has(pos):
			return true  # We're revisiting positions = loop
	
	return false


func _handle_stuck() -> void:
	if use_bfs_when_blocked:
		# Try BFS pathfinding
		_activate_bfs_pathfinding(_get_current_goal())
	else:
		# Fallback: wall following
		_wall_follow_mode = true
		_wall_follow_timer = 1.5
		_wall_side = 1 if randf() > 0.5 else -1
		if debug_mode:
			print("Police: STUCK! Entering wall-follow mode")


func _get_current_goal() -> Vector2:
	var players := _get_active_players()
	if not players.is_empty():
		var target := _pick_priority_target(players)
		if target != null:
			return target.global_position
	return _get_current_patrol_goal()


func reset_after_respawn() -> void:
	_alert_level = 0.0
	_alert_target = Vector2.ZERO
	_last_target_player_name = ""
	ai_direction = Vector2.ZERO
	velocity = Vector2.ZERO
	_globally_blocked.clear()
	_position_history.clear()
	_loop_detection.clear()
	_stuck_counter = 0
	_using_bfs = false
	_bfs_path.clear()
	_wall_follow_mode = false


func _connect_dogs() -> void:
	for dog in get_tree().get_nodes_in_group("dogs"):
		if dog.has_signal("player_spotted") and not (dog as Node).player_spotted.is_connected(_on_dog_alert):
			(dog as Node).player_spotted.connect(_on_dog_alert)


func alert_player_near_fire(alert_pos: Vector2) -> void:
	_alert_target = alert_pos
	_alert_level = minf(1.0, _alert_level + alert_on_fire)


func _on_dog_alert(alert_position: Vector2) -> void:
	_alert_target = alert_position
	_alert_level = minf(1.0, _alert_level + alert_on_bark)


# ══════════════════════════════════════════════════════════════════════════════
# DECISION MAKING
# ══════════════════════════════════════════════════════════════════════════════
func _make_decision() -> void:
	# Priority 1: Follow BFS path if active
	if _using_bfs and not _bfs_path.is_empty():
		_follow_bfs_path()
		return
	
	# Priority 2: Wall following mode
	if _wall_follow_mode and _wall_follow_timer > 0.0:
		ai_direction = _get_wall_follow_direction()
		return
	
	# Priority 3: Normal behavior
	var players: Array = _get_active_players()

	if players.is_empty():
		_current_behav = "PATROL"
		ai_direction = _get_smart_direction_to(_get_current_patrol_goal())
		return

	var target: Node2D = _pick_priority_target(players)
	if target == null:
		_current_behav = "PATROL"
		ai_direction = _get_smart_direction_to(_get_current_patrol_goal())
		return

	var target_pos: Vector2 = target.global_position
	var exit_threat: float = _compute_exit_threat(target)

	var goal: Vector2
	if exit_threat >= 0.72 or target_pos.distance_to(_get_nearest_exit_position(target_pos)) < exit_guard_distance:
		_current_behav = "INTERCEPT"
		var exit_pos := _get_nearest_exit_position(target_pos)
		goal = target_pos + (exit_pos - target_pos).normalized() * GRID * 2.5
	else:
		var alert_match: float = 0.0
		if _alert_target != Vector2.ZERO:
			alert_match = clampf(1.0 - target_pos.distance_to(_alert_target) / 800.0, 0.0, 1.0)

		if _alert_level > 0.50 and alert_match < 0.20:
			_current_behav = "INVESTIGATE"
			goal = _alert_target
		else:
			_current_behav = "CHASE"
			goal = target_pos

	_last_target_player_name = (target as Node).name
	ai_direction = _get_smart_direction_to(goal)


func _get_speed() -> float:
	match _current_behav:
		"CHASE", "INTERCEPT":
			return chase_speed
		"INVESTIGATE":
			return investigate_speed
		_:
			return patrol_speed


func _get_active_players() -> Array:
	var active: Array = []
	for player in get_tree().get_nodes_in_group("players"):
		var p: Node2D = player as Node2D
		if p in _caught_players:
			continue
		if "is_active" in p and not bool(p.get("is_active")):
			continue
		active.append(p)
	return active


func _pick_priority_target(players: Array) -> Node2D:
	var best: Node2D = null
	var best_score: float = -INF

	for p in players:
		var prisoner: Node2D = p as Node2D
		var ppos: Vector2 = prisoner.global_position

		var exit_threat: float = _compute_exit_threat(prisoner)
		var proximity: float = _compute_proximity(ppos)
		var low_stealth: float = _compute_low_stealth_threat(prisoner)

		var total: float = (
			exit_threat * weight_exit_threat +
			proximity * weight_proximity +
			low_stealth * weight_low_stealth
		)

		if _alert_target != Vector2.ZERO:
			var alert_match: float = clampf(1.0 - ppos.distance_to(_alert_target) / 900.0, 0.0, 1.0)
			total += alert_match * 0.10

		if (prisoner as Node).name == _last_target_player_name:
			total += 0.10

		if total > best_score:
			best_score = total
			best = prisoner

	return best


func _compute_exit_threat(player: Node2D) -> float:
	var exit_pos: Vector2 = _get_nearest_exit_position(player.global_position)
	var d: float = player.global_position.distance_to(exit_pos)
	return clampf(1.0 - d / 1400.0, 0.0, 1.0)


func _compute_proximity(target_pos: Vector2) -> float:
	var d: float = global_position.distance_to(target_pos)
	return clampf(1.0 - d / 1000.0, 0.0, 1.0)


func _compute_low_stealth_threat(player: Node2D) -> float:
	var node := player as Node
	if "stealth" in player:
		return clampf(1.0 - float(player.get("stealth")), 0.0, 1.0)
	if "stealth_level" in player:
		return clampf(1.0 - float(player.get("stealth_level")), 0.0, 1.0)
	if "visibility" in player:
		return clampf(float(player.get("visibility")), 0.0, 1.0)
	if "noise_level" in player:
		return clampf(float(player.get("noise_level")), 0.0, 1.0)
	if node.has_method("get_stealth"):
		return clampf(1.0 - float(node.call("get_stealth")), 0.0, 1.0)
	return 0.5


# ══════════════════════════════════════════════════════════════════════════════
# BFS PATHFINDING (GUARANTEED NO LOOPS)
# ══════════════════════════════════════════════════════════════════════════════
func _activate_bfs_pathfinding(goal: Vector2) -> void:
	_bfs_goal = goal
	var path := _find_bfs_path(global_position, goal)
	
	if path.is_empty():
		if debug_mode:
			print("Police: BFS found no path, using greedy")
		_using_bfs = false
		_wall_follow_mode = true
		_wall_follow_timer = 1.0
	else:
		_bfs_path = path
		_bfs_index = 0
		_using_bfs = true
		_loop_detection.clear()  # Reset loop detection
		if debug_mode:
			print("Police: BFS path found with ", path.size(), " waypoints")


func _find_bfs_path(start: Vector2, goal: Vector2) -> Array[Vector2]:
	var start_cell := _snap(start)
	var goal_cell := _snap(goal)
	
	var queue: Array = [start_cell]
	var visited: Dictionary = {start_cell: true}
	var came_from: Dictionary = {}
	var depth := 0
	
	while not queue.is_empty() and depth < max_bfs_depth:
		var current: Vector2 = queue.pop_front()
		depth += 1
		
		# Reached goal?
		if current.distance_to(goal_cell) <= GRID * 1.2:
			return _reconstruct_bfs_path(came_from, current)
		
		# Try all 8 directions
		for dir in ALL_DIRS:
			var neighbor := _snap(current + dir.normalized() * GRID)
			
			if visited.has(neighbor):
				continue
			
			# Check if this direction is known to be blocked
			var block_key := str(current) + str(dir)
			if int(_globally_blocked.get(block_key, 0)) > 3:  # Only skip if blocked many times
				continue
			
			visited[neighbor] = true
			came_from[neighbor] = current
			queue.append(neighbor)
	
	return []  # No path found


func _reconstruct_bfs_path(came_from: Dictionary, end: Vector2) -> Array[Vector2]:
	var path: Array[Vector2] = [end]
	var current := end
	
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	
	return path


func _follow_bfs_path() -> void:
	# Skip reached waypoints
	while _bfs_index < _bfs_path.size():
		var waypoint: Vector2 = _bfs_path[_bfs_index]
		if global_position.distance_to(waypoint) <= GRID * 0.4:
			_bfs_index += 1
		else:
			break
	
	# Finished path?
	if _bfs_index >= _bfs_path.size():
		_using_bfs = false
		_bfs_path.clear()
		if debug_mode:
			print("Police: BFS path complete")
		return
	
	# Move toward next waypoint
	var target: Vector2 = _bfs_path[_bfs_index]
	ai_direction = (target - global_position).normalized()


# ══════════════════════════════════════════════════════════════════════════════
# WALL FOLLOWING
# ══════════════════════════════════════════════════════════════════════════════
func _get_wall_follow_direction() -> Vector2:
	# Try to move along wall edge
	var forward := ai_direction if ai_direction != Vector2.ZERO else Vector2.RIGHT
	var right := Vector2(forward.y, -forward.x) * float(_wall_side)
	
	# Priority: forward, forward+right diagonal, right, backward
	var try_dirs := [forward, forward + right, right, -forward]
	
	for dir in try_dirs:
		var check_pos := _snap(global_position + dir.normalized() * GRID)
		var block_key := str(_snap(global_position)) + str(dir.normalized())
		
		if int(_globally_blocked.get(block_key, 0)) == 0:
			return dir.normalized()
	
	# All blocked, reverse
	return -forward


# ══════════════════════════════════════════════════════════════════════════════
# SMART MULTI-STEP LOOK-AHEAD NAVIGATION
# ══════════════════════════════════════════════════════════════════════════════
func _get_smart_direction_to(target_pos: Vector2) -> Vector2:
	var cell := _snap(global_position)
	var candidates: Array = []

	# Evaluate all 8 directions (including diagonals)
	for dir in ALL_DIRS:
		var score: float = _evaluate_direction(cell, dir, target_pos)
		candidates.append({"dir": dir, "score": score})

	# Sort by best score
	candidates.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
	
	# If best direction has terrible score, activate BFS
	var best_score := float(candidates[0]["score"])
	if best_score < -50.0 and use_bfs_when_blocked:
		_activate_bfs_pathfinding(target_pos)
		if _using_bfs:
			_follow_bfs_path()
			return ai_direction
	
	# Return best direction
	return candidates[0]["dir"] as Vector2


func _evaluate_direction(start_cell: Vector2, direction: Vector2, target_pos: Vector2) -> float:
	var score: float = 0.0
	var current_cell: Vector2 = start_cell
	var dir_normalized := direction.normalized()
	
	# Multi-step simulation
	for step in range(look_ahead_steps):
		current_cell = _snap(_cell_to_world(current_cell) + dir_normalized * GRID)
		
		# Check if blocked
		var block_key := str(current_cell) + str(dir_normalized)
		var block_count: int = int(_globally_blocked.get(block_key, 0))
		
		if block_count > 0:
			score -= 100.0 * float(block_count)
			break
		
		# Reward getting closer to target
		var world_pos := _cell_to_world(current_cell)
		var dist_to_target: float = world_pos.distance_to(target_pos)
		score += 25.0 / maxf(1.0, dist_to_target / 100.0)
	
	# Penalty for revisiting recent cells
	var next_cell := _snap(global_position + dir_normalized * GRID)
	if _position_history.has(next_cell):
		score -= 20.0
	
	# Strong bonus for alignment with target
	var to_target := (target_pos - global_position).normalized()
	var alignment := dir_normalized.dot(to_target)
	score += alignment * 30.0

	return score


func _get_intercept_direction(player: Node2D) -> Vector2:
	var exit_pos: Vector2 = _get_nearest_exit_position(player.global_position)
	var intercept_point: Vector2 = player.global_position + (exit_pos - player.global_position).normalized() * GRID * 3.0
	return _get_smart_direction_to(intercept_point)


# ══════════════════════════════════════════════════════════════════════════════
# PATROL & EXITS
# ══════════════════════════════════════════════════════════════════════════════
func _get_current_patrol_goal() -> Vector2:
	if _patrol_points.is_empty():
		return global_position + Vector2(100, 0)

	var target: Vector2 = _patrol_points[_patrol_index]
	
	if global_position.distance_to(target) <= GRID:
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()
		target = _patrol_points[_patrol_index]
	
	return target


func _seed_patrol_points() -> void:
	_patrol_points.clear()
	var exit_pos: Vector2 = _get_nearest_exit_position(global_position)
	var center: Vector2 = global_position

	_patrol_points.append(center + Vector2(-256, 0))
	_patrol_points.append(center + Vector2(0, -192))
	_patrol_points.append(center + Vector2(256, 0))
	_patrol_points.append(exit_pos + Vector2(0, -128))
	_patrol_points.append(center + Vector2(-128, 192))


func _get_exit_nodes() -> Array:
	var exits: Array = []
	for node in get_tree().get_nodes_in_group("exits"):
		if node is Node2D:
			exits.append(node)
	if exits.is_empty():
		var single_exit: Node2D = get_node_or_null("/root/Game/Exit") as Node2D
		if single_exit != null:
			exits.append(single_exit)
	return exits


func _get_nearest_exit_position(from_pos: Vector2) -> Vector2:
	var exits: Array = _get_exit_nodes()
	if exits.is_empty():
		return from_pos + Vector2(500, 0)

	var best_pos: Vector2 = (exits[0] as Node2D).global_position
	var best_dist: float = from_pos.distance_to(best_pos)

	for exit_var in exits:
		var exit_node: Node2D = exit_var as Node2D
		var d: float = from_pos.distance_to(exit_node.global_position)
		if d < best_dist:
			best_dist = d
			best_pos = exit_node.global_position

	return best_pos


func _check_catch() -> void:
	for player in get_tree().get_nodes_in_group("players"):
		var p: Node2D = player as Node2D
		if p in _caught_players:
			continue
		if global_position.distance_to(p.global_position) <= catch_radius:
			_caught_players.append(p)
			emit_signal("player_caught", p)
			if debug_mode:
				print("Police: ★★★ CAUGHT ", (p as Node).name, " ★★★")


func clear_caught_player(player: Node2D) -> void:
	_caught_players.erase(player)


func _cell_to_world(cell: Vector2) -> Vector2:
	return cell


static func _snap(pos: Vector2) -> Vector2:
	return pos.snapped(Vector2(GRID, GRID))
