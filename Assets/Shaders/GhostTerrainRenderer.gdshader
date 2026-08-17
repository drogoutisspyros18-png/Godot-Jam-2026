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
	// ---------------------------------------------------------
	// 1. THE WIPE LOGIC
	// ---------------------------------------------------------
	vec2 diff = world_position - dash_start_global;
	float dist_along = dot(diff, dash_direction);
	vec2 projection = dash_direction * dist_along;
	float dist_side = length(diff - projection);
	
	bool inside_tunnel = (dist_side <= bite_radius) && (dist_along >= 0.0) && (dist_along <= dash_length);
	
	// Adding bite_radius pushes the discard threshold forward to uncover the whole sprite
	if (inside_tunnel && dist_along <= (progress * dash_length) + bite_radius) {
		discard;
	}

	// ---------------------------------------------------------
	// 2. THE JELLO GOOP (Syncs perfectly with the live terrain)
	// ---------------------------------------------------------
	vec2 goop_uv = world_position * 0.015; 
	float t = TIME * 4.0;
	
	float wave = sin(goop_uv.x + t) 
			   + sin(goop_uv.y + t * 0.8) 
			   + sin((goop_uv.x + goop_uv.y) * 1.5 + t * 1.2) 
			   + sin(length(goop_uv) * 2.0 - t * 2.0);
			   
	vec3 goop_color = vec3(
		sin(wave * 0.5) * 0.5 + 0.5,
		sin(wave * 0.3 + 2.0) * 0.5 + 0.5,
		sin(wave * 0.6 + 4.0) * 0.5 + 0.8
	);
	
	// Grab the base texture
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Output the combined color so the ghost shell perfectly mimics the live terrain
	COLOR = vec4(goop_color * tex_color.rgb, tex_color.a);
}