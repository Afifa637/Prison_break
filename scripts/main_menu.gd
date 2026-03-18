# =============================================================================
# main_menu.gd  -  Main Menu Scene
# Attach to a Control node as root of MainMenu scene
# =============================================================================
extends Control

@onready var title_label: Label
@onready var start_button: Button
@onready var options_button: Button
@onready var quit_button: Button
@onready var anim_player: AnimationPlayer

var _title_time: float = 0.0

const C_BG: Color = Color(0.06, 0.06, 0.08, 1.0)
const C_TITLE: Color = Color(0.95, 0.75, 0.15)
const C_BUTTON_NORMAL: Color = Color(0.15, 0.15, 0.18)
const C_BUTTON_HOVER: Color = Color(0.85, 0.65, 0.10)
const C_BUTTON_TEXT: Color = Color(0.95, 0.95, 0.95)


func _ready() -> void:
	_build_menu()
	_setup_animations()


func _build_menu() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Main VBox
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	# Title  (no emoji - plain ASCII safe)
	title_label = Label.new()
	title_label.text = "PRISON BREAK"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(title_label)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "AI vs AI Escape Challenge"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(subtitle)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)

	# Buttons
	start_button = _create_button("START GAME")
	start_button.pressed.connect(_on_start_pressed)
	vbox.add_child(start_button)

	options_button = _create_button("OPTIONS")
	options_button.pressed.connect(_on_options_pressed)
	vbox.add_child(options_button)

	quit_button = _create_button("QUIT")
	quit_button.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_button)

	# Version label
	var version := Label.new()
	version.text = "v1.0  |  Made with Godot"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	version.position = Vector2(
		get_viewport_rect().size.x / 2.0 - 100,
		get_viewport_rect().size.y - 40
	)
	add_child(version)


func _create_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 60)
	btn.add_theme_font_size_override("font_size", 24)

	# Normal style
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = C_BUTTON_NORMAL
	style_normal.border_color = C_BUTTON_HOVER
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style_normal)

	# Hover style
	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = C_BUTTON_HOVER
	style_hover.border_color = C_TITLE
	style_hover.set_border_width_all(3)
	style_hover.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("hover", style_hover)

	# Pressed style
	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = C_TITLE
	style_pressed.border_color = Color.WHITE
	style_pressed.set_border_width_all(3)
	style_pressed.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	btn.add_theme_color_override("font_color", C_BUTTON_TEXT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

	return btn


func _setup_animations() -> void:
	anim_player = AnimationPlayer.new()
	add_child(anim_player)

	var anim := Animation.new()
	var track_idx := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_idx, ".:_title_time")
	anim.length = 2.0
	anim.loop_mode = Animation.LOOP_LINEAR

	anim.track_insert_key(track_idx, 0.0, 0.0)
	anim.track_insert_key(track_idx, 1.0, 1.0)
	anim.track_insert_key(track_idx, 2.0, 2.0)

	var lib := AnimationLibrary.new()
	lib.add_animation("title_pulse", anim)
	anim_player.add_animation_library("", lib)
	anim_player.play("title_pulse")


func _process(_delta: float) -> void:
	# Animate title colour
	var pulse := sin(_title_time * PI)
	var color := C_TITLE.lerp(Color.WHITE, pulse * 0.2)
	title_label.add_theme_color_override("font_color", color)

	# Animate title scale
	var scale_val := 1.0 + pulse * 0.05
	title_label.scale = Vector2(scale_val, scale_val)


func _on_start_pressed() -> void:
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade)

	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.5)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/game.tscn")
	)


func _on_options_pressed() -> void:
	var options := _create_options_overlay()
	add_child(options)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _create_options_overlay() -> Control:
	var overlay := Panel.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.85)
	overlay.add_theme_stylebox_override("panel", style)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(title)

	# Volume slider
	var vol_label := Label.new()
	vol_label.text = "Master Volume"
	vol_label.add_theme_font_size_override("font_size", 20)
	vol_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(vol_label)

	var vol_slider := HSlider.new()
	vol_slider.custom_minimum_size = Vector2(400, 40)
	vol_slider.min_value = 0.0
	vol_slider.max_value = 100.0
	vol_slider.value = 100.0
	vbox.add_child(vol_slider)

	# Close button
	var close_btn := _create_button("CLOSE")
	close_btn.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(close_btn)

	return overlay
