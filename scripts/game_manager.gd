# =============================================================================
# game_manager.gd  –  Match controller + scoring
# =============================================================================
class_name GameManager
extends Node

signal player_status_changed(player_name: String, status: String)
signal player_score_changed(player_name: String, score: int)
signal player_stats_changed(player_name: String, score: int, captures: int)
signal timer_changed(seconds_left: int)
signal game_over(result: String, standings: Array)

const STATUS_RUNNING: String = "RUNNING"
const STATUS_ESCAPED: String = "ESCAPED"
const STATUS_ELIMINATED: String = "ELIMINATED"
const STATUS_BURNED: String = "BURNED"

const MATCH_DURATION: float = 120.0
const MAX_CAPTURES: int = 3
const SCORE_TICK: float = 0.40
const EXIT_RADIUS: float = 110.0

const ESCAPE_BONUS: int = 320
const CAUGHT_PENALTY: int = -220
const DOG_ENTER_PENALTY: int = -20
const FIRE_ENTER_PENALTY: int = -35
const DOG_TICK_PENALTY: int = -8
const FIRE_TICK_PENALTY: int = -15

const POLICE_CATCH_BONUS: int = 320
const POLICE_ESCAPE_PENALTY: int = -160

const POLICE_NAME: String = "Police"

var _status: Dictionary = {}
var _scores: Dictionary = {}
var _captures: Dictionary = {}
var _start_positions: Dictionary = {}
var _last_positions: Dictionary = {}
var _escape_order: Array[String] = []
var _game_ended: bool = false
var _time_left: float = MATCH_DURATION
var _score_timer: float = 0.0
var _last_timer_whole: int = -1

var _police_start_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	call_deferred("_connect_signals")


func _connect_signals() -> void:
	for player in get_tree().get_nodes_in_group("players"):
		var p: Node2D = player as Node2D
		var name: String = (player as Node).name
		_status[name] = STATUS_RUNNING
		_scores[name] = 0
		_captures[name] = 0
		_start_positions[name] = p.global_position
		_last_positions[name] = p.global_position
		emit_signal("player_status_changed", name, STATUS_RUNNING)
		emit_signal("player_score_changed", name, 0)
		emit_signal("player_stats_changed", name, 0, 0)

	var police: Node2D = get_node_or_null("/root/Game/Police") as Node2D
	if police != null:
		_police_start_pos = police.global_position
		_status[POLICE_NAME] = STATUS_RUNNING
		_scores[POLICE_NAME] = 0
		_captures[POLICE_NAME] = 0
		emit_signal("player_status_changed", POLICE_NAME, STATUS_RUNNING)
		emit_signal("player_score_changed", POLICE_NAME, 0)
		emit_signal("player_stats_changed", POLICE_NAME, 0, 0)

		if police.has_signal("player_caught"):
			police.player_caught.connect(_on_player_caught)

	for fire in get_tree().get_nodes_in_group("fires"):
		if fire.has_signal("player_burned"):
			(fire as Node).player_burned.connect(_on_player_burned)

	_emit_timer()


func _process(delta: float) -> void:
	if _game_ended:
		return

	_time_left = maxf(0.0, _time_left - delta)
	_score_timer += delta
	_emit_timer()

	if _score_timer >= SCORE_TICK:
		_score_timer = 0.0
		_apply_continuous_scoring()

	_check_exit_reaches()

	if _time_left <= 0.0:
		_finish_game("timeout")
		return

	_check_game_over()


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
		return Vector2.ZERO

	var best_pos: Vector2 = (exits[0] as Node2D).global_position
	var best_dist: float = from_pos.distance_to(best_pos)

	for exit_node_var in exits:
		var exit_node: Node2D = exit_node_var as Node2D
		var d: float = from_pos.distance_to(exit_node.global_position)
		if d < best_dist:
			best_dist = d
			best_pos = exit_node.global_position

	return best_pos


func _check_exit_reaches() -> void:
	var exits: Array = _get_exit_nodes()
	if exits.is_empty():
		return

	for player in get_tree().get_nodes_in_group("players"):
		var p: Node2D = player as Node2D
		var name: String = (player as Node).name
		if _status.get(name, "") != STATUS_RUNNING:
			continue

		for exit_node_var in exits:
			var exit_node: Node2D = exit_node_var as Node2D
			if p.global_position.distance_to(exit_node.global_position) <= EXIT_RADIUS:
				_on_player_escaped(player as Node)
				break


