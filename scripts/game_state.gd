class_name GameState

var player_pos: Vector2
var exit_pos:   Vector2

# Defaults to a far-away sentinel — a missing guard never fires a false penalty.
var guard_pos: Vector2 = Vector2(1e9, 1e9)

var dog_positions:     Array = []
var fire_positions:    Array = []
var wall_positions:    Array = []

# Recent world-positions the player has occupied (snapped to grid).
# Populated by Player_red before each minimax call.
# evaluate() penalises moves that land on any of these cells.
var visited_positions: Array = []

var grid_size := 64


func get_possible_moves() -> Array:
	return [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]


func simulate(move: Vector2) -> GameState:
	var new_state                 = GameState.new()
	new_state.player_pos          = player_pos + move * grid_size
	new_state.exit_pos            = exit_pos
	new_state.guard_pos           = guard_pos
	new_state.dog_positions       = dog_positions.duplicate()
	new_state.fire_positions      = fire_positions.duplicate()
	new_state.wall_positions      = wall_positions.duplicate()
	new_state.visited_positions   = visited_positions.duplicate()
	return new_state


func is_terminal() -> bool:
	if player_pos.distance_to(exit_pos)  < grid_size: return true
	if player_pos.distance_to(guard_pos) < grid_size: return true
	return false


func evaluate() -> float:
	var score := 0.0

	# Reward proximity to exit
	score -= player_pos.distance_to(exit_pos)

	# Guard penalty
	if player_pos.distance_to(guard_pos) < 200.0:
		score -= 300.0

	# Dog penalty
	for dog in dog_positions:
		if player_pos.distance_to(dog) < 150.0:
			score -= 200.0

	# Fire penalty
	for fire in fire_positions:
		if player_pos.distance_to(fire) < grid_size:
			score -= 400.0

	# Wall penalty
	for wall in wall_positions:
		if player_pos.distance_to(wall) < grid_size:
			score -= 500.0

	# ── Revisit penalty ───────────────────────────────────────────────────────
	# Cells visited most recently carry the heaviest penalty so the AI
	# strongly prefers unvisited territory.  Penalty decays with age so older
	# visits have less influence, allowing the player to backtrack when truly
	# necessary.
	var snapped := player_pos.snapped(Vector2(grid_size, grid_size))
	var count   := visited_positions.size()
	for i in count:
		var v: Vector2 = visited_positions[i]
		if v.snapped(Vector2(grid_size, grid_size)) == snapped:
			# Recency weight: newest entry is at index (count-1)
			var recency := float(i + 1) / float(count)   # 0.0 oldest … 1.0 newest
			score -= 150.0 * recency

	return score
