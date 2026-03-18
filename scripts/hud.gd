# =============================================================================
# hud.gd  –  In-game HUD
# =============================================================================
extends CanvasLayer

var _rows: Dictionary = {}
var _timer_label: Label
var _overlay: Panel
var _overlay_title: Label
var _overlay_sub: Label
var _overlay_rankings: VBoxContainer

const C_BG: Color = Color(0.06, 0.06, 0.08, 0.88)
const C_BORDER: Color = Color(0.85, 0.65, 0.10)
const C_RUNNING: Color = Color(0.85, 0.85, 0.85)
const C_ESCAPED: Color = Color(0.20, 0.95, 0.45)
const C_CAUGHT: Color = Color(0.95, 0.22, 0.22)
const C_BURNED: Color = Color(1.00, 0.45, 0.10)
const C_POLICE: Color = Color(0.35, 0.75, 1.00)

const STATUS_COLORS: Dictionary = {
	"RUNNING": C_RUNNING,
	"ESCAPED": C_ESCAPED,
	"ELIMINATED": C_CAUGHT,
	"BURNED": C_BURNED,
}

const STATUS_ICONS: Dictionary = {
	"RUNNING": "▶",
	"ESCAPED": "★",
	"ELIMINATED": "✖",
	"BURNED": "🔥",
}

const GAME_OVER_TEXT: Dictionary = {
	"all_escaped": ["PRISON BREAK!", "Everyone escaped."],
	"all_caught": ["LOCKDOWN", "The prison held."],
	"partial": ["MATCH OVER", "Final standings below."],
	"timeout": ["TIME UP", "Ranked by score and escape order."],
}


func _ready() -> void:
	_build_status_panel()
	_build_overlay()
	call_deferred("_connect_to_manager")


func _build_status_panel() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(16, 16)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "⬛ PRISON BREAK"
	title.add_theme_color_override("font_color", C_BORDER)
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	_timer_label = Label.new()
	_timer_label.text = "TIME 120s"
	_timer_label.add_theme_color_override("font_color", C_RUNNING)
	_timer_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_timer_label)

	var sep: HSeparator = HSeparator.new()
	var sep_style: StyleBoxFlat = StyleBoxFlat.new()
	sep_style.bg_color = C_BORDER
	sep_style.set_content_margin_all(1)
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	for entry in [
		["Police", "👮 POLICE"],
		["Player_blue", "🔵 BLUE PRISONER"],
		["Player_red", "🔴 RED PRISONER"]
	]:
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		vbox.add_child(box)

		var name_lbl: Label = Label.new()
		name_lbl.text = String(entry[1])
		name_lbl.add_theme_color_override("font_color", C_POLICE if String(entry[0]) == "Police" else C_RUNNING)
		name_lbl.add_theme_font_size_override("font_size", 12)
		box.add_child(name_lbl)

		var stats_lbl: Label = Label.new()
		if String(entry[0]) == "Police":
			stats_lbl.text = "▶ RUNNING   SCORE 0   CATCHES 0"
		else:
			stats_lbl.text = "▶ RUNNING   SCORE 0   CAPTURES 0/3"
		stats_lbl.add_theme_color_override("font_color", C_RUNNING)
		stats_lbl.add_theme_font_size_override("font_size", 11)
		box.add_child(stats_lbl)

		_rows[String(entry[0])] = stats_lbl

	add_child(panel)


func _build_overlay() -> void:
	_overlay = Panel.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.78)
	_overlay.add_theme_stylebox_override("panel", style)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	_overlay_title = Label.new()
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title.add_theme_font_size_override("font_size", 48)
	_overlay_title.add_theme_color_override("font_color", C_BORDER)
	vbox.add_child(_overlay_title)

	_overlay_sub = Label.new()
	_overlay_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_sub.add_theme_font_size_override("font_size", 20)
	_overlay_sub.add_theme_color_override("font_color", C_RUNNING)
	vbox.add_child(_overlay_sub)

	_overlay_rankings = VBoxContainer.new()
	_overlay_rankings.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay_rankings.add_theme_constant_override("separation", 6)
	vbox.add_child(_overlay_rankings)

	var hint: Label = Label.new()
	hint.text = "press R to restart"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	vbox.add_child(hint)

	add_child(_overlay)


