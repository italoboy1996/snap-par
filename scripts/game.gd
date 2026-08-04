class_name SnapParGame
extends Node2D

signal hole_completed(strokes: int, par: int, captured_image: Image)
signal level_rejected(message: String)

const Generator := preload("res://scripts/terrain_from_image.gd")
const CELL_SIZE := 10.0
const MAX_PULL_DISTANCE := 280.0
const IMPULSE_PER_PIXEL := 7.5
const REST_SPEED := 7.0
const REST_ANGULAR_SPEED := 0.45
const REST_TIME_REQUIRED := 0.45
const RESET_MARGIN := 140.0

@export var use_test_image := true

@onready var photo: Sprite2D = $Photo
@onready var overlay: TerrainOverlayDrawer = $TerrainOverlay
@onready var rock_body: StaticBody2D = $Terrain/Rock
@onready var sand_body: StaticBody2D = $Terrain/Sand
@onready var ice_body: StaticBody2D = $Terrain/Ice
@onready var water_area: Area2D = $Terrain/Water
@onready var trail: TrailDrawer = $Trail
@onready var hole: Area2D = $Hole
@onready var ball: SnapParBall = $Ball
@onready var aim_preview: AimPreviewDrawer = $AimPreview
@onready var tutorial_hand: TutorialHand = $TutorialHand
@onready var strokes_label: Label = $HUD/TopBar/Margin/Row/Strokes
@onready var par_label: Label = $HUD/TopBar/Margin/Row/Par
@onready var state_label: Label = $HUD/State
@onready var error_panel: Control = $HUD/ErrorPanel
@onready var hud: CanvasLayer = $HUD
@onready var error_label: Label = $HUD/ErrorPanel/Panel/Margin/Message

var generator := Generator.new()
var terrain_result: Dictionary = {}
var strokes := 0
var par := 0
var dragging := false
var pointer_id := -1
var drag_position := Vector2.ZERO
var shot_active := false
var rest_timer := 0.0
var last_rest_position := Vector2.ZERO
var resetting := false
var completed := false
var pending_image: Image
var near_miss_armed := false
var near_miss_running := false

func _ready() -> void:
	water_area.body_entered.connect(_on_water_body_entered)
	hole.body_entered.connect(_on_hole_body_entered)
	ball.surface_contact.connect(_on_ball_surface_contact)
	if pending_image != null:
		_build_level(pending_image)
	elif use_test_image:
		_build_level(MediaBridge.create_test_image())

func start_with_image(image: Image) -> void:
	pending_image = image
	if is_node_ready():
		_build_level(image)

func _build_level(image: Image) -> void:
	completed = false
	resetting = false
	_clear_collision_children(rock_body)
	_clear_collision_children(sand_body)
	_clear_collision_children(ice_body)
	_clear_collision_children(water_area)
	trail.clear()

	var generated = generator.generate(image)
	if generated == null:
		_show_error("Zu wenig Kontrast, probier etwas anderes")
		level_rejected.emit("Zu wenig Kontrast, probier etwas anderes")
		return

	terrain_result = generated
	var display_image: Image = terrain_result.display_image
	photo.texture = ImageTexture.create_from_image(display_image)
	photo.visible = true
	photo.modulate = Color.WHITE
	overlay.set_cells(terrain_result.cells)

	_build_material_collision(rock_body, Generator.ROCK, "rock", 0.60, 0.40)
	_build_material_collision(sand_body, Generator.SAND, "sand", 0.95, 0.05)
	_build_material_collision(ice_body, Generator.ICE, "ice", 0.02, 0.30)
	_build_water_areas()

	ball.position = _cell_centre(terrain_result.ball_cell)
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.sleeping = true
	hole.position = _cell_centre(terrain_result.hole_cell)
	last_rest_position = ball.position
	strokes = 0
	par = int(ceil(ball.position.distance_to(hole.position) / 400.0)) + 1
	shot_active = false
	rest_timer = 0.0
	_update_hud()
	error_panel.visible = false
	state_label.text = ""
	AudioFx.start_ambience()
	if not AppState.tutorial_seen:
		tutorial_hand.play(ball.position)
		AppState.mark_tutorial_seen()

