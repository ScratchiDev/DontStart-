// Vitre sous la pluie : gouttes immobiles + gouttes qui glissent en laissant une traînée.
// Les gouttes réfractent l'image de l'extérieur (lecture de l'écran derrière la vitre).
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never, specular_schlick_ggx;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 glass_size = vec2(1.4, 1.25);   // en mètres, pour garder des gouttes rondes
uniform float rain = 1.0;
uniform float flash = 0.0;                   // éclair : la vitre s'illumine
uniform vec3 tint : source_color = vec3(0.78, 0.84, 0.92);

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
vec3 h31(float p) { vec3 p3 = fract(vec3(p) * vec3(0.1031, 0.11369, 0.13787)); p3 += dot(p3, p3.yzx + 19.19); return fract(vec3((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y, (p3.y + p3.z) * p3.x)); }

// renvoie (décalage x, décalage y, masque de goutte)
vec3 sliding(vec2 uv, float t) {
	vec2 a = vec2(6.0, 1.0);
	vec2 grid = a * 2.0;
	vec2 id = floor(uv * grid);
	float colShift = h21(vec2(id.x, 0.0));
	uv.y += colShift;
	id = floor(uv * grid);
	vec3 n = h31(id.x * 35.2 + id.y * 2376.1);
	vec2 st = fract(uv * grid) - vec2(0.5, 0.0);
	float x = n.x - 0.5;
	float y = uv.y * 20.0;
	float wiggle = sin(y + sin(y));
	x += wiggle * (0.5 - abs(x)) * (n.z - 0.5);
	x *= 0.7;
	float ti = fract(t + n.z);
	y = (smoothstep(0.0, 0.85, ti) * smoothstep(1.0, 0.85, ti) - 0.5) * 0.9 + 0.5;
	vec2 p = vec2(x, y);
	float d = length((st - p) * a.yx);
	float drop = smoothstep(0.4, 0.0, d);
	float r = sqrt(smoothstep(1.0, y, st.y));
	float cd = abs(st.x - x);
	float trail = smoothstep(0.23 * r, 0.15 * r * r, cd);
	float trailFront = smoothstep(-0.02, 0.02, st.y - y);
	trail *= trailFront * r * r;
	y = uv.y;
	float trail2 = smoothstep(0.2 * r, 0.0, cd);
	float droplets = max(0.0, (sin(y * (1.0 - y) * 120.0) - st.y)) * trail2 * trailFront * n.z;
	y = fract(y * 10.0) + (st.y - 0.5);
	float dd = length(st - vec2(x, y));
	droplets = smoothstep(0.3, 0.0, dd);
	float m = drop + droplets * r * trailFront;
	return vec3((st - p) * m, m);
}

float static_drops(vec2 uv, float t) {
	uv *= 40.0;
	vec2 id = floor(uv);
	uv = fract(uv) - 0.5;
	vec3 n = h31(id.x * 107.45 + id.y * 3543.654);
	vec2 p = (n.xy - 0.5) * 0.7;
	float d = length(uv - p);
	float fade = smoothstep(0.0, 0.025, fract(t + n.z)) * smoothstep(1.0, 0.025, fract(t + n.z));
	return smoothstep(0.3, 0.0, d) * fract(n.z * 10.0) * fade;
}

void fragment() {
	vec2 uv = UV * glass_size / glass_size.y;
	uv.y = 1.0 - uv.y;
	float t = TIME * 0.18;
	vec3 a = sliding(uv * 0.9, t);
	vec3 b = sliding(uv * 1.35 + 7.31, t * 0.8);
	float s = static_drops(uv, t);
	float mask = clamp(max(a.z, b.z) + s, 0.0, 1.0) * rain;
	vec2 offs = (a.xy + b.xy) * 0.05 * rain + vec2(s * 0.004);
	vec3 bg = textureLod(screen_tex, SCREEN_UV + offs * vec2(1.0, -1.0), mix(0.4, 1.4, mask)).rgb;
	ALBEDO = vec3(0.0);
	EMISSION = bg * tint * (0.92 + 0.25 * mask) + vec3(0.6, 0.7, 0.9) * flash * (0.15 + mask);
	ROUGHNESS = mix(0.45, 0.2, mask);
	SPECULAR = 0.2;
	ALPHA = 1.0;
}
