"""Images HD du bureau d'Albert (passe « triple A », lot V2-BUREAU) : godot/assets/images/bureau/.

  calendrier_2040.png    calendrier de la pharmacie, octobre 2040 (1024 × 1434 : le quad de 0,30 × 0,42 m),
                         photo du mois (Poly Haven, autumn_road DSC_0211, CC0), typographie Inter (OFL),
                         les jours barrés un à un par Albert au feutre rouge, jusqu'au 30
  diplome_medaille.png   diplôme de la médaille d'honneur du travail, échelon vermeil (1024 × 714 : l'image
                         de 0,33 × 0,23 m sous le verre du cadre) ; mêmes mots que l'ancien dessin en 3 × 5
  etiquette_box.png      l'étiquette d'Henriette sur la box, « NE PAS DÉBRANCHER » au stylo bille (512 × 140)
  etiquette_A.png        l'étiquette « A. » du manche du tournevis (512 × 240)

Usage : python3 godot/tools/gen_bureau.py [dossier des sources]
La photo source reste HORS du projet : par défaut ~/.cache/dontplay/backplates/autumn_road/DSC_0211.jpg (téléchargée
si elle manque, contrôle md5) ou le dossier donné. Imprime pour chaque image le facteur d'albédo papier
(Builder.paper_albedo) mesuré comme celui de builder.gd (PAPER_K) : bureau.gd recopie ces valeurs.
Réutilise les outils de make_assets.py (papier, encres, écriture) ; hasard à graine fixe, propre à chaque image.
"""
import hashlib
import os
import random
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_assets as M  # noqa: E402

import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

OUT = os.path.join(M.ROOT, 'assets', 'images', 'bureau')
SRC = os.path.join(os.path.expanduser('~'), '.cache', 'dontplay', 'backplates')
PHOTO = ('autumn_road/DSC_0211', 'autumn_road/jpg_plain/DSC_0211.jpg', '4c3f4aeeaca50edefca650a229923f57')
SERIF = '/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf'
SERIF_B = '/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf'
HAND = 'ReenieBeanie.ttf'


def serif(size, bold=False):
    p = SERIF_B if bold else SERIF
    if os.path.exists(p):
        return ImageFont.truetype(p, int(round(size)))
    return M.sfont('Inter-Bold.otf' if bold else 'Inter-Medium.otf', size)


