shader_type canvas_item;
// Fond du menu pause (lot V3-INTERFACE, style net) : l'image du jeu figée derrière le menu, floutée (mipmaps
// de l'écran : textureLod), désaturée, assombrie et vignettée. « amount » anime l'ouverture (0 → 1).
// Ne tourne que pendant la pause ; le style rétro garde son voile noir d'avant.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float lod = 2.6;
uniform float dim = 0.42;
uniform float desat = 0.45;

vec3 tap(vec2 uv, float l) {
	return textureLod(screen_tex, uv, l).rgb;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float l = lod * amount;
	vec2 px = SCREEN_PIXEL_SIZE * exp2(l) * 0.8;
	vec3 b = tap(uv, l) * 0.28;
	b += tap(uv + vec2(px.x, px.y), l) * 0.18;
	b += tap(uv + vec2(-px.x, px.y), l) * 0.18;
	b += tap(uv + vec2(px.x, -px.y), l) * 0.18;
	b += tap(uv + vec2(-px.x, -px.y), l) * 0.18;
	float lum = dot(b, vec3(0.299, 0.587, 0.114));
	b = mix(b, vec3(lum), desat * amount);
	vec2 d = uv - vec2(0.5);
	float vig = clamp(1.0 - dot(d, d) * 1.4, 0.0, 1.0);
	b *= mix(1.0, (1.0 - dim) * vig, amount);
	COLOR = vec4(b, 1.0);
}
