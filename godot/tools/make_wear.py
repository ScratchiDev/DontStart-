#!/usr/bin/env python3
"""Bibliothèque d'usure de Don't Play (lot V1-USURE) : décalques générés et masques de crasse HD.

À lancer en mode isolé (numpy et PIL seulement), depuis n'importe où :
    python3 -I godot/tools/make_wear.py                       tout
    python3 -I godot/tools/make_wear.py fissure empreinte     seulement ces genres
    python3 -I godot/tools/make_wear.py --planche <fichier>   et une planche de contrôle (PNG)
Puis l'import sans rendu : godot --headless --path godot --import

Tout est calculé ici, à partir de bruit fractal (synthèse spectrale), de champs de distance et de
tracés : aucune photo, aucune personne (les traces de pieds sont des formes abstraites). Résultat
déterministe (graines fixes). Écrit dans godot/assets/decals/gen/ (avec les .import) :

  Décalques (lus par scripts/wear.gd, Wear.decal) : <nom>_albedo.png (RGBA, sRGB : couleur et masque),
  <nom>_normal.png (normale OpenGL, vert = haut de l'image ; seulement s'il y a du relief) et
  <nom>_orm.png (R = occlusion, G = rugosité, B = métal). Godot mélange la normale et l'ORM d'un
  décalque selon l'alpha de l'albédo, et la couleur selon alpha × albedo_mix : une tache peut changer la
  rugosité sans changer la couleur (albedo_mix bas). Le haut de l'image va vers « up » (Wear.decal).
    tache_plafond_1..4   1024²      auréoles d'eau : bords de dépôt, cernes successifs, point de goutte
    moisissure_1..2      1024²      colonies de points noirs, satellites, voile gris-vert, auréole
                                    d'humidité ; 1 : bande le long du bord haut (jonction mur-plafond,
                                    plus fournie à gauche) ; 2 : colonie ronde
    fissure_1..3         1024×512   fissures de plâtre (sillon en relief, éclats de peinture)
    suie_1..2            512²       1 : halo au plafond au-dessus d'une ampoule ; 2 : panache sur un mur
    chemin_usure_1..2    512×1024   usure de passage (v = le long du chemin) : couleur presque blanche,
                                    teintée par Wear selon le sol ; mate
    empreinte_1..6       256×512    pieds nus, orteils en haut ; impairs = pied gauche, pairs = droit ;
                                    rugosité 0,2 (mouillé)
    crasse_pied_mur_1..3 1024×128   bande de pied de mur (0,22 m, Wear.wall_base) : crasse juste au-dessus
                                    de la plinthe de 11 cm (moitié basse de l'image), poussière sur la
                                    plinthe et dans l'angle du sol ; PÉRIODIQUE en u (les tronçons d'un même
                                    mur se raccordent sans couture)
    coin_1               512²       crasse d'angle (projetée en diagonale dans un coin de plafond)
  Décalques ambientCG adoucis : acg/<Id>_albedo.png, copie de ../acg/<Id>_albedo.png (lot V1-ASSETS)
    dont l'alpha s'éteint vers les bords (contour irrégulier) : ces motifs sont faits pour se répéter, et
    leur bord droit se voyait. Normale et ORM restent ceux de ../acg/ (mélangés selon cet alpha).
  Masques de crasse HD (Surfaces) : grime_hd_1..3.png, 1024², niveaux de gris, PÉRIODIQUES (posés en
    triplanaire), même moyenne (en lumière linéaire) que textures/grime.png qu'ils remplacent :
    1 = plâtre (marbrures, auréoles, pores), 2 = patine (bois, meubles : traces grasses, poussière),
    3 = peinture (portes, boiseries : rayures fines, éclats).

Import : décalques en WebP avec perte (compress/mode=1 : l'atlas des décalques de Godot est de toute
façon en RGBA8 non compressé ; c'est le format le plus léger dans le pck), masques en sans perte
(mode 0 : ils restent en L8, 1 octet par pixel en mémoire vidéo), tous avec mipmaps.
"""

import argparse
import io
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(HERE)
OUT = os.path.join(GODOT, "assets", "decals", "gen")
ACG = os.path.join(GODOT, "assets", "decals", "acg")
GRIME_OLD = os.path.join(GODOT, "assets", "textures", "grime.png")


# ------------------------------------------------------------------ outils

def sstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def spectral(h, w, beta, seed, kmin=0.0, kmax=0.5, ax=1.0, ay=1.0):
    """Bruit fractal périodique (h × w), moyenne 0, écart-type 1 : spectre en k^(-beta/2), k en cycles
    par pixel (ax, ay < 1 : motifs plus longs le long de cet axe, en pixels... inversement : un poids
    fort sur un axe y raccourcit les variations, donc allonge les motifs le long de cet axe)."""
    rng = np.random.default_rng(seed)
    white = rng.standard_normal((h, w))
    fy = np.fft.fftfreq(h)[:, None] * ay
    fx = np.fft.rfftfreq(w)[None, :] * ax
    k = np.sqrt(fx * fx + fy * fy)
    k[0, 0] = 1.0
    amp = k ** (-beta / 2.0)
    amp[k < kmin] = 0.0
    amp[k > kmax] = 0.0
    amp[0, 0] = 0.0
    n = np.fft.irfft2(np.fft.rfft2(white) * amp, s=(h, w))
    n -= n.mean()
    return n / (n.std() + 1e-9)


def blur(a, s, wrap=False):
    """Flou gaussien (écart-type s pixels), par FFT ; bords prolongés (wrap = False) ou périodiques."""
    if s <= 0:
        return a
    h, w = a.shape
    p = 0 if wrap else int(3 * s) + 2
    b = np.pad(a, p, mode="edge") if p else a
    hh, ww = b.shape
    fy = np.fft.fftfreq(hh)[:, None]
    fx = np.fft.rfftfreq(ww)[None, :]
    g = np.exp(-2.0 * (np.pi * s) ** 2 * (fx * fx + fy * fy))
    r = np.fft.irfft2(np.fft.rfft2(b) * g, s=(hh, ww))
    return r[p:p + h, p:p + w] if p else r


def sample(img, x, y, wrap=True):
    """Lecture bilinéaire de img aux coordonnées (x, y) en pixels."""
    h, w = img.shape
    if wrap:
        x = np.mod(x, w)
        y = np.mod(y, h)
    else:
        x = np.clip(x, 0, w - 1.001)
        y = np.clip(y, 0, h - 1.001)
    x0 = np.floor(x).astype(np.int64)
    y0 = np.floor(y).astype(np.int64)
    fx = x - x0
    fy = y - y0
    x1 = (x0 + 1) % w if wrap else np.minimum(x0 + 1, w - 1)
    y1 = (y0 + 1) % h if wrap else np.minimum(y0 + 1, h - 1)
    x0 %= w
    y0 %= h
    return (img[y0, x0] * (1 - fx) * (1 - fy) + img[y0, x1] * fx * (1 - fy)
            + img[y1, x0] * (1 - fx) * fy + img[y1, x1] * fx * fy)


