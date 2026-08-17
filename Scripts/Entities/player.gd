extends CharacterBody2D
## Main player controller. Handles movement, state transitions, 
## and triggering terrain destruction/VFX.

enum State {
	MOVE,
	DASH,
	DEAD,
}

# --- Physics Layers & Limits ---
const TERRAIN_LAYER = 1
const DESTRUCTIBLE_LAYER = 2 # Target layer for DestructiblePolygon2D hits
const MAX_ROOM_SIZE = 4000.0 # Safety limit for raycasts to prevent infinite math

# --- Movement & Ability Tuning ---
@export var speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.25 # Base max duration if no indestructible walls are hit
@export var bite_radius: float = 32 # The thickness of the destruction tunnel

var current_state: State = State.MOVE
var dash_direction: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0
var _vfx_tween: Tween

# --- Visual Nodes ---
@onready var particles: Node2D = $Particles
@onready var ghost_polygon: Polygon2D = %GhostTerrainRenderer


func _ready() -> void:
	particles.set("enabled", false)
	ghost_polygon.hide()

	# Decouple the ghost polygon's transform from the player.
	# This allows us to freeze it in world space over the exact spot of destruction.
	ghost_polygon.top_level = true


func _process(_delta: float) -> void:
	if current_state == State.DEAD:
		return

	# Only allow dashing if we are in the normal movement state
	if Input.is_action_just_pressed("use_ability") and current_state == State.MOVE:
		change_state(State.DASH)


func _physics_process(delta: float) -> void:
	# State Machine Router
	match current_state:
		State.MOVE:
			_process_normal_movement(delta)
		State.DASH:
			_process_dash(delta)
		State.DEAD:
			pass # Gravity/movement is disabled while dead

	move_and_slide()


## Centralized state management to guarantee clean transitions
func change_state(new_state: State) -> void:
	current_state = new_state

	match current_state:
		State.DASH:
			_start_dash()
		State.MOVE:
			_end_dash()
		State.DEAD:
			_trigger_entombment_death_logic()


## Briefly freezes the engine to give impacts a heavy, crunchy feel.
func apply_hit_stop(duration_seconds: float):
	Engine.time_scale = 0.0

	# Create a timer that explicitly ignores Engine.time_scale so it can unfreeze the game
	await get_tree().create_timer(duration_seconds, true, false, true).timeout

	Engine.time_scale = 1.0


func _process_normal_movement(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Horizontal movement with snappy friction
	var h_dir := Input.get_axis("left", "right")
	if h_dir:
		velocity.x = h_dir * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)


func _start_dash() -> void:
	# 1. Determine dash direction based on input or facing direction
	var dir := Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down")).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(1.0 if velocity.x >= 0.0 else -1.0, 0.0)

	dash_direction = dir

	# Push particles forward slightly so they lead the visual cut
	particles.position = dash_direction * bite_radius

	# 2. Calculate the cut and initiate visuals
	_carve_dash_path()


func _process_dash(delta: float) -> void:
	dash_timer -= delta
	velocity = dash_direction * dash_speed

	# Automatically return to normal movement when the calculated distance is covered
	if dash_timer <= 0.0:
		change_state(State.MOVE)


func _end_dash() -> void:
	particles.set("enabled", false)
	dash_timer = 0.0

	# Preserve a little momentum exiting the dash
	velocity *= 0.5

	# Clean up the ghost shell
	ghost_polygon.hide()


## Handles the math and execution of carving through DestructiblePolygon2D nodes.
func _carve_dash_path() -> void:
	var space_state = get_world_2d().direct_space_state
	var base_max_dist := dash_speed * dash_duration

	# 1. Find Indestructible Limits
	# We never want to dash out of bounds or through solid metal walls.
	var max_dash_distance = DashMath.get_wall_limited_distance(
		space_state,
		global_position,
		dash_direction,
		base_max_dist,
		MAX_ROOM_SIZE,
		TERRAIN_LAYER,
	)

	# Lock in the duration so the player stops exactly at the indestructible wall (if any)
	dash_timer = max_dash_distance / dash_speed

	# 2. Detect Destructible Terrain
	var hit = DashMath.get_destructible_hit(
		space_state,
		global_position,
		dash_direction,
		max_dash_distance,
		DESTRUCTIBLE_LAYER,
	)

	if hit and hit.collider is StaticBody2D:
		var collider = hit.collider
		var dest: DestructiblePolygon2D = collider.get_meta("destruct_root", null)

		if dest:
			var target_poly = collider.get_parent() as Polygon2D

			# Trigger the ripple effect on the live terrain at the point of impact
			if target_poly:
				_trigger_terrain_ripple(target_poly, hit.position)

			# Pause the game for impact emphasis
			await apply_hit_stop(0.25)

			# Trigger the wipe effect on our ghost shell
			if target_poly:
				_trigger_dash_vfx(target_poly, dash_timer, max_dash_distance)

			# 3. Execute the Geometry Cut
			var mask = DashMath.build_cut_mask(dash_direction, max_dash_distance, bite_radius)
			var destructed_area = dest.destruct(mask, global_position)

			# 4. Check for Death (Celeste-style dream block logic)
			# If the player carved entirely through solid dirt without reaching an air pocket, they die.
			if DashMath.is_entombed(destructed_area, bite_radius, max_dash_distance):
				change_state(State.DEAD)


