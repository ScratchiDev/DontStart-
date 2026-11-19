// Vitre sous la pluie, rendu net (lot V2-MAISON ; rain_glass.gdshader reste celui du rétro et du rendu
// logiciel) : mêmes gouttes, mais
//  - pas de brouillard sur la vitre (fog_disabled) : l'image de dehors l'a déjà, le compter deux fois
//    voilait le jardin en panneau laiteux ;
//  - teinte de nuit plus sombre : le jardin garde son noir ;
//  - réfraction plus faible, et qui ne lit jamais ce qui est DEVANT la vitre (montants, appui, rideaux :
//    test de profondeur) : les gouttes près de la croisée faisaient un bourrelet blanc ;
//  - un peu de buée dans les coins et en bas, éclairée par la pièce (la lampe la fait apparaître).
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never, specular_schlick_ggx, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec2 glass_size = vec2(1.4, 1.25);   // en mètres, pour garder des gouttes rondes
uniform float rain = 1.0;
uniform float flash = 0.0;                   // éclair : la vitre s'illumine
uniform vec3 tint : source_color = vec3(0.5, 0.55, 0.64);
uniform float refraction = 0.022;
uniform float frost = 0.32;
uniform vec3 frost_color : source_color = vec3(0.5, 0.53, 0.56);

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
vec3 h31(float p) { vec3 p3 = fract(vec3(p) * vec3(0.1031, 0.11369, 0.13787)); p3 += dot(p3, p3.yzx + 19.19); return fract(vec3((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y, (p3.y + p3.z) * p3.x)); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

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
	vec2 offs = (a.xy + b.xy) * refraction * rain + vec2(s * 0.003);
	vec2 suv = SCREEN_UV + offs * vec2(1.0, -1.0);
	// (profondeur inversée : plus grand = plus près ; ce qui est devant la vitre ne se réfracte pas)
	if (texture(depth_tex, suv).r > FRAGCOORD.z + 0.00001) {
		suv = SCREEN_UV;
	}
	vec3 bg = textureLod(screen_tex, suv, mix(0.3, 1.2, mask)).rgb;
	// bord des gouttes : une goutte d'eau renvoie, sur son pourtour, le sol sombre qu'elle voit à l'envers ;
	// sans ce liseré, sous l'éclair, les gouttes n'étaient que des disques clairs (de la neige)
	float rim = clamp(mask * (1.0 - mask) * 4.0, 0.0, 1.0);
	bg *= 1.0 - 0.25 * rim;
	// buée : coins et bas de la vitre, en taches irrégulières ; les gouttes la traversent
	vec2 m = UV * glass_size;
	vec2 e = min(m, glass_size - m);
	float corner = 1.0 - smoothstep(0.0, 0.3, length(e));
	float low = 1.0 - smoothstep(0.0, 0.12, glass_size.y - m.y);
	float n = vnoise(m * 9.0) * 0.6 + vnoise(m * 31.0) * 0.4;
	// (la buée est dedans, la pluie dehors : les gouttes ne l'essuient qu'à peine ; essuyée en plein, la buée
	// éclairée par la lampe laissait une goutte noire à chaque goutte, des trous dans la vitre)
	float fm = clamp((corner * 0.9 + low * 0.6) * (0.35 + 0.9 * n) - 0.2, 0.0, 1.0) * frost * (1.0 - 0.3 * mask);
	ALBEDO = frost_color * fm;
	// (éclair : c'est le ciel derrière la vitre qui s'allume et découpe les arbres ; la vitre n'en prend qu'un
	// reflet, la buée un peu plus, le cœur des gouttes à peine ; avec un voile uniforme de 0,2 et des gouttes
	// à 0,35, la vitre devenait un panneau laiteux sous une neige blanche)
	EMISSION = bg * tint * (0.92 + 0.25 * mask) * (1.0 - 0.75 * fm) + vec3(0.6, 0.7, 0.9) * flash * (0.05 + 0.12 * mask * (1.0 - rim) + 0.4 * fm);
	// (la vitre reflète un peu la pièce, gouttes comprises : le reflet vient de la face intérieure, que la
	// pluie ne touche pas, d'où une rugosité et un reflet uniformes. Plus rugueuses, les gouttes prenaient
	// chacune une tache du reflet de la lampe (une neige blanche) ; plus lisses, moins réfléchissantes ou
	// avec leur courbure en normale, elles faisaient des trous noirs dans le voile du reflet (des
	// moisissures). On ne les voit donc que par ce qu'elles réfractent du dehors (lampadaire, ciel, éclair).)
	ROUGHNESS = mix(0.3, 0.85, fm);
	SPECULAR = 0.14;
	ALPHA = 1.0;
}
