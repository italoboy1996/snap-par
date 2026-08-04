extends Control

signal new_round_requested

@onready var result_label: Label = $Layout/Header/Result
@onready var best_label: Label = $Layout/Header/Best
@onready var images: Array[TextureRect] = [
	$Layout/Collage/Hole1,
	$Layout/Collage/Hole2,
	$Layout/Collage/Hole3,
]
@onready var actions: Control = $Layout/Actions
@onready var share_button: Button = $Layout/Actions/Share
@onready var new_round_button: Button = $Layout/Actions/NewRound

var new_best := false

func _ready() -> void:
	share_button.pressed.connect(_share_collage)
	new_round_button.pressed.connect(func(): new_round_requested.emit())
	for index in range(mini(images.size(), AppState.hole_captures.size())):
		images[index].texture = ImageTexture.create_from_image(AppState.hole_captures[index])
	var difference := AppState.total_strokes() - AppState.total_par()
	var difference_text := "%+d" % difference
	result_label.text = "%d Schlaege   Par %d   %s" % [AppState.total_strokes(), AppState.total_par(), difference_text]
	best_label.text = "Neue Bestleistung" if new_best else AppState.best_round_text()

func set_new_best(value: bool) -> void:
	new_best = value

func _share_collage() -> void:
	actions.visible = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "user://snap-par-collage.png"
	var result := image.save_png(path)
	actions.visible = true
	if result == OK:
		MediaBridge.share_image(path)
