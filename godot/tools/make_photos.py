"""Photos du monde du jeu, tirées de vraies photos CC0 (les « backplates » des HDRI de Poly Haven).

Usage : python3 -I godot/tools/make_photos.py fetch          télécharge les backplates manquants (environ 62 Mo)
        python3 -I godot/tools/make_photos.py                toutes les photos (télécharge d'abord ce qui manque)
        python3 -I godot/tools/make_photos.py plage noel     certaines (voir PHOTOS)
Les sources restent HORS du projet : PHOTO_SOURCES (par défaut ~/.cache/dontplay/backplates/<hdri>/<image>.jpg).
Seules les images finales entrent dans le jeu : godot/assets/images/photos/<kind>.png, 768 × 576 (paysage) ou
576 × 768 (portrait), RGB 8 bits. Les fonds viennent des backplates (licence CC0, liste et adresses dans
BACKPLATES et assets/images/SOURCES.md) ; ecole, aieule et famille ont un fond de studio dessiné.
make_assets.py s'en sert aussi : month_photo() (la photo du calendrier), et « make_assets.py images » lance toutes
les photos (PHOTOS) avec les autres images HD.
Dépendances : numpy, Pillow. Le hasard est local (graines fixes) : deux lancements donnent les mêmes fichiers.

Règle (GDD § 11.1) : aucun visage humain généré. Les personnes sont de dos, à contre-jour, en silhouette (aieule :
une silhouette de papier découpé, de profil), floues au premier plan (noel), ou leur visage est rayé au stylo
jusqu'à disparaître (ecole, scribble()). Lot V2-RETOUCHES : les figures sont intégrées à la photo (render_person :
lwrap, match, soft) au lieu d'être collées en aplat, et jardin n'a plus personne.
Pour essayer sans toucher au jeu : PHOTO_OUT=<dossier> (les images y sont écrites au lieu de assets/images/photos).
"""
import hashlib
import os
import sys
import urllib.request

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
IMG = os.path.join(ROOT, 'assets', 'images')
OUT = os.path.join(IMG, 'photos')
SRC = os.environ.get('PHOTO_SOURCES', os.path.join(os.path.expanduser('~'), '.cache', 'dontplay', 'backplates'))
PH = 'https://dl.polyhaven.org/file/ph-assets/HDRIs/extra/Backplates/'

# backplate -> (chemin sous PH, md5) ; licence CC0 (Poly Haven), voir assets/images/SOURCES.md
BACKPLATES = {
    'autumn_park/DSC_0158': ('autumn_park/jpg_plain/DSC_0158.jpg', 'b8a32be850b66f8408ad97978ce84eeb'),
    'blouberg_sunrise_1/IMG_0623': ('blouberg_sunrise_1/jpg_plain/IMG_0623.jpg', '6af92cfd6a365095df4a524aa31066a8'),
    'christmas_photo_studio_07/15': ('christmas_photo_studio_07/jpg_plain/15.jpg', '154d8fec0814754772da1fb22ce33c32'),
    'small_cathedral_02/DSC_0681': ('small_cathedral_02/jpg_plain/DSC_0681.jpg', '1b681087930467eac1508d9124f8cdac'),
    'small_cathedral_02/DSC_0701': ('small_cathedral_02/jpg_plain/DSC_0701.jpg', 'c39fe46511af3a9e145ba4123daaf9c4'),
    'vignaioli/DSC07532': ('vignaioli/jpg_plain/DSC07532.jpg', 'cc25a1b2873d547d087a9bcd8ec775f0'),
    'residential_garden/IMG_0603': ('residential_garden/jpg_plain/IMG_0603.jpg', '813a95ce1515fad726d1b2ee5f8b700b'),
}

W4, H4 = 768, 576          # format des photos : 4:3 paysage (ou l'inverse en portrait)


# ------------------------------------------------------------------ sources

