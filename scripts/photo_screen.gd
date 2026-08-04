extends Control

signal image_ready(image: Image)

@export var starts_new_round := false

@onready var title_label: Label = $Content/Title
@onready var best_label: Label = $Content/Best
@onready var camera_button: Button = $Content/Buttons/Camera
@onready var gallery_button: Button = $Content/Buttons/Gallery
@onready var status_label: Label = $Content/Status

var initial_message := ""

func _ready() -> void:
	camera_button.pressed.connect(_on_camera_pressed)
	gallery_button.pressed.connect(_on_gallery_pressed)
	MediaBridge.image_selected.connect(_on_image_selected)
	MediaBridge.media_error.connect(_on_media_error)
	if starts_new_round:
		title_label.text = "SNAP PAR"
		best_label.text = AppState.best_round_text()
		best_label.visible = true
	else:
		title_label.text = "Loch %d von %d" % [AppState.current_hole_number(), AppState.HOLES_PER_ROUND]
		best_label.visible = false
	status_label.text = initial_message

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
		status_label.text = "Bild wird vorbereitet"
