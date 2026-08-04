class_name SnapParBallVisual
extends Node2D

var radius := 22.0
var squash_tween: Tween

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.97, 0.97, 0.94, 1.0))
	draw_circle(Vector2(-7, -8), radius * 0.28, Color(1.0, 1.0, 1.0, 0.78))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(0.10, 0.10, 0.12, 0.65), 2.0, true)

func set_radius(value: float) -> void:
	radius = value
	queue_redraw()

func squash(impact_speed: float, velocity: Vector2) -> void:
	if impact_speed < 65.0:
		return
	if squash_tween and squash_tween.is_running():
		squash_tween.kill()
	var amount := lerpf(0.025, 0.11, clampf(impact_speed / 1100.0, 0.0, 1.0))
	rotation = velocity.angle()
	scale = Vector2(1.0 - amount, 1.0 + amount)
	squash_tween = create_tween()
	squash_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	squash_tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	squash_tween.parallel().tween_property(self, "rotation", 0.0, 0.12)