func _apply_continuous_scoring() -> void:
	var police: Node2D = get_node_or_null("/root/Game/Police") as Node2D

	for player in get_tree().get_nodes_in_group("players"):
		var p: Node2D = player as Node2D
		var name: String = (player as Node).name
		if _status.get(name, "") != STATUS_RUNNING:
			continue

		var exit_pos: Vector2 = _get_nearest_exit_position(p.global_position)
		if exit_pos == Vector2.ZERO:
			continue

		var prev: Vector2 = _last_positions.get(name, p.global_position)
		var prev_dist: float = prev.distance_to(exit_pos)
		var now_dist: float = p.global_position.distance_to(exit_pos)
		var progress_px: float = prev_dist - now_dist
		var delta_score: int = 0

		delta_score += int(round(progress_px / 18.0))
		delta_score += int(round(clampf(1.0 - now_dist / 2200.0, 0.0, 1.0) * 4.0))

		if p.global_position.distance_to(prev) < 8.0:
			delta_score -= 1
		else:
			delta_score += 1

		if police != null:
			var police_dist: float = p.global_position.distance_to(police.global_position)
			if police_dist < 260.0:
				delta_score -= 4
			elif police_dist < 420.0:
				delta_score -= 2

		_add_score(name, delta_score)
		_last_positions[name] = p.global_position


func _on_player_escaped(player: Node) -> void:
	var name: String = player.name
	if _status.get(name, "") != STATUS_RUNNING:
		return

	_release_dogs_from_player(player as Node2D)

	_status[name] = STATUS_ESCAPED
	_escape_order.append(name)

	_add_score(name, ESCAPE_BONUS)
	_add_score(POLICE_NAME, POLICE_ESCAPE_PENALTY)
	_emit_signal_pack(name)
	_emit_signal_pack(POLICE_NAME)

	if "is_active" in player:
		player.set("is_active", false)

	player.remove_from_group("players")
	_check_game_over()


func handle_player_caught(player: Node2D) -> void:
	_on_player_caught(player)


func _on_player_caught(player: Node2D) -> void:
	var name: String = (player as Node).name
	if _status.get(name, "") != STATUS_RUNNING:
		return

	_release_dogs_from_player(player)

	var police: Node2D = get_node_or_null("/root/Game/Police") as Node2D
	var running_before_catch: int = _count_running_prisoners()

	_add_score(name, CAUGHT_PENALTY)
	_add_score(POLICE_NAME, POLICE_CATCH_BONUS)
	_captures[name] = int(_captures.get(name, 0)) + 1
	_captures[POLICE_NAME] = int(_captures.get(POLICE_NAME, 0)) + 1

	if int(_captures[name]) >= MAX_CAPTURES:
		_status[name] = STATUS_ELIMINATED
		_emit_signal_pack(name)

		if "is_active" in player:
			player.set("is_active", false)

		player.remove_from_group("players")
		_check_game_over()
	else:
		_respawn_player(player)

		if running_before_catch == 1 and police != null:
			_respawn_police(police)

		_emit_signal_pack(name)

	_emit_signal_pack(POLICE_NAME)

	if police != null and police.has_method("clear_caught_player"):
		police.call("clear_caught_player", player)


func _on_player_burned(player: Node2D) -> void:
	var name: String = (player as Node).name
	if _status.get(name, "") != STATUS_RUNNING:
		return

	_release_dogs_from_player(player)

	_add_score(name, FIRE_ENTER_PENALTY)
	_status[name] = STATUS_BURNED
	_emit_signal_pack(name)

	if "is_active" in player:
		player.set("is_active", false)

	player.remove_from_group("players")
	_check_game_over()


func _respawn_player(player: Node2D) -> void:
	_release_dogs_from_player(player)

	var name: String = (player as Node).name
	var start_pos: Vector2 = _start_positions.get(name, player.global_position)
	player.global_position = start_pos
	_last_positions[name] = start_pos

	if "velocity" in player:
		player.set("velocity", Vector2.ZERO)
	if "ai_direction" in player:
		player.set("ai_direction", Vector2.ZERO)


