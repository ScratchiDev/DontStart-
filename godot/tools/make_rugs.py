"""Motifs des vrais tapis de la maison (Builder._woven_rug) : godot/assets/textures/rugs/.

Usage : python3 -I godot/tools/make_rugs.py            (tout)
        python3 -I godot/tools/make_rugs.py oriental   (aussi : geometrique, frise, bain, franges)
Dépendances : numpy, Pillow. Aucune source extérieure : tout est dessiné ici (CC0, comme le projet).

Chaque motif est un PNG RGBA posé une fois sur tout le tapis (UV 0 à 1, u le long du grand côté) :
  - RGB : la couleur des laines, en sRGB, telle que la verra le jeu (le tissage de Fabric045 n'y ajoute
    que sa normale et son occlusion, en couche de détail : pas de facteur de couleur caché) ;
  - A   : la rugosité (0,86 à 0,92 pour la laine, +0,1 où le velours est usé, au centre et au passage).
L'usure éclaircit aussi la couleur d'environ 8 % (laine écrasée, trame qui apparaît, couleurs passées).
  rug_oriental.png    1024 × 640   chambre de la mère (2,4 × 1,5 m) : tapis noué, médaillon, écoinçons,
                                   bordure à rosettes, abrash (bandes de laine d'un autre bain de teinture)
  rug_frise.png       1024 × 616   chambre des grands-parents (2,0 × 1,2 m) : champ vieux rose à treillis,
                                   bordure à grecque (frise de méandres), rosettes aux coins
  rug_geometrique.png 1024 × 768   bureau d'Albert (2,0 × 1,5 m) : moquette tuftée de 1975, arcs de cercle
                                   (pavage de Truchet) orange, moutarde et crème sur chocolat
  rug_bain.png         768 × 768   salle de bain (rond, 0,9 m) : chenille gris-bleu, anneaux, festons
  rug_franges.png      256 × 128   franges (cartes découpées) : 10 cm de bord sur 5 cm de long, raccordable
                                   en u ; alpha = fil (Builder les découpe à 0,45)
Les fichiers .import (compression VRAM, mipmaps) sont écrits à côté s'ils manquent ; ensuite :
  godot --headless --path godot --import
Le hasard est local (numpy, graine fixe) : le jeu ne tire rien de plus.
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
OUT = os.path.join(ROOT, 'assets', 'textures', 'rugs')

IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=false
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


def C(r, g, b):
    return np.array([r, g, b], dtype=np.float32)


# ------------------------------------------------------------------ bruit et outils

def value_noise(h, w, cell, rng, octaves=1, gain=0.5):
    """Bruit de valeurs lissé (0 à 1), cellules de « cell » pixels ; raccordable sur les bords."""
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        c = max(2, int(cell / (2 ** o)))
        gh, gw = max(2, h // c + 2), max(2, w // c + 2)
        g = rng.random((gh, gw)).astype(np.float32)
        im = Image.fromarray((g * 255).astype(np.uint8)).resize((gw * c, gh * c), Image.BICUBIC)
        a = np.asarray(im, np.float32)[:h, :w] / 255.0
        out += a * amp
        tot += amp
        amp *= gain
    return out / tot


def smooth(x, e0, e1):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def paint(img, mask, color, alpha=1.0):
    """Pose une couleur là où mask (booléen ou 0..1) est vrai."""
    m = mask.astype(np.float32) * alpha
    img[...] = img * (1.0 - m[..., None]) + color[None, None, :] * m[..., None]


def lum(img):
    return 0.2126 * img[..., 0] + 0.7152 * img[..., 1] + 0.0722 * img[..., 2]


def grid(h, w):
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    return u + 0.5, v + 0.5


def rosette(du, dv, r, petals, depth=0.35, rot=0.0):
    """Disque festonné (fleur) de rayon r : masque booléen."""
    rr = np.hypot(du, dv)
    th = np.arctan2(dv, du) + rot
    return rr < r * (1.0 - depth + depth * np.abs(np.cos(th * petals / 2.0)))


def wool(img, rng, amount=0.05, hue=0.02):
    """Grain des nœuds : chaque nœud (≈ 1 pixel) a sa nuance ; fils plus ou moins clairs."""
    h, w, _ = img.shape
    n = rng.normal(0.0, amount, (h, w)).astype(np.float32)
    hn = rng.normal(0.0, hue, (h, w, 3)).astype(np.float32)
    img *= (1.0 + n)[..., None]
    img += hn * img
    return img


def finish(img, wear, rough_base, rng, rough_noise=0.03, lighten=0.08):
    """Usure (éclaircit d'environ 8 %, désature, rugosité +0,1) ; alpha = rugosité ; image 8 bits RGBA."""
    h, w, _ = img.shape
    g = lum(img)[..., None]
    worn = img * (1.0 - 0.3 * wear[..., None]) + g * 0.3 * wear[..., None]
    worn *= (1.0 + lighten * wear)[..., None]
    rough = rough_base + rough_noise * (value_noise(h, w, 24, rng) - 0.5) * 2.0 + 0.1 * wear
    rgba = np.concatenate([np.clip(worn, 0, 1), np.clip(rough, 0, 1)[..., None]], axis=2)
    return Image.fromarray((rgba * 255.0 + 0.5).astype(np.uint8), 'RGBA')


def wear_mask(h, w, rng, cx=0.5, cy=0.5, rx=0.36, ry=0.34, path=None, strength=1.0):
    """Usure : une ellipse au centre (bords nets mais irréguliers), plus un passage facultatif
    (path = (v_centre, demi-largeur) : une bande dans la longueur, là où l'on marche)."""
    u, v = grid(h, w)
    u /= w
    v /= h
    d = np.hypot((u - cx) / rx, (v - cy) / ry)
    m = 1.0 - smooth(d, 0.35, 1.0)
    if path is not None:
        pv, ph = path
        m = np.maximum(m, 0.8 * (1.0 - smooth(np.abs(v - pv), ph * 0.4, ph)) * smooth(u, 0.0, 0.25) * (1.0 - smooth(u, 0.75, 1.0)))
    n = value_noise(h, w, 40, rng, octaves=3)
    m = np.clip(m * (0.55 + 0.9 * n), 0.0, 1.0)
    return (m * strength).astype(np.float32)


def stains(img, rng, n, color, rmin, rmax, alpha=0.18):
    """Quelques taches anciennes (thé, café), plus sombres sur leur bord."""
    h, w, _ = img.shape
    u, v = grid(h, w)
    for _ in range(n):
        cx, cy = rng.uniform(0.2, 0.8) * w, rng.uniform(0.25, 0.75) * h
        r = rng.uniform(rmin, rmax)
        dd = np.hypot((u - cx) / r, (v - cy) / (r * rng.uniform(0.7, 1.0)))
        wob = value_noise(h, w, 18, rng) * 0.35
        body = 1.0 - smooth(dd + wob, 0.75, 1.0)
        ring = np.exp(-((dd + wob - 0.95) / 0.06) ** 2)
        a = np.clip(body * 0.6 + ring, 0, 1) * alpha
        paint(img, a, color)


def binding(img, edge, color, width=2.0):
    """Surjet du bord : les derniers pixels, plus sombres (le chant du tapis les montre)."""
    m = 1.0 - smooth(edge, width - 0.5, width + 0.5)
    paint(img, m, color)


# ------------------------------------------------------------------ tapis noué (chambre de la mère)

def oriental(rng):
    W, H = 1024, 640                       # 2,4 × 1,5 m : 2,34 mm par pixel (≈ un nœud)
    red = C(0.37, 0.085, 0.075)
    red_dk = C(0.27, 0.06, 0.055)
    navy = C(0.085, 0.10, 0.19)
    ivory = C(0.72, 0.65, 0.50)
    gold = C(0.62, 0.45, 0.17)
    rose = C(0.58, 0.27, 0.22)
    green = C(0.19, 0.30, 0.24)
    ink = C(0.07, 0.045, 0.035)
    u, v = grid(H, W)
    img = np.empty((H, W, 3), np.float32)
    img[...] = red
    edge = np.minimum(np.minimum(u, W - u), np.minimum(v, H - v))
    # abrash : bandes de laine d'un autre bain de teinture, en travers du tapis (le long de u)
    band = value_noise(1, W, 70, rng, octaves=2)[0]
    band = (band - band.mean()) * 0.22
    img *= (1.0 + band)[None, :, None]
    # ---- bordures (de l'extérieur vers l'intérieur) : garde, bordure principale, garde
    g0, g1, b0, b1, i0, i1 = 3.0, 15.0, 17.0, 79.0, 81.0, 93.0
    paint(img, (edge >= g0) & (edge < g1), ivory)
    # garde extérieure : dents alternées rouges et bleues (« trèfles réciproques » simplifiés)
    s = np.where(np.minimum(u, W - u) < np.minimum(v, H - v), v, u)   # abscisse le long du bord
    t = edge - g0                                                      # profondeur dans la garde
    tooth = (np.abs(((s / 12.0) % 1.0) - 0.5) * 2.0) * 9.0 > t
    alt = (np.floor(s / 12.0) % 2) == 0
    gm = (edge >= g0 + 1.5) & (edge < g1 - 1.5)
    paint(img, gm & tooth & alt, red)
    paint(img, gm & tooth & ~alt, navy)
    paint(img, (np.abs(edge - g0) < 1.0) | (np.abs(edge - g1) < 1.0) | (np.abs(edge - b1) < 1.0) | (np.abs(edge - i1) < 1.0), ink)
    # bordure principale : fond bleu nuit, rinceau doré, rosettes et palmettes alternées
    main = (edge >= g1 + 1.0) & (edge < b1 - 1.0)
    paint(img, main, navy)
    bw = b1 - g1
    tb = (edge - g1) / bw                          # 0 (extérieur) à 1 (intérieur)
    period = 64.0
    vine = np.abs(tb - (0.5 + 0.28 * np.sin(s / period * 2.0 * np.pi))) < 0.045
    paint(img, main & vine, gold)
    k = np.round(s / period)
    ds = s - k * period
    dt = (tb - 0.5) * bw
    big = (k % 2) == 0
    paint(img, main & big & rosette(ds, dt, 21.0, 8, 0.32), ivory)
    paint(img, main & big & rosette(ds, dt, 15.0, 8, 0.3, 0.4), rose)
    paint(img, main & big & (np.hypot(ds, dt) < 6.0), gold)
    paint(img, main & big & (np.hypot(ds, dt) < 2.5), ink)
    # palmette (entre deux rosettes) : un losange festonné, rouge sur bleu
    pal = (np.abs(ds) / 13.0 + np.abs(dt) / 20.0) < 1.0
    paint(img, main & ~big & pal, red)
    paint(img, main & ~big & ((np.abs(ds) / 7.0 + np.abs(dt) / 11.0) < 1.0), ivory)
    paint(img, main & ~big & ((np.abs(ds) / 3.0 + np.abs(dt) / 5.0) < 1.0), green)
    # coins de la bordure : une rosette (le motif tourne au coin)
    for cu in (g1 + bw / 2.0, W - g1 - bw / 2.0):
        for cv in (g1 + bw / 2.0, H - g1 - bw / 2.0):
            du, dv = u - cu, v - cv
            cm = main & (np.abs(du) < bw / 2.0) & (np.abs(dv) < bw / 2.0)
            paint(img, cm, navy)
            paint(img, cm & rosette(du, dv, 24.0, 8, 0.3), ivory)
            paint(img, cm & rosette(du, dv, 16.0, 8, 0.3, 0.4), red)
            paint(img, cm & (np.hypot(du, dv) < 6.0), gold)
    # garde intérieure : fond or, petit motif en S rouge
    inner = (edge >= b1 + 1.0) & (edge < i1 - 1.0)
    paint(img, inner, gold)
    ss = (s / 10.0) % 1.0
    ti = (edge - b1) / (i1 - b1)
    paint(img, inner & (np.abs(ti - 0.5 - 0.25 * np.sin(ss * 2 * np.pi)) < 0.14), red_dk)
    # ---- champ : semis de petits motifs, écoinçons, médaillon central
    field = edge >= i1 + 1.0
    fu, fv = u - W / 2.0, v - H / 2.0
    # treillis « hérati » : losanges en filet rouge sombre, une fleur à chaque nœud (4 couleurs), une paire
    # de feuilles au cœur de chaque maille, semés sur tout le champ (sous le médaillon et les écoinçons)
    pu, pv = 40.0, 27.0
    a = fu / pu + fv / pv
    b = fu / pu - fv / pv
    da = np.abs(a - np.round(a))
    db = np.abs(b - np.round(b))
    paint(img, field & (np.minimum(da, db) < 0.045), red_dk)
    na, nb = np.round(a), np.round(b)
    du = fu - (na + nb) / 2.0 * pu
    dv = fv - (na - nb) / 2.0 * pv
    pick = ((na * 3 + nb * 5) % 4).astype(np.int32)
    flower = rosette(du, dv, 7.5, 6, 0.42)
    for kk, col_c in enumerate((ivory, gold, rose, C(0.26, 0.40, 0.44))):
        paint(img, field & flower & (pick == kk), col_c)
    paint(img, field & (np.hypot(du, dv) < 2.0), ink)
    ca, cb = np.floor(a) + 0.5, np.floor(b) + 0.5
    du2 = fu - (ca + cb) / 2.0 * pu
    dv2 = fv - (ca - cb) / 2.0 * pv
    lr = (((du2 - dv2 * 0.4) / 6.5) ** 2 + ((dv2 + du2 * 0.25) / 2.4) ** 2) < 1.0
    paint(img, field & lr, green)
    paint(img, field & (np.hypot(du2, dv2) < 1.6), gold)
    # médaillon central : losange à gradins, bleu nuit, bande ivoire, cœur rouge, étoile or
    md = np.abs(fu) / 250.0 + np.abs(fv) / 160.0
    step = np.abs(fu) / 250.0 + np.floor(np.abs(fv) / 8.0) * 8.0 / 160.0     # gradins (nœuds en escalier)
    med = field & (step < 1.0)
    paint(img, med, navy)
    paint(img, field & (np.abs(step - 0.97) < 0.03), ivory)
    paint(img, field & (md < 0.78), ivory)
    paint(img, field & (md < 0.72), red)
    # dans le cœur rouge : huit rosettes sur une couronne, reliées par un filet or
    paint(img, field & (np.abs(md - 0.5) < 0.012), gold)
    for k in range(8):
        ang = k * np.pi / 4.0
        ru, rv = 250.0 * 0.5 * np.cos(ang) / (np.abs(np.cos(ang)) + np.abs(np.sin(ang))), \
            160.0 * 0.5 * np.sin(ang) / (np.abs(np.cos(ang)) + np.abs(np.sin(ang)))
        paint(img, field & rosette(fu - ru, fv - rv, 12.0, 6, 0.4), ivory if k % 2 == 0 else gold)
        paint(img, field & rosette(fu - ru, fv - rv, 5.5, 6, 0.3), rose if k % 2 == 0 else red_dk)
    paint(img, field & (np.abs(md - 0.86) < 0.025), gold)
    star = rosette(fu, fv, 46.0, 8, 0.55)
    paint(img, field & star, navy)
    paint(img, field & rosette(fu, fv, 30.0, 8, 0.4, 0.39), ivory)
    paint(img, field & (np.hypot(fu, fv) < 11.0), red_dk)
    # pendentifs aux deux bouts du médaillon (dans la longueur)
    for sgn in (-1.0, 1.0):
        pu = fu - sgn * 300.0
        pmask = field & ((np.abs(pu) / 38.0 + np.abs(fv) / 30.0) < 1.0)
        paint(img, pmask, navy)
        paint(img, field & ((np.abs(pu) / 22.0 + np.abs(fv) / 17.0) < 1.0), gold)
        paint(img, field & ((np.abs(pu) / 9.0 + np.abs(fv) / 7.0) < 1.0), red)
        stem = field & (np.abs(fv) < 2.0) & (sgn * fu > 250.0) & (sgn * fu < 262.0)
        paint(img, stem, ivory)
    # écoinçons : quarts de losange bleu nuit dans les coins du champ, fleurs ivoire
    for cu in (i1, W - i1):
        for cv in (i1, H - i1):
            du, dv = np.abs(u - cu), np.abs(v - cv)
            q = field & ((du / 150.0 + dv / 100.0) < 1.0)
            paint(img, q, navy)
            paint(img, field & (np.abs(du / 150.0 + dv / 100.0 - 0.96) < 0.03), ivory)
            fl = rosette(du - 46.0, dv - 30.0, 13.0, 6, 0.35)
            paint(img, q & fl, ivory)
            paint(img, q & rosette(du - 46.0, dv - 30.0, 6.0, 6, 0.3), rose)
            paint(img, q & rosette(du - 95.0, dv - 12.0, 8.0, 4, 0.4), gold)
            paint(img, q & rosette(du - 14.0, dv - 62.0, 8.0, 4, 0.4), gold)
    # ---- laine, usure, taches, surjet
    img = wool(img, rng, 0.055, 0.025)
    wear = wear_mask(H, W, rng, 0.52, 0.5, 0.42, 0.36, path=(0.55, 0.22))
    # usure plus marquée au médaillon : la trame claire apparaît par endroits (lignes de chaîne)
    warp = ((np.floor(u) % 3) == 0) & (rng.random((H, W)) < 0.22 * wear ** 3)
    paint(img, warp, C(0.70, 0.64, 0.54), 0.35)
    stains(img, rng, 2, C(0.16, 0.08, 0.05), 28, 46, 0.22)
    binding(img, edge, C(0.11, 0.05, 0.04), 2.5)
    return finish(img, wear, 0.88, rng)


# ------------------------------------------------------------------ bordure à grecque (grands-parents)

def greek_key(s, t, unit):
    """Méandre (grecque) dans une bande : s le long du bord, t depuis l'extérieur (pixels).
    Période 8 unités, hauteur 7 : une ligne de base et un crochet en spirale par période."""
    x = (s / unit) % 8.0
    y = 7.0 - t / unit                  # y vers l'intérieur décroît : la ligne de base est à l'extérieur
    ink = np.zeros_like(s, dtype=bool)
    # segments [x0, x1] × [y0, y1] en unités, épaisseur 1 (centrée sur la ligne médiane)
    segs = [
        (0.0, 8.0, 0.5, 0.5),           # ligne de base
        (0.5, 0.5, 0.5, 6.5),           # montée
        (0.5, 6.5, 6.5, 6.5),           # dessus
        (6.5, 6.5, 2.5, 6.5),           # descente à droite
        (2.5, 6.5, 2.5, 2.5),           # retour vers la gauche
        (2.5, 2.5, 2.5, 4.5),           # remontée intérieure
        (2.5, 4.5, 4.5, 4.5),           # crochet final
    ]
    yy = y - 0.0
    for x0, x1, y0, y1 in segs:
        ax0, ax1 = min(x0, x1) - 0.5, max(x0, x1) + 0.5
        ay0, ay1 = min(y0, y1) - 0.5, max(y0, y1) + 0.5
        ink |= (x >= ax0) & (x < ax1) & (yy >= ay0) & (yy < ay1)
    return ink


def frise(rng):
    W, H = 1024, 616                       # 2,0 × 1,2 m : 1,95 mm par pixel
    field_c = C(0.44, 0.30, 0.26)
    trellis_c = C(0.36, 0.235, 0.205)
    dark = C(0.19, 0.115, 0.085)
    cream = C(0.70, 0.60, 0.45)
    gold = C(0.56, 0.42, 0.21)
    rose = C(0.58, 0.31, 0.29)
    sage = C(0.38, 0.42, 0.32)
    u, v = grid(H, W)
    img = np.empty((H, W, 3), np.float32)
    img[...] = field_c
    edge = np.minimum(np.minimum(u, W - u), np.minimum(v, H - v))
    band = value_noise(1, W, 90, rng, octaves=2)[0]
    img *= (1.0 + (band - band.mean()) * 0.14)[None, :, None]
    unit = 6.0
    b0, b1 = 4.0, 4.0 + 9.0 * unit         # bande de la grecque : 9 unités (marges comprises)
    s = np.where(np.minimum(u, W - u) < np.minimum(v, H - v), v, u)
    kb = (edge >= b0) & (edge < b1)
    paint(img, edge < b1, dark)
    paint(img, (np.abs(edge - b0 - 1.5) < 1.0) | (np.abs(edge - b1 + 1.5) < 1.0), gold)
    # la grecque (dans les 7 unités du milieu) ; aux coins, un carré à rosette
    t = edge - b0 - unit
    corner = (np.minimum(u, W - u) < b1) & (np.minimum(v, H - v) < b1)
    key = greek_key(s - b1, t, unit) & (t >= 0.0) & (t < 7.0 * unit)
    paint(img, kb & key & ~corner, cream)
    for cu in (b1 / 2.0 + b0 / 2.0, W - b1 / 2.0 - b0 / 2.0):
        for cv in (b1 / 2.0 + b0 / 2.0, H - b1 / 2.0 - b0 / 2.0):
            du, dv = u - cu, v - cv
            paint(img, corner & rosette(du, dv, 21.0, 8, 0.3), cream)
            paint(img, corner & rosette(du, dv, 13.0, 8, 0.3, 0.39), rose)
            paint(img, corner & (np.hypot(du, dv) < 4.0), gold)
    # garde intérieure : filet or, puis petites perles crème
    g0 = b1 + 2.0
    paint(img, np.abs(edge - g0 - 1.0) < 1.0, gold)
    pearls = (np.abs(edge - g0 - 7.0) < 3.2) & ((s % 12.0) > 3.0) & ((s % 12.0) < 9.0)
    paint(img, pearls, cream * 0.9)
    paint(img, np.abs(edge - g0 - 13.0) < 1.0, gold * 0.8)
    field = edge >= g0 + 15.0
    # champ : treillis de losanges ton sur ton, une fleur à chaque nœud, un bouton au centre de chaque maille
    fu, fv = u - W / 2.0, v - H / 2.0
    pu, pv = 64.0, 44.0
    a = (fu / pu + fv / pv)
    b = (fu / pu - fv / pv)
    da = np.abs(a - np.round(a))
    db = np.abs(b - np.round(b))
    lines = (np.minimum(da, db) < 0.035)
    paint(img, field & lines, trellis_c)
    # nœuds du treillis : là où a et b sont entiers ensemble
    na, nb = np.round(a), np.round(b)
    cu_n = (na + nb) / 2.0 * pu
    cv_n = (na - nb) / 2.0 * pv
    du, dv = fu - cu_n, fv - cv_n
    node = (np.abs(da) < 0.5) & (np.abs(db) < 0.5)
    fl = rosette(du, dv, 9.0, 5, 0.45)
    alt = ((na + nb) % 2) == 0
    paint(img, field & node & fl & alt, rose)
    paint(img, field & node & fl & ~alt, cream * 0.92)
    paint(img, field & node & (np.hypot(du, dv) < 2.6), gold)
    # boutons (centres des mailles) : deux feuilles vert-de-gris
    ca = np.floor(a) + 0.5
    cb = np.floor(b) + 0.5
    cu_c = (ca + cb) / 2.0 * pu
    cv_c = (ca - cb) / 2.0 * pv
    du2, dv2 = fu - cu_c, fv - cv_c
    leaf = ((du2 / 7.0) ** 2 + (dv2 / 2.6) ** 2 < 1.0)
    paint(img, field & leaf, sage)
    paint(img, field & (np.hypot(du2, dv2) < 2.2), rose * 0.9)
    # médaillon ovale discret au centre : couronne de feuilles crème
    ov = np.hypot(fu / 150.0, fv / 92.0)
    paint(img, field & (ov < 1.0), field_c * 1.05)
    paint(img, field & (np.abs(ov - 1.0) < 0.03), gold)
    th = np.arctan2(fv / 92.0, fu / 150.0)
    wreath = (np.abs(ov - 0.86) < 0.07) & (np.abs(np.sin(th * 14.0)) > 0.35)
    paint(img, field & wreath, sage)
    paint(img, field & (np.abs(ov - 0.86) < 0.07) & (np.abs(np.sin(th * 14.0)) <= 0.35), rose)
    paint(img, field & rosette(fu, fv, 34.0, 8, 0.4), cream)
    paint(img, field & rosette(fu, fv, 20.0, 8, 0.35, 0.39), rose)
    paint(img, field & (np.hypot(fu, fv) < 6.0), gold)
    img = wool(img, rng, 0.05, 0.02)
    # usure : le côté du lit (où l'on pose les pieds le matin) et le passage vers la porte
    wear = wear_mask(H, W, rng, 0.5, 0.42, 0.42, 0.32, path=(0.3, 0.2))
    warp = ((np.floor(u) % 3) == 0) & (rng.random((H, W)) < 0.35 * wear ** 2)
    paint(img, warp, C(0.68, 0.60, 0.50), 0.45)
    stains(img, rng, 3, C(0.20, 0.12, 0.07), 20, 34, 0.2)
    binding(img, edge, C(0.12, 0.07, 0.05), 2.5)
    return finish(img, wear, 0.88, rng)


# ------------------------------------------------------------------ moquette de 1975 (bureau)

def geometrique(rng):
    W, H = 1024, 768                       # 2,0 × 1,5 m : 1,95 mm par pixel
    choc = C(0.235, 0.14, 0.085)
    choc_dk = C(0.15, 0.09, 0.055)
    orange = C(0.56, 0.255, 0.085)
    mustard = C(0.62, 0.47, 0.155)
    cream = C(0.72, 0.64, 0.47)
    u, v = grid(H, W)
    img = np.empty((H, W, 3), np.float32)
    img[...] = choc
    edge = np.minimum(np.minimum(u, W - u), np.minimum(v, H - v))
    B = 58.0
    paint(img, edge < B, choc_dk)
    paint(img, np.abs(edge - B + 12.0) < 2.2, orange)
    paint(img, np.abs(edge - B + 22.0) < 1.2, mustard)
    field = edge >= B
    # pavage de Truchet : dans chaque carreau, deux quarts de cercle centrés sur des coins opposés ;
    # trois bandes concentriques (orange, moutarde, crème) qui se raccordent d'un carreau à l'autre
    T = 64.0
    fu, fv = u - W / 2.0, v - H / 2.0
    cx = np.floor(fu / T)
    cy = np.floor(fv / T)
    lu = fu - cx * T
    lv = fv - cy * T
    # orientation de chaque carreau : tirée une fois (graine fixe), avec un peu d'ordre (motif d'époque)
    nx, ny = int(np.ceil(W / T)) + 2, int(np.ceil(H / T)) + 2
    flip_tab = rng.random((ny, nx)) < 0.5
    for j in range(ny):
        for i in range(nx):
            if (i + j) % 5 == 0:
                flip_tab[j, i] = (i % 2 == 0)
    ix = (cx.astype(np.int32) + nx // 2) % nx
    iy = (cy.astype(np.int32) + ny // 2) % ny
    flip = flip_tab[iy, ix]
    lu2 = np.where(flip, T - lu, lu)
    r1 = np.hypot(lu2, lv)
    r2 = np.hypot(T - lu2, T - lv)
    r = np.minimum(r1, r2)
    for rad, wdt, col in ((T * 0.5, 7.5, orange), (T * 0.5 - 13.0, 2.8, mustard), (T * 0.5 + 13.0, 2.8, mustard),
                          (T * 0.5 - 21.0, 1.8, cream), (T * 0.5 + 21.0, 1.8, cream)):
        a = 1.0 - smooth(np.abs(r - rad), wdt - 0.7, wdt + 0.7)
        paint(img, a * field, col)
    # tuftage : rangées de boucles (fin quadrillage plus sombre), velours ras d'une machine
    rows = ((np.floor(v) % 2) == 0).astype(np.float32) * 0.03
    img *= (1.0 - rows)[..., None]
    img = wool(img, rng, 0.04, 0.012)
    # velours inégal (marbrures de lumière sur le poil couché dans un sens ou l'autre), 50 ans d'âge
    img *= (0.93 + 0.14 * value_noise(H, W, 90, rng, octaves=3))[..., None]
    g = lum(img)[..., None]
    img = (img * 0.82 + g * 0.18) * 0.88
    # couleurs passées par 50 ans de soleil (le côté fenêtre, x = 1 : u élevé) : désaturées
    fade = smooth(u / W, 0.55, 1.0) * 0.25
    g = lum(img)[..., None]
    img = img * (1.0 - fade[..., None]) + g * fade[..., None]
    # usure : la chaise du bureau (côté +z du tapis = v élevé) et le passage porte → bureau
    wear = wear_mask(H, W, rng, 0.55, 0.78, 0.30, 0.22, path=(0.6, 0.18))
    stains(img, rng, 2, C(0.10, 0.06, 0.04), 22, 36, 0.24)
    binding(img, edge, C(0.09, 0.055, 0.035), 2.0)
    return finish(img, wear, 0.9, rng, 0.02, 0.08)


# ------------------------------------------------------------------ tapis de bain rond

def bain(rng):
    N = 768                                # 0,9 m de diamètre : 1,2 mm par pixel
    base = C(0.45, 0.54, 0.56)
    dark = C(0.33, 0.42, 0.45)
    light = C(0.56, 0.64, 0.65)
    cream = C(0.70, 0.70, 0.64)
    u, v = grid(N, N)
    du, dv = u - N / 2.0, v - N / 2.0
    rr = np.hypot(du, dv) / (N / 2.0)
    th = np.arctan2(dv, du)
    img = np.empty((N, N, 3), np.float32)
    img[...] = base
    paint(img, rr > 0.84, dark)
    paint(img, np.abs(rr - 0.80) < 0.012, cream)
    # festons (coquille) : pétales clairs autour du centre, un cœur
    scal = rr < 0.56 * (0.86 + 0.14 * np.abs(np.cos(th * 6.0)))
    paint(img, scal, light)
    paint(img, rr < 0.3 * (0.8 + 0.2 * np.abs(np.cos(th * 6.0 + 0.5))), base)
    paint(img, rr < 0.12, light)
    paint(img, np.abs(rr - 0.68) < 0.008, cream * 0.95)
    # chenille : des « doigts » de coton en quinconce, chacun bombé (plus clair au sommet), creux sombres
    p = 5.0
    row = np.floor(v / p)
    off = np.where(row % 2 == 0, 0.0, p / 2.0)
    lu = (u - off) % p - p / 2.0
    lv = v % p - p / 2.0
    jit = value_noise(N, N, 5, rng) * 0.6
    tuft = np.clip(1.0 - np.hypot(lu, lv) / (p * 0.62) + jit * 0.2, 0.0, 1.0)
    img *= (0.78 + 0.3 * tuft)[..., None]
    img = wool(img, rng, 0.05, 0.015)
    # le centre, où l'on pose les pieds mouillés : grisâtre, aplati ; une auréole d'eau calcaire
    wear = wear_mask(N, N, rng, 0.5, 0.52, 0.3, 0.3)
    stains(img, rng, 2, C(0.40, 0.38, 0.30), 52, 90, 0.12)
    ring = np.exp(-((rr - 0.97) / 0.03) ** 2)
    paint(img, ring, C(0.24, 0.30, 0.33), 0.6)
    return finish(img, wear, 0.9, rng, 0.03, 0.08)


# ------------------------------------------------------------------ franges

def franges(rng):
    W, H = 256, 128                        # 10 cm de bord (u) × 5 cm de frange (v, 0 = côté tapis)
    img = np.zeros((H, W, 4), np.float32)
    u, v = grid(H, W)
    cotton = C(0.86, 0.83, 0.75)
    dirt = C(0.55, 0.50, 0.42)
    # (couleur du coton partout, même là où l'alpha est nul : le filtrage et les mipmaps ne foncent pas les fils)
    img[..., :3] = cotton * 0.8
    # base (sortie des fils de chaîne, serrés) : bande pleine
    base = v < 9.0
    img[base, :3] = cotton * 0.82
    img[base, 3] = 1.0
    # pompons : 10 par 10 cm, 5 fils chacun, noués à 1 cm du tapis, qui s'écartent vers la pointe
    for k in range(10):
        cx = (k + 0.5) * W / 10.0 + rng.uniform(-2.0, 2.0)
        knot_v = rng.uniform(16.0, 22.0)
        for f in range(5):
            tip = rng.uniform(0.78, 0.98) * H
            spread = (f - 2.0) * rng.uniform(1.6, 2.6)
            wave = rng.uniform(0.5, 1.6)
            ph = rng.uniform(0, 6.28)
            shade = rng.uniform(0.82, 1.05)
            # trajectoire : serrée jusqu'au nœud, puis écartée
            t = np.clip((v - knot_v) / (H - knot_v), 0.0, 1.0)
            xc = cx + (f - 2.0) * 1.3 * (1.0 - t) + spread * t * 3.0 + wave * np.sin(v * 0.12 + ph) * t
            d = np.abs(((u - xc + W / 2.0) % W) - W / 2.0)
            m = (d < 1.25) & (v < tip) & (v >= 6.0)
            col = cotton * shade * (1.0 - 0.35 * np.clip((v - 60.0) / 70.0, 0, 1))[..., None] \
                + dirt * 0.35 * np.clip((v - 60.0) / 70.0, 0, 1)[..., None]
            img[m, :3] = col[m]
            img[m, 3] = 1.0
        # le nœud : un renflement
        kn = ((u - cx) / 5.0) ** 2 + ((v - knot_v) / 3.2) ** 2 < 1.0
        img[kn, :3] = cotton * 0.9
        img[kn, 3] = 1.0
    return Image.fromarray((np.clip(img, 0, 1) * 255.0 + 0.5).astype(np.uint8), 'RGBA')


MAKERS = {"oriental": oriental, "frise": frise, "geometrique": geometrique, "bain": bain, "franges": franges}


def main():
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[1:] or list(MAKERS)
    for i, name in enumerate(MAKERS):
        if name not in names:
            continue
        rng = np.random.default_rng(1975 + i)
        im = MAKERS[name](rng)
        path = os.path.join(OUT, "rug_%s.png" % name)
        im.save(path, optimize=True)
        imp = path + ".import"
        if not os.path.exists(imp):
            with open(imp, "w", encoding="utf-8") as f:
                # franges : vraie transparence (bords d'alpha corrigés) ; motifs : alpha = rugosité, intact
                f.write(IMPORT.replace("fix_alpha_border=false", "fix_alpha_border=true") if name == "franges" else IMPORT)
        print("%-40s %s %d Ko" % (os.path.relpath(path, ROOT), im.size, os.path.getsize(path) // 1024))


if __name__ == "__main__":
    main()
