extends Control

signal image_ready(image: Image)

@export var starts_new_round := false

@onready var content: Control = $Content
@onready var title_label: Label = $Content/Title
@onready var best_label: Label = $Content/Best
@onready var camera_button: Button = $Content/Buttons/Camera
@onready var gallery_button: Button = $Content/Buttons/Gallery
@onready var status_label: Label = $Content/Status

var initial_message := ""

func _ready() -> void:
	_apply_modern_style()
	camera_button.pressed.connect(_on_camera_pressed)
	gallery_button.pressed.connect(_on_gallery_pressed)
	MediaBridge.image_selected.connect(_on_image_selected)
	MediaBridge.media_error.connect(_on_media_error)
	if starts_new_round:
		title_label.text = "SNAP PAR"
		best_label.text = AppState.best_round_text()
		best_label.visible = true
	else:
		title_label.text = "LOCH %d VON %d" % [AppState.current_hole_number(), AppState.HOLES_PER_ROUND]
		best_label.visible = false
	status_label.text = initial_message
	_animate_in()

func _exit_tree() -> void:
	if MediaBridge.image_selected.is_connected(_on_image_selected):
		MediaBridge.image_selected.disconnect(_on_image_selected)
	if MediaBridge.media_error.is_connected(_on_media_error):
		MediaBridge.media_error.disconnect(_on_media_error)

func set_initial_message(message: String) -> void:
	initial_message = message
	if is_node_ready():
		status_label.text = message

func _on_camera_pressed() -> void:
	_set_busy(true)
	MediaBridge.take_photo()

func _on_gallery_pressed() -> void:
	_set_busy(true)
	MediaBridge.pick_image()

func _on_image_selected(image: Image) -> void:
	if starts_new_round:
		AppState.begin_round()
	image_ready.emit(image)

func _on_media_error(message: String) -> void:
	status_label.text = message
	_set_busy(false)

func _set_busy(value: bool) -> void:
	camera_button.disabled = value
	gallery_button.disabled = value
	if value:
		status_label.text = "BILD WIRD VORBEREITET"

func _apply_modern_style() -> void:
	camera_button.text = "FOTO MACHEN"
	gallery_button.text = "GALERIE OEFFNEN"
	_style_button(camera_button, Color(0.33, 0.95, 0.63, 1.0), Color(0.03, 0.10, 0.075, 1.0), true)
	_style_button(gallery_button, Color(0.055, 0.075, 0.085, 0.96), Color(0.93, 1.0, 0.96, 1.0), false)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 5)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.48, 1.0))

func _style_button(button: Button, base_colour: Color, text_colour: Color, primary: bool) -> void:
	button.add_theme_color_override("font_color", text_colour)
	button.add_theme_color_override("font_hover_color", text_colour)
	button.add_theme_color_override("font_pressed_color", text_colour)
	button.add_theme_color_override("font_disabled_color", Color(text_colour, 0.42))
	button.add_theme_stylebox_override("normal", _button_box(base_colour, 0.16 if primary else 0.24, 0))
	button.add_theme_stylebox_override("hover", _button_box(base_colour.lightened(0.06), 0.34, 4))
	button.add_theme_stylebox_override("pressed", _button_box(base_colour.darkened(0.08), 0.42, 1))
	button.add_theme_stylebox_override("disabled", _button_box(Color(base_colour, 0.45), 0.08, 0))

func _button_box(colour: Color, border_alpha: float, shadow_size: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = Color(0.72, 1.0, 0.84, border_alpha)
	box.corner_radius_top_left = 34
	box.corner_radius_top_right = 34
	box.corner_radius_bottom_left = 34
	box.corner_radius_bottom_right = 34
	box.content_margin_left = 34
	box.content_margin_right = 34
	box.shadow_color = Color(0, 0, 0, 0.32)
	box.shadow_size = shadow_size
	return box

func _animate_in() -> void:
	var target_position := content.position
	content.position = target_position + Vector2(0, 34)
	content.modulate = Color(1, 1, 1, 0)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(content, "position", target_position, 0.42)
	tween.tween_property(content, "modulate", Color.WHITE, 0.32)
