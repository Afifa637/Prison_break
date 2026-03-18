# =============================================================================
# visual_indicators.gd  -  Detection Circles & Status Icons
# Attach to a CanvasLayer node inside your game scene (Layer = 10)
# =============================================================================
extends CanvasLayer

# ---- tuneable settings (edit in the Inspector) ----
@export var show_detection_circles: bool = true
@export var show_status_icons: bool      = true
@export var show_ai_paths: bool          = false   # debug only

@export var police_detect_radius: float  = 300.0
@export var dog_detect_radius: float     = 260.0

# Colours (RGBA)
const C_POLICE_RING: Color  = Color(1.0, 0.15, 0.15, 0.25)
const C_POLICE_EDGE: Color  = Color(1.0, 0.15, 0.15, 0.70)
const C_DOG_RING: Color     = Color(1.0, 0.90, 0.15, 0.20)
const C_DOG_EDGE: Color     = Color(1.0, 0.90, 0.15, 0.65)
const C_PATH_POLICE: Color  = Color(1.0, 0.55, 0.0,  0.80)
const C_PATH_MONTE: Color   = Color(0.2, 0.5,  1.0,  0.80)
const C_PATH_MINI: Color    = Color(1.0, 0.2,  0.2,  0.80)

# Status icon strings (plain ASCII labels - swap for your font glyphs if needed)
const ICON_CAUGHT     = "[CAUGHT]"
const ICON_DOG        = "[DOG]"
const ICON_FIRE       = "[FIRE]"
const ICON_CHASING    = "[CHASE]"
const ICON_INTERCEPT  = "[INTCPT]"
const ICON_INVESTIGATE= "[INVST]"

var _draw_node: Node2D   # child Node2D used for all draw calls


func _ready() -> void:
	_draw_node = Node2D.new()
	_draw_node.name = "IndicatorCanvas"
	# CanvasLayer children are 2-D nodes drawn in layer space
	# We need to move drawing into world-space via a viewport-relative trick:
	# Instead just add it as a plain Node2D child - CanvasLayer renders it
	# at the correct screen position automatically.
	add_child(_draw_node)
	_draw_node.draw.connect(_on_draw)


func _process(_delta: float) -> void:
	_draw_node.queue_redraw()


# -----------------------------------------------------------------------
func _on_draw() -> void:
	if show_detection_circles:
		_draw_police_circles()
		_draw_dog_circles()

	if show_status_icons:
		_draw_status_icons()

	if show_ai_paths:
		_draw_ai_paths()


# -----------------------------------------------------------------------
#  DETECTION CIRCLES
# -----------------------------------------------------------------------
func _draw_police_circles() -> void:
	for officer in get_tree().get_nodes_in_group("police"):
		if not is_instance_valid(officer):
			continue
		var state = officer.get("ai_state") if "ai_state" in officer else ""
		if state in ["chasing", "intercepting", "investigating"]:
			var pos: Vector2 = _world_to_canvas(officer.global_position)
			_draw_node.draw_circle(pos, police_detect_radius, C_POLICE_RING)
			_draw_arc(pos, police_detect_radius, C_POLICE_EDGE, 2.0)


func _draw_dog_circles() -> void:
	for dog in get_tree().get_nodes_in_group("dogs"):
		if not is_instance_valid(dog):
			continue
		var state = dog.get("ai_state") if "ai_state" in dog else ""
		if state in ["spotted", "chasing"]:
			var pos: Vector2 = _world_to_canvas(dog.global_position)
			_draw_node.draw_circle(pos, dog_detect_radius, C_DOG_RING)
			_draw_arc(pos, dog_detect_radius, C_DOG_EDGE, 2.0)


