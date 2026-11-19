// Rideau (salle de bain, chambre d'amis, chambre de Manon en rendu logiciel) : plis irréguliers en relief,
// avec leurs normales (lot V2-SDB), léger mouvement (un courant d'air qui ne devrait pas exister, la fenêtre
// est fermée), ourlet droit doublé, tissu ou plastique selon les réglages.
// Plan PlaneMesh FACE_Z : VERTEX.x le long de la largeur (m, repère du plan, avant l'échelle du nœud),
// VERTEX.y vers le haut ; UV.y = 0 en haut (la tringle), 1 en bas (l'ourlet).
// Plis : trois sinus (pas de 0,78 / 1,05 / 1,33 × fold_period), pas déformé et amplitude modulée le long
// du pan (aucun pli identique au voisin), plus amples en bas (bottom_gain), froncés sous la tringle
// (top_gain). Les normales et tangentes sont dérivées des plis : la lumière les dessine (plus de faux
// ombrage peint). Creux des plis un peu assombris (cavity, occlusion).
// Réglages par défaut : tissu mat (les rideaux d'avant n'avaient que color et sway).
shader_type spatial;
render_mode cull_disabled;

uniform vec3 color : source_color = vec3(0.29, 0.12, 0.15);
uniform float sway = 0.015;            // amplitude du mouvement (m), au bas du pan
uniform float fold_depth = 0.035;      // profondeur des plis (m) à mi-hauteur
uniform float fold_period = 0.12;      // pas moyen des plis (m, repère du plan)
uniform float bottom_gain = 1.5;       // plis plus amples en bas…
uniform float top_gain = 0.6;          // … froncés sous la tringle
uniform float push = 0.0;              // plis décalés vers l'avant (× amplitude) : un rideau qui pend
                                       // devant une baignoire ne doit pas y entrer
uniform float seed = 0.0;              // phases propres à chaque pan
uniform float height_m = 2.0;          // hauteur du plan (m) : ourlet et moisissure se comptent en mètres
uniform float hem_m = 0.035;           // ourlet doublé (m)
uniform float roughness_v : hint_range(0.0, 1.0) = 0.9;
uniform float spec = 0.3;
uniform float backlight_k = 0.0;       // plastique fin ou voile : la lumière d'en face passe
uniform float rim_k = 0.0;             // velours : lisière claire sous la lumière rasante
uniform float rim_tint_k = 0.5;
uniform float cavity = 0.35;           // occlusion au creux des plis
uniform float mold = 0.0;              // moisissure dans le bas (rideau de douche)
uniform float mold_m = 0.15;           // hauteur de la bande (m)
uniform vec3 mold_color : source_color = vec3(0.07, 0.075, 0.05);
uniform sampler2D crinkle_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float crinkle = 0.0;           // froissures fines (carte de normales)
uniform vec2 crinkle_scale = vec2(6.0, 7.0);

varying float v_fold;    // -1 creux … +1 crête (vers l'avant du plan)
varying vec2 v_pos;      // position dans le plan (m)