def save(arr, name):
    os.makedirs(OUT, exist_ok=True)
    rgb = (np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(rgb, 'RGB').save(os.path.join(OUT, name), optimize=True)
    # facteur d'albédo papier (comme builder.gd PAPER_K) : 95e centile de la luminance linéaire, part claire
    lin = np.where(rgb / 255.0 <= 0.04045, rgb / 255.0 / 12.92, ((rgb / 255.0 + 0.055) / 1.055) ** 2.4)
    lum = lin @ np.array([0.2126, 0.7152, 0.0722])
    p95 = float(np.percentile(lum, 95))
    f = float((lum > 0.5).mean())
    k = 1 - (1 - 0.5 / max(p95, 1e-3)) * min(1.0, f / 0.5) if p95 > 0.5 else 1.0
    print('%-22s %4d × %-4d  p95 %.3f  clair %.2f  k %.2f' % (name, rgb.shape[1], rgb.shape[0], p95, f, k))
    return k


def photo_source(folder):
    key, path, md5 = PHOTO
    dst = os.path.join(folder, key + '.jpg')
    if not (os.path.exists(dst) and hashlib.md5(open(dst, 'rb').read()).hexdigest() == md5):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        req = urllib.request.Request('https://dl.polyhaven.org/file/ph-assets/HDRIs/extra/Backplates/' + path,
                                     headers={'User-Agent': 'dontplay-assets/1.0'})
        data = urllib.request.urlopen(req, timeout=180).read()
        if hashlib.md5(data).hexdigest() != md5:
            raise SystemExit('md5 inattendu : ' + key)
        open(dst, 'wb').write(data)
    return dst


def month_photo(src, w, h):
    """Le bois au bord de la route, en octobre (moitié droite du cliché) : imprimé en offset, couleurs un peu
    poussées comme sur un calendrier publicitaire, ciel gris laiteux."""
    im = Image.open(src)
    W0, H0 = im.size
    im.draft('RGB', (W0 // 2, H0 // 2))
    im = im.convert('RGB')
    w1, h1 = im.size
    x0, x1 = 0.47, 1.0
    bh = (x1 - x0) * w1 * h / w
    y1 = 0.86 * h1
    crop = (x0 * w1, y1 - bh, x1 * w1, y1)
    a = np.asarray(im.resize((w, h), Image.LANCZOS, box=crop), np.float32) / 255.0
    lum = a.mean(-1, keepdims=True)
    a = np.clip(lum + (a - lum) * 1.35, 0, 1)
    a = np.clip((a - 0.04) * 1.18, 0, 1) ** 0.88
    a = a + (a - M._blur(a, 1.4)) * 0.45
    return np.clip(a, 0, 1) * np.array([1.0, 0.98, 0.92])


def calendrier(src):
    """Calendrier d'octobre 2040 offert par la pharmacie, punaisé au mur sud ; Albert barre chaque soir le
    jour passé, d'un trait de feutre rouge, toujours le même : du 1er au 30."""
    s = 1024 / 300
    W, H = 1024, 1434
    rng, rs = random.Random(2040), np.random.RandomState(2040)
    yy, xx = M._grid(W, H, s)
    arr = M._paper(W, H, s, (0.93, 0.92, 0.88), 20401, grain=0.5, mottle=0.04)
    green = (0.04, 0.36, 0.22)
    # bandeau de la pharmacie : la croix verte, le nom, l'adresse
    band = M._mask_hd(W, H, s, lambda d, k: d.rectangle([0, 18 * k, 300 * k, 50 * k], fill=255))
    arr = M._ink(arr, band, green, 'imprime', rs, s)
    cross = M._mask_hd(W, H, s, lambda d, k: [d.rectangle([(31 - 4) * k, 23 * k, (31 + 4) * k, 45 * k], fill=255),
                                                d.rectangle([(31 - 11) * k, 30 * k, (31 + 11) * k, 38 * k], fill=255)])
    arr = M._ink(arr, cross, (0.93, 0.95, 0.9), 'imprime', rs, s)
    white = Image.new('L', (W, H), 0)
    M._text_on(white, (164 * s, 30 * s), 'PHARMACIE DU MARCHÉ', M.sfont('Inter-Bold.otf', 15.5 * s))
    M._text_on(white, (164 * s, 43.5 * s), 'Place de l\'Église · ouvert du lundi au samedi', M.sfont('Inter-Medium.otf', 6.6 * s))
    arr = M._ink(arr, np.asarray(white, np.float32) / 255.0, (0.95, 0.96, 0.92), 'imprime', rs, s)
    # la photo du mois et sa légende
    top, bot = 57, 196
    pw, ph = int(round(276 * s)), int(round((bot - top) * s))
    x0p, y0p = int(round(12 * s)), int(round(top * s))
    arr[y0p:y0p + ph, x0p:x0p + pw] = month_photo(src, pw, ph)
    ink = Image.new('L', (W, H), 0)
    red = Image.new('L', (W, H), 0)
    M._text_on(ink, (150 * s, 203.5 * s), 'Les couleurs de l\'automne', M.sfont('Inter-Medium.otf', 6.2 * s))
    M._text_on(ink, (150 * s, 224 * s), 'OCTOBRE 2040', M.sfont('Inter-Bold.otf', 24 * s))
    small = M.sfont('Inter-SemiBold.otf', 10 * s)
    f = M.sfont('Inter-Medium.otf', 15 * s)
    x0, dx, y0, dy = 33, 39, 268, 27
    for col, lettre in enumerate('LMMJVSD'):
        M._text_on(red if col == 6 else ink, ((x0 + col * dx) * s, 245 * s), lettre, small)
    grid = M._mask_hd(W, H, s, lambda d, k: [d.line([(14 * k, (254 + j * dy) * k), (286 * k, (254 + j * dy) * k)],
                                                    fill=255 if j == 0 else 110, width=max(1, int((0.7 if j == 0 else 0.4) * k))) for j in range(6)]
                      + [d.line([((x0 - dx / 2 + c_ * dx) * k, 256 * k), ((x0 - dx / 2 + c_ * dx) * k, (254 + 5 * dy) * k)],
                                fill=110, width=max(1, int(0.4 * k))) for c_ in range(1, 7)])
    arr = M._ink(arr, grid, (0.5, 0.5, 0.46), 'imprime', rs, s)
    pos = {}
    for day in range(1, 32):
        row, col = divmod(day - 1, 7)                  # le 1er octobre 2040 est un lundi
        x, y = x0 + col * dx, y0 + row * dy
        pos[day] = (x, y)
        M._text_on(red if col == 6 else ink, (x * s, y * s), str(day), f)
    # pied de page : la pharmacie de garde
    M._text_on(ink, (150 * s, 404 * s), 'Pharmacie de garde : composez le 3237', M.sfont('Inter-SemiBold.otf', 7.2 * s))
    M._text_on(ink, (150 * s, 413 * s), 'Votre pharmacien vous souhaite une bonne santé', M.sfont('Inter-Medium.otf', 5.6 * s))
    arr = M._ink(arr, np.asarray(ink, np.float32) / 255.0, (0.17, 0.16, 0.15), 'imprime', rs, s)
    arr = M._ink(arr, np.asarray(red, np.float32) / 255.0, (0.66, 0.16, 0.13), 'imprime', rs, s)
    # Albert : un trait par jour, en diagonale, le même geste chaque soir ; la note du 23 au stylo bille
    pen = Image.new('L', (W, H), 0)
    dp = ImageDraw.Draw(pen)
    for day in range(1, 31):
        x, y = pos[day]
        a = (x - 12 + rng.uniform(-1.5, 1.5), y + 9 + rng.uniform(-1, 1))
        b = (x + 12 + rng.uniform(-1.5, 1.5), y - 9 + rng.uniform(-1, 1))
        pts = M._hand_path([a, ((a[0] + b[0]) / 2 + rng.uniform(-0.8, 0.8), (a[1] + b[1]) / 2 + rng.uniform(-0.8, 0.8)), b], rng, 0.15, 1.0)
        dp.line([(px * s, py * s) for px, py in pts], fill=rng.randint(215, 245), width=max(1, int(1.9 * s)), joint='curve')
    arr = M._ink(arr, np.asarray(pen, np.float32) / 255.0, (0.7, 0.07, 0.08), 'feutre', rs, s, 0.92)
    note = Image.new('L', (W, H), 0)
    nx, ny = pos[23]
    M._text_on(note, ((nx + 1) * s, (ny + 10.5) * s), 'cardio H.', M.font(HAND, 8.5 * s), angle=4.0)
    arr = M._ink(arr, M._wobble(np.asarray(note, np.float32) / 255.0, s, 0.4, 20, 2043), (0.1, 0.13, 0.4), 'bille', rs, s)
    # le trou de la punaise, le papier jauni et gondolé, la crasse des doigts en bas à droite
    hole = np.exp(-(((xx - 150) ** 2 + (yy - 8) ** 2) / 8))
    arr *= (1 - 0.75 * np.clip(hole * 2, 0, 1))[..., None]
    stain = M._fbm(W, H, 2.3, 20402, s)
    arr *= (0.91 + 0.12 * stain)[..., None] * np.array([1.0, 0.985, 0.94])
    arr = M._fold(arr, s, 210, 'y', 0.35, 8)
    arr = M._edges(arr, s, 6, 0.12, 0.3, 20403)
    thumb = np.exp(-(((xx - 268) / 26) ** 2 + ((yy - 400) / 30) ** 2))
    arr *= (1 - 0.1 * thumb)[..., None]
    return save(M._grime_hd(arr, .4, rng, s, stains=2), 'calendrier_2040.png')


def diplome():
    """Diplôme de la médaille d'honneur du travail, échelon vermeil (trente ans de métier), imprimé sur un
    vélin crème : double filet doré, coins ornés, la Marianne remplacée par un écusson « RF », le nom écrit
    à la plume, le cachet rouge et la signature. Jauni sous le verre, piqué de rousseurs."""
    s = 1024 / 300
    W, H = 1024, 714
    w0, h0 = W / s, H / s
    rng, rs = random.Random(2031), np.random.RandomState(2031)
    yy, xx = M._grid(W, H, s)
    arr = M._paper(W, H, s, (0.93, 0.89, 0.78), 20311, grain=0.6, mottle=0.06)
    gold = (0.6, 0.45, 0.18)

    def frame(d, k):
        for m_, wd in ((8, 1.6), (12, 0.6)):
            d.rectangle([m_ * k, m_ * k, (w0 - m_) * k, (h0 - m_) * k], outline=255, width=max(1, int(wd * k)))
        for cx, cy in ((16, 16), (w0 - 16, 16), (16, h0 - 16), (w0 - 16, h0 - 16)):
            for r in (5.0, 3.0):
                d.ellipse([(cx - r) * k, (cy - r) * k, (cx + r) * k, (cy + r) * k], outline=255, width=max(1, int(0.6 * k)))
        # guillochis : une onde fine le long des bords
        for y_ in (10.0, h0 - 10.0):
            pts = [((20 + t) * k, (y_ + 1.1 * np.sin(t * 0.7)) * k) for t in np.arange(0, w0 - 40, 0.5)]
            d.line(pts, fill=170, width=max(1, int(0.35 * k)))
    arr = M._ink(arr, M._mask_hd(W, H, s, frame, ss=3), gold, 'imprime', rs, s)
    # le drapeau et l'écusson
    flag = [M._mask_hd(W, H, s, lambda d, k, i=i: d.rectangle([(141 + i * 6) * k, 22 * k, (147 + i * 6) * k, 31 * k], fill=255)) for i in range(3)]
    arr = M._ink(arr, flag[0], (0.12, 0.2, 0.5), 'imprime', rs, s)
    arr = M._ink(arr, flag[2], (0.72, 0.13, 0.12), 'imprime', rs, s)
    arr = M._ink(arr, np.clip(M._mask_hd(W, H, s, lambda d, k: d.rectangle([141 * k, 22 * k, 159 * k, 31 * k], outline=255, width=max(1, int(0.4 * k)))), 0, 1),
                 (0.3, 0.28, 0.25), 'imprime', rs, s)
    ink = Image.new('L', (W, H), 0)
    redm = Image.new('L', (W, H), 0)
    M._text_on(ink, (150 * s, 40 * s), 'RÉPUBLIQUE FRANÇAISE', M.sfont('Inter-SemiBold.otf', 7.5 * s))
    M._text_on(ink, (150 * s, 48 * s), 'Ministère du Travail', M.sfont('Inter-Medium.otf', 5.6 * s))
    M._text_on(ink, (150 * s, 70 * s), 'MÉDAILLE D\'HONNEUR', serif(19 * s, True))
    M._text_on(ink, (150 * s, 89 * s), 'DU TRAVAIL', serif(15 * s, True))
    M._text_on(redm, (150 * s, 107 * s), 'VERMEIL', serif(12 * s, True))
    body = serif(6.4 * s)
    M._text_on(ink, (150 * s, 126 * s), 'Le Ministre du Travail confère la médaille d\'honneur du travail,', body)
    M._text_on(ink, (150 * s, 134 * s), 'échelon vermeil, en récompense de trente années de services, à', body)
    M._text_on(ink, (150 * s, 169 * s), 'Promotion du 1er janvier 2031', serif(6 * s))
    M._text_on(ink, (70 * s, 189 * s), 'Fait à Paris, le 1er janvier 2031', serif(5.4 * s))
    arr = M._ink(arr, np.asarray(ink, np.float32) / 255.0, (0.2, 0.15, 0.1), 'imprime', rs, s)
    arr = M._ink(arr, np.asarray(redm, np.float32) / 255.0, (0.62, 0.16, 0.1), 'imprime', rs, s)
    # le nom, à la plume (ligne pointillée imprimée dessous)
    dots = M._mask_hd(W, H, s, lambda d, k: [d.ellipse([(x_ - 0.35) * k, 153.5 * k, (x_ + 0.35) * k, 154.2 * k], fill=255) for x_ in np.arange(80, 220, 2.2)])
    arr = M._ink(arr, dots, (0.35, 0.3, 0.24), 'imprime', rs, s)
    nm = Image.new('L', (W, H), 0)
    M._text_on(nm, (150 * s, 147 * s), 'Monsieur Albert', M.font(HAND, 17 * s), angle=1.2, shear=-0.12)
    arr = M._ink(arr, M._wobble(np.asarray(nm, np.float32) / 255.0, s, 0.5, 30, 2032), (0.08, 0.07, 0.12), 'feutre', rs, s, 0.95)
    # le cachet rouge (en bas à gauche) et la signature (en bas à droite)
    seal = Image.new('L', (W, H), 0)
    sd = ImageDraw.Draw(seal)
    cx, cy, r = 232, 186, 14
    k = s
    sd.ellipse([(cx - r) * k, (cy - r) * k, (cx + r) * k, (cy + r) * k], outline=255, width=max(1, int(1.2 * k)))
    sd.ellipse([(cx - r + 3) * k, (cy - r + 3) * k, (cx + r - 3) * k, (cy + r - 3) * k], outline=200, width=max(1, int(0.5 * k)))
    M._text_on(seal, (cx * k, cy * k), 'RF', serif(10 * s, True))
    sm = np.asarray(seal, np.float32) / 255.0 * (0.55 + 0.45 * M._fbm(W, H, 0.8, 20312, s))
    arr = M._ink(arr, sm, (0.66, 0.12, 0.12), 'imprime', rs, s, 0.85)
    sig = Image.new('L', (W, H), 0)
    dg = ImageDraw.Draw(sig)
    t = np.linspace(0, 1, 260)
    sx = 176 + 50 * t + 3.2 * np.sin(t * np.pi * 13)                  # des boucles : la plume revient en arrière
    sy = 187 - 5.5 * np.sin(t * np.pi * 6.5 + 0.4) * (1 - 0.55 * t) - 3.0 * np.cos(t * np.pi * 13)
    dg.line([(px * s, py * s) for px, py in zip(sx, sy)], fill=235, width=max(1, int(0.8 * s)), joint='curve')
    dg.line([(px * s, py * s) for px, py in M._hand_path([(174, 195), (228, 192)], rng, 0.3, 1.0)], fill=220, width=max(1, int(0.7 * s)))
    arr = M._ink(arr, np.asarray(sig, np.float32) / 255.0, (0.1, 0.1, 0.2), 'bille', rs, s)
    # rousseurs, jaunissement sous le verre (plus fort au bord, protégé là où était le passe-partout)
    for _ in range(40):
        fx, fy, fr = rng.uniform(0, w0), rng.uniform(0, h0), rng.uniform(0.5, 2.2)
        spot = np.exp(-(((xx - fx) ** 2 + (yy - fy) ** 2) / (fr * fr)))
        arr *= (1 - 0.18 * spot[..., None] * (1 - np.array([0.8, 0.62, 0.4])))
    stain = M._fbm(W, H, 2.2, 20313, s)
    arr *= (0.9 + 0.12 * stain)[..., None] * np.array([1.0, 0.975, 0.9])
    arr = M._edges(arr, s, 9, 0.16, 0.45, 20314)
    return save(M._grime_hd(arr, .3, rng, s, stains=1), 'diplome_medaille.png')


def _label(name, W, H, lines, seed, card=(0.95, 0.94, 0.9), ink=(0.1, 0.12, 0.38), kind='bille', sizes=None, tape=False):
    """Étiquette autocollante (ou ruban de masquage) écrite à la main : lines = [(texte, x, y), …] en
    fractions de l'image ; sizes : hauteur des lettres (fraction de H) par ligne."""
    rng, rs = random.Random(seed), np.random.RandomState(seed)
    s = 2.0
    arr = M._paper(W, H, s, card, seed + 1, grain=0.5 if not tape else 1.2,
                   tex='Paper002/Paper002_albedo.jpg', mottle=0.05 if not tape else 0.1)
    arr = M._edges(arr, s, 5.0, 0.18 if not tape else 0.1, 0.3, seed + 2)
    m = Image.new('L', (W, H), 0)
    for i, (txt, fx, fy) in enumerate(lines):
        size = (sizes[i] if sizes else 0.5) * H
        M._text_on(m, (fx * W + rng.uniform(-3, 3), fy * H + rng.uniform(-2, 2)), txt, M.font(HAND, size),
                   angle=rng.uniform(-2.5, 2.5), shear=rng.uniform(-0.1, 0.02))
    mk = M._wobble(np.asarray(m, np.float32) / 255.0, s, 0.6, 24, seed + 3)
    arr = M._ink(arr, mk, ink, kind, rs, s)
    sm = M._fbm(W, H, 1.6, seed + 4, s)
    arr *= (0.93 + 0.08 * sm)[..., None]
    return save(arr, name)


def etiquettes():
    kb = _label('etiquette_box.png', 512, 140, [('NE PAS', 0.5, 0.33), ('DÉBRANCHER', 0.5, 0.71)], 3101,
                sizes=[0.45, 0.47])
    ka = _label('etiquette_A.png', 512, 240, [('A.', 0.47, 0.5)], 3102, card=(0.9, 0.87, 0.74),
                ink=(0.06, 0.06, 0.08), kind='feutre', sizes=[0.95], tape=True)
    return kb, ka


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else SRC
    src = photo_source(folder)
    ks = {'calendrier_2040.png': calendrier(src), 'diplome_medaille.png': diplome()}
    kb, ka = etiquettes()
    ks['etiquette_box.png'] = kb
    ks['etiquette_A.png'] = ka
    print('PAPER_K : ' + ', '.join('"%s": %.2f' % (k, v) for k, v in ks.items()))
    M._import_vram([os.path.join(OUT, n) for n in ks])      # compressées pour la carte (BC1), comme les autres


if __name__ == '__main__':
    main()
