// Filtre plein écran rétro : palette réduite + tramage ordonné (Bayer 4×4), grain, vignettage,
// aberration chromatique. Appliqué sur l'image 640×360 avant l'agrandissement, donc chaque
// point du tramage est un vrai pixel de l'écran rétro.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float levels = 16.0;          // niveaux par canal (plus bas = plus rétro)
uniform float dither_strength = 1.0;
uniform float grain = 0.045;
uniform float vignette = 0.85;
uniform float aberration = 0.0011;
uniform float corruption = 0.0;       // 0..1 : la partie « pourrit » l'image
uniform float blackout = 0.0;         // 0..1 : fondu au noir
uniform vec3 tint = vec3(1.0);

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
                                  3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float r2 = dot(d, d);
	// petites déchirures horizontales quand la corruption monte
	float tear = step(0.985 - corruption * 0.08, rnd(vec2(floor(uv.y * 90.0), floor(TIME * 12.0))));
	uv.x += tear * (rnd(vec2(TIME, uv.y)) - 0.5) * 0.04 * corruption;
	vec2 off = d * r2 * aberration * 40.0 * (1.0 + corruption * 4.0);
	vec3 c;
	c.r = texture(screen_tex, uv + off).r;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - off).b;
	c *= mix(1.0, smoothstep(0.95, 0.12, r2 * 1.9), vignette);
	c += (rnd(FRAGCOORD.xy + fract(TIME * 7.13) * 97.0) - 0.5) * grain;
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float b = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0 - 0.5;
	c = floor(c * levels + b * dither_strength + 0.5) / levels;
	c = mix(c, vec3(c.r * 1.25, c.g * 0.35, c.b * 0.3), corruption * 0.5);
	c *= tint * (1.0 - blackout);
	COLOR = vec4(c, 1.0);
}