## Configures the ghost polygon to perfectly mimic the target terrain, then animates a mask wipe.
func _trigger_dash_vfx(target_poly: Polygon2D, duration: float, max_dist: float) -> void:
	particles.set("enabled", true)

	# 1. Sync geometry and textures
	ghost_polygon.polygon = target_poly.polygon
	ghost_polygon.uv = target_poly.uv
	ghost_polygon.texture = target_poly.texture
	ghost_polygon.global_transform = target_poly.global_transform
	ghost_polygon.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	# 2. Clone the Uber Shader dynamically (WASM optimized multi-pass fake)
	if target_poly.material:
		ghost_polygon.material = target_poly.material.duplicate()

	var mat := ghost_polygon.material as ShaderMaterial
	if mat:
		# Toggle ON the wipe logic, toggle OFF the ripple logic
		mat.set_shader_parameter("enable_wipe", true)
		mat.set_shader_parameter("enable_ripple", false)

		# Inject the wipe math parameters
		mat.set_shader_parameter("dash_start_global", global_position)
		mat.set_shader_parameter("dash_direction", dash_direction)
		mat.set_shader_parameter("dash_length", max_dist)
		mat.set_shader_parameter("bite_radius", bite_radius)
		mat.set_shader_parameter("progress", 0.0)

	# 3. Reveal and animate
	ghost_polygon.show()

	if _vfx_tween:
		_vfx_tween.kill()
	_vfx_tween = create_tween()
	_vfx_tween.tween_property(mat, "shader_parameter/progress", 1.0, duration)


func _trigger_entombment_death_logic() -> void:
	velocity = Vector2.ZERO
	dash_timer = 0.0
	ghost_polygon.hide()

	print("Player entombed in terrain! Restarting...")

	# Use call_deferred to safely reload the tree outside of the physics step
	get_tree().call_deferred("reload_current_scene")


## Applies an expanding shockwave to the target terrain's shader.
func _trigger_terrain_ripple(target_poly: Polygon2D, impact_world_pos: Vector2) -> void:
	if not target_poly.material is ShaderMaterial:
		push_warning("Target polygon does not have a ShaderMaterial assigned.")
		return

	# Duplicate the material so the ripple only affects this specific piece of terrain
	var unique_mat = target_poly.material.duplicate()
	target_poly.material = unique_mat

	# Toggle ON the ripple logic, toggle OFF the wipe logic (Uber Shader)
	unique_mat.set_shader_parameter("enable_ripple", true)
	unique_mat.set_shader_parameter("enable_wipe", false)

	# Initialize shockwave parameters
	unique_mat.set_shader_parameter("impact_global_position", impact_world_pos)
	unique_mat.set_shader_parameter("size", 0.0)
	unique_mat.set_shader_parameter("force", 50.0)
	unique_mat.set_shader_parameter("highlight_intensity", 1.0) # Start with a bright flash
	unique_mat.set_shader_parameter("thickness", 40.0)

	var tween = create_tween()
	tween.set_ignore_time_scale(true) # Ensure the ripple plays during hit-stop

	# Expand the ring outwards
	tween.tween_property(unique_mat, "shader_parameter/size", 300.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Simultaneously fade out the distortion force
	tween.parallel().tween_property(unique_mat, "shader_parameter/force", 0.0, 0.35).set_ease(Tween.EASE_OUT)

	# Simultaneously fade out the white flash quickly
	tween.parallel().tween_property(unique_mat, "shader_parameter/highlight_intensity", 0.0, 0.25).set_ease(Tween.EASE_OUT)
