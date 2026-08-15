extends CharacterBody2D

# --- ENUMS & CONSTANTS ---
enum State { NORMAL, DASHING }

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const DASH_SPEED = 800.0
const DASH_DURATION = 0.25
const TERRAIN_LAYER = 1

# --- STATE VARIABLES ---
var current_state: State = State.NORMAL
var dash_direction := Vector2.ZERO
var dash_timer := 0.0
# --- ABILITY VARIABLES ---
var destruct_interval := 0.0
var bite_timer := 0.0
var bite_size_px := 0.0

# --- ONREADY NODES ---
@onready var raycast: RayCast2D = $RayCast2D
@onready var bite_hitbox: Area2D = $BiteHitbox
@onready var bite_shape: CollisionPolygon2D = $BiteHitbox/CollisionPolygon2D


# ==========================================
# ENGINE CALLBACKS
# ==========================================
func _ready() -> void:
	_calculate_bite_metrics()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("use_ability") and current_state == State.NORMAL:
		_start_dash()


func _physics_process(delta: float) -> void:
	match current_state:
		State.NORMAL:
			_process_normal_movement(delta)
		State.DASHING:
			_process_dash(delta)

	move_and_slide()


# ==========================================
# STATE LOGIC: NORMAL
# ==========================================
func _process_normal_movement(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var h_dir := Input.get_axis("left", "right")
	var v_dir := Input.get_axis("up", "down")
	var move_dir := Vector2(h_dir, v_dir)

	if h_dir:
		velocity.x = h_dir * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if move_dir != Vector2.ZERO:
		raycast.target_position = move_dir.normalized() * 100


# ==========================================
# STATE LOGIC: DASHING
# ==========================================
func _start_dash() -> void:
	current_state = State.DASHING
	dash_timer = DASH_DURATION
	bite_timer = 0.0

	var h_dir = Input.get_axis("left", "right")
	var v_dir = Input.get_axis("up", "down")
	dash_direction = Vector2(h_dir, v_dir).normalized()

	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2(1 if velocity.x >= 0 else -1, 0)

	set_collision_mask_value(TERRAIN_LAYER, false)

	bite_hitbox.global_position = global_position
	_take_bite()


func _process_dash(delta: float) -> void:
	dash_timer -= delta
	bite_timer += delta

	velocity = dash_direction * DASH_SPEED
	bite_hitbox.global_position = global_position

	if bite_timer >= destruct_interval:
		_take_bite()
		bite_timer -= destruct_interval

	# Check for dash exit condition once the initial burst finishes
	if dash_timer <= 0.0 and not _is_terrain_ahead():
		_end_dash()


func _end_dash() -> void:
	current_state = State.NORMAL
	velocity *= 0.5
	set_collision_mask_value(TERRAIN_LAYER, true)


# ==========================================
# HELPER FUNCTIONS
# ==========================================
func _take_bite() -> void:
	var bodies = bite_hitbox.get_overlapping_bodies()
	var modified_nodes = []

	for collider in bodies:
		if collider is StaticBody2D:
			var dest_polygon: DestructiblePolygon2D = collider.get_meta("destruct_root", null)

			if dest_polygon and not dest_polygon in modified_nodes:
				dest_polygon.destruct(bite_shape.polygon, bite_hitbox.global_position)
				modified_nodes.append(dest_polygon)


func _is_terrain_ahead() -> bool:
	raycast.target_position = dash_direction * (bite_size_px * 1.25)
	raycast.force_raycast_update()

	if raycast.is_colliding():
		var collider = raycast.get_collider()
		return collider is Node2D and collider.has_meta("destruct_root")

	return false


func _calculate_bite_metrics() -> void:
	if bite_shape and bite_shape.polygon.size() > 0:
		var min_x = INF
		var max_x = -INF
		for p in bite_shape.polygon:
			min_x = min(min_x, p.x)
			max_x = max(max_x, p.x)

		bite_size_px = max_x - min_x
		destruct_interval = (bite_size_px * 0.75) / DASH_SPEED
