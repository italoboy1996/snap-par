class_name TrailDrawer
extends Node2D

const MIN_POINT_DISTANCE := 5.0

var strokes: Array[PackedVector2Array] = []
var active_stroke := PackedVector2Array()

func begin_stroke(start_position: Vector2) -> void:
	active_stroke = PackedVector2Array([start_position])
	queue_redraw()

func add_point(point: Vector2) -> void:
	if active_stroke.is_empty():
		return
	if active_stroke[-1].distance_to(point) < MIN_POINT_DISTANCE:
		return
	active_stroke.append(point)
	queue_redraw()

func end_stroke() -> void:
	if active_stroke.size() >= 2:
		strokes.append(active_stroke)
	active_stroke = PackedVector2Array()
	queue_redraw()

func clear() -> void:
	strokes.clear()
	active_stroke = PackedVector2Array()
	queue_redraw()

func _draw() -> void:
	for stroke in strokes:
		if stroke.size() >= 2:
			draw_polyline(stroke, Color(0.04, 0.04, 0.05, 0.78), 3.0, true)
	if active_stroke.size() >= 2:
		draw_polyline(active_stroke, Color(0.04, 0.04, 0.05, 0.78), 3.0, true)
