extends RigidBody2D

@export var dest_polygon: DestructiblePolygon2D

@onready var shape: CollisionPolygon2D = $CollisionPolygon2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	dest_polygon.destruct(shape.polygon, global_position)