func _respawn_police(police: Node2D) -> void:
	police.global_position = _police_start_pos

	if "velocity" in police:
		police.set("velocity", Vector2.ZERO)
	if "ai_direction" in police:
		police.set("ai_direction", Vector2.ZERO)
	if police.has_method("reset_after_respawn"):
		police.call("reset_after_respawn")


func _release_dogs_from_player(player: Node2D) -> void:
	for dog in get_tree().get_nodes_in_group("dogs"):
		if dog.has_method("release_player"):
			dog.call("release_player", player)


func _count_running_prisoners() -> int:
	var count: int = 0
	for name in _status.keys():
		if name == POLICE_NAME:
			continue
		if String(_status.get(name, "")) == STATUS_RUNNING:
			count += 1
	return count


func _check_game_over() -> void:
	if _game_ended:
		return

	for name in _status.keys():
		if name == POLICE_NAME:
			continue
		if _status[name] == STATUS_RUNNING:
			return

	_finish_game("resolved")


func _finish_game(reason: String) -> void:
	if _game_ended:
		return

	_game_ended = true
	var standings: Array = _build_standings()
	var result: String = "partial"

	var escaped: int = 0
	var prisoner_total: int = 0

	for name in _status.keys():
		if name == POLICE_NAME:
			continue
		prisoner_total += 1
		if _status[name] == STATUS_ESCAPED:
			escaped += 1

	if escaped == prisoner_total and prisoner_total > 0:
		result = "all_escaped"
	elif escaped == 0:
		result = "all_caught"
	elif reason == "timeout":
		result = "timeout"

	emit_signal("game_over", result, standings)


func _build_standings() -> Array:
	var rows: Array = []

	for name in _status.keys():
		rows.append({
			"name": name,
			"score": int(_scores.get(name, 0)),
			"captures": int(_captures.get(name, 0)),
			"status": String(_status.get(name, STATUS_RUNNING)),
			"escaped_rank": _escape_order.find(name)
		})

	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) > int(b["score"])

		var a_escaped: bool = String(a["status"]) == STATUS_ESCAPED
		var b_escaped: bool = String(b["status"]) == STATUS_ESCAPED

		if a_escaped != b_escaped:
			return a_escaped

		if a_escaped and b_escaped:
			return int(a["escaped_rank"]) < int(b["escaped_rank"])

		return int(a["captures"]) < int(b["captures"])
	)

	return rows


func _emit_signal_pack(player_name: String) -> void:
	emit_signal("player_status_changed", player_name, String(_status.get(player_name, STATUS_RUNNING)))
	emit_signal("player_score_changed", player_name, int(_scores.get(player_name, 0)))
	emit_signal("player_stats_changed", player_name, int(_scores.get(player_name, 0)), int(_captures.get(player_name, 0)))


func _add_score(player_name: String, delta: int) -> void:
	_scores[player_name] = int(_scores.get(player_name, 0)) + delta
	emit_signal("player_score_changed", player_name, int(_scores[player_name]))
	emit_signal("player_stats_changed", player_name, int(_scores[player_name]), int(_captures.get(player_name, 0)))


func _emit_timer() -> void:
	var seconds_left: int = int(ceil(_time_left))
	if seconds_left != _last_timer_whole:
		_last_timer_whole = seconds_left
		emit_signal("timer_changed", seconds_left)


func get_player_score(player_name: String) -> int:
	return int(_scores.get(player_name, 0))


func get_player_captures(player_name: String) -> int:
	return int(_captures.get(player_name, 0))


func apply_dog_penalty(player_name: String, over_time: bool = false) -> void:
	if _status.get(player_name, "") != STATUS_RUNNING:
		return
	_add_score(player_name, DOG_TICK_PENALTY if over_time else DOG_ENTER_PENALTY)


func apply_fire_penalty(player_name: String, over_time: bool = false) -> void:
	if _status.get(player_name, "") != STATUS_RUNNING:
		return
	_add_score(player_name, FIRE_TICK_PENALTY if over_time else FIRE_ENTER_PENALTY)
