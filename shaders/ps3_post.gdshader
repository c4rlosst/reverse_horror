shader_type canvas_item;
// Late-2000s console look: soft chromatic fringe, desaturation, film grain,
// and a heavy vignette. `monster_mix` pushes the image colder and tighter once
// the player has become the monster.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float aberration = 0.002;
uniform float grain_strength = 0.07;
uniform float vignette_strength = 0.6;
uniform float desaturation = 0.3;
uniform float monster_mix : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_centre = uv - vec2(0.5);
	vec2 shift = from_centre * aberration;
	vec3 colour = vec3(
		texture(screen_tex, uv + shift).r,
		texture(screen_tex, uv).g,
		texture(screen_tex, uv - shift).b
	);

	float luma = dot(colour, vec3(0.299, 0.587, 0.114));
	colour = mix(colour, vec3(luma), clamp(desaturation + monster_mix * 0.5, 0.0, 1.0));
	colour *= mix(vec3(1.0), vec3(0.8, 0.9, 1.1), monster_mix);

	float grain = hash(uv / SCREEN_PIXEL_SIZE + fract(TIME) * 100.0) - 0.5;
	colour += grain * grain_strength;

	float vignette = smoothstep(0.85, 0.2, length(from_centre) * (1.0 + monster_mix * 0.4));
	colour *= mix(1.0, vignette, vignette_strength);

	COLOR = vec4(colour, 1.0);
}
