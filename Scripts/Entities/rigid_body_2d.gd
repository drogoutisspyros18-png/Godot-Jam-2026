extends CollisionPolygon2D

@export var timer: Timer

var dest_polygon: DestructiblePolygon2D
var enabled: bool = false


func _ready() -> void:
	timer.connect("timeout", disable)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if enabled:
		dest_polygon.destruct(self.polygon, global_position)
		timer.start()


func disable():
	if enabled:
		enabled = false
