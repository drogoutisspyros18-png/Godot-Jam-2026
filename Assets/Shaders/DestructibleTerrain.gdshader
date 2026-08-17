shader_type canvas_item;

// ---------------------------------------------------------
// TOGGLES
// ---------------------------------------------------------
uniform bool enable_wipe = false;
uniform bool enable_ripple = false;

// ---------------------------------------------------------
// WIPE UNIFORMS (From Ghost Shader)
// ---------------------------------------------------------
uniform vec2 dash_start_global;
uniform vec2 dash_direction;
uniform float dash_length;
uniform float bite_radius;
uniform float progress; 

// ---------------------------------------------------------
// RIPPLE UNIFORMS (From Terrain Shader)
// ---------------------------------------------------------
uniform vec2 impact_global_position;
uniform float force = 0.0;
uniform float size = 0.0;
uniform float thickness = 40.0;
uniform float highlight_intensity = 0.0; 

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 current_world_pos = world_position;
	vec2 uv_offset = vec2(0.0);

	// 1. DASH WIPE MECHANIC
	if (enable_wipe) {
		vec2 diff = current_world_pos - dash_start_global;
		float dist_along = dot(diff, dash_direction);
		vec2 projection = dash_direction * dist_along;
		float dist_side = length(diff - projection);
		
		bool inside_tunnel = (dist_side <= bite_radius) && (dist_along >= 0.0) && (dist_along <= dash_length);
		
		if (inside_tunnel && dist_along <= (progress * dash_length) + bite_radius) {
			discard;
		}
	}

	// 2. TERRAIN RIPPLE MECHANIC
	if (enable_ripple) {
		float dist = distance(current_world_pos, impact_global_position);
		float mask = (1.0 - smoothstep(size - 1.0, size, dist)) * smoothstep(max(0.0, size - thickness - 1.0), max(0.0, size - thickness), dist);
		
		vec2 disp_dir = normalize(current_world_pos - impact_global_position);
		float actual_force = force * mask;
		
		uv_offset = disp_dir * actual_force * TEXTURE_PIXEL_SIZE;
		current_world_pos -= (disp_dir * actual_force); 
	}

	// ---------------------------------------------------------
	// 3. YOUR VISUALS (Only write this once!)
	// Test your poster, TV billboard, or jello here.
	// ---------------------------------------------------------
	vec2 goop_uv = current_world_pos * 0.015; 
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
	
	// Apply UV distortion from the ripple
	vec4 tex_color = texture(TEXTURE, UV - uv_offset);
	
	// Add the highlight intensity for the flash
	COLOR = vec4(goop_color * tex_color.rgb, tex_color.a) + vec4(vec3(highlight_intensity), 0.0);
}