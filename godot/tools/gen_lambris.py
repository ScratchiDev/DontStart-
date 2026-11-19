"""gen_lambris.py TEXTURES_DIR OUT_DIR : textures du lot V2-RETOUCHES (œuvres dérivées de textures CC0 du projet :
Wood027 d'ambientCG, herringbone_parquet et l'ORM v2 du parquet de V2-NUIT, CC0 ; le résultat est CC0).
 - Lambris/Lambris_{albedo,normal_gl,orm}.jpg : lambris de lames verticales à joint en V, 8 lames par
   répétition (1024 px), fil vertical (Wood027 tourné d'un quart), une teinte et un fil par lame, lames
   à peine bombées, vernis satiné (rugosité 0,4 à 0,62, pores plus mats ; un facteur par pièce dans le jeu), joints sombres et mats ;
 - Lambris/LambrisPeint_{albedo,normal_gl,orm}.jpg : les mêmes lames peintes (blanc cassé, teinté dans
   le jeu), traces de pinceau, fil du bois qui transparaît, joints encrassés, quelques éclats ;
 - Lambris/Panneau_{albedo,normal_gl,orm}.jpg : Wood027 tourné d'un quart (fil vertical), vernis satiné,
   pour les panneaux et les moulures du lambris à cadres ;
 - herringbone_parquet/herringbone_parquet_orm_v3.jpg : rugosité des lames de 0,6 à 0,82 (au-dessus du
   seuil de 0,6 où Godot coupe la réflexion en espace écran), joints et pores à 0,9 ;
 - Carpet016/moquette_var2.png : variation de la moquette (couche de détail multipliée) : ±12 %, taches de
   poils couchés à deux échelles, périodique, 512 px.
Usage : python3 -I gen_lambris.py godot/assets/textures OUT_DIR   (déterministe : graines fixes)."""
import os
import sys

import numpy as np
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
N = 1024


def load(p, mode='RGB'):
    return np.asarray(Image.open(os.path.join(src, p)).convert(mode), np.float32) / 255.0


