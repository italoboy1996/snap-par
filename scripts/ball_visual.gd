class_name SnapParBallVisual
extends Node2D

var radius := 22.0
var squash_tween: Tween

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# Soft contact shadow and subtle mint glow keep the ball readable on every photo.
	draw_circle(Vector2(5, 8), radius + 4.0, Color(0, 0, 0, 0.28))
	draw_circle(Vector2.ZERO, radius + 3.0, Color(0.42, 1.0, 0.72, 0.22))
	draw_circle(Vector2.ZERO, radius, Color(0.975, 0.985, 0.97, 1.0))
	draw_circle(Vector2(-7, -8), radius * 0.30, Color(1.0, 1.0, 1.0, 0.82))

	var dimples := [
		Vector2(-8, 4), Vector2(2, 7), Vector2(9, -2),
		Vector2(-1, -5), Vector2(-11, -7), Vector2(7, 10),
	]
	for dimple in dimples:
		draw_circle(dimple, 2.1, Color(0.50, 0.56, 0.53, 0.22))

	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.04, 0.07, 0.06, 0.72), 2.2, true)

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
