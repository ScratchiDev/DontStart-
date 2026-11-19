// Arbres nus dans le vent : le tronc tient, les branches hautes ploient et frémissent.
// Vraie carte (lot V2-MAISON, use_bark) : écorce bark_brown_02 projetée en triplanaire dans le monde (position
// d'avant le vent : l'écorce ne glisse pas), relief par sa carte de normales, rugosité mouillée, et un
// contre-jour du lampadaire sur les bords (rim_*). Rendu logiciel : la couleur unie d'avant.
shader_type spatial;

uniform vec3 color : source_color = vec3(0.06, 0.055, 0.05);
uniform float base_y = -2.8;
uniform float height = 9.0;
uniform float wind = 1.0;
uniform bool use_bark = false;
uniform sampler2D bark_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D bark_normal : filter_linear_mipmap, repeat_enable;   // (importée en BC5 : x et y seulement)
uniform sampler2D bark_orm : filter_linear_mipmap, repeat_enable;
uniform vec3 bark_tint : source_color = vec3(0.5, 0.5, 0.5);
uniform float bark_scale = 1.25;          // répétitions par mètre
uniform float wet_roughness = 0.6;
uniform vec3 rim_pos = vec3(-8.9, 2.2, 2.6);   // le lampadaire
uniform vec3 rim_color : source_color = vec3(1.0, 0.58, 0.26);
uniform float rim_k = 0.0;

varying vec3 w_rest;
varying vec3 n_rest;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_rest = w;
	n_rest = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float k = clamp((w.y - base_y) / height, 0.0, 1.0);
	k = k * k;
	float gust = 0.6 + 0.4 * sin(TIME * 0.31 + w.x * 0.05);
	float sway = sin(TIME * 1.1 + w.x * 0.3 + w.z * 0.2) * 0.35 + sin(TIME * 2.7 + w.y * 1.3) * 0.08;
	VERTEX.x += sway * k * wind * gust;
	VERTEX.z += cos(TIME * 0.9 + w.z * 0.4) * 0.18 * k * wind * gust;
}

void fragment() {
	if (!use_bark) {
		ALBEDO = color;
		ROUGHNESS = 0.9;
	} else {
		vec3 nw = normalize(n_rest);
		vec3 bw = pow(abs(nw), vec3(4.0));
		bw /= (bw.x + bw.y + bw.z);
		vec2 ux = w_rest.zy * bark_scale;
		vec2 uy = w_rest.xz * bark_scale;
		vec2 uz = w_rest.xy * bark_scale;
		vec3 alb = texture(bark_albedo, ux).rgb * bw.x + texture(bark_albedo, uy).rgb * bw.y + texture(bark_albedo, uz).rgb * bw.z;
		vec3 orm = texture(bark_orm, ux).rgb * bw.x + texture(bark_orm, uy).rgb * bw.y + texture(bark_orm, uz).rgb * bw.z;
		// (cartes de normales en triplanaire, mélange « whiteout »)
		vec3 tx = vec3(texture(bark_normal, ux).xy * 2.0 - 1.0, 0.0);
		vec3 ty = vec3(texture(bark_normal, uy).xy * 2.0 - 1.0, 0.0);
		vec3 tz = vec3(texture(bark_normal, uz).xy * 2.0 - 1.0, 0.0);
		tx.z = sqrt(max(0.0, 1.0 - dot(tx.xy, tx.xy)));
		ty.z = sqrt(max(0.0, 1.0 - dot(ty.xy, ty.xy)));
		tz.z = sqrt(max(0.0, 1.0 - dot(tz.xy, tz.xy)));
		tx = vec3(tx.xy + nw.zy, abs(tx.z) * nw.x);
		ty = vec3(ty.xy + nw.xz, abs(ty.z) * nw.y);
		tz = vec3(tz.xy + nw.xy, abs(tz.z) * nw.z);
		vec3 n = normalize(tx.zyx * bw.x + ty.xzy * bw.y + tz.xyz * bw.z);
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
		ALBEDO = alb * bark_tint;
		AO = orm.r;
		ROUGHNESS = clamp(orm.g * wet_roughness * 1.2, 0.25, 0.85);
		// contre-jour : le lampadaire derrière l'arbre allume ses bords
		vec3 v = normalize(CAMERA_POSITION_WORLD - w_rest);
		vec3 ld = rim_pos - w_rest;
		float dist = length(ld);
		ld /= dist;
		float back = pow(max(dot(-v, ld), 0.0), 2.0);
		float edge = pow(1.0 - max(dot(n, v), 0.0), 3.0);
		EMISSION = rim_color * rim_k * back * edge / (1.0 + dist * dist * 0.08);
	}
}
