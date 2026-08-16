shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// How big you want the chunky pixels to be
uniform float pixel_size : hint_range(1.0, 16.0, 1.0) = 4.0;

// Set this to your project's native base resolution (e.g., 1920x1080)
uniform vec2 base_resolution = vec2(1920.0, 1080.0);

void fragment() {
    // Snap the SCREEN_UVs to a grid based on your FIXED base resolution
    // instead of the dynamic screen size.
    vec2 grid_uv = floor(SCREEN_UV * base_resolution / pixel_size) * pixel_size / base_resolution;
    
    // Read the flattened image from the screen texture
    vec4 pixelated_color = texture(screen_texture, grid_uv);
    
    // Apply the color while preserving the CanvasGroup's alpha
    COLOR = pixelated_color * COLOR;
}