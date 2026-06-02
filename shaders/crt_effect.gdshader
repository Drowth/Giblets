shader_type canvas_item;

// Darkness & atmosphere
uniform float brightness        : hint_range(0.4, 1.0) = 0.78;
uniform vec3  color_tint                               = vec3(0.88, 0.84, 0.96);

// Vignette
uniform float vignette_power    : hint_range(0.1, 2.0) = 0.50;
uniform float vignette_strength : hint_range(0.0, 2.0) = 1.10;

// CRT optics
uniform float curvature         : hint_range(0.0, 0.12) = 0.022;
uniform float aberration        : hint_range(0.0, 0.008) = 0.0022;

// Scanlines
uniform float scanline_intensity : hint_range(0.0, 0.5) = 0.13;

// Noise / flicker
uniform float noise_intensity   : hint_range(0.0, 0.12) = 0.032;
uniform float flicker_amount    : hint_range(0.0, 0.05) = 0.016;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

vec2 barrel(vec2 uv) {
	uv = uv * 2.0 - 1.0;
	uv.x *= 1.0 + uv.y * uv.y * curvature;
	uv.y *= 1.0 + uv.x * uv.x * curvature;
	return uv * 0.5 + 0.5;
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = barrel(SCREEN_UV);
	bool oob = uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0;

	if (oob) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// Chromatic aberration
		float r = texture(SCREEN_TEXTURE, uv + vec2(aberration, 0.0)).r;
		float g = texture(SCREEN_TEXTURE, uv).g;
		float b = texture(SCREEN_TEXTURE, uv - vec2(aberration, 0.0)).b;
		vec3 col = vec3(r, g, b);

		// Horizontal scanlines
		float scan = mod(floor(FRAGCOORD.y), 2.0);
		col *= 1.0 - scanline_intensity * scan;

		// Subtle RGB phosphor column grid
		float px_col = mod(floor(FRAGCOORD.x), 3.0);
		col *= 1.0 - 0.025 * step(2.0, px_col);

		// Vignette
		vec2 vig = uv * (1.0 - uv);
		float vignette = pow(vig.x * vig.y * 16.0, vignette_power);
		col *= mix(1.0 - vignette_strength, 1.0, vignette);

		// Film grain
		float noise = hash21(uv + fract(vec2(TIME * 0.31, TIME * 0.27)));
		col += (noise - 0.5) * noise_intensity;

		// Phosphor flicker
		float flicker = 1.0 - flicker_amount * sin(TIME * 23.7 + 1.3);
		col *= flicker;

		// Brightness + cold-purple tint
		col *= brightness * color_tint;

		COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
	}
}
