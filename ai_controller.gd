# ai_controller.gd
extends Node2D
class_name AIController

@export var player: NodePath             # Path to AI-controlled player
@export var move_interval: float = 0.5
@export var move_speed: float = 200.0

var minimax_ai
var player_node
var timer := 0.0
var target_position: Vector2 = Vector2.ZERO
var moving: bool = false

func _ready():
	minimax_ai = Minimax.new()
	player_node = get_node(player)
	target_position = player_node.position

func _process(delta):
	if moving:
		move_player_smooth(delta)
	else:
		timer += delta
		if timer >= move_interval:
			timer = 0
			make_ai_move()

func make_ai_move():
	var state = GameState.new()
	state.player_pos = player_node.position

	# --- Collect hazard positions from groups ---
	state.dog_positions.clear()
	for dog in get_tree().get_nodes_in_group("Dogs"):
		state.dog_positions.append(dog.global_position)

	state.fire_positions.clear()
	for fire in get_tree().get_nodes_in_group("Fires"):
		state.fire_positions.append(fire.global_position)

	state.wall_positions.clear()
	for wall in get_tree().get_nodes_in_group("Walls"):
		state.wall_positions.append(wall.global_position)

	# --- COMMENTING OUT EXIT for now ---
	# state.exit_pos = get_node("Exit").global_position

	# Get the best move from Minimax AI
	var best_move = minimax_ai.get_best_move(state)

	# Set the target position to move smoothly
	target_position = player_node.position + best_move * state.grid_size
	moving = true

func move_player_smooth(delta):
	var direction = (target_position - player_node.position).normalized()
	var distance = move_speed * delta
	
	if player_node.position.distance_to(target_position) <= distance:
		player_node.position = target_position
		moving = false
	else:
		player_node.position += direction * distance
