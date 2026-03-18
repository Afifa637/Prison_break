# =============================================================================
# pause_menu.gd  -  Pause Menu Overlay
# Attach to a CanvasLayer node inside your game scene (Layer = 100)
# =============================================================================
extends CanvasLayer

const C_BG: Color        = Color(0.0,  0.0,  0.0,  0.80)
const C_TITLE: Color     = Color(0.95, 0.75, 0.15, 1.0)
const C_BTN_NORMAL: Color = Color(0.15, 0.15, 0.18, 1.0)
const C_BTN_HOVER: Color  = Color(0.85, 0.65, 0.10, 1.0)
const C_BTN_TEXT: Color   = Color(0.95, 0.95, 0.95, 1.0)

var _panel: Panel
var _visible: bool = false

# ---------- references to game stat labels (filled in _refresh_stats) ----------
var _label_score_prisoner: Label
var _label_score_police: Label
var _label_captures: Label


func _ready() -> void:
	_build_panel()
	_set_visible(false)
	# Make sure this node processes even when the tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle()
		get_viewport().set_input_as_handled()


# -----------------------------------------------------------------------
func _toggle() -> void:
	_set_visible(not _visible)


func _set_visible(show: bool) -> void:
	_visible = show
	_panel.visible = show
	get_tree().paused = show
	if show:
		_refresh_stats()


# -----------------------------------------------------------------------
func _build_panel() -> void:
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = C_BG
	_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(_panel)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	center.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(title)

	# Divider
	var div := HSeparator.new()
	div.custom_minimum_size = Vector2(400, 4)
	vbox.add_child(div)

	# Stats section
	var stats_title := Label.new()
	stats_title.text = "-- CURRENT STATS --"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_title.add_theme_font_size_override("font_size", 18)
	stats_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(stats_title)

	_label_score_prisoner = _make_stat_label("Prisoner Score : 0")
	vbox.add_child(_label_score_prisoner)

	_label_score_police = _make_stat_label("Police Score   : 0")
	vbox.add_child(_label_score_police)

	_label_captures = _make_stat_label("Captures       : 0")
	vbox.add_child(_label_captures)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# Buttons
	var resume_btn := _make_button("RESUME")
	resume_btn.pressed.connect(_on_resume)
	vbox.add_child(resume_btn)

	var restart_btn := _make_button("RESTART")
	restart_btn.pressed.connect(_on_restart)
	vbox.add_child(restart_btn)

	var menu_btn := _make_button("MAIN MENU")
	menu_btn.pressed.connect(_on_main_menu)
	vbox.add_child(menu_btn)


func _make_stat_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	return lbl


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 55)
	btn.add_theme_font_size_override("font_size", 22)

	var sn := StyleBoxFlat.new()
	sn.bg_color = C_BTN_NORMAL
	sn.border_color = C_BTN_HOVER
	sn.set_border_width_all(2)
	sn.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", sn)

	var sh := StyleBoxFlat.new()
	sh.bg_color = C_BTN_HOVER
	sh.border_color = C_TITLE
	sh.set_border_width_all(3)
	sh.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("hover", sh)

	var sp := StyleBoxFlat.new()
	sp.bg_color = C_TITLE
	sp.border_color = Color.WHITE
	sp.set_border_width_all(3)
	sp.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("pressed", sp)

	btn.add_theme_color_override("font_color", C_BTN_TEXT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	return btn


# -----------------------------------------------------------------------
# Pull live stats from the game scene.
# Adjust the node paths below to match your actual scene structure.
# -----------------------------------------------------------------------
func _refresh_stats() -> void:
	var game = get_tree().get_first_node_in_group("game_manager")
	if game == null:
		return
	if "prisoner_score" in game:
		_label_score_prisoner.text = "Prisoner Score : %d" % game.prisoner_score
	if "police_score" in game:
		_label_score_police.text   = "Police Score   : %d" % game.police_score
	if "capture_count" in game:
		_label_captures.text       = "Captures       : %d" % game.capture_count


# -----------------------------------------------------------------------
func _on_resume() -> void:
	_set_visible(false)


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_menu.tscn")
