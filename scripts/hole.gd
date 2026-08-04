extends Area2D

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# Layered rim and shadow make the target readable without hiding the photo.
	draw_ellipse_shadow()
	draw_circle(Vector2.ZERO, 34.0, Color(0.36, 1.0, 0.68, 0.18))
	draw_circle(Vector2.ZERO, 30.0, Color(0.92, 0.98, 0.94, 0.88))
	draw_circle(Vector2.ZERO, 24.0, Color(0.015, 0.02, 0.02, 1.0))
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 48, Color(0.45, 1.0, 0.72, 0.72), 2.0, true)

	draw_line(Vector2(2, 0), Vector2(2, -94), Color(0.97, 1.0, 0.98, 1.0), 5.0, true)
	draw_line(Vector2(6, 0), Vector2(6, -94), Color(0, 0, 0, 0.20), 2.0, true)
	var flag := PackedVector2Array([Vector2(4, -92), Vector2(54, -75), Vector2(4, -57)])
	draw_colored_polygon(flag, Color(1.0, 0.26, 0.21, 1.0))
	draw_polyline(PackedVector2Array([Vector2(4, -92), Vector2(54, -75), Vector2(4, -57)]), Color(1, 0.66, 0.52, 0.9), 2.0, true)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(5, 8), 0.0, Vector2(1.15, 0.52))
	draw_circle(Vector2.ZERO, 31.0, Color(0, 0, 0, 0.34))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
