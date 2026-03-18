class_name Minimax

var MAX_DEPTH := 3


# Standard entry — uses all 4 directions.
func get_best_move(state: GameState) -> Vector2:
	return get_best_move_from(state, state.get_possible_moves())


# Entry point used by Player_red — only considers directions in `candidates`.
func get_best_move_from(state: GameState, candidates: Array) -> Vector2:
	var best_score := -INF
	var best_move  := Vector2.ZERO

	for move in candidates:
		var score := minimax(state.simulate(move), MAX_DEPTH - 1, false, -INF, INF)
		if score > best_score:
			best_score = score
			best_move  = move

	# Fallback: should never hit this, but guard against empty candidates
	if best_move == Vector2.ZERO and not candidates.is_empty():
		best_move = candidates[0]

	return best_move


# Kept for backwards-compat with ai_controller or any other caller.
func get_best_move_excluding(state: GameState, excluded: Vector2) -> Vector2:
	var candidates := state.get_possible_moves().filter(
		func(d): return d != excluded
	)
	return get_best_move_from(state, candidates)


func minimax(state: GameState, depth: int, maximizing: bool,
		alpha: float, beta: float) -> float:

	if depth == 0 or state.is_terminal():
		return state.evaluate()

	if maximizing:
		var max_eval := -INF
		for move in state.get_possible_moves():
			var eval := minimax(state.simulate(move), depth - 1, false, alpha, beta)
			max_eval = max(max_eval, eval)
			alpha    = max(alpha, eval)
			if beta <= alpha: break
		return max_eval
	else:
		var min_eval := INF
		for move in state.get_possible_moves():
			var eval := minimax(state.simulate(move), depth - 1, true, alpha, beta)
			min_eval = min(min_eval, eval)
			beta     = min(beta, eval)
			if beta <= alpha: break
		return min_eval