def grid(h, w):
    """Coordonnées normalisées : X de 0 à 1 (largeur), Y de 0 (haut) à 1 (bas), au centre des pixels."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    return (xx + 0.5) / w, (yy + 0.5) / h


def over(layers, h, w):
    """Superpose des couches (couleur sRGB, alpha) ; rend (couleur non prémultipliée, alpha)."""
    c = np.zeros((h, w, 3))
    a = np.zeros((h, w))
    for col, al in layers:
        col = np.broadcast_to(np.asarray(col, np.float64), (h, w, 3)) if np.ndim(col) < 3 else col
        al = np.clip(al, 0.0, 1.0)
        c = col * al[..., None] + c * (1.0 - al[..., None])
        a = al + a * (1.0 - al)
    rgb = c / np.maximum(a, 1e-6)[..., None]
    # pixels transparents : la couleur moyenne de la tache (pas de liseré sombre dans les mipmaps)
    m = a > 0.02
    if m.any():
        mean = rgb[m].mean(axis=0)
        rgb[~m] = mean
    return rgb, a


def to8(a):
    return (np.clip(a, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)


def edge_fade(h, w, margin, seed, keep=(), amount=0.035):
    """Masque qui s'éteint vers les bords sur « margin » (fraction), avec un contour irrégulier ; keep :
    côtés gardés pleins ("top", "bottom", "left", "right")."""
    x, y = grid(h, w)
    n = spectral(h, w, 2.6, seed, kmin=1.0 / max(h, w)) * amount
    m = np.ones((h, w))
    sides = {"left": x, "right": 1.0 - x, "top": y, "bottom": 1.0 - y}
    for side, d in sides.items():
        if side in keep:
            continue
        mx = margin * (1.0 if side in ("left", "right") else w / h if h < w else 1.0)
        m *= sstep(0.0, max(mx, 1e-3), d + n - 0.01)
    return m


def normal_map(height, strength):
    """Normale OpenGL (vert = haut de l'image) d'un champ de hauteur (en pixels de pente × strength)."""
    dy, dx = np.gradient(height)
    nx = -dx * strength
    ny = dy * strength
    nz = np.ones_like(height)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.dstack([nx / ln * 0.5 + 0.5, ny / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5])


def save_png(im, path):
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    data = buf.getvalue()
    if os.path.exists(path):
        with open(path, "rb") as f:
            if f.read() == data:
                return
    with open(path, "wb") as f:
        f.write(data)


IMPORT_TMPL = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=%(mode)d
compress/high_quality=false
compress/lossy_quality=%(q)s
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=%(normal)d
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


def write_import(path, mode, normal=False, q="0.85"):
    """.import d'une image : écrit seulement s'il n'existe pas ou si ses réglages ont changé (Godot y
    ajoute ensuite uid et chemins ; ils sont gardés)."""
    imp = path + ".import"
    want = {"compress/mode": str(mode), "compress/normal_map": "1" if normal else "0",
            "compress/lossy_quality": q, "mipmaps/generate": "true", "detect_3d/compress_to": "0"}
    if os.path.exists(imp):
        with open(imp, encoding="utf-8") as f:
            txt = f.read()
        cur = dict(l.split("=", 1) for l in txt.splitlines() if "=" in l and not l.startswith("["))
        if all(cur.get(k) == v for k, v in want.items()):
            return
        lines = []
        for l in txt.splitlines():
            k = l.split("=", 1)[0]
            lines.append("%s=%s" % (k, want[k]) if "=" in l and k in want else l)
        txt = "\n".join(lines) + "\n"
    else:
        txt = IMPORT_TMPL % {"mode": mode, "normal": 1 if normal else 0, "q": q}
    with open(imp, "w", encoding="utf-8") as f:
        f.write(txt)


def _half(arr, k):
    """Réduit une carte (h × w × c, 0 à 1) d'un facteur k (moyenne par blocs)."""
    if k <= 1:
        return arr
    h, w = arr.shape[:2]
    return arr[:h - h % k, :w - w % k].reshape(h // k, k, w // k, k, -1).mean(axis=(1, 3))


def save_decal(name, rgb, alpha, height=None, strength=1.0, ao=None, rough=0.9, metal=0.0, aux=1):
    """Écrit <name>_albedo.png, _orm.png et (si height) _normal.png dans gen/, avec leurs .import.
    aux = 2 : normale et ORM à demi-résolution (le décalque lit chaque carte avec les mêmes UV, quelle
    que soit sa taille ; relief et rugosité doux n'ont pas besoin de la pleine résolution)."""
    h, w = alpha.shape
    base = os.path.join(OUT, name)
    rgba = np.dstack([to8(rgb[..., 0]), to8(rgb[..., 1]), to8(rgb[..., 2]), to8(alpha)])
    save_png(Image.fromarray(rgba, "RGBA"), base + "_albedo.png")
    write_import(base + "_albedo.png", 1)
    ao = np.ones((h, w)) if ao is None else np.broadcast_to(ao, (h, w))
    rough = np.broadcast_to(np.asarray(rough, np.float64), (h, w))
    metal = np.broadcast_to(np.asarray(metal, np.float64), (h, w))
    orm = _half(np.dstack([ao, rough, metal]), aux)
    save_png(Image.fromarray(to8(orm), "RGB"), base + "_orm.png")
    write_import(base + "_orm.png", 1)
    nrm = base + "_normal.png"
    if height is not None:
        n = _half(normal_map(height, strength) * 2.0 - 1.0, aux)
        n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
        save_png(Image.fromarray(to8(n * 0.5 + 0.5), "RGB"), nrm)
        write_import(nrm, 1, normal=True, q="0.9")
    else:
        for p in (nrm, nrm + ".import"):
            if os.path.exists(p):
                os.remove(p)
    print("  %-22s %4d × %-4d%s" % (name, w, h, "  (relief)" if height is not None else ""))


def ellipse_field(x, y, cx, cy, rx, ry, ang=0.0):
    """1 au centre, 0 sur le bord, négatif dehors (distance normalisée)."""
    c, s = np.cos(ang), np.sin(ang)
    dx = x - cx
    dy = y - cy
    u = (dx * c + dy * s) / rx
    v = (-dx * s + dy * c) / ry
    return 1.0 - np.sqrt(u * u + v * v)


def capsule_field(x, y, ax_, ay_, bx, by, r):
    px, py = x - ax_, y - ay_
    vx, vy = bx - ax_, by - ay_
    t = np.clip((px * vx + py * vy) / (vx * vx + vy * vy), 0.0, 1.0)
    dx = px - vx * t
    dy = py - vy * t
    return 1.0 - np.sqrt(dx * dx + dy * dy) / r


def smax(a, b, k=0.08):
    """Maximum adouci (union de formes sans arête)."""
    h = np.clip(0.5 + 0.5 * (a - b) / k, 0.0, 1.0)
    return b * (1 - h) + a * h + k * h * (1 - h)


# ------------------------------------------------------------------ taches d'eau au plafond

# (centre x, y, rayons, angle, poids) par variante, en unités de l'image ; niveaux des cernes
STAIN_SHAPES = {
    1: {"blobs": [(0.5, 0.52, 0.36, 0.31, 0.3)], "levels": [0.0, 0.16, 0.34, 0.55], "drip": (0.47, 0.5)},
    2: {"blobs": [(0.5, 0.5, 0.44, 0.15, -0.35), (0.3, 0.6, 0.16, 0.12, 0.0)], "levels": [0.0, 0.2, 0.42], "drip": None},
    3: {"blobs": [(0.36, 0.42, 0.22, 0.2, 0.0), (0.62, 0.6, 0.25, 0.21, 0.6), (0.52, 0.3, 0.13, 0.12, 0.0)],
        "levels": [0.0, 0.22, 0.45], "drip": (0.62, 0.6)},
    4: {"blobs": [(0.5, 0.5, 0.42, 0.38, 1.1)], "levels": [0.0, 0.1, 0.24, 0.4, 0.6], "drip": None, "old": True},
}


def tache_plafond(v, S=1024):
    spec = STAIN_SHAPES[v]
    seed = 1000 + v * 17
    x, y = grid(S, S)
    # coordonnées tordues : un contour de flaque (grands lobes), pas une ellipse
    wx = spectral(S, S, 3.6, seed + 1, kmin=1.0 / S) * 0.05
    wy = spectral(S, S, 3.6, seed + 2, kmin=1.0 / S) * 0.05
    X, Y = x + wx, y + wy
    f = None
    for (cx, cy, rx, ry, ang) in spec["blobs"]:
        e = ellipse_field(X, Y, cx, cy, rx, ry, ang)
        f = e if f is None else smax(f, e, 0.1)
    # lobes moyens et légère dentelure du bord (l'eau suit les fibres du plâtre)
    f = f + 0.03 * spectral(S, S, 3.4, seed + 3, kmin=3.0 / S) + 0.0035 * spectral(S, S, 2.0, seed + 4, kmin=24.0 / S)
    old = spec.get("old", False)
    layers = []
    fill_n = 0.5 + 0.5 * np.tanh(spectral(S, S, 2.6, seed + 5, kmin=2.0 / S))
    inside0 = sstep(-0.003, 0.003, f)
    # fond de la tache : jaunissement léger et marbré
    layers.append(((0.56, 0.47, 0.3), inside0 * (0.12 + 0.16 * fill_n) * (0.65 if old else 1.0)))
    height = np.zeros((S, S))
    ring_total = np.zeros((S, S))
    for k, lv in enumerate(spec["levels"]):
        ins = sstep(lv - 0.003, lv + 0.003, f)
        if k > 0:
            # chaque crue plus petite fonce un peu l'intérieur
            layers.append(((0.5, 0.4, 0.24), ins * (0.06 + 0.07 * fill_n)))
        d = np.maximum(f - lv, 0.0)
        sharp = 0.011 * (1.8 if old else 1.0)
        bleed = 0.07 * (1.5 if old else 1.0)
        # le dépôt n'est pas régulier le long du bord
        mod = 0.5 + 0.5 * sstep(-1.0, 0.8, spectral(S, S, 2.4, seed + 20 + k, kmin=3.0 / S))
        strength = [1.0, 0.75, 0.85, 0.6, 0.5][k % 5] * (0.55 if old else 1.0)
        line = ins * np.exp(-d / sharp) * mod * strength
        halo = ins * np.exp(-d / bleed) * mod * strength
        ring_total = np.maximum(ring_total, line)
        layers.append(((0.42, 0.31, 0.16), halo * 0.34))
        layers.append(((0.26, 0.17, 0.08) if k == 0 else (0.31, 0.21, 0.1), line * 0.9))
        height += line * 0.8 + halo * 0.1
    if spec["drip"]:
        dx, dy = spec["drip"]
        r = np.sqrt((X - dx) ** 2 + (Y - dy) ** 2) + 0.006 * spectral(S, S, 2.6, seed + 30, kmin=6.0 / S)
        spot = sstep(0.04, 0.012, r)
        ring = np.exp(-((r - 0.042) / 0.006) ** 2)
        layers.append(((0.4, 0.29, 0.14), spot * 0.4))
        layers.append(((0.3, 0.2, 0.09), ring * 0.6))
        height += ring * 0.5
    if old:
        # vieille tache : quelques points de moisissure au centre
        dots = sstep(2.4, 3.1, spectral(S, S, 0.8, seed + 40, kmin=40.0 / S)) * sstep(0.25, 0.5, f)
        layers.append(((0.12, 0.12, 0.09), dots * 0.8))
    # cloquage léger de la peinture dans la zone mouillée
    bub = sstep(0.8, 2.0, spectral(S, S, 1.8, seed + 50, kmin=16.0 / S)) * inside0
    height += bub * 0.3
    rgb, a = over(layers, S, S)
    a *= edge_fade(S, S, 0.04, seed + 60)
    rough = 0.9 - 0.16 * ring_total
    ao = 1.0 - 0.08 * ring_total
    save_decal("tache_plafond_%d" % v, rgb, a, blur(height, 1.2), 2.2, ao, rough, aux=2)


# ------------------------------------------------------------------ moisissure

def _colonies(S, dens, n_col, seed, per=(20, 220), sig=(2.0, 22.0), rmax=2.6, K=2):
    """Colonies de moisissure : des amas de points (gaussiens autour d'un centre tiré selon « dens »),
    rayons en loi de puissance (surtout des points d'un pixel), plus gros et plus noirs au cœur."""
    rng = np.random.default_rng(seed)
    canvas = Image.new("L", (S * K, S * K), 0)
    dr = ImageDraw.Draw(canvas)
    cols = tries = 0
    while cols < n_col and tries < n_col * 60:
        tries += 1
        px, py = rng.random() * S, rng.random() * S
        d = dens[int(py), int(px)]
        if rng.random() > d ** 1.6:
            continue
        cols += 1
        sg = sig[0] + (sig[1] - sig[0]) * rng.random() ** 1.6 * (0.4 + 0.6 * d)
        m = int(per[0] + (per[1] - per[0]) * rng.random() ** 1.3 * d)
        # points plus serrés au centre (loi de Student : quelques points égarés loin)
        ox = rng.standard_t(3, m) * sg * 0.7
        oy = rng.standard_t(3, m) * sg * 0.7
        rr = np.sqrt(ox * ox + oy * oy) / sg
        rad = 0.3 + rmax * rng.random(m) ** 3.4 * np.exp(-rr * 0.8) * (0.5 + 0.5 * d)
        g = 120 + 135 * np.exp(-rr * 0.5) * (0.6 + 0.4 * rng.random(m))
        for i in range(m):
            x0, y0, r = px + ox[i], py + oy[i], rad[i]
            dr.ellipse([K * (x0 - r), K * (y0 - r), K * (x0 + r), K * (y0 + r)], fill=int(min(255, g[i])))
    return np.asarray(canvas.resize((S, S), Image.BOX), np.float64) / 255.0


def moisissure(v, S=1024):
    seed = 2000 + v * 31
    x, y = grid(S, S)
    n1 = spectral(S, S, 2.6, seed + 1, kmin=1.0 / S)
    n2 = spectral(S, S, 2.2, seed + 6, kmin=4.0 / S)
    if v == 1:
        # le long du bord haut (jonction mur-plafond), plus fournie vers le coin gauche
        raw = 1.0 - y / 0.58 + 0.34 * n1 + 0.3 * (1.0 - x) + 0.16 * n2
        side = sstep(0.0, 0.1, x + 0.03 * n1) * sstep(0.0, 0.18, 1.0 - x + 0.03 * n1)
    else:
        r = np.sqrt((x - 0.5) ** 2 + ((y - 0.52) * 1.1) ** 2)
        raw = 1.0 - r / 0.4 + 0.32 * n1 + 0.12 * n2
        side = 1.0
    dens = np.clip(sstep(0.0, 1.0, raw) * side, 0.0, 1.0)
    col = _colonies(S, dens, 1500, seed + 2)
    # colonies satellites, petites, au-delà du front (la moisissure gagne par taches isolées)
    sat = np.clip(sstep(-0.45, 0.5, raw + 0.25 * n2) * (side if v == 1 else 1.0), 0.0, 1.0) * 0.8
    col = np.maximum(col, _colonies(S, sat, 700, seed + 7, per=(4, 45), sig=(1.0, 7.0), rmax=1.8))
    # semis très fin (spores, poussière grise) : grain qui épaissit vers le cœur
    grain = sstep(1.2 + 1.4 * (1.0 - dens), 3.2, spectral(S, S, 0.2, seed + 3, kmin=80.0 / S)) * sstep(0.05, 0.5, dens)
    specks = np.clip(col + 0.7 * grain, 0.0, 1.0)
    # voile gris-vert autour des amas, et cœur presque continu là où la densité est forte
    haze = np.clip(blur(specks, 4.0) * 1.6 + 0.5 * blur(specks, 14.0) * 1.6, 0.0, 1.0)
    core = sstep(0.62, 0.95, dens + 0.15 * n2) * (0.55 + 0.45 * sstep(-0.5, 1.0, spectral(S, S, 1.6, seed + 4, kmin=10.0 / S)))
    # auréole d'humidité : fond jaunâtre et ligne de dépôt au bord de la zone humide
    wet = raw + 0.05
    stain_in = sstep(-0.02, 0.25, wet) * side
    tide = np.exp(-((wet + 0.0) / 0.035) ** 2) * side * (0.5 + 0.5 * sstep(-1.0, 1.0, n2))
    layers = [
        ((0.56, 0.48, 0.32), stain_in * 0.2),
        ((0.4, 0.31, 0.18), tide * 0.38),
        ((0.25, 0.25, 0.2), haze * 0.42),
        ((0.06, 0.065, 0.05), core * 0.55),
        ((0.035, 0.04, 0.03), specks * 0.97),
    ]
    rgb, a = over(layers, S, S)
    a *= edge_fade(S, S, 0.04, seed + 5, keep=("top",) if v == 1 else ())
    height = blur(specks, 0.6) + 0.4 * blur(core, 2.0)
    save_decal("moisissure_%d" % v, rgb, a, height, 1.4, 1.0 - 0.2 * blur(specks, 2.0), 0.97, aux=2)


# ------------------------------------------------------------------ fissures

def _crack(rng, x0, y0, heading, length, W, H, step=3.0, jag=0.22, wander=0.035):
    pts = [(x0, y0)]
    ang = heading
    drift = 0.0
    for _ in range(int(length / step)):
        drift = 0.9 * drift + rng.normal(0.0, wander)
        a = ang + drift + rng.normal(0.0, jag)
        ang += drift * 0.25
        px = pts[-1][0] + step * np.cos(a)
        py = pts[-1][1] + step * np.sin(a)
        if px < 30 or px > W - 30 or py < 24 or py > H - 24:
            break
        pts.append((px, py))
    return pts


CRACKS = {
    1: [(0.05, 0.52, 0.02, 0.9)],                 # (x, y, cap, longueur) relatifs
    2: [(0.06, 0.88, -0.42, 0.95)],
    3: [(0.5, 0.48, 0.15, 0.5), (0.5, 0.48, 3.0, 0.45)],
}


def fissure(v, W=1024, H=512):
    seed = 3000 + v * 13
    rng = np.random.default_rng(seed)
    K = 2
    core = Image.new("L", (W * K, H * K), 0)
    dr = ImageDraw.Draw(core)
    mains = []

    def stroke(pts, w0, w1):
        n = len(pts)
        for i in range(n - 1):
            t = i / max(1, n - 1)
            # plus large au milieu, effilée aux bouts
            w = w1 + (w0 - w1) * np.sin(np.pi * min(1.0, t * 1.15)) ** 0.6
            dr.line([(pts[i][0] * K, pts[i][1] * K), (pts[i + 1][0] * K, pts[i + 1][1] * K)],
                    fill=255, width=max(1, int(round(w * K))))

    for (cx, cy, cap, ln) in CRACKS[v]:
        pts = _crack(rng, cx * W, cy * H, cap, ln * W, W, H)
        mains.append(pts)
        stroke(pts, 3.2, 0.8)
        # branches
        nb = int(rng.integers(2, 4))
        for _ in range(nb):
            if len(pts) < 20:
                break
            i = int(rng.integers(len(pts) // 6, len(pts) * 5 // 6))
            side = 1.0 if rng.random() < 0.5 else -1.0
            b = _crack(rng, pts[i][0], pts[i][1], cap + side * rng.uniform(0.4, 1.0), ln * W * rng.uniform(0.15, 0.35), W, H, jag=0.28)
            stroke(b, 1.8, 0.6)
            if len(b) > 12 and rng.random() < 0.6:
                j = int(rng.integers(len(b) // 3, len(b)))
                bb = _crack(rng, b[j][0], b[j][1], cap - side * rng.uniform(0.3, 0.9), ln * W * 0.12, W, H, jag=0.3)
                stroke(bb, 1.1, 0.5)
    c = np.asarray(core.resize((W, H), Image.LANCZOS), np.float64) / 255.0
    c = np.clip(c, 0.0, 1.0)
    # éclats de peinture le long du tracé principal
    chips = np.zeros((H, W))
    x, y = grid(H, W)
    X, Y = x * W, y * H
    wob = spectral(H, W, 2.0, seed + 7, kmin=8.0 / W) * 0.45
    for pts in mains:
        for _ in range(int(rng.integers(3, 6))):
            i = int(rng.integers(len(pts) // 8, max(len(pts) // 8 + 1, len(pts) * 7 // 8)))
            px, py = pts[i]
            r = rng.uniform(4.0, 11.0)
            ox, oy = rng.normal(0, r * 0.5), rng.normal(0, r * 0.5)
            d = 1.0 - np.sqrt((X - px - ox) ** 2 / (r * 1.3) ** 2 + (Y - py - oy) ** 2 / r ** 2) + wob
            chips = np.maximum(chips, sstep(0.0, 0.08, d))
    chip_edge = np.clip(chips - blur(chips, 1.2) * 0.0, 0, 1) - sstep(0.5, 1.0, blur(chips, 1.5))
    chip_edge = np.clip(chip_edge * 2.0, 0.0, 1.0)
    halo = np.clip(blur(c, 5.0) * 3.0, 0.0, 1.0)
    layers = [
        ((0.32, 0.29, 0.25), halo * 0.3),            # poussière prise dans la fissure
        ((0.8, 0.78, 0.73), chips * 0.42),           # plâtre à nu sous la peinture écaillée
        ((0.3, 0.28, 0.25), chip_edge * 0.4),       # tranche de la couche de peinture
        ((0.06, 0.05, 0.045), np.clip(c * 1.15, 0, 1) * 0.95),
    ]
    rgb, a = over(layers, H, W)
    a *= edge_fade(H, W, 0.03, seed + 8)
    height = -1.0 * c - 0.5 * blur(c, 1.5) - 0.35 * blur(chips, 0.6)
    save_decal("fissure_%d" % v, rgb, a, height, 3.0, 1.0 - 0.35 * c, 0.95)


# ------------------------------------------------------------------ suie

def suie(v, S=512):
    seed = 4000 + v * 7
    x, y = grid(S, S)
    n = spectral(S, S, 2.8, seed + 1, kmin=1.0 / S)
    n2 = spectral(S, S, 1.8, seed + 2, kmin=8.0 / S)
    if v == 1:
        # halo au plafond, au-dessus d'une ampoule
        r = np.sqrt((x - 0.5) ** 2 + (y - 0.5) ** 2)
        rn = r * (1.0 + 0.16 * n) + 0.01 * n2
        a = 0.62 * (1.0 - sstep(0.0, 0.47, rn)) ** 1.7
        a *= 0.8 + 0.2 * sstep(-1.5, 1.5, n2)
    else:
        # panache sur un mur, au-dessus d'une applique (la source en bas, au centre) : un cône qui
        # s'évase en montant, le plus noir juste au-dessus de la source
        X = x - 0.5 + 0.02 * spectral(S, S, 3.4, seed + 3, kmin=1.0 / S)
        Y = y + 0.015 * spectral(S, S, 3.4, seed + 4, kmin=1.0 / S)
        s = np.clip(0.94 - Y, 0.0, None)                 # hauteur au-dessus de la source
        half = 0.035 + 0.38 * s
        across = np.exp(-1.8 * (X / half) ** 2)
        along = sstep(0.0, 0.07, s) * np.exp(-s / 0.42)
        a = 0.7 * across * along * (0.8 + 0.2 * sstep(-1.5, 1.5, n2))
    a *= edge_fade(S, S, 0.03, seed + 5)
    rgb = np.zeros((S, S, 3))
    rgb[...] = (0.035, 0.032, 0.03)
    save_decal("suie_%d" % v, rgb, a, None, 1.0, 1.0 - 0.1 * a, 0.95, aux=4)


# ------------------------------------------------------------------ chemin d'usure

def chemin_usure(v, W=512, H=1024):
    seed = 5000 + v * 11
    x, y = grid(H, W)
    X = x - 0.5
    meander = 0.03 * spectral(H, 1, 4.0, seed + 1)[:, :1] if v == 1 else 0.07 * spectral(H, 1, 4.0, seed + 1)[:, :1]
    X = X - meander + 0.035 * spectral(H, W, 2.6, seed + 2, kmin=1.0 / H)
    half = 0.2 if v == 1 else 0.16
    prof = np.exp(-(X / half) ** 2)
    if v == 2:
        prof = 0.55 * prof + 0.45 * (np.exp(-((X - 0.13) / 0.09) ** 2) + np.exp(-((X + 0.13) / 0.09) ** 2))
    streaks = spectral(H, W, 2.0, seed + 3, kmin=1.0 / H, ax=1.0, ay=6.0)
    patches = sstep(-0.8, 0.9, spectral(H, W, 2.3, seed + 4, kmin=2.0 / H))
    ends = sstep(0.0, 0.16, y) * sstep(0.0, 0.16, 1.0 - y)
    a = 0.62 * prof * ends * (0.55 + 0.45 * patches) * (0.85 + 0.15 * np.tanh(streaks))
    a *= edge_fade(H, W, 0.04, seed + 5)
    lum = 0.93 + 0.05 * np.tanh(streaks)
    rgb = np.dstack([lum, lum * 0.985, lum * 0.97])
    save_decal("chemin_usure_%d" % v, rgb, a, None, 1.0, 1.0, 0.88 + 0.06 * np.tanh(streaks), aux=2)


# ------------------------------------------------------------------ empreintes de pieds nus

def _foot_field(X, Y, v):
    """Champ d'un pied DROIT vu de dessus, orteils en haut (X : -0,5 à 0,5 de la longueur ; Y : 0 au
    bout des orteils, 1 au talon), et l'appui (0 à 1) en chaque point."""
    heel = ellipse_field(X, Y, 0.02, 0.85, 0.11, 0.122)
    band = capsule_field(X, Y, 0.118, 0.43, 0.09, 0.78, 0.052)
    ball = ellipse_field(X, Y, -0.012, 0.335, 0.172, 0.085, -0.17)
    toes = [(-0.11, 0.135, 0.055, 0.066), (-0.033, 0.112, 0.032, 0.038), (0.024, 0.126, 0.029, 0.034),
            (0.075, 0.155, 0.026, 0.031), (0.117, 0.197, 0.024, 0.028)]
    tf = [ellipse_field(X, Y, cx, cy, rx, ry, 0.1) for (cx, cy, rx, ry) in toes]
    if v == 3:
        # pied qui a glissé : talon traîné vers l'arrière, orteils étirés
        heel = smax(heel, ellipse_field(X, Y, 0.03, 0.9, 0.1, 0.11), 0.06)
        tf = [smax(t, ellipse_field(X, Y, cx, cy - 0.03, rx * 0.9, ry * 1.2, 0.1), 0.04) for t, (cx, cy, rx, ry) in zip(tf, toes)]
    sole = smax(smax(heel, band, 0.12), ball, 0.1)
    # appui : talon et avant-pied francs, voûte externe plus légère, orteils au bout
    arch = sstep(0.42, 0.52, Y) * (1.0 - sstep(0.66, 0.76, Y))
    press = 1.0 - (0.42 if v != 2 else 0.6) * arch
    tw = [0.95, 0.85, 0.8, 0.72 if v != 2 else 0.3, 0.62 if v != 2 else 0.15]
    toe_all = np.full_like(X, -1.0)
    toe_p = np.zeros_like(X)
    for f, p in zip(tf, tw):
        toe_p = np.maximum(toe_p, sstep(-0.05, 0.1, f) * p)
        toe_all = np.maximum(toe_all, f)
    press = np.where(toe_all > sole, toe_p, press)
    return np.maximum(sole, toe_all), press


def empreinte(n, W=256, H=512):
    """n = 1..6 : (n + 1) // 2 = forme 1..3 ; n impair = pied gauche, pair = pied droit."""
    v = (n + 1) // 2
    left = n % 2 == 1
    seed = 6000 + n * 19
    x, y = grid(H, W)
    L = 0.88 * H
    X = (x * W - W * 0.5) / L
    Y = (y * H - 0.05 * H) / L
    if left:
        X = -X
    X = X + 0.005 * spectral(H, W, 2.6, seed + 1, kmin=3.0 / H)
    Y = Y + 0.005 * spectral(H, W, 2.6, seed + 2, kmin=3.0 / H)
    f, press = _foot_field(X, Y, v)
    shape = sstep(-0.012, 0.03, f)
    fine = 0.8 + 0.2 * np.tanh(spectral(H, W, 1.3, seed + 3, kmin=24.0 / H))     # grain de la peau
    broad = 0.82 + 0.18 * np.tanh(spectral(H, W, 2.6, seed + 4, kmin=2.0 / H))   # appui inégal
    rim = np.clip(shape - sstep(0.02, 0.09, f), 0.0, 1.0)     # l'eau se ramasse au bord de l'appui
    a = shape * press * fine * broad * 0.82 + rim * 0.22 * press
    if v == 2:
        # plus sèche : l'empreinte se défait par endroits
        a *= 0.35 + 0.65 * sstep(-1.1, 0.3, spectral(H, W, 2.0, seed + 5, kmin=5.0 / H))
    a = np.clip(a, 0.0, 0.95)
    a *= edge_fade(H, W, 0.03, seed + 6)
    rgb = np.zeros((H, W, 3))
    rgb[...] = (0.095, 0.085, 0.075)
    save_decal("empreinte_%d" % n, rgb, a, None, 1.0, 1.0, 0.2 - 0.05 * (fine - 0.8) * 5.0)


# ------------------------------------------------------------------ crasse de pied de mur

def crasse_pied_mur(v, W=1024, H=128):
    """Bande de 0,22 m (Wear.wall_base) : le haut de l'image à 22 cm du sol, le bas au sol ; la plinthe
    de Builder.trim (11 cm) en occupe la moitié basse. Le plus sombre juste au-dessus de la plinthe
    (balai, aspirateur, chaussures), voile qui monte en s'effilochant ; sur la plinthe, poussière grise
    et coups de chaussure ; liseré de poussière dans l'angle du sol. PÉRIODIQUE en u."""
    seed = 7000 + v * 23
    rng = np.random.default_rng(seed)
    x, y = grid(H, W)
    n2 = spectral(H, W, 2.8, seed + 1, kmin=1.0 / W, ax=0.68)
    n3 = spectral(H, W, 2.0, seed + 2, kmin=8.0 / W, ax=0.68)
    front1 = spectral(1, W, 3.2, seed + 3)[0][None, :]
    PL = 0.5                                                  # dessus de la plinthe (11 cm sur 22)
    top = [0.16, 0.08, 0.24][(v - 1) % 3]
    front = top + 0.09 * front1 + 0.03 * n2
    # au-dessus de la plinthe : de 0 au front à ~0,6 juste au-dessus du dessus de plinthe
    g = np.clip((y - front) / (PL - front), 0.0, 1.0)
    # plus ou moins sale le long du mur (meubles déplacés, passages), sans couture (périodique)
    along = 0.55 + 0.45 * sstep(-1.2, 1.0, spectral(1, W, 2.4, seed + 7, kmin=2.0 / W)[0][None, :])
    wall = 0.82 * g ** 1.4 * along * (0.72 + 0.28 * np.tanh(n2)) * (0.9 + 0.1 * np.tanh(n3)) * (y < PL + 0.01)
    # traînées verticales légères (eau de lavage qui a coulé, bas de serpillière)
    drips = sstep(0.6, 1.6, spectral(H, W, 1.6, seed + 6, kmin=6.0 / W, ax=1.0, ay=0.12)) * g * 0.25
    wall = np.clip(wall + drips * (y < PL + 0.01), 0.0, 0.85)
    # sur la plinthe : poussière grise sur le haut, coups de chaussure, liseré au sol
    on_pl = (y >= PL + 0.01)
    dust_top = np.exp(-((y - PL - 0.03) / 0.05) ** 2) * on_pl * (0.6 + 0.4 * np.tanh(n3)) * 0.28
    floor_line = sstep(0.86, 1.0, y) * (0.7 + 0.3 * np.tanh(n2)) * 0.32
    K = 4
    sc = Image.new("L", (W * K, H * K), 0)
    dr = ImageDraw.Draw(sc)
    for _ in range(int(rng.integers(8, 14))):
        cx = rng.uniform(0, W)
        cy = rng.uniform(0.6, 0.95) * H
        ln = rng.uniform(10, 46)
        th = rng.uniform(0.8, 2.4)
        g8 = int(rng.uniform(110, 230))
        for off in (-W, 0, W):
            dr.ellipse([(cx + off - ln / 2) * K, (cy - th / 2) * K, (cx + off + ln / 2) * K, (cy + th / 2) * K], fill=g8)
    scuffs = blur(np.asarray(sc.resize((W, H), Image.BOX), np.float64) / 255.0, 0.8, wrap=True)
    scuffs *= 0.6 + 0.4 * sstep(-1.0, 1.0, spectral(H, W, 1.8, seed + 4, kmin=10.0 / W))
    layers = [
        ((0.21, 0.175, 0.13), wall),
        ((0.45, 0.43, 0.4), dust_top),
        ((0.4, 0.38, 0.35), floor_line),
        ((0.07, 0.06, 0.05), scuffs * 0.55),
    ]
    rgb, al = over(layers, H, W)
    al *= sstep(0.0, 0.06, y)
    rough = 0.95 - 0.0 * g
    save_decal("crasse_pied_mur_%d" % v, rgb, al, None, 1.0, 1.0 - 0.12 * wall, rough, aux=2)


# ------------------------------------------------------------------ coin de plafond

def coin(v, S=512):
    seed = 8000 + v
    x, y = grid(S, S)
    r = np.sqrt((x - 0.5) ** 2 + (y - 0.5) ** 2)
    n = spectral(S, S, 2.6, seed + 1, kmin=1.0 / S)
    specks = sstep(2.0, 2.9, spectral(S, S, 0.6, seed + 2, kmin=30.0 / S))
    fib = sstep(1.2, 2.2, spectral(S, S, 1.4, seed + 5, kmin=12.0 / S, ax=1.0, ay=0.25))   # filaments (toiles)
    body = (1.0 - sstep(0.0, 0.5, r * (1.0 + 0.25 * n))) ** 1.6
    a = 0.8 * body * (0.72 + 0.28 * np.tanh(spectral(S, S, 1.8, seed + 3, kmin=6.0 / S)))
    a = np.clip(a + specks * body * 0.7 + fib * body * 0.25, 0, 0.92)
    a *= edge_fade(S, S, 0.03, seed + 4)
    rgb = np.zeros((S, S, 3))
    rgb[...] = (0.19, 0.18, 0.16)
    save_decal("coin_%d" % v, rgb, a, None, 1.0, 1.0 - 0.15 * a, 0.96, aux=4)


# ------------------------------------------------------------------ décalques ambientCG adoucis

# id -> (marge du fondu, côtés gardés pleins)
ACG_FADE = {
    "Leaking001": (0.1, ("top",)), "Leaking002": (0.1, ("top",)), "Leaking003": (0.1, ("top",)),
    "Leaking005": (0.1, ("top",)), "Leaking007": (0.1, ("top",)), "Leaking009": (0.12, ("top",)),
    "Rust001": (0.12, ("bottom",)),
    "Fingerprints001": (0.16, ()), "Scratches001": (0.14, ()), "Scratches004": (0.14, ()),
    "Smear002": (0.15, ()), "SurfaceImperfections005": (0.08, ()), "SurfaceImperfections006": (0.08, ()),
    "SurfaceImperfections009": (0.16, ()), "SurfaceImperfections010": (0.16, ()),
    "SurfaceImperfections014": (0.2, ()), "SurfaceImperfections017": (0.2, ()),
}


def acg_soft():
    os.makedirs(os.path.join(OUT, "acg"), exist_ok=True)
    for i, (aid, (margin, keep)) in enumerate(sorted(ACG_FADE.items())):
        src = os.path.join(ACG, aid + "_albedo.png")
        if not os.path.exists(src):
            print("  (absent : %s)" % src)
            continue
        im = np.asarray(Image.open(src).convert("RGBA"), np.float64) / 255.0
        h, w = im.shape[:2]
        m = edge_fade(h, w, margin, 9000 + i * 7, keep=keep, amount=0.05)
        out = im.copy()
        out[..., 3] = im[..., 3] * m
        dst = os.path.join(OUT, "acg", aid + "_albedo.png")
        save_png(Image.fromarray(to8(out), "RGBA"), dst)
        write_import(dst, 1)
        print("  acg/%-22s %4d × %-4d (bords adoucis)" % (aid, w, h))


# ------------------------------------------------------------------ masques de crasse HD

def _lin(v8):
    c = v8 / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def _scratches(S, n, seed, light):
    rng = np.random.default_rng(seed)
    K = 2
    im = Image.new("L", (S * K, S * K), 0)
    dr = ImageDraw.Draw(im)
    for _ in range(n):
        x0, y0 = rng.uniform(0, S), rng.uniform(0, S)
        ang = rng.uniform(0, np.pi)
        ln = rng.uniform(8, 90)
        bend = rng.normal(0, 0.15)
        pts = []
        for t in np.linspace(0, 1, 8):
            a = ang + bend * t
            pts.append((x0 + np.cos(a) * ln * t, y0 + np.sin(a) * ln * t))
        g = int(rng.uniform(90, 255))
        for ox in (-S, 0, S):
            for oy in (-S, 0, S):
                dr.line([((px + ox) * K, (py + oy) * K) for px, py in pts], fill=g, width=1 if not light else 2)
    return np.asarray(im.resize((S, S), Image.BOX), np.float64) / 255.0


def grime_hd(v, S=1024):
    seed = 9500 + v * 41
    old = np.asarray(Image.open(GRIME_OLD).convert("L"), np.float64)
    target_lin = _lin(old).mean()
    low = spectral(S, S, 3.0, seed + 1, kmin=1.0 / S)
    mid = spectral(S, S, 2.0, seed + 2, kmin=4.0 / S)
    fine = spectral(S, S, 1.1, seed + 3, kmin=40.0 / S)
    f = 0.62 * low + 0.3 * mid + 0.16 * fine
    if v == 1:
        # plâtre : marbrures, vieilles auréoles (contours fins), pores
        c = spectral(S, S, 2.8, seed + 4, kmin=2.0 / S)
        marks = np.exp(-((c - 0.9) / 0.035) ** 2) + 0.6 * np.exp(-((c + 1.1) / 0.03) ** 2)
        pores = sstep(2.3, 3.2, spectral(S, S, 0.5, seed + 5, kmin=60.0 / S))
        f = f - 0.55 * marks - 0.9 * pores
    elif v == 2:
        # patine : traces grasses et poussière
        smudge = sstep(0.8, 1.9, spectral(S, S, 2.3, seed + 4, kmin=3.0 / S))
        dust = sstep(2.0, 3.0, spectral(S, S, 0.6, seed + 5, kmin=50.0 / S))
        f = f - 0.9 * smudge - 0.7 * dust + 0.25 * fine
    else:
        # peinture : rayures fines claires et sombres, petits éclats
        dark = _scratches(S, 220, seed + 4, False)
        light = _scratches(S, 90, seed + 5, True)
        chips = sstep(2.5, 3.2, spectral(S, S, 0.7, seed + 6, kmin=40.0 / S))
        f = f - 0.9 * dark + 0.6 * light - 1.0 * chips
    f = (f - f.mean()) / f.std()
    # même médiane et même dispersion que l'ancienne (un peu plus de contraste : plus de détail fin)
    sd = old.std() * 1.12
    base = np.median(old)
    img = np.clip(base + sd * f, 120, 255)
    # même moyenne en lumière linéaire (la crasse est multipliée sur la couleur) : décalage ajusté
    for _ in range(30):
        cur = _lin(img).mean()
        img = np.clip(img + (target_lin - cur) / max(1e-6, cur) * 140.0, 100, 255)
        if abs(_lin(img).mean() - target_lin) < 1e-5:
            break
    path = os.path.join(OUT, "grime_hd_%d.png" % v)
    save_png(Image.fromarray(np.clip(img + 0.5, 0, 255).astype(np.uint8), "L"), path)
    write_import(path, 0)
    print("  %-22s %4d × %-4d moyenne linéaire %.4f (ancienne %.4f), sRGB %.1f ± %.1f" % (
        "grime_hd_%d" % v, S, S, _lin(np.round(img)).mean(), target_lin, img.mean(), img.std()))


# ------------------------------------------------------------------ planche de contrôle

PLANCHE_BG = {"tache_plafond": (150, 146, 136), "moisissure": (170, 165, 150), "fissure": (175, 170, 160),
              "suie": (175, 170, 160), "chemin_usure": (95, 62, 42), "empreinte": (120, 85, 60),
              "crasse_pied_mur": (165, 160, 150), "coin": (170, 165, 155), "acg": (175, 170, 160)}


def planche(path):
    """Chaque albédo sur un fond typique, sa rugosité (G de l'ORM) et un éclairage rasant de sa normale."""
    files = sorted(f[:-11] for f in os.listdir(OUT) if f.endswith("_albedo.png"))
    files += ["acg/" + f[:-11] for f in sorted(os.listdir(os.path.join(OUT, "acg"))) if f.endswith("_albedo.png")]
    T = 220
    cols = 4
    rows = (len(files) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * T * 3, rows * (T + 14)), (20, 20, 20))
    dr = ImageDraw.Draw(sheet)
    for i, name in enumerate(files):
        kind = "acg" if name.startswith("acg/") else name.rsplit("_", 1)[0]
        a = Image.open(os.path.join(OUT, name + "_albedo.png")).convert("RGBA")
        bg = Image.new("RGBA", a.size, PLANCHE_BG.get(kind, (170, 165, 155)) + (255,))
        bg.alpha_composite(a)
        ormp = os.path.join(OUT, name + "_orm.png") if not name.startswith("acg/") else os.path.join(ACG, name[4:] + "_orm.png")
        nrmp = os.path.join(OUT, name + "_normal.png") if not name.startswith("acg/") else os.path.join(ACG, name[4:] + "_normal.png")
        alpha = np.asarray(a, np.float64)[..., 3] / 255.0
        if os.path.exists(ormp):
            g = np.asarray(Image.open(ormp).convert("RGB"), np.float64)[..., 1] / 255.0
            ga = Image.fromarray(to8(0.9 * (1 - alpha) + g * alpha), "L").convert("RGB")
        else:
            ga = Image.new("RGB", a.size, (0, 0, 0))
        if os.path.exists(nrmp):
            nm = np.asarray(Image.open(nrmp).convert("RGB"), np.float64) / 127.5 - 1.0
            ld = np.array([-0.6, 0.6, 0.5])
            ld /= np.linalg.norm(ld)
            sh = np.clip((nm * ld).sum(-1), 0, 1)
            sh = sh * alpha + 0.75 * (1 - alpha)
            na = Image.fromarray(to8(sh), "L").convert("RGB")
        else:
            na = Image.new("RGB", a.size, (40, 40, 40))
        x0 = (i % cols) * T * 3
        y0 = (i // cols) * (T + 14)
        for j, im in enumerate((bg.convert("RGB"), ga, na)):
            im = im.copy()
            im.thumbnail((T, T), Image.LANCZOS)
            sheet.paste(im, (x0 + j * T, y0 + 14))
        dr.text((x0 + 3, y0 + 1), name, fill=(255, 220, 120))
    sheet.save(path)
    print("planche : %s (%d × %d)" % (path, sheet.size[0], sheet.size[1]))


# ------------------------------------------------------------------ programme

JOBS = {
    "tache_plafond": lambda: [tache_plafond(v) for v in (1, 2, 3, 4)],
    "moisissure": lambda: [moisissure(v) for v in (1, 2)],
    "fissure": lambda: [fissure(v) for v in (1, 2, 3)],
    "suie": lambda: [suie(v) for v in (1, 2)],
    "chemin_usure": lambda: [chemin_usure(v) for v in (1, 2)],
    "empreinte": lambda: [empreinte(n) for n in range(1, 7)],
    "crasse_pied_mur": lambda: [crasse_pied_mur(v) for v in (1, 2, 3)],
    "coin": lambda: [coin(1)],
    "acg": acg_soft,
    "grime_hd": lambda: [grime_hd(v) for v in (1, 2, 3)],
}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("kinds", nargs="*", help="genres à refaire (défaut : tous) : " + ", ".join(JOBS))
    ap.add_argument("--planche", help="écrit une planche de contrôle (PNG) à ce chemin")
    args = ap.parse_args(argv)
    os.makedirs(OUT, exist_ok=True)
    kinds = args.kinds or list(JOBS)
    for k in kinds:
        if k not in JOBS:
            sys.exit("genre inconnu : %s" % k)
        print(k)
        JOBS[k]()
    if args.planche:
        planche(args.planche)
    total = 0
    for root, _, files in os.walk(OUT):
        total += sum(os.path.getsize(os.path.join(root, f)) for f in files if f.endswith(".png"))
    print("assets/decals/gen : %.2f Mo de PNG" % (total / 1e6))


if __name__ == "__main__":
    main()
