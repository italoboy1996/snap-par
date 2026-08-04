class_name TerrainOverlayDrawer
extends Node2D

const Generator := preload("res://scripts/terrain_from_image.gd")
const CELL_SIZE := 10.0

var cells := PackedInt32Array()

func set_cells(value: PackedInt32Array) -> void:
	cells = value
	queue_redraw()

func _draw() -> void:
	if cells.size() != Generator.GRID_WIDTH * Generator.GRID_HEIGHT:
		return
	for y in range(Generator.GRID_HEIGHT):
		for x in range(Generator.GRID_WIDTH):
			var material := cells[y * Generator.GRID_WIDTH + x]
			var colour := _overlay_colour(material)
			if colour.a <= 0.0:
				continue
			draw_rect(Rect2(Vector2(x, y) * CELL_SIZE, Vector2.ONE * CELL_SIZE), colour, true)

func _overlay_colour(material: int) -> Color:
	match material:
		Generator.ROCK:
			return Color(0.20, 0.16, 0.24, 0.24)
		Generator.SAND:
			return Color(0.94, 0.70, 0.24, 0.22)
		Generator.ICE:
			return Color(0.72, 0.92, 1.00, 0.20)
		Generator.WATER:
			return Color(0.10, 0.48, 0.92, 0.28)
		Generator.AIR:
			return Color(0.80, 0.94, 1.00, 0.025)
		_:
			return Color.TRANSPARENT
