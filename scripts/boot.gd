extends Control

const StartScene := preload("res://scenes/Start.tscn")
const PhotoPickerScene := preload("res://scenes/PhotoPicker.tscn")
const GameScene := preload("res://scenes/Game.tscn")
const EndScene := preload("res://scenes/EndScreen.tscn")

var active_screen: Node
var current_photo: Image

func _ready() -> void:
	_show_start()

func _show_start() -> void:
	var screen := StartScene.instantiate()
	screen.image_ready.connect(_on_image_ready)
	_swap_screen(screen)

func _show_photo_picker(message := "") -> void:
	var screen := PhotoPickerScene.instantiate()
	screen.set_initial_message(message)
	screen.image_ready.connect(_on_image_ready)
	_swap_screen(screen)

func _show_game(image: Image) -> void:
	var game := GameScene.instantiate()
	game.use_test_image = false
	game.start_with_image(image)
	game.hole_completed.connect(_on_hole_completed)
	game.level_rejected.connect(_on_level_rejected)
	_swap_screen(game)

func _show_end() -> void:
	var screen := EndScene.instantiate()
	screen.set_new_best(AppState.finish_round())
	screen.new_round_requested.connect(_show_start)
	_swap_screen(screen)

func _on_image_ready(image: Image) -> void:
	current_photo = image.duplicate()
	_show_game(current_photo)

func _on_hole_completed(strokes: int, par: int, capture: Image) -> void:
	AppState.record_hole(current_photo, capture, strokes, par)
	if AppState.round_complete():
		_show_end()
	else:
		_show_photo_picker()

func _on_level_rejected(message: String) -> void:
	if AppState.hole_strokes.is_empty():
		_show_start_with_message(message)
	else:
		_show_photo_picker(message)

func _show_start_with_message(message: String) -> void:
	var screen := StartScene.instantiate()
	screen.set_initial_message(message)
	screen.image_ready.connect(_on_image_ready)
	_swap_screen(screen)

func _swap_screen(next_screen: Node) -> void:
	if active_screen:
		active_screen.queue_free()
	active_screen = next_screen
	add_child(active_screen)