# -----------------------------------------------------------------------
#  STATUS ICONS
# -----------------------------------------------------------------------
func _draw_status_icons() -> void:
	for prisoner in get_tree().get_nodes_in_group("prisoners"):
		if not is_instance_valid(prisoner):
			continue
		var icon  := _get_prisoner_icon(prisoner)
		var color := _get_prisoner_icon_color(prisoner)
		if icon == "":
			continue
		var pos: Vector2 = _world_to_canvas(prisoner.global_position) + Vector2(-20, -50)
		_draw_node.draw_string(
			ThemeDB.fallback_font,
			pos,
			icon,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			color
		)

	for officer in get_tree().get_nodes_in_group("police"):
		if not is_instance_valid(officer):
			continue
		var icon  := _get_police_icon(officer)
		var color := _get_police_icon_color(officer)
		if icon == "":
			continue
		var pos: Vector2 = _world_to_canvas(officer.global_position) + Vector2(-20, -50)
		_draw_node.draw_string(
			ThemeDB.fallback_font,
			pos,
			icon,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			color
		)


func _get_prisoner_icon(node: Node) -> String:
	var state = node.get("state") if "state" in node else ""
	match state:
		"caught":  return ICON_CAUGHT
		"latched": return ICON_DOG
		"on_fire": return ICON_FIRE
	return ""


func _get_prisoner_icon_color(node: Node) -> Color:
	var state = node.get("state") if "state" in node else ""
	match state:
		"caught":  return Color(1.0, 0.2, 0.2)
		"latched": return Color(1.0, 0.9, 0.1)
		"on_fire": return Color(1.0, 0.5, 0.0)
	return Color.WHITE


func _get_police_icon(node: Node) -> String:
	var state = node.get("ai_state") if "ai_state" in node else ""
	match state:
		"chasing":      return ICON_CHASING
		"intercepting": return ICON_INTERCEPT
		"investigating":return ICON_INVESTIGATE
	return ""


func _get_police_icon_color(node: Node) -> Color:
	var state = node.get("ai_state") if "ai_state" in node else ""
	match state:
		"chasing":      return Color(1.0, 0.2, 0.2)
		"intercepting": return Color(1.0, 0.6, 0.0)
		"investigating":return Color(0.3, 0.6, 1.0)
	return Color.WHITE


# -----------------------------------------------------------------------
#  AI PATH VISUALISATION  (debug)
# -----------------------------------------------------------------------
func _draw_ai_paths() -> void:
	for officer in get_tree().get_nodes_in_group("police"):
		if not is_instance_valid(officer):
			continue
		var path = officer.get("current_path") if "current_path" in officer else []
		_draw_path(path, C_PATH_POLICE)

	for prisoner in get_tree().get_nodes_in_group("prisoners"):
		if not is_instance_valid(prisoner):
			continue
		var path  = prisoner.get("current_path") if "current_path" in prisoner else []
		var ptype = prisoner.get("ai_type")      if "ai_type"     in prisoner else ""
		var color := C_PATH_MINI if ptype == "minimax" else C_PATH_MONTE
		_draw_path(path, color)


func _draw_path(path: Array, color: Color) -> void:
	if path.size() < 2:
		return
	for i in range(path.size() - 1):
		var a: Vector2 = _world_to_canvas(path[i])
		var b: Vector2 = _world_to_canvas(path[i + 1])
		_draw_node.draw_line(a, b, color, 2.0)
		_draw_node.draw_circle(b, 4.0, color)


# -----------------------------------------------------------------------
#  HELPERS
# -----------------------------------------------------------------------
func _world_to_canvas(world_pos: Vector2) -> Vector2:
	# Convert a world-space position to CanvasLayer-local screen coords.
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return world_pos
	return world_pos - cam.get_screen_center_position() + get_viewport().get_visible_rect().size * 0.5


func _draw_arc(center: Vector2, radius: float, color: Color, width: float) -> void:
	var points := 48
	for i in range(points):
		var a0 := (float(i)       / points) * TAU
		var a1 := (float(i + 1)  / points) * TAU
		_draw_node.draw_line(
			center + Vector2(cos(a0), sin(a0)) * radius,
			center + Vector2(cos(a1), sin(a1)) * radius,
			color,
			width
		)