func _physics_process(delta: float) -> void:
	if terrain_result.is_empty() or completed or resetting:
		return

	if shot_active:
		trail.add_point(ball.position)
		_check_near_miss()
		if ball.linear_velocity.length() <= REST_SPEED and absf(ball.angular_velocity) <= REST_ANGULAR_SPEED:
			rest_timer += delta
			if rest_timer >= REST_TIME_REQUIRED:
				_finish_rest()
		else:
			rest_timer = 0.0

	if _ball_is_outside():
		_reset_ball(false)

	if not completed and ball.position.distance_to(hole.position) <= 27.0 and ball.linear_velocity.length() <= 430.0:
		_complete_hole()

func _unhandled_input(event: InputEvent) -> void:
	if terrain_result.is_empty() or completed or resetting:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_drag(touch.position, touch.index)
		elif dragging and touch.index == pointer_id:
			_release_drag(touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if dragging and drag.index == pointer_id:
			_update_drag(drag.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed:
			_begin_drag(mouse_button.position, 0)
		elif dragging:
			_release_drag(mouse_button.position)
	elif event is InputEventMouseMotion and dragging:
		_update_drag((event as InputEventMouseMotion).position)

func _begin_drag(position: Vector2, id: int) -> void:
	if shot_active or not ball.sleeping:
		return
	if position.distance_to(ball.position) > 78.0:
		return
	dragging = true
	pointer_id = id
	_update_drag(position)

func _update_drag(position: Vector2) -> void:
	drag_position = ball.position + (position - ball.position).limit_length(MAX_PULL_DISTANCE)
	var shot_vector := ball.position - drag_position
	aim_preview.show_preview(ball.position, ball.position + shot_vector * 1.55)

func _release_drag(position: Vector2) -> void:
	_update_drag(position)
	dragging = false
	pointer_id = -1
	aim_preview.hide_preview()
	var pull_vector := drag_position - ball.position
	if pull_vector.length() < 18.0:
		return
	_shoot(-pull_vector.limit_length(MAX_PULL_DISTANCE) * IMPULSE_PER_PIXEL)

func _shoot(impulse: Vector2) -> void:
	strokes += 1
	shot_active = true
	near_miss_armed = true
	rest_timer = 0.0
	ball.sleeping = false
	trail.begin_stroke(ball.position)
	ball.apply_central_impulse(impulse)
	Input.vibrate_handheld(24)
	AudioFx.play_shot()
	_update_hud()

func _finish_rest() -> void:
	shot_active = false
	near_miss_armed = false
	rest_timer = 0.0
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.sleeping = true
	last_rest_position = ball.position
	trail.end_stroke()

func _reset_ball(add_penalty: bool) -> void:
	if resetting or completed:
		return
	resetting = true
	near_miss_armed = false
	if near_miss_running:
		Engine.time_scale = 1.0
		near_miss_running = false
	if add_penalty:
		strokes += 1
	_update_hud()
	trail.end_stroke()
	shot_active = false
	dragging = false
	aim_preview.hide_preview()
	ball.freeze = true
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.position = last_rest_position
	await get_tree().create_timer(0.18).timeout
	ball.freeze = false
	ball.sleeping = true
	resetting = false

func _on_water_body_entered(body: Node) -> void:
	if body == ball and not resetting and not completed:
		AudioFx.play_water()
		_reset_ball(true)

func _on_hole_body_entered(body: Node) -> void:
	if body == ball and ball.linear_velocity.length() <= 430.0:
		_complete_hole()

func _complete_hole() -> void:
	if completed:
		return
	completed = true
	dragging = false
	shot_active = false
	aim_preview.hide_preview()
	trail.end_stroke()
	ball.freeze = true
	ball.position = hole.position
	Input.vibrate_handheld(70)
	AudioFx.play_hole()
	state_label.text = "LOCH GESCHAFFT"
	await get_tree().process_frame
	hud.visible = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var captured := get_viewport().get_texture().get_image()
	hud.visible = true
	hole_completed.emit(strokes, par, captured)

func _on_ball_surface_contact(material_name: String, impact_speed: float) -> void:
	AudioFx.play_collision(material_name, impact_speed)

func _check_near_miss() -> void:
	if not near_miss_armed or near_miss_running:
		return
	var distance := ball.position.distance_to(hole.position)
	var speed := ball.linear_velocity.length()
	if distance > 27.0 and distance < 40.0 and speed > 120.0:
		near_miss_armed = false
		_trigger_near_miss()

func _trigger_near_miss() -> void:
	near_miss_running = true
	Engine.time_scale = 0.35
	await get_tree().create_timer(0.30, true, false, true).timeout
	Engine.time_scale = 1.0
	near_miss_running = false

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	AudioFx.stop_ambience()

func _build_material_collision(body: StaticBody2D, material_code: int, material_name: String, friction: float, bounce: float) -> void:
	body.set_meta("surface_material", material_name)
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = friction
	physics_material.bounce = bounce
	body.physics_material_override = physics_material
	for rectangle in _rectangles_for_material(material_code):
		_add_rectangle_shape(body, rectangle)

func _build_water_areas() -> void:
	for rectangle in _rectangles_for_material(Generator.WATER):
		_add_rectangle_shape(water_area, rectangle)

func _rectangles_for_material(material_code: int) -> Array[Rect2i]:
	var cells: PackedInt32Array = terrain_result.cells
	var visited := PackedByteArray()
	visited.resize(cells.size())
	var rectangles: Array[Rect2i] = []
	for y in range(Generator.GRID_HEIGHT):
		for x in range(Generator.GRID_WIDTH):
			var index := y * Generator.GRID_WIDTH + x
			if visited[index] == 1 or cells[index] != material_code:
				continue
			var width := 1
			while x + width < Generator.GRID_WIDTH:
				var next_index := y * Generator.GRID_WIDTH + x + width
				if visited[next_index] == 1 or cells[next_index] != material_code:
					break
				width += 1
			var height := 1
			var can_extend := true
			while y + height < Generator.GRID_HEIGHT and can_extend:
				for offset_x in range(width):
					var next_index := (y + height) * Generator.GRID_WIDTH + x + offset_x
					if visited[next_index] == 1 or cells[next_index] != material_code:
						can_extend = false
						break
				if can_extend:
					height += 1
			for offset_y in range(height):
				for offset_x in range(width):
					visited[(y + offset_y) * Generator.GRID_WIDTH + x + offset_x] = 1
			rectangles.append(Rect2i(x, y, width, height))
	return rectangles

func _add_rectangle_shape(parent: CollisionObject2D, rectangle: Rect2i) -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(rectangle.size) * CELL_SIZE
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = (Vector2(rectangle.position) + Vector2(rectangle.size) * 0.5) * CELL_SIZE
	parent.add_child(collision)

func _clear_collision_children(parent: Node) -> void:
	for child in parent.get_children():
		if child is CollisionShape2D:
			child.queue_free()

func _cell_centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE

func _ball_is_outside() -> bool:
	return ball.position.x < -RESET_MARGIN or ball.position.x > 1080.0 + RESET_MARGIN or ball.position.y < -RESET_MARGIN or ball.position.y > 1920.0 + RESET_MARGIN

func _show_error(message: String) -> void:
	error_label.text = message
	error_panel.visible = true

func _update_hud() -> void:
	strokes_label.text = "SCHLAEGE  %d" % strokes
	par_label.text = "PAR  %d" % par
