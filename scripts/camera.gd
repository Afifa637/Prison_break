# =============================================================================
# camera.gd  –  Simulation Overview Camera
#
# Follows the centroid of all nodes in the "players" group so both
# prisoners stay in frame throughout the simulation.
# Zoom adjusts automatically to keep both players visible.
# =============================================================================
extends Camera2D

@export var follow_speed:  float = 4.0    # position lerp speed
@export var zoom_speed:    float = 2.0    # zoom lerp speed
@export var zoom_padding:  float = 400.0  # world-unit margin around players
@export var zoom_min:      float = 0.2    # most zoomed-out
@export var zoom_max:      float = 0.5    # most zoomed-in


func _process(delta: float) -> void:
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return

	# ── Target position: centroid of all players ──────────────────────────────
	var centre := Vector2.ZERO
	for p in players:
		centre += (p as Node2D).global_position
	centre /= players.size()

	global_position = global_position.lerp(centre, follow_speed * delta)

	# ── Target zoom: fit all players inside the viewport ──────────────────────
	if players.size() > 1:
		var min_pos: Vector2 = (players[0] as Node2D).global_position
		var max_pos: Vector2 = (players[0] as Node2D).global_position
		for p in players:
			var pos: Vector2 = (p as Node2D).global_position
			min_pos = min_pos.min(pos)
			max_pos = max_pos.max(pos)

		var spread: Vector2 = (max_pos - min_pos) + Vector2(zoom_padding, zoom_padding) * 2.0
		var viewport        := get_viewport_rect().size
		var target_z        := minf(viewport.x / spread.x, viewport.y / spread.y)
		target_z             = clampf(target_z, zoom_min, zoom_max)
		zoom                 = zoom.lerp(Vector2(target_z, target_z), zoom_speed * delta)
	else:
		zoom = zoom.lerp(Vector2(zoom_max, zoom_max), zoom_speed * delta)
