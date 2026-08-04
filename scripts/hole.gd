extends Area2D

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 30.0, Color(0.02, 0.02, 0.025, 0.90))
	draw_circle(Vector2.ZERO, 22.0, Color(0.0, 0.0, 0.0, 1.0))
	draw_line(Vector2(0, 0), Vector2(0, -86), Color(0.95, 0.95, 0.92, 1.0), 5.0, true)
	var flag := PackedVector2Array([Vector2(2, -84), Vector2(48, -68), Vector2(2, -52)])
	draw_colored_polygon(flag, Color(0.93, 0.20, 0.18, 1.0))
