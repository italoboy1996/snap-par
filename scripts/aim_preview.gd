class_name AimPreviewDrawer
extends Node2D

var start_point := Vector2.ZERO
var end_point := Vector2.ZERO
var visible_preview := false

func show_preview(from: Vector2, to: Vector2) -> void:
	start_point = from
	end_point = to
	visible_preview = true
	queue_redraw()

func hide_preview() -> void:
	visible_preview = false
	queue_redraw()

func _draw() -> void:
	if not visible_preview:
		return
	var delta := end_point - start_point
	var length := delta.length()
	if length < 1.0:
		return
	var direction := delta / length
	var distance := 0.0
	while distance < length:
		var dot_position := start_point + direction * distance
		var radius := lerpf(6.0, 2.5, distance / length)
		draw_circle(dot_position, radius, Color(1.0, 1.0, 1.0, 0.82))
		distance += 22.0
