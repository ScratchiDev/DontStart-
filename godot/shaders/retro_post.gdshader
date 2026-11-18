// Filtre plein écran, réglé par main.gd (_apply_video) selon l'option « Style rétro (pixels) » :
//  - rendu moderne (par défaut) : image à la résolution de l'écran, léger grain de pellicule,
//    vignettage doux, aberration chromatique nulle au repos (vraie carte ; presque nulle en rendu
//    logiciel) ; levels = 0 (pas de palette réduite) ;
//    point noir, épaule étirée jusqu'au blanc (les hautes lumières d'AgX plafonnent vers 0,8 : au-delà
//    du genou, elles montent au blanc ; les tons moyens ne bougent pas), pied de courbe ;
//  - style rétro : image 640×360 agrandie sans lissage, palette réduite (levels = 16) + tramage
//    ordonné (Bayer 4×4), grain, vignettage, aberration chromatique : l'aspect des versions 0.1 à 0.3.
// La peur (corruption, main.gd _on_fear) déchire l'image et écarte les couleurs dans les deux modes ;
// le stress (Game) fait monter le grain (grain × grain_mult).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float levels = 0.0;           // niveaux par canal (0 = palette complète ; 16 = rétro)
uniform float dither_strength = 0.0;  // tramage de Bayer (rétro : 1)
uniform float grain = 0.045;          // grain de base + stress (piloté par Game)
uniform float grain_mult = 0.5;       // part du grain gardée (rétro : 1)
uniform float vignette = 0.55;
uniform float vignette_inner = 0.12;  // où le vignettage commence (rayon² × 1,9) ; rétro : 0,12
uniform float aberration = 0.00015;
uniform float corruption_aberration = 0.0044;  // aberration ajoutée par la corruption (× corruption)
uniform float corruption = 0.0;       // 0..1 : la partie « pourrit » l'image
// rendu net sur vraie carte : l'aberration ne vient qu'au-dessus de ce seuil de corruption, en montée
// quadratique (0 en rétro et en rendu logiciel : la montée linéaire d'avant, à l'identique)
uniform float corruption_floor = 0.0;
uniform float blackout = 0.0;         // 0..1 : fondu au noir
uniform vec3 tint = vec3(1.0);
// rendu net seulement (0 en rétro : l'image d'avant, à l'identique) :
uniform float black_point = 0.0;      // noir relevé par AgX et le brouillard, ramené à 0
uniform float white_point = 1.0;      // valeur qui devient le blanc (1 : rien ne change)
uniform float shoulder_knee = 0.4;    // l'épaule s'étire au-dessus de ce genou (raccord sans cassure)
uniform float toe = 0.0;              // pied de courbe : les basses lumières s'enfoncent (0..1)
uniform float grain_net = 0.0;        // grain de pellicule : taille suivant la résolution, plus fort dans le noir

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
	float ca = corruption;
	if (corruption_floor > 0.0) {
		float ct = max(corruption - corruption_floor, 0.0);
		ca = ct * ct / (1.0 - corruption_floor);
	}
	vec2 off = d * r2 * 40.0 * (aberration + ca * corruption_aberration);
	vec3 c;
	c.r = texture(screen_tex, uv + off).r;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - off).b;
	c *= mix(1.0, smoothstep(0.95, vignette_inner, r2 * 1.9), vignette);
	if (black_point > 0.0) {
		c = max(c - black_point, vec3(0.0)) / (1.0 - black_point);
	}
	if (white_point < 1.0) {
		vec3 t = max(c - shoulder_knee, vec3(0.0));
		c += t * t * (1.0 - white_point) / ((white_point - shoulder_knee) * (white_point - shoulder_knee));
	}
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	if (toe > 0.0) {
		c *= 1.0 - toe * (1.0 - clamp(lum / 0.25, 0.0, 1.0));
	}
	if (grain_net > 0.0) {
		// un grain de 2 px en 1080p (1 px en 540p), plus présent dans les ombres que dans les lumières,
		// mais qui s'efface dans le noir profond (il n'y fait plus de points noirs ni gris)
		float gp = max(1.0, floor(0.5 + 1.0 / (SCREEN_PIXEL_SIZE.y * 540.0)));
		float gw = (0.6 + 0.8 * (1.0 - clamp(lum, 0.0, 1.0))) * smoothstep(0.0, 0.06, lum);
		c += (rnd(floor(FRAGCOORD.xy / gp) + fract(TIME * 7.13) * 97.0) - 0.5) * grain * grain_mult * gw * grain_net;
	} else {
		c += (rnd(FRAGCOORD.xy + fract(TIME * 7.13) * 97.0) - 0.5) * grain * grain_mult;
	}
	if (levels > 0.5) {
		ivec2 p = ivec2(FRAGCOORD.xy) % 4;
		float b = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0 - 0.5;
		c = floor(c * levels + b * dither_strength + 0.5) / levels;
	}
	c = mix(c, vec3(c.r * 1.25, c.g * 0.35, c.b * 0.3), corruption * 0.5);
	c *= tint * (1.0 - blackout);
	COLOR = vec4(c, 1.0);
}
