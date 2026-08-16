extends CharacterBody2D

const TERRAIN_LAYER = 1
const DESTRUCTIBLE_LAYER = 2 # Ensure your DestructiblePolygon2D collisions are set to this layer
const MAX_ROOM_SIZE = 4000.0 # Maximum distance to raycast for the indestructible bounds

@export var speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.25 # Base max duration if nothing is hit
@export var bite_radius: float = 32

var dash_direction: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0
var is_dead: bool = false
var _vfx_tween: Tween

@onready var particles: Node2D = $Particles
# Visual Pool for Web Optimization
@onready var ghost_polygon: Polygon2D = %GhostTerrainRenderer


func _ready() -> void:
	particles.set("enabled", false)
	ghost_polygon.hide()
	ghost_polygon.top_level = true # Decouples transform from player movement


func _process(_delta: float) -> void:
	if is_dead:
		return

	if Input.is_action_just_pressed("use_ability") and dash_timer <= 0.0:
		_start_dash()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if dash_timer > 0.0:
		_process_dash(delta)
	else:
		_process_normal_movement(delta)

	move_and_slide()


func apply_hit_stop(duration_seconds: float):
	# Freeze the engine
	Engine.time_scale = 0.0

	# Create a timer that ignores Engine.time_scale (process_always = true, process_in_physics = false, ignore_time_scale = true)
	await get_tree().create_timer(duration_seconds, true, false, true).timeout

	# Restore normal time
	Engine.time_scale = 1.0


func _process_normal_movement(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var h_dir := Input.get_axis("left", "right")
	if h_dir:
		velocity.x = h_dir * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)


func _start_dash() -> void:
	var dir := Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down")).normalized()
	#NOTE: this code is confusing, should just default to last dir pressed.
	if dir == Vector2.ZERO:
		dir = Vector2(1.0 if velocity.x >= 0.0 else -1.0, 0.0)
	dash_direction = dir
	particles.position = dash_direction * bite_radius
	_carve_dash_path()


func _process_dash(delta: float) -> void:
	dash_timer -= delta
	velocity = dash_direction * dash_speed

	if dash_timer <= 0.0:
		_end_dash()


func _end_dash() -> void:
	particles.set("enabled", false)
	dash_timer = 0.0
	velocity *= 0.5
	# set_collision_mask_value(TERRAIN_LAYER, true)
	# set_collision_mask_value(DESTRUCTIBLE_LAYER, true)
	ghost_polygon.hide() # Reset the shader state without freeing memory


func _carve_dash_path() -> void:
	# Bypassing RayCast2D nodes for pure math direct space state (Web Optimization)
	var space_state = get_world_2d().direct_space_state

	# Default maximum dash distance
	var max_dash_distance := dash_speed * dash_duration

	# ---------------------------------------------------------
	# RAYCAST 1: Find the Indestructible Wall Limit
	# ---------------------------------------------------------
	var query_indestructible = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + (dash_direction * MAX_ROOM_SIZE),
		1 << (TERRAIN_LAYER - 1),
	)
	var hit_indestructible = space_state.intersect_ray(query_indestructible)

	if hit_indestructible:
		print("hit indestructible result ", hit_indestructible)
		var dist_to_wall = global_position.distance_to(hit_indestructible.position)
		# Clamp the maximum dash distance so we never cut past the indestructible bounds
		max_dash_distance = max(max_dash_distance, dist_to_wall)

	# Dynamically set the duration so the player stops exactly at the wall/limit
	dash_timer = max_dash_distance / dash_speed

	# ---------------------------------------------------------
	# RAYCAST 2: Detect the Destructible Polygon
	# ---------------------------------------------------------
	var query_destructible = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + (dash_direction * max_dash_distance),
		1 << (DESTRUCTIBLE_LAYER - 1),
	)
	var hit_destructible = space_state.intersect_ray(query_destructible)

	if hit_destructible and hit_destructible.collider is StaticBody2D:
		print("hit destructible result ", hit_destructible)
		var collider = hit_destructible.collider
		var dest: DestructiblePolygon2D = collider.get_meta("destruct_root", null)

		if dest:
			await apply_hit_stop(0.125)
			# The Polygon2D visual is the parent of the StaticBody2D
			var target_poly = collider.get_parent() as Polygon2D
			if target_poly:
				_trigger_dash_vfx(target_poly, dash_timer, max_dash_distance)

			# Build the mask to cut the entire possible distance
			var mask := Transform2D(dash_direction.angle(), Vector2.ZERO) * PackedVector2Array(
				[
					Vector2(0, -bite_radius),
					Vector2(max_dash_distance, -bite_radius),
					Vector2(max_dash_distance, bite_radius),
					Vector2(0, bite_radius),
				],
			)

			# Execute the cut instantly in the background
			var destructed_area = dest.destruct(mask, global_position)

			# ---------------------------------------------------------
			# DEATH MATH: "Celeste Dream Goop" Check
			# ---------------------------------------------------------
			var carved_length = destructed_area / (bite_radius * 2.0)

			# If the length of the solid dirt carved equals or exceeds our max travel distance
			# (accounting for tiny float precision errors), we did not reach an air pocket.
			if carved_length >= max_dash_distance - 1.0:
				_trigger_entombment_death()


func _trigger_dash_vfx(target_poly: Polygon2D, duration: float, max_dist: float) -> void:
	particles.set("enabled", true)
	# 1. Copy visual data directly to the pool node (no instantiation)
	ghost_polygon.polygon = target_poly.polygon
	ghost_polygon.uv = target_poly.uv
	ghost_polygon.texture = target_poly.texture
	ghost_polygon.global_transform = target_poly.global_transform

	# 2. Update Shader Uniforms
	var mat := ghost_polygon.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("dash_start_global", global_position)
		mat.set_shader_parameter("dash_direction", dash_direction)
		mat.set_shader_parameter("dash_length", max_dist)
		mat.set_shader_parameter("bite_radius", bite_radius)
		mat.set_shader_parameter("progress", 0.0)

	# 3. Reveal the ghost shell to cover the instant geometry cut
	ghost_polygon.show()

	# 4. Tween the progress from 0.0 to 1.0 over the dash duration
	if _vfx_tween:
		_vfx_tween.kill()
	_vfx_tween = create_tween()
	_vfx_tween.tween_property(mat, "shader_parameter/progress", 1.0, duration)


func _trigger_entombment_death() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	dash_timer = 0.0
	ghost_polygon.hide()

	print("Player entombed in terrain! Restarting...")

	# Use call_deferred to safely reload the tree outside of the physics step
	get_tree().call_deferred("reload_current_scene")
