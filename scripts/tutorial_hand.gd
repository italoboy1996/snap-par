class_name TutorialHand
extends Node2D

var active := false
var animation: Tween

func _ready() -> void:
	visible = false
	queue_redraw()

func _draw() -> void:
	if not active:
		return
	var fill := Color(1.0, 0.88, 0.74, 0.94)
	var edge := Color(0.16, 0.13, 0.12, 0.72)
	draw_line(Vector2(0, -6), Vector2(0, 58), fill, 25.0, true)
	draw_circle(Vector2(0, -21), 20.0, fill)
	draw_arc(Vector2(0, -21), 20.0, 0.0, TAU, 32, edge, 3.0, true)
	draw_line(Vector2(-12, 55), Vector2(12, 55), edge, 3.0, true)

func play(ball_position: Vector2) -> void:
	if animation and animation.is_running():
		animation.kill()
	active = true
	visible = true
	position = ball_position + Vector2(0, 18)
	scale = Vector2.ONE
	modulate = Color(1, 1, 1, 0)
	queue_redraw()
	animation = create_tween()
	animation.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	animation.tween_property(self, "modulate:a", 1.0, 0.16)
	animation.tween_property(self, "position", ball_position + Vector2(0, 175), 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	animation.tween_property(self, "scale", Vector2(0.82, 0.82), 0.10).set_trans(Tween.TRANS_BACK)
	animation.tween_interval(0.12)
	animation.tween_property(self, "modulate:a", 0.0, 0.32)
	animation.finished.connect(_finish)

func _finish() -> void:
	active = false
	visible = false
	queue_redraw()