def save(a, p, q=92):
    path = os.path.join(out, p)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    a = np.clip(a * 255 + 0.5, 0, 255).astype(np.uint8)
    im = Image.fromarray(a, 'L' if a.ndim == 2 else 'RGB')
    if p.endswith('.png'):
        im.save(path, optimize=True)
    else:
        im.save(path, quality=q, subsampling=0 if 'normal' in p or 'orm' in p else 2)
    print('écrit', p, os.path.getsize(path) // 1024, 'Ko')


def blur(a, s):
    """Flou gaussien périodique (FFT)."""
    if s <= 0.05:
        return a
    h, w = a.shape[:2]
    g = np.exp(-2 * (np.pi * s) ** 2 * (np.fft.fftfreq(h)[:, None] ** 2 + np.fft.fftfreq(w)[None, :] ** 2))
    if a.ndim == 2:
        return np.real(np.fft.ifft2(np.fft.fft2(a) * g)).astype(np.float32)
    return np.stack([np.real(np.fft.ifft2(np.fft.fft2(a[..., c]) * g)) for c in range(a.shape[2])], -1).astype(np.float32)


def lowfreq(h, w, s, seed, sx=1.0, sy=1.0):
    r = np.random.default_rng(seed).standard_normal((h, w))
    if sx != 1.0 or sy != 1.0:
        ky = np.fft.fftfreq(h)[:, None] * sy
        kx = np.fft.fftfreq(w)[None, :] * sx
        g = np.exp(-2 * (np.pi * s) ** 2 * (kx ** 2 + ky ** 2))
        o = np.real(np.fft.ifft2(np.fft.fft2(r) * g))
    else:
        o = blur(r, s)
    return (o / (o.std() + 1e-9)).astype(np.float32)


def lum(a):
    return a @ np.array([0.2126, 0.7152, 0.0722], np.float32)


def normal_from_height(h, k=1.0):
    """Carte de normales OpenGL (vert vers le haut) d'une hauteur en px (y de l'image vers le bas)."""
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    n = np.stack([-gx * k, gy * k, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


rng = np.random.default_rng(3120)
wood = np.rot90(load('Wood027/Wood027_albedo.jpg'), 1).copy()     # fil vertical
wood_l = lum(wood)

# ------------------------------------------------------------------ lames (8 par répétition)
NB = 8
BW = N // NB
CH = 5.0            # chanfrein du joint en V (px de chaque côté : 4 mm à 0,84 m la répétition)
GAP = 1.2           # fond du joint (px)
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
lx = (xx % BW) + 0.5
edge = np.minimum(lx, BW - lx)                                  # distance au bord de la lame (px)
board = (xx // BW).astype(int)
alb = np.zeros((N, N, 3), np.float32)
grain = np.zeros((N, N), np.float32)
tone = rng.normal(0, 0.07, NB)
hue = rng.normal(0, 0.025, NB)
rgh = rng.normal(0, 0.035, NB)
for i in range(NB):
    ox = int(rng.integers(0, N - BW))
    oy = int(rng.integers(0, N))
    if i % 3 == 2:                                              # une lame sur trois : fil retourné
        piece = np.roll(wood[:, ox:ox + BW][:, ::-1], oy, 0)
    else:
        piece = np.roll(wood[:, ox:ox + BW], oy, 0)
    t = 1.0 + tone[i]
    alb[:, i * BW:(i + 1) * BW] = piece * t * np.array([1 + hue[i], 1.0, 1 - hue[i]], np.float32)
    gl = lum(piece)
    grain[:, i * BW:(i + 1) * BW] = gl - blur(gl, 6.0)
# joint en V : chanfreins plus sombres (bois de bout, crasse), fond très sombre
cham = np.clip(1.0 - edge / CH, 0, 1)
gapm = np.clip(1.0 - (edge - 0.3) / GAP, 0, 1)
alb_lames = alb * (1 - 0.22 * cham ** 1.5)[..., None] * (1 - 0.7 * gapm)[..., None]
alb_lames = np.clip(alb_lames, 0, 1)
# relief : chanfrein à 45°, fond du joint, lames bombées de 1,2 px, pores
cup = 1.2 * (1 - ((lx / BW) * 2 - 1) ** 2)
hgt = np.minimum(edge, CH) - 1.5 * gapm + cup + 0.5 * np.clip(-grain * 6, -1, 1)
nrm_lames = normal_from_height(hgt, 1.0)
ao = np.clip(1 - 0.75 * gapm - 0.18 * cham, 0, 1) * (0.97 + 0.03 * np.clip(1 + grain * 5, 0, 1))
rough = 0.47 + rgh[board] + 0.16 * np.clip(-grain * 8, 0, 1)
rough = np.clip(rough, 0.38, 0.7)
rough = rough * (1 - cham) + 0.62 * cham
rough = rough * (1 - gapm) + 0.88 * gapm
orm_lames = np.stack([ao, rough, np.zeros_like(ao)], -1)
save(alb_lames, 'Lambris/Lambris_albedo.jpg')
save(nrm_lames, 'Lambris/Lambris_normal_gl.jpg')
save(orm_lames, 'Lambris/Lambris_orm.jpg')
print('lames : albédo moyen', alb_lames.reshape(-1, 3).mean(0).round(3), 'rugosité moyenne %.3f' % rough.mean())

# ------------------------------------------------------------------ lames peintes
brush = lowfreq(N, N, 0.9, 11, sx=0.2, sy=16.0)                 # traces de pinceau (verticales)
brush2 = lowfreq(N, N, 18, 12)
paint = np.array([0.88, 0.865, 0.83], np.float32)[None, None, :] * (1 + 0.018 * brush + 0.02 * brush2)[..., None]
paint = paint * (1 + 0.05 * np.clip(grain * 4, -1, 1))[..., None]          # le fil transparaît
# éclats : la peinture partie, le bois dessous (près des joints surtout)
chips = np.zeros((N, N), np.float32)
from PIL import ImageDraw
cim = Image.new('L', (N * 2, N * 2), 0)
cd = ImageDraw.Draw(cim)
for k in range(46):
    b = int(rng.integers(0, NB))
    side = rng.choice([-1, 1])
    x0 = (b * BW + (BW if side > 0 else 0)) - side * rng.uniform(1, 14)
    y0 = rng.uniform(0, N)
    rx, ry = rng.uniform(1.0, 4.5), rng.uniform(1.5, 9.0)
    pts = [(2 * (x0 + rx * np.cos(a) * rng.uniform(0.6, 1.2)), 2 * (y0 + ry * np.sin(a) * rng.uniform(0.6, 1.2)))
           for a in np.linspace(0, 2 * np.pi, 9, endpoint=False)]
    cd.polygon(pts, fill=255)
chips = np.asarray(cim.resize((N, N), Image.BOX), np.float32) / 255.0
chips = np.maximum(chips, np.roll(chips, N, 1))
dirt = np.array([0.42, 0.37, 0.3], np.float32)
alb_p = paint * (1 - chips[..., None]) + alb * 0.85 * chips[..., None]
alb_p = alb_p * (1 - 0.14 * cham ** 1.2)[..., None]
alb_p = alb_p * (1 - gapm[..., None]) + dirt * 0.55 * gapm[..., None]
hgt_p = blur(np.minimum(edge, CH) - 1.5 * gapm, 1.1) + cup + 0.07 * brush + 0.12 * np.clip(-grain * 6, -1, 1) - 0.7 * chips
nrm_p = normal_from_height(hgt_p, 1.0)
rough_p = np.clip(0.5 + 0.03 * brush + 0.02 * brush2, 0.4, 0.62)
rough_p = rough_p * (1 - chips) + 0.72 * chips
rough_p = rough_p * (1 - gapm) + 0.85 * gapm
orm_p = np.stack([ao, rough_p, np.zeros_like(ao)], -1)
save(alb_p, 'Lambris/LambrisPeint_albedo.jpg')
save(nrm_p, 'Lambris/LambrisPeint_normal_gl.jpg')
save(orm_p, 'Lambris/LambrisPeint_orm.jpg')
print('peint : albédo moyen', alb_p.reshape(-1, 3).mean(0).round(3), 'rugosité moyenne %.3f' % rough_p.mean())

# ------------------------------------------------------------------ panneaux (Wood027 tourné, vernis)
wn = np.rot90(load('Wood027/Wood027_normal_gl.jpg'), 1).copy()
# (rotation d'un quart dans le sens direct : le vecteur (x, y) devient (-y, x))
wn = np.stack([1.0 - wn[..., 1], wn[..., 0], wn[..., 2]], -1)
wo = np.rot90(load('Wood027/Wood027_orm.jpg'), 1).copy()
pr = np.clip(0.45 + (wo[..., 1] - 0.486) * 1.0 + 0.1 * np.clip(-(wood_l - blur(wood_l, 6.0)) * 8, 0, 1), 0.34, 0.68)
save(wood, 'Lambris/Panneau_albedo.jpg')
save(wn, 'Lambris/Panneau_normal_gl.jpg')
save(np.stack([wo[..., 0], pr, np.zeros_like(pr)], -1), 'Lambris/Panneau_orm.jpg')
print('panneau : rugosité moyenne %.3f' % pr.mean())

# ------------------------------------------------------------------ parquet : rugosité des lames >= 0,6
o2 = load('herringbone_parquet/herringbone_parquet_orm_v2.jpg')
g = o2[..., 1]
joint = np.clip((g - 0.82) / 0.06, 0, 1)                         # joints et pores (0,9 dans la v2)
lam = 0.6 + (np.clip(g, 0.53, 0.8) - 0.53) * (0.82 - 0.6) / (0.8 - 0.53)
g3 = lam * (1 - joint) + 0.9 * joint
save(np.stack([o2[..., 0], g3, np.zeros_like(g3)], -1), 'herringbone_parquet/herringbone_parquet_orm_v3.jpg')
print('parquet v3 : rugosité moyenne %.3f, p1 %.3f, p50 %.3f' % (g3.mean(), np.percentile(g3, 1), np.percentile(g3, 50)))

# ------------------------------------------------------------------ moquette : poils couchés
n = 512
v = 0.9 + 0.05 * np.clip(lowfreq(n, n, 40, 21), -2, 2) + 0.035 * np.clip(lowfreq(n, n, 9, 22, sx=0.5, sy=1.6), -2, 2) \
    + 0.012 * lowfreq(n, n, 2.5, 23)
v = np.clip(v, 0.74, 1.0)
save(v, 'Carpet016/moquette_var2.png')
print('moquette v2 : moyenne %.3f, p2 %.3f, p98 %.3f' % (v.mean(), np.percentile(v, 2), np.percentile(v, 98)))
