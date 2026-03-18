# =============================================================================
# fire.gd  –  Fire hazard
# Works with current fire scene:
#   fire (CharacterBody2D)
#   ├── AnimatedSprite2D
#   └── CollisionShape2D
# =============================================================================
class_name Fire
extends CharacterBody2D

@export var burn_radius: float = 70.0
@export var penalty_tick: float = 0.75
@export var slow_push_strength: float = 35.0
@export var eliminate_on_touch: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

signal player_burned(player: Node2D)

var _inside_players: Dictionary = {}


func _ready() -> void:
	add_to_group("fires")
	anim.play("fire")


func _process(delta: float) -> void:
	for player in get_tree().get_nodes_in_group("players"):
		var p: Node2D = player as Node2D
		if p == null:
			continue
		if "is_active" in p and not bool(p.get("is_active")):
			continue

		var inside: bool = global_position.distance_to(p.global_position) <= burn_radius

		if inside:
			if not _inside_players.has(p):
				_inside_players[p] = 0.0
				_apply_fire_penalty(p, false)
				_alert_police(p.global_position)

				if eliminate_on_touch:
					emit_signal("player_burned", p)

			_inside_players[p] += delta

			if float(_inside_players[p]) >= penalty_tick:
				_inside_players[p] = 0.0
				_apply_fire_penalty(p, true)
				_alert_police(p.global_position)

			# simulate slowdown a bit without editing prisoner script
			var away: Vector2 = (p.global_position - global_position).normalized()
			if away == Vector2.ZERO:
				away = Vector2.UP
			p.global_position += away * slow_push_strength * delta
		else:
			if _inside_players.has(p):
				_inside_players.erase(p)

	var to_remove: Array = []
	for key in _inside_players.keys():
		if not is_instance_valid(key):
			to_remove.append(key)
	for key in to_remove:
		_inside_players.erase(key)


func _apply_fire_penalty(player: Node2D, over_time: bool) -> void:
	var gm: Node = get_node_or_null("/root/Game/GameManager")
	if gm != null and gm.has_method("apply_fire_penalty"):
		gm.call("apply_fire_penalty", (player as Node).name, over_time)


func _alert_police(alert_pos: Vector2) -> void:
	for police in get_tree().get_nodes_in_group("police"):
		if police.has_method("alert_player_near_fire"):
			(police as Node).call("alert_player_near_fire", alert_pos)