func _connect_to_manager() -> void:
	var gm: Node = get_node_or_null("/root/Game/GameManager")
	if gm == null:
		return
	gm.player_status_changed.connect(_on_status_changed)
	gm.player_stats_changed.connect(_on_stats_changed)
	gm.timer_changed.connect(_on_timer_changed)
	gm.game_over.connect(_on_game_over)


func _on_status_changed(player_name: String, status: String) -> void:
	_update_row(player_name, status, null, null)


func _on_stats_changed(player_name: String, score: int, captures: int) -> void:
	_update_row(player_name, null, score, captures)


func _update_row(player_name: String, status_value, score_value, captures_value) -> void:
	if not _rows.has(player_name):
		return

	var lbl: Label = _rows[player_name] as Label

	var status: String = "RUNNING"
	var score: int = 0
	var captures: int = 0

	if lbl.has_meta("status"):
		status = String(lbl.get_meta("status"))
	if lbl.has_meta("score"):
		score = int(lbl.get_meta("score"))
	if lbl.has_meta("captures"):
		captures = int(lbl.get_meta("captures"))

	if status_value != null:
		status = String(status_value)
	if score_value != null:
		score = int(score_value)
	if captures_value != null:
		captures = int(captures_value)

	lbl.set_meta("status", status)
	lbl.set_meta("score", score)
	lbl.set_meta("captures", captures)

	var icon: String = String(STATUS_ICONS.get(status, "?"))
	var color: Color = STATUS_COLORS.get(status, C_RUNNING) as Color

	if player_name == "Police":
		lbl.text = "%s %s   SCORE %d   CATCHES %d" % [icon, status, score, captures]
		if status == "RUNNING":
			color = C_POLICE
	else:
		lbl.text = "%s %s   SCORE %d   CAPTURES %d/3" % [icon, status, score, captures]

	lbl.add_theme_color_override("font_color", color)


func _on_timer_changed(seconds_left: int) -> void:
	_timer_label.text = "TIME %ds" % seconds_left


func _on_game_over(result: String, standings: Array) -> void:
	var texts: Array = GAME_OVER_TEXT.get(result, ["MATCH OVER", ""]) as Array
	_overlay_title.text = String(texts[0])
	_overlay_sub.text = String(texts[1])

	for child in _overlay_rankings.get_children():
		child.queue_free()

	var place: int = 1
	for row_variant in standings:
		var row: Dictionary = row_variant as Dictionary
		var label: Label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)

		var status: String = String(row.get("status", ""))
		var name: String = String(row.get("name", ""))
		var color: Color = STATUS_COLORS.get(status, C_RUNNING) as Color

		if name == "Police" and status == "RUNNING":
			color = C_POLICE

		label.add_theme_color_override("font_color", color)

		var capture_word: String = "catches" if name == "Police" else "captures"
		label.text = "%d. %s  —  %s  —  %d pts  —  %d %s" % [
			place,
			name,
			status,
			int(row.get("score", 0)),
			int(row.get("captures", 0)),
			capture_word
		]

		_overlay_rankings.add_child(label)
		place += 1

	match result:
		"all_escaped":
			_overlay_title.add_theme_color_override("font_color", C_ESCAPED)
		"all_caught":
			_overlay_title.add_theme_color_override("font_color", C_CAUGHT)
		"timeout":
			_overlay_title.add_theme_color_override("font_color", C_BORDER)
		_:
			_overlay_title.add_theme_color_override("font_color", C_BORDER)

	_overlay.visible = true


func _input(event: InputEvent) -> void:
	if _overlay.visible and event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.physical_keycode == KEY_R:
			get_tree().reload_current_scene()