def fetch():
    """Télécharge les backplates manquants (contrôle md5) dans SRC."""
    for key, (path, md5) in BACKPLATES.items():
        dst = os.path.join(SRC, key + '.jpg')
        if os.path.exists(dst) and hashlib.md5(open(dst, 'rb').read()).hexdigest() == md5:
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        req = urllib.request.Request(PH + path, headers={'User-Agent': 'dontplay-assets/1.0'})
        data = urllib.request.urlopen(req, timeout=180).read()
        if hashlib.md5(data).hexdigest() != md5:
            raise SystemExit('md5 inattendu : ' + key)
        open(dst, 'wb').write(data)
        print('téléchargé', key, len(data) // 1024, 'Ko')


def plate(key, box, size):
    """Le backplate key, recadré (box : fractions x0, y0, x1, y1 de l'image) et réduit à size (W, H) :
    tableau de flottants 0 à 1 (sRGB). La réduction passe par draft() (JPEG à 1/2, 1/4…), puis Lanczos."""
    path = os.path.join(SRC, key + '.jpg')
    if not os.path.exists(path):
        raise FileNotFoundError(path)
    im = Image.open(path)
    W0, H0 = im.size
    bw = (box[2] - box[0]) * W0
    scale = bw / size[0]
    if scale >= 2.2:
        im.draft('RGB', (int(W0 / scale * 2.0), int(H0 / scale * 2.0)))
    im = im.convert('RGB')
    w1, h1 = im.size
    crop = (box[0] * w1, box[1] * h1, box[2] * w1, box[3] * h1)
    im = im.resize(size, Image.LANCZOS, box=crop)
    return np.asarray(im, np.float32) / 255.0


def month_photo(W, H):
    """La photo du calendrier d'octobre 2016 : un parc en automne (érables rouges, bouleaux jaunes, ciel
    bleu), imprimée en offset : un peu plus contrastée et saturée, à peine plus nette."""
    a = plate('autumn_park/DSC_0158', (0.3, 0.02, 1.0, 0.02 + 0.7 * (H / W) * 4928 / 3264), (W, H))
    lum = a.mean(-1, keepdims=True)
    a = np.clip(lum + (a - lum) * 1.18, 0, 1)
    a = np.clip((a - 0.04) * 1.08, 0, 1)
    sharp = a + (a - blur(a, 1.5)) * 0.4
    return np.clip(sharp, 0, 1) * np.array([0.98, 0.97, 0.93])


# ------------------------------------------------------------------ outils

def blur(a, sigma):
    """Flou gaussien (FFT, bords en miroir) d'un tableau (h, w) ou (h, w, c) de flottants."""
    if sigma <= 0.05:
        return a.astype(np.float32)
    p = int(3 * sigma) + 2
    pad = ((p, p), (p, p)) + (((0, 0),) if a.ndim == 3 else ())
    b = np.pad(a.astype(np.float32), pad, mode='reflect')
    h, w = b.shape[:2]
    g = np.exp(-2 * (np.pi * sigma) ** 2 * (np.fft.fftfreq(h)[:, None] ** 2 + np.fft.rfftfreq(w)[None, :] ** 2))
    if b.ndim == 2:
        out = np.fft.irfft2(np.fft.rfft2(b) * g, s=(h, w))
    else:
        out = np.stack([np.fft.irfft2(np.fft.rfft2(b[..., c]) * g, s=(h, w)) for c in range(b.shape[2])], -1)
    return out[p:-p, p:-p].astype(np.float32)


def noise(W, H, beta, seed, sx=1.0, sy=1.0):
    """Bruit fractal 0 à 1 (pente du spectre beta), étiré de sx en x et sy en y (fibres, mèches, plis)."""
    rs = np.random.RandomState(seed)
    w, h = max(8, int(W / sx)), max(8, int(H / sy))
    white = rs.randn(h, w)
    fy = np.fft.fftfreq(h)[:, None] * h
    fx = np.fft.rfftfreq(w)[None, :] * w
    r = np.sqrt(fx ** 2 + fy ** 2)
    r[0, 0] = 1.0
    spec = np.fft.rfft2(white) / r ** (beta / 2.0)
    spec[0, 0] = 0
    out = np.fft.irfft2(spec, s=(h, w))
    lo, hi = np.percentile(out, 0.2), np.percentile(out, 99.8)
    out = np.clip((out - lo) / (hi - lo + 1e-9), 0, 1).astype(np.float32)
    if (w, h) != (W, H):
        out = np.asarray(Image.fromarray(out, 'F').resize((W, H), Image.BICUBIC), np.float32)
    return np.clip(out, 0, 1)


def mask(W, H, fn, ss=3):
    """Masque 0 à 1 dessiné à ss × la taille puis réduit : fn(d, k) dessine en coordonnées × k."""
    big = Image.new('L', (W * ss, H * ss), 0)
    fn(ImageDraw.Draw(big), ss)
    return np.asarray(big.resize((W, H), Image.BOX), np.float32) / 255.0


def lay(arr, m, col):
    """Pose une couleur (ou une image) à travers le masque m."""
    m = np.clip(m, 0, 1)[..., None]
    return arr * (1 - m) + np.asarray(col, np.float32) * m


def shift(a, dx, dy):
    """Décale un tableau (h, w) de dx, dy px (entiers ; les bords se répètent)."""
    out = np.roll(np.roll(a, int(dy), 0), int(dx), 1)
    if dy > 0:
        out[:int(dy)] = out[int(dy):int(dy) + 1]
    elif dy < 0:
        out[int(dy):] = out[int(dy) - 1:int(dy)]
    if dx > 0:
        out[:, :int(dx)] = out[:, int(dx):int(dx) + 1]
    elif dx < 0:
        out[:, int(dx):] = out[:, int(dx) - 1:int(dx)]
    return out


def taper(d, k, a, b, ra, rb, fill=255):
    """Un membre : cône arrondi de a (rayon ra) à b (rayon rb), en px × k."""
    ax, ay = a
    bx, by = b
    vx, vy = bx - ax, by - ay
    ln = max(1e-6, np.hypot(vx, vy))
    nx, ny = -vy / ln, vx / ln
    d.polygon([((ax + nx * ra) * k, (ay + ny * ra) * k), ((bx + nx * rb) * k, (by + ny * rb) * k),
               ((bx - nx * rb) * k, (by - ny * rb) * k), ((ax - nx * ra) * k, (ay - ny * ra) * k)], fill=fill)
    d.ellipse([(ax - ra) * k, (ay - ra) * k, (ax + ra) * k, (ay + ra) * k], fill=fill)
    d.ellipse([(bx - rb) * k, (by - rb) * k, (bx + rb) * k, (by + rb) * k], fill=fill)


def blob(d, k, pts, fill=255, steps=10):
    """Polygone lissé (Catmull-Rom fermé) passant par pts (px × k)."""
    n = len(pts)
    out = []
    for i in range(n):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        for t in np.linspace(0, 1, steps, endpoint=False):
            t2, t3 = t * t, t * t * t
            x = 0.5 * (2 * p1[0] + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2
                       + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * (2 * p1[1] + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
                       + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x * k, y * k))
    d.polygon(out, fill=fill)


def save(arr, name, folder=None):
    """Enregistre arr (flottants 0 à 1) en PNG RGB 8 bits dans folder (par défaut OUT)."""
    folder = folder or os.environ.get('PHOTO_OUT', OUT)
    os.makedirs(folder, exist_ok=True)
    Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGB').save(os.path.join(folder, name), optimize=True)


# ------------------------------------------------------------------ personnes (de dos ou à contre-jour)

class Person:
    """Une personne vue de dos (ou en silhouette à contre-jour), dessinée par matières : cheveux, peau,
    haut, bas, jambes, chaussures, chapeau, voile. Coordonnées en px de l'image finale : x au milieu du
    corps, yf sous les pieds (ou le bas du cadre pour un buste), h la taille debout.
    kind : 'homme', 'femme', 'fille' (enfant de 4 à 7 ans). pose : 'debout', 'assis' (par terre, de dos),
    'chaise' (assis sur une chaise : les jambes vont vers l'avant, cachées), 'genoux', 'buste'.
    hair : 'court', 'carre', 'permanente', 'chignon', 'long', 'queue'. arms : 'bas', 'devant' (les mains
    tiennent quelque chose devant soi), 'leve' (bras droit levé), 'main' (bras gauche tendu vers le bas,
    vers une main d'enfant), 'bras' (les deux bras pliés : l'un tient l'autre, un bouquet…). dress : robe
    (jupe jusqu'au genou), long_dress : robe longue (mariée). turn : la tête tournée vers la droite (> 0)
    ou la gauche, en fraction de largeur de tête. Les contours sont un peu déformés (seed) : rien n'est
    une ellipse parfaite."""

    # repères du corps, en hauteurs de tête depuis le sommet du crâne
    BODY = {
        'adulte': dict(n=7.5, neck=1.28, sh=1.6, arm=2.2, waist=3.0, hip=3.75, crotch=4.05, knee=5.55, ankle=7.12),
        'fille': dict(n=5.6, neck=1.2, sh=1.42, arm=1.9, waist=2.4, hip=2.95, crotch=3.15, knee=4.25, ankle=5.3),
    }

    def __init__(self, x, yf, h, kind='femme', pose='debout', hair='court', arms='bas', dress=False,
                 long_dress=False, hat=None, veil=False, turn=0.0, lean=0.0, seed=0, width=1.0, front=False):
        self.x, self.yf, self.h = x, yf, h
        self.kind, self.pose, self.hair, self.arms = kind, pose, hair, arms
        self.dress, self.long_dress, self.hat, self.veil = dress, long_dress, hat, veil
        self.turn, self.lean, self.seed, self.width, self.front = turn, lean, seed, width, front
        self.B = self.BODY['fille' if kind == 'fille' else 'adulte']
        self.hh = h / self.B['n']

    def top(self):
        B, hh = self.B, self.hh
        if self.pose == 'assis':
            return self.yf - (B['hip'] + 0.45) * hh
        if self.pose == 'chaise':
            return self.yf - (B['hip'] + 0.1) * hh
        if self.pose == 'genoux':
            return self.yf - (B['hip'] + 0.95) * hh
        if self.pose == 'buste':
            return self.yf - (B['sh'] + 2.1) * hh
        return self.yf - B['n'] * hh

    def joints(self):
        """Épaule, coude, poignet de chaque bras : {-1: (épaule, coude, poignet), +1: …}."""
        B, hh, x = self.B, self.hh, self.x
        t = self.top()
        man = self.kind == 'homme'
        sw = hh * (1.15 if man else (0.92 if self.kind == 'femme' else 0.9)) * self.width
        lean = self.lean * hh
        out = {}
        for sx in (-1, 1):
            sh = (x + sx * (sw - 0.24 * hh) + lean * 0.8, t + (B['sh'] + 0.12) * hh)
            ln1, ln2 = 1.4 * hh * (0.8 if self.kind == 'fille' else 1), 1.15 * hh * (0.8 if self.kind == 'fille' else 1)
            mode = self.arms
            if mode == 'leve' and sx > 0:
                el = (sh[0] + 0.6 * ln1, sh[1] - 0.75 * ln1)
                wr = (el[0] + 0.15 * ln2, el[1] - 0.98 * ln2)
            elif mode == 'main' and sx < 0:
                el = (sh[0] - 0.25 * ln1, sh[1] + 0.96 * ln1)
                wr = (el[0] - 0.55 * ln2, el[1] + 0.82 * ln2)
            elif mode == 'main' and sx > 0 and self.kind == 'fille':
                el = (sh[0] + 0.25 * ln1, sh[1] + 0.96 * ln1)
                wr = (el[0] + 0.55 * ln2, el[1] + 0.82 * ln2)
            elif mode in ('devant', 'bras') or self.pose in ('genoux', 'assis', 'chaise'):
                el = (sh[0] + sx * 0.1 * ln1, sh[1] + 0.97 * ln1)
                wr = (el[0] - sx * 0.6 * ln2, el[1] + 0.25 * ln2)
            else:
                el = (sh[0] + sx * 0.12 * ln1, sh[1] + 0.99 * ln1)
                wr = (el[0] - sx * 0.04 * ln2, el[1] + 0.99 * ln2)
            out[sx] = (sh, el, wr)
        return out, sw

    def draw(self, W, H, ss=3):
        """Les masques des matières (nom -> tableau 0 à 1)."""
        B, hh, x, yf = self.B, self.hh, self.x, self.yf
        t = self.top()
        man = self.kind == 'homme'
        child = self.kind == 'fille'
        lean = self.lean * hh
        J, sw = self.joints()
        hx = x + self.turn * hh * 0.18 + lean
        hy = t + 0.5 * hh
        hrx, hry = hh * (0.39 if not child else 0.43), hh * 0.5
        yn, ysh, yw, yh, yc = (t + B[k] * hh for k in ('neck', 'sh', 'waist', 'hip', 'crotch'))
        ww = hh * (0.72 if man else (0.62 if child else 0.56)) * self.width
        hw = hh * (0.8 if man else (0.66 if child else 0.86)) * self.width
        parts = {}

        def m(fn):
            return mask(W, H, fn, ss)

        def torso(d, k):
            pts = [(x - 0.25 * hh + lean, yn - 0.1 * hh), (x - sw * 0.68 + lean * 0.9, yn + 0.12 * hh),
                   (x - sw + lean * 0.8, ysh + 0.1 * hh), (x - sw * 0.97 + lean * 0.6, ysh + 0.75 * hh),
                   (x - ww + lean * 0.3, yw), (x - hw, yh), (x - hw * 0.94, yc),
                   (x + hw * 0.94, yc), (x + hw, yh), (x + ww + lean * 0.3, yw),
                   (x + sw * 0.97 + lean * 0.6, ysh + 0.75 * hh), (x + sw + lean * 0.8, ysh + 0.1 * hh),
                   (x + sw * 0.68 + lean * 0.9, yn + 0.12 * hh), (x + 0.25 * hh + lean, yn - 0.1 * hh)]
            if self.pose == 'buste':
                pts = pts[:4] + [(x - sw * 1.02, H * 1.2), (x + sw * 1.02, H * 1.2)] + pts[-4:]
            blob(d, k, pts, steps=8)

        def legs(d, k):
            if self.pose == 'debout':
                r1, r2, r3 = (0.42, 0.3, 0.21) if man else (0.4, 0.25, 0.13)    # pantalon d'homme : jambe droite
                for sx in (-1, 1):
                    kx = x + sx * hh * 0.34
                    taper(d, k, (x + sx * hh * 0.42, yc - 0.15 * hh), (kx, t + B['knee'] * hh), hh * r1, hh * r2)
                    taper(d, k, (kx, t + B['knee'] * hh), (x + sx * hh * 0.3, t + B['ankle'] * hh), hh * r2, hh * r3)
            elif self.pose == 'assis':                              # assis en tailleur : la base s'élargit
                blob(d, k, [(x - hw * 1.0, yh - 0.2 * hh), (x - hw * 1.55, yf - 0.25 * hh), (x - hw * 1.35, yf),
                            (x + hw * 1.35, yf), (x + hw * 1.55, yf - 0.25 * hh), (x + hw * 1.0, yh - 0.2 * hh)], steps=8)
            elif self.pose == 'chaise':
                d.rectangle([(x - hw * 1.0) * k, (yh - 0.1 * hh) * k, (x + hw * 1.0) * k, (yf + 0.05 * hh) * k], fill=255)
            elif self.pose == 'genoux':                             # assise sur les talons
                blob(d, k, [(x - hw * 1.0, yh - 0.2 * hh), (x - hw * 1.22, yf - 0.35 * hh), (x - hw * 1.05, yf),
                            (x + hw * 1.05, yf), (x + hw * 1.22, yf - 0.35 * hh), (x + hw * 1.0, yh - 0.2 * hh)], steps=8)

        def skirt(d, k):
            if self.long_dress:
                bot = yf + 0.05 * hh
                flare = 1.5
            else:
                bot = t + (B['knee'] + (0.15 if child else 0.25)) * hh
                flare = 1.12
            blob(d, k, [(x - ww * 0.98, yw - 0.1 * hh), (x - hw * 1.04, yh), (x - hw * flare, bot), (x, bot + 0.1 * hh),
                        (x + hw * flare, bot), (x + hw * 1.04, yh), (x + ww * 0.98, yw - 0.1 * hh)], steps=6)

        def shoes(d, k):
            if self.pose == 'genoux':
                for sx in (-1, 1):
                    cx = x + sx * hh * 0.5
                    d.ellipse([(cx - hh * 0.2) * k, (yf - 0.3 * hh) * k, (cx + hh * 0.2) * k, (yf + 0.02 * hh) * k], fill=255)
                return
            if self.pose != 'debout' or self.long_dress:
                return
            for sx in (-1, 1):
                cx = x + sx * hh * 0.3
                d.ellipse([(cx - hh * 0.17) * k, (yf - 0.34 * hh) * k, (cx + hh * 0.17) * k, (yf + 0.03 * hh) * k], fill=255)

        def neck(d, k):
            taper(d, k, (hx - 0.02 * hh, hy + 0.3 * hh), (x + lean, yn + 0.12 * hh), hh * 0.18, hh * 0.21)

        def head(d, k):
            d.ellipse([(hx - hrx) * k, (hy - hry) * k, (hx + hrx) * k, (hy + hry) * k], fill=255)
            for sx in (-1, 1):                                      # les oreilles
                ex = hx + sx * hrx * 0.95 + self.turn * hh * 0.04
                d.ellipse([(ex - hh * 0.085) * k, (hy - 0.04 * hh) * k, (ex + hh * 0.085) * k, (hy + 0.22 * hh) * k], fill=255)

        def hair(d, k):
            st = self.hair
            if st == 'court':
                blob(d, k, [(hx - hrx * 1.04, hy + 0.06 * hh), (hx - hrx * 0.92, hy - hry * 0.72), (hx, hy - hry * 1.07),
                            (hx + hrx * 0.92, hy - hry * 0.72), (hx + hrx * 1.04, hy + 0.06 * hh),
                            (hx + hrx * 0.8, hy + hry * 0.62), (hx, hy + hry * 0.8), (hx - hrx * 0.8, hy + hry * 0.62)])
            elif st == 'carre':                                     # carré d'enfant, jusqu'à la nuque
                blob(d, k, [(hx - hrx * 1.12, hy + 0.05 * hh), (hx - hrx * 1.0, hy - hry * 0.78), (hx, hy - hry * 1.1),
                            (hx + hrx * 1.0, hy - hry * 0.78), (hx + hrx * 1.12, hy + 0.05 * hh), (hx + hrx * 1.16, hy + hry * 0.95),
                            (hx + hrx * 0.5, hy + hry * 1.12), (hx - hrx * 0.5, hy + hry * 1.12), (hx - hrx * 1.16, hy + hry * 0.95)])
            elif st == 'permanente':
                rr = np.random.RandomState(self.seed + 7)
                for a in np.linspace(0, 2 * np.pi, 22, endpoint=False):
                    if np.sin(a) > 0.82:
                        continue
                    r = hh * rr.uniform(0.15, 0.21)
                    cx = hx + np.cos(a) * hrx * 1.0
                    cy = hy - 0.02 * hh + np.sin(a) * hry * (0.92 if np.sin(a) < 0 else 0.78)
                    d.ellipse([(cx - r) * k, (cy - r) * k, (cx + r) * k, (cy + r) * k], fill=255)
                d.ellipse([(hx - hrx * 1.08) * k, (hy - hry * 1.08) * k, (hx + hrx * 1.08) * k, (hy + hry * 0.82) * k], fill=255)
            elif st == 'chignon':
                blob(d, k, [(hx - hrx * 1.07, hy + 0.08 * hh), (hx - hrx * 0.98, hy - hry * 0.8), (hx, hy - hry * 1.1),
                            (hx + hrx * 0.98, hy - hry * 0.8), (hx + hrx * 1.07, hy + 0.08 * hh),
                            (hx + hrx * 0.72, hy + hry * 0.7), (hx, hy + hry * 0.84), (hx - hrx * 0.72, hy + hry * 0.7)])
                r = hh * 0.25
                d.ellipse([(hx - r * 1.1) * k, (hy + 0.05 * hh - r) * k, (hx + r * 1.1) * k, (hy + 0.05 * hh + r) * k], fill=255)
            elif st == 'long':
                blob(d, k, [(hx - hrx * 1.06, hy), (hx - hrx * 0.95, hy - hry * 0.85), (hx, hy - hry * 1.08),
                            (hx + hrx * 0.95, hy - hry * 0.85), (hx + hrx * 1.06, hy), (hx + hrx * 1.22, yn + 0.5 * hh),
                            (hx + hrx * 0.95, ysh + 0.9 * hh), (hx, ysh + 1.05 * hh), (hx - hrx * 0.95, ysh + 0.9 * hh),
                            (hx - hrx * 1.22, yn + 0.5 * hh)])
            elif st == 'queue':
                blob(d, k, [(hx - hrx * 1.04, hy + 0.05 * hh), (hx - hrx * 0.92, hy - hry * 0.75), (hx, hy - hry * 1.07),
                            (hx + hrx * 0.92, hy - hry * 0.75), (hx + hrx * 1.04, hy + 0.05 * hh),
                            (hx + hrx * 0.75, hy + hry * 0.6), (hx, hy + hry * 0.72), (hx - hrx * 0.75, hy + hry * 0.6)])
                taper(d, k, (hx, hy + 0.1 * hh), (hx + 0.05 * hh, yn + 0.5 * hh), hh * 0.15, hh * 0.08)

        def arms_upper(d, k):
            if self.pose == 'buste':
                for sx in (-1, 1):
                    sh = J[sx][0]
                    taper(d, k, sh, (sh[0] + sx * 0.1 * hh, H * 1.2), hh * 0.26, hh * 0.22)
                return
            for sx in (-1, 1):
                sh, el, wr = J[sx]
                taper(d, k, sh, el, hh * 0.24, hh * 0.18)

        def forearms(d, k):
            if self.pose == 'buste':
                return
            for sx in (-1, 1):
                sh, el, wr = J[sx]
                taper(d, k, el, wr, hh * 0.18, hh * 0.12)

        def hands(d, k):
            if self.pose == 'buste':
                return
            for sx in (-1, 1):
                sh, el, wr = J[sx]
                if self.arms in ('devant', 'bras') or self.pose in ('genoux', 'assis', 'chaise'):
                    if not (self.arms == 'main'):
                        continue                                    # les mains sont devant, cachées par le corps
                vx, vy = wr[0] - el[0], wr[1] - el[1]
                ln = max(1e-6, np.hypot(vx, vy))
                cx, cy = wr[0] + vx / ln * hh * 0.16, wr[1] + vy / ln * hh * 0.16
                r = hh * 0.13
                d.ellipse([(cx - r) * k, (cy - r * 1.2) * k, (cx + r) * k, (cy + r * 1.2) * k], fill=255)

        def hat(d, k):
            if self.hat == 'paille':
                d.ellipse([(hx - hh * 0.92) * k, (hy - hry * 0.78) * k, (hx + hh * 0.92) * k, (hy - hry * 0.12) * k], fill=255)
                d.ellipse([(hx - hrx * 1.02) * k, (hy - hry * 1.32) * k, (hx + hrx * 1.02) * k, (hy - hry * 0.3) * k], fill=255)
            elif self.hat == 'casquette':
                blob(d, k, [(hx - hrx * 1.06, hy - hry * 0.08), (hx - hrx * 0.96, hy - hry * 0.8), (hx, hy - hry * 1.12),
                            (hx + hrx * 0.96, hy - hry * 0.8), (hx + hrx * 1.06, hy - hry * 0.08), (hx, hy - hry * 0.0)])

        def veil(d, k):
            bot = yf + 0.08 * hh
            blob(d, k, [(hx - hrx * 0.7, hy - hry * 0.95), (hx + hrx * 0.7, hy - hry * 0.95), (hx + hrx * 1.35, hy + 0.35 * hh),
                        (x + sw * 1.18, ysh + 1.5 * hh), (x + hw * 1.6, bot), (x - hw * 1.6, bot),
                        (x - sw * 1.18, ysh + 1.5 * hh), (hx - hrx * 1.35, hy + 0.35 * hh)], steps=8)

        skirt_on = self.dress or self.long_dress
        if self.pose == 'debout':
            parts['jambes'] = m(legs)
            parts['chaussures'] = m(shoes)
        else:
            parts['bas'] = m(legs)
            if self.pose == 'genoux':
                parts['chaussures'] = m(shoes)
        parts['haut'] = m(torso)
        if skirt_on and self.pose == 'debout':
            parts['jupe'] = m(skirt)
        parts['cou'] = m(neck)
        parts['tete'] = m(head)
        parts['bras'] = m(arms_upper)
        parts['avant_bras'] = m(forearms)
        parts['mains'] = m(hands)
        parts['cheveux'] = m(hair)
        if self.front:                                              # de face : le visage, puis la frange
            fx, fy = hx, hy + 0.06 * hh
            parts['visage'] = m(lambda d, k: d.ellipse([(fx - hrx * 0.86) * k, (fy - hry * 0.78) * k,
                                                        (fx + hrx * 0.86) * k, (fy + hry * 0.92) * k], fill=255))
            parts['frange'] = m(lambda d, k: blob(d, k, [(fx - hrx * 0.95, fy - hry * 0.2), (fx - hrx * 0.8, fy - hry * 0.85),
                                                         (fx, fy - hry * 1.0), (fx + hrx * 0.8, fy - hry * 0.85),
                                                         (fx + hrx * 0.95, fy - hry * 0.2), (fx + hrx * 0.4, fy - hry * 0.42),
                                                         (fx, fy - hry * 0.36), (fx - hrx * 0.4, fy - hry * 0.42)], steps=6))
        if self.hat:
            parts['chapeau'] = m(hat)
        if self.veil:
            parts['voile'] = m(veil)
        # contours vivants : un même champ de déplacement doux pour toutes les pièces
        rs = np.random.RandomState(self.seed + 1)
        g = 6
        y0, y1 = int(max(0, t - hh)), int(min(H, yf + hh))
        x0, x1 = int(max(0, x - 3 * hh)), int(min(W, x + 3 * hh))
        if y1 - y0 > 4 and x1 - x0 > 4:
            dxf = np.asarray(Image.fromarray(rs.randn(g, g).astype(np.float32), 'F').resize((x1 - x0, y1 - y0), Image.BICUBIC))
            dyf = np.asarray(Image.fromarray(rs.randn(g, g).astype(np.float32), 'F').resize((x1 - x0, y1 - y0), Image.BICUBIC))
            amp = hh * 0.05
            yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
            sx_ = np.clip(xx + dxf * amp, 0, W - 1)
            sy_ = np.clip(yy + dyf * amp, 0, H - 1)
            ix0, iy0 = np.floor(sx_).astype(int), np.floor(sy_).astype(int)
            ix1, iy1 = np.minimum(ix0 + 1, W - 1), np.minimum(iy0 + 1, H - 1)
            fx, fy = sx_ - ix0, sy_ - iy0
            for kname, v in parts.items():
                s_ = ((v[iy0, ix0] * (1 - fx) + v[iy0, ix1] * fx) * (1 - fy) + (v[iy1, ix0] * (1 - fx) + v[iy1, ix1] * fx) * fy)
                v2 = v.copy()
                v2[y0:y1, x0:x1] = s_
                parts[kname] = v2
        # cheveux : bord effiloché (mèches folles), à l'échelle de la tête
        hm = parts['cheveux']
        fine = noise(W, H, 0.9, self.seed + 3, sx=0.5, sy=2.0)
        edge = np.clip(blur(hm, hh * 0.03) * (1 - hm) * 4, 0, 1)
        parts['cheveux'] = np.clip(hm + edge * (fine - 0.55) * 1.4, 0, 1)
        return parts


def shade_normal(u, r):
    """Normales approchées d'une forme (masque u) : le flou du masque fait une bosse ; (nx, ny, nz)."""
    b = blur(u, r)
    gy, gx = np.gradient(b)
    nx, ny = -gx * r * 2.4, -gy * r * 2.4
    nz = np.ones_like(nx)
    ln = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    return nx / ln, ny / ln, nz / ln


ALIAS = {'jupe': 'bas', 'avant_bras': 'bras', 'cou': 'peau', 'tete': 'peau', 'mains': 'peau', 'visage': 'peau'}


def render_person(arr, p, mats, light=(-0.5, -0.6, 0.62), amb=(0.42, 0.44, 0.5), sun=(1.0, 0.94, 0.85),
                  rim=None, shadow=None, soft=0.7, seed=0, alpha=1.0, haze=None, lwrap=None, match=0.0):
    """Pose la personne p sur arr (flottants 0 à 1). mats : matière -> couleur, ou (couleur, genre) avec
    genre 'tissu' (plis verticaux), 'laine', 'cheveux' (mèches, reflet), 'peau', 'fleurs' (robe à fleurs),
    'uni'. Les matières absentes se replient : jupe -> bas, avant_bras -> bras -> haut, cou/tete/mains ->
    peau, jambes -> peau si robe, sinon bas. light : direction d'où vient la lumière (x, y de l'écran, z
    vers l'objectif ; z < 0 : contre-jour). amb : lumière du ciel ; sun : lumière directe. rim : (couleur,
    dx, dy) : liseré de contre-jour du côté (dx, dy). shadow : (dx, dy, force) : ombre portée au sol, la
    silhouette couchée vers (dx, dy) par unité de hauteur. haze : (couleur, force) : voile de distance.
    Intégration (V2-RETOUCHES : la revue voyait des figures en aplat collées sur les photos) : lwrap = (rayon,
    force) : la lumière du fond déborde sur les bords de la personne (« light wrap » : un fond clair mange
    son contour, comme sur un vrai négatif) ; match (0 à 1) : la personne prend la dominante de couleur du
    décor autour d'elle ; soft : flou (mise au point, bouger) de la personne et de son contour."""
    H, W = arr.shape[:2]
    parts = p.draw(W, H)
    body = np.zeros((H, W), np.float32)
    for kname, v in parts.items():
        if kname != 'voile':
            body = np.maximum(body, v)
    L = np.asarray(light, np.float32)
    L = L / np.linalg.norm(L)
    rs = np.random.RandomState(seed)
    yf = p.yf
    if shadow is not None:
        dx, dy, k = shadow
        im = Image.fromarray((body * 255).astype(np.uint8))
        # point (x, y) au-dessus du sol -> ombre en (x + (yf - y) dx, yf + (yf - y) dy) ; inverse pour transform
        # y = yf - (y' - yf) / dy ; x = x' - (yf - y) dx = x' - (y' - yf) dx / dy
        inv = (1, -dx / dy, dx / dy * yf, 0, -1 / dy, yf + yf / dy)
        sh = np.asarray(im.transform((W, H), Image.AFFINE, inv, resample=Image.BILINEAR), np.float32) / 255.0
        sh *= (np.arange(H)[:, None] >= yf - p.hh * 0.25)
        arr = arr * (1 - k * blur(sh, p.hh * 0.1)[..., None])
        cont = mask(W, H, lambda d, kk: d.ellipse([(p.x - p.hh * 0.75) * kk, (yf - p.hh * 0.14) * kk,
                                                    (p.x + p.hh * 0.75) * kk, (yf + p.hh * 0.14) * kk], fill=255))
        arr = arr * (1 - 0.6 * min(1.0, k * 1.6) * blur(cont, p.hh * 0.1)[..., None])
    nx, ny, nz = shade_normal(body, p.hh * 0.42)
    lam = np.clip(nx * L[0] + ny * L[1] + nz * L[2], 0, 1)
    wrap = np.clip((nx * L[0] + ny * L[1] + nz * L[2] + 0.35) / 1.35, 0, 1)
    sunv = np.asarray(sun, np.float32)
    ambv = np.asarray(amb, np.float32)
    sky = 0.7 + 0.3 * np.clip(-ny + 0.2, 0, 1)                    # le ciel éclaire plus le haut des formes
    light_rgb = ambv[None, None, :] * sky[..., None] + sunv[None, None, :] * (0.75 * lam + 0.25 * wrap * (L[2] > 0))[..., None]
    out = np.zeros((H, W, 3), np.float32)
    acc = np.zeros((H, W), np.float32)
    skirt = 'jupe' in parts
    for name in ('jambes', 'bas', 'chaussures', 'cou', 'jupe', 'haut', 'tete', 'bras', 'avant_bras', 'mains', 'cheveux',
                 'visage', 'frange', 'chapeau'):
        if name not in parts:
            continue
        mk = parts[name]
        key = name
        while key not in mats:
            if key == 'jambes':
                key = 'peau' if skirt else 'bas'
            elif key == 'bras':
                key = 'haut'
            elif key == 'frange':
                key = 'cheveux'
            elif key in ALIAS:
                key = ALIAS[key]
            else:
                break
        spec = mats.get(key, (0.3, 0.3, 0.3))
        if isinstance(spec, tuple) and len(spec) == 2 and isinstance(spec[1], str):
            col, kind = spec
        else:
            col, kind = spec, ('peau' if key == 'peau' else 'tissu')
        col = np.asarray(col, np.float32)[None, None, :] * np.ones((H, W, 1), np.float32)
        if kind == 'tissu':
            folds = noise(W, H, 2.4, rs.randint(1 << 30), sx=1.0, sy=5.0)
            tex = 0.8 + 0.32 * folds + 0.06 * noise(W, H, 1.0, rs.randint(1 << 30))
        elif kind == 'laine':
            tex = 0.86 + 0.2 * noise(W, H, 1.4, rs.randint(1 << 30)) + 0.06 * noise(W, H, 0.4, rs.randint(1 << 30))
        elif kind == 'cheveux':
            strands = noise(W, H, 1.0, rs.randint(1 << 30), sx=0.5, sy=7.0)
            tex = 0.7 + 0.55 * strands
        elif kind == 'fleurs':
            fl = noise(W, H, 0.6, rs.randint(1 << 30))
            dots = np.clip((fl - 0.62) * 8, 0, 1)
            col = col * (1 - 0.7 * dots[..., None]) + np.array([0.92, 0.84, 0.72], np.float32) * 0.85 * dots[..., None]
            tex = 0.84 + 0.26 * noise(W, H, 2.4, rs.randint(1 << 30), sy=5.0)
        elif kind == 'peau':
            tex = 0.95 + 0.08 * noise(W, H, 2.6, rs.randint(1 << 30))
        elif kind == 'brule':                                       # visage brûlé par le flash : blanc, sans traits
            tex = 0.97 + 0.04 * noise(W, H, 2.6, rs.randint(1 << 30))
        else:
            tex = np.ones((H, W), np.float32)
        if kind == 'brule':                                         # brûlé au centre, la peau revient sur les bords
            fall = blur(mk, p.hh * 0.28) * mk
            c = col * tex[..., None] * light_rgb * (0.78 + 1.0 * fall ** 4)[..., None]
        else:
            c = col * tex[..., None] * light_rgb
        if kind == 'cheveux':                                       # reflet en bande sur le haut de la tête
            band = np.exp(-((ny + 0.45) / 0.22) ** 2) * np.clip(lam * 1.4, 0, 1)
            c = c + (band * strands * 0.22)[..., None] * sunv
        ao = np.clip(blur(mk, p.hh * 0.07) - mk, 0, 1) * acc       # la pièce posée assombrit ce qu'elle couvre
        out *= (1 - 0.5 * ao)[..., None]
        out = out * (1 - mk[..., None]) + c * mk[..., None]
        acc = np.maximum(acc, mk)
    if 'voile' in parts:                                            # tulle blanc translucide, par-dessus
        vm = parts['voile']
        vt = 0.75 + 0.3 * noise(W, H, 1.6, rs.randint(1 << 30), sx=0.7, sy=6.0)
        vcol = np.asarray(mats.get('voile', (0.94, 0.93, 0.9)), np.float32)
        vnx, vny, vnz = shade_normal(vm, p.hh * 0.6)
        vl = ambv * (0.8 + 0.2 * vnz[..., None]) + sunv * np.clip(vnx * L[0] + vny * L[1] + vnz * L[2], 0, 1)[..., None]
        vc = vcol * vl * vt[..., None]
        a = (vm * 0.6)[..., None]
        out = out * (1 - a) + vc * a
        acc = np.maximum(acc, vm * 0.6)
    if 'visage' in parts and mats.get('visage', (0, ''))[1:] == ('brule',):
        glow = blur(parts['visage'], p.hh * 0.12)                   # le halo autour de la surexposition
        out = out + glow[..., None] * np.asarray(mats['visage'][0], np.float32) * 0.35
        acc = np.maximum(acc, np.clip(glow * 1.2, 0, 1) * (acc > 0.01))
    if rim is not None:
        rc, dx, dy = rim
        edge = np.clip(acc - shift(acc, dx, dy), 0, 1)
        out = out + blur(edge, 0.9)[..., None] * np.asarray(rc, np.float32)
    if match > 0:
        bgm = blur(arr, p.hh * 2.5)
        cast = bgm / np.maximum(bgm.mean(-1, keepdims=True), 1e-3)
        out = out * (1 - match + match * np.clip(cast, 0.5, 1.6))
    if lwrap is not None:
        wr, wk = lwrap
        av = np.clip(acc, 0, 1)
        inv = 1 - av
        bgw = blur(arr * inv[..., None], wr) / np.maximum(blur(inv, wr), 1e-3)[..., None]
        band = np.clip(av * (1 - blur(av, wr)) * 2.2, 0, 1)
        out = out + bgw * (band * wk)[..., None]
    if haze is not None:
        hc, hk = haze
        out = out * (1 - hk) + np.asarray(hc, np.float32) * hk
    if soft:
        acc_b = blur(acc, soft)
        out = blur(out * acc[..., None], soft) / np.maximum(acc_b, 1e-4)[..., None]
        acc = acc_b
    a = (np.clip(acc, 0, 1) * alpha)[..., None]
    return arr * (1 - a) + np.clip(out, 0, 1.5) * a


# ------------------------------------------------------------------ tirage : couleurs, grain, usure

def develop(arr, rs, era='couleur', blur_px=0.7, grain=0.03, fade=0.5, vignette=0.25, warm=0.5):
    """Développe une image « vue par l'objectif » en tirage : flou d'objectif, courbe de film (noirs levés,
    blancs adoucis), couleurs passées (era 'couleur' : film des années 2000, plus ou moins passé ;
    'sepia' : argentique des années 20 à 70 viré sépia ; 'flash' : comme 'couleur'), grain, vignette."""
    H, W = arr.shape[:2]
    a = blur(arr, blur_px)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    vig = 1 - vignette * (((xx - W / 2) / (W * 0.62)) ** 2 + ((yy - H / 2) / (H * 0.62)) ** 2)
    a = a * vig[..., None]
    if era == 'sepia':
        lum = a @ np.array([0.3, 0.59, 0.11], np.float32)
        lum = np.clip((lum - 0.03) * 1.08, 0, 1)
        lum = lum / (lum + 0.12) * 1.12                          # épaule douce
        lo = np.array([0.16, 0.11, 0.07], np.float32)
        mid = np.array([0.62, 0.47, 0.32], np.float32)
        hi = np.array([0.94, 0.88, 0.74], np.float32)
        t = np.clip(lum, 0, 1)[..., None]
        a = np.where(t < 0.5, lo + (mid - lo) * (t / 0.5), mid + (hi - mid) * ((t - 0.5) / 0.5))
        a = a * (1 - fade * 0.25) + fade * 0.25 * np.array([0.78, 0.7, 0.56])
    else:
        lum = a.mean(-1, keepdims=True)
        sat = 0.82 - 0.2 * fade
        a = lum + (a - lum) * sat
        # film passé : le cyan s'en va le premier (dominante rouge-magenta), noirs levés, blancs crème
        a = a * np.array([1.0 + 0.05 * warm, 1.0 - 0.01 * warm, 1.0 - 0.1 * warm], np.float32)
        a = 0.05 * fade + 0.03 + a * (0.92 - 0.06 * fade)
        a = a + fade * 0.05 * (1 - a) * np.array([0.4, 0.1, -0.3], np.float32)
        a = np.clip(a, 0, 1)
        a = a * a * (3 - 2 * a) * 0.35 + a * 0.65                 # courbe en S douce
    # grain : un peu plus gros que le pixel, plus fort dans les gris moyens
    g = rs.randn(H, W).astype(np.float32)
    g = blur(g, 0.6) * 1.6
    gc = blur(rs.randn(H, W, 3).astype(np.float32), 0.9) * 0.35
    lum = a.mean(-1, keepdims=True)
    k = grain * (0.6 + 1.6 * lum * (1 - lum))
    a = a + (g[..., None] + gc * (0 if era == 'sepia' else 1)) * k
    return np.clip(a, 0, 1)


def wear(arr, rs, amount=1.0, scratches=6, dust=60):
    """Usure du tirage : rayures fines claires, poussière (points clairs et sombres), un pli léger."""
    H, W = arr.shape[:2]
    over = Image.new('L', (W * 2, H * 2), 0)
    d = ImageDraw.Draw(over)
    for _ in range(scratches):
        x0, y0 = rs.uniform(0, W * 2), rs.uniform(0, H * 2)
        ang = rs.uniform(0, np.pi)
        ln = rs.uniform(0.1, 0.5) * W * 2
        pts = []
        for t in np.linspace(0, 1, 12):
            pts.append((x0 + np.cos(ang) * ln * t + rs.uniform(-2, 2), y0 + np.sin(ang) * ln * t + rs.uniform(-2, 2)))
        d.line(pts, fill=int(rs.uniform(60, 150)), width=1)
    light = np.asarray(over.resize((W, H), Image.BOX), np.float32) / 255.0
    dk = Image.new('L', (W, H), 0)
    dd = ImageDraw.Draw(dk)
    for _ in range(dust):
        x, y, r = rs.uniform(0, W), rs.uniform(0, H), rs.uniform(0.4, 1.6)
        dd.ellipse([x - r, y - r, x + r, y + r], fill=int(rs.uniform(90, 255)))
    dark = blur(np.asarray(dk, np.float32) / 255.0, 0.5)
    lt = Image.new('L', (W, H), 0)
    dl = ImageDraw.Draw(lt)
    for _ in range(dust // 2):
        x, y, r = rs.uniform(0, W), rs.uniform(0, H), rs.uniform(0.4, 1.2)
        dl.ellipse([x - r, y - r, x + r, y + r], fill=int(rs.uniform(90, 255)))
    lite = blur(np.asarray(lt, np.float32) / 255.0, 0.5)
    a = arr + (light * 0.35 * amount + lite * 0.5 * amount)[..., None] * (1 - arr)
    a = a * (1 - dark * 0.55 * amount)[..., None]
    return np.clip(a, 0, 1)


def border(arr, rs, kind='blanc', margin=0.045, paper=(0.95, 0.94, 0.9), yellow=0.5):
    """Le papier autour de l'image : 'blanc' (bord blanc des tirages), 'dentele' (bord dentelé des vieux
    tirages), 'ovale' (cache ovale crème d'un portrait), 'aucun' (tirage sans bord). Coins jaunis, bord
    du papier un peu sale. L'image garde sa taille : le bord est pris dessus."""
    H, W = arr.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    pap = np.asarray(paper, np.float32)
    tex = 0.97 + 0.05 * noise(W, H, 2.0, rs.randint(1 << 30)) + 0.015 * noise(W, H, 0.6, rs.randint(1 << 30))
    card = pap[None, None, :] * tex[..., None]
    mx, my = margin * W, margin * W
    if kind == 'aucun':
        inside = np.ones((H, W), np.float32)
    elif kind == 'ovale':
        o = ((xx - W / 2) / (W * 0.43)) ** 2 + ((yy - H / 2) / (H * 0.44)) ** 2
        inside = np.clip((1 - o) * min(W, H) * 0.25, 0, 1)
        bevel = np.exp(-((o - 1) * min(W, H) * 0.12) ** 2)       # le biseau du cache, plus clair
        card = card * (1 + 0.08 * bevel[..., None])
    else:
        e = np.minimum(np.minimum(xx - mx, W - 1 - mx - xx), np.minimum(yy - my, H - 1 - my - yy))
        inside = np.clip(e + 0.5, 0, 1)
        if kind == 'dentele':
            ex = np.minimum(np.minimum(xx, W - 1 - xx), np.minimum(yy, H - 1 - yy))
            per = 7.0
            tooth = 2.2 * (0.5 + 0.5 * np.cos(2 * np.pi * (xx + yy) / per))
            card_in = np.clip(ex - tooth + 0.5, 0, 1)
            card = card * card_in[..., None] + (1 - card_in[..., None]) * np.array([0.0, 0.0, 0.0])
    a = arr * inside[..., None] + card * (1 - inside[..., None])
    # jaunissement des coins et du pourtour, bord du papier plus sombre
    cx = np.minimum(xx, W - 1 - xx) / W
    cy = np.minimum(yy, H - 1 - yy) / H
    corner = np.exp(-(np.hypot(cx, cy) / 0.16) ** 2)
    edge = np.exp(-np.minimum(cx * W, cy * H) / (0.015 * W))
    n = noise(W, H, 1.6, rs.randint(1 << 30))
    ylw = np.clip(yellow * (corner * 0.6 + edge * 0.25) * (0.6 + 0.8 * n), 0, 0.6)
    a = a * (1 - ylw[..., None]) + ylw[..., None] * a * np.array([1.0, 0.86, 0.6], np.float32)
    a = a * (1 - 0.18 * edge[..., None])
    if kind == 'dentele':
        a = a * card_in[..., None] + (1 - card_in[..., None]) * np.array([0.08, 0.07, 0.06])
    return np.clip(a, 0, 1)


# ------------------------------------------------------------------ les photos

SKIN = (0.8, 0.6, 0.5)


def crop_box(key, cx, cy, cw, size):
    """Cadre d'un backplate : centre (cx, cy) et largeur cw en fractions de l'image, au rapport de size."""
    W0, H0 = Image.open(os.path.join(SRC, key + '.jpg')).size
    ch = cw * W0 / H0 * size[1] / size[0]
    if ch > 1:
        raise ValueError('cadre trop large : ' + key)
    cx = min(max(cx, cw / 2), 1 - cw / 2)                      # le cadre reste dans l'image
    cy = min(max(cy, ch / 2), 1 - ch / 2)
    return (cx - cw / 2, cy - ch / 2, cx + cw / 2, cy + ch / 2)


def studio_backdrop(W, H, rs, base, light, center=(0.5, 0.4), spread=0.55, marble=0.25):
    """Toile de fond de studio peinte : marbrures douces, plus claire derrière le sujet."""
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    r = np.hypot((xx / W - center[0]) / spread, (yy / H - center[1]) / (spread * 1.2))
    halo = np.exp(-r ** 2)
    n1 = noise(W, H, 2.6, rs.randint(1 << 30))
    n2 = noise(W, H, 1.8, rs.randint(1 << 30))
    mot = (n1 - 0.5) * marble + (n2 - 0.5) * marble * 0.4
    b, l = np.asarray(base, np.float32), np.asarray(light, np.float32)
    a = b + (l - b) * np.clip(halo + mot, 0, 1.2)[..., None]
    return np.clip(a, 0, 1)


def plage():
    """Mamie et ta mère petite (vers 2004), main dans la main au bord de l'eau, de dos, à contre-jour du
    matin ; le parasol rayé planté à côté. Plage de Blouberg (Poly Haven blouberg_sunrise_1, CC0)."""
    W, H = W4, H4
    rs = np.random.RandomState(4101)
    a = plate('blouberg_sunrise_1/IMG_0623', (0.08, 0.2, 0.86, 0.785), (W, H))
    a = np.clip(a * np.array([1.08, 1.02, 0.96]) * 1.12, 0, 1)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    # le parasol rayé, planté dans le sable à droite (plus près de l'objectif)
    px, pb, pt = W * 0.79, H * 0.97, H * 0.43
    a = a * (1 - 0.3 * blur(mask(W, H, lambda d, k: d.ellipse([(px - 150) * k, (H * 0.93) * k, (px + 60) * k, (H * 1.02) * k], fill=255)), 14)[..., None])
    pole = mask(W, H, lambda d, k: taper(d, k, (px, pb), (px - 6, pt), 3.2, 2.6))
    a = lay(a, pole, np.array([0.62, 0.6, 0.56]) * (0.7 + 0.3 * np.clip((xx - px + 3) / 4, 0, 1))[..., None])
    cx, cy, R = px - 6, pt, W * 0.19
    def canopy_fn(d, k):
        pts = [(cx - R, cy + R * 0.2)]
        for i in range(17):                                       # ourlet festonné
            u = i / 16
            xs = cx - R + 2 * R * u
            pts.append((xs, cy + R * 0.2 + (5 if i % 2 else 0)))
        pts.append((cx + R, cy + R * 0.2))
        pts += [(cx + R * 0.6, cy - R * 0.22), (cx, cy - R * 0.36), (cx - R * 0.6, cy - R * 0.22)]
        d.polygon([(x_ * k, y_ * k) for x_, y_ in pts], fill=255)
    canopy = mask(W, H, canopy_fn)
    u = (xx - cx) / R
    stripes = blur((np.sin(np.arctan2(u, 0.55) * 9.0) > 0).astype(np.float32), 0.7)
    ccol = np.array([0.78, 0.13, 0.1])[None, None] * stripes[..., None] + np.array([0.93, 0.9, 0.84])[None, None] * (1 - stripes[..., None])
    dome = np.clip(1 - u ** 2, 0, 1) ** 0.5
    ccol = ccol * (0.42 + 0.5 * dome + 0.15 * np.clip((cy - yy) / (R * 0.3), 0, 1))[..., None]
    ccol = ccol + np.array([0.25, 0.18, 0.15]) * np.exp(-((yy - (cy - R * 0.3)) / 8) ** 2)[..., None] * dome[..., None] * 0.3
    a = lay(a, canopy, ccol)
    light = (0.15, -0.35, -0.9)                                    # le soleil derrière eux, sur la mer
    # (contre-jour : leur dos est dans l'ombre, sombre et terne ; le ciel mange leur contour)
    common = dict(light=light, amb=(0.3, 0.27, 0.31), sun=(1.0, 0.85, 0.72), rim=((0.75, 0.55, 0.42), 0, 2),
                  shadow=(0.12, 0.45, 0.3), soft=1.1, haze=((0.75, 0.68, 0.72), 0.1), lwrap=(4.5, 0.6), match=0.35)
    m = Person(W * 0.43, H * 0.89, H * 0.43, 'femme', hair='permanente', hat='paille', dress=True, arms='main', seed=41)
    a = render_person(a, m, {'haut': ((0.64, 0.14, 0.16), 'fleurs'), 'bas': ((0.64, 0.14, 0.16), 'fleurs'),
                             'peau': (SKIN, 'peau'), 'cheveux': ((0.34, 0.24, 0.17), 'cheveux'),
                             'chapeau': ((0.9, 0.8, 0.56), 'laine'), 'chaussures': (0.75, 0.65, 0.5)},
                      seed=41, **common)
    c = Person(W * 0.315, H * 0.905, H * 0.235, 'fille', hair='carre', arms='main', seed=42)
    a = render_person(a, c, {'haut': ((0.95, 0.78, 0.2), 'uni'), 'bas': ((0.95, 0.78, 0.2), 'uni'), 'jambes': (SKIN, 'peau'),
                             'peau': (SKIN, 'peau'), 'cheveux': ((0.36, 0.22, 0.12), 'cheveux'), 'chaussures': (SKIN, 'peau')},
                      seed=42, **common)
    # le seau de l'enfant, renversé dans le sable
    sb = mask(W, H, lambda d, k: d.polygon([(W * 0.215 * k, H * 0.935 * k), (W * 0.245 * k, H * 0.93 * k),
                                             (W * 0.25 * k, H * 0.965 * k), (W * 0.212 * k, H * 0.968 * k)], fill=255))
    a = lay(a, blur(sb, 0.6), np.array([0.2, 0.45, 0.8]) * 0.75)
    a = develop(a, rs, 'couleur', blur_px=0.75, grain=0.028, fade=0.55, vignette=0.24, warm=0.75)
    a = wear(a, rs, 0.7)
    save(border(a, rs, 'blanc', 0.042), 'plage.png')


def jardin():
    """La maison, l'été où Papi a repeint les volets (vers 2008) : les volets verts tout neufs, l'échelle encore
    contre le mur, le pot de peinture au pied ; Papi n'est pas sur la photo (c'est lui qui la prend). Façade
    rose aux volets verts (Poly Haven vignaioli, CC0), ciel couvert. (V2-RETOUCHES : la silhouette en bleu
    de travail, collée sur la façade, est retirée.)"""
    W, H = W4, H4
    rs = np.random.RandomState(4102)
    a = plate('vignaioli/DSC07532', crop_box('vignaioli/DSC07532', 0.74, 0.5, 0.52, (W, H)), (W, H))
    a = np.clip(a * np.array([1.06, 1.0, 0.94]) * 1.08, 0, 1)
    # l'échelle contre le mur, à droite, et le pot de peinture verte posé au pied
    def ladder(d, k):
        for x_ in (W * 0.7, W * 0.77):
            d.line([((x_ + 30) * k, H * 0.22 * k), (x_ * k, H * 0.92 * k)], fill=255, width=int(5 * k))
        for i in range(9):
            u = (i + 0.5) / 9
            y_ = H * (0.22 + 0.7 * u)
            d.line([((W * 0.7 + 30 * (1 - u)) * k, y_ * k), ((W * 0.77 + 30 * (1 - u)) * k, y_ * k)], fill=255, width=int(4 * k))
    lad = blur(mask(W, H, ladder), 0.7)
    a = a * (1 - 0.3 * blur(shift(lad, 10, 4), 4)[..., None])
    # (montants éclairés du côté du ciel, bois grisé)
    lit = 0.72 + 0.28 * np.clip(blur(lad, 2.0) - shift(blur(lad, 2.0), 3, 0), 0, 1) * 3
    a = lay(a, lad, np.array([0.5, 0.43, 0.34]) * (lit * (0.85 + 0.15 * noise(W, H, 1.0, 9, sy=6)))[..., None])
    pot = mask(W, H, lambda d, k: d.rectangle([(W * 0.6) * k, (H * 0.86) * k, (W * 0.64) * k, (H * 0.925) * k], fill=255))
    a = a * (1 - 0.35 * blur(shift(pot, 6, 3), 3)[..., None])
    a = lay(a, pot, np.array([0.62, 0.6, 0.56]) * (0.75 + 0.3 * np.clip((np.arange(W)[None, :] - W * 0.6) / (W * 0.04), 0, 1))[..., None])
    drip = mask(W, H, lambda d, k: d.rectangle([(W * 0.6) * k, (H * 0.86) * k, (W * 0.64) * k, (H * 0.873) * k], fill=255))
    a = lay(a, drip, (0.12, 0.3, 0.2))
    a = develop(a, rs, 'couleur', blur_px=0.7, grain=0.025, fade=0.4, vignette=0.2, warm=0.6)
    a = wear(a, rs, 0.5)
    save(border(a, rs, 'blanc', 0.04, yellow=0.35), 'jardin.png')


def labo():
    """Papi devant le labo, le jour de sa retraite (vers 2012) : de dos, en costume, le sac du cadeau de
    départ à la main, il regarde le bâtiment une dernière fois (Poly Haven residential_garden, CC0)."""
    W, H = W4, H4
    rs = np.random.RandomState(4103)
    a = plate('residential_garden/IMG_0603', crop_box('residential_garden/IMG_0603', 0.47, 0.5, 0.74, (W, H)), (W, H))
    a = np.clip((a - 0.02) * 1.06, 0, 1)
    p = Person(W * 0.4, H * 0.8, H * 0.27, 'homme', hair='court', arms='bas', seed=61, turn=-0.2)
    a = render_person(a, p, {'haut': ((0.17, 0.18, 0.21), 'tissu'), 'bas': ((0.15, 0.16, 0.19), 'tissu'),
                             'peau': (SKIN, 'peau'), 'cheveux': ((0.38, 0.36, 0.34), 'cheveux'), 'chaussures': (0.06, 0.05, 0.05)},
                      light=(-0.4, -0.7, 0.4), amb=(0.62, 0.64, 0.68), sun=(0.6, 0.58, 0.54),
                      shadow=(-0.1, 0.15, 0.3), soft=0.9, seed=62, lwrap=(2.5, 0.3), match=0.4)
    # le sac du cadeau de départ (papier kraft, anses en corde), dans la main droite
    J, _ = p.joints()
    wx, wy = J[1][2]
    bag = blur(mask(W, H, lambda d, k: d.rectangle([(wx - 6) * k, (wy + 4) * k, (wx + 7) * k, (wy + 21) * k], fill=255)), 0.8)
    a = lay(a, bag, np.array([0.62, 0.48, 0.32]) * (0.9 + 0.1 * noise(W, H, 2.0, 7))[..., None])
    a = develop(a, rs, 'couleur', blur_px=0.55, grain=0.018, fade=0.15, vignette=0.15, warm=0.3)
    a = wear(a, rs, 0.25, scratches=2, dust=20)
    save(border(a, rs, 'aucun', yellow=0.15), 'labo.png')


def _couple(a, rs, x, yf, h, seed, light, amb, sun, gap=0.95, shadow=None):
    """Henriette et Albert, de dos, côte à côte : la mariée (robe longue, voile) à gauche, lui à droite."""
    hh = h / 7.5
    b = Person(x - gap * hh * 0.75, yf, h * 0.95, 'femme', hair='chignon', long_dress=True, veil=True, arms='devant', seed=seed)
    g = Person(x + gap * hh * 0.85, yf, h * 1.02, 'homme', hair='court', arms='bas', seed=seed + 1)
    a = render_person(a, g, {'haut': ((0.08, 0.08, 0.09), 'tissu'), 'bas': ((0.08, 0.08, 0.09), 'tissu'),
                             'peau': (SKIN, 'peau'), 'cheveux': ((0.12, 0.09, 0.07), 'cheveux'), 'chaussures': (0.03, 0.03, 0.03)},
                      light=light, amb=amb, sun=sun, shadow=shadow, soft=1.3, seed=seed + 2, lwrap=(3.5, 0.35), match=0.3)
    # (robe et voile un peu moins blancs : la nuit, dans le couloir, la mariée brillait comme une lampe)
    a = render_person(a, b, {'haut': ((0.8, 0.78, 0.74), 'tissu'), 'bas': ((0.81, 0.79, 0.75), 'tissu'),
                             'peau': (SKIN, 'peau'), 'cheveux': ((0.2, 0.14, 0.1), 'cheveux'), 'voile': (0.84, 0.83, 0.8)},
                      light=light, amb=amb, sun=sun, shadow=shadow, soft=1.3, seed=seed + 3, lwrap=(3.5, 0.35), match=0.3)
    return a


def mariage():
    """Le mariage d'Henriette et Albert (vers 1975), en sépia : ils passent sous le porche de l'église, de
    dos, elle en voile long (Poly Haven small_cathedral_02, CC0). Tirage aux bords dentelés."""
    W, H = H4, W4
    rs = np.random.RandomState(4104)
    a = plate('small_cathedral_02/DSC_0681', crop_box('small_cathedral_02/DSC_0681', 0.535, 0.55, 0.42, (W, H)), (W, H))
    a = _couple(a, rs, W * 0.5, H * 0.9, H * 0.42, 71, light=(0.2, -0.6, 0.5), amb=(0.6, 0.6, 0.62), sun=(0.7, 0.68, 0.64),
                shadow=(0.1, 0.18, 0.3))
    a = np.clip((a - 0.12) * 1.3, 0, 0.94)
    a = develop(a, rs, 'sepia', blur_px=1.1, grain=0.04, fade=0.45, vignette=0.32)
    a = wear(a, rs, 1.0, scratches=9, dust=90)
    save(border(a, rs, 'dentele', 0.05, paper=(0.93, 0.9, 0.82), yellow=0.6), 'mariage.png')


def gp_mariage():
    """Le même mariage, la photo de la commode : ils s'arrêtent devant le portail du parvis, de dos, plus
    près ; cache ovale crème (Poly Haven small_cathedral_02, CC0). Sépia plus froid, tirage de studio."""
    W, H = H4, W4
    rs = np.random.RandomState(4105)
    a = plate('small_cathedral_02/DSC_0701', crop_box('small_cathedral_02/DSC_0701', 0.58, 0.48, 0.4, (W, H)), (W, H))
    a = _couple(a, rs, W * 0.5, H * 0.86, H * 0.47, 81, light=(-0.75, -0.45, 0.35), amb=(0.42, 0.42, 0.44),
                sun=(0.95, 0.92, 0.86), gap=0.9, shadow=(0.25, 0.18, 0.35))
    a = np.clip((a - 0.1) * 1.26, 0, 0.94)
    a = develop(a, rs, 'sepia', blur_px=1.2, grain=0.035, fade=0.35, vignette=0.4)
    a = a * np.array([0.97, 0.99, 1.02])
    a = wear(a, rs, 0.6, scratches=4, dust=40)
    save(border(a, rs, 'ovale', paper=(0.86, 0.82, 0.72), yellow=0.4), 'gp_mariage.png')


def noel():
    """Ta mère, petite (vers 2004), à genoux devant le sapin, de dos, au flash : le premier plan brûlé,
    le fond qui tombe dans le noir, les boules qui renvoient l'éclair (Poly Haven christmas_photo_studio_07,
    CC0, le salon passé de nuit)."""
    W, H = W4, H4
    rs = np.random.RandomState(4106)
    a = plate('christmas_photo_studio_07/15', crop_box('christmas_photo_studio_07/15', 0.56, 0.6, 0.78, (W, H)), (W, H))
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    # la nuit, au flash : la lumière tombe avec la distance (le haut de l'image est plus loin), tungstène au fond
    near = np.clip((yy / H - 0.15) / 0.85, 0, 1)
    flash = 0.22 + 1.05 * near ** 1.3 * np.exp(-((xx / W - 0.5) / 0.75) ** 2)
    a = a * flash[..., None] * np.array([1.0, 0.9, 0.78]) + (1 - flash[..., None]) * a * 0.06 * np.array([1.0, 0.7, 0.4])
    hi = np.clip(a.max(-1) - 0.55, 0, 1)                           # les reflets de l'éclair dans les boules
    a = a + blur(hi, 2.0)[..., None] * 0.6
    box = mask(W, H, lambda d, k: d.polygon([(W * 0.5 * k, H * 0.74 * k), (W * 0.66 * k, H * 0.72 * k),
                                              (W * 0.67 * k, H * 0.86 * k), (W * 0.51 * k, H * 0.88 * k)], fill=255))
    rib = mask(W, H, lambda d, k: d.line([(W * 0.585 * k, H * 0.73 * k), (W * 0.59 * k, H * 0.87 * k)], fill=255, width=int(7 * k)))
    side = mask(W, H, lambda d, k: d.polygon([(W * 0.66 * k, H * 0.72 * k), (W * 0.7 * k, H * 0.75 * k),
                                               (W * 0.705 * k, H * 0.88 * k), (W * 0.67 * k, H * 0.86 * k)], fill=255))
    lid = mask(W, H, lambda d, k: d.polygon([(W * 0.5 * k, H * 0.74 * k), (W * 0.66 * k, H * 0.72 * k),
                                              (W * 0.7 * k, H * 0.75 * k), (W * 0.54 * k, H * 0.77 * k)], fill=255))
    stars = (np.sin(xx * 0.55) * np.sin(yy * 0.55 + xx * 0.12) > 0.82).astype(np.float32)   # papier cadeau à pois dorés
    paper = np.array([0.15, 0.32, 0.62]) * (0.85 + 0.15 * noise(W, H, 1.5, 21))[..., None]
    paper = paper * (1 - 0.8 * blur(stars, 0.6)[..., None]) + np.array([0.9, 0.75, 0.35]) * 0.8 * blur(stars, 0.6)[..., None]
    a = lay(a, box, paper * 0.95)
    a = lay(a, side, paper * 0.55)
    a = lay(a, lid, paper * 1.25)
    rib2 = mask(W, H, lambda d, k: d.line([(W * 0.52 * k, H * 0.755 * k), (W * 0.68 * k, H * 0.735 * k)], fill=255, width=int(6 * k)))
    a = lay(a, np.maximum(rib, rib2) * np.maximum(box, lid), (0.95, 0.8, 0.35))
    bow = mask(W, H, lambda d, k: (d.ellipse([W * 0.565 * k, H * 0.71 * k, W * 0.59 * k, H * 0.745 * k], fill=255),
                                   d.ellipse([W * 0.59 * k, H * 0.705 * k, W * 0.618 * k, H * 0.742 * k], fill=255)))
    a = lay(a, blur(bow, 0.8), np.array([0.98, 0.84, 0.38]) * 0.95)
    a = a + blur(lid * (noise(W, H, 0.5, 22) > 0.8), 1.5)[..., None] * 0.5
    # (le paquet est un peu derrière le plan de netteté : flou léger, le flash tombe plus bas que lui)
    gm = np.clip(blur(np.maximum(np.maximum(box, side), np.maximum(lid, bow)), 2.0) * 1.5, 0, 1)
    gfall = 0.8 + 0.2 * np.clip((H * 0.74 - yy) / (H * 0.14) + 1, 0, 1)
    a = a * (1 - gm[..., None]) + blur(a, 1.3) * (gfall * gm)[..., None]
    c = Person(W * 0.44, H * 1.0, H * 0.72, 'fille', pose='genoux', hair='carre', arms='devant', seed=91, turn=0.4)
    a = render_person(a, c, {'haut': ((0.75, 0.1, 0.14), 'laine'), 'bas': ((0.75, 0.1, 0.14), 'laine'),
                             'peau': (SKIN, 'peau'), 'cheveux': ((0.3, 0.18, 0.1), 'cheveux'), 'chaussures': ((0.85, 0.75, 0.68), 'peau')},
                      light=(0.05, -0.1, 1.0), amb=(0.2, 0.17, 0.15), sun=(1.1, 1.04, 0.98), soft=4.5, seed=92,
                      lwrap=(6.0, 0.2))
    a = develop(a, rs, 'couleur', blur_px=0.65, grain=0.03, fade=0.45, vignette=0.3, warm=0.8)
    a = wear(a, rs, 0.6)
    save(border(a, rs, 'blanc', 0.04, yellow=0.45), 'noel.png')


def scribble(a, rs, region, ink=(0.07, 0.085, 0.2), strokes=760):
    """Un visage rayé au stylo à bille (GDD : « visages hors cadre ou rayés au stylo » ; comme la photo de
    Manon au visage rayé de sa chambre) : des boucles serrées et des zigzags d'encre bleu-noir, qui
    débordent un peu de la zone (region : masque 0 à 1) jusqu'à la couvrir entièrement ; l'encre épaisse
    brille un peu ; trois traits appuyés ont rayé l'émulsion jusqu'au papier. Rend l'image et le masque."""
    H, W = a.shape[:2]
    ys, xs = np.nonzero(region > 0.5)
    cy, cx = ys.mean(), xs.mean()
    ry, rx = (ys.max() - ys.min()) / 2.0, (xs.max() - xs.min()) / 2.0
    ss = 3
    im = Image.new('L', (W * ss, H * ss), 0)
    d = ImageDraw.Draw(im)
    for k in range(strokes):
        ang, r = rs.uniform(0, 2 * np.pi), np.sqrt(rs.uniform(0, 1))
        x, y = cx + np.cos(ang) * r * rx * 1.05, cy + np.sin(ang) * r * ry * 1.05
        heading = rs.uniform(0, 2 * np.pi)
        loop = rs.uniform(0.25, 0.65) * (1 if rs.uniform() < 0.5 else -1)
        step = rs.uniform(1.8, 3.4)
        pts = []
        for i in range(rs.randint(25, 70)):
            heading += loop + rs.normal(0, 0.3)
            x += np.cos(heading) * step
            y += np.sin(heading) * step * 1.1
            dx, dy = (x - cx) / (rx * 1.12), (y - cy) / (ry * 1.12)
            if dx * dx + dy * dy > 1.0:                             # la main revient sur le visage
                x -= (x - cx) * 0.18
                y -= (y - cy) * 0.18
            pts.append((x * ss, y * ss))
        d.line(pts, fill=int(rs.uniform(150, 255)), width=int(rs.choice([2, 3, 3, 4])), joint='curve')
    for k in range(14):                                             # zigzags appuyés en travers
        y = cy + rs.uniform(-0.9, 0.9) * ry
        x = cx - rx * rs.uniform(0.9, 1.15)
        pts = []
        while x < cx + rx * 1.1:
            pts.append((x * ss, (y + rs.uniform(-0.12, 0.12) * ry) * ss))
            x += rs.uniform(4, 9)
            y += rs.uniform(-6, 6)
        d.line(pts, fill=255, width=5, joint='curve')
    m = np.asarray(im.resize((W, H), Image.BOX), np.float32) / 255.0
    core = np.clip(blur(region, 6.0) * 1.5 - 0.5, 0, 1)             # au cœur, l'encre bouche presque tout
    m = np.clip(np.maximum(m * 1.1, core * (0.7 + 0.2 * noise(W, H, 1.2, rs.randint(1 << 30)))), 0, 1)
    inkc = np.asarray(ink, np.float32)
    sheen = np.clip(blur(m, 1.5) - 0.8, 0, 1) * 0.5 * noise(W, H, 0.8, rs.randint(1 << 30), sx=0.3, sy=1.0)
    out = a * (1 - 0.94 * m[..., None]) + (inkc + sheen[..., None] * np.array([0.25, 0.27, 0.35])) * 0.94 * m[..., None]
    # l'émulsion rayée jusqu'au papier : trois traits clairs, un peu en relief
    sc = Image.new('L', (W * ss, H * ss), 0)
    ds = ImageDraw.Draw(sc)
    for k in range(3):
        a0 = rs.uniform(-0.6, 0.6)
        x0, y0 = cx - np.cos(a0) * rx * 0.9, cy - np.sin(a0) * ry * 0.7 + rs.uniform(-0.3, 0.3) * ry
        x1, y1 = cx + np.cos(a0) * rx * 0.95, cy + np.sin(a0) * ry * 0.7 + rs.uniform(-0.3, 0.3) * ry
        ds.line([(x0 * ss, y0 * ss), ((x0 + x1) / 2 * ss + rs.uniform(-6, 6), (y0 + y1) / 2 * ss), (x1 * ss, y1 * ss)],
                fill=255, width=3, joint='curve')
    scr = np.asarray(sc.resize((W, H), Image.BOX), np.float32) / 255.0
    out = out * (1 - 0.8 * scr[..., None]) + np.array([0.9, 0.88, 0.82]) * 0.8 * scr[..., None]
    return np.clip(out, 0, 1), m


def ecole():
    """La photo de classe de ta mère (vers 2007), fond bleu marbré, carré brun, col blanc, gilet rouge ; son
    visage a été rayé au stylo à bille, jusqu'à disparaître (V2-RETOUCHES : avant, un ovale brûlé par le
    flash, que la revue lisait comme un visage vide collé). L'ombre portée du flash sur la toile de fond."""
    W, H = H4, W4
    rs = np.random.RandomState(4107)
    a = studio_backdrop(W, H, rs, (0.14, 0.2, 0.34), (0.48, 0.6, 0.8), center=(0.5, 0.36), spread=0.5, marble=0.5)
    p = Person(W * 0.5, H * 1.3, H * 1.55, 'fille', pose='buste', hair='carre', seed=101, front=True, width=0.9)
    parts = p.draw(W, H)
    body = np.zeros((H, W), np.float32)
    for v in parts.values():
        body = np.maximum(body, v)
    a = a * (1 - 0.32 * blur(shift(body, 16, 9), 12))[..., None]     # l'ombre du flash, à droite derrière elle
    a = render_person(a, p, {'haut': ((0.56, 0.1, 0.13), 'laine'), 'peau': (SKIN, 'peau'),
                             'visage': (SKIN, 'peau'), 'cheveux': ((0.33, 0.2, 0.11), 'cheveux')},
                      light=(-0.35, -0.3, 0.88), amb=(0.34, 0.36, 0.44), sun=(0.92, 0.88, 0.82),
                      rim=((0.2, 0.25, 0.35), 2, 0), soft=1.8, seed=102, lwrap=(4.0, 0.25), match=0.15)
    # le col blanc du chemisier, rabattu sur le gilet
    hh = p.hh
    t = p.top()
    yn = t + p.B['neck'] * hh
    # (col Claudine : deux petits rabats arrondis de part et d'autre du cou)
    col = mask(W, H, lambda d, k: (blob(d, k, [(W * 0.5 - 0.02 * hh, yn + 0.02 * hh), (W * 0.5 - 0.2 * hh, yn - 0.04 * hh),
                                               (W * 0.5 - 0.44 * hh, yn + 0.1 * hh), (W * 0.5 - 0.38 * hh, yn + 0.3 * hh),
                                               (W * 0.5 - 0.12 * hh, yn + 0.33 * hh)], steps=6),
                                   blob(d, k, [(W * 0.5 + 0.02 * hh, yn + 0.02 * hh), (W * 0.5 + 0.2 * hh, yn - 0.04 * hh),
                                               (W * 0.5 + 0.44 * hh, yn + 0.1 * hh), (W * 0.5 + 0.38 * hh, yn + 0.3 * hh),
                                               (W * 0.5 + 0.12 * hh, yn + 0.33 * hh)], steps=6)))
    # le gilet : côtes du tricot, la lumière du flash qui tombe vers la droite, une patte boutonnée
    haut = parts['haut']
    xx_ = np.arange(W, dtype=np.float32)[None, :]
    ribs = 1 - 0.09 * (0.5 + 0.5 * np.sin(2 * np.pi * xx_ / 5.0))
    side = 1 - 0.26 * np.clip((xx_ - W * 0.3) / (W * 0.65), 0, 1)
    a = a * (1 - haut[..., None]) + a * (ribs * side * (0.92 + 0.08 * noise(W, H, 2.2, 7, sy=4.0)))[..., None] * haut[..., None]
    plk = mask(W, H, lambda d, k: d.line([(W * 0.5 * k, (yn + 0.3 * hh) * k), (W * 0.505 * k, H * k)], fill=255, width=int(2 * k)))
    a = a * (1 - 0.3 * blur(plk, 1.0) * haut)[..., None]
    for i in range(3):
        by = yn + (0.6 + 0.46 * i) * hh
        btn = mask(W, H, lambda d, k: d.ellipse([(W * 0.5 + 6 - 0.05 * hh) * k, (by - 0.05 * hh) * k,
                                                 (W * 0.5 + 6 + 0.05 * hh) * k, (by + 0.05 * hh) * k], fill=255))
        a = a * (1 - 0.35 * blur(shift(btn, 1, 2), 1.2))[..., None]
        a = lay(a, blur(btn, 0.7), np.array([0.8, 0.76, 0.7]) * (0.85 + 0.15 * np.clip((by - np.arange(H)[:, None]) / (0.05 * hh), -1, 1))[..., None])
    cshade = 0.78 + 0.22 * np.clip(1 - (np.arange(H)[:, None] - yn) / (0.35 * hh), 0, 1)
    a = a * (1 - 0.25 * blur(shift(col, 2, 4), 2.5))[..., None]
    a = lay(a, blur(col, 1.4) * 0.97, np.array([0.86, 0.85, 0.83]) * (cshade * (0.88 + 0.12 * noise(W, H, 2.0, 5)))[..., None])
    a = develop(a, rs, 'couleur', blur_px=1.6, grain=0.022, fade=0.35, vignette=0.15, warm=0.4)
    # le visage (et le front sous la frange) rayé au stylo, sur le tirage
    face = np.clip(parts['visage'] + parts.get('frange', 0) * parts['tete'] * 0.0, 0, 1)
    face = np.maximum(face, np.clip(blur(parts['visage'], 6.0) * 2.0 - 0.3, 0, 1))
    a, _ = scribble(a, rs, face)
    a = wear(a, rs, 0.4, scratches=2, dust=30)
    save(border(a, rs, 'blanc', 0.05, yellow=0.3), 'ecole.png')


# profil de femme tourné vers la gauche (silhouette découpée) : x, y dans un carré de 1, sommet du crâne en haut
PROFIL = [(0.52, 0.06), (0.42, 0.085), (0.36, 0.125), (0.335, 0.175), (0.33, 0.212), (0.322, 0.232), (0.3, 0.262),
          (0.283, 0.284), (0.292, 0.296), (0.31, 0.302), (0.316, 0.316), (0.307, 0.326), (0.318, 0.334),
          (0.311, 0.344), (0.326, 0.358), (0.324, 0.374), (0.342, 0.392), (0.38, 0.4), (0.415, 0.415),
          (0.425, 0.45), (0.415, 0.478), (0.405, 0.5), (0.39, 0.53), (0.35, 0.6), (0.325, 0.67), (0.315, 0.74),
          (0.29, 0.79), (0.34, 0.81), (0.42, 0.795), (0.55, 0.805), (0.68, 0.795), (0.78, 0.81), (0.82, 0.79),
          (0.8, 0.7), (0.76, 0.6), (0.69, 0.53), (0.63, 0.49), (0.6, 0.45), (0.605, 0.41), (0.64, 0.385),
          (0.69, 0.37), (0.73, 0.33), (0.745, 0.27), (0.72, 0.21), (0.67, 0.18), (0.66, 0.13), (0.61, 0.085)]


def aieule():
    """L'arrière-grand-mère (vers 1910) : son portrait en silhouette de papier noir découpé, de profil
    (chignon, col montant), collé sur un carton crème jauni, dans un cache ovale. Pas une photo : l'ombre
    découpée qu'on faisait faire à la foire ; aucun trait du visage, seulement le contour."""
    W, H = H4, W4
    rs = np.random.RandomState(4108)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    paper = np.array([0.9, 0.86, 0.75], np.float32) * (0.94 + 0.08 * noise(W, H, 2.2, 1081) + 0.03 * noise(W, H, 0.7, 1082))[..., None]
    S = W * 0.95
    ox, oy = W * 0.5 - S * 0.55, H * 0.5 - S * 0.45
    pts = [(ox + u * S, oy + v * S) for u, v in PROFIL]
    sil = mask(W, H, lambda d, k: blob(d, k, pts, steps=8), ss=4)
    # le papier découpé décolle un peu : une ombre douce, décalée vers le bas à droite
    a = paper * (1 - 0.35 * blur(shift(sil, 3, 4), 3.0))[..., None]
    black = np.array([0.07, 0.065, 0.06], np.float32) * (0.9 + 0.2 * noise(W, H, 1.5, 1083))[..., None]
    sheen = np.exp(-((yy - H * 0.36) / (H * 0.25)) ** 2) * 0.05            # le papier glacé accroche un peu la lumière
    a = lay(a, sil, black + sheen[..., None])
    # mèches du chignon : quelques fines entailles claires dans le noir
    cut = Image.new('L', (W * 3, H * 3), 0)
    dc = ImageDraw.Draw(cut)
    bx, by = ox + 0.68 * S, oy + 0.28 * S
    for i in range(6):
        r = S * (0.03 + 0.008 * i)
        dc.arc([(bx - r) * 3, (by - r) * 3, (bx + r) * 3, (by + r) * 3], 200 + i * 8, 330 + i * 5, fill=255, width=3)
    cm = np.asarray(cut.resize((W, H), Image.BOX), np.float32) / 255.0
    a = lay(a, cm * sil * 0.12, paper)
    # taches de rousseur du vieux papier, jaunissement
    fox = np.clip((noise(W, H, 0.4, 1084) - 0.8) * 6, 0, 1) * (noise(W, H, 2.0, 1085) > 0.5)
    a = a * (1 - 0.35 * blur(fox, 1.2)[..., None] * np.array([0.3, 0.6, 1.0]))
    a = develop(a, rs, 'couleur', blur_px=0.5, grain=0.01, fade=0.2, vignette=0.12, warm=0.5)
    a = wear(a, rs, 0.5, scratches=3, dust=40)
    save(border(a, rs, 'ovale', paper=(0.62, 0.52, 0.4), yellow=0.6), 'aieule.png')


def famille():
    """Le grand portrait de famille (studio, vers 2006) : Mamie assise, Papi debout derrière elle, ta mère à
    six ans devant ; le photographe les a posés à contre-jour devant la toile éclairée : trois silhouettes."""
    W, H = H4, W4
    rs = np.random.RandomState(4109)
    a = studio_backdrop(W, H, rs, (0.66, 0.62, 0.56), (0.97, 0.94, 0.88), center=(0.5, 0.42), spread=0.6, marble=0.18)
    common = dict(light=(0.0, -0.3, -0.95), amb=(0.24, 0.22, 0.21), sun=(1.0, 0.95, 0.88), soft=1.4, lwrap=(5.0, 0.55))
    floor = H * 1.25                                                 # le sol, sous le cadre
    # le dossier de la chaise de Mamie, en bois tourné, qui dépasse derrière elle
    chair = mask(W, H, lambda d, k: (taper(d, k, (W * 0.17, H * 0.6), (W * 0.17, H * 1.05), 7, 7),
                                     taper(d, k, (W * 0.43, H * 0.6), (W * 0.43, H * 1.05), 7, 7),
                                     d.ellipse([W * 0.155 * k, H * 0.585 * k, W * 0.185 * k, H * 0.615 * k], fill=255),
                                     d.ellipse([W * 0.415 * k, H * 0.585 * k, W * 0.445 * k, H * 0.615 * k], fill=255)))
    a = lay(a, blur(chair, 1.0), (0.09, 0.07, 0.06))
    pa = Person(W * 0.7, floor, H * 1.08, 'homme', hair='court', seed=121, arms='bas')
    a = render_person(a, pa, {'haut': (0.12, 0.12, 0.14), 'bas': (0.12, 0.12, 0.14), 'peau': SKIN,
                              'cheveux': ((0.45, 0.45, 0.45), 'cheveux')}, rim=((0.6, 0.55, 0.48), 0, 3), seed=122, **common)
    ma = Person(W * 0.3, floor - H * 1.02 * 0.27, H * 1.02, 'femme', pose='chaise', hair='permanente', seed=123, arms='devant')
    a = render_person(a, ma, {'haut': ((0.45, 0.16, 0.2), 'fleurs'), 'bas': ((0.45, 0.16, 0.2), 'fleurs'), 'peau': SKIN,
                              'cheveux': ((0.55, 0.5, 0.45), 'cheveux')}, rim=((0.6, 0.55, 0.48), 3, 2), seed=124, **common)
    en = Person(W * 0.52, floor, H * 0.62, 'fille', hair='carre', dress=True, seed=125, arms='bas')
    a = render_person(a, en, {'haut': ((0.8, 0.62, 0.2), 'uni'), 'bas': ((0.8, 0.62, 0.2), 'uni'), 'peau': SKIN,
                              'cheveux': ((0.3, 0.18, 0.1), 'cheveux')}, rim=((0.75, 0.68, 0.58), 0, 3), seed=126, **common)
    a = develop(a, rs, 'couleur', blur_px=0.7, grain=0.016, fade=0.2, vignette=0.2, warm=0.3)
    a = wear(a, rs, 0.25, scratches=1, dust=20)
    save(border(a, rs, 'aucun', yellow=0.2), 'famille.png')


PHOTOS = {'labo': labo, 'aieule': aieule, 'mariage': mariage, 'noel': noel, 'ecole': ecole, 'plage': plage,
          'jardin': jardin, 'famille': famille, 'gp_mariage': gp_mariage}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args[:1] == ['fetch']:
        fetch()
        raise SystemExit
    fetch()
    names = args or list(PHOTOS)
    for nm in names:
        PHOTOS[nm]()
        print('photo', nm)
