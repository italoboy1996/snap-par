class_name SnapParBall
extends RigidBody2D

signal surface_contact(material_name: String, impact_speed: float)

const MATERIALS := {
	"rock": {"friction": 0.60, "bounce": 0.40},
	"sand": {"friction": 0.95, "bounce": 0.05},
	"ice": {"friction": 0.02, "bounce": 0.30},
}

var radius := 22.0
var current_surface := "rock"

@onready var visual: SnapParBallVisual = $Visual

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_surface_material(current_surface)

func set_radius(value: float) -> void:
	radius = value
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is CircleShape2D:
		(shape_node.shape as CircleShape2D).radius = radius
	if visual.has_method("set_radius"):
		visual.set_radius(radius)

func _on_body_entered(body: Node) -> void:
	if not body.has_meta("surface_material"):
		return
	current_surface = str(body.get_meta("surface_material"))
	_apply_surface_material(current_surface)
	var impact_speed := linear_velocity.length()
	if visual.has_method("squash"):
		visual.squash(impact_speed, linear_velocity)
	surface_contact.emit(current_surface, impact_speed)

func _apply_surface_material(material_name: String) -> void:
	var values: Dictionary = MATERIALS.get(material_name, MATERIALS["rock"])
	var material := PhysicsMaterial.new()
	material.friction = float(values["friction"])
	material.bounce = float(values["bounce"])
	physics_material_override = material
