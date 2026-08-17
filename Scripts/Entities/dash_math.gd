class_name DashMath
extends RefCounted


## 1. Calculates the maximum allowed dash distance before hitting an indestructible wall.
static func get_wall_limited_distance(space_state: PhysicsDirectSpaceState2D, start_pos: Vector2, direction: Vector2, base_max_dist: float, max_room_size: float, terrain_layer: int) -> float:
	var query = PhysicsRayQueryParameters2D.create(
		start_pos,
		start_pos + (direction * max_room_size),
		1 << (terrain_layer - 1),
	)
	var hit = space_state.intersect_ray(query)

	if hit:
		var dist_to_wall = start_pos.distance_to(hit.position)
		# Clamp the maximum dash distance so we never cut past the indestructible bounds
		return max(base_max_dist, dist_to_wall)

	return base_max_dist


## 2. Performs the raycast to find destructible terrain.
static func get_destructible_hit(space_state: PhysicsDirectSpaceState2D, start_pos: Vector2, direction: Vector2, distance: float, layer: int) -> Dictionary:
	var query = PhysicsRayQueryParameters2D.create(
		start_pos,
		start_pos + (direction * distance),
		1 << (layer - 1),
	)
	return space_state.intersect_ray(query)


## 3. Builds the polygon mask used to cut the terrain geometry.
static func build_cut_mask(direction: Vector2, distance: float, radius: float) -> PackedVector2Array:
	return Transform2D(direction.angle(), Vector2.ZERO) * PackedVector2Array(
		[
			Vector2(0, -radius),
			Vector2(distance, -radius),
			Vector2(distance, radius),
			Vector2(0, radius),
		],
	)


## 4. Evaluates if the player carved through too much solid material without reaching an air pocket.
static func is_entombed(carved_area: float, radius: float, dash_distance: float) -> bool:
	var carved_length = carved_area / (radius * 2.0)
	return carved_length >= dash_distance - 1.0
