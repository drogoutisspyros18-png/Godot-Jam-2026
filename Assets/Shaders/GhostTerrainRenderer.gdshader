shader_type canvas_item;

// Fed in from player.gd
uniform vec2 dash_start_global;
uniform vec2 dash_direction;
uniform float dash_length;
uniform float bite_radius;
uniform float progress; // Animates from 0.0 to 1.0

varying vec2 world_position;

void vertex() {
	// Grab the true global world position of the vertex
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// Get the vector from the dash starting point to this specific pixel
	vec2 diff = world_position - dash_start_global;
	
	// Project that vector to find how far forward (along the dash) this pixel is
	float dist_along = dot(diff, dash_direction);
	
	// Find the orthogonal distance to see how far sideways this pixel is from the center line
	vec2 projection = dash_direction * dist_along;
	float dist_side = length(diff - projection);
	
	// Check if this pixel lives inside the carved rectangle
	bool inside_tunnel = (dist_side <= bite_radius) && (dist_along >= 0.0) && (dist_along <= dash_length);
	
	// If it is inside the tunnel, and the player's progress has passed it, erase it
	if (inside_tunnel && dist_along <= (progress * dash_length)) {
		discard;
	}
}