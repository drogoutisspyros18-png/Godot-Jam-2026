shader_type canvas_item;

uniform vec2 impact_global_position;
uniform float force = 0.0;
uniform float size = 0.0;
uniform float thickness = 40.0;

// Kept so your GDScript tween doesn't crash!
uniform float highlight_intensity = 0.0; 

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// 1. Calculate the physical shockwave mask
	float dist = distance(world_position, impact_global_position);
	float mask = (1.0 - smoothstep(size - 1.0, size, dist)) * smoothstep(max(0.0, size - thickness - 1.0), max(0.0, size - thickness), dist);
	
	// 2. Calculate the displacement vector
	vec2 disp_dir = normalize(world_position - impact_global_position);
	float actual_force = force * mask;
	
	// Distort the UVs for the base texture
	vec2 uv_disp = disp_dir * actual_force * TEXTURE_PIXEL_SIZE;
	vec4 tex_color = texture(TEXTURE, UV - uv_disp);
	
	// Distort the world position for the math goop so the shockwave pushes the fluid
	vec2 distorted_world_pos = world_position - (disp_dir * actual_force);
	
	// ---------------------------------------------------------
	// THE JELLO (Always active, distorted by the ripple)
	// ---------------------------------------------------------
	vec2 goop_uv = distorted_world_pos * 0.015; 
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
	
	// Multiply the goop with the texture. 
	// If you use your noise texture, it adds lovely gritty shading to the jello!
	// If you remove the texture, tex_color is white, and the goop displays perfectly.
	COLOR = vec4(goop_color * tex_color.rgb, tex_color.a);
}