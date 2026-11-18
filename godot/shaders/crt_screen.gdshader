// Écran du moniteur : affiche le terminal (SubViewport) avec courbure du tube, lignes de balayage,
// lueur et léger scintillement. Non éclairé : c'est l'écran qui éclaire la pièce.
// Rendu net (room.gd, set_screen_glow_style) : le phosphore sort au-dessus de 1 (hdr_gain) pour que le
// halo de l'image le fasse irradier, un peu de halation (la lumière qui bave dans le verre autour des
// lettres), et des lignes de balayage qui s'effacent quand elles deviendraient plus fines qu'un pixel
// (sinon du moiré). Rétro : exactement l'écran d'avant (hdr_gain 1, halation 0, scan_aa 0).
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D screen : source_color, filter_linear;
uniform float brightness = 1.45;
uniform float curvature = 0.12;
uniform float power_on = 1.0;     // 0 = éteint (noir), 1 = allumé
uniform float glitch = 0.0;
uniform float collapse = 0.0;    // extinction du tube : l'image s'écrase en une ligne puis un point
uniform float bright_line = 0.0; // éclat de la ligne pendant l'extinction
uniform vec3 phosphor = vec3(0.36, 1.0, 0.42);
// fond du tube et vignette (room.gd, set_screen_glow_style : en rendu net, tube presque noir et coins
// seulement assombris ; en rétro, les valeurs d'avant)
uniform float base_glow = 0.035;
uniform float vig_outer = 0.62;
uniform float vig_inner = 0.18;
// rendu net : gain HDR (brightness reste entre 0,45 et 1,45, comme l'écrivent la séance et la convocation),
// halation, et fondu des lignes de balayage selon leur taille à l'écran (0 : lignes d'avant, sans fondu)
uniform float hdr_gain = 1.0;
uniform float halation = 0.0;
uniform float scan_aa = 0.0;

float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

vec3 tap(vec2 p) {
	if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) {
		return vec3(0.0);
	}
	return texture(screen, p).rgb;
}

void fragment() {
	vec2 uv = UV - 0.5;
	uv *= 1.0 + curvature * dot(uv, uv);
	// extinction : l'image s'écrase verticalement (0 → 0,7), puis horizontalement (0,7 → 1)
	float sy = max(0.004, 1.0 - smoothstep(0.0, 0.7, collapse));
	float sx = max(0.002, 1.0 - smoothstep(0.7, 1.0, collapse));
	float in_band = step(abs(uv.y), sy * 0.5) * step(abs(uv.x), sx * 0.5);
	uv = vec2(uv.x / sx, uv.y / sy);
	uv += 0.5;
	uv.x += (rnd(vec2(floor(uv.y * 60.0), floor(TIME * 20.0))) - 0.5) * 0.03 * glitch;
	vec3 c = tap(uv);
	// halation : un flou large autour des lettres (8 points sur deux couronnes), ajouté sous l'image
	if (halation > 0.0) {
		vec3 h = vec3(0.0);
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398 + 0.39;
			vec2 o = vec2(cos(a), sin(a) * 1.333);
			h += tap(uv + o * 0.006) + tap(uv + o * 0.014) * 0.6;
		}
		c += h / 12.8 * halation;
	}
	float wave = sin(uv.y * 480.0 * 3.14159);
	float scan = 0.78 + 0.22 * wave;
	if (scan_aa > 0.0) {
		// une ligne de balayage plus fine que ~1,5 pixel : elle s'efface (même luminosité moyenne)
		float lines = fwidth(uv.y * 240.0);
		scan = 0.78 + 0.22 * wave * (1.0 - scan_aa * smoothstep(0.25, 0.6, lines));
	}
	vec2 d = uv - 0.5;
	float vig = smoothstep(vig_outer, vig_inner, dot(d, d) * 2.0);
	float flicker = 0.96 + 0.04 * sin(TIME * 60.0) + (rnd(vec2(TIME)) - 0.5) * 0.03;
	// fond du tube allumé : jamais complètement noir
	vec3 base = phosphor * base_glow;
	vec3 col = (c * scan + base) * vig * flicker * brightness * hdr_gain * power_on;
	col = mix(col, vec3(1.0) * 2.5 * power_on, bright_line * smoothstep(0.5, 0.9, collapse));
	ALBEDO = col * in_band;
}