void vertex() {
	float x = VERTEX.x;
	float t = clamp(UV.y, 0.0, 1.0);
	float s = seed * 7.13;
	// pas irrégulier : x déformé (dw/dx entre 0,46 et 1,54, toujours croissant)
	float kw = TAU / (2.9 * fold_period);
	float aw = 0.25 * fold_period;
	float w = x + aw * sin(kw * x + s);
	float dw = 1.0 + aw * kw * cos(kw * x + s);
	// amplitude modulée le long du pan
	float km = TAU / (4.3 * fold_period);
	float m = 1.0 + 0.35 * sin(km * x + s * 1.7);
	float dm = 0.35 * km * cos(km * x + s * 1.7);
	vec3 k = TAU / (fold_period * vec3(0.78, 1.05, 1.33));
	vec3 a = vec3(0.5, 0.33, 0.22);
	vec3 ph = vec3(0.0, 2.1, 4.4) + s * vec3(1.0, 2.3, 0.6);
	vec3 arg = k * w + ph;
	float f = dot(a, sin(arg));
	float df = dot(a * k, cos(arg)) * dw;
	float shape = m * f;
	float dshape = dm * f + m * df;
	// profil vertical : froncé en haut, ample en bas
	float ease = t * t * (3.0 - 2.0 * t);
	float amp = fold_depth * mix(top_gain, bottom_gain, ease);
	float damp_dt = fold_depth * (bottom_gain - top_gain) * 6.0 * t * (1.0 - t);
	// courant d'air : surtout le bas bouge
	float tt = pow(t, 1.5);
	float ph_d = TIME * 0.7 + VERTEX.y * 2.0 + s;
	float across = 0.75 + 0.25 * sin(TIME * 0.31 + x * 1.3 + s);
	float drift = sin(ph_d) * sway * tt * across;
	float ddrift_dx = sin(ph_d) * sway * tt * 0.25 * cos(TIME * 0.31 + x * 1.3 + s) * 1.3;
	float ddrift_dt = sin(ph_d) * sway * 1.5 * sqrt(t) * across;
	float d = amp * (shape + push) + drift;
	// dérivées (repère du plan) ; t descend quand y monte : dt/dy = -1 / hauteur
	float dt_dy = -1.0 / max(height_m, 0.1);
	float dd_dx = amp * dshape + ddrift_dx;
	float dd_dy = (damp_dt * (shape + push) + ddrift_dt) * dt_dy + cos(ph_d) * 2.0 * sway * tt * across;
	VERTEX.z += d;
	NORMAL = normalize(vec3(-dd_dx, -dd_dy, 1.0));
	TANGENT = normalize(vec3(1.0, 0.0, dd_dx));
	BINORMAL = normalize(cross(NORMAL, TANGENT));
	v_fold = clamp(shape / 0.9, -1.0, 1.0);
	v_pos = VERTEX.xy;
}

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float t = clamp(UV.y, 0.0, 1.0);
	float up = (1.0 - t) * height_m;              // hauteur au-dessus de l'ourlet (m)
	vec3 c = color;
	float rough = roughness_v;
	float bl = backlight_k;
	// ourlet doublé : un peu plus sombre et plus opaque, une couture
	float hem = 1.0 - smoothstep(hem_m - 0.002, hem_m + 0.002, up);
	float seam = 1.0 - smoothstep(0.0, 0.0018, abs(up - hem_m));
	c *= mix(1.0, 0.9, hem) * (1.0 - 0.18 * seam);
	bl *= mix(1.0, 0.45, hem);
	// moisissure : piqûres noires, plus denses au ras du bas et dans les creux (l'eau y reste)
	if (mold > 0.0) {
		float band = 1.0 - smoothstep(0.0, mold_m, up);
		band *= mix(1.0, 1.35, clamp(-v_fold, 0.0, 1.0));
		float n = vnoise(v_pos * 70.0 + seed) * 0.55 + vnoise(v_pos * 18.0 - seed) * 0.45;
		float spots = smoothstep(0.62, 0.8, n * (0.55 + 0.75 * band)) * clamp(band, 0.0, 1.0);
		float stain = band * band * 0.22;
		float mk = clamp((spots * 0.8 + stain) * mold, 0.0, 0.85);
		c = mix(c, mold_color, mk);
		rough = mix(rough, 0.85, mk);
		bl *= 1.0 - mk;
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = spec;
	BACKLIGHT = c * bl;
	RIM = rim_k;
	RIM_TINT = rim_tint_k;
	AO = 1.0 - cavity * smoothstep(-0.15, -0.95, v_fold);
	AO_LIGHT_AFFECT = 0.3;
	NORMAL_MAP = texture(crinkle_tex, UV * crinkle_scale).xyz;
	NORMAL_MAP_DEPTH = crinkle;
}
