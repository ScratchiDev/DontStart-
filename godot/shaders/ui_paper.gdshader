shader_type canvas_item;
// Feuille de papier des documents (lot V3-INTERFACE, style net) : grain et relief de Paper001 / Paper002
// (ambientCG, CC0, déjà livrées), teinte crème, bords jaunis, pli horizontal, lumière douce venue du haut à
// gauche. Interface 2D seulement : quelques lectures de texture sur la surface de la feuille.

uniform sampler2D albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 sheet_px = vec2(190.0, 250.0);   // taille de la feuille (pixels logiques)
uniform float tile_px = 210.0;                // une répétition de la texture
uniform vec4 tint : source_color = vec4(0.96, 0.93, 0.85, 1.0);
uniform float age = 0.35;                     // jaunissement
uniform float fold_y = 0.37;                  // pli (fraction de la hauteur)
uniform float relief = 0.55;

void fragment() {
	vec2 uv = UV * sheet_px / tile_px;
	vec3 a = texture(albedo, uv).rgb;
	float l = dot(a, vec3(0.3333));
	vec3 base = tint.rgb * (0.86 + 0.2 * l);
	vec3 n = texture(normal_map, uv).rgb * 2.0 - 1.0;
	float lit = clamp(1.0 + relief * 0.35 * dot(n.xy, normalize(vec2(-0.55, 0.75))), 0.8, 1.12);
	float fall = 1.04 - 0.16 * distance(UV, vec2(0.2, 0.1));
	float e = min(min(UV.x, 1.0 - UV.x) * sheet_px.x, min(UV.y, 1.0 - UV.y) * sheet_px.y);
	float edge = 1.0 - smoothstep(0.0, 16.0, e);
	vec3 c = mix(base, base * vec3(0.92, 0.84, 0.68), clamp(edge * age * 1.6 + age * 0.12, 0.0, 1.0));
	float dy = (UV.y - fold_y) * sheet_px.y;
	float crest = exp(-dy * dy / 2.0);
	float shade = smoothstep(0.0, 2.0, dy) * exp(-max(dy, 0.0) / 9.0);
	c *= 1.0 + 0.05 * crest - 0.07 * shade;
	COLOR = vec4(c * lit * fall, 1.0);
}
