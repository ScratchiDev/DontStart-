"""Génère les images et sons « faits maison » du jeu (affiches, mot, étiquette, ambiances).

Usage : python3 godot/tools/make_assets.py
        python3 godot/tools/make_assets.py story   (seulement l'acte I ; aussi : house, music, floor, images, son)
        python3 godot/tools/make_assets.py images  (0.3.4 : les images du monde en HD, les étiquettes des classeurs,
                                                    le tapis du couloir, la lampe, et les photos de make_photos.py ;
                                                    contrôle des textes dessinés ; télécharge les photos sources)
Dépendances : Pillow, numpy (et ffmpeg pour les .ogg). Les polices viennent de godot/assets/fonts (licence OFL) ;
les images HD prennent Inter (OFL) si elle est installée (paquet fonts-inter), sinon IBM Plex.
Ce dossier contient un fichier .gdignore : Godot ne l'importe pas.
"""
import os
import random
import wave
from itertools import pairwise

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
FONTS = os.path.join(ROOT, 'assets', 'fonts')
IMG = os.path.join(ROOT, 'assets', 'images')
AUDIO = os.path.join(ROOT, 'assets', 'audio')
os.makedirs(IMG, exist_ok=True)
random.seed(7)
np.random.seed(7)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def write_wav(name, data, rate=44100):
    data = np.clip(data, -1, 1)
    pcm = (data * 32767).astype(np.int16)
    path = os.path.join(AUDIO, name)
    with wave.open(path, 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(pcm.tobytes())


def lowpass(x, alpha):
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def room_tone():
    """Souffle grave de la pièce la nuit, bouclable (20 s), avec un filtre qui « respire »."""
    rate, sec = 44100, 20
    n = rate * sec
    brown = np.cumsum(np.random.randn(n)) * .02
    brown -= lowpass(brown, .0005)
    t = np.arange(n) / rate
    breathe = .6 + .4 * np.sin(2 * np.pi * t / sec)  # une période complète : boucle sans couture
    tone = lowpass(brown, .03) * breathe
    hum = .04 * np.sin(2 * np.pi * 50 * t) + .015 * np.sin(2 * np.pi * 100 * t)  # le secteur, très bas
    out = tone / (np.max(np.abs(tone)) + 1e-9) * .5 + hum
    fade = int(rate * .05)
    out[:fade] *= np.linspace(0, 1, fade)
    out[-fade:] *= np.linspace(1, 0, fade)
    write_wav('room_tone.wav', out)


def crt_hum():
    """Sifflement aigu d'un vieux tube cathodique + ronflement, bouclable (4 s)."""
    rate, sec = 44100, 4
    t = np.arange(rate * sec) / rate
    whine = .05 * np.sin(2 * np.pi * 15734 * t)
    buzz = .12 * np.sign(np.sin(2 * np.pi * 60 * t)) * .5 + .08 * np.sin(2 * np.pi * 120 * t)
    noise = np.random.randn(len(t)) * .01
    write_wav('crt_hum.wav', whine + lowpass(buzz, .05) + noise)


def drive_seek():
    """Lecteur de disquette : tête qui cherche (clics) + moteur."""
    rate = 44100
    out = np.zeros(int(rate * 1.6))
    t = np.arange(len(out)) / rate
    out += .08 * np.sin(2 * np.pi * 300 * t) * (np.random.rand(len(t)) * .5 + .5)
    for k in range(14):
        i = int(rate * (.08 + k * .09 + random.random() * .02))
        click = np.random.randn(220) * np.exp(-np.arange(220) / 40)
        out[i:i + 220] += click * .6
    env = np.minimum(1, t / .05) * np.minimum(1, (1.6 - t) / .2)
    write_wav('drive_seek.wav', lowpass(out * env, .5))


# ============================================================ v0.2 : environnement

TEX = os.path.join(ROOT, 'assets', 'textures')
DECAL = os.path.join(ROOT, 'assets', 'decals')
os.makedirs(DECAL, exist_ok=True)


def fbm_tile(n, beta=2.0, seed=0):
    """Bruit fractal 2D périodique (raccord parfait), valeurs 0..1."""
    rs = np.random.RandomState(seed)
    white = rs.randn(n, n)
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f, f)
    r = np.sqrt(fx ** 2 + fy ** 2)
    r[0, 0] = 1.0
    spec = np.fft.fft2(white) / r ** (beta / 2.0)
    spec[0, 0] = 0
    out = np.real(np.fft.ifft2(spec))
    out = (out - out.min()) / (out.max() - out.min())
    return out


def save_gray(arr, path):
    Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), 'L').save(path)


def wallpaper():
    """Papier peint années 80 : rayures moutarde, petits motifs floraux, jauni et passé. 512 px = 0,6 m."""
    n = 512
    img = Image.new('RGB', (n, n), (176, 160, 116))
    d = ImageDraw.Draw(img)
    for x in range(0, n, 64):
        d.rectangle([x + 22, 0, x + 41, n], fill=(156, 141, 100))
        d.line([(x + 21, 0), (x + 21, n)], fill=(140, 124, 86))
        d.line([(x + 42, 0), (x + 42, n)], fill=(140, 124, 86))
    for row, y in enumerate(range(0, n, 64)):
        for x in range(0, n, 64):
            cx = x + (0 if row % 2 else 32) + 0
            cy = y + 32
            for k in range(5):
                ang = k * 2 * np.pi / 5
                px, py = cx + 7 * np.cos(ang), cy + 7 * np.sin(ang)
                d.ellipse([px - 4, py - 4, px + 4, py + 4], fill=(150, 104, 92))
            d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(120, 110, 70))
            d.line([(cx, cy + 9), (cx - 5, cy + 20)], fill=(110, 118, 78), width=2)
            d.ellipse([cx - 11, cy + 13, cx - 3, cy + 19], fill=(110, 118, 78))
    arr = np.asarray(img).astype(np.float32) / 255.0
    fade = fbm_tile(n, 2.6, 11)[..., None]
    fibers = fbm_tile(n, 0.6, 12)[..., None]
    arr = arr * (0.82 + 0.28 * fade) * (0.94 + 0.08 * fibers)
    yellow = np.array([1.0, 0.96, 0.82])
    arr = arr * yellow
    Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)).save(os.path.join(TEX, 'wallpaper.png'))
    h = 0.5 + 0.35 * (fibers[..., 0] - 0.5) + 0.25 * (np.asarray(img.convert('L')) < 140)
    save_gray(h, os.path.join(TEX, 'wallpaper_height.png'))


def beadboard():
    """Lambris en planches verticales vernies (bas des murs). 512 px = 1 m de large."""
    n = 512
    grain = fbm_tile(n, 1.2, 21)
    stretch = np.repeat(fbm_tile(n, 1.8, 22)[:, :1], n, axis=1).T  # fibres verticales
    base = np.zeros((n, n, 3), np.float32)
    height = np.ones((n, n), np.float32)
    col = np.array([0.42, 0.27, 0.16])
    for i, x in enumerate(range(0, n, 64)):
        tone = 0.85 + 0.3 * random.random()
        base[:, x:x + 64] = col * tone
        height[:, x:x + 3] = 0.15
        height[:, x + 61:x + 64] = 0.4
    lines = np.sin((np.arange(n)[None, :] + 40 * stretch) * 0.9) * 0.5 + 0.5
    base *= (0.8 + 0.25 * lines[..., None] * grain[..., None])
    base[height < 0.5] *= 0.45
    Image.fromarray((np.clip(base, 0, 1) * 255).astype(np.uint8)).save(os.path.join(TEX, 'beadboard.png'))
    save_gray(height * (0.9 + 0.1 * grain), os.path.join(TEX, 'beadboard_height.png'))


def grime_tile():
    """Crasse et usure, en niveaux de gris, à multiplier sur les meubles (détail)."""
    n = 256
    big = fbm_tile(n, 2.4, 31)
    small = fbm_tile(n, 1.0, 32)
    g = 0.72 + 0.3 * big - 0.12 * (small > 0.82)
    save_gray(g, os.path.join(TEX, 'grime.png'))


def decal_rgba(name, arr_rgb, alpha):
    a = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
    rgb = (np.clip(arr_rgb, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(np.dstack([rgb, a]), 'RGBA').save(os.path.join(DECAL, name))


def stain_water():
    """Tache d'humidité au plafond : auréoles brunes concentriques."""
    n = 512
    y, x = np.mgrid[0:n, 0:n] / n - 0.5
    noise = fbm_tile(n, 2.2, 41) - 0.5
    r = np.sqrt(x ** 2 + y ** 2) + noise * 0.18
    body = np.clip((0.42 - r) / 0.12, 0, 1)
    rings = np.clip(1 - np.abs(np.sin(r * 55)) * 3, 0, 1) * body
    edge = np.clip(1 - np.abs(r - 0.38) / 0.025, 0, 1)
    alpha = body * 0.6 + rings * 0.3 + edge * 0.8
    rgb = np.dstack([0.27 + 0 * x, 0.19 + 0 * x, 0.1 + 0 * x])
    decal_rgba('stain_water.png', rgb, alpha)


def mold():
    """Moisissure noire dans un coin : amas de points."""
    n = 512
    y, x = np.mgrid[0:n, 0:n] / n
    cover = fbm_tile(n, 2.0, 51)
    falloff = np.clip(1.2 - np.sqrt((x - 0.15) ** 2 + (y - 0.15) ** 2) * 1.6, 0, 1)
    speck = (fbm_tile(n, 0.4, 52) > 0.55).astype(np.float32)
    alpha = np.clip((cover - 0.4) * 3, 0, 1) * falloff * (0.55 + 0.45 * speck)
    rgb = np.dstack([0.05 + 0 * x, 0.07 + 0.03 * cover, 0.04 + 0 * x])
    decal_rgba('mold.png', rgb, alpha)


def footprint(name, flip):
    """Empreinte de pied nu, humide et sale."""
    n = 256
    img = Image.new('L', (n, n), 0)
    d = ImageDraw.Draw(img)
    d.ellipse([92, 70, 164, 170], fill=230)       # avant du pied
    d.ellipse([100, 150, 156, 236], fill=210)     # talon
    d.rectangle([110, 140, 150, 180], fill=150)   # voûte (plus légère)
    for i, (cx, cy, r) in enumerate([(98, 52, 13), (120, 40, 11), (139, 40, 10), (155, 48, 9), (168, 60, 8)]):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=225)
    img = img.filter(ImageFilter.GaussianBlur(3))
    a = np.asarray(img).astype(np.float32) / 255.0
    a *= 0.55 + 0.45 * fbm_tile(n, 1.0, 61 + flip)
    if flip:
        a = a[:, ::-1]
    rgb = np.dstack([0.035 + 0 * a, 0.028 + 0 * a, 0.022 + 0 * a])
    decal_rgba(name, rgb, np.clip(a * 1.5, 0, 0.95))


def scratches():
    """Griffures dans le plâtre, près du lit, et un mot gratté."""
    w, h = 512, 256
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for k in range(4):
        x0 = 60 + k * 22
        pts = [(x0 + random.uniform(-3, 3), 20)]
        for s in range(1, 12):
            pts.append((x0 + s * 6 + random.uniform(-4, 4), 20 + s * 18 + random.uniform(-3, 3)))
        d.line(pts, fill=(30, 22, 16, 230), width=5)
        d.line([(x + 1, y) for x, y in pts], fill=(214, 202, 176, 200), width=2)
    hand = font('ReenieBeanie.ttf', 72)
    d.text((340, 120), 'ne dors pas', font=hand, fill=(40, 30, 24, 210), anchor='mm')
    img.filter(ImageFilter.GaussianBlur(0.6)).save(os.path.join(DECAL, 'scratches.png'))


def neighbor_window():
    """Fenêtre allumée de la maison voisine, rideau, et une silhouette debout derrière."""
    w, h = 128, 160
    arr = np.zeros((h, w, 3), np.float32)
    y, x = np.mgrid[0:h, 0:w]
    glow = np.exp(-(((x - 64) / 70) ** 2 + ((y - 70) / 90) ** 2))
    arr[...] = np.dstack([1.0 * glow, 0.62 * glow, 0.28 * glow]) * 1.0
    img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    # une personne debout dans la vitre de gauche, épaules, bras le long du corps, qui regarde dehors
    d.ellipse([28, 66, 48, 90], fill=(14, 8, 6))
    d.polygon([(33, 90), (43, 90), (56, 100), (54, 160), (22, 160), (20, 100)], fill=(14, 8, 6))
    d.rectangle([0, 0, w - 1, h - 1], outline=(10, 8, 6), width=6)
    d.line([(64, 0), (64, h)], fill=(10, 8, 6), width=4)
    d.line([(0, 44), (w, 44)], fill=(10, 8, 6), width=4)
    img.save(os.path.join(IMG, 'neighbor_window.png'))
    img2 = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8))
    d2 = ImageDraw.Draw(img2)
    d2.rectangle([0, 0, w - 1, h - 1], outline=(10, 8, 6), width=6)
    d2.line([(64, 0), (64, h)], fill=(10, 8, 6), width=4)
    d2.line([(0, 44), (w, 44)], fill=(10, 8, 6), width=4)
    img2.save(os.path.join(IMG, 'neighbor_window_empty.png'))


def rain_loop():
    """Pluie sur la vitre et le jardin, bouclable (12 s)."""
    rate, sec = 44100, 12
    n = rate * sec
    spec = np.fft.rfft(np.random.randn(n))
    f = np.fft.rfftfreq(n, 1 / rate)
    shape = 1 / np.sqrt(np.maximum(f, 40)) * np.exp(-f / 9000)
    hiss = np.fft.irfft(spec * shape, n)
    hiss /= np.max(np.abs(hiss))
    out = hiss * 0.35
    for _ in range(900):
        i = random.randrange(n - 600)
        k = np.arange(500)
        out[i:i + 500] += np.sin(k * random.uniform(0.25, 0.6)) * np.exp(-k / random.uniform(25, 70)) * random.uniform(0.05, 0.22)
    write_wav('rain_loop.wav', out * 0.8)


def thunder():
    """Tonnerre : craquement puis grondement qui roule (7 s)."""
    rate, sec = 44100, 7
    n = rate * sec
    t = np.arange(n) / rate
    rumble = lowpass(np.random.randn(n), 0.012) * 9
    crack = lowpass(np.random.randn(n), 0.25) * np.exp(-t / 0.18)
    env = np.minimum(1, t / 0.05) * np.exp(-t / 2.2) * (0.7 + 0.3 * np.sin(t * 3.1) * np.sin(t * 1.7))
    out = rumble * env + crack * 0.9
    out /= np.max(np.abs(out))
    write_wav('thunder.wav', out * 0.95)


# ============================================================ v0.3 : la maison

def _save_rgb(arr, name):
    Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)).save(os.path.join(TEX, name))


def wallpaper_floral():
    """Chambre des grands-parents : petits bouquets passés sur fond vieux rose, en quinconce. 512 px = 0,6 m."""
    n = 512
    img = Image.new('RGB', (n, n), (196, 168, 158))
    d = ImageDraw.Draw(img)
    for row, y in enumerate(range(0, n, 128)):
        for x in range(0, n, 128):
            cx = x + (64 if row % 2 else 0) + 32
            cy = y + 48
            for dx in (-128, 0, 128):
                bx = (cx + dx)
                d.line([(bx, cy + 6), (bx - 6, cy + 30)], fill=(122, 128, 96), width=2)
                d.line([(bx, cy + 6), (bx + 7, cy + 28)], fill=(122, 128, 96), width=2)
                d.ellipse([bx - 16, cy + 14, bx - 6, cy + 22], fill=(128, 136, 100))
                d.ellipse([bx + 6, cy + 16, bx + 16, cy + 24], fill=(128, 136, 100))
                for k, (ox, oy, col) in enumerate([(0, 0, (168, 92, 96)), (-9, 5, (186, 122, 112)), (9, 4, (160, 84, 92))]):
                    d.ellipse([bx + ox - 7, cy + oy - 7, bx + ox + 7, cy + oy + 7], fill=col)
                    d.arc([bx + ox - 5, cy + oy - 5, bx + ox + 5, cy + oy + 5], 0, 300, fill=(120, 60, 66))
    # fines rayures verticales en filet
    for x in range(0, n, 32):
        d.line([(x, 0), (x, n)], fill=(184, 156, 146))
    arr = np.asarray(img).astype(np.float32) / 255.0
    fade = fbm_tile(n, 2.6, 41)[..., None]
    fibers = fbm_tile(n, 0.6, 42)[..., None]
    arr = arr * (0.8 + 0.3 * fade) * (0.94 + 0.08 * fibers) * np.array([1.0, 0.97, 0.88])
    _save_rgb(arr, 'wallpaper_floral.png')
    h = 0.5 + 0.35 * (fibers[..., 0] - 0.5) + 0.2 * (np.asarray(img.convert('L')) < 150)
    save_gray(h, os.path.join(TEX, 'wallpaper_floral_height.png'))


def wallpaper_stripes():
    """Couloir et bureau : larges rayures vert sauge et crème, filet brun, très jauni. 512 px = 0,6 m."""
    n = 512
    img = Image.new('RGB', (n, n), (186, 178, 142))
    d = ImageDraw.Draw(img)
    for x in range(0, n, 128):
        d.rectangle([x, 0, x + 54, n], fill=(132, 140, 108))
        d.line([(x + 60, 0), (x + 60, n)], fill=(108, 86, 62), width=2)
        d.line([(x + 66, 0), (x + 66, n)], fill=(108, 86, 62), width=1)
        for y in range(8, n, 32):
            d.ellipse([x + 93, y, x + 99, y + 6], fill=(150, 120, 90))
    arr = np.asarray(img).astype(np.float32) / 255.0
    fade = fbm_tile(n, 2.6, 51)[..., None]
    fibers = fbm_tile(n, 0.6, 52)[..., None]
    drip = np.repeat(fbm_tile(n, 2.0, 53)[:1, :], n, axis=0)[..., None]   # coulures verticales
    arr = arr * (0.8 + 0.3 * fade) * (0.94 + 0.08 * fibers) * (0.9 + 0.12 * drip) * np.array([1.0, 0.96, 0.84])
    _save_rgb(arr, 'wallpaper_stripes.png')
    h = 0.5 + 0.35 * (fibers[..., 0] - 0.5)
    save_gray(h, os.path.join(TEX, 'wallpaper_stripes_height.png'))


def tiles_wall():
    """Salle de bains : carreaux de faïence 15 cm rose pâle, joints grisés, quelques carreaux fêlés. 512 px = 0,6 m."""
    n, k = 512, 128
    base = np.zeros((n, n, 3), np.float32)
    height = np.ones((n, n), np.float32)
    rs = np.random.RandomState(61)
    col = np.array([0.86, 0.79, 0.76])
    for i in range(4):
        for j in range(4):
            tone = 0.94 + 0.08 * rs.rand()
            base[i * k:(i + 1) * k, j * k:(j + 1) * k] = col * tone
    g = 5
    for v in range(0, n, k):
        base[v:v + g, :] = [0.52, 0.5, 0.46]
        base[:, v:v + g] = [0.52, 0.5, 0.46]
        height[v:v + g, :] = 0.2
        height[:, v:v + g] = 0.2
    img = Image.fromarray((np.clip(base, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    for _ in range(2):   # fêlures
        x, y = rs.randint(10, n - 10), rs.randint(10, n - 10)
        pts = [(x, y)]
        for _ in range(6):
            x += rs.randint(-14, 14)
            y += rs.randint(4, 16)
            pts.append((x, y))
        d.line(pts, fill=(96, 86, 80), width=1)
    arr = np.asarray(img).astype(np.float32) / 255.0
    dirt = fbm_tile(n, 2.2, 62)[..., None]
    arr = arr * (0.86 + 0.18 * dirt)
    _save_rgb(arr, 'tiles_wall.png')
    save_gray(height * (0.95 + 0.05 * dirt[..., 0]), os.path.join(TEX, 'tiles_wall_height.png'))


def tiles_floor():
    """Sol carrelé (salle de bains, cuisine) : damier beige et brun-rouge 20 cm, usé. 512 px = 0,8 m."""
    n, k = 512, 128
    base = np.zeros((n, n, 3), np.float32)
    height = np.ones((n, n), np.float32)
    rs = np.random.RandomState(71)
    a = np.array([0.78, 0.7, 0.58])
    b = np.array([0.5, 0.29, 0.22])
    for i in range(4):
        for j in range(4):
            base[i * k:(i + 1) * k, j * k:(j + 1) * k] = (a if (i + j) % 2 == 0 else b) * (0.9 + 0.12 * rs.rand())
    g = 4
    for v in range(0, n, k):
        base[v:v + g, :] = [0.34, 0.31, 0.28]
        base[:, v:v + g] = [0.34, 0.31, 0.28]
        height[v:v + g, :] = 0.25
        height[:, v:v + g] = 0.25
    wear = fbm_tile(n, 2.4, 72)[..., None]
    speck = (fbm_tile(n, 0.4, 73) > 0.7)[..., None] * 0.08
    arr = base * (0.8 + 0.3 * wear) - speck
    _save_rgb(arr, 'tiles_floor.png')
    save_gray(height * (0.94 + 0.06 * wear[..., 0]), os.path.join(TEX, 'tiles_floor_height.png'))


def carpet():
    """Moquette rase brun-rouille, tachée et tassée aux passages. 512 px = 1 m."""
    n = 512
    mottle = fbm_tile(n, 2.2, 81)
    fiber = fbm_tile(n, 0.2, 82)
    worn = fbm_tile(n, 3.0, 83)
    base = np.array([0.42, 0.24, 0.17])
    arr = base[None, None, :] * (0.72 + 0.4 * mottle[..., None]) * (0.85 + 0.3 * fiber[..., None])
    arr = arr * (0.9 + 0.15 * worn[..., None])
    _save_rgb(arr, 'carpet.png')
    save_gray(0.5 + 0.5 * (fiber - 0.5) + 0.2 * (mottle - 0.5), os.path.join(TEX, 'carpet_height.png'))


def static_loop():
    """Neige d'un écran hanté : souffle large bande, crépitements, ronflement 50 Hz (4 s, boucle)."""
    rate, sec = 44100, 4
    n = rate * sec
    t = np.arange(n) / rate
    hiss = np.random.randn(n) - lowpass(np.random.randn(n), 0.05)
    crackle = (np.random.rand(n) > 0.9993) * np.random.randn(n) * 6
    crackle = lowpass(crackle, 0.4)
    hum = 0.25 * np.sin(2 * np.pi * 50 * t) + 0.12 * np.sin(2 * np.pi * 150 * t)
    wob = 0.8 + 0.2 * np.sin(2 * np.pi * t / sec * 3)
    out = hiss * 0.5 * wob + crackle + hum
    fade = int(rate * 0.05)
    out[:fade] *= np.linspace(0, 1, fade)    # raccord de la boucle
    out[-fade:] *= np.linspace(1, 0, fade)
    out /= np.max(np.abs(out))
    write_wav('static_loop.wav', out * 0.8)


def entity_face():
    """Le visage de S.1.L.3.N.C.3. sur les écrans : le scan 3D (rendu par tests/face_render.tscn dans
    tools/face_raw.png) éclairé par en dessous, yeux creusés, pixelisé et décalé en bandes."""
    src = Image.open(os.path.join(os.path.dirname(__file__), 'face_raw.png')).convert('L')
    a = np.asarray(src).astype(np.float32) / 255.0
    a = np.clip((a - 0.08) * 1.5, 0, 1) ** 1.3
    n = a.shape[0]
    yy, xx = np.mgrid[0:n, 0:n] / n
    for ex in (0.335, 0.63):   # orbites vides
        d = ((xx - ex) / 0.105) ** 2 + ((yy - 0.425) / 0.07) ** 2
        a *= np.clip((d - 0.15) * 1.4, 0, 1) ** 2
    d = ((xx - 0.48) / 0.11) ** 2 + ((yy - 0.735) / 0.025) ** 2   # bouche un peu ouverte
    a *= np.clip(0.25 + d, 0, 1)
    img = Image.fromarray((a * 255).astype(np.uint8)).resize((96, 96), Image.BILINEAR)
    arr = np.asarray(img).astype(np.float32)
    rs = np.random.RandomState(91)
    for _ in range(7):   # bandes décalées (image numérique abîmée)
        y0 = rs.randint(0, 90)
        h = rs.randint(1, 4)
        arr[y0:y0 + h] = np.roll(arr[y0:y0 + h], rs.randint(-6, 7), axis=1)
    img = Image.fromarray(arr.astype(np.uint8)).resize((256, 256), Image.NEAREST)
    rgb = np.stack([np.asarray(img)] * 3, -1).astype(np.float32) / 255.0 * np.array([0.85, 0.95, 1.0])
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).save(os.path.join(IMG, 'entity_face.png'))


HOUSE = [wallpaper_floral, wallpaper_stripes, tiles_wall, tiles_floor, carpet, static_loop, entity_face]


# ============================================================ v0.3 : musique (synthèse, boucles sans couture)
# Tout est calculé dans le domaine fréquentiel ou avec des fréquences multiples de 1/durée :
# la fin de chaque boucle raccorde exactement avec son début.

RATE = 44100


def _q(f, sec):
    """Arrondit une fréquence à un multiple de 1/sec (boucle parfaite)."""
    return round(f * sec) / sec


def _band_noise(n, lo, hi, seed, tilt=0.0):
    """Bruit filtré passe-bande (circulaire, donc bouclable)."""
    rs = np.random.RandomState(seed)
    spec = np.fft.rfft(rs.randn(n))
    f = np.fft.rfftfreq(n, 1 / RATE)
    shape = np.exp(-0.5 * (np.log(np.maximum(f, 1) / np.sqrt(lo * hi)) / (np.log(hi / lo) / 2.5)) ** 2)
    shape *= np.maximum(f, 1) ** tilt
    out = np.fft.irfft(spec * shape, n)
    return out / (np.max(np.abs(out)) + 1e-9)


def _reverb(x, seconds=3.5, seed=5, mix=0.45, loop=True):
    """Réverbération par convolution avec une queue de bruit qui décroît. loop=True : convolution
    circulaire (la queue revient au début, pour les boucles) ; sinon la queue est coupée à la fin."""
    if not loop:
        pad = int(RATE * seconds)
        return _reverb(np.concatenate([x, np.zeros(pad)]), seconds, seed, mix, True)[:len(x)]
    n = len(x)
    rs = np.random.RandomState(seed)
    m = int(RATE * seconds)
    t = np.arange(m) / RATE
    ir = rs.randn(m) * np.exp(-t * 6.9 / seconds)
    ir = np.fft.irfft(np.fft.rfft(ir) * np.exp(-np.fft.rfftfreq(m, 1 / RATE) / 5000.0), m)   # queue plus sombre
    ir_full = np.zeros(n)
    ir_full[:min(m, n)] = ir[:min(m, n)]
    wet = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir_full), n)
    wet /= (np.max(np.abs(wet)) + 1e-9) / (np.max(np.abs(x)) + 1e-9)
    return x * (1 - mix) + wet * mix


def _ogg(name, left, right=None):
    """Écrit un .ogg (Vorbis) via ffmpeg, stéréo si right est donné."""
    import subprocess
    import tempfile
    st = np.stack([left, left if right is None else right], 1)
    st = np.clip(st, -1, 1)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
        path = tmp.name
    with wave.open(path, 'wb') as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((st * 32767).astype(np.int16).tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', path, '-c:a', 'libvorbis', '-q:a', '5',
                    os.path.join(AUDIO, name)], check=True)
    os.remove(path)


def _partials(t, sec, f0, ratios, amps, detune=0.0, phase=0.0):
    out = np.zeros_like(t)
    for r, a in zip(ratios, amps):
        out += a * np.sin(2 * np.pi * _q(f0 * r + detune, sec) * t + phase * r)
    return out


def music_house():
    """La maison, la nuit : bourdon grave en ré qui bat lentement, souffle, harmonica de verre
    dissonant qui passe, tintements métalliques lointains. 64 s, stéréo, boucle."""
    sec = 64
    n = RATE * sec
    t = np.arange(n) / RATE
    lfo = lambda k, ph=0.0: 0.5 + 0.5 * np.sin(2 * np.pi * k * t / sec + ph)   # k périodes par boucle
    chans = []
    for side, (dt, seed) in enumerate([(0.0, 101), (0.21, 102)]):
        drone = (_partials(t, sec, 73.42, [1, 2, 3, 4, 6], [1, .5, .28, .14, .06], dt)
                 + 0.8 * _partials(t, sec, 73.42 * 1.5, [1, 2, 3], [.5, .2, .08], -dt * 1.3))
        drone *= 0.55 + 0.45 * lfo(3, side * 0.7)
        sub = 0.5 * np.sin(2 * np.pi * _q(36.71, sec) * t) * lfo(2, 1.0)
        breath = _band_noise(n, 180, 900, seed) * (0.15 + 0.35 * lfo(5, side)) * 0.5
        # harmonica de verre : ré et mi bémol aigus, la seconde mineure qui grince
        glass = (np.sin(2 * np.pi * _q(587.33, sec) * t + 0.4 * np.sin(2 * np.pi * _q(5.0, sec) * t))
                 + 0.8 * np.sin(2 * np.pi * _q(622.25, sec) * t))
        glass *= lfo(1, 2.2 + side * 0.4) ** 6 * 0.18
        ping = np.zeros(n)
        rs = np.random.RandomState(103 + side)
        for start in (9.5, 27.0, 44.5, 58.0):
            i0 = int((start + rs.rand() * 0.3) * RATE)
            m = int(4.5 * RATE)
            tt = np.arange(m) / RATE
            p = sum(a * np.sin(2 * np.pi * f * tt) for f, a in [(1180, 1), (1873, .6), (2731, .4), (3990, .25)])
            p *= np.exp(-tt / 1.1) * 0.12
            idx = (i0 + np.arange(m)) % n
            ping[idx] += p
        mix = drone * 0.35 + sub * 0.4 + breath + glass + ping
        chans.append(_reverb(mix, 4.0, 7 + side, 0.5))
    peak = max(np.max(np.abs(c)) for c in chans)
    _ogg('music_house.ogg', chans[0] / peak * 0.7, chans[1] / peak * 0.7)


def music_tension():
    """Quand l'entité est là : glissando de Shepard qui monte sans fin, battement de cœur,
    trémolo grinçant. 32 s, stéréo, boucle."""
    sec = 32
    n = RATE * sec
    t = np.arange(n) / RATE
    chans = []
    for side in range(2):
        # Shepard : 8 octaves qui montent d'une octave par boucle, enveloppe en cloche sur log(f)
        xf = 4 * RATE                                    # fondu enchaîné pour boucler sans clic
        te = np.arange(n + xf) / RATE
        shep = np.zeros(n + xf)
        base = 30.0
        for k in range(8):
            pos = (k + te / sec) % 8                     # position en octaves
            f = base * 2 ** pos
            phase = 2 * np.pi * np.cumsum(f) / RATE
            env = np.exp(-0.5 * ((pos - 4.0) / 1.3) ** 2)
            shep += env * np.sin(phase + side * 0.3)
        ramp = np.linspace(0, 1, xf)
        head = shep[:xf] * np.sqrt(ramp) + shep[n:] * np.sqrt(1 - ramp)
        shep = np.concatenate([head, shep[xf:n]])
        shep /= np.max(np.abs(shep))
        # cœur : deux coups (lub-dub) à 64 battements par minute environ (34 battements par boucle)
        heart = np.zeros(n)
        beats = 34
        for b in range(beats):
            for off, amp in ((0.0, 1.0), (0.28, 0.6)):
                i0 = int((b * sec / beats + off) * RATE)
                m = int(0.35 * RATE)
                tt = np.arange(m) / RATE
                thump = np.sin(2 * np.pi * (55 - 25 * tt / 0.35) * tt) * np.exp(-tt / 0.07) * amp
                heart[(i0 + np.arange(m)) % n] += thump
        # trémolo de cordes grinçantes (dent de scie filtrée) en ré, mi bémol
        saw = np.zeros(n)
        for f, a in ((293.66, 1.0), (311.13, 0.7), (440.0, 0.4)):
            fq = _q(f + side * 0.4, sec)
            for h in range(1, 9):
                saw += a * np.sin(2 * np.pi * fq * h * t) / h
        trem = 0.5 + 0.5 * np.sin(2 * np.pi * _q(9.0, sec) * t)
        swell = 0.5 + 0.5 * np.sin(2 * np.pi * 2 * t / sec - np.pi / 2)
        saw = saw / np.max(np.abs(saw)) * trem * swell
        mix = shep * 0.45 + heart * 0.7 + saw * 0.22 + _band_noise(n, 60, 400, 120 + side) * 0.18
        chans.append(_reverb(mix, 2.5, 21 + side, 0.35))
    peak = max(np.max(np.abs(c)) for c in chans)
    _ogg('music_tension.ogg', chans[0] / peak * 0.75, chans[1] / peak * 0.75)


def sting():
    """Coup de sursaut : boum grave + grappe de cris métalliques aigus + queue de réverbération. 4 s."""
    sec = 4
    n = RATE * sec
    t = np.arange(n) / RATE
    boom = np.sin(2 * np.pi * (90 * np.exp(-t * 3) + 28) * t) * np.exp(-t / 0.5)
    hit = _band_noise(n, 100, 3000, 131) * np.exp(-t / 0.08)
    scream = np.zeros(n)
    rs = np.random.RandomState(132)
    for f in (1650, 1747, 2210, 2333, 3120):
        vib = 1 + 0.012 * np.sin(2 * np.pi * (6 + rs.rand() * 3) * t)
        ph = 2 * np.pi * np.cumsum(f * vib) / RATE
        saw = sum(np.sin(h * ph) / h for h in range(1, 6))
        scream += saw
    scream = scream / np.max(np.abs(scream)) * np.minimum(1, t / 0.015) * np.exp(-t / 0.7)
    mix = boom * 0.9 + hit * 0.6 + scream * 0.45
    mix[-int(0.3 * RATE):] *= np.linspace(1, 0, int(0.3 * RATE))
    out = _reverb(mix, 2.5, 133, 0.35, loop=False)
    out /= np.max(np.abs(out))
    _ogg('sting.ogg', out * 0.95)


def riser():
    """Montée de tension (6 s) qui se coupe net : souffle qui enfle et grappe qui monte."""
    sec = 6
    n = RATE * sec
    t = np.arange(n) / RATE
    env = (t / sec) ** 2.2
    noise = _band_noise(n, 400, 6000, 141) * env
    cl = np.zeros(n)
    for f in (220, 233, 311, 330):
        ph = 2 * np.pi * np.cumsum(f * 2 ** (1.5 * t / sec)) / RATE
        cl += np.sin(ph) + 0.4 * np.sin(2 * ph)
    cl = cl / np.max(np.abs(cl)) * env
    out = noise * 0.5 + cl * 0.6
    out[-200:] *= np.linspace(1, 0, 200)
    out /= np.max(np.abs(out))
    _ogg('riser.ogg', out * 0.9)


MUSIC = [music_house, music_tension, sting, riser]


# ============================================================ v0.3 : l'acte I
# Objets et sons de la nuit du 31 octobre 2040 chez Henriette et Albert.
# Chaque fonction a ses PROPRES générateurs à graine fixe (random.Random, np.random.RandomState) :
# le résultat ne dépend pas de l'ordre d'exécution. Ces fonctions remplacent volontairement
# calendar.png, floppy_label.png et photo.png des versions précédentes (STORY passe en dernier).
# Les sons en boucle sont construits de façon circulaire (filtres dans le domaine fréquentiel,
# enveloppes périodiques) : la fin raccorde exactement avec le début.


def _grime_local(img, amount, rng):
    """Taches, plis et poussière (comme le grime() de la 0.3.2), avec son propre générateur (random.Random) :
    ne touche pas au hasard global."""
    w, h = img.size
    over = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for _ in range(int(w * h / 900)):
        x, y = rng.randrange(w), rng.randrange(h)
        d.point((x, y), fill=(0, 0, 0, int(rng.random() * 60 * amount)))
    for _ in range(6):
        x = rng.randrange(w)
        d.line([(x, 0), (x + rng.randint(-20, 20), h)], fill=(255, 255, 255, int(18 * amount)), width=1)
    for _ in range(3):
        cx, cy, r = rng.randrange(w), rng.randrange(h), rng.randint(20, 60)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(60, 40, 10, int(40 * amount)))
    over = over.filter(ImageFilter.GaussianBlur(1.2))
    return Image.alpha_composite(img.convert('RGBA'), over).convert('RGB')


def _to_img(arr):
    return Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8))


def _to_arr(img):
    return np.asarray(img.convert('RGB')).astype(np.float32) / 255.0


PHOTO_DATE = "'16 10 31"   # dateur orange dans le coin de la photo (appareil réglé sur l'année, mois, jour)


def _code39(txt):
    """Barres d'un code 39 (chiffres et *) : liste de (largeur, est_une_barre)."""
    table = {'0': '000110100', '1': '100100001', '2': '001100001', '3': '101100000', '4': '000110001',
             '5': '100110000', '6': '001110000', '7': '000100101', '8': '100100100', '9': '001100100',
             '*': '010010100'}
    out = []
    for ch in '*' + txt + '*':
        for i, bit in enumerate(table[ch]):
            out.append((3 if bit == '1' else 1, i % 2 == 0))
        out.append((1, False))
    return out


def _spec_filter(x, gain):
    """Filtre circulaire dans le domaine fréquentiel (la boucle reste sans couture). gain(f) -> amplitude."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1 / RATE)
    return np.fft.irfft(np.fft.rfft(x) * gain(f), n)


def _butter(f, fc, order, high=False):
    """Réponse en amplitude d'un Butterworth (passe-bas, ou passe-haut si high)."""
    r = (np.maximum(f, 1e-6) / fc) if not high else (fc / np.maximum(f, 1e-6))
    return 1 / np.sqrt(1 + r ** (2 * order))


def _seg_env(t, start, dur, shape, period):
    """Enveloppe d'un segment [start, start+dur] dans une boucle de durée period (u de 0 à 1)."""
    u = ((t - start) % period) / dur
    inside = u < 1
    uu = np.where(inside, u, 0.0)
    return np.where(inside, shape(uu), 0.0), uu, inside


def snore():
    """Albert ronfle derrière le mur : inspiration ronflée (le voile du palais qui bat vers 30 Hz,
    souffle grave), puis expiration plus douce. Deux respirations différentes, 8 s, boucle."""
    sec = 8
    n = RATE * sec
    t = np.arange(n) / RATE
    out = np.zeros(n)
    # (début, durée inspiration, durée expiration, fréquence du battement, force)
    for i, (t0, din, dout, fl, amp) in enumerate([(0.45, 1.75, 1.55, 31.0, 1.0), (4.35, 1.55, 1.7, 27.0, 0.82)]):
        env, u, inside = _seg_env(t, t0, din, lambda u: np.sin(np.pi * u) ** 0.5 * (0.55 + 0.45 * u) * (1 - u ** 6), sec)
        f = fl * (1 + 0.07 * np.sin(np.pi * u) + 0.03 * np.sin(2 * np.pi * 3.1 * u * din))
        phase = 2 * np.pi * np.cumsum(f * inside) / RATE
        pulses = ((1 + np.cos(phase)) / 2) ** 7
        pulses -= pulses[inside].mean() if inside.any() else 0
        noise = _band_noise(n, 90, 420, 3050 + i)
        flap = pulses * 1.1 + noise * (0.4 + 1.1 * ((1 + np.cos(phase)) / 2) ** 3)
        out += flap * env * amp
        env2, u2, _ = _seg_env(t, t0 + din + 0.08, dout, lambda u: np.sin(np.pi * u ** 0.6) ** 1.6, sec)
        breath = _band_noise(n, 110, 600, 3052 + i) * 0.55
        puff = _band_noise(n, 60, 200, 3054 + i) * 0.4 * np.exp(-u2 * 6)  # petit « pff » des lèvres
        out += (breath + puff) * env2 * amp * 0.55
    # le mur : passe-bas fort, coupe le très grave, petite résonance de la cloison
    wall = lambda f: (_butter(f, 380, 2) * _butter(f, 50, 2, high=True)
                      * (1 + 0.6 * np.exp(-0.5 * ((f - 130) / 30) ** 2)))
    out = _spec_filter(out, wall)
    out = _reverb(out, 0.7, 306, 0.22)                    # la chambre d'à côté (convolution circulaire)
    out += _band_noise(n, 40, 200, 3056) * np.std(out) * 0.04
    out /= np.max(np.abs(out))
    write_wav('snore.wav', out * 0.7)


def breath_slow():
    """Henriette dort derrière sa porte : respiration lente et profonde, étouffée. 10 s, deux cycles, boucle."""
    sec = 10
    n = RATE * sec
    t = np.arange(n) / RATE
    out = np.zeros(n)
    for i, (t0, din, dout, amp) in enumerate([(0.35, 1.9, 2.5, 1.0), (5.3, 2.05, 2.35, 0.9)]):
        env, _, _ = _seg_env(t, t0, din, lambda u: np.sin(np.pi * u ** 0.8) ** 1.3, sec)
        nose = _band_noise(n, 300, 1800, 3070 + i, tilt=-0.2)       # inspiration par le nez
        out += nose * env * amp * 0.75
        env2, u2, _ = _seg_env(t, t0 + din + 0.12, dout, lambda u: (1 - np.exp(-u * 5)) * (1 - u) ** 1.7, sec)
        mouth = _band_noise(n, 140, 900, 3072 + i)                  # expiration, bouche entrouverte
        out += mouth * env2 * amp
    # la porte : très étouffé, un peu d'aigu passe par la fente du bas
    door = lambda f: (_butter(f, 450, 2) + 0.025 * _butter(f, 2400, 2)) * _butter(f, 70, 2, high=True)
    out = _spec_filter(out, door)
    out = _reverb(out, 0.5, 307, 0.18)
    out /= np.max(np.abs(out))
    write_wav('breath_slow.wav', out * 0.55)


def door_slide():
    """On glisse une clé et un papier sous la porte : frottement de papier, la clé qui racle et tinte. 1,2 s."""
    n = int(RATE * 1.2)
    pad = int(RATE * 0.4)
    m = n + pad
    t = np.arange(m) / RATE
    rs = np.random.RandomState(308)
    # papier : souffle aigu, irrégulier (accroche-glisse), poussé en deux fois
    grains = (rs.rand(m) < 140 / RATE) * rs.rand(m)
    grains = np.convolve(grains, np.hanning(int(RATE * 0.006)), mode='same')
    push = (np.clip(t / 0.03, 0, 1) * np.clip((0.42 - t) / 0.06, 0, 1)
            + 0.8 * np.clip((t - 0.46) / 0.03, 0, 1) * np.clip((0.78 - t) / 0.12, 0, 1))
    hiss = _spec_filter(rs.randn(m), lambda f: _butter(f, 900, 2, high=True) * _butter(f, 7000, 2))
    body = _spec_filter(rs.randn(m), lambda f: _butter(f, 180, 2, high=True) * _butter(f, 700, 2))
    paper = (hiss * (0.35 + 1.4 * grains / (grains.max() + 1e-9)) + body * 0.5) * push
    # la clé racle le plancher sous le papier : petites résonances métalliques excitées par le frottement
    scrape_env = np.clip((t - 0.5) / 0.05, 0, 1) * np.clip((0.8 - t) / 0.05, 0, 1)
    excite = _spec_filter(rs.randn(m), lambda f: _butter(f, 2500, 2, high=True)) * scrape_env
    ring = np.zeros(m)
    for fr, a in ((3170, 1.0), (4890, 0.7), (7120, 0.45)):
        res = lambda f, fr=fr: np.exp(-0.5 * ((f - fr) / 120) ** 2)
        ring += a * _spec_filter(excite, res)
    scrape = excite * 0.3 + ring * 1.6
    # le tintement : la clé retombe sur le plancher (deux petits rebonds)
    tink = np.zeros(m)
    for t0, a in ((0.82, 1.0), (0.905, 0.45), (0.95, 0.2)):
        tt = t - t0
        on = tt >= 0
        part = sum(b * np.sin(2 * np.pi * fr * tt) * np.exp(-np.maximum(tt, 0) / dec)
                   for fr, b, dec in ((2870, 1.0, 0.09), (4410, .7, .06), (6230, .5, .045), (7960, .35, .03), (9580, .2, .02)))
        click = rs.randn(m) * np.exp(-np.maximum(tt, 0) / 0.002)
        tink += a * on * (part + click * 0.6)
    out = paper * 0.55 + scrape * 0.5 + tink * 0.25
    out = _spec_filter(out, lambda f: _butter(f, 9000, 2) * _butter(f, 60, 2, high=True))
    out = _reverb(out, 0.45, 309, 0.18, loop=False)[:n]
    out[:int(RATE * .004)] *= np.linspace(0, 1, int(RATE * .004))
    out[-int(RATE * .06):] *= np.linspace(1, 0, int(RATE * .06))
    out /= np.max(np.abs(out))
    write_wav('door_slide.wav', out * 0.85)




# ============================================================ 0.3.4 : images en haute définition (passe « triple A »)
# Les images du monde du jeu (papiers, étiquettes, affiches, calendrier, horloge, liège…) étaient dessinées à
# 64-512 px, dans un monde photoréaliste. Elles sont régénérées AUX MÊMES NOMS et au même rapport largeur /
# hauteur, SCALE fois plus grandes (HD_SCALE pour les grandes : une affiche n'a pas besoin de 2 944 px), avec
# un vrai papier (fibres, grain, pli, bord jauni), des encres qui se comportent comme des encres (stylo bille
# qui saute, feutre qui bave, impression nette, ruban de machine à écrire) et la même mise en page : les
# dessins sont décrits dans le repère de la 0.3.3 (w × h d'avant) et multipliés par s.
# Les chaînes dessinées ne changent pas : « make_assets.py images » relève toutes les chaînes passées à
# ImageDraw.text pendant la génération et les compare à TEXTES_033 (relevé fait sur les générateurs de la
# 0.3.3) ; une différence arrête le script.
# Chaque fonction a son propre hasard (graine fixe) ; aucune ne touche random ni np.random globaux.

SCALE = 4
HD_SCALE = {'poster_choisis': 2.0, 'poster_spectres': 2.0, 'poster_corbeaux': 2.56, 'corkboard': 2.5,
            'tableau_cles': 2.0, 'carton_2euros': 2.0, 'tin_lid': 2.0, 'calendar': 1024 / 300}

SYS_FONTS = '/usr/share/fonts/opentype/inter'   # Inter (OFL), pour la typographie imprimée ; sinon IBM Plex


def hd(name, w, h):
    """Facteur s et taille finale (W, H) d'une image de la 0.3.3 de w × h px."""
    s = HD_SCALE.get(name, SCALE)
    return s, int(round(w * s)), int(round(h * s))


def sfont(name, size):
    """Police d'imprimerie : Inter si elle est installée (OFL), sinon IBM Plex Mono (dans le projet)."""
    p = os.path.join(SYS_FONTS, name)
    if os.path.exists(p):
        return ImageFont.truetype(p, int(round(size)))
    return font('IBMPlexMono-Bold.ttf' if 'Bold' in name or 'Semi' in name else 'IBMPlexMono-Regular.ttf', int(round(size)))


def _grid(W, H, s):
    """(yy, xx) : coordonnées des centres des pixels dans le repère d'origine (0.3.3)."""
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    return (yy + 0.5) / s - 0.5, (xx + 0.5) / s - 0.5


def _fbm(W, H, beta, seed, s, base=512):
    """Bruit fractal (0 à 1) à la taille finale, au grain de fbm_tile(base) dans le repère d'origine
    (même pente du spectre, détails fins en plus). Raccordable sur ses bords."""
    rs = np.random.RandomState(seed)
    white = rs.randn(H, W)
    fy = np.fft.fftfreq(H)[:, None] * (s * base)
    fx = np.fft.rfftfreq(W)[None, :] * (s * base)
    r = np.sqrt(fx ** 2 + fy ** 2)
    r[0, 0] = 1.0
    spec = np.fft.rfft2(white) / r ** (beta / 2.0)
    spec[0, 0] = 0
    out = np.fft.irfft2(spec, s=(H, W))
    lo, hi = np.percentile(out, 0.05), np.percentile(out, 99.95)
    return np.clip((out - lo) / (hi - lo + 1e-9), 0, 1).astype(np.float32)


def _blur(a, sigma):
    """Flou gaussien d'un tableau (h, w) ou (h, w, c) de flottants (bords en miroir, pas de raccord)."""
    if sigma <= 0.05:
        return a
    p = int(3 * sigma) + 1
    pad = ((p, p), (p, p)) + (((0, 0),) if a.ndim == 3 else ())
    return _gblur(np.pad(a.astype(np.float32), pad, mode='reflect'), sigma)[p:-p, p:-p].astype(np.float32)


def _mask_hd(W, H, k, draw_fn, ss=2, mode='L'):
    """Masque (0 à 1) dessiné à ss × la taille finale puis réduit : draw_fn(d, kk) dessine avec des
    coordonnées d'origine × kk (kk = k × ss)."""
    big = Image.new(mode, (W * ss, H * ss), 0)
    draw_fn(ImageDraw.Draw(big), k * ss)
    return np.asarray(big.resize((W, H), Image.BOX), np.float32) / 255.0


def _text_on(mask, xy, txt, fnt, anchor='mm', angle=0.0, shear=0.0, fill=255, stroke=0):
    """Écrit txt sur le masque 'L' (ImageDraw.text, donc relevé par le contrôle des chaînes) : le point
    d'ancrage reste en xy, le texte est penché (shear) puis tourné (degrés, sens trigonométrique) autour de lui."""
    x0, y0, x1, y1 = fnt.getbbox(txt, anchor=anchor, stroke_width=stroke)
    pad = int(fnt.size * 0.5) + 4 + stroke
    tw, th = x1 - x0 + 2 * pad, y1 - y0 + 2 * pad
    tmp = Image.new('L', (tw, th), 0)
    ax, ay = pad - x0, pad - y0                  # le point d'ancrage dans tmp
    erase = fill == 0                            # fill = 0 : le texte en réserve (efface le masque)
    ink = 255 if erase else fill
    ImageDraw.Draw(tmp).text((ax, ay), txt, font=fnt, fill=ink, anchor=anchor, stroke_width=stroke, stroke_fill=ink)
    if shear:
        # x' = x + shear * (y - ay) : le pied de la ligne d'ancrage ne bouge pas
        ext = int(abs(shear) * th) + 2
        off = ext if shear > 0 else 0
        tmp = tmp.transform((tw + ext, th), Image.AFFINE, (1, shear, -shear * ay - off, 0, 1, 0), resample=Image.BICUBIC)
        ax += off
    if angle:
        big = Image.new('L', (tmp.width * 2 + 8, tmp.height * 2 + 8), 0)
        cx, cy = big.width // 2, big.height // 2
        big.paste(tmp, (int(cx - ax), int(cy - ay)))
        tmp = big.rotate(angle, resample=Image.BICUBIC, center=(cx, cy))
        ax, ay = cx, cy
    px, py = int(round(xy[0] - ax)), int(round(xy[1] - ay))
    from PIL import ImageChops
    region = mask.crop((px, py, px + tmp.width, py + tmp.height))
    mask.paste(ImageChops.subtract(region, tmp) if erase else ImageChops.lighter(region, tmp), (px, py))


def _wobble(m, s, amp=1.2, size=40.0, seed=0):
    """Écriture à la main : le masque (h, w) déformé par un champ de déplacement doux (amp px d'origine,
    ondulations de size px) : lignes qui ondulent, lettres qui ne se ressemblent plus tout à fait."""
    H, W = m.shape
    rs = np.random.RandomState(seed)
    gy, gx = max(2, int(H / s / size) + 3), max(2, int(W / s / size) + 3)
    dx = np.asarray(Image.fromarray(rs.randn(gy, gx).astype(np.float32), 'F').resize((W, H), Image.BICUBIC))
    dy = np.asarray(Image.fromarray(rs.randn(gy, gx).astype(np.float32), 'F').resize((W, H), Image.BICUBIC))
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    sx = np.clip(xx + dx * amp * s, 0, W - 1)
    sy = np.clip(yy + dy * amp * s * 0.6, 0, H - 1)
    x0, y0 = np.floor(sx).astype(int), np.floor(sy).astype(int)
    x1, y1 = np.minimum(x0 + 1, W - 1), np.minimum(y0 + 1, H - 1)
    fx, fy = sx - x0, sy - y0
    return ((m[y0, x0] * (1 - fx) + m[y0, x1] * fx) * (1 - fy) + (m[y1, x0] * (1 - fx) + m[y1, x1] * fx) * fy).astype(np.float32)


def _tex_detail(name, W, H, px_per_tile, seed=0, gray=True):
    """Détail d'une matière CC0 du projet (albédo d'ambientCG), autour de 1 : la texture divisée par sa
    moyenne locale, répétée à px_per_tile px, décalée au hasard (seed)."""
    path = os.path.join(TEX, name)
    im = Image.open(path).convert('L' if gray else 'RGB')
    k = px_per_tile / im.width
    im = im.resize((max(8, int(im.width * k)), max(8, int(im.height * k))), Image.LANCZOS)
    a = np.asarray(im, np.float32) / 255.0
    rs = np.random.RandomState(seed)
    oy, ox = rs.randint(0, a.shape[0]), rs.randint(0, a.shape[1])
    a = np.roll(np.roll(a, oy, 0), ox, 1)
    ry, rx = H // a.shape[0] + 2, W // a.shape[1] + 2
    a = np.tile(a, (ry, rx) + ((1,) if a.ndim == 3 else ()))[:H, :W]
    m = _blur(a, px_per_tile / 6)
    return a / np.maximum(m, 1e-3)


def _paper(W, H, s, color, seed, grain=1.0, tex='Paper001/Paper001_albedo.jpg', tile=1.0, mottle=0.06):
    """Papier : couleur × nuages (bruit fractal) × grain d'une vraie feuille (ambientCG Paper001/002,
    CC0) × fibres fines. tile : largeur d'une répétition du grain, en multiples de 256 px d'origine."""
    clouds = _fbm(W, H, 2.4, seed, s)
    mid = _fbm(W, H, 1.2, seed + 1, s)
    det = _tex_detail(tex, W, H, int(256 * s * tile * 0.5), seed)
    det = 1 + (det - 1) * 1.6 * grain
    lum = (1 - mottle / 2 + mottle * clouds) * (0.985 + 0.03 * mid) * det
    return np.asarray(color, np.float32)[None, None, :] * lum[..., None]


def _edges(arr, s, width=9.0, amount=0.16, yellow=0.0, seed=0):
    """Bords d'une feuille : plus sombres (et plus jaunes) sur quelques px d'origine, irréguliers."""
    H, W = arr.shape[:2]
    yy, xx = _grid(W, H, s)
    w0, h0 = W / s, H / s
    e = np.minimum(np.minimum(xx + 0.5, w0 - 0.5 - xx), np.minimum(yy + 0.5, h0 - 0.5 - yy))
    n = _fbm(W, H, 1.6, seed + 77, s)
    k = np.clip(e / (width * (0.6 + 0.8 * n)), 0, 1) ** 0.7
    arr = arr * (1 - amount + amount * k)[..., None]
    if yellow:
        arr = arr * (1 - yellow * (1 - k))[..., None] + (yellow * (1 - k))[..., None] * arr * np.array([1.05, 0.95, 0.7])
    return arr


def _fold(arr, s, at, axis, strength=1.0, width=2.5):
    """Pli d'une feuille (repère d'origine) : un côté éclairé, l'autre dans l'ombre, une arête claire et
    la crasse dans le creux. axis 'x' : pli vertical en x = at ; 'y' : horizontal en y = at."""
    H, W = arr.shape[:2]
    yy, xx = _grid(W, H, s)
    d = (xx - at) if axis == 'x' else (yy - at)
    side = np.tanh(d / width) * np.exp(-np.abs(d) / (width * 6))
    ridge = np.exp(-(d / (0.35 + 0.15 / s)) ** 2)
    dirt = np.exp(-(d / 0.9) ** 2)
    f = 1 + strength * (0.05 * side + 0.06 * ridge - 0.07 * dirt)
    return arr * f[..., None]


def _ink(arr, m, color, kind, rs, s, opacity=1.0):
    """Pose une encre à travers le masque m (0 à 1), selon l'outil :
    'bille'   stylo à bille : trait fin, encre inégale, petits manques, une pointe plus sombre aux reprises ;
    'feutre'  feutre : encre saturée qui bave dans les fibres (halo), stries du feutre qui sèche ;
    'imprime' imprimerie : net, dense, le grain du papier passe à peine ;
    'machine' ruban de machine à écrire : bords flous, encrage tacheté ;
    'crayon'  mine de crayon : grise, brillante, suit le grain."""
    H, W = m.shape
    col = np.asarray(color, np.float32)
    if kind == 'bille':
        m = _blur(m, 0.25 * s)
        dens = 0.78 + 0.22 * _fbm(W, H, 0.9, rs.randint(1 << 30), s)
        skip = np.clip((_fbm(W, H, 1.1, rs.randint(1 << 30), s) - 0.12) * 6, 0, 1)
        m = np.clip(m * 1.25, 0, 1) * dens * (0.55 + 0.45 * skip)
    elif kind == 'feutre':
        halo = _blur(m, 1.2 * s)
        arr = arr * (1 - (np.clip(halo * 0.28, 0, 0.3) * opacity)[..., None]) + (np.clip(halo * 0.28, 0, 0.3) * opacity)[..., None] * col
        streak = 0.9 + 0.1 * _fbm(W, H, 0.5, rs.randint(1 << 30), s)
        m = np.clip(_blur(m, 0.35 * s) * 1.2, 0, 1) * streak
    elif kind == 'imprime':
        m = _blur(m, 0.18 * s) * (0.94 + 0.06 * _fbm(W, H, 0.6, rs.randint(1 << 30), s))
    elif kind == 'machine':
        m = _blur(m, 0.3 * s)
        m = np.clip(m * (0.75 + 0.4 * rs.rand(H, W)), 0, 1)
    elif kind == 'crayon':
        m = _blur(m, 0.2 * s) * (0.5 + 0.5 * _fbm(W, H, 0.4, rs.randint(1 << 30), s))
    m = np.clip(m * opacity, 0, 1)[..., None]
    return arr * (1 - m) + col * m


def _grime_hd(arr, amount, rng, s, stains=3):
    """_grime_local() à la taille finale : points de poussière, traces claires et taches
    irrégulières (eau, café) avec leur auréole plus sombre. Même densité par surface d'origine."""
    H, W = arr.shape[:2]
    w0, h0 = W / s, H / s
    over = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for _ in range(int(w0 * h0 / 900)):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(0.25, 0.9) * s
        d.ellipse([x - r, y - r, x + r, y + r], fill=(30, 22, 12, int(rng.random() * 70 * amount)))
    for _ in range(6):
        x = rng.uniform(0, W)
        d.line([(x, 0), (x + rng.uniform(-20, 20) * s, H)], fill=(255, 255, 255, int(16 * amount)), width=max(1, int(0.6 * s)))
    over = over.filter(ImageFilter.GaussianBlur(0.6 * s))
    o = np.asarray(over, np.float32) / 255.0
    a = o[..., 3:4]
    arr = arr * (1 - a) + o[..., :3] * a
    if stains:
        yy, xx = _grid(W, H, s)
        n1 = _fbm(W, H, 2.0, rng.randint(0, 1 << 30), s)
        n2 = _fbm(W, H, 1.3, rng.randint(0, 1 << 30), s)
        for _ in range(stains):
            cx, cy, r = rng.uniform(0, w0), rng.uniform(0, h0), rng.uniform(20, 60)
            dd = np.hypot(xx - cx, (yy - cy) * rng.uniform(0.8, 1.25)) / r + 0.55 * (n1 - 0.5) + 0.12 * (n2 - 0.5)
            inside = np.clip((1 - dd) * 8, 0, 1)
            tide = np.exp(-((dd - 1) / 0.035) ** 2) * (0.6 + 0.8 * n2)
            k = amount * rng.uniform(0.5, 1.0)
            tint = np.array([0.82, 0.7, 0.5])
            arr = arr * (1 - (0.1 * k * inside + 0.22 * k * tide)[..., None] * (1 - tint))
    return arr


def _tape(arr, s, quad, rs, color=(0.93, 0.86, 0.6), alpha=0.32):
    """Un morceau de ruban adhésif (transparent jauni) posé sur la feuille : quad = 4 coins d'origine."""
    H, W = arr.shape[:2]
    m = _mask_hd(W, H, s, lambda d, k: d.polygon([(x * k, y * k) for x, y in quad], fill=255))
    n = _fbm(W, H, 1.0, rs.randint(1 << 30), s)
    a = (m * (alpha * (0.75 + 0.5 * n)))[..., None]
    arr = arr * (1 - a) + np.asarray(color, np.float32) * a * (arr * 0.6 + 0.4)
    # le bord du ruban, un peu plus clair (la colle qui accroche la poussière : un liseré)
    edge = np.clip(_blur(m, 0.4 * s) - _blur(m, 1.2 * s), 0, 1) * 2
    return arr * (1 + 0.15 * edge[..., None])


def _save_png(arr, name, alpha=None):
    """Enregistre arr (flottants 0 à 1) en PNG 8 bits dans assets/images (avec alpha s'il est donné)."""
    rgb = (np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8)
    if alpha is not None:
        a = (np.clip(alpha, 0, 1) * 255 + 0.5).astype(np.uint8)
        Image.fromarray(np.dstack([rgb, a]), 'RGBA').save(os.path.join(IMG, name), optimize=True)
    else:
        Image.fromarray(rgb, 'RGB').save(os.path.join(IMG, name), optimize=True)


def _ruled(arr, s, step, rs, first=1.6, margin=0.12, line=(0.62, 0.66, 0.84), red=(0.86, 0.52, 0.52), weight=0.55):
    """Lignes d'un cahier (bleu pâle, imprimées) et la marge rouge, aux positions de lined_paper()."""
    H, W = arr.shape[:2]
    w0, h0 = W / s, H / s

    def draw(d, k):
        for y in range(int(step * first), int(h0), step):
            d.line([(0, (y + 0.5) * k), (w0 * k, (y + 0.5) * k)], fill=255, width=max(1, int(weight * k)))
    arr = _ink(arr, _mask_hd(W, H, s, draw), line, 'imprime', rs, s, 0.8)
    mx = int(w0 * margin) + 0.5
    m2 = _mask_hd(W, H, s, lambda d, k: d.line([(mx * k, 0), (mx * k, h0 * k)], fill=255, width=max(1, int(weight * 1.1 * k))))
    return _ink(arr, m2, red, 'imprime', rs, s, 0.8)


def _thin(m, s, amount=1):
    """Amincit un trait (police manuscrite trop épaisse pour un stylo à bille) : érosion de amount × s/4 px."""
    im = Image.fromarray((np.clip(m, 0, 1) * 255).astype(np.uint8), 'L')
    for _ in range(max(1, int(round(amount * s / 4)))):
        im = im.filter(ImageFilter.MinFilter(3))
    return np.maximum(np.asarray(im, np.float32) / 255.0, m * 0.35)


def note():
    """Le mot de la chambre (au mur, sur le bureau, sous la porte) : « ne pas / jouer / après minuit », au
    stylo à bille bleu sur une feuille de cahier à lignes, pliée en quatre. 0.3.4 : 1024 × 1280 (×4)."""
    s, W, H = hd('note', 256, 320)
    rng, rs = _rngs(3200)
    arr = _paper(W, H, s, (0.945, 0.915, 0.835), 3201)
    arr = _ruled(arr, s, 28, rs)
    ink = Image.new('L', (W, H), 0)
    hand = font('ReenieBeanie.ttf', 50 * s)
    for i, txt in enumerate(['ne pas', 'jouer', 'après minuit']):
        _text_on(ink, ((128 + rng.uniform(-3, 3)) * s, (92 + i * 56 + rng.uniform(-2, 2)) * s), txt, hand,
                 angle=rng.uniform(-2.5, 1.5), shear=-0.06)
    m = _thin(_wobble(np.asarray(ink, np.float32) / 255.0, s, 1.0, 30, 3203), s)
    arr = _ink(arr, m, (0.13, 0.15, 0.42), 'bille', rs, s)
    arr *= (1 - 0.06 * np.clip(_blur(m, 0.8 * s) - m, 0, 1))[..., None]       # le sillon du stylo
    arr = _fold(arr, s, 160, 'y', 1.0)
    arr = _fold(arr, s, 128, 'x', 0.6)
    arr = _edges(arr, s, 7, 0.12, 0.3, 3202)
    _save_png(_grime_hd(arr, .35, rng, s), 'note.png')


def papers():
    """paper_312 : douze lignes de l'écriture de Manon à seize ans, « ne pas jouer », « 3:12 », de plus en
    plus appuyées, qui sortent de la feuille ; manual : la couverture du manuel de RUNTIME (1984), carte
    imprimée en deux couleurs, agrafée. 0.3.4 : 1024 × 1360 (×4)."""
    s, W, H = hd('paper_312', 256, 340)
    rng, rs = _rngs(3300)
    arr = _paper(W, H, s, (0.94, 0.905, 0.82), 3301)
    arr = _ruled(arr, s, 22, rs)
    ink = Image.new('L', (W, H), 0)
    for i in range(12):
        txt = '3:12  3:12  3:12  3:12' if i % 3 == 2 else 'ne pas jouer ne pas jouer'
        fnt = font('ReenieBeanie.ttf', 30 * s * rng.uniform(0.97, 1.05))
        _text_on(ink, ((40 + rng.uniform(-1.5, 1.5)) * s, (30 + i * 22 + rng.uniform(-1, 1)) * s), txt, fnt, anchor='la',
                 angle=rng.uniform(-1.2, 0.8), shear=-0.04 - 0.012 * i, fill=int(196 + 5 * i))
    m = _thin(_wobble(np.asarray(ink, np.float32) / 255.0, s, 1.5, 24, 3303), s)
    arr = _ink(arr, m, (0.15, 0.15, 0.43), 'bille', rs, s)
    arr *= (1 - 0.07 * np.clip(_blur(m, 0.8 * s) - m, 0, 1))[..., None]
    arr = _fold(arr, s, 170, 'y', 0.5)
    arr = _edges(arr, s, 8, 0.14, 0.3, 3302)
    _save_png(_grime_hd(arr, .4, rng, s), 'paper_312.png')

    # la couverture du manuel : carte crème, titre noir, illustration en deux tons (soleil rayé, sol
    # quadrillé qui fuit vers l'horizon : les douze lignes de la 0.3.3), « © 1984 » ; deux agrafes
    s, W, H = hd('manual', 256, 340)
    rng, rs = _rngs(3310)
    arr = _paper(W, H, s, (0.93, 0.92, 0.88), 3311, grain=0.7, tex='Paper002/Paper002_albedo.jpg')
    hz = 178.0                                                           # l'horizon de l'illustration

    def sun(d, k):
        d.pieslice([(128 - 62) * k, (hz - 62) * k, (128 + 62) * k, (hz + 62) * k], 180, 360, fill=255)
    cut = lambda d, k: [d.rectangle([60 * k, (hz - 40 + i * 9 - 1.2 - i * 0.45) * k, 196 * k, (hz - 40 + i * 9 + 1.2 + i * 0.45) * k],
                                    fill=255) for i in range(6)]
    sm = np.clip(_mask_hd(W, H, s, sun) - _mask_hd(W, H, s, cut), 0, 1)
    yy, xx = _grid(W, H, s)
    sunc = np.stack([np.full_like(yy, 0.86), 0.28 + 0.3 * np.clip((hz - yy) / 62, 0, 1), np.full_like(yy, 0.2)], -1)
    red = np.roll(np.roll(sm, int(0.5 * s), 1), -int(0.4 * s), 0)       # repérage approximatif du rouge
    arr = arr * (1 - red[..., None] * 0.92) + sunc * red[..., None] * 0.92 * (arr / 0.9)

    def floor(d, k):
        for i in range(12):                                              # les douze lignes, en perspective
            t = i / 11.0
            y = hz + 2 + 116 * t ** 1.7
            x_end = 236 - rng.randint(0, 8) if i % 4 else 236
            d.line([(20 * k, y * k), (x_end * k, y * k)], fill=255, width=max(1, int((0.7 + 1.6 * t) * k)))
        for j in range(-8, 9):
            d.line([((128 + j * 3) * k, (hz + 2) * k), ((128 + j * 40) * k, (hz + 120) * k)], fill=255, width=max(1, int(1.0 * k)))
    clip = _mask_hd(W, H, s, lambda d, k: d.rectangle([20 * k, (hz + 1) * k, 236 * k, (hz + 120) * k], fill=255))
    fm = _mask_hd(W, H, s, floor) * clip
    arr = _ink(arr, fm, (0.07, 0.27, 0.3), 'imprime', rs, s, 0.9)
    title = Image.new('L', (W, H), 0)
    _text_on(title, (20 * s, 18 * s), 'RUNTIME', font('IBMPlexMono-Bold.ttf', 30 * s), anchor='la')
    _text_on(title, (20 * s, 56 * s), "MANUEL DE L'UTILISATEUR", font('IBMPlexMono-Regular.ttf', 14 * s), anchor='la')
    _text_on(title, (20 * s, 316 * s), '© 1984', font('IBMPlexMono-Regular.ttf', 14 * s), anchor='la')
    arr = _ink(arr, np.asarray(title, np.float32) / 255.0, (0.08, 0.08, 0.09), 'imprime', rs, s)
    # deux agrafes dans le pli, à gauche ; le dos de la carte frotté
    for yc in (64, 276):
        st = _mask_hd(W, H, s, lambda d, k, yc=yc: d.rectangle([5 * k, (yc - 11) * k, 7.2 * k, (yc + 11) * k], fill=255))
        arr = arr * (1 - 0.35 * _blur(st, 1.2 * s)[..., None])
        arr = arr * (1 - st[..., None]) + st[..., None] * np.array([0.62, 0.62, 0.6]) * (0.8 + 0.4 * (np.roll(st, int(s), 0) < st))[..., None]
    arr = _fold(arr, s, 2.5, 'x', 1.2, 1.5)
    yy, xx = _grid(W, H, s)
    corner = np.clip(1 - np.hypot(xx - 256, yy - 340) / 26, 0, 1) * _fbm(W, H, 1.4, 3312, s)   # coin frotté, plus clair
    arr = arr * (1 - 0.25 * corner[..., None]) + corner[..., None] * 0.25 * np.array([0.95, 0.94, 0.9])
    arr = _edges(arr, s, 6, 0.14, 0.2, 3313)
    _save_png(_grime_hd(arr, .5, rng, s), 'manual.png')


def vhs_label():
    """L'étiquette de la cassette VHS : « NE PAS EFFACER » au feutre, sur une étiquette lignée. 1024 × 192 (×4)."""
    s, W, H = hd('vhs_label', 256, 48)
    rng, rs = _rngs(3320)
    arr = _paper(W, H, s, (0.945, 0.93, 0.88), 3321, grain=0.6)
    arr = _ruled(arr, s, 16, rs, weight=0.5)
    ink = Image.new('L', (W, H), 0)
    _text_on(ink, (128 * s, 26 * s), 'NE PAS EFFACER', font('ReenieBeanie.ttf', 34 * s), angle=-0.8, shear=-0.05)
    arr = _ink(arr, _wobble(np.asarray(ink, np.float32) / 255.0, s, 0.8, 20, 3323), (0.12, 0.12, 0.36), 'feutre', rs, s)
    arr = _edges(arr, s, 3, 0.18, 0.2, 3322)
    _save_png(_grime_hd(arr, .25, rng, s), 'vhs_label.png')


def floppy_label_albert():
    """Étiquette de disquette jaunie : « RUNTIME — SAUV. 01/11/99 » tapé à la machine, et par-dessus,
    au feutre noir, de travers, l'écriture d'Albert : NE PAS JOUER. 0.3.4 : 1024 × 384 (×4)."""
    s, W, H = hd('floppy_label', 256, 96)
    rng, rs = _rngs(302)
    yy, xx = _grid(W, H, s)
    stain = _fbm(W, H, 2.4, 3021, s, 256)
    edge = np.minimum(np.minimum(xx, 255 - xx), np.minimum(yy, 95 - yy))
    base = _paper(W, H, s, (0.89, 0.84, 0.66), 3023, grain=0.8)
    arr = base * ((0.86 + 0.18 * stain) * (0.8 + 0.2 * np.clip(edge / 9.0, 0, 1)))[..., None]
    lines = _mask_hd(W, H, s, lambda d, k: [d.line([(8 * k, (y + 0.5) * k), (247 * k, (y + 0.5) * k)], fill=255,
                                                     width=max(1, int(0.6 * k))) for y in (38, 60, 82)])
    arr = _ink(arr, lines, (0.66, 0.63, 0.59), 'imprime', rs, s)
    band = _mask_hd(W, H, s, lambda d, k: d.rectangle([0, 0, 256 * k, 5 * k], fill=255))
    arr = _ink(arr, band, (0.59, 0.19, 0.16), 'imprime', rs, s)           # liseré rouge du haut de l'étiquette
    typed = Image.new('L', (W, H), 0)
    tf = font('IBMPlexMono-Regular.ttf', 15 * s)
    txt = 'RUNTIME — SAUV. 01/11/99'
    adv = tf.getlength('M') / s
    x0 = (256 - adv * len(txt)) / 2
    for i, ch in enumerate(txt):
        _text_on(typed, ((x0 + i * adv + rng.uniform(-.3, .3)) * s, (22 + rng.uniform(-.7, .7)) * s), ch, tf, anchor='lm',
                 fill=int(255 * rng.uniform(.62, 1.0)))
    arr = _ink(arr, np.asarray(typed, np.float32) / 255.0, (0.1, 0.09, 0.12), 'machine', rs, s, 0.92)
    hand = None
    size = 64
    for size in range(64, 30, -2):
        hand = font('ReenieBeanie.ttf', size)
        x_a, y_a, x_b, y_b = hand.getbbox('NE PAS JOUER', stroke_width=2)
        if x_b - x_a < 226:
            break
    hand = font('ReenieBeanie.ttf', size * s)
    big = Image.new('L', (W * 2, H * 2), 0)
    cx, cy = W, H + 8 * s
    total = hand.getlength('NE PAS JOUER')
    x = cx - total / 2
    for word, drop in [('NE', -.9), ('PAS', .1), ('JOUER', 1.0)]:   # chaque mot un peu plus bas : la main qui descend
        _text_on(big, (x, cy + drop * 3 * s), word, hand, anchor='lm', stroke=int(2 * s))
        x += hand.getlength(word + ' ')
    big = big.rotate(-7.5, resample=Image.BICUBIC, center=(cx, cy))
    big = big.crop((W // 2, H // 2, W // 2 + W, H // 2 + H))
    m = np.asarray(big, np.float32) / 255.0
    arr = _ink(arr, m, (0.045, 0.04, 0.05), 'feutre', rs, s, 0.95)
    _save_png(_grime_hd(arr, .45, rng, s), 'floppy_label.png')


def ceraf_label():
    """Autocollant d'inventaire en alu brossé, usé : CERAF · INVENTAIRE N° 0312, code-barres,
    PROPRIÉTÉ DU CERAF — NE PAS SORTIR DU SITE. Collé sur le matériel qu'Albert a ramené du labo.
    0.3.4 : 1024 × 384 (×4)."""
    s, W, H = hd('ceraf_label', 256, 96)
    rng, rs = _rngs(304)
    yy, xx = _grid(W, H, s)
    # alu brossé : stries horizontales (bruit étalé le long de x), reflet en bande
    pad = int(32 * s)
    raw = rs.randn(H, W + 2 * pad).astype(np.float32)
    n = int(48 * s)
    cs = np.cumsum(raw, axis=1)
    brushed = (cs[:, n:] - cs[:, :-n])[:, pad - n // 2:pad - n // 2 + W] / n
    fine = (cs[:, 3:] - cs[:, :-3])[:, pad:pad + W] / 3
    brushed = brushed / (np.abs(brushed).max() + 1e-9)
    sheen = 0.58 + 0.28 * np.exp(-((yy - 26 - 0.12 * xx) / 26) ** 2)
    metal = sheen + 0.07 * brushed + 0.012 * fine / (np.abs(fine).max() + 1e-9) * 3
    metal = metal[..., None] * np.array([0.97, 0.98, 1.0])
    ink = Image.new('L', (W, H), 0)
    di = ImageDraw.Draw(ink)
    k = s
    di.rectangle([5 * k, 5 * k, (256 - 5) * k, 29 * k], fill=255)       # bandeau noir
    _text_on(ink, (128 * k, 17 * k), 'CERAF · INVENTAIRE N° 0312', font('IBMPlexMono-Bold.ttf', 14 * k), fill=0)
    x = 14
    for wd, bar in _code39('0312'):
        if bar:
            di.rectangle([x * k, 35 * k, (x + wd) * k - 1, 63 * k - 1], fill=255)
        x += wd
    _text_on(ink, ((14 + (x - 14) / 2) * k, 69 * k), '0312', font('IBMPlexMono-Regular.ttf', 10 * k))
    _text_on(ink, (178 * k, 47 * k), 'N° 0312', font('IBMPlexMono-Bold.ttf', 24 * k))
    di.rectangle([118 * k, 63 * k, (256 - 10) * k, 63.8 * k], fill=255)
    _text_on(ink, (128 * k, 83 * k), 'PROPRIÉTÉ DU CERAF — NE PAS SORTIR DU SITE', font('IBMPlexMono-Bold.ttf', 9 * k))
    di.rectangle([2 * k, 2 * k, 254 * k, 94 * k], outline=255, width=max(1, int(0.9 * k)))   # filet du bord
    m = np.asarray(ink, np.float32) / 255.0
    m = _blur(m, 0.2 * s)
    wear = _fbm(W, H, 1.6, 3041, s, 256)
    edge = np.minimum(np.minimum(xx, 255 - xx), np.minimum(yy, 95 - yy))
    keep = np.clip((wear + 0.55 * np.clip(edge / 14, 0, 1) - 0.42) * 6, 0, 1)
    scr = Image.new('L', (W, H), 0)
    dsc = ImageDraw.Draw(scr)
    for _ in range(40):
        x0, y0 = rng.uniform(0, 256), rng.uniform(0, 96)
        a = rng.uniform(-0.5, 0.5) + (np.pi / 2 if rng.random() < .2 else 0)
        ln = rng.uniform(6, 42)
        dsc.line([(x0 * k, y0 * k), ((x0 + ln * np.cos(a)) * k, (y0 + ln * np.sin(a)) * k)], fill=rng.randint(70, 190),
                 width=max(1, int(rng.choice([0.3, 0.5, 0.8]) * k)))
    sc = np.asarray(scr.filter(ImageFilter.GaussianBlur(0.3 * s)), np.float32) / 255.0
    m = m * keep * (1 - sc * 0.75)
    arr = metal * (1 - m[..., None]) + np.array([0.06, 0.06, 0.07]) * m[..., None]
    arr += sc[..., None] * 0.12 * (1 - m[..., None])
    dirt = _fbm(W, H, 2.6, 3042, s, 256)
    arr *= (0.78 + 0.25 * dirt * (0.6 + 0.4 * np.clip(edge / 10, 0, 1)))[..., None]
    arr *= (0.75 + 0.25 * np.clip(edge / 4, 0, 1))[..., None]
    # le coin en bas à droite se décolle
    cm = _mask_hd(W, H, s, lambda d, kk: d.polygon([(255.5 * kk, 80 * kk), (255.5 * kk, 95.5 * kk), (240 * kk, 95.5 * kk)], fill=255))
    arr = arr * (1 - cm[..., None]) + cm[..., None] * np.array([0.16, 0.16, 0.165])
    flap = _mask_hd(W, H, s, lambda d, kk: d.polygon([(255.5 * kk, 80 * kk), (244 * kk, 84 * kk), (240 * kk, 95.5 * kk)], fill=255))
    shade = 0.75 + 0.25 * np.clip((xx - 240) / 16, 0, 1)
    arr = arr * (1 - flap[..., None]) + flap[..., None] * np.array([0.81, 0.8, 0.77]) * shade[..., None]
    arr = arr * (1 - 0.5 * np.clip(_blur(flap, 1.5 * s) - flap, 0, 1)[..., None])
    _save_png(arr, 'ceraf_label.png')


def _poster_wear(arr, s, rng, rs, folds_x=(), folds_y=(), tape=True, pins=False, fade=0.08, seed=0):
    """Une affiche restée trente ans au mur : pliée pour la poste (plis), ruban adhésif jauni aux coins
    (ou punaises), bords frottés et petites déchirures, couleurs passées au soleil."""
    H, W = arr.shape[:2]
    w0, h0 = W / s, H / s
    lum = arr.mean(-1, keepdims=True)
    arr = arr * (1 - fade) + (lum * 0.6 + 0.4 * arr) * fade + fade * 0.06            # passé, un peu laiteux
    for x in folds_x:
        arr = _fold(arr, s, x, 'x', 1.4, 3.0)
    for y in folds_y:
        arr = _fold(arr, s, y, 'y', 1.4, 3.0)
    # usure le long des plis : l'encre part en petits éclats blancs
    yy, xx = _grid(W, H, s)
    n = _fbm(W, H, 0.7, seed + 11, s)
    wear = np.zeros_like(yy)
    for x in folds_x:
        wear = np.maximum(wear, np.exp(-((xx - x) / 0.8) ** 2))
    for y in folds_y:
        wear = np.maximum(wear, np.exp(-((yy - y) / 0.8) ** 2))
    chips = np.clip((n - 0.62) * 6, 0, 1) * wear
    arr = arr * (1 - chips[..., None]) + chips[..., None] * np.array([0.86, 0.84, 0.78])
    if tape:
        for cx, cy, sx, sy in ((0, 0, 1, 1), (w0, 0, -1, 1), (0, h0, 1, -1), (w0, h0, -1, -1)):
            a, b = rng.uniform(16, 26), rng.uniform(6, 9)
            ang = np.radians(45 + rng.uniform(-12, 12))
            ox, oy = cx + sx * rng.uniform(4, 9), cy + sy * rng.uniform(4, 9)
            ux, uy = np.cos(ang) * sx, np.sin(ang) * sy
            vx, vy = -uy, ux
            quad = [(ox - ux * a - vx * b, oy - uy * a - vy * b), (ox + ux * a - vx * b, oy + uy * a - vy * b),
                    (ox + ux * a + vx * b, oy + uy * a + vy * b), (ox - ux * a + vx * b, oy - uy * a + vy * b)]
            arr = _tape(arr, s, quad, rs)
    if pins:
        for px, py in ((10, 10), (w0 - 10, 10), (10, h0 - 10), (w0 - 10, h0 - 10)):
            hole = np.exp(-(((xx - px) ** 2 + (yy - py) ** 2) / 1.4))
            arr *= (1 - 0.8 * hole)[..., None]
    e = np.minimum(np.minimum(xx, w0 - 1 - xx), np.minimum(yy, h0 - 1 - yy))
    rub = np.clip(1 - e / 5, 0, 1) * np.clip((n - 0.35) * 3, 0, 1)
    arr = arr * (1 - 0.5 * rub[..., None]) + rub[..., None] * 0.5 * np.array([0.8, 0.77, 0.7])
    return arr


def _capsule(d, k, a, b, r, fill=255):
    """Un trait arrondi (capsule) de a à b, rayon r (repère d'origine)."""
    d.line([(a[0] * k, a[1] * k), (b[0] * k, b[1] * k)], fill=fill, width=max(1, int(2 * r * k)))
    for p in (a, b):
        d.ellipse([(p[0] - r) * k, (p[1] - r) * k, (p[0] + r) * k, (p[1] + r) * k], fill=fill)


def poster_choisis():
    """Affiche du film CHOISIS OU SINON (1983) : ciel rouge d'aérographe, une lune pâle, une silhouette
    en long manteau debout sur la colline, la brume au pied des sapins. Offset sur papier couché, pliée en
    six pour la poste, scotchée aux coins. 0.3.4 : 1024 × 1472 (×2)."""
    s, W, H = hd('poster_choisis', 512, 736)
    rng, rs = _rngs(3400)
    w0, h0 = 512, 736
    yy, xx = _grid(W, H, s)
    t = yy / h0
    r = np.where(t < .6, 42 + 80 * np.minimum(1, t / .6), 122 - 112 * (t - .6) / .4)
    g = 11 + 16 * np.minimum(1, t / .6)
    b = 16 + 6 * np.minimum(1, t / .6)
    arr = np.stack([r, g, b], -1) / 255.0
    clouds = _fbm(W, H, 2.6, 3401, s)
    arr *= (0.8 + 0.4 * clouds)[..., None]
    # la lune, derrière la tête, et son halo d'aérographe
    mx, my = 256, 268
    dm = np.hypot(xx - mx, yy - my)
    arr += (np.exp(-(dm / 150) ** 2) * 0.22)[..., None] * np.array([1.0, 0.45, 0.3])
    moon = np.clip((96 - dm) * 0.6, 0, 1)
    mtex = 0.88 + 0.12 * _fbm(W, H, 1.8, 3402, s)
    arr = arr * (1 - moon[..., None]) + moon[..., None] * np.array([0.95, 0.83, 0.68]) * mtex[..., None]
    # étoiles
    st = Image.new('L', (W, H), 0)
    dst = ImageDraw.Draw(st)
    for _ in range(140):
        x, y = rng.uniform(0, w0), rng.uniform(0, h0 * 0.45)
        rr = rng.uniform(0.3, 1.0) * s
        dst.ellipse([x * s - rr, y * s - rr, x * s + rr, y * s + rr], fill=rng.randint(60, 220))
    arr += (np.asarray(st, np.float32) / 255.0 * (1 - moon))[..., None] * 0.5 * np.array([1.0, 0.9, 0.85])

    def hills(d, k):
        pts = [(0, h0 * .62 * k)]
        for x in range(0, w0 + 1, 4):
            y = h0 * .62 - abs(np.sin(x * .035)) * 80 - (36 if x % 96 < 48 else 0) * (0.5 + 0.5 * np.cos(x * 0.065))
            pts.append((x * k, y * k))
        pts += [(w0 * k, h0 * k), (0, h0 * k)]
        d.polygon(pts, fill=255)
        for i in range(46):                                               # les sapins sur la crête
            x = rng.uniform(0, w0)
            yb = h0 * .62 - abs(np.sin(x * .035)) * 80 - 20
            ht = rng.uniform(40, 120)
            for j in range(10):                                           # étages de branches tombantes
                f = j / 9
                half = 3 + ht * 0.2 * f
                yy_ = yb - ht + ht * f
                d.polygon([((x - half) * k, (yy_ + 6) * k), (x * k, (yy_ - 4) * k), ((x + half) * k, (yy_ + 6) * k)], fill=255)
            d.line([(x * k, (yb - ht - 8) * k), (x * k, (yb + 20) * k)], fill=255, width=max(1, int(1.5 * k)))
    hm = _mask_hd(W, H, s, hills)
    arr = arr * (1 - hm[..., None]) + hm[..., None] * np.array([0.02, 0.012, 0.035])

    def figure(d, k):                                                     # en long manteau, la tête un peu baissée
        cx = 256
        d.ellipse([(cx - 27) * k, (my - 52) * k, (cx + 27) * k, (my + 12) * k], fill=255)               # tête
        d.polygon([((cx - 12) * k, (my + 4) * k), ((cx + 12) * k, (my + 4) * k), ((cx + 15) * k, (my + 30) * k),
                   ((cx - 15) * k, (my + 30) * k)], fill=255)                                           # cou
        coat = [(cx - 18, my + 26), (cx - 62, my + 44), (cx - 74, my + 76), (cx - 76, my + 200), (cx - 84, my + 330),
                (cx - 98, h0), (cx + 98, h0), (cx + 86, my + 330), (cx + 78, my + 200), (cx + 76, my + 76),
                (cx + 64, my + 44), (cx + 18, my + 26)]
        d.polygon([(x * k, y * k) for x, y in coat], fill=255)
        for sx in (-1, 1):                                                # bras le long du corps, mains
            _capsule(d, k, (cx + sx * 70, my + 64), (cx + sx * 84, my + 250), 14)
            d.ellipse([(cx + sx * 84 - 10) * k, (my + 240) * k, (cx + sx * 84 + 10) * k, (my + 276) * k], fill=255)
        d.polygon([((cx - 26) * k, (my - 40) * k), ((cx + 26) * k, (my - 40) * k), ((cx + 34) * k, (my - 16) * k),
                   ((cx - 34) * k, (my - 16) * k)], fill=255)                                           # bord du chapeau
    fm = _mask_hd(W, H, s, figure)
    fm = _blur(fm, 0.5 * s)
    rim = np.clip(fm - np.roll(np.roll(_blur(fm, 2.5 * s), int(2 * s), 1), int(2 * s), 0), 0, 1) * np.exp(-((yy - my) / 140) ** 2)
    arr = arr * (1 - fm[..., None]) + fm[..., None] * np.array([0.03, 0.015, 0.03])
    arr += rim[..., None] * np.array([0.9, 0.35, 0.2]) * 0.6
    # la brume au pied
    fog = np.clip((yy - h0 * 0.6) / (h0 * 0.18), 0, 1) * np.clip((h0 * 0.95 - yy) / (h0 * 0.2), 0, 1)
    fog *= 0.5 + 0.7 * _fbm(W, H, 2.2, 3403, s)
    arr += (fog * 0.26)[..., None] * np.array([0.8, 0.32, 0.3])
    # les textes
    txt = Image.new('L', (W, H), 0)
    _text_on(txt, (256 * s, 120 * s), 'CHOISIS', font('IBMPlexMono-Bold.ttf', 92 * s))
    _text_on(txt, (256 * s, 196 * s), 'OU SINON', font('IBMPlexMono-Bold.ttf', 54 * s))
    tm = np.asarray(txt, np.float32) / 255.0

    cred = Image.new('L', (W, H), 0)
    _text_on(cred, (256 * s, (h0 - 40) * s), 'UN FILM DE J. MORVAN · 1983', font('IBMPlexMono-Regular.ttf', 22 * s))
    cm = np.asarray(cred, np.float32) / 255.0
    arr = arr * (1 - 0.6 * np.roll(np.roll(_blur(tm, 2 * s), int(2 * s), 0), int(1 * s), 1)[..., None])   # ombre portée
    grad = (0.95 - 0.12 * np.clip((yy - 80) / 140, 0, 1))[..., None]
    arr = _ink(arr, tm, (0.95, 0.89, 0.78), 'imprime', rs, s) * (1 - tm[..., None] * (1 - grad))
    arr = _ink(arr, cm, (0.79, 0.7, 0.54), 'imprime', rs, s)
    arr *= _paper(W, H, s, (1, 1, 1), 3404, grain=0.5, mottle=0.03)
    arr = _poster_wear(arr, s, rng, rs, folds_x=(256,), folds_y=(245, 490), fade=0.1, seed=3405)
    _save_png(_grime_hd(arr, .6, rng, s), 'poster_choisis.png')


def poster_spectres():
    """Affiche de concert LES SPECTRES (1984) : sérigraphie deux couleurs, cercles jaunes sur noir.
    Le noir est passé un peu décalé (filets de papier entre les couleurs), l'encre jaune garde la trame
    de l'écran. Pliée en quatre, scotchée. 0.3.4 : 1024 × 1024 (×2)."""
    s, W, H = hd('poster_spectres', 512, 512)
    rng, rs = _rngs(3410)
    paper = _paper(W, H, s, (0.93, 0.91, 0.84), 3411, grain=0.6)

    def rings(d, k):
        for i in range(12, 0, -1):
            r = 40 + i * 22
            d.ellipse([(256 - r) * k, (256 - r) * k, (256 + r) * k, (256 + r) * k], fill=255 if i % 2 else 0)
        d.rectangle([0, 512 * .38 * k, 512 * k, 512 * .62 * k], fill=0)
    ym = _mask_hd(W, H, s, rings)
    tx = Image.new('L', (W, H), 0)
    _text_on(tx, (256 * s, 512 * .47 * s), 'LES SPECTRES', font('IBMPlexMono-Bold.ttf', 60 * s))
    _text_on(tx, (256 * s, 512 * .56 * s), 'TOURNÉE 84 · COMPLET', font('IBMPlexMono-Regular.ttf', 26 * s))
    ym = np.maximum(ym, np.asarray(tx, np.float32) / 255.0)
    mesh = 0.9 + 0.1 * _fbm(W, H, 0.3, 3412, s)                         # trame de l'écran, encre inégale
    yellow = np.array([0.91, 0.86, 0.2])
    arr = paper * (1 - ym[..., None] * mesh[..., None]) + ym[..., None] * mesh[..., None] * yellow * (paper / 0.9)
    off = (int(round(0.9 * s)), int(round(-0.6 * s)))
    black = 1 - np.roll(np.roll(_blur(ym, 0.2 * s), off[0], 1), off[1], 0)
    black = np.clip((black - 0.08) * 1.15, 0, 1) * (0.93 + 0.07 * _fbm(W, H, 0.4, 3413, s))
    arr = arr * (1 - black[..., None] * 0.93) + black[..., None] * 0.93 * np.array([0.07, 0.07, 0.075])
    arr = _poster_wear(arr, s, rng, rs, folds_x=(256,), folds_y=(256,), fade=0.12, seed=3414)
    _save_png(_grime_hd(arr, .5, rng, s), 'poster_spectres.png')


def _crow(d, k, x, y, size, ang, flap, rng):
    """Un corbeau en vol vu d'en dessous (silhouette) : corps, tête et bec, queue en éventail, deux ailes
    aux cinq rémiges écartées comme des doigts. size : demi-envergure (px d'origine), ang : cap (radians,
    0 = vers la droite), flap : -1 (ailes basses) à 1 (ailes hautes : envergure apparente plus courte)."""
    ca, sa = np.cos(ang), np.sin(ang)
    T = lambda u, v: ((x + (u * ca - v * sa) * size) * k, (y + (u * sa + v * ca) * size) * k)
    d.polygon([T(-0.3, 0), T(-0.18, -0.07), T(0.1, -0.075), T(0.3, -0.055), T(0.34, -0.03), T(0.33, 0.03),
               T(0.3, 0.055), T(0.1, 0.075), T(-0.18, 0.07)], fill=255)
    d.ellipse([T(0.36 - 0.07, -0.07)[0] if False else (x + 0.36 * ca * size - 0.07 * size) * k,
               (y + 0.36 * sa * size - 0.07 * size) * k, (x + 0.36 * ca * size + 0.07 * size) * k,
               (y + 0.36 * sa * size + 0.07 * size) * k], fill=255)
    d.polygon([T(0.4, -0.035), T(0.53, 0.0), T(0.4, 0.03)], fill=255)                   # le bec
    d.polygon([T(-0.25, -0.05), T(-0.5, -0.12), T(-0.55, -0.05), T(-0.56, 0.05), T(-0.5, 0.12), T(-0.25, 0.05)], fill=255)
    span = 1 - 0.32 * abs(flap)
    du = 0.08 * flap
    wing = [(0.12, 0.05), (0.2, 0.3), (0.22, 0.5), (0.16, 0.7), (0.1, 0.88), (0.04, 1.0), (0.0, 0.9), (-0.04, 0.96),
            (-0.07, 0.86), (-0.11, 0.9), (-0.13, 0.8), (-0.17, 0.82), (-0.18, 0.72), (-0.22, 0.72), (-0.2, 0.6),
            (-0.23, 0.48), (-0.19, 0.4), (-0.21, 0.3), (-0.17, 0.22), (-0.18, 0.13), (-0.14, 0.05)]
    for side in (-1, 1):
        d.polygon([T(u + du * v, side * v * span) for u, v in wing], fill=255)


def poster_corbeaux():
    """Affiche de concert LES CORBEAUX (salle des fêtes, 31 octobre) : un vol de corbeaux, un cercle
    rouge peint au pinceau, le titre en gothique. Photocopie tramée sur papier gris, agrafée. 0.3.4 :
    1024 × 1434 (×2,56)."""
    s, W, H = hd('poster_corbeaux', 400, 560)
    rng, rs = _rngs(3420)
    yy, xx = _grid(W, H, s)
    arr = np.ones((H, W, 3), np.float32) * np.array([0.07, 0.063, 0.086])
    arr *= (0.85 + 0.3 * _fbm(W, H, 2.0, 3421, s))[..., None]
    # le cercle rouge : un coup de pinceau sec, qui se charge puis s'épuise
    a = np.arctan2(yy - 250, xx - 200)
    rr = np.hypot(xx - 200, (yy - 250) * (110 / 110))
    wob = 110 + 3 * np.sin(a * 3 + 1) + 2 * np.sin(a * 7)
    stroke = np.clip(1 - np.abs(rr - wob) / (3.2 + 1.5 * np.sin(a + 2)), 0, 1)
    dry = np.clip((_fbm(W, H, 0.5, 3422, s) + 0.35 * np.sin(a * 2 - 0.5) - 0.25) * 4, 0, 1)
    bristle = 0.7 + 0.3 * np.sin(rr * 9.0 + 0.3 * _fbm(W, H, 1.0, 3423, s) * 40)
    ring = stroke * dry * bristle
    arr = arr * (1 - ring[..., None]) + ring[..., None] * np.array([0.6, 0.08, 0.1])
    # les corbeaux
    def crows(d, k):
        for i in range(11):
            x, y, sz = rng.uniform(30, 370), rng.uniform(120, 390), rng.uniform(18, 46)
            _crow(d, k, x, y, sz, rng.uniform(-0.6, 0.6) + (np.pi if rng.random() < 0.4 else 0), rng.uniform(-1, 1), rng)
    cm = _mask_hd(W, H, s, crows)
    arr = arr * (1 - cm[..., None]) + cm[..., None] * np.array([0.012, 0.012, 0.018])
    txt = Image.new('L', (W, H), 0)
    _text_on(txt, (200 * s, 70 * s), 'Les Corbeaux', font('UnifrakturMaguntia-Book.ttf', 46 * s))
    arr = _ink(arr, np.asarray(txt, np.float32) / 255.0, (0.8, 0.76, 0.68), 'imprime', rs, s)
    t2 = Image.new('L', (W, H), 0)
    _text_on(t2, (200 * s, 440 * s), 'EN CONCERT', font('IBMPlexMono-Bold.ttf', 36 * s))
    arr = _ink(arr, np.asarray(t2, np.float32) / 255.0, (0.6, 0.08, 0.1), 'imprime', rs, s)
    t3 = Image.new('L', (W, H), 0)
    _text_on(t3, (200 * s, 490 * s), 'SALLE DES FÊTES · 31 OCTOBRE', font('IBMPlexMono-Regular.ttf', 18 * s))
    arr = _ink(arr, np.asarray(t3, np.float32) / 255.0, (0.68, 0.64, 0.6), 'imprime', rs, s)
    # photocopie : poudre de toner sur les aplats, voile gris du papier
    toner = np.clip((_fbm(W, H, 0.2, 3424, s) - 0.8) * 5, 0, 1)
    arr = arr + toner[..., None] * 0.08
    arr *= _paper(W, H, s, (1, 1, 1), 3425, grain=0.4, mottle=0.04, tex='Paper002/Paper002_albedo.jpg')
    # agrafes en haut
    for x0 in (14, 386):
        st = _mask_hd(W, H, s, lambda d, k, x0=x0: d.rectangle([(x0 - 6) * k, 9 * k, (x0 + 6) * k, 10.6 * k], fill=255))
        arr = arr * (1 - 0.5 * _blur(st, 1.0 * s)[..., None])
        arr = arr * (1 - st[..., None]) + st[..., None] * np.array([0.7, 0.7, 0.68])
    arr = _poster_wear(arr, s, rng, rs, folds_y=(280,), tape=False, fade=0.05, seed=3426)
    _save_png(_grime_hd(arr, .8, rng, s), 'poster_corbeaux.png')


def _photos_module():
    """tools/make_photos.py (les photos tirées des backplates de Poly Haven), chargé sans toucher sys.path
    (MAKE_PHOTOS : un autre fichier, pour les essais)."""
    import importlib.util
    path = os.environ.get('MAKE_PHOTOS', os.path.join(ROOT, 'tools', 'make_photos.py'))
    spec = importlib.util.spec_from_file_location('make_photos', path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _pushpin(arr, s, x, y, rng, col=(0.75, 0.1, 0.1)):
    """Une punaise vue de face (repère d'origine) : tête bombée et son reflet, ombre portée sur le support."""
    H, W = arr.shape[:2]
    yy, xx = _grid(W, H, s)
    d = np.hypot(xx - x, yy - y)
    ds = np.hypot(xx - x - 2.2, yy - y - 3.0)
    arr = arr * (1 - 0.5 * np.clip(1 - ds / 7.5, 0, 1) ** 1.5)[..., None]
    head = np.clip((6.2 - d) * s * 0.5, 0, 1)
    shade = np.clip(1 - np.hypot(xx - x + 1.8, yy - y + 2.0) / 8.5, 0, 1)
    c = np.asarray(col) * (0.45 + 0.75 * shade[..., None])
    spec = np.exp(-(np.hypot(xx - x + 2.0, yy - y + 2.4) / 1.3) ** 2)
    c = c + spec[..., None] * 0.7
    rim = np.clip(1 - np.abs(d - 5.4) / 0.9, 0, 1) * 0.35
    return arr * (1 - head[..., None]) + head[..., None] * (c * (1 - rim[..., None]))


def _polaroid_photo(kind, w, h, s, rng, rs):
    """Le tirage d'un polaroïd de 2016 (w × h px d'origine) : concert, copines au soleil couchant, nuit."""
    W, H = int(w * s), int(h * s)
    yy, xx = _grid(W, H, s)
    if kind == 'concert':
        arr = np.zeros((H, W, 3), np.float32) + np.array([0.04, 0.02, 0.07])
        for bx, col in ((25, (0.5, 0.2, 0.9)), (55, (0.95, 0.3, 0.5)), (80, (0.2, 0.5, 1.0))):
            ang = np.arctan2(xx - bx, yy + 5)
            beam = np.exp(-(ang / 0.13) ** 2) * np.clip((yy + 5) / h, 0, 1) ** 0.4
            arr += beam[..., None] * np.array(col) * 0.6
            arr += (np.exp(-(np.hypot(xx - bx, yy + 2) / 6) ** 2) * 1.2)[..., None] * np.array(col)
        crowd = _mask_hd(W, H, s, lambda d, k: [d.ellipse([(x - 7) * k, (y - 8) * k, (x + 7) * k, (y + 9) * k], fill=255)
                                                 for x, y in [(rng.uniform(-5, w + 5), rng.uniform(h * 0.62, h * 0.8)) for _ in range(26)]]
                       + [d.rectangle([0, h * 0.75 * k, w * k, h * k], fill=255)]
                       + [_capsule(d, k, (rng.uniform(10, w - 10), h * 0.7), (rng.uniform(10, w - 10), h * 0.25), 2.2) for _ in range(3)])
        arr = arr * (1 - crowd[..., None] * 0.95)
    elif kind == 'copines':
        t = yy / h
        arr = np.stack([0.98 - 0.25 * t, 0.62 - 0.2 * t, 0.36 - 0.1 * t], -1)
        sun = np.exp(-(np.hypot(xx - w * 0.5, yy - h * 0.55) / 9) ** 2)
        arr += sun[..., None] * np.array([1.0, 0.8, 0.5])
        wall = yy > h * 0.7
        arr = np.where(wall[..., None], np.array([0.12, 0.07, 0.06]), arr)

        def girls(d, k):
            for cx, hr in ((w * 0.36, 7.5), (w * 0.62, 7.0)):
                d.ellipse([(cx - hr) * k, (h * 0.42 - hr) * k, (cx + hr) * k, (h * 0.42 + hr * 1.1) * k], fill=255)
                d.polygon([((cx - hr * 1.1) * k, (h * 0.42) * k), ((cx + hr * 1.1) * k, (h * 0.42) * k),
                           ((cx + hr * 1.5) * k, (h * 0.62) * k), ((cx - hr * 1.5) * k, (h * 0.62) * k)], fill=255)  # cheveux
                d.ellipse([(cx - hr * 2.2) * k, (h * 0.55) * k, (cx + hr * 2.2) * k, (h * 0.75) * k], fill=255)
                d.rectangle([(cx - hr * 2.0) * k, (h * 0.64) * k, (cx + hr * 2.0) * k, h * 0.75 * k], fill=255)
        gm = _blur(_mask_hd(W, H, s, girls), 0.4 * s)
        arr = arr * (1 - gm[..., None]) + gm[..., None] * np.array([0.08, 0.04, 0.04])
    else:   # la nuit : le coin de la chambre, une forme pâle floue dans l'embrasure de la porte
        arr = np.zeros((H, W, 3), np.float32) + np.array([0.05, 0.05, 0.06])
        door = np.clip(1 - np.abs(xx - w * 0.68) / 9, 0, 1) * (yy > h * 0.12)
        arr += door[..., None] * np.array([0.1, 0.1, 0.12])
        ghost = np.exp(-(((xx - w * 0.68) / 4.5) ** 2 + ((yy - h * 0.45) / 16) ** 2))
        arr += ghost[..., None] * np.array([0.42, 0.44, 0.45])
        arr += (np.exp(-(np.hypot(xx - w * 0.2, yy - h * 0.3) / 30) ** 2) * 0.25)[..., None] * np.array([1.0, 0.9, 0.7])
    arr = _blur(arr, 0.7 * s)
    arr = arr + rs.randn(H, W, 1).astype(np.float32) * 0.03
    lum = arr.mean(-1, keepdims=True)
    arr = 0.08 + 0.85 * (arr * 0.8 + lum * 0.2) * np.array([1.02, 0.97, 0.86])        # polaroïd passé
    vig = 1 - 0.35 * (((xx - w / 2) / (w * 0.7)) ** 2 + ((yy - h / 2) / (h * 0.7)) ** 2)
    return np.clip(arr * vig[..., None], 0, 1)


def _paste_rot(arr, piece, alpha, cx, cy, ang, s, shadow=0.45):
    """Colle piece (RGB flottants, alpha 0 à 1) tournée de ang degrés, centrée en (cx, cy) d'origine, avec
    une ombre portée douce (la feuille décolle un peu du support)."""
    H, W = arr.shape[:2]
    pim = Image.fromarray((np.clip(piece, 0, 1) * 255).astype(np.uint8), 'RGB').convert('RGBA')
    pim.putalpha(Image.fromarray((np.clip(alpha, 0, 1) * 255).astype(np.uint8), 'L'))
    pim = pim.rotate(ang, resample=Image.BICUBIC, expand=True)
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    layer.paste(pim, (int(cx * s - pim.width / 2), int(cy * s - pim.height / 2)))
    la = np.asarray(layer, np.float32) / 255.0
    a = la[..., 3]
    sh = np.roll(np.roll(_blur(a, 2.2 * s), int(1.6 * s), 0), int(1.2 * s), 1)
    arr = arr * (1 - shadow * sh)[..., None]
    return arr * (1 - a[..., None]) + la[..., :3] * a[..., None]


def corkboard():
    """Le tableau en liège de Manon : trois polaroïds de 2016 (un concert, deux copines au soleil couchant,
    une photo de nuit ratée), trois mots punaisés ; cadre en bois. Liège : ambientCG Cork003 (CC0).
    0.3.4 : 1280 × 960 (×2,5)."""
    s, W, H = hd('corkboard', 512, 384)
    rng, rs = _rngs(3500)
    cork = Image.open(os.path.join(TEX, 'Cork003/Cork003_albedo.jpg')).convert('RGB')
    cork = cork.resize((int(cork.width * 0.62 * s / 2.5), int(cork.height * 0.62 * s / 2.5)), Image.LANCZOS)
    c = np.asarray(cork, np.float32) / 255.0
    c = np.tile(c, (H // c.shape[0] + 1, W // c.shape[1] + 1, 1))[:H, :W]
    c = c / c.reshape(-1, 3).mean(0) * np.array([0.6, 0.42, 0.25])
    arr = c * (0.88 + 0.2 * _fbm(W, H, 2.2, 3501, s))[..., None]
    yy, xx = _grid(W, H, s)
    # trous d'anciennes punaises
    holes = np.zeros_like(yy)
    for _ in range(40):
        hx, hy = rng.uniform(20, 492), rng.uniform(20, 364)
        holes = np.maximum(holes, np.exp(-((xx - hx) ** 2 + (yy - hy) ** 2) / 0.9))
    arr *= (1 - 0.6 * holes)[..., None]
    # polaroïds
    for i, (x, y, rot, kind) in enumerate([(40, 40, -6, 'concert'), (190, 30, 4, 'copines'), (340, 52, -3, 'nuit')]):
        pw, ph = 120, 140
        piece = _paper(int(pw * s), int(ph * s), s, (0.93, 0.92, 0.88), 3510 + i, grain=0.5)
        photo = _polaroid_photo(kind, 100, 95, s, rng, rs)
        y0, x0 = int(10 * s), int(10 * s)
        piece[y0:y0 + photo.shape[0], x0:x0 + photo.shape[1]] = photo
        piece = _edges(piece, s, 4, 0.1, 0.15, 3515 + i)
        alpha = np.ones(piece.shape[:2], np.float32)
        cx, cy = x + pw / 2 + 6, y + ph / 2 + 6
        arr = _paste_rot(arr, piece, alpha, cx, cy, rot, s)
        px, py = cx + (60 - pw / 2) * np.cos(np.radians(-rot)) - (12 - ph / 2) * np.sin(np.radians(-rot)), \
            cy + (60 - pw / 2) * np.sin(np.radians(-rot)) + (12 - ph / 2) * np.cos(np.radians(-rot))
        arr = _pushpin(arr, s, px, py, rng)
    # les mots
    notes = [(40, 220, (0.93, 0.86, 0.43), ['rendre la K7', 'à Karim'], -2.5),
             (210, 230, (0.96, 0.94, 0.89), ['14h dentiste', '(mardi)'], 1.5),
             (360, 200, (0.78, 0.88, 0.94), ['elle me', 'regarde', 'la nuit'], 3.0)]
    hand = font('ReenieBeanie.ttf', 27 * s)
    for j, (x, y, col, lines, rot) in enumerate(notes):
        nw, nh = 130, 110
        Wn, Hn = int(nw * s), int(nh * s)
        piece = _paper(Wn, Hn, s, col, 3520 + j, grain=0.7)
        ink = Image.new('L', (Wn, Hn), 0)
        for i, t in enumerate(lines):
            _text_on(ink, (10 * s, (18 + i * 32) * s), t, hand, anchor='la', angle=rng.uniform(-2, 2), shear=-0.05)
        m = _thin(_wobble(np.asarray(ink, np.float32) / 255.0, s, 0.8, 20, 3525 + j), s, 0.6)
        piece = _ink(piece, m, (0.12, 0.12, 0.33), 'bille', rs, s)
        piece = _edges(piece, s, 3, 0.12, 0.2, 3528 + j)
        if j == 0:                                                       # le post-it : la bande de colle
            gy = np.arange(Hn)[:, None] / s
            piece *= (1 - 0.05 * (gy < 18))[..., None]
        cx, cy = x + nw / 2, y + nh / 2
        arr = _paste_rot(arr, piece, np.ones((Hn, Wn), np.float32), cx, cy, rot, s, 0.35)
        arr = _pushpin(arr, s, cx + (65 - nw / 2) * np.cos(np.radians(-rot)) - (8 - nh / 2) * np.sin(np.radians(-rot)),
                       cy + (65 - nw / 2) * np.sin(np.radians(-rot)) + (8 - nh / 2) * np.cos(np.radians(-rot)), rng,
                       [(0.75, 0.1, 0.1), (0.1, 0.3, 0.75), (0.9, 0.75, 0.15)][j])
    # le cadre : baguette de bois vernie, fil du bois le long de chaque côté, coupes d'onglet
    e_l, e_r, e_t, e_b = xx, 511 - xx, yy, 383 - yy
    e = np.minimum(np.minimum(e_l, e_r), np.minimum(e_t, e_b))
    vertical = np.minimum(e_l, e_r) < np.minimum(e_t, e_b)
    grain_h = _fbm(W, H, 1.2, 3530, s)
    gu = np.where(vertical, xx, yy)
    gv = np.where(vertical, yy, xx)
    fib = 0.5 + 0.5 * np.sin(gu * 2.6 + 6 * _fbm(W, H, 2.0, 3531, s) + 0.02 * gv)
    wood = np.array([0.3, 0.19, 0.11]) * (0.75 + 0.2 * fib + 0.15 * grain_h)[..., None]
    bevel = 1 + 0.35 * np.clip(1 - np.abs(e - 2) / 2, 0, 1) - 0.4 * np.clip(1 - np.abs(e - 13) / 1.5, 0, 1)
    frame = (e < 14)[..., None]
    arr = np.where(frame, wood * bevel[..., None], arr)
    inner = np.clip(1 - (e - 14) / 6, 0, 1) * (e >= 14)
    arr *= (1 - 0.45 * inner)[..., None]                                  # ombre du cadre sur le liège
    _save_png(_grime_hd(arr, .35, rng, s, stains=0), 'corkboard.png')


def clock_face():
    """Le cadran de l'horloge arrêtée à 3 h 12 (et du réveil de la chambre d'amis) : carton imprimé crème,
    minuterie, chiffres arabes, aiguilles noires effilées et trotteuse rouge ; leurs ombres sur le cadran ;
    jauni au bord, une auréole d'humidité. RGBA, hors du cadran alpha 0. 0.3.4 : 1024 × 1024 (×4)."""
    s, n0 = SCALE, 256
    N = n0 * s
    rng, rs = _rngs(3600)
    yy, xx = _grid(N, N, s)
    c = n0 / 2
    r = np.hypot(xx - c + 0.5, yy - c + 0.5)
    th = np.arctan2(yy - c, xx - c)
    dial = _paper(N, N, s, (0.9, 0.87, 0.8), 3601, grain=0.5)
    dial *= (1 - 0.1 * np.clip((r - 70) / 50, 0, 1) ** 2)[..., None] * np.array([1, 0.99, 0.95])
    ink = Image.new('L', (N, N), 0)
    d = ImageDraw.Draw(ink)
    k = s
    for m in range(60):                                                  # la minuterie
        a = np.pi / 2 - m * np.pi / 30
        big = m % 5 == 0
        r0, r1 = (101, 112) if big else (106, 112)
        wd = 2.6 if big else 0.9
        d.line([((c + r0 * np.cos(a)) * k, (c - r0 * np.sin(a)) * k), ((c + r1 * np.cos(a)) * k, (c - r1 * np.sin(a)) * k)],
               fill=255, width=max(1, int(wd * k)))
    for rr in (113.5, 99.5):
        d.ellipse([(c - rr) * k, (c - rr) * k, (c + rr) * k, (c + rr) * k], outline=255, width=max(1, int(0.6 * k)))
    f = sfont('Inter-SemiBold.otf', 25 * s)
    for hr in range(1, 13):
        ang = np.pi / 2 - hr * np.pi / 6
        _text_on(ink, ((c + 85 * np.cos(ang)) * k, (c - 85 * np.sin(ang)) * k), str(hr), f)
    dial = _ink(dial, np.asarray(ink, np.float32) / 255.0, (0.09, 0.085, 0.08), 'imprime', rs, s)
    # l'auréole d'humidité, en bas à gauche
    stain = np.clip(1 - np.hypot(xx - 70, yy - 190) / 46 - 0.25 * (_fbm(N, N, 1.8, 3602, s) - 0.5), 0, 1)
    tide = np.exp(-((stain - 0.02) / 0.03) ** 2) * (stain < 0.2)
    dial *= (1 - 0.06 * np.clip(stain * 4, 0, 1) - 0.12 * tide)[..., None]

    def hands(dd, kk, off=(0.0, 0.0)):
        ox, oy = off
        def blade(angle, length, width, tail):
            ca, sa = np.cos(angle), -np.sin(angle)
            px, py = -sa, ca
            pts = [(-tail, -width * 0.6), (length * 0.75, -width * 0.5), (length, 0), (length * 0.75, width * 0.5), (-tail, width * 0.6)]
            dd.polygon([((c + ox + u * ca + v * px) * kk, (c + oy + u * sa + v * py) * kk) for u, v in pts], fill=255)
        blade(np.pi / 2 - (3 + 12 / 60) * np.pi / 6, 60, 8, 12)
        blade(np.pi / 2 - 12 * np.pi / 30, 92, 5.5, 16)
        dd.ellipse([(c + ox - 7) * kk, (c + oy - 7) * kk, (c + ox + 7) * kk, (c + oy + 7) * kk], fill=255)
    shadow = _blur(_mask_hd(N, N, s, lambda dd, kk: hands(dd, kk, (2.5, 3.5))), 1.8 * s)
    dial *= (1 - 0.4 * shadow)[..., None]
    hm = _mask_hd(N, N, s, hands)
    hand_col = np.array([0.05, 0.045, 0.045]) + 0.08 * np.clip(-np.sin(th + 0.8), 0, 1)[..., None]
    dial = dial * (1 - hm[..., None]) + hm[..., None] * hand_col
    sec = 47
    a2 = np.pi / 2 - sec * np.pi / 30
    sm = _mask_hd(N, N, s, lambda dd, kk: (_capsule(dd, kk, (c - 22 * np.cos(a2), c + 22 * np.sin(a2)), (c + 100 * np.cos(a2), c - 100 * np.sin(a2)), 0.8),
                                           dd.ellipse([(c - 4) * kk, (c - 4) * kk, (c + 4) * kk, (c + 4) * kk], fill=255),
                                           dd.ellipse([(c - 22 * np.cos(a2) - 3.5) * kk, (c + 22 * np.sin(a2) - 3.5) * kk,
                                                       (c - 22 * np.cos(a2) + 3.5) * kk, (c + 22 * np.sin(a2) + 3.5) * kk], fill=255)))
    dial *= (1 - 0.3 * np.roll(np.roll(_blur(sm, 1.2 * s), int(2 * s), 0), int(1.5 * s), 1))[..., None]
    dial = dial * (1 - sm[..., None]) + sm[..., None] * np.array([0.62, 0.08, 0.06])
    cap = np.clip((1.6 - np.hypot(xx - c, yy - c)) * s, 0, 1)
    dial = dial * (1 - cap[..., None]) + cap[..., None] * np.array([0.7, 0.68, 0.6])
    # la lunette noire (bord du boîtier)
    bez = np.clip((r - 117) * s * 0.5, 0, 1)
    shine = 0.06 + 0.12 * np.clip(np.cos(th + 2.3), 0, 1) ** 4 + 0.05 * np.clip(1 - np.abs(r - 121) / 2, 0, 1)
    arr = dial * (1 - bez[..., None]) + bez[..., None] * (np.array([1, 1, 1]) * shine[..., None])
    arr *= (1 - 0.35 * np.clip(1 - (r - 112) / 5, 0, 1) * (r > 112) * (r < 117))[..., None]   # ombre de la lunette
    alpha = np.clip((n0 / 2 - 4 - r) * s + 0.5, 0, 1)
    arr = _grime_hd(arr, .25, rng, s, stains=0)
    arr = arr * alpha[..., None]                                         # hors du cadran : noir (comme avant)
    _save_png(arr, 'clock_face.png', alpha)


def calendar_octobre():
    """Calendrier d'octobre 2016, dans l'ancienne chambre de Manon : la photo du mois (un parc en automne,
    Poly Haven autumn_park, CC0), une vraie typographie, tous les jours barrés en rouge jusqu'au 30, de plus
    en plus rageusement ; le 31 entouré si fort que le stylo a troué le papier. 0.3.4 : 1024 × 1434."""
    s, W, H = hd('calendar', 300, 420)
    rng = random.Random(301)
    rs = np.random.RandomState(301)
    yy, xx = _grid(W, H, s)
    arr = _paper(W, H, s, (0.93, 0.915, 0.87), 3011, grain=0.5, mottle=0.04)
    top, bot = 14, 168
    pw, ph = int(round(279 * s)), int(round((bot - top) * s))
    photo = None
    try:
        photo = _photos_module().month_photo(pw, ph)
    except Exception as e:                                              # sources absentes : le dessin de la 0.3.3
        print('calendar : photo du mois indisponible (%s) : make_photos.py fetch' % e)
    if photo is None:
        photo = np.ones((ph, pw, 3), np.float32) * np.array([0.12, 0.16, 0.14])
    x0p, y0p = int(round(10 * s)), int(round(top * s))
    arr[y0p:y0p + ph, x0p:x0p + pw] = photo
    hole_m = np.exp(-(((xx - 150) ** 2 + (yy - 7) ** 2) / 10))
    arr *= (1 - 0.7 * np.clip(hole_m * 2, 0, 1))[..., None]               # trou du clou
    ink = Image.new('L', (W, H), 0)
    k = s
    _text_on(ink, (150 * k, 188 * k), 'OCTOBRE 2016', sfont('Inter-Bold.otf', 25 * k))
    small = sfont('Inter-SemiBold.otf', 10.5 * k)
    f = sfont('Inter-Medium.otf', 16 * k)
    x0, dx, y0, dy = 32, 40, 238, 29
    red = Image.new('L', (W, H), 0)
    for col, lettre in enumerate('LMMJVSD'):
        _text_on(red if col == 6 else ink, ((x0 + col * dx) * k, 213 * k), lettre, small)
    grid = _mask_hd(W, H, s, lambda d, kk: [d.line([(14 * kk, (222 + j * dy) * kk), (286 * kk, (222 + j * dy) * kk)], fill=255 if j == 0 else 110,
                                                   width=max(1, int((0.7 if j == 0 else 0.4) * kk))) for j in range(7)]
                    + [d.line([((x0 - dx / 2 + c_ * dx) * kk, 224 * kk), ((x0 - dx / 2 + c_ * dx) * kk, (222 + 6 * dy) * kk)], fill=110,
                              width=max(1, int(0.4 * kk))) for c_ in range(1, 7)])
    arr = _ink(arr, grid, (0.55, 0.52, 0.48), 'imprime', rs, s)
    pos = {}
    for day in range(1, 32):
        i = day - 1 + 5                              # le 1er octobre 2016 est un samedi
        row, col = divmod(i, 7)
        x, y = x0 + col * dx, y0 + row * dy
        pos[day] = (x, y)
        _text_on(red if col == 6 else ink, (x * k, y * k), str(day), f)
    arr = _ink(arr, np.asarray(ink, np.float32) / 255.0, (0.2, 0.17, 0.16), 'imprime', rs, s)
    arr = _ink(arr, np.asarray(red, np.float32) / 255.0, (0.62, 0.22, 0.18), 'imprime', rs, s)
    # l'encre rouge, au feutre : les croix, de plus en plus fortes
    pen = Image.new('L', (W, H), 0)
    dp = ImageDraw.Draw(pen)
    for day in range(1, 31):
        x, y = pos[day]
        kk = day / 30.0
        sz = 10 + 5 * kk
        wd = (1.6 if day < 20 else 2.4) * k
        for a, b in (((-sz, -sz * .8), (sz, sz * .8)), ((sz, -sz * .8), (-sz, sz * .8))):
            mid = (x + (a[0] + b[0]) / 2 + rng.uniform(-2, 2), y + (a[1] + b[1]) / 2 + rng.uniform(-2, 2))
            pts = _hand_path([(x + a[0], y + a[1]), mid, (x + b[0], y + b[1])], rng, 0.25, 1.0)
            dp.line([(px * k, py * k) for px, py in pts], fill=rng.randint(200, 245), width=max(1, int(wd)), joint='curve')
        if day >= 27:                                                    # repasser plusieurs fois
            pts = _hand_path([(x - sz, y - sz * .7), (x + sz, y + sz * .9)], rng, 0.3, 1.0)
            dp.line([(px * k, py * k) for px, py in pts], fill=230, width=max(1, int(1.8 * k)), joint='curve')
    cx, cy = pos[31]
    rx, ry = 20, 16
    for j in range(14):
        ph_ = rng.uniform(0, 2 * np.pi)
        a = np.linspace(ph_, ph_ + 2 * np.pi * rng.uniform(1.0, 1.25), 90)
        jr = 1 + 0.08 * np.sin(a * 3 + rng.uniform(0, 6))
        pts = [(cx + rng.uniform(-0.8, 0.8) + rx * jr[q] * np.cos(a[q]), cy + rng.uniform(-0.8, 0.8) + ry * jr[q] * np.sin(a[q]))
               for q in range(len(a))]
        dp.line([(px * k, py * k) for px, py in pts], fill=rng.randint(190, 240), width=max(1, int(rng.choice([1.6, 1.8, 2.4]) * k)), joint='curve')
    pm = np.asarray(pen, np.float32) / 255.0
    arr = _ink(arr, pm, (0.66, 0.06, 0.08), 'feutre', rs, s, 0.95)
    # le trou : une déchirure le long du cercle, en bas à droite, là où la pointe a traversé ; on voit le
    # papier peint du mur derrière, dans l'ombre du bord de la feuille
    ph1, ph2 = rng.uniform(0, 6), rng.uniform(0, 6)
    sm_ = lambda a, amp: amp * (0.6 * np.sin(a * 9 + ph1) + 0.4 * np.sin(a * 23 + ph2))

    def tear(d, kk):
        a = np.linspace(-0.6, 2.0, 140)
        wid = 1.0 + 4.2 * np.sin(np.pi * (a - a[0]) / (a[-1] - a[0])) ** 0.8
        outer = [(cx + (rx + wid[q] * .5 + sm_(a[q], 0.6)) * np.cos(a[q]), cy + (ry + wid[q] * .5 + sm_(a[q], 0.6)) * np.sin(a[q]))
                 for q in range(len(a))]
        inner = [(cx + (rx - wid[q] * .5 + sm_(a[q] + 1, 0.5)) * np.cos(a[q]), cy + (ry - wid[q] * .5 + sm_(a[q] + 1, 0.5)) * np.sin(a[q]))
                 for q in range(len(a))][::-1]
        d.polygon([(x * kk, y * kk) for x, y in outer + inner], fill=255)
        bx, by = cx + (rx + 1) * np.cos(0.9), cy + (ry + 1) * np.sin(0.9)          # la pointe a percé ici
        tt = np.linspace(0, 2 * np.pi, 60, endpoint=False)
        rr_ = 5.5 + 0.9 * np.sin(tt * 5 + ph1) + 0.5 * np.sin(tt * 11 + ph2)
        d.polygon([((bx + rr_[q] * np.cos(tt[q])) * kk, (by + rr_[q] * 0.85 * np.sin(tt[q])) * kk) for q in range(len(tt))], fill=255)
        px_, py_ = cx + rx * np.cos(-1.6), cy + ry * np.sin(-1.6)
        d.ellipse([(px_ - 1.6) * kk, (py_ - 1.4) * kk, (px_ + 1.6) * kk, (py_ + 1.4) * kk], fill=255)
    m = _mask_hd(W, H, s, tear, ss=3)
    rough = _fbm(W, H, 0.6, 3014, s)
    m = np.clip((m - 0.5) * 1.6 + 0.5 + (rough - 0.5) * 0.5 * (m > 0.02) * (m < 0.98), 0, 1)
    ring = np.clip(_blur(m, 0.9 * s) * 2.2 - m * 2.2, 0, 1)
    fib = ring * (0.55 + 0.45 * np.clip((_fbm(W, H, 0.3, 3015, s) - 0.3) * 3, 0, 1))      # fibres claires, ébouriffées
    halo = _blur(m, 3 * s)
    crush = 0.45 * np.clip(halo * 2, 0, 1) * (1 - m)
    arr = arr * (1 - crush[..., None]) + arr * np.array([0.72, 0.25, 0.22]) * crush[..., None]
    arr = arr * (1 - fib[..., None] * 0.8) + fib[..., None] * np.array([0.96, 0.94, 0.89]) * 0.8
    wall = np.array([0.36, 0.28, 0.2]) * (0.75 + 0.35 * _fbm(W, H, 1.0, 3016, s))[..., None]
    shade = np.clip(np.roll(np.roll(_blur(1 - m, 1.8 * s), int(1.5 * s), 0), int(1.0 * s), 1), 0, 1)   # l'ombre du bord
    void = wall * (1 - 0.75 * shade)[..., None]
    arr = arr * (1 - m[..., None]) + void * m[..., None]
    fx, fy = cx + (rx + 2) * np.cos(0.35), cy + (ry + 2) * np.sin(0.35)
    flap = _mask_hd(W, H, s, lambda d, kk: d.polygon([((fx - 2) * kk, (fy - 4) * kk), ((fx + 3) * kk, (fy - 2) * kk), ((fx - 3) * kk, (fy + 5) * kk)], fill=255))
    arr = arr * (1 - flap[..., None]) + flap[..., None] * np.array([0.78, 0.72, 0.64])
    # papier jauni, gondolé ; la photo du mois a un peu de brillant qui accroche la lumière
    stain = _fbm(W, H, 2.3, 3012, s)
    arr *= (0.9 + 0.13 * stain)[..., None] * np.array([1.0, 0.98, 0.93])
    arr = _fold(arr, s, 300, 'y', 0.6, 6)
    arr = _edges(arr, s, 6, 0.12, 0.25, 3013)
    _save_png(_grime_hd(arr, .55, rng, s), 'calendar.png')


def tin_lid():
    """Couvercle de la boîte à biscuits bleue d'Henriette (boîte danoise en fer, vue de dessus) :
    bleu roi, frise blanche, filets dorés, médaillon crème avec un village danois dessiné en bleu
    (maisons à pignons à redans, église, moulin). Rayé, frotté sur le bord, quelques points de rouille.
    RGBA : hors du disque, alpha 0 (la couleur du bord reste dessous). 0.3.4 : 1024 × 1024 (×2)."""
    s, N, _ = hd('tin_lid', 512, 512)
    n = 512
    rng, _rs = _rngs(315)
    c = n / 2
    yy, xx = _grid(N, N, s)
    r = np.hypot(xx - c + 0.5, yy - c + 0.5) / (c - 3)
    th = np.arctan2(yy - c, xx - c)
    blue = np.array([0.075, 0.17, 0.47])
    gold = np.array([0.74, 0.6, 0.3])
    cream = np.array([0.92, 0.9, 0.82])
    arr = np.ones((N, N, 3), np.float32) * blue
    arr *= (0.92 + 0.12 * _fbm(N, N, 2.2, 3151, s))[..., None]           # laque inégale
    arr *= (0.97 + 0.05 * _fbm(N, N, 0.8, 3156, s))[..., None]           # peau d'orange de la laque
    rim = np.clip((r - 0.935) / 0.065, 0, 1)
    roll = 0.55 + 0.6 * np.clip(np.sin(np.pi * rim), 0, 1) ** 0.7 - 0.25 * rim
    arr = np.where((r > 0.935)[..., None], blue * roll[..., None] * 0.95, arr)
    for r0, wd in ((0.925, 0.006), (0.905, 0.0035), (0.79, 0.0035), (0.655, 0.008), (0.625, 0.003)):
        arr = _lay(arr, np.clip(1 - np.abs(r - r0) / wd, 0, 1), gold * (0.85 + 0.3 * np.clip(np.cos(th - 2.2), 0, 1))[..., None])
    R = c - 3

    def frieze(d, k):
        for i in range(32):
            a = i * 2 * np.pi / 32
            for sgn in (-1, 1):                                          # deux volutes en C, dos à dos
                pts = []
                for t in np.linspace(0, 1.6 * np.pi, 40):
                    rr = 0.848 + 0.03 * np.cos(t) * (1 - t / 6)
                    aa = a + sgn * (0.035 + 0.032 * np.sin(t) * (1 - t / 7))
                    pts.append(((c + R * rr * np.cos(aa)) * k, (c + R * rr * np.sin(aa)) * k))
                d.line(pts, fill=255, width=max(1, int(2.2 * k)), joint='curve')
            ad = a + np.pi / 32
            for rr, rad in ((0.848, 0.011), (0.88, 0.006), (0.816, 0.006)):
                px, py = c + R * rr * np.cos(ad), c + R * rr * np.sin(ad)
                d.ellipse([(px - rad * R) * k, (py - rad * R) * k, (px + rad * R) * k, (py + rad * R) * k], fill=255)
        for i in range(72):
            a = i * 2 * np.pi / 72
            px, py = c + R * 0.64 * np.cos(a), c + R * 0.64 * np.sin(a)
            d.ellipse([(px - 0.006 * R) * k, (py - 0.006 * R) * k, (px + 0.006 * R) * k, (py + 0.006 * R) * k], fill=128)
    fm = _mask_hd(N, N, s, frieze)
    arr = _lay(arr, np.clip(fm * 2, 0, 1) * (fm > 0.3), cream * 0.97)
    arr = _lay(arr, np.clip((fm - 0.2) * 4, 0, 1) * (np.abs(r - 0.64) < 0.01), gold)
    med = r < 0.62
    arr = np.where(med[..., None], cream * (0.95 + 0.06 * _fbm(N, N, 1.8, 3152, s))[..., None], arr)

    def scene(d, k):
        S = lambda x, y: ((c + x * R) * k, (c + y * R) * k)
        lw = max(1, int(1.6 * k))
        d.line([S(-0.6, 0.2), S(-0.3, 0.17), S(0.0, 0.19), S(0.3, 0.16), S(0.6, 0.18)], fill=255, width=lw)
        d.line([S(-0.55, 0.32), S(-0.1, 0.3), S(0.4, 0.33)], fill=200, width=max(1, int(1.2 * k)))

        def house(x0, w_, h_, steps, y0=0.18):
            d.line([S(x0, y0), S(x0, y0 - h_), S(x0 + w_, y0 - h_), S(x0 + w_, y0)], fill=255, width=lw)
            st = []
            for kk in range(steps + 1):
                fx = kk / (steps + 1) / 2
                st += [S(x0 + w_ * fx, y0 - h_ - 0.035 * kk), S(x0 + w_ * (fx + 0.5 / (steps + 1)), y0 - h_ - 0.035 * kk)]
            top = y0 - h_ - 0.035 * steps
            st += [S(x0 + w_ * 0.5, top - 0.02)]
            for kk in range(steps, -1, -1):
                fx = 1 - kk / (steps + 1) / 2
                st += [S(x0 + w_ * (fx - 0.5 / (steps + 1)), y0 - h_ - 0.035 * kk), S(x0 + w_ * fx, y0 - h_ - 0.035 * kk)]
            d.line(st, fill=255, width=lw)
            for wx in np.linspace(x0 + w_ * 0.22, x0 + w_ * 0.78, 2 if w_ < 0.16 else 3):
                d.rectangle([S(wx - 0.018, y0 - h_ * 0.75), S(wx + 0.018, y0 - h_ * 0.4)], outline=255, width=max(1, int(1.1 * k)))
                d.line([S(wx, y0 - h_ * 0.75), S(wx, y0 - h_ * 0.4)], fill=255, width=max(1, int(0.9 * k)))
            d.rectangle([S(x0 + w_ * 0.45, y0 - h_ * 0.35), S(x0 + w_ * 0.58, y0)], outline=255, width=max(1, int(1.1 * k)))
            for kk in range(1, 4):
                d.line([S(x0, y0 - h_ * kk / 4 + 0.01), S(x0 + w_, y0 - h_ * kk / 4 + 0.01)], fill=150, width=max(1, int(0.8 * k)))

        house(-0.47, 0.17, 0.13, 3)
        house(-0.27, 0.13, 0.17, 2)
        house(0.06, 0.15, 0.12, 3)
        d.line([S(-0.11, 0.18), S(-0.11, -0.12), S(0.02, -0.12), S(0.02, 0.18)], fill=255, width=lw)
        d.line([S(-0.125, -0.12), S(-0.045, -0.36), S(0.035, -0.12)], fill=255, width=lw)
        d.line([S(-0.045, -0.36), S(-0.045, -0.44)], fill=255, width=lw)
        d.line([S(-0.07, -0.41), S(-0.02, -0.41)], fill=255, width=lw)
        d.ellipse([S(-0.07, -0.06), S(-0.02, -0.01)], outline=255, width=max(1, int(1.2 * k)))
        d.arc([S(-0.08, 0.06), S(-0.01, 0.2)], 180, 360, fill=255, width=max(1, int(1.2 * k)))
        d.line([S(0.33, 0.17), S(0.37, -0.12), S(0.45, -0.12), S(0.49, 0.17)], fill=255, width=lw)
        d.line([S(0.36, -0.12), S(0.41, -0.19), S(0.46, -0.12)], fill=255, width=lw)
        hub = (0.41, -0.15)
        for a in (0.5, 0.5 + np.pi / 2, 0.5 + np.pi, 0.5 + 3 * np.pi / 2):
            e = (hub[0] + 0.16 * np.cos(a), hub[1] + 0.16 * np.sin(a))
            d.line([S(*hub), S(*e)], fill=255, width=lw)
            p1 = (hub[0] + 0.05 * np.cos(a) + 0.03 * np.cos(a + np.pi / 2), hub[1] + 0.05 * np.sin(a) + 0.03 * np.sin(a + np.pi / 2))
            p2 = (e[0] + 0.03 * np.cos(a + np.pi / 2), e[1] + 0.03 * np.sin(a + np.pi / 2))
            d.line([S(*p1), S(*p2), S(*e)], fill=200, width=max(1, int(1.1 * k)))
        for kk in range(4):
            d.line([S(0.25 - 0.05 + 0.012 * kk, 0.17 - 0.07 * kk), S(0.25, 0.08 - 0.07 * kk), S(0.25 + 0.05 - 0.012 * kk, 0.17 - 0.07 * kk)],
                   fill=255, width=max(1, int(1.3 * k)))
        for _ in range(46):
            a_ = rng.uniform(0, 2 * np.pi)
            rr = 0.58 * np.sqrt(rng.random())
            x, y = rr * np.cos(a_), rr * np.sin(a_)
            if y < 0.12 and not (-0.15 < x < 0.06 and y > -0.45):
                d.ellipse([S(x - 0.007, y - 0.007), S(x + 0.007, y + 0.007)], fill=230)
        d.line([S(-0.32, 0.27), S(-0.12, 0.27), S(-0.1, 0.24)], fill=255, width=lw)
        d.line([S(-0.3, 0.27), S(-0.3, 0.23), S(-0.16, 0.23), S(-0.15, 0.2)], fill=255, width=max(1, int(1.2 * k)))
        d.line([S(-0.1, 0.24), S(0.0, 0.25)], fill=180, width=max(1, int(0.9 * k)))
        d.ellipse([S(0.0, 0.2), S(0.09, 0.26)], outline=255, width=max(1, int(1.2 * k)))
        d.line([S(0.08, 0.21), S(0.12, 0.16)], fill=255, width=lw)
        for lx in (0.015, 0.035, 0.06, 0.08):
            d.line([S(lx, 0.255), S(lx, 0.29)], fill=255, width=max(1, int(1.1 * k)))
    sm = _mask_hd(N, N, s, scene) * med
    sm *= 0.85 + 0.15 * _fbm(N, N, 0.5, 3157, s)                         # l'impression sur le fer : encre inégale
    arr = _lay(arr, sm, blue * 1.1, 1.05)

    def scratches(d, k):
        for _ in range(110):
            x, y = rng.uniform(40, n - 40), rng.uniform(40, n - 40)
            a_ = rng.uniform(0, np.pi)
            ln = rng.uniform(8, 90)
            bend = rng.uniform(-0.15, 0.15)
            pts = [((x + ln * t * np.cos(a_ + bend * t)) * k, (y + ln * t * np.sin(a_ + bend * t)) * k) for t in np.linspace(0, 1, 10)]
            d.line(pts, fill=rng.randint(90, 230), width=max(1, int(rng.choice([0.35, 0.5, 0.8]) * k)))
        for _ in range(14):
            rr = rng.uniform(0.2, 0.85) * c
            a0 = rng.uniform(0, 360)
            d.arc([(c - rr) * k, (c - rr) * k, (c + rr) * k, (c + rr) * k], a0, a0 + rng.uniform(15, 60), fill=rng.randint(60, 160),
                  width=max(1, int(0.4 * k)))
    sc = _mask_hd(N, N, s, scratches) * (r < 0.99)
    metal = np.array([0.7, 0.7, 0.68])
    arr = _lay(arr, sc * (r < 0.93), metal, 1.4)
    rub = np.clip((_fbm(N, N, 1.4, 3153, s) - 0.55) * 5, 0, 1) * np.clip((r - 0.92) / 0.05, 0, 1)
    arr = _lay(arr, rub, metal * 0.9)
    rust_n = _fbm(N, N, 1.0, 3154, s)
    rust = np.clip((rust_n - 0.66) * 8, 0, 1) * np.clip((r - 0.84) / 0.08, 0, 1) * (np.sin(th * 3 + 1) > 0.1)
    arr = _lay(arr, rust * (0.7 + 0.3 * _fbm(N, N, 0.6, 3158, s)), np.array([0.42, 0.22, 0.1]), 0.9)
    dent = _fbm(N, N, 3.2, 3155, s)
    arr *= (0.9 + 0.16 * dent)[..., None]
    alpha = np.clip((1.0 - r) * (c - 3) * s + 0.5, 0, 1)
    out = np.clip((r - 1.0) * (c - 3) * s, 0, 1)[..., None]              # hors du disque : le bleu sombre du bord roulé
    arr = arr * (1 - out) + out * blue * 0.3
    _save_png(arr, 'tin_lid.png', alpha)


def carton_2euros():
    """L'écriteau du vide-grenier d'Henriette : un rabat de carton découpé, « TOUT À 2 € » au gros
    feutre noir, souligné ; un reste d'impression du carton (HAUT, flèches) et du ruban adhésif.
    0.3.4 : 1024 × 640 (×2)."""
    s, W, H = hd('carton_2euros', 512, 320)
    w, h = 512, 320
    rng, rs = _rngs(317)
    yy, xx = _grid(W, H, s)
    mott = _fbm(W, H, 2.2, 3171, s)
    fib = _fbm(W, H, 0.4, 3172, s)
    flute = 0.5 + 0.5 * np.cos(xx * 2 * np.pi / 8.5)
    kraft = np.array([0.6, 0.45, 0.29])
    det = _tex_detail('Paper002/Paper002_albedo.jpg', W, H, int(160 * s), 3174)
    arr = kraft * ((0.86 + 0.18 * mott + 0.06 * fib + 0.03 * flute) * (1 + (det - 1) * 1.4))[..., None]
    arr *= (1 - 0.12 * np.exp(-((yy - 34) / 1.2) ** 2))[..., None]
    edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
    arr *= (0.78 + 0.22 * np.clip(edge / 5, 0, 1))[..., None]

    def old(d, k):
        tmp = Image.new('L', d.im.size, 0)
        _text_on(tmp, ((w - 18) * k, 6 * k), 'HAUT', font('IBMPlexMono-Bold.ttf', 26 * k), anchor='ra')
        d.bitmap((0, 0), tmp, fill=255)
        for i in range(2):
            d.polygon([((w - 110 - i * 26) * k, 30 * k), ((w - 100 - i * 26) * k, 12 * k), ((w - 90 - i * 26) * k, 30 * k)], fill=255)
            d.line([((w - 100 - i * 26) * k, 30 * k), ((w - 100 - i * 26) * k, 40 * k)], fill=255, width=int(4 * k))
    om = _mask_hd(W, H, s, old)
    arr = _lay(arr, om * (0.35 + 0.25 * fib) * (0.8 + 0.2 * _fbm(W, H, 0.5, 3175, s)), np.array([0.45, 0.2, 0.15]))
    size = 170
    for size in range(170, 60, -4):
        if font('ReenieBeanie.ttf', size).getlength('TOUT À 2 €') + 9 < 430:
            break
    hand = font('ReenieBeanie.ttf', size * s)
    big = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(big)
    x = W / 2 - hand.getlength('TOUT À 2 €') / 2
    cap = hand.getbbox('T', anchor='lm')
    for i, word in enumerate(['TOUT', 'À', '2', '€']):
        yc = (158 + [0, 4, -2, 3][i]) * s
        if word == '2':                                                  # le 2 d'Henriette, bien rond
            ch = cap[3] - cap[1]
            x0, y0 = x + 0.05 * ch, yc + cap[1]
            arc = [(x0 + 0.3 * ch + 0.29 * ch * np.cos(a), y0 + 0.3 * ch + 0.3 * ch * np.sin(a)) for a in np.linspace(-2.7, 0.55, 30)]
            path = [(x0 + 0.02 * ch, y0 + 0.32 * ch)] + arc + [(x0 + 0.02 * ch, y0 + 0.98 * ch), (x0 + 0.68 * ch, y0 + 0.95 * ch)]
            d.line(path, fill=255, width=int(13 * s), joint='curve')
            for px, py in (path[0], path[-1]):
                rr = 6.5 * s
                d.ellipse([px - rr, py - rr, px + rr, py + rr], fill=255)
            x += 0.75 * ch + hand.getlength(' ')
            continue
        _text_on(big, (x, yc), word, hand, anchor='lm', stroke=int(4.5 * s))
        x += hand.getlength(word + ' ')
    pts = [(62 + t * 392, 218 + 5 * np.sin(t * 5.5) - 10 * t) for t in np.linspace(0, 1, 60)]
    d.line([(px * s, py * s) for px, py in pts], fill=255, width=int(6 * s), joint='curve')
    big = big.rotate(2.5, resample=Image.BICUBIC, center=(W / 2, H / 2))
    m = _wobble(np.asarray(big, np.float32) / 255.0, s, 0.8, 30, 3176)
    bleed = _blur(m, 1.4 * s)
    dry = 0.8 + 0.2 * np.clip(_fbm(W, H, 0.6, 3173, s) * 1.6, 0, 1)
    arr = _lay(arr, np.clip(bleed * 0.35, 0, 1), np.array([0.2, 0.15, 0.1]))
    arr = _lay(arr, m * dry, np.array([0.04, 0.035, 0.04]))
    tape = _mask_hd(W, H, s, lambda d, k: d.polygon([(0, 52 * k), (52 * k, 0), (92 * k, 0), (0, 92 * k)], fill=255))
    arr = _lay(arr, tape * 0.6, np.array([0.5, 0.31, 0.12]))
    arr += (tape * 0.06 * (0.5 + fib))[..., None]
    arr *= (1 + 0.12 * np.clip(_blur(tape, 0.5 * s) - _blur(tape, 1.5 * s), 0, 1))[..., None]
    clear = _mask_hd(W, H, s, lambda d, k: d.polygon([((w - 120) * k, h * k), ((w - 70) * k, (h - 70) * k),
                                                       ((w - 40) * k, (h - 40) * k), ((w - 90) * k, h * k)], fill=255))
    arr = arr * (1 - clear[..., None] * 0.08) + clear[..., None] * np.array([0.08, 0.07, 0.02])
    _save_png(_grime_hd(arr, 0.6, rng, s), 'carton_2euros.png')


def postit_chocolat():
    """Le post-it collé sur l'ordinateur portable d'Henriette : « mot de passe : CHOCOLAT », de son
    écriture penchée et tremblée, au stylo bille bleu, CHOCOLAT souligné deux fois. 0.3.4 : 1024 × 1024 (×4)."""
    s, N, _ = hd('postit_chocolat', 256, 256)
    n = 256
    rng, rs = _rngs(318)
    yy, xx = _grid(N, N, s)
    yellow = np.array([0.98, 0.88, 0.4])
    arr = _paper(N, N, s, yellow, 3183, grain=0.6, mottle=0.04)
    arr *= (0.95 + 0.06 * _fbm(N, N, 1.4, 3181, s))[..., None]
    arr = arr * (1 - 0.05 * np.clip((46 - yy) * 2, 0, 1))[..., None]
    arr = arr * (1 + 0.06 * np.clip((yy - 180) / 76, 0, 1) ** 2)[..., None]
    arr *= (0.93 + 0.07 * np.clip(np.minimum(np.minimum(xx, n - 1 - xx), np.minimum(yy, n - 1 - yy)) / 4, 0, 1))[..., None]
    ink = Image.new('L', (N, N), 0)
    for txt, (cx, cy), size, ang in (('mot de passe :', (128, 84), 46, 6), ('CHOCOLAT', (128, 152), 62, 4)):
        for i in range(2):
            _text_on(ink, ((cx + i * 0.6) * s, (cy + i * 0.4) * s), txt, font('ReenieBeanie.ttf', size * s),
                     angle=ang + rng.uniform(-0.6, 0.6), fill=230 - 60 * i, shear=-0.28)
    d = ImageDraw.Draw(ink)
    for j, yb in enumerate((188, 197)):
        pts = [(46 + t * 168, yb - 8 * t + 1.6 * np.sin(t * 31 + j) + rng.uniform(-0.4, 0.4)) for t in np.linspace(0, 1, 80)]
        d.line([(x * s, y * s) for x, y in pts], fill=225, width=int(1.6 * s), joint='curve')
    m = _thin(_wobble(np.asarray(ink, np.float32) / 255.0, s, 0.6, 18, 3184), s, 0.7)
    m *= 0.8 + 0.2 * _fbm(N, N, 1.2, 3182, s)
    arr = _ink(arr, m, (0.12, 0.17, 0.5), 'bille', rs, s)
    _save_png(_grime_hd(arr, 0.12, rng, s, stains=1), 'postit_chocolat.png')


def tableau_cles():
    """Le tableau à clés d'Albert : planche vernie, sept crochets de laiton sous sept étiquettes en relief
    (étiqueteuse à ruban : CAVE, ESCALIER, CUISINE, BIBLIO, CELLIER, BUREAU, LINGERIE). Tous les
    crochets sont vides : sous chacun, le bois resté clair dessine la clé qui n'est plus là.
    0.3.4 : 1024 × 768 (×2). Crochets (u, v) : rangée 1 en v = 0,22, u = 0,125 / 0,375 / 0,625 / 0,875 ;
    rangée 2 en v = 0,635, u = 0,25 / 0,5 / 0,75."""
    s, W, H = hd('tableau_cles', 512, 384)
    w, h = 512, 384
    rng, _rs = _rngs(319)
    yy, xx = _grid(W, H, s)
    grain = _fbm(W, H, 1.6, 3191, s)
    rings = np.sin((yy + 26 * _fbm(W, H, 2.4, 3192, s)) * 0.55 + xx * 0.012)
    pores = np.clip((_fbm(W, H, 0.5, 3194, s) - 0.7) * 4, 0, 1) * (0.5 + 0.5 * rings)
    wood = np.array([0.5, 0.32, 0.15])
    arr = wood * (0.8 + 0.18 * grain + 0.07 * rings - 0.08 * pores)[..., None]
    names = ['CAVE', 'ESCALIER', 'CUISINE', 'BIBLIO', 'CELLIER', 'BUREAU', 'LINGERIE']
    hooks = [(64, 84), (192, 84), (320, 84), (448, 84), (128, 244), (256, 244), (384, 244)]
    sws = [rng.uniform(-0.08, 0.08) for _ in hooks]
    teeth = [[rng.randint(1, 5) for _ in range(3)] for _ in hooks]

    def ghosts(d, k):
        for i, (hx, hy) in enumerate(hooks):
            sw = sws[i]
            X = lambda x, t, hx=hx, sw=sw: (hx + x + sw * t) * k
            Y = lambda t, hy=hy: (hy + t) * k
            d.ellipse([X(-11, 12), Y(2), X(11, 12), Y(24)], outline=255, width=int(3 * k))
            d.rounded_rectangle([X(-10, 34), Y(22), X(10, 34), Y(42)], radius=int(7 * k), fill=255)
            d.ellipse([X(-3, 30), Y(27), X(3, 30), Y(33)], fill=0)
            d.rectangle([X(-2.5, 60), Y(42), X(2.5, 60), Y(84)], fill=255)
            for j in range(3):
                d.rectangle([X(2, 70 + 5 * j), Y(66 + 6 * j), X(6 + teeth[i][j], 70 + 5 * j), Y(70 + 6 * j)], fill=255)
    g = _blur(_mask_hd(W, H, s, ghosts), 0.9 * s)
    arr = arr * (1 + 0.13 * g[..., None]) + g[..., None] * np.array([0.02, 0.012, 0.0])
    edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
    frame = edge < 16
    arr = np.where(frame[..., None], arr * 0.72, arr)
    arr *= (1 + 0.28 * np.clip(1 - np.abs(edge - 4) / 3, 0, 1) - 0.3 * np.clip(1 - np.abs(edge - 15) / 2, 0, 1))[..., None]

    def scratch(d, k):
        for (hx, hy) in hooks:
            for _ in range(7):
                rr = rng.uniform(30, 60)
                a0 = rng.uniform(55, 80)
                d.arc([(hx - rr) * k, (hy + 2 - rr) * k, (hx + rr) * k, (hy + 2 + rr) * k], a0, a0 + rng.uniform(15, 40),
                      fill=rng.randint(60, 140), width=max(1, int(0.5 * k)))
    sc = _mask_hd(W, H, s, scratch)
    arr = _lay(arr, sc, np.array([0.78, 0.6, 0.38]), 0.8)

    def hookshape(d, k):
        for (hx, hy) in hooks:
            d.ellipse([(hx - 5) * k, (hy - 13) * k, (hx + 5) * k, (hy - 3) * k], fill=255)
            d.line([(hx * k, (hy - 8) * k), (hx * k, (hy + 4) * k)], fill=255, width=int(3 * k))
            d.arc([(hx - 7) * k, (hy - 4) * k, (hx + 7) * k, (hy + 10) * k], 0, 180, fill=255, width=int(3 * k))
            d.line([((hx + 7) * k, (hy + 3) * k), ((hx + 7) * k, (hy - 1) * k)], fill=255, width=int(3 * k))
    hm = _mask_hd(W, H, s, hookshape)
    shadow = np.roll(np.roll(_blur(hm, 2.0 * s), int(3 * s), 0), int(2 * s), 1)
    arr *= (1 - 0.5 * shadow)[..., None]
    shine = 0.75 + 0.5 * np.clip(np.roll(hm, int(s), 1) - hm + 0.5, 0, 1)
    arr = _lay(arr, hm, np.array([0.7, 0.55, 0.25]) * shine[..., None] * 0.85)
    # les étiquettes en relief : ruban noir brillant, lettres blanchies par l'embossage
    from PIL import ImageChops
    ss = 2
    k = s * ss
    lab = Image.new('L', (W * ss, H * ss), 0)
    txt = Image.new('L', (W * ss, H * ss), 0)
    f = font('IBMPlexMono-Bold.ttf', 18 * k)
    for (hx, hy), name in zip(hooks, names):
        tw = f.getlength(name) + 2.2 * k * (len(name) - 1)
        lw_ = tw / k + 18
        cy = hy - 34
        bw, bh = int((lw_ + 24) * k), int(48 * k)
        tl = Image.new('L', (bw, bh), 0)
        tt = Image.new('L', (bw, bh), 0)
        ox, oy = bw / 2 - hx * k, bh / 2 - cy * k                       # du repère de l'image à celui du morceau
        ImageDraw.Draw(tl).rounded_rectangle([(hx - lw_ / 2) * k + ox, (cy - 13) * k + oy, (hx + lw_ / 2) * k + ox, (cy + 13) * k + oy],
                                             radius=int(3 * k), fill=255)
        x = hx * k - tw / 2
        for ch in name:
            _text_on(tt, (x + ox, (cy + 1) * k + oy), ch, f, anchor='lm')
            x += f.getlength(ch) + 2.2 * k
        ang = rng.uniform(-1.2, 1.2)
        tl = tl.rotate(ang, resample=Image.BICUBIC, center=(bw / 2, bh / 2))
        tt = tt.rotate(ang, resample=Image.BICUBIC, center=(bw / 2, bh / 2))
        px, py = int(hx * k - bw / 2), int(cy * k - bh / 2)
        lab.paste(ImageChops.lighter(lab.crop((px, py, px + bw, py + bh)), tl), (px, py))
        txt.paste(ImageChops.lighter(txt.crop((px, py, px + bw, py + bh)), tt), (px, py))
    lm = np.asarray(lab.resize((W, H), Image.BOX), np.float32) / 255.0
    tm = np.asarray(txt.resize((W, H), Image.BOX), np.float32) / 255.0 * lm
    arr *= (1 - 0.35 * np.roll(np.roll(_blur(lm, 1.5 * s), int(2 * s), 0), int(s), 1) * (1 - lm))[..., None]
    arr = _lay(arr, lm, np.array([0.07, 0.07, 0.08]))
    top_band = lm * np.clip(lm - np.roll(lm, int(4 * s), 0), 0, 1)
    arr += top_band[..., None] * 0.18
    sh_t = np.clip(tm - np.roll(np.roll(tm, int(s), 0), int(s), 1), 0, 1)
    hl_t = np.clip(tm - np.roll(np.roll(tm, -int(s), 0), -int(s), 1), 0, 1)
    letters = np.array([0.86, 0.86, 0.84]) * (0.85 + 0.15 * _fbm(W, H, 0.8, 3193, s))[..., None]
    arr = _lay(arr, tm * 0.95, letters)
    arr = arr * (1 - 0.3 * sh_t[..., None]) + 0.1 * hl_t[..., None]
    _save_png(_grime_hd(arr, 0.35, rng, s), 'tableau_cles.png')


def photo_manon():
    """Photo jaunie de 2016 : Manon, de dos et de trois-quarts, assise à son bureau devant un écran
    cathodique vert, dans cette même chambre. Son visage a été rayé au stylo à bille.
    0.3.4 : la même scène, 3 fois plus grande (972 × 732 avec le bord) : l'écran bombé et ses lignes de
    balayage, la lueur verte qui accroche le contour de Manon et ses mèches, le grain d'un tirage de
    supermarché, et le stylo qui a creusé l'émulsion."""
    s = 3.0
    w, h = 300, 220
    W, H = int(w * s), int(h * s)
    rng = random.Random(303)
    rs = np.random.RandomState(303)
    yy, xx = _grid(W, H, s)
    scx, scy = 207.0, 92.0                                   # centre de l'écran
    glow = np.exp(-(((xx - scx) / 85) ** 2 + ((yy - scy) / 70) ** 2))
    glow_wide = np.exp(-(((xx - scx) / 170) ** 2 + ((yy - scy) / 130) ** 2))
    green = np.array([0.32, 0.78, 0.42])
    # la pièce : papier peint à rayures dans le noir, fenêtre de nuit à gauche, une affiche
    stripes = 0.93 + 0.07 * np.clip(np.sin(xx * 0.42) * 3, -1, 1) * (0.7 + 0.3 * _fbm(W, H, 2.0, 3033, s))
    arr = (np.array([0.10, 0.085, 0.07]) * stripes[..., None]
           + green * (glow * 0.55 + glow_wide * 0.12)[..., None] * stripes[..., None])

    def shape(fn):
        return _mask_hd(W, H, s, fn, ss=2)

    def fill(arr, m, col):
        return arr * (1 - m[..., None]) + np.asarray(col, np.float32) * m[..., None]

    win = shape(lambda d, k: d.rectangle([6 * k, 14 * k, 58 * k, 104 * k], fill=255))
    sky = np.array([0.055, 0.08, 0.13]) * (0.85 + 0.3 * _fbm(W, H, 2.2, 3034, s))[..., None]
    arr = arr * (1 - win[..., None]) + sky * win[..., None]
    arr = fill(arr, shape(lambda d, k: (d.line([(32 * k, 14 * k), (32 * k, 104 * k)], fill=255, width=int(3 * k)),
                                        d.line([(6 * k, 58 * k), (58 * k, 58 * k)], fill=255, width=int(3 * k)))), (0.024, 0.024, 0.03))
    curtain = shape(lambda d, k: d.rectangle([0, 8 * k, 14 * k, 120 * k], fill=255))
    folds = 0.75 + 0.35 * (0.5 + 0.5 * np.sin(xx * 1.6 + 2 * _fbm(W, H, 2.0, 3035, s)))
    arr = arr * (1 - curtain[..., None]) + (np.array([0.1, 0.078, 0.07]) * folds[..., None]) * curtain[..., None]
    arr = fill(arr, shape(lambda d, k: d.rectangle([94 * k, 18 * k, 132 * k, 66 * k], fill=255)), (0.18, 0.2, 0.17))
    arr = fill(arr, shape(lambda d, k: d.rectangle([98 * k, 22 * k, 128 * k, 46 * k], fill=255)), (0.118, 0.133, 0.118))
    # le bureau, son chant éclairé par l'écran
    desk = shape(lambda d, k: d.polygon([(70 * k, 150 * k), (300 * k, 142 * k), (300 * k, 220 * k), (70 * k, 220 * k)], fill=255))
    wood = 0.85 + 0.25 * _fbm(W, H, 2.0, 3036, s)
    arr = arr * (1 - desk[..., None]) + (np.array([0.133, 0.118, 0.094]) * wood[..., None] * (0.7 + 0.6 * glow)[..., None]) * desk[..., None]
    arr = fill(arr, shape(lambda d, k: d.polygon([(70 * k, 150 * k), (300 * k, 142 * k), (300 * k, 150 * k), (70 * k, 158 * k)], fill=255)),
               (0.27, 0.38, 0.27))
    # l'écran cathodique : caisse sombre, dalle verte bombée
    case = shape(lambda d, k: d.polygon([(158 * k, 50 * k), (256 * k, 46 * k), (262 * k, 142 * k), (152 * k, 146 * k)], fill=255))
    arr = arr * (1 - case[..., None]) + (np.array([0.25, 0.275, 0.23]) * (0.85 + 0.3 * glow)[..., None]) * case[..., None]
    arr = fill(arr, shape(lambda d, k: d.rectangle([174 * k, 142 * k, 238 * k, 150 * k], fill=255)), (0.17, 0.18, 0.16))
    arr = fill(arr, shape(lambda d, k: d.polygon([(164 * k, 160 * k), (250 * k, 156 * k), (256 * k, 170 * k), (160 * k, 174 * k)], fill=255)),
               (0.157, 0.172, 0.149))
    keys = shape(lambda d, k: [d.line([((166 + j) * k, (163 + j * 3) * k), ((250 + j) * k, (159 + j * 3) * k)], fill=255, width=max(1, int(0.8 * k)))
                               for j in range(4)])
    arr = fill(arr, keys * 0.8, (0.27, 0.37, 0.28))
    sm = _blur(shape(lambda d, k: d.rounded_rectangle([170 * k, 60 * k, 246 * k, 128 * k], radius=9 * k, fill=255)), 0.6 * s)
    curve = 1 - 0.45 * (((xx - 208) / 40) ** 2 + ((yy - 94) / 36) ** 2)  # coins plus sombres
    lines = 0.8 + 0.2 * (0.5 + 0.5 * np.cos(yy * np.pi / 0.75))           # lignes de balayage
    text = np.ones_like(xx)
    for r in range(8):                                                     # lignes de texte vert pâle
        ty = 66 + r * 7
        ln = rng.randint(20, 66)
        tm = shape(lambda d, k: d.rectangle([176 * k, ty * k, (176 + ln) * k, (ty + 2.6) * k], fill=255))
        chars = 0.75 + 0.5 * (np.sin(xx * 2.1 + r) > -0.2)
        text = text + 0.4 * _blur(tm, 0.35 * s) * chars
    screen = np.array([0.5, 1.0, 0.6]) * (np.clip(curve, 0, 1) * lines * text * 0.85)[..., None]
    screen = screen + np.array([0.6, 0.8, 0.65]) * np.exp(-(((xx - 190) / 14) ** 2 + ((yy - 72) / 8) ** 2))[..., None] * 0.2  # reflet de la vitre
    arr = arr * (1 - sm[..., None]) + screen * sm[..., None]
    arr = arr + green * _blur(sm, 6 * s)[..., None] * 0.18                 # la lueur bave autour de la dalle
    # Manon, de dos, tournée vers l'écran : une silhouette en contre-jour
    def body(d, k):
        d.ellipse([97 * k, 62 * k, 141 * k, 112 * k], fill=255)                                     # tête
        d.polygon([(98 * k, 88 * k), (140 * k, 84 * k), (147 * k, 116 * k), (151 * k, 146 * k), (124 * k, 152 * k),
                   (93 * k, 148 * k), (95 * k, 116 * k)], fill=255)                                  # cheveux
        d.ellipse([70 * k, 122 * k, 170 * k, 172 * k], fill=255)                                    # épaules arrondies
        d.polygon([(72 * k, 146 * k), (168 * k, 146 * k), (160 * k, 220 * k), (80 * k, 220 * k)], fill=255)   # dos
        d.line([(158 * k, 138 * k), (182 * k, 160 * k), (204 * k, 160 * k)], fill=255, width=int(13 * k), joint='curve')
        d.ellipse([198 * k, 154 * k, 212 * k, 165 * k], fill=255)                                   # main
        d.rounded_rectangle([54 * k, 158 * k, 84 * k, 220 * k], radius=5 * k, fill=255)             # dossier de la chaise
    sil = _blur(shape(body), 0.5 * s)
    cloth = 0.8 + 0.4 * _fbm(W, H, 2.2, 3037, s)
    bodyc = np.array([0.03, 0.035, 0.03]) * cloth[..., None]
    arr = arr * (1 - sil[..., None]) + bodyc * sil[..., None]
    # liseré vert sur les bords tournés vers l'écran (contre-jour)
    shifted = np.roll(sil, -int(3 * s), axis=1)
    rim = np.clip(sil - shifted, 0, 1) * np.clip(glow * 2.2, 0, 1)
    arr += green * _blur(rim, 0.4 * s)[..., None] * 0.9
    # la joue, de trois-quarts, à peine éclairée par l'écran
    cheek = _blur(shape(lambda d, k: d.chord([116 * k, 68 * k, 144 * k, 110 * k], -80, 80, fill=255)), 1.5 * s)
    arr += np.array([0.1, 0.26, 0.14]) * cheek[..., None]
    hair = Image.new('L', (W, H), 0)                                       # mèches éclairées
    dhr = ImageDraw.Draw(hair)
    for _ in range(9):
        x = 128 + rng.uniform(0, 12)
        pts = [(x, 66 + rng.uniform(0, 8)), (x + rng.uniform(6, 14), 118 + rng.uniform(0, 28))]
        mid = ((pts[0][0] + pts[1][0]) / 2 + rng.uniform(-2, 2), (pts[0][1] + pts[1][1]) / 2)
        dhr.line([(px_ * s, py_ * s) for px_, py_ in (pts[0], mid, pts[1])], fill=150, width=max(1, int(0.7 * s)))
    for _ in range(30):                                                    # et les fines, en HD
        x = 124 + rng.uniform(0, 18)
        y0 = 64 + rng.uniform(0, 10)
        dhr.line([(x * s, y0 * s), ((x + rng.uniform(4, 16)) * s, (y0 + rng.uniform(40, 80)) * s)], fill=rng.randint(50, 110), width=1)
    hm = _blur(np.asarray(hair, np.float32) / 255.0, 0.35 * s) * sil
    arr += green * hm[..., None] * 0.35
    # dateur orange
    stamp = Image.new('L', (W, H), 0)
    _text_on(stamp, ((w - 12) * s, (h - 12) * s), PHOTO_DATE, font('IBMPlexMono-Bold.ttf', int(12 * s)), anchor='rb')
    st = np.asarray(stamp, np.float32) / 255.0
    arr += np.array([1.0, 0.5, 0.12]) * np.clip(_blur(st, 0.25 * s) * .8 + _blur(st, 1.6 * s) * .5, 0, 1)[..., None]
    # tirage de 2016 qui a vieilli : flou, grain, noirs délavés, jaunissement, vignette, taches
    arr = _blur(arr, 0.7 * s)
    g = _blur(rs.randn(H, W).astype(np.float32), 0.45 * s)
    arr = arr + (g * 0.025 * 1.8)[..., None] + _blur(rs.randn(H, W, 3).astype(np.float32), 0.5 * s) * 0.012
    lum = arr @ np.array([0.3, 0.55, 0.15])
    arr = arr * 0.72 + (lum[..., None] * np.array([1.05, 0.95, 0.7])) * 0.28
    arr = 0.12 + arr * 0.86
    arr *= np.array([1.0, 0.93, 0.7])
    vig = 1 - 0.35 * (((xx - w / 2) / (w * .62)) ** 2 + ((yy - h / 2) / (h * .62)) ** 2)
    stain = _fbm(W, H, 2.4, 3031, s)
    arr *= (vig * (0.9 + 0.16 * stain))[..., None]
    arr = _grime_hd(arr, 0.9, rng, s, stains=2)
    # le visage rayé au stylo à bille, par-dessus le tirage : des allers-retours serrés, rageurs
    ink = Image.new('L', (W * 2, H * 2), 0)
    shine = Image.new('L', (W * 2, H * 2), 0)
    groove = Image.new('L', (W * 2, H * 2), 0)
    di, ds, dg = ImageDraw.Draw(ink), ImageDraw.Draw(shine), ImageDraw.Draw(groove)
    k2 = s * 2
    fx, fy, frx, fry = 127, 88, 25, 28
    for layer in range(6):
        ang = rng.uniform(-0.9, 0.9)
        ca, sa = np.cos(ang), np.sin(ang)
        pts = []
        v = -fry - 4
        side = 1
        while v < fry + 4:
            half = frx * np.sqrt(max(0.05, 1 - (v / (fry + 4)) ** 2)) + rng.uniform(-4, 4) + (9 if rng.random() < .12 else 0)
            u = side * half
            pts.append((fx + u * ca - v * sa, fy + u * sa + v * ca))
            v += rng.uniform(1.0, 2.2)
            side = -side
        di.line([(x * k2, y * k2) for x, y in pts], fill=225, width=int(1.1 * k2), joint='curve')
        if layer % 2:                                                       # reflet de l'encre fraîche
            ds.line([((x + 0.4) * k2, y * k2) for x, y in pts[::4]], fill=60, width=max(1, int(0.4 * k2)))
    for _ in range(7):                                                     # quelques coups qui débordent
        a0 = rng.uniform(0, 2 * np.pi)
        r0 = rng.uniform(14, 22)
        di.line([((fx + r0 * np.cos(a0)) * k2, (fy + r0 * np.sin(a0)) * k2),
                 ((fx - (r0 + rng.uniform(6, 16)) * np.cos(a0)) * k2, (fy - (r0 + rng.uniform(4, 12)) * np.sin(a0)) * k2)],
                fill=210, width=int(rng.choice([1, 2]) * k2 * 0.8))
    for _ in range(4):                                                     # sillons clairs dans l'émulsion
        a0 = rng.uniform(0, 2 * np.pi)
        pts = [(fx + rng.uniform(-8, 8), fy + rng.uniform(-10, 10))]
        for _j in range(5):
            a0 += rng.uniform(-0.5, 0.5)
            pts.append((pts[-1][0] + 5 * np.cos(a0), pts[-1][1] + 5 * np.sin(a0)))
        dg.line([(x * k2, y * k2) for x, y in pts], fill=110, width=int(0.8 * k2))
    im = np.asarray(ink.resize((W, H), Image.BOX), np.float32) / 255.0
    sh_ = np.asarray(shine.resize((W, H), Image.BOX), np.float32) / 255.0
    gr = np.asarray(groove.resize((W, H), Image.BOX), np.float32) / 255.0
    im = _blur(im, 0.3 * s) * (0.85 + 0.15 * _fbm(W, H, 1.0, 3038, s))
    arr = arr * (1 - im[..., None]) + np.array([0.055, 0.047, 0.086]) * im[..., None]
    arr = arr + sh_[..., None] * np.array([0.38, 0.41, 0.55]) * 0.75
    arr = arr * (1 - gr[..., None] * 0.6) + gr[..., None] * 0.6 * np.array([0.84, 0.81, 0.72])
    # le bord blanc du tirage (12 px d'origine), papier un peu sale
    bw = int(12 * s)
    FW, FH = W + 2 * bw, H + 2 * bw
    framed = np.ones((FH, FW, 3), np.float32) * np.array([0.886, 0.855, 0.769])
    framed[bw:bw + H, bw:bw + W] = arr
    fs = _fbm(FW, FH, 2.2, 3032, s)
    framed *= (0.9 + 0.12 * fs)[..., None] * np.array([1.0, 0.98, 0.9])
    fyy, fxx = np.mgrid[0:FH, 0:FW].astype(np.float32)
    e = np.minimum(np.minimum(fxx, FW - 1 - fxx), np.minimum(fyy, FH - 1 - fyy)) / s
    framed *= (1 - 0.12 * np.exp(-e / 3.0))[..., None]
    _save_png(framed, 'photo.png')


def _bureau_labels():
    """Les étiquettes des classeurs, lues dans scripts/house/rooms/bureau.gd (_bookcases : les listes de
    « sets »), dans l'ordre, sans les vides : les mêmes chaînes que le jeu, sans recopie."""
    import re
    src = open(os.path.join(ROOT, 'scripts', 'house', 'rooms', 'bureau.gd'), encoding='utf-8').read()
    a = src.index('func _bookcases()')
    b = src.index('for s in sets', a)
    return [x for x in re.findall(r'"([^"]*)"', src[a:b]) if x]


BINDER_CELL = (78, 256)       # une étiquette dans l'atlas : 78 × 256 px (13 colonnes × 4 rangées dans 1024²)


def binder_labels():
    """Étiquettes des dos de classeurs du bureau d'Albert (0.3.4) : atlas assets/images/binder_labels.png
    (1024 × 1024) et binder_labels.json. Une case par étiquette posée (une chaîne qui revient deux fois a
    deux cases : deux étiquettes écrites à la main ne se ressemblent pas). Écriture d'Albert (Reenie
    Beanie, OFL) au stylo bille bleu ou au feutre noir, sur une fiche cartonnée glissée dans la fenêtre
    du dos ; le texte monte (rotation de 90° dans le sens inverse des aiguilles d'une montre, comme le
    px_text pivoté de _binder_row) : le pied des lettres est du côté droit de la case.
    Le .json : {"image", "size", "cell", "labels": {chaîne: [[x, y, l, h] en px, …]}, "uv": {chaîne:
    [[u0, v0, u1, v1], …]}} ; la n-ième fois qu'une chaîne revient dans bureau.gd, elle prend la n-ième case."""
    import json
    labels = _bureau_labels()
    N = 1024
    cw, ch = BINDER_CELL
    cols, rows = N // cw, N // ch
    if len(labels) > cols * rows:
        raise SystemExit('binder_labels : %d étiquettes pour %d cases' % (len(labels), cols * rows))
    rng, rs = _rngs(1201)
    atlas = np.zeros((N, N, 3), np.float32) + np.array([0.8, 0.78, 0.7])
    rects, uvs = {}, {}
    hand = 'ReenieBeanie.ttf'
    for i, txt in enumerate(labels):
        cx0, cy0 = (i % cols) * cw, (i // cols) * ch
        # la fiche : carton crème, plus ou moins jauni, un peu de crasse vers le bas (les doigts)
        Lw, Lh = ch, cw                                                     # dessinée à plat, puis tournée
        tint = np.array([0.88, 0.86, 0.78]) * (1 - rng.uniform(0.0, 0.14)) * np.array([1.0, 1.0 - rng.uniform(0, 0.03), 1.0 - rng.uniform(0, 0.08)])
        card = _paper(Lw, Lh, 2.0, tint, 1210 + i, grain=0.7, tex='Paper002/Paper002_albedo.jpg', mottle=0.08)
        card = _edges(card, 2.0, width=3.0, amount=0.2, yellow=0.25, seed=1230 + i)
        # l'écriture : taille qui tient dans la case (on garde de la marge), petite pente, tremblement
        size = 64
        while True:
            fnt = font(hand, size)
            x0, y0, x1, y1 = fnt.getbbox(txt)
            if (x1 - x0) <= Lw - 30 and (y1 - y0) <= Lh - 22 or size <= 20:
                break
            size -= 2
        m = Image.new('L', (Lw, Lh), 0)
        _text_on(m, (Lw / 2 + rng.uniform(-6, 6), Lh / 2 + rng.uniform(-2, 3)), txt, fnt, angle=rng.uniform(-2.0, 2.0),
                 shear=rng.uniform(-0.08, 0.04))
        mk = np.asarray(m, np.float32) / 255.0
        mk = _wobble(mk, 2.0, amp=0.8, size=30.0, seed=1250 + i)
        blue = rng.random() < 0.6
        if blue:
            card = _ink(card, mk, (0.1, 0.12, 0.36), 'bille', rs, 2.0)
        else:
            card = _ink(card, mk, (0.05, 0.05, 0.06), 'feutre', rs, 2.0)
        sm = _fbm(Lw, Lh, 2.0, 1270 + i, 2.0)
        card = card * (1 - 0.06 * np.clip(sm - 0.4, 0, 1))[..., None]
        cell = np.rot90(card, 1)                                            # le texte monte
        atlas[cy0:cy0 + ch, cx0:cx0 + cw] = cell
        rects.setdefault(txt, []).append([cx0, cy0, cw, ch])
        uvs.setdefault(txt, []).append([round(cx0 / N, 6), round(cy0 / N, 6), round((cx0 + cw) / N, 6), round((cy0 + ch) / N, 6)])
    _save_png(atlas, 'binder_labels.png')
    meta = {'image': 'res://assets/images/binder_labels.png', 'size': [N, N], 'cell': [cw, ch],
            'note': "le texte monte (pied des lettres à droite de la case) ; la n-ième occurrence d'une chaîne prend la n-ième case",
            'labels': rects, 'uv': uvs}
    with open(os.path.join(IMG, 'binder_labels.json'), 'w', encoding='utf-8') as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
    return labels


RUNNER = os.path.join(TEX, 'runner')
COOKIE = os.path.join(TEX, 'flashlight_cookie.png')
RUNNER_TILE_M = 0.52          # côté du carreau runner_tile.png (1024 px), en mètres
RUNNER_BORD_M = (0.13, 0.52)  # largeur × longueur de runner_bord.png (256 × 1024 px), en mètres


def _wool(N, M, seed):
    """Velours de laine noué main, raccordable (N lignes × M colonnes, N multiple de 512) : nœuds de 3 mm
    (170 par carreau), poil inégal, détail d'une vraie moquette (ambientCG Carpet016, CC0), autour de 1."""
    im = Image.open(os.path.join(TEX, 'Carpet016', 'Carpet016_Color.jpg')).convert('L').resize((512, 512), Image.LANCZOS)
    a = np.tile(np.asarray(im, np.float32) / 255.0, (N // 512, 2))
    det = a / np.maximum(_gblur(a, 512 / 6), 1e-3)
    det = np.clip(1 + (det - 1) * 0.9, 0.6, 1.4)[:, :M]
    yy, xx = np.mgrid[0:N, 0:M].astype(np.float32)
    knot = 1024 / 170
    kn = (0.5 + 0.5 * np.cos(2 * np.pi * xx / knot)) * (0.5 + 0.5 * np.cos(2 * np.pi * (yy + 0.5 * knot * (np.floor(xx / knot) % 2)) / knot))
    pile = _periodic_fbm(M, N, 1.2, seed)
    return det * (0.9 + 0.12 * kn) * (0.92 + 0.16 * pile)


def _periodic_fbm(M, N, beta, seed):
    """Bruit fractal raccordable (périodique) de M × N."""
    rs = np.random.RandomState(seed)
    white = rs.randn(N, M)
    fy = np.fft.fftfreq(N)[:, None] * N
    fx = np.fft.rfftfreq(M)[None, :] * M
    r = np.sqrt(fx ** 2 + fy ** 2)
    r[0, 0] = 1
    spec = np.fft.rfft2(white) / r ** (beta / 2)
    spec[0, 0] = 0
    o = np.fft.irfft2(spec, s=(N, M))
    lo, hi = np.percentile(o, 0.2), np.percentile(o, 99.8)
    return np.clip((o - lo) / (hi - lo), 0, 1).astype(np.float32)


def runner():
    """Le tapis du couloir en HD (0.3.4) : assets/textures/runner/runner_tile.png (1024², raccordable dans
    les deux sens : le champ rouge et ses médaillons en losange, un entier au centre et des quarts aux
    coins) et runner_bord.png (256 × 1024, raccordable en longueur : le galon, bord extérieur à gauche,
    côté champ à droite). Couleurs de runner_couloir.png (le motif de _runner_texture, couloir.gd).
    Échelle : RUNNER_TILE_M et RUNNER_BORD_M (≈ 1 970 px/m dans les deux images). L'usure du milieu (chemin
    de passage) n'est pas dans l'image : elle se pose par-dessus (Wear.path)."""
    os.makedirs(RUNNER, exist_ok=True)
    rng, rs = _rngs(1301)
    N = 1024
    red = np.array([0.36, 0.085, 0.07])
    red2 = np.array([0.5, 0.15, 0.11])
    navy = np.array([0.11, 0.1, 0.17])
    ochre = np.array([0.6, 0.43, 0.19])
    dark = np.array([0.17, 0.04, 0.035])
    weft = np.array([0.55, 0.47, 0.39])
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    # --- le champ : médaillons en losange (comme _runner_texture : ocre au cœur, rouge clair, bleu nuit,
    # liseré sombre), un au centre et un réparti sur les quatre coins : le carreau se raccorde
    u = (xx + 0.5) / N
    v = (yy + 0.5) / N
    # le dessin tissé : les contours en escalier des nœuds (≈ 3 mm, 6 px), un peu baveux
    step = 1024 / 170
    qx, qy = np.floor(xx / step) * step + step / 2, np.floor(yy / step) * step + step / 2
    uq, vq = qx / N, qy / N
    dq = np.minimum(np.abs(uq - 0.5) + np.abs(vq - 0.5), np.minimum(np.minimum(np.abs(uq) + np.abs(vq), np.abs(uq - 1) + np.abs(vq)),
                                                                    np.minimum(np.abs(uq) + np.abs(vq - 1), np.abs(uq - 1) + np.abs(vq - 1)))) / 0.42
    def band(lo, hi):
        return ((dq >= lo) & (dq < hi)).astype(np.float32)
    col = np.zeros((N, N, 3), np.float32) + red
    col = col + (ochre - red) * band(0, 0.3)[..., None]
    col = col + (red2 - red) * band(0.3, 0.55)[..., None]
    col = col + (navy - red) * band(0.55, 0.7)[..., None]
    col = col + (dark - red) * band(0.98, 1.08)[..., None]
    # petits motifs dans le cœur (fleurs à huit pétales, bleu nuit) et dans le champ (croix ocre)
    rc = np.minimum(np.hypot(u - 0.5, v - 0.5), np.minimum(np.minimum(np.hypot(u, v), np.hypot(u - 1, v)),
                                                          np.minimum(np.hypot(u, v - 1), np.hypot(u - 1, v - 1))))
    ru, rv = (u + 0.5) % 1.0 - 0.5, (v + 0.5) % 1.0 - 0.5                  # au centre et aux coins
    th = np.where(rc == np.hypot(u - 0.5, v - 0.5), np.arctan2(v - 0.5, u - 0.5), np.arctan2(rv, ru))
    flower = (rc < 0.055 * (0.62 + 0.38 * np.abs(np.cos(4 * th)))).astype(np.float32)   # rosace à huit pétales
    flower = np.clip(flower - (rc < 0.012), 0, 1)
    col = col + (navy - col) * flower[..., None] * 0.9
    cross_u, cross_v = (u + 0.25) % 0.5 - 0.25, (v + 0.25) % 0.5 - 0.25
    cross = (((np.abs(cross_u) < 0.012) & (np.abs(cross_v) < 0.05)) | ((np.abs(cross_v) < 0.012) & (np.abs(cross_u) < 0.05))).astype(np.float32)
    cross *= (dq > 1.1)
    col = col + (ochre * 0.85 - col) * cross[..., None]
    col = _gblur(col, 1.4)
    # laine : nœuds, abrash (bandes de teinte des bains de teinture, en travers), poussière
    wool = _wool(N, N, 1302)
    abrash = 0.94 + 0.12 * _periodic_fbm(N, N, 3.0, 1303)[:, :1]
    col = col * wool[..., None] * abrash[..., None] * 0.97
    worn = np.clip((_periodic_fbm(N, N, 1.6, 1304) - 0.62) * 3.0, 0, 1) * 0.5     # trame qui apparaît, par plaques
    col = col * (1 - worn[..., None]) + weft * wool[..., None] * worn[..., None] * 0.8
    stains = np.clip((_periodic_fbm(N, N, 2.6, 1305) - 0.7) * 4, 0, 1)
    col = col * (1 - 0.3 * stains[..., None])
    col = col * 0.72 + 0.28 * np.array([0.3, 0.24, 0.2])                    # le ton passé de runner_couloir.png
    img = np.clip(col, 0, 1)
    Image.fromarray((img * 255 + 0.5).astype(np.uint8), 'RGB').save(os.path.join(RUNNER, 'runner_tile.png'), optimize=True)
    # --- le galon : 0,13 m (256 px), raccordable en longueur
    Wb = 256
    yb, xb = np.mgrid[0:N, 0:Wb].astype(np.float32)
    e = xb / Wb * RUNNER_BORD_M[0]                                             # distance au bord extérieur (m)
    c = np.zeros((N, Wb, 3), np.float32) + red
    c = np.where((e < 0.012)[..., None], dark, c)
    c = np.where(((e >= 0.012) & (e < 0.018))[..., None], ochre, c)
    navy_band = (e >= 0.018) & (e < 0.105)
    c = np.where(navy_band[..., None], navy, c)
    # dans le bleu nuit : une frise de petits rectangles ocre (les tirets de l'ancien dessin) et un rinceau
    period = N / 16
    dash = ((yb % period) < period * 0.36) & (np.abs(e - 0.06) < 0.008)
    c = np.where(dash[..., None], ochre, c)
    wave = np.abs(e - (0.06 + 0.022 * np.sin(2 * np.pi * yb / (N / 8)))) < 0.0035
    c = np.where((wave & navy_band & ~dash)[..., None], red2 * 0.9, c)
    c = np.where(((e >= 0.105) & (e < 0.111))[..., None], ochre, c)
    c = np.where(((e >= 0.111) & (e < 0.118))[..., None], dark, c)
    c = _gblur(c, 1.2)
    woolb = _wool(N, Wb, 1306)
    c = c * woolb[..., None] * 0.97
    # le bord extérieur, roulé et râpé : la trame claire apparaît sur le surjet
    fray = np.clip((0.006 - e) / 0.006, 0, 1) * (0.5 + 0.5 * _periodic_fbm(Wb, N, 1.4, 1307))
    c = c * (1 - 0.6 * fray[..., None]) + weft * 0.6 * fray[..., None]
    worn_b = np.clip((_periodic_fbm(Wb, N, 1.6, 1308) - 0.65) * 3.0, 0, 1) * 0.4
    c = c * (1 - worn_b[..., None]) + weft * woolb[..., None] * worn_b[..., None] * 0.8
    c = c * 0.72 + 0.28 * np.array([0.3, 0.24, 0.2])
    Image.fromarray((np.clip(c, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGB').save(os.path.join(RUNNER, 'runner_bord.png'), optimize=True)


def flashlight_cookie():
    """Le motif projeté par la lampe de poche (0.3.4) : textures/flashlight_cookie.png, 512 px, même dessin
    que la 0.3.3 (point chaud, anneau du réflecteur, halo, coupure nette au bord : profil relevé sur
    l'ancien fichier de 256 px), avec les défauts d'un réflecteur embouti : point chaud un peu décentré,
    peau d'orange de l'emboutissage, rayures radiales, une trace de doigt. En 8 bits tramé : Godot 4.7 importe les
    PNG 16 bits en L8 (vérifié), le tramage efface les marches de l'anneau aussi bien. Import sans perte."""
    N = 512
    rng, rs = _rngs(1401)
    # profil de la 0.3.3 (niveau moyen par anneau de 4 px de rayon sur 128) : r (fraction du rayon) -> 0..1
    prof_r = np.array([0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60, 64, 68, 72, 76, 80, 84, 88,
                       92, 96, 100, 104, 108, 112, 116, 120, 124, 128], np.float32) + 2.0
    prof_r[0] = 0.0
    prof_v = np.array([249.6, 249.7, 249.8, 250.1, 249.4, 245.0, 236.6, 226.1, 215.5, 205.2, 196.4, 191.4, 192.2,
                       197.9, 197.9, 189.3, 179.5, 168.4, 154.6, 138.4, 121.4, 104.1, 90.4, 82.5, 81.1, 81.0,
                       76.4, 63.6, 46.1, 27.5, 11.5, 1.8, 0.0], np.float32) / 255.0
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    c = N / 2.0
    ox, oy = 0.012 * N, -0.008 * N                                       # point chaud un peu décentré
    r_hot = np.hypot(xx + 0.5 - c - ox, yy + 0.5 - c - oy) / (N / 2) * 128
    r = np.hypot(xx + 0.5 - c, yy + 0.5 - c) / (N / 2) * 128
    # le centre suit le point chaud, le bord reste centré (la coupure vient de la lentille)
    t = np.clip(r / 100.0, 0, 1)
    rr = r_hot * (1 - t) + r * t
    v = np.interp(rr, prof_r, prof_v)
    ang = np.arctan2(yy + 0.5 - c, xx + 0.5 - c)
    ring = np.clip((rr - 20) / 30, 0, 1) * np.clip((116 - rr) / 20, 0, 1)
    facets = 1 + 0.025 * (_fbm(N, N, 1.8, 1403, 2.0) - 0.5) * ring          # peau d'orange de l'emboutissage
    lobes = 1 + 0.02 * np.cos(6 * ang + 0.4) * np.clip((rr - 40) / 40, 0, 1) * np.clip((118 - rr) / 20, 0, 1)
    streak = np.zeros((N, N), np.float32)
    for _ in range(7):                                                   # rayures du réflecteur, en rayons
        a0 = rng.uniform(-np.pi, np.pi)
        wdt = rng.uniform(0.004, 0.012)
        da = np.angle(np.exp(1j * (ang - a0)))
        streak += np.exp(-(da / wdt) ** 2) * rng.uniform(-0.022, 0.018) * np.clip((rr - 30) / 40, 0, 1)
    smudge = 1 - 0.035 * np.exp(-(((xx - c + 0.18 * N) / (0.07 * N)) ** 2 + ((yy - c - 0.12 * N) / (0.05 * N)) ** 2))
    mottle = 1 + 0.015 * (_fbm(N, N, 2.0, 1402, 2.0) - 0.5)
    out = v * facets * lobes * (1 + streak) * smudge * mottle
    out = _blur(out, 0.8)
    # même énergie que la 0.3.3 (la lampe éclaire autant)
    ref = np.interp(np.hypot(xx + 0.5 - c, yy + 0.5 - c) / (N / 2) * 128, prof_r, prof_v)
    out = out * (ref.sum() / max(out.sum(), 1e-6))
    q = np.clip(out * 255 + rs.uniform(-0.5, 0.5, out.shape) + rs.uniform(-0.5, 0.5, out.shape), 0, 255)
    q = np.where(out <= 0.5 / 255, 0, q)                                 # le noir reste noir
    Image.fromarray((q + 0.5).astype(np.uint8), 'L').save(COOKIE, optimize=True)




# ------------------------------------------------------------ 0.3.4 : régénération et contrôles des images HD

# Les chaînes dessinées par les générateurs de la 0.3.3 (relevé : ImageDraw.text, dans l'ordre, par image ;
# les répétitions consécutives sont fusionnées : un stylo qui repasse deux fois sur le même mot ne compte
# qu'une fois). « make_assets.py images » vérifie que les générateurs HD dessinent exactement les mêmes.
TEXTES_033 = {
    'note': ['ne pas', 'jouer', 'après minuit'],
    'paper_312': ['ne pas jouer ne pas jouer', 'ne pas jouer ne pas jouer', '3:12  3:12  3:12  3:12',
        'ne pas jouer ne pas jouer', 'ne pas jouer ne pas jouer', '3:12  3:12  3:12  3:12',
        'ne pas jouer ne pas jouer', 'ne pas jouer ne pas jouer', '3:12  3:12  3:12  3:12',
        'ne pas jouer ne pas jouer', 'ne pas jouer ne pas jouer', '3:12  3:12  3:12  3:12'],
    'manual': ['RUNTIME', "MANUEL DE L'UTILISATEUR", '© 1984'],
    'calendar': ['OCTOBRE 2016', 'L', 'M', 'M', 'J', 'V', 'S', 'D', '1', '2', '3', '4', '5', '6', '7', '8', '9',
        '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24', '25', '26', '27',
        '28', '29', '30', '31'],
    'clock_face': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'],
    'corkboard': ['rendre la K7', 'à Karim', '14h dentiste', '(mardi)', 'elle me', 'regarde', 'la nuit'],
    'poster_choisis': ['CHOISIS', 'OU SINON', 'UN FILM DE J. MORVAN · 1983'],
    'poster_corbeaux': ['Les Corbeaux', 'EN CONCERT', 'SALLE DES FÊTES · 31 OCTOBRE'],
    'poster_spectres': ['LES SPECTRES', 'TOURNÉE 84 · COMPLET'],
    'ceraf_label': ['CERAF · INVENTAIRE N° 0312', '0312', 'N° 0312', 'PROPRIÉTÉ DU CERAF — NE PAS SORTIR DU SITE'],
    'floppy_label': ['R', 'U', 'N', 'T', 'I', 'M', 'E', ' ', '—', ' ', 'S', 'A', 'U', 'V', '.', ' ', '0', '1', '/',
        '1', '1', '/', '9', '9', 'NE', 'PAS', 'JOUER'],
    'vhs_label': ['NE PAS EFFACER'],
    'postit_chocolat': ['mot de passe :', 'mot de passe :', 'CHOCOLAT', 'CHOCOLAT'],
    'carton_2euros': ['HAUT', 'TOUT', 'À', '€'],
    'tableau_cles': ['C', 'A', 'V', 'E', 'E', 'S', 'C', 'A', 'L', 'I', 'E', 'R', 'C', 'U', 'I', 'S', 'I', 'N', 'E',
        'B', 'I', 'B', 'L', 'I', 'O', 'C', 'E', 'L', 'L', 'I', 'E', 'R', 'B', 'U', 'R', 'E', 'A', 'U', 'L', 'I', 'N',
        'G', 'E', 'R', 'I', 'E'],
    'tin_lid': [],
    'photo': ["'16 10 31"],
}

# les générateurs HD, dans l'ordre (calendar_octobre, floppy_label_albert et photo_manon gardent leur nom
# de l'acte I) ; leurs fichiers, et la taille de la 0.3.3 (rapport largeur / hauteur à garder)
HD_IMAGES = [note, papers, calendar_octobre, clock_face, corkboard, poster_choisis, poster_corbeaux, poster_spectres,
             ceraf_label, floppy_label_albert, vhs_label, postit_chocolat, carton_2euros, tableau_cles, tin_lid, photo_manon]
TAILLES_033 = {'note': (256, 320), 'paper_312': (256, 340), 'manual': (256, 340), 'calendar': (300, 420),
               'clock_face': (256, 256), 'corkboard': (512, 384), 'poster_choisis': (512, 736), 'poster_corbeaux': (400, 560),
               'poster_spectres': (512, 512), 'ceraf_label': (256, 96), 'floppy_label': (256, 96), 'vhs_label': (256, 48),
               'postit_chocolat': (256, 256), 'carton_2euros': (512, 320), 'tableau_cles': (512, 384), 'tin_lid': (512, 512),
               'photo': (324, 244)}


def _dedup(seq):
    out = []
    for x in seq:
        if not out or out[-1] != x:
            out.append(x)
    return out


# Nombres de 32 bits que les générateurs d'images de la 0.3.3 tiraient du hasard global (random) dans la
# génération complète : 5211 (photo, poster_choisis, poster_spectres, note, floppy_label), puis 4496 (calendar,
# corkboard, clock_face, poster_corbeaux, papers, vhs_label). Les générateurs HD ont leur propre hasard ; on
# tire quand même ces nombres au même endroit, pour que ce qui suit (scratches.png, rain_loop.wav…) ne change pas.
HASARD_033 = (5211, 4496)


def _hasard_033(n):
    random.getrandbits(32 * n)


IMPORT_VRAM = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality=false
mipmaps/generate=true
detect_3d/compress_to=0
"""


def _import_vram(paths):
    """Les images HD sont importées compressées pour la carte (BC1, ou BC3 avec alpha) : 4 à 8 fois moins de
    mémoire que l'import sans perte, pas de décodage PNG au chargement. On règle leur .import (même uid) ;
    une image neuve reçoit un .import minimal que Godot complète au prochain « --import »."""
    for path in paths:
        imp = path + '.import'
        if not os.path.exists(imp):
            with open(imp, 'w', encoding='utf-8') as f:
                f.write(IMPORT_VRAM)
            continue
        txt = open(imp, encoding='utf-8').read()
        new = txt.replace('compress/mode=0', 'compress/mode=2').replace('detect_3d/compress_to=1', 'detect_3d/compress_to=0')
        new = new.replace('compress/high_quality=true', 'compress/high_quality=false')
        if new != txt:
            with open(imp, 'w', encoding='utf-8') as f:
                f.write(new)


def images_hd():
    """« make_assets.py images » : régénère les images HD de la 0.3.4 (HD_IMAGES, binder_labels, runner,
    flashlight_cookie, et les photos de make_photos.py, dont il télécharge d'abord les sources) et contrôle :
    mêmes chaînes dessinées que la 0.3.3 (TEXTES_033), étiquettes des classeurs = celles de bureau.gd, même
    rapport largeur / hauteur à 1 % près, hasard global intact. Arrête le script (code 1) sur une différence."""
    photos = _photos_module()
    photos.OUT = os.path.join(IMG, 'photos')
    photos.fetch()
    got = {}
    cur = []
    orig_text = ImageDraw.ImageDraw.text
    orig_save = Image.Image.save
    state = (random.getstate(), np.random.get_state())

    def text(self, xy, t, *a, **k):
        cur.append(t)
        return orig_text(self, xy, t, *a, **k)

    def save(self, fp, *a, **k):
        name = os.path.splitext(os.path.basename(str(fp)))[0]
        if os.path.dirname(os.path.abspath(str(fp))) == os.path.abspath(IMG):
            got[name] = _dedup(cur)
        cur.clear()
        return orig_save(self, fp, *a, **k)

    ImageDraw.ImageDraw.text = text
    Image.Image.save = save
    try:
        for f in HD_IMAGES:
            cur.clear()
            f()
        cur.clear()
        labels = binder_labels()
        runner()
        flashlight_cookie()
        for f in photos.PHOTOS.values():
            f()
    finally:
        ImageDraw.ImageDraw.text = orig_text
        Image.Image.save = orig_save
    bad = []
    for name, want in TEXTES_033.items():
        if name not in got:
            bad.append('%s : pas régénérée' % name)
        elif got[name] != _dedup(want):
            bad.append('%s : chaînes %r au lieu de %r' % (name, got[name], _dedup(want)))
        w0, h0 = TAILLES_033[name]
        w1, h1 = Image.open(os.path.join(IMG, name + '.png')).size
        if abs((w1 / h1) / (w0 / h0) - 1) > 0.01:
            bad.append('%s : rapport %d × %d au lieu de %d × %d' % (name, w1, h1, w0, h0))
        print('%-16s %4d × %-4d  %d chaînes' % (name, w1, h1, len(got.get(name, []))))
    if got.get('binder_labels') != _dedup(labels):
        bad.append('binder_labels : %r au lieu de %r' % (got.get('binder_labels'), _dedup(labels)))
    print('binder_labels    %d étiquettes de bureau.gd' % len(labels))
    if random.getstate() != state[0] or any(not np.array_equal(x, y) if isinstance(x, np.ndarray) else x != y
                                             for x, y in zip(np.random.get_state(), state[1])):
        bad.append('le hasard global a bougé')
    paths = [os.path.join(IMG, n + '.png') for n in TAILLES_033] + [os.path.join(IMG, 'binder_labels.png')]
    paths += [os.path.join(photos.OUT, n + '.png') for n in photos.PHOTOS]
    paths += [os.path.join(RUNNER, n) for n in ('runner_tile.png', 'runner_bord.png')]
    _import_vram(paths)
    total = sum(os.path.getsize(p_) for p_ in paths + [COOKIE])
    print('photos           %d (%s)' % (len(photos.PHOTOS), ', '.join(photos.PHOTOS)))
    print('taille des PNG   %.1f Mo' % (total / 1e6))
    if bad:
        print('ÉCHEC des images HD :\n  ' + '\n  '.join(bad))
        raise SystemExit(1)
    print('images HD : mêmes chaînes et mêmes rapports que la 0.3.3 (%d images)' % len(TAILLES_033))


STORY = [snore, breath_slow, door_slide]   # 0.3.4 : les images de l'acte I sont dans HD_IMAGES (« images »)


# ============================================================ v0.3.1 : l'étage
# Images et sons du 1er étage (docs/v0.3.md § 5.7). Comme pour STORY : chaque fonction a ses
# PROPRES générateurs à graine fixe (random.Random, np.random.RandomState), jamais le hasard global.
# Les sons en boucle sont construits de façon circulaire : la fin raccorde exactement avec le début.

FLOOR_TIME = '03:27'   # l'heure imprimée sur la photo de la caméra du couloir (le « 03:2x » des textes)


def _rngs(seed):
    return random.Random(seed), np.random.RandomState(seed)


def _gblur(a, sigma):
    """Flou gaussien par FFT (circulaire) d'un tableau (h, w) ou (h, w, c)."""
    if sigma <= 0:
        return a
    h, w = a.shape[:2]
    g = np.exp(-2 * (np.pi * sigma) ** 2 * (np.fft.fftfreq(h)[:, None] ** 2 + np.fft.rfftfreq(w)[None, :] ** 2))
    if a.ndim == 2:
        return np.fft.irfft2(np.fft.rfft2(a) * g, s=(h, w))
    return np.stack([np.fft.irfft2(np.fft.rfft2(a[..., c]) * g, s=(h, w)) for c in range(a.shape[2])], -1)


def _mask(w, h, ss, draw_fn):
    """Masque lissé : dessine à ss fois la taille (draw_fn(d, ss)), puis réduit par moyenne."""
    big = Image.new('L', (w * ss, h * ss), 0)
    draw_fn(ImageDraw.Draw(big), ss)
    return np.asarray(big.resize((w, h), Image.BOX)).astype(np.float32) / 255.0


def _lay(arr, m, col, k=1.0):
    """Pose une couleur à travers un masque."""
    m = np.clip(m * k, 0, 1)[..., None]
    return arr * (1 - m) + np.asarray(col, np.float32) * m


def _paper_white(w, h, seed):
    """Papier d'imprimante : blanc un peu cassé, fibres à peine visibles."""
    fib = fbm_tile(1024, 0.5, seed)[:h, :w]
    big = fbm_tile(1024, 2.4, seed + 1)[:h, :w]
    return np.array([0.962, 0.958, 0.945]) * (0.985 + 0.02 * fib + 0.014 * big)[..., None]


def _inkjet(content, paper, rs, density=0.9, bands=1.0, grain=0.22, dead=0.025):
    """Impression jet d'encre : content = l'image voulue (RGB, 1 = blanc), paper = le papier.
    L'encre bave un peu, le cyan et le magenta sont décalés d'un pixel, les passages du chariot
    laissent des bandes, quelques buses bouchées font des lignes claires, grain dans les gris."""
    h, w = content.shape[:2]
    d = _gblur(1 - np.clip(content, 0, 1), 0.5)
    d[..., 0] = 0.7 * d[..., 0] + 0.3 * np.roll(d[..., 0], 1, axis=1)
    d[..., 1] = 0.75 * d[..., 1] + 0.25 * np.roll(d[..., 1], 1, axis=0)
    y = np.arange(h)
    pas = 24                                                  # hauteur d'un passage de la tête
    band = 1 - 0.06 * bands * (y % pas) / pas - 0.12 * bands * ((y % pas) == 0)
    band *= np.where(rs.rand(h) < dead, 1 - 0.3 * bands, 1.0)   # buses bouchées
    y0 = h * rs.uniform(0.3, 0.75)                            # une bande plus pâle (cartouche fatiguée)
    band *= 1 - 0.08 * bands * np.exp(-0.5 * ((y - y0) / (h * 0.035)) ** 2)
    d *= band[:, None, None]
    mid = np.clip(d.mean(-1, keepdims=True), 0, 1)
    d = np.clip(d * (1 + grain * rs.randn(h, w, 1) * np.clip(mid * (1 - mid) * 4, 0, 1)), 0, 1)
    return paper * (1 - d * density)


# Plan du 1er étage, copié de scripts/house/house_data.gd (pièces [x0, x1, z0, z1], portes, fenêtres).
_F1_ROOMS = {
    'gp': ([-3.2, 3.2, -7.3, -2.7], 'CHAMBRE 1'), 'mere': ([-3.2, 3.2, -2.6, 2.6], 'CHAMBRE 2'),
    'amis': ([-3.2, 3.2, 2.7, 6.3], 'CHAMBRE 3'), 'couloir': ([3.3, 4.7, -7.3, 6.3], 'COULOIR'),
    'sdb': ([4.8, 9.2, -7.3, -4.0], 'SALLE DE BAIN'), 'lingerie': ([4.8, 9.2, -3.9, -0.5], 'LINGERIE'),
    'escalier': ([4.8, 9.2, -0.4, 1.9], 'ESCALIER'), 'bureau': ([4.8, 9.2, 2.0, 6.3], 'BUREAU'),
}
_F1_DOORS = [(3.25, 1.40, -1), (3.25, -3.60, -1), (3.25, 3.40, -1), (4.75, -4.60, 1), (4.75, -1.20, 1),
             (4.75, 1.35, -1), (4.75, 4.40, 1)]                  # (mur x, centre z, côté du battant)
_F1_WINDOWS = [('x', -3.25, -0.45, 1.4), ('x', -3.25, -5.0, 1.4), ('x', -3.25, 4.5, 1.4), ('x', 9.25, -5.8, 0.8),
               ('x', 9.25, -2.2, 0.8), ('x', 9.25, 0.75, 1.0), ('x', 9.25, 4.15, 1.4), ('z', 6.35, 4.0, 0.7)]


def plan_etage():
    """Page imprimée par l'entité : le plan du 1er étage au trait, tel que le connaît la console
    domotique (chambres numérotées, appareils connectés, caméras), la salle de bain entourée de rouge
    et, en dessous, PROTOCOLE 4. Jet d'encre sur papier ordinaire. A4, 576 × 816."""
    w, h, ss = 576, 816, 3
    rng, rs = _rngs(311)
    s = 35.0                                                   # pixels par mètre
    ext = 0.12                                                 # surépaisseur des murs extérieurs
    ox = (w - (13.8 + 2 * ext) * s) / 2 + ext * s
    oy = 122 + ext * s

    def P(x, z, k=1):                                          # repère du jeu -> pixels ; le jardin en haut
        return (ox + (z + 7.4) * s) * k, (oy + (9.3 - x) * s) * k

    def rect(d, k, x0, x1, z0, z1, fill):
        ax, ay = P(x1, z0, k)
        bx, by = P(x0, z1, k)
        d.rectangle([ax, ay, bx, by], fill=fill)

    mono = lambda size, k: font('IBMPlexMono-Regular.ttf', int(size * k))
    bold = lambda size, k: font('IBMPlexMono-Bold.ttf', int(size * k))

    def walls(d, k):
        rect(d, k, -3.3 - ext, 9.3 + ext, -7.4 - ext, 6.4 + ext, 255)
        for r, _ in _F1_ROOMS.values():
            rect(d, k, r[0], r[1], r[2], r[3], 0)
        rect(d, k, 4.8, 7.3, 0.7, 0.8, 255)                     # mur d'échiffre de l'escalier
        for at, c, side in _F1_DOORS:                           # baies des portes
            rect(d, k, at - 0.06, at + 0.06, c - 0.43, c + 0.43, 0)
        for axis, at, c, wd in _F1_WINDOWS:                     # baies des fenêtres
            o = -1 if at < 0 else 1
            lo, hi = sorted((at - 0.06 * o, at + (0.06 + ext) * o))
            if axis == 'x':
                rect(d, k, lo, hi, c - wd / 2, c + wd / 2, 0)
            else:
                rect(d, k, c - wd / 2, c + wd / 2, lo, hi, 0)

    def lines(d, k):
        lw = max(1, int(1.1 * k))
        for at, c, side in _F1_DOORS:                           # battants ouverts à 90° et leur arc
            hx, hz = at + side * 0.05, c - 0.43
            ex = at + side * (0.05 + 0.82)
            d.line([P(hx, hz, k), P(ex, hz, k)], fill=255, width=lw)
            arc = [P(hx + side * 0.82 * np.cos(a), hz + 0.86 * np.sin(a), k) for a in np.linspace(0, np.pi / 2, 24)]
            d.line(arc, fill=200, width=max(1, int(0.7 * k)))
        for axis, at, c, wd in _F1_WINDOWS:                     # vitrages : trois filets
            o = -1 if at < 0 else 1
            for off in (-0.04, 0.05, 0.14):
                xx = at + off * o
                if axis == 'x':
                    d.line([P(xx, c - wd / 2, k), P(xx, c + wd / 2, k)], fill=255, width=max(1, int(0.7 * k)))
                else:
                    d.line([P(c - wd / 2, xx, k), P(c + wd / 2, xx, k)], fill=255, width=max(1, int(0.7 * k)))
        # escalier : deux volées de 7 girons, palier ; flèche de descente
        for z0, z1 in ((0.8, 1.9), (-0.4, 0.7)):
            for i in range(8):
                x = 5.2 + 0.3 * i
                d.line([P(x, z0, k), P(x, z1, k)], fill=255, width=max(1, int(0.8 * k)))
            d.line([P(5.2, z0, k), P(7.3, z0, k)], fill=255, width=max(1, int(0.8 * k)))
        pts = [P(5.0, 1.35, k), P(7.05, 1.35, k)]
        d.line(pts, fill=255, width=lw)
        tx, ty = P(7.25, 1.35, k)
        d.polygon([(tx, ty), (tx - 5 * k, ty + 9 * k), (tx + 5 * k, ty + 9 * k)], fill=255)
        d.line([P(5.55, -0.45, k), P(6.75, 0.65, k)], fill=255, width=lw)   # ligne de coupe de la volée du bas
        # noms des pièces et surfaces
        for key, (r, name) in _F1_ROOMS.items():
            cx, cz = (r[0] + r[1]) / 2, (r[2] + r[3]) / 2
            if key == 'escalier':
                cx, cz = 8.3, 0.75
            if key == 'couloir':
                px, py = P(cx, -2.0, k)
                d.text((px, py), name, font=mono(11, k), fill=255, anchor='mm')
                continue
            area = (r[1] - r[0]) * (r[3] - r[2])
            px, py = P(cx, cz, k)
            d.text((px, py - 7 * k), name, font=mono(11, k), fill=255, anchor='mm')
            if key != 'escalier':
                d.text((px, py + 8 * k), f'{area:.1f} m²'.replace('.', ','), font=mono(9, k), fill=170, anchor='mm')
        # rue, jardin, échelle, légende
        px, py = P(9.3, -0.5, k)
        d.text((px, py - 16 * k), 'JARDIN', font=mono(10, k), fill=255, anchor='mm')
        px, py = P(-3.3, -0.5, k)
        d.text((px, py + 16 * k), 'RUE', font=mono(10, k), fill=255, anchor='mm')
        bx, by = 44 * k, 610 * k
        for i in range(4):
            seg = [bx + i * 0.5 * s * k, by, bx + (i + 1) * 0.5 * s * k, by + 5 * k]
            d.rectangle(seg, fill=255 if i % 2 == 0 else 0, outline=255, width=max(1, int(0.7 * k)))
        for m in range(3):
            d.text((bx + m * s * k, by + 14 * k), str(m), font=mono(9, k), fill=255, anchor='mm')
        d.text((bx + 2 * s * k + 14 * k, by + 14 * k), 'm', font=mono(9, k), fill=255, anchor='mm')
        lx = 330 * k
        d.ellipse([lx - 3 * k, by - 1 * k, lx + 3 * k, by + 5 * k], fill=255)
        d.text((lx + 9 * k, by + 2 * k), 'APPAREIL CONNECTÉ', font=mono(9, k), fill=255, anchor='lm')
        d.polygon([(lx - 4 * k, by + 22 * k), (lx + 4 * k, by + 18 * k), (lx + 4 * k, by + 26 * k)], fill=255)
        d.text((lx + 9 * k, by + 22 * k), 'CAMÉRA', font=mono(9, k), fill=255, anchor='lm')
        # appareils connectés (points) et caméras (triangle + champ)
        for x, z in [(3.52, -1.0), (4.0, -5.0), (4.0, -0.5), (4.0, 4.0), (4.0, 2.2), (7.0, -4.15), (6.0, -5.7),
                     (4.95, -6.4), (1.15, 5.95), (7.2, 6.0), (8.3, 6.0), (5.55, 6.1), (6.9, 4.2), (-0.05, -3.6)]:
            px, py = P(x, z, k)
            d.ellipse([px - 2.6 * k, py - 2.6 * k, px + 2.6 * k, py + 2.6 * k], fill=255)
        for (x, z), (tx, tz), ln, ha, (lx2, lz2), label in (
                ((4.0, -7.18), (4.0, -4.0), 1.1, 0.42, (3.52, -6.55), 'CAM 1'),
                ((2.9, -6.9), (-0.4, -3.8), 1.6, 0.55, (3.02, -6.15), 'CAM 3'),
                ((-3.45, 0.6), (-6.4, 1.6), 1.2, 0.5, (-3.78, 1.4), 'CAM 2')):
            a = np.arctan2(tz - z, tx - x)
            ux, uz = np.cos(a), np.sin(a)
            px, py = P(x, z, k)
            tip = P(x + ux * 0.28, z + uz * 0.28, k)
            l1 = P(x - uz * 0.12, z + ux * 0.12, k)
            l2 = P(x + uz * 0.12, z - ux * 0.12, k)
            d.polygon([l1, l2, tip], fill=255)
            for sgn in (-1, 1):                                  # champ de vision, en pointillés
                b = a + sgn * ha
                for t0 in np.arange(0.35, ln, 0.18):
                    d.line([P(x + np.cos(b) * t0, z + np.sin(b) * t0, k),
                            P(x + np.cos(b) * (t0 + 0.09), z + np.sin(b) * (t0 + 0.09), k)], fill=150, width=lw)
            d.text(P(lx2, lz2, k), label, font=mono(8, k), fill=255, anchor='mm')

    def cable(d, k):                                            # ton câble, en pointillés fins
        pts = [(3.34, 1.0), (3.34, 4.15), (4.66, 4.15), (4.85, 4.15), (4.85, 6.2), (5.45, 6.2)]
        for (x0, z0), (x1, z1) in pairwise(pts):
            n = max(1, int(np.hypot(x1 - x0, z1 - z0) / 0.12))
            for i in range(0, n, 2):
                a, b = i / n, min(1, (i + 1) / n)
                d.line([P(x0 + (x1 - x0) * a, z0 + (z1 - z0) * a, k), P(x0 + (x1 - x0) * b, z0 + (z1 - z0) * b, k)],
                       fill=255, width=max(1, int(0.8 * k)))

    def texts(d, k):
        d.text((40 * k, 40 * k), 'CONSOLE DOMOTIQUE · PLAN DU LOGEMENT', font=mono(11, k), fill=255, anchor='lm')
        d.text((w * k - 40 * k, 40 * k), '1er ÉTAGE', font=bold(11, k), fill=255, anchor='rm')
        d.line([(40 * k, 52 * k), (w * k - 40 * k, 52 * k)], fill=255, width=max(1, int(0.8 * k)))
        d.text((w * k / 2, 690 * k), 'PROTOCOLE 4', font=bold(46, k), fill=255, anchor='mm')
        d.line([(40 * k, 772 * k), (w * k - 40 * k, 772 * k)], fill=255, width=max(1, int(0.6 * k)))
        d.text((w * k - 40 * k, 786 * k), '1/1', font=mono(9, k), fill=255, anchor='rm')

    def circle(d, k):                                           # le cercle rouge, tracé d'un geste
        cx, cy = P(6.95, -5.6, 1)
        rx, ry = 2.3 * s, 2.75 * s
        a0 = rng.uniform(-2.4, -2.0)
        turns = np.linspace(a0, a0 + 2 * np.pi * 1.12, 140)
        pts = []
        for i, a in enumerate(turns):
            grow = 1 + 0.06 * i / len(turns) + 0.025 * np.sin(a * 3 + 1.3)
            pts.append(((cx + rx * grow * np.cos(a)) * k, (cy + ry * grow * np.sin(a) * 0.98) * k))
        d.line(pts, fill=255, width=int(3.8 * k), joint='curve')

    page = np.ones((h, w, 3), np.float32)
    page = _lay(page, _mask(w, h, ss, walls), (0.1, 0.1, 0.1))
    page = _lay(page, _mask(w, h, ss, lines), (0.08, 0.08, 0.08))
    page = _lay(page, _mask(w, h, ss, cable), (0.45, 0.45, 0.45))
    page = _lay(page, _mask(w, h, ss, texts), (0.06, 0.06, 0.06))
    page = _lay(page, _mask(w, h, ss, circle), (0.86, 0.1, 0.13), 0.92)
    out = _inkjet(page, _paper_white(w, h, 3111), rs)
    _to_img(out).save(os.path.join(IMG, 'plan_etage.png'))


def _hand_path(pts, rng, amp, step=3.0):
    """Rééchantillonne une ligne brisée et la fait trembler doucement (main qui dessine)."""
    pts = np.asarray(pts, np.float64)
    seg = np.hypot(*np.diff(pts, axis=0).T)
    tot = max(seg.sum(), 1e-6)
    n = max(2, int(tot / step))
    cum = np.concatenate([[0], np.cumsum(seg)])
    u = np.linspace(0, tot, n)
    x = np.interp(u, cum, pts[:, 0])
    y = np.interp(u, cum, pts[:, 1])
    k = np.hanning(9)
    k /= k.sum()
    nx = np.convolve([rng.gauss(0, 1) for _ in range(n + 8)], k, mode='same')[4:4 + n]
    ny = np.convolve([rng.gauss(0, 1) for _ in range(n + 8)], k, mode='same')[4:4 + n]
    return list(zip(x + nx * amp * 2.2, y + ny * amp * 2.2))


def _bez(a, c, b, n=40):
    """Courbe de Bézier quadratique de a à b (point de contrôle c)."""
    t = np.linspace(0, 1, n)[:, None]
    a, c, b = (np.asarray(v, np.float64) for v in (a, c, b))
    return list(map(tuple, (1 - t) ** 2 * a + 2 * (1 - t) * t * c + t ** 2 * b))


def _ell(cx, cy, rx, ry, a0=0.0, a1=2 * np.pi, n=60, rot=0.0):
    a = np.linspace(a0, a1, n)
    x, y = rx * np.cos(a), ry * np.sin(a)
    cr, sr = np.cos(rot), np.sin(rot)
    return list(zip(cx + x * cr - y * sr, cy + x * sr + y * cr))


def _hand_text(mask, xy, txt, fnt, angle=0.0, fill=255, shear=0.0):
    """Écrit à la main sur un masque 'L' : texte tourné (degrés) et penché (shear), centré sur xy."""
    x0, y0, x1, y1 = fnt.getbbox(txt)
    pad = int(fnt.size * 0.6)
    tw, th = x1 - x0 + 2 * pad, y1 - y0 + 2 * pad
    tmp = Image.new('L', (tw, th), 0)
    ImageDraw.Draw(tmp).text((pad - x0, pad - y0), txt, font=fnt, fill=fill)
    if shear:
        tmp = tmp.transform((tw + int(abs(shear) * th), th), Image.AFFINE,
                            (1, shear, -abs(shear) * th if shear > 0 else 0, 0, 1, 0), resample=Image.BICUBIC)
    tmp = tmp.rotate(angle, resample=Image.BICUBIC, expand=True)
    bb = tmp.getbbox()
    if bb:
        tmp = tmp.crop(bb)
    px, py = int(xy[0] - tmp.width / 2), int(xy[1] - tmp.height / 2)
    region = mask.crop((px, py, px + tmp.width, py + tmp.height))
    from PIL import ImageChops
    mask.paste(ImageChops.lighter(region, tmp), (px, py))


def _halftone(rgb, pitch, mix, rs):
    """Trame d'impression : CMJN en points ronds sur des grilles tournées (15°, 75°, 0°, 45°)."""
    h, w = rgb.shape[:2]
    k = 1 - rgb.max(-1)
    cmy = (1 - rgb - k[..., None]) / np.maximum(1 - k[..., None], 1e-4)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    out = []
    for ch, ang in ((cmy[..., 0], 15), (cmy[..., 1], 75), (cmy[..., 2], 0), (k, 45)):
        a = np.radians(ang)
        u = (xx * np.cos(a) + yy * np.sin(a)) * 2 * np.pi / pitch
        v = (-xx * np.sin(a) + yy * np.cos(a)) * 2 * np.pi / pitch
        spot = 0.5 - 0.25 * (np.cos(u) + np.cos(v))           # 0 au centre du point, 1 entre les points
        dots = np.clip((ch - spot) * 3.0 + 0.5, 0, 1)
        out.append(ch * (1 - mix) + dots * mix)
    c, m, y, kk = out
    return np.stack([(1 - c) * (1 - kk), (1 - m) * (1 - kk), (1 - y) * (1 - kk)], -1)


def croquis_fractionneur():
    """Page imprimée par l'entité : le croquis de Manon à 16 ans, sur une feuille à petits carreaux,
    au stylo bille bleu. Sèche-cheveux (boîtier, gâchette), boussole (viseur), antenne de la télé
    (émetteur), bobine de cuivre (dedans), reliés par des flèches ; « ? pile ? » barré ; les ondes
    coupées en morceaux. Reproduit et tramé ; en bas, imprimé : Construis-le. Je veux voir. A4, 576 × 816."""
    W, H = 576, 816
    w, h, k = 496, 664, 3                                       # la feuille du cahier, dessinée à 3×
    rng, rs = _rngs(312)
    ink = Image.new('L', (w * k, h * k), 0)
    d = ImageDraw.Draw(ink)

    def pen(pts, width=1.3, amp=0.5, passes=1, val=235):
        for p in range(passes):
            path = _hand_path(pts, rng, amp + 0.25 * p)
            d.line([(x * k, y * k) for x, y in path], fill=val - 25 * p, width=max(1, int(width * k)), joint='curve')

    def arrow(a, c, b, width=1.3):
        pts = _bez(a, c, b)
        pen(pts, width)
        (x0, y0), (x1, y1) = pts[-4], pts[-1]
        ang = np.arctan2(y1 - y0, x1 - x0)
        for s_ in (-1, 1):
            pen([(x1, y1), (x1 - 12 * np.cos(ang + s_ * 0.45), y1 - 12 * np.sin(ang + s_ * 0.45))], width)

    hand = lambda size: font('ReenieBeanie.ttf', int(size * k))

    def write(xy, txt, size, angle=0.0, val=240):
        _hand_text(ink, (xy[0] * k, xy[1] * k), txt, hand(size), angle + rng.uniform(-1.5, 1.5), val)

    # titre, souligné deux fois
    write((214, 50), 'le Fractionneur', 54, 1.5)
    pen([(96, 80), (200, 77), (334, 74)], 1.4, 0.6)
    pen([(110, 88), (220, 85), (322, 83)], 1.2, 0.7)
    write((436, 30), 'nov. 2016', 26, -2)
    # le sèche-cheveux, de profil, la buse vers la droite
    pen([(152, 286), (240, 287), (322, 291)], 1.5, 0.4, 2)           # dessus du corps
    pen([(152, 376), (240, 375), (322, 369)], 1.5, 0.4, 2)           # dessous
    pen(_ell(152, 331, 17, 45), 1.4, 0.4, 2)                          # l'arrière (grille)
    pen(_ell(152, 331, 9, 28), 1.0, 0.3)
    for yy in range(300, 365, 9):
        half = 15 * np.sqrt(max(0, 1 - ((yy - 331) / 45) ** 2))
        pen([(152 - half * 0.9, yy), (152 + half * 0.9, yy)], 0.9, 0.2)
    pen(_ell(322, 330, 8, 39, -np.pi / 2, np.pi / 2, 30), 1.1, 0.3)   # le raccord de la buse
    pen([(322, 291), (388, 306)], 1.4, 0.4, 2)                         # la buse
    pen([(322, 369), (388, 354)], 1.4, 0.4, 2)
    pen(_ell(388, 330, 8, 24), 1.3, 0.3, 2)
    for i in range(16):                                                # ombre au bic sous le corps
        x = 168 + i * 9.5
        pen([(x, 372), (x + 9, 352)], 0.8, 0.25, val=170)
    pen([(206, 375), (188, 488)], 1.5, 0.4, 2)                         # la poignée
    pen([(258, 373), (240, 490)], 1.5, 0.4, 2)
    pen(_ell(214, 489, 26, 13, 0, np.pi, 24), 1.4, 0.4, 2)
    pen([(254, 398), (268, 404), (268, 420), (251, 428)], 1.4, 0.3, 2)  # la gâchette
    cord = [(214, 502)]
    for i in range(1, 36):                                              # le cordon, en boucles
        t = i / 35
        cord.append((214 + 46 * t + 8 * np.sin(t * 13), 502 + 52 * t + 8 * np.cos(t * 13) - 8))
    pen(cord, 1.1, 0.3)
    pen([(256, 548), (274, 541), (280, 555), (262, 562), (256, 548)], 1.2, 0.2)   # la prise
    pen([(277, 545), (288, 541)], 1.1, 0.1)
    pen([(280, 552), (291, 548)], 1.1, 0.1)
    write((86, 424), 'sèche-cheveux', 34, 3)
    write((90, 450), 'de Mamie', 30, 2)
    write((96, 476), '= le boîtier', 28, 1)
    arrow((118, 404), (130, 380), (164, 372))
    write((322, 452), 'gâchette', 30, -6)
    arrow((292, 444), (274, 438), (271, 422))
    # la boussole, en haut à gauche : le viseur, sur le dessus
    pen(_ell(104, 152, 42, 42), 1.5, 0.4, 2)
    pen(_ell(104, 152, 34, 34), 1.0, 0.3)
    for i in range(16):
        a = i * np.pi / 8
        r0 = 28 if i % 4 else 24
        pen([(104 + r0 * np.cos(a), 152 + r0 * np.sin(a)), (104 + 33 * np.cos(a), 152 + 33 * np.sin(a))], 0.8, 0.1)
    pen([(104, 118), (111, 152), (104, 186), (97, 152), (104, 118)], 1.3, 0.2)
    for i in range(6):                                                  # moitié nord noircie
        pen([(99 + i * 2, 124 + i * 4), (101 + i * 2, 150)], 0.9, 0.1)
    write((104, 100), 'N', 26)
    write((106, 222), 'boussole', 34, -2)
    write((110, 248), '= viseur', 30, -2)
    arrow((140, 252), (186, 248), (204, 280))
    # l'antenne de la télé, en haut à droite : l'émetteur, au bout
    pen(_ell(410, 186, 30, 17, np.pi, 2 * np.pi, 24), 1.4, 0.3, 2)
    pen([(380, 186), (440, 186)], 1.4, 0.3)
    for (x0, y0, x1, y1) in ((402, 172, 346, 66), (418, 172, 470, 60)):
        pen([(x0, y0), (x1, y1)], 1.5, 0.3, 2)
        for t in (0.35, 0.65):                                          # les tubes qui coulissent
            mx, my = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            nx, ny = -(y1 - y0), (x1 - x0)
            nn = np.hypot(nx, ny)
            pen([(mx - nx / nn * 4, my - ny / nn * 4), (mx + nx / nn * 4, my + ny / nn * 4)], 1.0, 0.1)
        pen(_ell(x1, y1, 5, 5), 1.2, 0.1)
    write((412, 214), 'antenne (télé)', 32, 2)
    write((416, 240), '= émetteur', 30, 1)
    arrow((404, 256), (412, 282), (392, 302))
    # la bobine, en bas à droite : dans la buse
    pen([(372, 432), (452, 432)], 1.4, 0.3)
    pen([(372, 478), (452, 478)], 1.4, 0.3)
    pen(_ell(372, 455, 7, 23), 1.2, 0.2)
    pen(_ell(452, 455, 7, 23), 1.2, 0.2)
    for i in range(13):
        x = 376 + i * 6
        pen([(x, 478), (x + 5, 432)], 1.0, 0.15)
    pen([(452, 438), (468, 426), (480, 432), (474, 444)], 1.0, 0.3)
    pen([(452, 472), (470, 486), (482, 478)], 1.0, 0.3)
    write((404, 508), 'bobine de cuivre', 31, -1)
    arrow((372, 426), (352, 380), (358, 340))
    write((424, 390), 'dedans !', 30, -4)
    # « ? pile ? », barré
    write((352, 566), '? pile ?', 42, -3)
    pen([(306, 569), (350, 563), (396, 565)], 1.3, 0.4)
    pen([(308, 575), (352, 570), (398, 571)], 1.3, 0.4)
    # les ondes, coupées en morceaux
    write((132, 578), 'son signal = des ondes', 31, 1)
    xs = np.linspace(28, 112, 40)
    pen(list(zip(xs, 610 + 11 * np.sin((xs - 28) / 84 * 4 * np.pi))), 1.2, 0.2)
    arrow((118, 610), (130, 608), (146, 610))
    for j in range(4):
        xs = np.linspace(156 + j * 24, 172 + j * 24, 10)
        pen(list(zip(xs, 610 + rng.uniform(-6, 6) + 11 * np.sin((xs - 156) / 84 * 4 * np.pi))), 1.2, 0.2)
    write((200, 640), 'en morceaux, il ne tient plus', 27, 0)

    m = np.asarray(ink.resize((w, h), Image.BOX)).astype(np.float32) / 255.0
    # la feuille à petits carreaux (5 mm), marge rouge, papier un peu crème
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    grid = ((np.abs(((xx - 6) % 14.5) - 7.25) > 6.75) | (np.abs(((yy - 4) % 14.5) - 7.25) > 6.75)).astype(np.float32)
    sheet = np.array([0.97, 0.96, 0.92]) * (0.97 + 0.03 * fbm_tile(1024, 2.0, 3121)[:h, :w])[..., None]
    sheet = _lay(sheet, grid * 0.55, (0.58, 0.68, 0.84))
    sheet = _lay(sheet, (np.abs(xx - 30) < 0.8).astype(np.float32) * 0.8, (0.86, 0.38, 0.4))
    pressure = 0.82 + 0.18 * fbm_tile(1024, 1.6, 3122)[:h, :w]
    sheet = _lay(sheet, m * pressure, (0.11, 0.15, 0.5))
    # la feuille posée de travers sur la page, une ombre légère à son bord (la vitre du scanner)
    page = np.ones((H, W, 3), np.float32)
    sh = Image.new('L', (W, H), 0)
    sheet_img = _to_img(sheet).rotate(-1.1, resample=Image.BICUBIC, expand=True, fillcolor=(255, 255, 255))
    alpha = Image.new('L', (w, h), 255).rotate(-1.1, resample=Image.BICUBIC, expand=True)
    px, py = (W - sheet_img.width) // 2, 40
    sh.paste(alpha, (px + 3, py + 4))
    shadow = _gblur(np.asarray(sh).astype(np.float32) / 255.0, 3.0)
    page *= 1 - 0.22 * shadow[..., None]
    full = _to_img(page)
    full.paste(sheet_img, (px, py), alpha)
    page = _to_arr(full)
    page = _halftone(page, 2.8, 0.55, rs)
    txt = _mask(W, H, 3, lambda dd, kk: dd.text((W * kk / 2, 762 * kk), 'Construis-le. Je veux voir.',
                                                 font=font('IBMPlexMono-Regular.ttf', int(19 * kk)), fill=255, anchor='mm'))
    page = _lay(page, txt, (0.05, 0.05, 0.05))
    out = _inkjet(page, _paper_white(W, H, 3123), rs, bands=0.8)
    _to_img(out).save(os.path.join(IMG, 'croquis_fractionneur.png'))


def _corridor_render(W, H, rs):
    """Lancer de rayons du couloir vu par la caméra dôme (CAM 1, en (4.0, 2.52, -7.18), vers +z) :
    infrarouge de la caméra, et le rond d'une lampe de poche sur le sol, sans personne pour la tenir.
    Rend la luminance (h, w) avant réglages de la caméra. Positions : docs/v0.3.md § 5.2."""
    cam = np.array([4.0, 2.42, -7.06])
    pitch = np.radians(-17.0)
    fwd = np.array([0, np.sin(pitch), np.cos(pitch)])
    up = np.array([0, np.cos(pitch), -np.sin(pitch)])
    right = np.array([-1.0, 0, 0])
    th = np.tan(np.radians(31.0))                              # 62° (l'impression est recadrée)
    jj, ii = np.mgrid[0:H, 0:W].astype(np.float64)
    sx = (2 * (ii + 0.5) / W - 1) * (W / H) * th
    sy = (1 - 2 * (jj + 0.5) / H) * th
    r2 = (sx ** 2 + sy ** 2) / (th * th * 3.2)
    sx, sy = sx * (1 + 0.1 * r2), sy * (1 + 0.1 * r2)          # grand angle d'un dôme : un peu de barillet
    dirs = fwd[None, None] + sx[..., None] * right[None, None] + sy[..., None] * up[None, None]
    dirs /= np.linalg.norm(dirs, axis=-1, keepdims=True)
    dx, dy, dz = dirs[..., 0], dirs[..., 1], dirs[..., 2]
    eps = 1e-9
    # la boîte du couloir, vue de l'intérieur
    tx = np.where(dx > 0, (4.7 - cam[0]) / np.maximum(dx, eps), (3.3 - cam[0]) / np.minimum(dx, -eps))
    ty = np.where(dy > 0, (2.6 - cam[1]) / np.maximum(dy, eps), (0.0 - cam[1]) / np.minimum(dy, -eps))
    tz = np.where(dz > 0, (6.3 - cam[2]) / np.maximum(dz, eps), (-7.3 - cam[2]) / np.minimum(dz, -eps))
    t = np.minimum(np.minimum(tx, ty), tz)
    surf = np.where(t == tx, np.where(dx > 0, 1, 0), np.where(t == ty, np.where(dy > 0, 3, 2), 4))
    normal = np.zeros(dirs.shape)
    normal[surf == 0] = (1, 0, 0)
    normal[surf == 1] = (-1, 0, 0)
    normal[surf == 2] = (0, 1, 0)
    normal[surf == 3] = (0, -1, 0)
    normal[surf == 4] = (0, 0, -1)
    alb = np.zeros(t.shape)
    emit = np.zeros(t.shape)
    # les meubles : (x0, x1, y0, y1, z0, z1, albédo, émission)
    boxes = [(3.3, 3.76, 0.0, 0.74, -1.4, -0.6, 0.42, 0), (3.3, 3.74, 0.66, 0.74, -1.42, -0.58, 0.5, 0),
             (3.47, 3.57, 0.74, 0.9, -1.05, -0.95, 0.25, 0), (3.47, 3.57, 0.84, 0.865, -1.05, -0.95, 0.3, 2.2),
             (3.45, 3.6, 0.74, 0.79, -0.86, -0.72, 0.3, 0), (4.58, 4.66, 0.15, 0.75, -3.4, -2.4, 0.6, 0),
             (4.2, 4.5, 0.0, 0.34, 5.8, 6.1, 0.35, 0), (3.85, 4.15, 2.53, 2.6, -5.15, -4.85, 0.5, 0),
             (3.85, 4.15, 2.53, 2.6, -0.65, -0.35, 0.5, 0), (3.85, 4.15, 2.53, 2.6, 3.85, 4.15, 0.5, 0),
             (3.94, 4.06, 2.56, 2.6, 2.14, 2.26, 0.8, 0)]
    for zc in (-5.6, -2.0, 0.2, 5.2):
        boxes.append((3.3, 3.325, 1.38, 1.84, zc - 0.2, zc + 0.2, 0.18, 0))
    for zc in (-6.3, 2.6, 5.6):
        boxes.append((4.675, 4.7, 1.38, 1.84, zc - 0.2, zc + 0.2, 0.18, 0))
    hit_box = np.full(t.shape, -1)
    for bi, (x0, x1, y0, y1, z0, z1, a, e) in enumerate(boxes):
        lo = np.stack([(x0 - cam[0]) / np.where(np.abs(dx) < eps, eps, dx), (y0 - cam[1]) / np.where(np.abs(dy) < eps, eps, dy),
                       (z0 - cam[2]) / np.where(np.abs(dz) < eps, eps, dz)], -1)
        hi = np.stack([(x1 - cam[0]) / np.where(np.abs(dx) < eps, eps, dx), (y1 - cam[1]) / np.where(np.abs(dy) < eps, eps, dy),
                       (z1 - cam[2]) / np.where(np.abs(dz) < eps, eps, dz)], -1)
        tmin = np.minimum(lo, hi)
        tn = tmin.max(-1)
        tf = np.maximum(lo, hi).min(-1)
        ok = (tn <= tf) & (tn > 0) & (tn < t)
        ax = tmin.argmax(-1)
        t = np.where(ok, tn, t)
        hit_box = np.where(ok, bi, hit_box)
        for axis in range(3):
            sel = ok & (ax == axis)
            n = np.zeros(3)
            n[axis] = 1
            normal[sel] = -np.sign(dirs[sel][:, axis])[:, None] * n
        alb = np.where(ok, a, alb)
        emit = np.where(ok, e, emit)
    hit = cam[None, None] + dirs * t[..., None]
    X, Y, Z = hit[..., 0], hit[..., 1], hit[..., 2]
    base = hit_box < 0
    for bi in range(11, len(boxes)):                                     # les cadres : la photo dans la baguette
        zc = (boxes[bi][4] + boxes[bi][5]) / 2
        inner = (hit_box == bi) & (np.abs(Z - zc) < 0.165) & (np.abs(Y - 1.61) < 0.195)
        alb = np.where(hit_box == bi, np.where(inner, 0.3 + 0.12 * np.sin(Z * 40 + zc) * np.sin(Y * 23), 0.55), alb)
    # sol : parquet en lames le long du couloir, tapis élimé au milieu
    fl = base & (surf == 2)
    plank = np.floor((X - 3.3) / 0.11)
    plank_tone = 0.5 + 0.08 * np.sin(plank * 12.9898 + np.floor(Z / 1.3 + plank * 0.37) * 78.233)
    seam = (((X - 3.3) / 0.11) % 1 < 0.06)
    rug = (np.abs(X - 4.0) < 0.4) & (np.abs(Z + 0.5) < 6.0)
    rug_border = rug & ((np.abs(X - 4.0) > 0.32) | (np.abs(Z + 0.5) > 5.92))
    floor_alb = np.where(rug, np.where(rug_border, 0.42, 0.3), plank_tone * np.where(seam, 0.7, 1.0))
    wear = np.exp(-((X - 4.0) / 0.18) ** 2) * rug * 0.08                  # usé au milieu
    cable = ((np.abs(X - 3.34) < 0.008) & (Z > 1.0) & (Z < 4.15)) | ((np.abs(Z - 4.15) < 0.008) & (X > 3.34) & (X < 4.66))
    alb = np.where(fl, np.where(cable, 0.95, floor_alb + wear), alb)
    # murs : papier peint à rayures, cimaise, plinthe ; portes et leurs chambranles
    wl = base & (surf <= 1)
    stripe = 0.52 + 0.035 * (np.sin(Z * 2 * np.pi / 0.15) > 0.3)
    wall_alb = np.where(Y < 0.1, 0.7, np.where(np.abs(Y - 0.92) < 0.025, 0.72, np.where(Y < 0.92, 0.4, stripe)))
    doors = {0: [1.40, -3.60, 3.40], 1: [-4.60, -1.20, 1.35, 4.40]}           # 0 : mur x = 3.3 ; 1 : mur x = 4.7
    for side, cs in doors.items():
        on = wl & (surf == side)
        for c in cs:
            inside = on & (np.abs(Z - c) < 0.43) & (Y < 2.04)
            casing = on & (np.abs(Z - c) < 0.5) & (Y < 2.11) & ~inside
            leaf = 0.62 + 0.05 * ((np.abs(Z - c) < 0.32) & (np.abs(Y - 1.45) < 0.45)) - 0.05 * ((np.abs(Z - c) < 0.32) & (np.abs(Y - 0.55) < 0.35))
            if side == 1 and c == 1.35:                                         # P6 vitrée : l'escalier noir derrière
                glass = inside & (np.abs(Z - c) < 0.3) & (Y > 0.95) & (Y < 1.92)
                leaf = np.where(glass, 0.06 + 0.05 * np.sin(Z * 61) * np.sin(Y * 47), leaf)
            if side == 1 and c == -4.60:                                        # P4 entrouverte : une fente noire
                leaf = np.where(Z > c + 0.43 - 0.13, 0.015, leaf * 0.82)
            wall_alb = np.where(inside, leaf, np.where(casing, 0.74, wall_alb))
    alb = np.where(wl, wall_alb, alb)
    # plafond, et le mur du fond avec la fenêtre F8 (la rue, un peu de lumière)
    alb = np.where(base & (surf == 3), 0.62, alb)
    end = base & (surf == 4)
    win = end & (np.abs(X - 4.0) < 0.35) & (Y > 0.95) & (Y < 2.2)
    frame = win & ((np.abs(X - 4.0) < 0.025) | (np.abs(Y - 1.6) < 0.025) | (np.abs(X - 4.0) > 0.31) | (Y < 0.99) | (Y > 2.16))
    alb = np.where(end, np.where(win, np.where(frame, 0.55, 0.04), stripe), alb)
    emit = np.where(win & ~frame, 0.035 + 0.025 * np.clip(Y - 0.95, 0, 1), emit)
    # la plante sous la fenêtre : une masse de feuilles sombres devant la vitre
    pc = np.array([4.35, 0.75, 5.92])
    oc = cam - pc
    b = (dirs * oc).sum(-1)
    disc = b * b - ((oc * oc).sum() - 0.36 ** 2)
    tp = -b - np.sqrt(np.maximum(disc, 0))
    leaves = (disc > 0) & (tp > 0) & (tp < t)
    hp = cam + dirs * tp[..., None]
    leafy = np.sin(hp[..., 0] * 41) * np.sin(hp[..., 1] * 37) * np.sin(hp[..., 2] * 43) > -0.3
    leaves &= leafy
    t = np.where(leaves, tp, t)
    alb = np.where(leaves, 0.22, alb)
    emit = np.where(leaves, 0, emit)
    normal[leaves] = (0, 0, -1)
    hit = cam[None, None] + dirs * t[..., None]
    # éclairage : projecteur infrarouge de la caméra
    lc = np.array([4.0, 2.38, -7.0])
    L = lc - hit
    dist = np.linalg.norm(L, axis=-1)
    L /= dist[..., None]
    ndl = np.clip((normal * L).sum(-1), 0, 1)
    axis_cos = np.clip(-(L * fwd).sum(-1), 0, 1)
    E = 7.0 * ndl / (dist ** 2 + 1.5) * (0.2 + 0.8 * axis_cos ** 5)
    # la lampe de poche : tenue à hauteur de poitrine près de la porte de Mamie, braquée sur le sol
    lp = np.array([4.12, 1.32, -3.5])
    tgt = np.array([4.12, 0.0, -1.85])
    ax_ = (tgt - lp) / np.linalg.norm(tgt - lp)
    L2 = lp - hit
    d2 = np.linalg.norm(L2, axis=-1)
    L2 /= d2[..., None]
    ang = np.degrees(np.arccos(np.clip(-(L2 * ax_).sum(-1), -1, 1)))
    cone = np.clip((19 - ang) / 7, 0, 1) ** 2 * (0.75 + 0.25 * np.clip((8 - ang) / 4, 0, 1))
    cone += 0.05 * np.clip((34 - ang) / 15, 0, 1)
    ring = 0.12 * np.exp(-((ang - 15.5) / 1.3) ** 2)                    # l'anneau du réflecteur
    E2 = 26.0 * np.clip((normal * L2).sum(-1), 0, 1) / (d2 ** 2 + 0.05) * (cone + ring)
    lum = alb * (E + E2 + 0.012) + emit
    return lum


def photo_couloir():
    """Page imprimée par l'entité : deux images de la caméra du couloir (CAM 1), infrarouge, noir et
    blanc. En haut, tout le couloir, vide ; en bas, le zoom numérique sur le rond de ta lampe, par terre
    devant la console, et personne pour la tenir. Horodatage « CAM 1 · 03:27 ». A4, 576 × 816."""
    W, H = 576, 816
    _rng, rs = _rngs(313)
    pw, ph = 528, 297
    hr = _corridor_render(pw * 2, ph * 2, rs)

    def camera(lum, gain, noise, rs_):
        v = 1 - np.exp(-lum * gain)
        v = v + 0.55 * _gblur(np.clip(v - 0.7, 0, 1), 6.0) + 0.25 * _gblur(np.clip(v - 0.55, 0, 1), 18.0)
        v = _gblur(v, 0.6)
        v = v + rs_.randn(*v.shape) * noise * (0.6 + 0.8 * (1 - v))
        h_, w_ = v.shape
        yy, xx = np.mgrid[0:h_, 0:w_] / np.array([h_, w_])[:, None, None]
        v *= 1 - 0.45 * ((xx - 0.5) ** 2 + (yy - 0.5) ** 2) * 2.2       # vignettage de l'objectif
        bh, bw = h_ // 8 * 8, w_ // 8 * 8                                  # compression : blocs de 8 × 8
        blk = v[:bh, :bw].reshape(bh // 8, 8, bw // 8, 8).mean((1, 3))
        v[:bh, :bw] = 0.88 * v[:bh, :bw] + 0.12 * np.repeat(np.repeat(blk, 8, 0), 8, 1)
        return np.clip(0.03 + v * 0.95, 0, 1)

    full = camera(np.asarray(Image.fromarray(hr.astype(np.float32), 'F').resize((pw, ph), Image.BOX)), 1.8, 0.03, rs)
    # le zoom : le capteur ne voit que 176 × 110 points autour du rond ; agrandi trois fois, flou et granuleux
    cy, cx = np.unravel_index(np.argmax(_gblur(hr, 6.0)), hr.shape)
    zw, zh = 176 * 2, 110 * 2
    x0 = int(np.clip(cx - zw * 0.5, 0, hr.shape[1] - zw))
    y0 = int(np.clip(cy - zh * 0.42, 0, hr.shape[0] - zh))
    crop = Image.fromarray(hr[y0:y0 + zh, x0:x0 + zw].astype(np.float32), 'F').resize((176, 110), Image.BOX)
    zoom = camera(np.asarray(crop), 1.8, 0.035, rs)
    zoom = np.asarray(Image.fromarray((zoom * 255).astype(np.uint8)).resize((528, 330), Image.BILINEAR)).astype(np.float32) / 255

    def osd(img, lines_):
        """Incrustations de la caméra : texte blanc cerné de noir."""
        im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
        d = ImageDraw.Draw(im)
        f = font('VT323-Regular.ttf', 22)
        for (x, y, txt, anc) in lines_:
            for ox, oy in ((-1, 0), (1, 0), (0, -1), (0, 1), (1, 1)):
                d.text((x + ox, y + oy), txt, font=f, fill=10, anchor=anc)
            d.text((x, y), txt, font=f, fill=232, anchor=anc)
        return np.asarray(im).astype(np.float32) / 255

    full = osd(full, [(12, 8, 'CAM 1 · ' + FLOOR_TIME, 'la'), (516, 8, 'IR', 'ra'), (12, 289, '01/11/2040', 'ld'),
                      (516, 289, 'COULOIR', 'rd')])
    zoom = osd(zoom, [(12, 8, 'CAM 1 · ' + FLOOR_TIME, 'la'), (516, 8, 'ZOOM ×3', 'ra')])
    page = np.ones((H, W, 3), np.float32)
    gray = lambda a: np.repeat(a[..., None], 3, -1) * np.array([0.97, 1.0, 0.98])  # le noir composite tire un peu au vert
    page[64:64 + ph, 24:24 + pw] = gray(full)
    page[388:388 + 330, 24:24 + pw] = gray(zoom)
    txt = _mask(W, H, 3, lambda d, k: (
        d.text((24 * k, 40 * k), 'CONSOLE DOMOTIQUE · CAM 1 COULOIR', font=font('IBMPlexMono-Regular.ttf', int(11 * k)), fill=255, anchor='lm'),
        d.text((W * k - 24 * k, 40 * k), 'IMAGES 1 ET 2', font=font('IBMPlexMono-Regular.ttf', int(11 * k)), fill=255, anchor='rm'),
        d.text((24 * k, 374 * k), '1', font=font('IBMPlexMono-Bold.ttf', int(10 * k)), fill=255, anchor='lm'),
        d.text((24 * k, 730 * k), '2', font=font('IBMPlexMono-Bold.ttf', int(10 * k)), fill=255, anchor='lm'),
        d.line([(24 * k, 772 * k), (W * k - 24 * k, 772 * k)], fill=255, width=2),
        d.text((W * k - 24 * k, 786 * k), '1/1', font=font('IBMPlexMono-Regular.ttf', int(9 * k)), fill=255, anchor='rm')))
    page = _lay(page, txt, (0.06, 0.06, 0.06))
    out = _inkjet(page, _paper_white(W, H, 3131), rs, density=0.86, bands=0.35, grain=0.08, dead=0.008)
    _to_img(out).save(os.path.join(IMG, 'photo_couloir.png'))


def silhouette_feed():
    """La silhouette du flux du miroir (couche « flux uniquement ») : une forme humaine plate et sombre,
    cheveux mouillés qui pendent devant la tête (pas de visage), bras trop longs, chemise de nuit
    collée. 128 × 256, RGBA, pixelisée par blocs de 4. Dessinée pour un quad de 0,55 × 1,75 m :
    l'image est étirée en largeur pour que la forme ait les bonnes proportions sur ce quad."""
    W, H = 128, 256
    _rng, rs = _rngs(314)
    qw, qh = 0.55, 1.75
    ss = 4

    def P(x, y, k):                                            # mètres (x centré, y depuis le sol) -> pixels
        return ((x + qw / 2) / qw * W * k, (qh - y) / qh * H * k)

    def body(d, k):
        poly = lambda pts: d.polygon([P(x, y, k) for x, y in pts], fill=255)

        def limb(a, b, r0, r1):
            (ax_, ay_), (bx_, by_) = a, b
            nx, ny = -(by_ - ay_), (bx_ - ax_)
            nn = np.hypot(nx, ny)
            nx, ny = nx / nn, ny / nn
            poly([(ax_ - nx * r0, ay_ - ny * r0), (ax_ + nx * r0, ay_ + ny * r0),
                  (bx_ + nx * r1, by_ + ny * r1), (bx_ - nx * r1, by_ - ny * r1)])

        # la tête, penchée sur l'épaule gauche ; les cheveux mouillés pendent devant, en mèches
        hx, hy = 0.03, 1.585
        poly(_ell(hx, hy, 0.072, 0.104, rot=np.radians(-13), n=32))
        hair = [(hx - 0.085, hy + 0.03), (hx - 0.05, hy + 0.1), (hx + 0.05, hy + 0.1), (hx + 0.088, hy + 0.02),
                (hx + 0.082, 1.36)]
        for i, yl in enumerate([1.27, 1.31, 1.22, 1.25, 1.19, 1.28, 1.24]):     # bouts des mèches
            x = hx + 0.075 - i * 0.152 / 6
            hair += [(x + 0.008, yl + 0.04), (x, yl)]
        hair += [(hx - 0.09, 1.38)]
        poly(hair)
        # épaules tombantes, la gauche plus basse ; chemise de nuit collée, ourlet mouillé, déchiré
        poly([(-0.06, 1.47), (-0.13, 1.43), (-0.185, 1.37), (-0.19, 1.3), (-0.16, 1.16), (-0.13, 1.0),
              (-0.145, 0.86), (-0.16, 0.66), (-0.175, 0.47), (-0.13, 0.44), (-0.11, 0.49), (-0.07, 0.43),
              (-0.02, 0.47), (0.03, 0.42), (0.08, 0.47), (0.12, 0.44), (0.165, 0.48), (0.155, 0.68),
              (0.14, 0.87), (0.125, 1.0), (0.15, 1.17), (0.18, 1.33), (0.17, 1.41), (0.12, 1.46), (0.07, 1.49)])
        # les bras, trop longs, un peu écartés du corps : les mains pendent sous les genoux
        for sh, el, wr, tip in (((-0.165, 1.36), (-0.225, 0.98), (-0.245, 0.58), (-0.25, 0.36)),
                                ((0.16, 1.39), (0.215, 1.0), (0.23, 0.6), (0.24, 0.38))):
            limb(sh, el, 0.042, 0.03)
            limb(el, wr, 0.031, 0.022)
            poly(_ell(el[0], el[1], 0.031, 0.031, n=16))
            sx_ = 1 if wr[0] > 0 else -1
            poly([(wr[0] - 0.028, wr[1] + 0.01), (wr[0] + 0.028, wr[1] + 0.01), (tip[0] + 0.02 * sx_, tip[1] + 0.06),
                  (tip[0] + 0.008, tip[1]), (tip[0] - 0.012, tip[1] + 0.01), (tip[0] - 0.024, tip[1] + 0.07)])
        # jambes maigres, genoux un peu rentrés, pieds nus
        for sgn in (-1, 1):
            limb((sgn * 0.075, 0.5), (sgn * 0.05, 0.27), 0.04, 0.03)
            limb((sgn * 0.05, 0.27), (sgn * 0.07, 0.04), 0.03, 0.022)
            poly(_ell(sgn * 0.05, 0.27, 0.03, 0.03, n=16))
            poly([(sgn * 0.045, 0.06), (sgn * 0.095, 0.06), (sgn * 0.115, 0.0), (sgn * 0.035, 0.0)])

    big = Image.new('L', (W * ss, H * ss), 0)
    body(ImageDraw.Draw(big), ss)
    cov = np.asarray(big).astype(np.float32) / 255.0
    # pixelisée : la caméra du miroir ne la voit qu'en blocs de 4 × 4
    b = 4 * ss
    blocks = cov.reshape(H * ss // b, b, W * ss // b, b).mean((1, 3))
    alpha = np.clip((blocks - 0.18) / 0.5, 0, 1)
    alpha = np.round(alpha * 4) / 4                              # quelques niveaux seulement
    hh, ww = alpha.shape
    alpha[-1] = np.maximum(alpha[-1], alpha[-2])                 # les pieds touchent le sol
    shade = 0.035 + 0.03 * rs.rand(hh, ww)                       # noir, presque uniforme
    sheen = np.zeros((hh, ww))                                   # reflet mouillé, très faible, en haut
    sheen[:hh // 3] = 0.03 * rs.rand(hh // 3, ww)
    rgb = np.stack([shade + sheen * 0.8, shade + sheen * 0.9, shade + sheen + 0.006], -1)
    rgb = np.repeat(np.repeat(rgb, 4, 0), 4, 1)
    alpha = np.repeat(np.repeat(alpha, 4, 0), 4, 1)
    out = np.dstack([np.clip(rgb, 0, 1) * 255, alpha * 255]).astype(np.uint8)
    Image.fromarray(out, 'RGBA').save(os.path.join(IMG, 'silhouette_feed.png'))


def _emboss(m, depth=1.0):
    """Relief d'une gravure à partir de son masque : (ombre en haut à gauche, lumière en bas à droite)."""
    sh = np.clip(m - np.roll(np.roll(m, 1, 0), 1, 1), 0, 1)
    hl = np.clip(m - np.roll(np.roll(m, -1, 0), -1, 1), 0, 1)
    return sh * depth, hl * depth


def clovis_plaque():
    """La plaque du socle de Clovis : laiton gravé, huit ans dehors (patine brune, vert-de-gris qui
    coule des vis et des lettres), « CLOVIS — 2032 » et une file d'empreintes de vélociraptor
    gravées par Albert. Quatre vis rouillées. 512 × 192 (pour une plaque d'environ 0,32 × 0,12 m)."""
    w, h, ss = 512, 192, 3
    rng, rs = _rngs(316)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    patina = fbm_tile(512, 2.2, 3161)[:h, :w]
    fine = fbm_tile(512, 0.8, 3162)[:h, :w]
    brass = np.array([0.6, 0.47, 0.25])
    brown = np.array([0.3, 0.22, 0.13])
    k = np.clip(0.35 + 0.6 * patina + 0.1 * fine, 0, 1)[..., None]
    arr = brass * (1 - k) + brown * k
    tl = np.clip(1 - np.minimum(xx, yy) / 7, 0, 1)
    br = np.clip(1 - np.minimum(w - 1 - xx, h - 1 - yy) / 7, 0, 1)
    arr = arr * (1 + 0.35 * tl[..., None] - 0.4 * br[..., None])
    # la gravure : texte et empreintes, sur un masque
    eng = Image.new('L', (w * ss, h * ss), 0)
    d = ImageDraw.Draw(eng)
    f = font('IBMPlexMono-Bold.ttf', 56 * ss)
    txt = 'CLOVIS — 2032'
    adv = f.getlength(txt)
    x = (w * ss - adv) / 2
    for ch in txt:                                                      # lettre par lettre, gravées à la main
        d.text((x, 84 * ss + rng.uniform(-1.5, 1.5) * ss), ch, font=f, fill=255, anchor='lm')
        x += f.getlength(ch) + rng.uniform(-0.6, 0.6) * ss
    d.line([(64 * ss, 122 * ss), (w * ss - 64 * ss, 122 * ss)], fill=255, width=2 * ss)
    for i in range(7):                                                  # la piste : sept empreintes à trois doigts
        cx = 86 + i * 57
        cy = 154 + (6 if i % 2 else -6)
        for a, ln in ((-0.62, 13), (0.0, 17), (0.62, 13)):             # les doigts vers la droite : il avance
            ex, ey = cx + ln * np.cos(a), cy + ln * np.sin(a)
            d.line([(cx * ss, cy * ss), (ex * ss, ey * ss)], fill=255, width=int(4.2 * ss))
            d.ellipse([(ex - 2.2) * ss, (ey - 2.2) * ss, (ex + 2.2) * ss, (ey + 2.2) * ss], fill=255)
            d.line([(ex * ss, ey * ss), ((ex + 4 * np.cos(a)) * ss, (ey + 4 * np.sin(a)) * ss)], fill=255, width=int(1.6 * ss))
        d.ellipse([(cx - 7) * ss, (cy - 5) * ss, (cx + 3) * ss, (cy + 5) * ss], fill=255)
    m = np.asarray(eng.resize((w, h), Image.BOX)).astype(np.float32) / 255.0
    shadow, hilite = _emboss(m)
    paint = np.clip((fbm_tile(512, 1.2, 3163)[:h, :w] - 0.3) * 3, 0, 1)   # la peinture noire qui reste au fond
    inside = brown * 0.55 * (1 - paint[..., None]) + np.array([0.05, 0.045, 0.04]) * paint[..., None]
    arr = _lay(arr, m, inside)
    arr = arr * (1 - 0.45 * shadow[..., None]) + 0.3 * hilite[..., None] * brass
    # quatre vis à tête bombée, rouillées
    screws = [(20, 20), (w - 21, 20), (20, h - 21), (w - 21, h - 21)]
    for (sx, sy) in screws:
        rr = np.hypot(xx - sx, yy - sy)
        head = np.clip(8.5 - rr, 0, 1)
        dome = np.clip(1 - rr / 8.5, 0, 1)
        col = np.array([0.36, 0.3, 0.24]) * (0.7 + 0.6 * dome[..., None]) * (1 - 0.3 * ((xx - sx + yy - sy) > 0))[..., None]
        arr = _lay(arr, head, np.array([0.0, 0.0, 0.0]))
        arr = arr + head[..., None] * col
        a = rng.uniform(0, np.pi)
        slot = (np.abs((xx - sx) * np.sin(a) - (yy - sy) * np.cos(a)) < 1.0) & (rr < 7)
        arr = np.where(slot[..., None], arr * 0.35, arr)
        arr = _lay(arr, np.clip(1.2 - np.abs(rr - 9.5), 0, 1) * 0.6, np.array([0.08, 0.06, 0.04]))   # le trou fraisé
    # coulures : vert-de-gris sous les vis et les lettres, eau de pluie
    drip_src = np.zeros((h, w), np.float32)
    for (sx, sy) in screws:
        drip_src[sy + 6:sy + 9, sx - 4:sx + 5] = 1
    drip_src = np.maximum(drip_src, m * 0.6)
    streak = np.zeros_like(drip_src)
    acc = np.zeros(w, np.float32)
    jitter = 0.9 + 0.1 * rs.rand(w)
    for y in range(h):                                                   # ce qui coule descend et s'efface
        acc = np.maximum(acc * 0.975 * jitter, drip_src[y])
        streak[y] = acc
    streak = _gblur(streak, 1.2) * (0.6 + 0.6 * fbm_tile(512, 1.0, 3164)[:h, :w])
    verdigris = np.array([0.32, 0.52, 0.44])
    arr = _lay(arr, np.clip(streak * 0.75, 0, 0.8) * (1 - m), verdigris)
    vg = np.clip((fbm_tile(512, 1.6, 3165)[:h, :w] - 0.6) * 4, 0, 1) * (0.4 + 0.6 * (yy / h))
    arr = _lay(arr, vg * 0.7, verdigris * 0.9)
    arr = _lay(arr, np.clip(m * 1.2, 0, 1) * np.clip((fbm_tile(512, 1.0, 3166)[:h, :w] - 0.45) * 3, 0, 1), verdigris * 0.8)
    dirt = np.clip((yy - h * 0.7) / (h * 0.3), 0, 1) * (0.5 + 0.5 * patina)   # la terre qui remonte, en bas
    arr *= (1 - 0.35 * dirt)[..., None]
    _to_img(arr).save(os.path.join(IMG, 'clovis_plaque.png'))


def _seg7(d, k, x, y, h, txt, fill=255):
    """Chiffres à sept segments (dateur d'un appareil photo compact) : x, y = coin haut gauche, h = hauteur."""
    segs = {'0': 'abcdef', '1': 'bc', '2': 'abdeg', '3': 'abcdg', '4': 'bcfg', '5': 'acdfg', '6': 'acdefg',
            '7': 'abc', '8': 'abcdefg', '9': 'abcdfg'}
    ends = {'a': (0, 0, 1, 0), 'b': (1, 0, 1, 0.5), 'c': (1, 0.5, 1, 1), 'd': (0, 1, 1, 1),
            'e': (0, 0.5, 0, 1), 'f': (0, 0, 0, 0.5), 'g': (0, 0.5, 1, 0.5)}
    w, t, sl = h * 0.5, h * 0.12, h * 0.08                            # largeur, épaisseur, pente
    for ch in txt:
        if ch == "'":
            d.polygon([((x + sl + t) * k, y * k), ((x + sl + 2 * t) * k, y * k), ((x + t) * k, (y + 2.5 * t) * k)], fill=fill)
            x += 3.2 * t
        elif ch == ' ':
            x += w * 0.8
        else:
            for s in segs[ch]:
                x0, y0, x1, y1 = ends[s]
                a = ((x + x0 * w + sl * (1 - y0)) * k, (y + y0 * h) * k)
                b = ((x + x1 * w + sl * (1 - y1)) * k, (y + y1 * h) * k)
                d.line([a, b], fill=fill, width=max(1, int(t * k)))
            x += w * 1.5


def portrait_1996():
    """Le portrait du couloir : Mamie et Papi en 1996, un soir d'été, au flash d'un appareil compact.
    Tirage agrandi et surexposé : les visages et les mains sont brûlés en blanc, sans aucun trait ;
    les deux corps se lisent comme des silhouettes claires sur le fond sombre de la salle à manger,
    avec l'ombre dure du flash sur le mur. Elle rit la tête en arrière, la main devant la bouche ; il
    rit penché vers elle, le bras autour de ses épaules ; leurs têtes ont bougé pendant la pose (un
    léger fantôme). Dateur orange « '96 8 15 ». Couleurs passées d'un vieux tirage.
    384 × 512, pour le quad de 0,6 × 0,8 m du couloir."""
    w, h, ss = 384, 512, 3
    rng, rs = _rngs(320)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)

    def M(*fns):                                                   # masque lissé d'une ou plusieurs formes
        return _mask(w, h, ss, lambda d, k: [fn(d, k) for fn in fns])

    def P(pts):                                                    # un polygone
        return lambda d, k: d.polygon([(x * k, y * k) for x, y in pts], fill=255)

    def O(cx, cy, rx, ry, rot=0.0):                                # une ellipse tournée (degrés)
        return P(_ell(cx, cy, rx, ry, rot=np.radians(rot), n=48))

    def L(pts, width):                                             # un trait épais
        return lambda d, k: d.line([(x * k, y * k) for x, y in pts], fill=255, width=int(width * k), joint='curve')

    def fluffy(m, amount, seed, beta=0.6, rough=1.2):
        """Bord irrégulier (cheveux, laine) : le masque flou, seuillé à travers du bruit."""
        n = fbm_tile(512, beta, seed)[:h, :w]
        return np.clip((_gblur(m, amount) - 0.5 + (n - 0.5) * rough) * 5 + 0.5, 0, 1)

    def round_(m, sigma, lo=0.4):
        """Modelé : le flash, dans l'axe, éclaire moins les bords d'une forme ronde."""
        b = np.clip((_gblur(m, sigma) - 0.5) * 2, 0, 1) ** 0.6
        return (lo + (1 - lo) * b)[..., None]

    skin = np.array([0.98, 0.76, 0.64])
    flash = 1.3
    hx, hy = 118, 194                                              # la tête de Mamie
    px, py = 270, 148                                              # la tête de Papi
    # --- les formes
    p_arm = M(L(_bez((222, 262), (150, 236), (62, 270), 30), 24))  # son bras à lui, derrière elle
    p_body = fluffy(M(P([(250, 204), (222, 212), (204, 230), (196, 262), (190, 330), (186, 512), (384, 512), (384, 264),
                        (366, 236), (330, 218), (292, 205)])), 1.0, 3204, 0.2, 0.5)
    p_shirt = M(P([(244, 204), (296, 203), (284, 250), (266, 338), (262, 344), (256, 338), (240, 252)]))
    p_collar = M(P([(250, 200), (268, 214), (256, 238), (240, 214)]), P([(290, 200), (272, 214), (284, 236), (298, 214)]))
    p_placket = M(L([(262, 344), (258, 512)], 3), *[O(260 - 0.25 * (yb - 344), yb, 3, 3) for yb in (362, 404, 446, 488)])
    p_neck = M(P([(252, 172), (288, 174), (292, 212), (248, 212)]))
    p_ears = M(O(px - 35, py + 6, 6, 11, 12), O(px + 33, py + 16, 6, 11, 12))
    p_face = M(O(px, py, 34, 44, 12))
    # la couronne de cheveux gris autour du crâne dégarni : tout le reste est caché par le visage
    p_hair = fluffy(M(O(px - 2, py + 5, 41, 46, 12)), 1.4, 3208, 0.3, 0.8) * (1 - M(O(px + 4, py - 24, 34, 30, 12)))
    m_body = M(P(_bez((104, 250), (66, 260), (40, 292), 14) + [(30, 340), (26, 512), (240, 512), (236, 400), (230, 330)]
                 + _bez((222, 300), (206, 266), (146, 252), 14)))
    m_collar = M(P([(100, 248), (122, 262), (98, 300), (76, 272)]), P([(146, 248), (124, 262), (150, 298), (170, 268)]))
    m_seams = M(L([(62, 320), (58, 512)], 3), L([(204, 318), (210, 400)], 3))       # les bras le long du corps
    m_neck = M(P([(102, 222), (138, 220), (146, 258), (98, 260)]))
    m_hair = fluffy(M(O(hx - 8, hy - 24, 50, 44, -18), O(hx - 40, hy + 8, 18, 24, 0)), 5.0, 3207, 0.4, 1.6)
    m_face = M(O(hx + 6, hy + 4, 31, 38, -24))
    m_arm = M(L([(214, 404), (186, 340), (140, 246)], 30))       # son bras replié, la main devant la bouche
    m_hand = M(O(134, 234, 14, 18, 25))
    m_crease = M(L([(228, 402), (198, 344), (156, 262)], 2))      # le pli sous l'avant-bras
    p_hand = M(O(66, 270, 18, 12, -16))                            # la main de Papi sur son épaule
    people = np.clip(p_arm + p_body + p_neck + p_face + p_hair + m_body + m_hair + m_face, 0, 1)

    # --- le fond : la salle à manger, à peine touchée par le flash
    fall = np.exp(-(((xx - 190) / 210) ** 2 + ((yy - 220) / 240) ** 2))
    stripes = 0.88 + 0.12 * (np.sin(xx * 2 * np.pi / 19 + 0.3 * np.sin(yy * 0.05)) > 0.35)
    paper = (0.85 + 0.15 * fbm_tile(512, 1.3, 3201)[:h, :w]) * stripes
    E = np.array([0.6, 0.47, 0.32]) * (paper * (0.07 + 0.22 * fall))[..., None]
    E = _lay(E, M(P([(0, 0), (30, 0), (24, 512), (0, 512)])), np.array([0.035, 0.025, 0.02]))   # un chambranle
    E = _lay(E, M(P([(26, 0), (31, 0), (25, 512), (20, 512)])), np.array([0.09, 0.07, 0.05]))
    E = _lay(E, M(P([(306, 46), (384, 44), (384, 176), (304, 178)])), np.array([0.05, 0.045, 0.045]))  # une gravure
    E = _lay(E, M(P([(306, 46), (384, 44), (384, 50), (306, 52)])), np.array([0.16, 0.12, 0.06]))
    glint = M(O(345, 98, 7, 6))                                     # la vitre renvoie le flash
    E += (_gblur(glint, 1.4)[..., None] * np.array([3.0, 2.9, 2.6]) + _gblur(glint, 9.0)[..., None] * 0.22)
    # l'ombre dure du flash (un peu au-dessus et à droite de l'objectif) : en bas à gauche, sur le mur
    shadow = _gblur(np.roll(np.roll(people, 9, 0), -11, 1), 2.0)
    E *= (1 - 0.8 * shadow)[..., None]

    # --- les corps : rayonnement = albédo × flash, modelé par le flash dans l'axe
    wool = (0.85 + 0.3 * fbm_tile(512, 0.5, 3202)[:h, :w])[..., None]
    cardigan = np.array([0.2, 0.13, 0.08]) * flash * wool
    E = _lay(E, p_arm, cardigan * 1.1 * round_(p_arm, 6))
    E = _lay(E, p_body, cardigan * round_(p_body, 22, 0.55))
    E = _lay(E, p_shirt, np.array([0.78, 0.84, 0.92]) * flash * round_(p_shirt, 6, 0.6))
    E = _lay(E, p_collar, np.array([0.8, 0.86, 0.94]) * flash * 1.2 * round_(p_collar, 3, 0.6))
    E = _lay(E, p_placket, np.array([0.1, 0.07, 0.05]) * flash, 0.8)
    E = _lay(E, p_neck, skin * flash * 1.6 * round_(p_neck, 6, 0.5) * (0.35 + 0.65 * np.clip((yy - 186) / 22, 0, 1))[..., None])
    folds = (0.86 + 0.14 * np.sin(xx * 0.08 + 9 * fbm_tile(512, 1.6, 3205)[:h, :w]))[..., None]
    motif = (fbm_tile(512, 0.3, 3206)[:h, :w] > 0.62)[..., None]
    blouse = np.where(motif, np.array([0.8, 0.5, 0.52]), np.array([0.84, 0.8, 0.74])) * flash
    E = _lay(E, m_body, blouse * folds * round_(m_body, 24, 0.5))
    E = _lay(E, m_seams, np.array([0.12, 0.1, 0.09]) * flash, 0.7)
    E = _lay(E, m_neck, skin * flash * 1.6 * round_(m_neck, 6, 0.55))
    E *= (1 - 0.45 * np.clip(np.roll(m_collar, 3, 0) - m_collar, 0, 1))[..., None]        # l'ombre sous le col
    E = _lay(E, m_collar, blouse * round_(m_collar, 2, 0.5))
    E = _lay(E, p_hand, skin * flash * 2.2 * round_(p_hand, 4, 0.6))
    # --- les têtes : d'abord le fantôme (elles ont bougé), puis l'image nette du flash
    ghost = np.roll(np.maximum(m_hair, m_face), 8, 1) * 0.3 * (1 - m_hair)
    E = _lay(E, ghost, np.array([0.5, 0.3, 0.22]) * flash)
    ghost = np.roll(np.maximum(p_face, p_hair), -7, 1) * 0.3 * (1 - p_face)
    E = _lay(E, ghost, skin * flash)
    curls = (0.6 + 0.8 * fbm_tile(512, 0.1, 3209)[:h, :w])[..., None]
    E = _lay(E, m_hair, np.array([0.36, 0.15, 0.08]) * flash * curls * round_(m_hair, 10, 0.5))
    E = _lay(E, m_face, skin * flash * 2.8 * round_(m_face, 8, 0.4))
    E = _lay(E, p_ears, skin * flash * 1.4 * round_(p_ears, 3, 0.5))
    E = _lay(E, p_hair, np.array([0.42, 0.41, 0.39]) * flash * curls * round_(p_hair, 4, 0.5))
    E = _lay(E, p_face, skin * flash * 2.8 * round_(p_face, 9, 0.4))
    E = _lay(E, m_arm, blouse * 1.05 * round_(m_arm, 7, 0.7))
    E = _lay(E, m_crease, np.array([0.25, 0.2, 0.18]) * flash, 0.5)
    E = _lay(E, m_hand, skin * flash * 2.6 * round_(m_hand, 4, 0.5))

    # --- le film : deux diaphragmes de trop, les blancs bavent (halo rouge), grain
    v = 1 - np.exp(-E * 3.0)
    bright = np.clip(v - 0.78, 0, 1)
    v = v + _gblur(bright, 3.0) * np.array([0.55, 0.38, 0.3]) + _gblur(bright, 14.0) * np.array([0.3, 0.17, 0.12])
    v = _gblur(v, 0.9)                                             # objectif de compact, agrandissement
    g = _gblur(rs.randn(h, w), 0.7)
    v = np.clip(v + (g * 0.05)[..., None] * (0.35 + 0.65 * (1 - v.mean(-1, keepdims=True))), 0, 1)
    # --- le tirage, des années après : le cyan s'en va, les noirs remontent, les coins s'assombrissent
    v = v * np.array([1.0, 0.92, 0.78]) + np.array([0.08, 0.055, 0.06])
    v *= (1 - 0.25 * (((xx - w / 2) / (w * 0.6)) ** 2 + ((yy - h / 2) / (h * 0.6)) ** 2))[..., None]
    # le dateur, en bas à droite : orange, qui bave dans l'émulsion
    stamp = M(lambda d, k: _seg7(d, k, 268, 480, 15, "'96 8 15"))
    v = v + _gblur(stamp, 1.8)[..., None] * np.array([0.55, 0.22, 0.02]) + stamp[..., None] * np.array([0.5, 0.3, 0.06])
    _grime_local(_to_img(np.clip(v, 0, 1)), 0.18, rng).save(os.path.join(IMG, 'portrait_1996.png'))


# ---------------------------------------------------------------- sons de l'étage

def _save_wav(name, x, peak=0.89):
    """Normalise à la crête voulue (toujours sous 0,95) et écrit un WAV mono 16 bits 44,1 kHz."""
    x = np.asarray(x, np.float64)
    assert np.all(np.isfinite(x)), name
    write_wav(name, x / (np.max(np.abs(x)) + 1e-12) * min(peak, 0.94), RATE)


def _fftconv(x, ir):
    """Convolution (non circulaire) par FFT, tronquée à la longueur de x."""
    n = 1 << int(np.ceil(np.log2(len(x) + len(ir))))
    return np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)[:len(x)]


def _fades(x, a=0.004, b=0.03):
    """Petits fondus d'entrée et de sortie (en secondes) : pas de clic aux extrémités d'un son ponctuel."""
    x = x.copy()
    na, nb = int(RATE * a), int(RATE * b)
    if na:
        x[:na] *= np.linspace(0, 1, na) ** 2
    if nb:
        x[-nb:] *= np.linspace(1, 0, nb) ** 2
    return x


def _verb(x, seconds, seed, mix, bright=4500.0, predelay=0.006):
    """Réverbération d'une pièce, par convolution : une queue de bruit qui décroît, les aigus plus vite
    que les graves. Le filtre est appliqué au bruit avant l'enveloppe : la réponse ne se replie pas sur
    elle-même (pas d'écho parasite à la fin de la queue). Rend un son de même longueur que x."""
    rs = np.random.RandomState(seed)
    m = int(RATE * seconds)
    t = np.arange(m) / RATE
    lo = _spec_filter(rs.randn(m), lambda f: _butter(f, bright, 2))
    hi = _spec_filter(rs.randn(m), lambda f: _butter(f, bright, 2, high=True))
    ir = (lo * np.exp(-t * 6.9 / seconds) + hi * np.exp(-t * 6.9 / (seconds * 0.4))) * np.clip(t / 0.003, 0, 1)
    ir = np.concatenate([np.zeros(int(RATE * predelay)), ir])
    wet = _fftconv(x, ir)
    wet *= np.sqrt(np.mean(x ** 2) / (np.mean(wet ** 2) + 1e-18))
    return x * (1 - mix) + wet * mix


def _modes(t, parts):
    """Somme de modes amortis : parts = [(fréquence, amplitude, décroissance en s)], t >= 0."""
    tt = np.maximum(t, 0)
    return sum(a * np.sin(2 * np.pi * f * tt) * np.exp(-tt / dec) for f, a, dec in parts) * (t >= 0)


def _line_band(x, lo=300, hi=3400):
    """Une ligne téléphonique, ou un petit haut-parleur : bande étroite."""
    return _spec_filter(x, lambda f: _butter(f, hi, 4) * _butter(f, lo, 3, high=True))


def modem_chant():
    """Le chant d'un modem 56k, par le haut-parleur de l'ordinateur de Manon (~8 s) : décroché, tonalité
    française à 440 Hz, numérotation DTMF, sonnerie, tonalité de réponse à 2100 Hz (inversions de phase),
    échanges V.21 (les « di-di-di »), sondage de ligne (« bong »), puis le souffle des données ; le
    haut-parleur se coupe net."""
    sec = 8.0
    n = int(RATE * sec)
    t = np.arange(n) / RATE
    rng, rs = _rngs(321)
    out = np.zeros(n)

    def seg(a, b, ramp=0.004):
        e = np.clip((t - a) / ramp, 0, 1) * np.clip((b - t) / ramp, 0, 1)
        return e

    # le relais qui décroche
    out += _modes(t - 0.02, [(180, 0.5, 0.012), (1300, 0.3, 0.004)]) + rs.randn(n) * np.exp(-np.maximum(t - 0.02, 0) / 0.003) * (t > 0.02) * 0.4
    out += 0.28 * np.sin(2 * np.pi * 440 * t) * seg(0.14, 1.02, 0.01)           # tonalité
    rows = {'1': 697, '2': 697, '3': 697, '4': 770, '5': 770, '6': 770, '7': 852, '8': 852, '9': 852, '0': 941}
    cols = {'1': 1209, '2': 1336, '3': 1477, '4': 1209, '5': 1336, '6': 1477, '7': 1209, '8': 1336, '9': 1477, '0': 1336}
    for i, dg in enumerate('0836031231'):
        a = 1.12 + i * 0.118 + rng.uniform(-0.006, 0.006)
        e = seg(a, a + 0.072, 0.003)
        out += 0.22 * e * (np.sin(2 * np.pi * rows[dg] * t) + 0.9 * np.sin(2 * np.pi * cols[dg] * t))
    out += _modes(t - 2.33, [(220, 0.25, 0.01)])                                # le central commute
    out += 0.16 * np.sin(2 * np.pi * 440 * t) * seg(2.42, 2.92, 0.01)           # retour d'appel, coupé
    out += _modes(t - 2.95, [(160, 0.35, 0.01), (900, 0.2, 0.004)])             # on décroche en face
    # ANSam : 2100 Hz, phase inversée toutes les 450 ms, modulé à 15 Hz
    ph = np.pi * np.floor(np.maximum(t - 3.05, 0) / 0.45)
    ans = np.sin(2 * np.pi * 2100 * t + ph) * (1 + 0.2 * np.sin(2 * np.pi * 15 * t))
    out += 0.3 * ans * seg(3.05, 4.15, 0.01)

    def fsk(a, b, f_mark, f_space, baud, seed):
        r = np.random.RandomState(seed)
        nb = int((b - a) * baud) + 2
        bits = r.randint(0, 2, nb)
        idx = np.clip(((t - a) * baud).astype(int), 0, nb - 1)
        f = np.where(bits[idx] == 1, f_mark, f_space)
        return np.sin(2 * np.pi * np.cumsum(f) / RATE) * seg(a, b, 0.006)

    out += 0.22 * fsk(4.2, 4.72, 980, 1180, 300, 3211)                         # V.8 : l'appelant
    out += 0.22 * fsk(4.3, 4.78, 1650, 1850, 300, 3212)                        # l'appelé
    # sondage de ligne : deux « bong », peigne de fréquences multiples de 150 Hz
    probe = sum(np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) for f in range(150, 3800, 150) if f not in (900, 1200, 1800, 2400))
    probe /= np.max(np.abs(probe))
    out += 0.3 * probe * (seg(4.86, 5.02, 0.006) + seg(5.1, 5.3, 0.006))
    out += 0.22 * np.sin(2 * np.pi * 1200 * t) * seg(5.02, 5.1, 0.004)
    # entraînement et données : souffle brouillé, qui change trois fois de grain
    data = _line_band(rs.randn(n), 250, 3600)
    data /= np.max(np.abs(data))
    pulse = 1 + 0.35 * np.sign(np.sin(2 * np.pi * 23 * t)) * seg(6.05, 6.55, 0.01)
    shimmer = _spec_filter(rs.randn(n), lambda f: np.exp(-0.5 * ((f - 1800) / 600) ** 2))
    shimmer /= np.max(np.abs(shimmer))
    out += 0.26 * shimmer * seg(5.35, 6.05, 0.02) * (1 + 0.5 * np.sin(2 * np.pi * 7 * t))
    out += 0.3 * data * pulse * seg(5.95, 7.62, 0.02) * (0.85 + 0.15 * np.sin(2 * np.pi * 1.3 * t))
    out += _modes(t - 7.63, [(240, 0.2, 0.008)])                               # le haut-parleur se coupe
    out += rs.randn(n) * 0.006 * seg(0.0, 7.62, 0.01)                           # le souffle de la ligne
    # la ligne puis le petit haut-parleur du PC : bande étroite, un peu de saturation, une résonance
    out = _line_band(out, 280, 3500)
    out = np.tanh(out * 2.2) / 2.2
    out = _spec_filter(out, lambda f: (1 + 0.8 * np.exp(-0.5 * ((f - 1900) / 450) ** 2)) * _butter(f, 220, 2, high=True)
                       * _butter(f, 4800, 3))
    out = _verb(out, 0.6, 3213, 0.12)
    _save_wav('modem_chant.wav', _fades(out, 0.002, 0.05), 0.88)


def hum_move():
    """Le bourdonnement de l'entité qui traverse les murs : secteur 50 Hz et ses harmoniques, grésillement
    d'arc, battements lents. 3 s, en boucle (toutes les fréquences sont des multiples de 1/3 Hz)."""
    sec = 3
    n = RATE * sec
    t = np.arange(n) / RATE
    out = np.zeros(n)
    for h_, a in ((1, 0.55), (2, 1.0), (3, 0.7), (4, 0.45), (5, 0.38), (6, 0.3), (7, 0.22), (8, 0.16), (9, 0.14),
                  (10, 0.1), (12, 0.08), (14, 0.06), (17, 0.05), (21, 0.04), (26, 0.03), (33, 0.025)):
        wob = 1 + 0.15 * np.sin(2 * np.pi * (h_ % 3 + 1) / sec * t + h_)      # chaque harmonique respire à son rythme
        out += a * wob * np.sin(2 * np.pi * 50 * h_ * t + h_ * 0.7)
    buzz = np.sign(np.sin(2 * np.pi * 100 * t)) * np.abs(np.sin(2 * np.pi * 100 * t)) ** 0.3   # le grésillement
    out += 0.25 * _spec_filter(buzz, lambda f: _butter(f, 4000, 2) * _butter(f, 400, 2, high=True))
    crackle = _band_noise(n, 1500, 7000, 3221)
    gate = np.clip(np.sin(2 * np.pi * 50 * t) * 6 - 5, 0, 1) * (0.5 + 0.5 * np.sin(2 * np.pi * 2 / sec * t))
    out += 0.35 * crackle * gate
    out *= 0.8 + 0.2 * np.sin(2 * np.pi * 1 / sec * t)
    out = _spec_filter(out, lambda f: _butter(f, 35, 2, high=True))
    _save_wav('hum_move.wav', out, 0.8)


def chirp(i):
    """Bips de données sous les phrases de l'entité : ~0,3 s, sauts de fréquence rapides, un peu crénelés."""
    seeds = {1: 3231, 2: 3232, 3: 3233, 4: 3234}
    rng, _rs = _rngs(seeds[i])
    dur = [0.28, 0.32, 0.24, 0.34][i - 1]
    n = int(RATE * dur)
    t = np.arange(n) / RATE
    freqs = [[1200, 2400, 1800, 3000], [900, 1350, 2700, 2025], [1600, 3200, 2400, 800], [1100, 2200, 3300, 1650]][i - 1]
    f = np.zeros(n)
    pos = 0
    while pos < n:
        ln = int(RATE * rng.uniform(0.008, 0.026))
        f[pos:pos + ln] = rng.choice(freqs) * (1 + 0.02 * rng.uniform(-1, 1))
        pos += ln
    if i == 2:                                                       # une variante qui glisse vers le haut
        f = f * (1 + 0.6 * t / dur)
    if i == 4:
        f[int(n * 0.55):] = 3300 - 2400 * (t[int(n * 0.55):] - t[int(n * 0.55)]) / (dur * 0.45)
    ph = 2 * np.pi * np.cumsum(f) / RATE
    x = np.sign(np.sin(ph)) * 0.45 + np.sin(ph) * 0.55               # carré adouci
    gate = np.ones(n)
    for _ in range(rng.randint(2, 5)):                                # de courts silences entre les paquets
        a = int(n * rng.uniform(0.15, 0.85))
        gate[a:a + int(RATE * rng.uniform(0.01, 0.025))] = 0
    gate = np.convolve(gate, np.ones(60) / 60, mode='same')
    x *= gate
    x = np.round(x * 12) / 12                                        # crénelé (peu de bits)
    x = _spec_filter(x, lambda fr: _butter(fr, 6500, 3) * _butter(fr, 500, 2, high=True))
    env = np.minimum(1, t / 0.006) * np.minimum(1, (dur - t) / 0.02)
    _save_wav(f'chirp_{i}.wav', x * env, 0.8)


def chirps():
    for i in range(1, 5):
        chirp(i)


def babyphone_breath():
    """Le babyphone de la chambre d'amis : une respiration lente, trop près du micro, derrière le souffle
    de la liaison radio (petit haut-parleur, bande étroite, crachotements). 10 s, deux respirations, boucle."""
    sec = 10
    n = RATE * sec
    t = np.arange(n) / RATE
    breath = np.zeros(n)
    for i, (t0, din, dout, amp) in enumerate([(0.6, 2.0, 2.6, 1.0), (5.55, 1.9, 2.8, 0.92)]):
        env, _, _ = _seg_env(t, t0, din, lambda u: np.sin(np.pi * u ** 0.75) ** 1.4, sec)
        breath += _band_noise(n, 500, 3200, 3241 + i, tilt=-0.1) * env * amp * 0.7
        env2, u2, _ = _seg_env(t, t0 + din + 0.15, dout, lambda u: (1 - np.exp(-u * 6)) * (1 - u) ** 1.5, sec)
        breath += _band_noise(n, 200, 1400, 3243 + i) * env2 * amp
        breath += _band_noise(n, 90, 300, 3245 + i) * env2 * amp * 0.5 * np.exp(-u2 * 3)   # le souffle sur le micro
    hiss = _band_noise(n, 400, 5000, 3247)
    squelch = 0.75 + 0.25 * np.sin(2 * np.pi * 3 / sec * t) * np.sin(2 * np.pi * 7 / sec * t + 1)
    rs = np.random.RandomState(3248)
    pops = np.zeros(n)                                                # crachotements numériques, placés en boucle
    for _ in range(22):
        i0 = rs.randint(0, n)
        ln = rs.randint(40, 400)
        idx = (i0 + np.arange(ln)) % n
        pops[idx] += rs.randn(ln) * np.hanning(ln) * rs.uniform(0.3, 1.0)
    pops = _spec_filter(pops, lambda f: _butter(f, 1200, 2, high=True))
    hum = 0.05 * np.sin(2 * np.pi * 50 * t) + 0.03 * np.sin(2 * np.pi * 150 * t)
    out = breath * 1.0 + hiss * 0.32 * squelch + pops * 0.25 + hum
    out = _spec_filter(out, lambda f: _butter(f, 3800, 4) * _butter(f, 280, 3, high=True)
                       * (1 + 0.7 * np.exp(-0.5 * ((f - 1500) / 350) ** 2)))
    out = np.tanh(out / np.max(np.abs(out)) * 1.6)
    out = _spec_filter(out, lambda f: _butter(f, 4500, 3))
    _save_wav('babyphone_breath.wav', out, 0.75)


def pipe_knock():
    """Un coup sur un tuyau de chauffage, à la cave, entendu par le radiateur du couloir : impact métallique,
    modes d'un tube d'acier (1 : 2,76 : 5,40 : 8,93), corps du radiateur, lointain et réverbéré. 1,6 s."""
    sec = 1.4
    n = int(RATE * sec)
    t = np.arange(n) / RATE
    _rng, rs = _rngs(325)
    f0 = 410.0
    ring = _modes(t - 0.01, [(f0, 1.0, 0.28), (f0 * 2.76, 0.7, 0.18), (f0 * 5.4, 0.45, 0.1), (f0 * 8.93, 0.25, 0.06),
                              (f0 * 1.013, 0.5, 0.32)])                      # deux modes voisins : un battement
    body = _modes(t - 0.012, [(232, 0.7, 0.15), (148, 0.5, 0.2), (610, 0.3, 0.08)])
    click = rs.randn(n) * np.exp(-np.maximum(t - 0.01, 0) / 0.0015) * (t >= 0.01)
    click = _spec_filter(click, lambda f: _butter(f, 1500, 2, high=True))
    out = ring * 0.6 + body * 0.8 + click * 0.5
    # loin, à travers la maison : passe-bas, et la réverbération du sous-sol et des tuyaux
    out = _spec_filter(out, lambda f: _butter(f, 2600, 2) * _butter(f, 90, 2, high=True))
    out = _verb(out, 1.2, 3251, 0.4)
    _save_wav('pipe_knock.wav', _fades(out, 0.0, 0.08), 0.85)


def _stepper(t, rate_fn, res, seed):
    """Moteur pas à pas : un train d'impulsions (cadence variable) qui excite quelques résonances."""
    rs = np.random.RandomState(seed)
    n = len(t)
    ph = np.cumsum(rate_fn) / RATE
    steps = np.diff(np.floor(ph), prepend=0) > 0
    imp = steps * (0.8 + 0.4 * rs.rand(n))
    m = int(RATE * 0.03)
    tt = np.arange(m) / RATE
    ir = sum(a * np.sin(2 * np.pi * f * tt) * np.exp(-tt / d) for f, a, d in res)
    return _fftconv(imp, ir)


def printer():
    """L'imprimante jet d'encre du bureau (~5 s) : réveil et calage du chariot, prise de la feuille,
    quatre passages du chariot entrecoupés d'avances papier (moteur pas à pas), éjection."""
    sec = 5.0
    n = int(RATE * sec)
    t = np.arange(n) / RATE
    _rng, rs = _rngs(326)
    out = np.zeros(n)

    def win(a, b, ra=0.02, rb=0.02):
        return np.clip((t - a) / ra, 0, 1) * np.clip((b - t) / rb, 0, 1)

    def carriage(a, b, f, direction):
        e = win(a, b, 0.05, 0.05)
        prog = np.clip((t - a) / (b - a), 0, 1)
        near = 0.75 + 0.25 * np.sin(np.pi * (prog if direction > 0 else 1 - prog)) ** 2
        ph = 2 * np.pi * np.cumsum(f * (1 + 0.01 * np.sin(2 * np.pi * 9 * t))) / RATE
        whine = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph)
        belt = _spec_filter(rs.randn(n), lambda fr: np.exp(-0.5 * ((fr - 2600) / 900) ** 2)) * 6
        rattle = 1 + 0.5 * np.sin(2 * np.pi * 37 * t) ** 8
        return (whine * 0.2 + belt * 0.12 * rattle) * e * near

    # réveil : le chariot va se caler, petit choc
    out += carriage(0.05, 0.5, 950, 1)
    out += _modes(t - 0.52, [(320, 0.6, 0.02), (1900, 0.3, 0.006)])
    # prise du papier : le rouleau, le frottement, l'engagement
    feed = _stepper(t, np.where((t > 0.7) & (t < 1.3), 520, 0), [(1150, 1, 0.004), (2600, 0.6, 0.002), (300, 0.5, 0.006)], 3261)
    out += feed * 0.5
    paper = _spec_filter(rs.randn(n), lambda fr: _butter(fr, 2500, 2, high=True) * _butter(fr, 9000, 2)) * 3
    out += paper * win(0.85, 1.3, 0.05, 0.05) * 0.15
    out += _modes(t - 1.28, [(240, 0.6, 0.025), (1500, 0.2, 0.006)])
    # impression : quatre allers-retours du chariot, avance de ligne entre chaque
    lf_rate = np.zeros(n)
    for k in range(4):
        a = 1.4 + k * 0.72
        out += carriage(a, a + 0.55, 1350 + (40 if k % 2 else 0), 1 if k % 2 == 0 else -1)
        lf_rate += np.where((t > a + 0.57) & (t < a + 0.7), 640, 0)
    out += _stepper(t, lf_rate, [(1300, 1, 0.003), (2900, 0.5, 0.002), (420, 0.4, 0.005)], 3262) * 0.45
    # éjection : longue avance rapide, la feuille glisse, petit claquement
    out += _stepper(t, np.where((t > 4.3) & (t < 4.82), 900, 0), [(1250, 1, 0.003), (2700, 0.6, 0.002), (360, 0.5, 0.005)], 3263) * 0.5
    out += paper * win(4.35, 4.85, 0.05, 0.1) * 0.2
    out += _modes(t - 4.86, [(260, 0.5, 0.02), (2100, 0.2, 0.005)])
    out += _spec_filter(rs.randn(n), lambda fr: _butter(fr, 300, 2)) * 0.02     # le ventilateur, à peine
    out = _spec_filter(out, lambda fr: _butter(fr, 80, 2, high=True) * _butter(fr, 11000, 2))
    out = _verb(out, 0.5, 3264, 0.15)
    _save_wav('printer.wav', _fades(out, 0.004, 0.08), 0.85)


def fans_spinup():
    """Les ventilateurs du PC du bureau qui démarrent (~3 s) : le relais, l'alimentation, deux
    ventilateurs qui montent à fond (souffle et fréquence des pales), puis se calment un peu."""
    sec = 3.0
    n = int(RATE * sec)
    t = np.arange(n) / RATE
    _rng, rs = _rngs(327)
    out = _modes(t - 0.03, [(90, 0.8, 0.03), (1500, 0.3, 0.004)])          # le relais de l'alimentation
    out += rs.randn(n) * np.exp(-np.maximum(t - 0.03, 0) / 0.004) * (t > 0.03) * 0.3
    for k, (top, rest, blades, seed) in enumerate(((2900, 1700, 7, 3271), (1900, 1100, 9, 3272), (2400, 1300, 11, 3273))):
        start = 0.08 + 0.05 * k
        up = 1 - np.exp(-np.maximum(t - start, 0) / (0.45 + 0.1 * k))
        down = np.clip((t - 1.9) / 0.6, 0, 1)
        rpm = (top * up) * (1 - down) + (top * up + (rest - top) * up) * down
        rpm *= t > start
        bpf = rpm / 60 * blades
        ph = 2 * np.pi * np.cumsum(bpf) / RATE
        tone = np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)
        level = (rpm / 2900) ** 2
        noise = _band_noise(n, 300 + 600 * k, 5000 + 1000 * k, seed)
        motor = np.sin(2 * np.pi * np.cumsum(rpm / 60 * 4 * 6) / RATE) * 0.05   # le petit sifflement du moteur
        out += (tone * 0.18 + noise * 0.9 + motor) * level * (0.7 + 0.15 * k)
    out = _spec_filter(out, lambda f: _butter(f, 60, 2, high=True) * _butter(f, 9000, 2) * _butter(f, 3500, 1))
    out = _verb(out, 0.4, 3274, 0.12)
    _save_wav('fans_spinup.wav', _fades(out, 0.002, 0.3), 0.85)


def servo():
    """Le petit moteur de la caméra dôme qui tourne (~0,6 s) : déclic, moteur à engrenages qui siffle,
    arrêt et jeu des pignons."""
    sec = 0.62
    n = int(RATE * sec)
    t = np.arange(n) / RATE
    _rng, _rs = _rngs(328)
    run = np.clip((t - 0.03) / 0.035, 0, 1) * np.clip((0.5 - t) / 0.06, 0, 1)
    speed = run * (1 + 0.04 * np.sin(2 * np.pi * 13 * t))
    f = 1750 * (0.6 + 0.4 * speed)
    ph = 2 * np.pi * np.cumsum(f) / RATE
    whine = (np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.3 * np.sin(3.02 * ph)) * speed
    gears = _stepper(t, 340 * speed, [(3100, 1, 0.0015), (5200, 0.6, 0.001), (900, 0.4, 0.003)], 3281) * 0.9
    out = whine * 0.25 + gears
    out += _modes(t - 0.02, [(2400, 0.4, 0.004), (700, 0.3, 0.006)])
    out += _modes(t - 0.505, [(2200, 0.45, 0.004), (600, 0.3, 0.008)])
    out += _modes(t - 0.528, [(2500, 0.2, 0.003)])
    out = _spec_filter(out, lambda fr: _butter(fr, 300, 2, high=True) * _butter(fr, 9000, 2))
    out = _verb(out, 0.5, 3282, 0.12)
    _save_wav('servo.wav', _fades(out, 0.002, 0.04), 0.8)


def curtain_rings():
    """Le rideau de douche qu'on ouvre, derrière soi (~1,4 s) : les anneaux de métal qui glissent et
    s'entrechoquent sur la tringle, le plastique qui froisse ; salle de bain carrelée."""
    sec = 1.4
    n = int(RATE * sec)
    t = np.arange(n) / RATE
    rng, rs = _rngs(329)
    move = np.clip(t / 0.08, 0, 1) * np.clip((0.95 - t) / 0.25, 0, 1)       # vitesse de la main
    scrape = _spec_filter(rs.randn(n), lambda f: _butter(f, 2200, 2, high=True) * _butter(f, 9500, 2))
    scrape *= move * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 11 * t)))
    clinks = np.zeros(n)
    tt = 0.04
    for k in range(14):                                                  # les anneaux se rattrapent, s'entassent
        tt += rng.uniform(0.035, 0.07) * (1 + 0.6 * k / 14)
        if tt > 1.05:
            break
        f1 = rng.uniform(2800, 3600)
        clinks += _modes(t - tt, [(f1, 1, 0.03), (f1 * 1.47, 0.6, 0.02), (f1 * 2.13, 0.4, 0.012), (f1 * 0.52, 0.3, 0.02)]) * rng.uniform(0.4, 1.0)
        if rng.random() < 0.4:                                           # un anneau qui en heurte un autre
            clinks += _modes(t - tt - rng.uniform(0.008, 0.02), [(f1 * 1.2, 0.5, 0.015), (f1 * 1.9, 0.3, 0.01)])
    crinkle = _spec_filter(rs.randn(n) * (rs.rand(n) < 0.08), lambda f: _butter(f, 1800, 2, high=True))
    swish = _spec_filter(rs.randn(n), lambda f: _butter(f, 500, 2, high=True) * _butter(f, 5000, 2))
    plastic = (crinkle * 0.7 + swish * 0.35) * np.clip(t / 0.12, 0, 1) * np.clip((1.15 - t) / 0.3, 0, 1)
    out = scrape * 0.18 + clinks * 0.22 + plastic * 0.3
    out = _verb(out, 0.7, 3291, 0.3)
    _save_wav('curtain_rings.wav', _fades(out, 0.002, 0.1), 0.82)


def drip():
    """Une goutte qui tombe dans le seau de la chambre d'amis (~0,8 s) : petit impact, la bulle qui chante
    en montant, le seau qui résonne à peine ; une pièce feutrée."""
    sec = 0.8
    n = int(RATE * sec)
    t = np.arange(n) / RATE
    _rng, rs = _rngs(330)
    t0 = 0.01
    tt = np.maximum(t - t0, 0)
    f = 1050 * (1 + 0.9 * (1 - np.exp(-tt / 0.012)))                      # la bulle monte
    bubble = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-tt / 0.028) * (t >= t0)
    tt2 = np.maximum(t - 0.052, 0)
    f2 = 1500 * (1 + 0.5 * (1 - np.exp(-tt2 / 0.01)))
    bubble2 = np.sin(2 * np.pi * np.cumsum(f2) / RATE) * np.exp(-tt2 / 0.018) * (t >= 0.052) * 0.3
    click = rs.randn(n) * np.exp(-tt / 0.0008) * (t >= t0)
    bucket = _modes(t - t0, [(380, 0.25, 0.05), (720, 0.12, 0.03)])
    out = bubble + bubble2 + click * 0.25 + bucket
    out = _spec_filter(out, lambda fr: _butter(fr, 150, 2, high=True) * _butter(fr, 8000, 2))
    out = _verb(out, 0.45, 3301, 0.2)
    _save_wav('drip.wav', _fades(out, 0.0, 0.1), 0.8)


def wet_step(i):
    """Un pas mouillé, pied nu, sur le carrelage de la salle de bain (~0,5 s) : le talon qui claque,
    la plante, la peau qui se décolle du carreau mouillé, un peu d'eau."""
    rng, rs = _rngs(331 + i)
    sec = 0.55
    n = int(RATE * sec)
    t = np.arange(n) / RATE
    heel_t = 0.012
    ball_t = heel_t + rng.uniform(0.055, 0.085)
    peel_t = ball_t + rng.uniform(0.09, 0.13)

    def slap(t0, amp, bright):
        tt = np.maximum(t - t0, 0)
        x = rs.randn(n) * np.exp(-tt / 0.006) * (t >= t0)
        x = _spec_filter(x, lambda f: np.exp(-0.5 * ((np.log(np.maximum(f, 1)) - np.log(bright)) / 0.7) ** 2))
        thud = _modes(t - t0, [(140 + rng.uniform(-20, 20), 0.5, 0.02)])
        return (x / (np.max(np.abs(x)) + 1e-9) + thud) * amp

    out = slap(heel_t, 1.0, 1700) + slap(ball_t, 0.7, 2300)
    sq = (rs.rand(n) < 0.03) * rs.randn(n)                               # la succion : petits claquements serrés
    sq_env = np.clip((t - peel_t) / 0.01, 0, 1) * np.exp(-np.maximum(t - peel_t, 0) / 0.035)
    sq = _spec_filter(sq * sq_env, lambda f: _butter(f, 1500, 2, high=True) * _butter(f, 7000, 2))
    out += sq * 1.2
    water = np.zeros(n)
    for k in range(rng.randint(2, 4)):                                   # quelques gouttelettes
        t0 = ball_t + rng.uniform(0.0, 0.08)
        tt = np.maximum(t - t0, 0)
        fb = rng.uniform(2200, 3600) * (1 + 0.6 * (1 - np.exp(-tt / 0.006)))
        water += np.sin(2 * np.pi * np.cumsum(fb) / RATE) * np.exp(-tt / 0.008) * (t >= t0) * rng.uniform(0.1, 0.25)
    out += water
    out = _spec_filter(out, lambda f: _butter(f, 90, 2, high=True) * _butter(f, 9000, 2))
    out = _verb(out, 0.55, 3320 + i, 0.25)
    _save_wav(f'wet_step_{i}.wav', _fades(out, 0.0, 0.08), 0.85)


def wet_steps():
    for i in (1, 2):
        wet_step(i)


def heartbeat_loop():
    """Battements de cœur sourds, entendus de l'intérieur (~70 par minute) : huit battements « lub-dub »
    un peu irréguliers, filtrés très bas. 6,857 s (8 × 60/70 s exactement), en boucle."""
    n = RATE * 60 * 8 // 70                                             # 302 400 échantillons
    rng, _rs = _rngs(334)
    out = np.zeros(n)
    beat = n / 8
    m = int(RATE * 0.4)
    tt = np.arange(m) / RATE
    for b in range(8):
        i0 = int(b * beat + rng.uniform(-0.012, 0.012) * RATE)
        amp = 1 + rng.uniform(-0.08, 0.08)
        for off, a, f0, f1, dec in ((0.0, 1.0, 62, 38, 0.075), (0.31 + rng.uniform(-0.01, 0.01), 0.62, 74, 48, 0.055)):
            f = f1 + (f0 - f1) * np.exp(-tt / 0.04)
            th = np.sin(2 * np.pi * np.cumsum(f) / RATE) * (1 - np.exp(-tt / 0.006)) * np.exp(-tt / dec)
            th += 0.25 * np.sin(2 * np.pi * np.cumsum(f * 2.3) / RATE) * np.exp(-tt / (dec * 0.6))   # un peu de corps, pour les petits haut-parleurs
            idx = (i0 + int(off * RATE) + np.arange(m)) % n
            out[idx] += th * a * amp
    out += _band_noise(n, 30, 120, 3341) * 0.04                        # le sang, l'oreille sur l'oreiller
    out = _spec_filter(out, lambda f: _butter(f, 180, 3) * _butter(f, 22, 2, high=True))
    _save_wav('heartbeat_loop.wav', out, 0.85)


def breath_near():
    """Un souffle tout près de l'oreille (~1,5 s) : une petite inspiration par le nez, la bouche qui
    s'entrouvre (claquement humide), puis une longue expiration chaude qui tremble un peu. Sec, très proche."""
    sec = 1.5
    n = int(RATE * sec)
    t = np.arange(n) / RATE
    _rng, rs = _rngs(335)
    inh = np.clip((t - 0.02) / 0.12, 0, 1) * np.clip((0.3 - t) / 0.08, 0, 1)
    nose = _spec_filter(rs.randn(n), lambda f: np.exp(-0.5 * ((f - 3200) / 1400) ** 2) + 0.4 * np.exp(-0.5 * ((f - 900) / 300) ** 2))
    lip = _modes(t - 0.4, [(1800, 0.4, 0.004), (3900, 0.3, 0.002)]) + rs.randn(n) * np.exp(-np.maximum(t - 0.4, 0) / 0.002) * (t > 0.4) * 0.3
    ex = np.clip((t - 0.42) / 0.09, 0, 1) * np.clip((1.47 - t) / 0.75, 0, 1) ** 1.3
    trem = 1 + 0.12 * np.sin(2 * np.pi * 5.5 * t) + 0.06 * np.sin(2 * np.pi * 8.3 * t + 1)
    formants = lambda f: (0.9 * np.exp(-0.5 * ((f - 650) / 220) ** 2) + 0.7 * np.exp(-0.5 * ((f - 1250) / 300) ** 2)
                          + 0.5 * np.exp(-0.5 * ((f - 2600) / 500) ** 2) + 0.25 * _butter(f, 4000, 2, high=True) * _butter(f, 9000, 2))
    exhale = _spec_filter(rs.randn(n), formants)
    wind = _spec_filter(rs.randn(n), lambda f: _butter(f, 260, 3) * _butter(f, 40, 2, high=True))   # l'air sur l'oreille
    wind *= 1 + 0.6 * _spec_filter(rs.randn(n), lambda f: _butter(f, 12, 2))
    out = nose / np.std(nose) * inh * 0.35 + lip * 0.6
    out += (exhale / np.std(exhale) * 0.8 + wind / np.std(wind) * 0.55) * ex * trem
    out += _spec_filter(rs.randn(n), lambda f: _butter(f, 3000, 1)) * 0.004    # le silence de la pièce, pas le vide
    out = _spec_filter(out, lambda f: _butter(f, 30, 2, high=True) * _butter(f, 11000, 2))
    _save_wav('breath_near.wav', _fades(out, 0.003, 0.05), 0.85)


FLOOR = [plan_etage, croquis_fractionneur, photo_couloir, silhouette_feed, clovis_plaque,   # (tin_lid… : HD_IMAGES)
         portrait_1996, modem_chant, hum_move, chirps, babyphone_breath, pipe_knock,
         printer, fans_spinup, servo, curtain_rings, drip, wet_steps, heartbeat_loop, breath_near]


# ============================================================ passe « triple A », lot V2-SON : pluie, respiration
# « make_assets.py son » : la pluie contre chaque fenêtre (rain_glass_1 à 3, boucles de 16 s), la pluie sur le
# toit (rain_roof, 20 s) et la respiration du héros (breath_<calme|tendu|panique>_<in|out>_<1..4>), lue par
# Sfx._update_breath. Synthèse, en attendant de vrais enregistrements. Chaque fonction a son propre hasard
# (np.random.RandomState à graine fixe) : le hasard global n'est jamais touché, rien d'autre ne change.
# Niveaux : la pluie à -20 dBFS efficaces (crête limitée à 0,9), chaque souffle à BREATH_LEVELS (dBFS efficaces
# sur sa partie active) : les rapports calme / tendu / panique et inspiration / expiration sont dans les fichiers,
# le volume d'ensemble dans Sfx.BREATH_POINTS.
# Lot V2-CREATURE (revue 3) : 48 kHz (SON_RATE) ; pluie en boucles de 36 s, gouttes plafonnées (plus de « pop-corn »),
# ruissellement plus présent, une seule source à l'appui de fenêtre et à un rythme qui flotte (facteur de crête
# ≤ 20 dB, vérifié) ; souffles avec les petits bruits de la bouche (langue, salive), le sifflement des narines au
# calme et une turbulence qui bouge.

def _peaks(f, specs):
    """Résonances (formants) : somme de pics de Lorentz [(centre, largeur, gain)]."""
    out = np.zeros_like(f)
    for fc, bw, g in specs:
        out += g / (1 + ((f - fc) / (bw / 2)) ** 2)
    return out


def _shaped_noise(n, env_fn, rs, frame=1024, hop=256):
    """Bruit dont l'enveloppe spectrale suit env_fn(f, u) (u de 0 à 1 dans le son), par STFT (Hann, 75 %)."""
    x = rs.randn(n + frame)
    win = np.hanning(frame)
    out = np.zeros(n + 2 * frame)
    norm = np.zeros(n + 2 * frame)
    f = np.fft.rfftfreq(frame, 1 / RATE)
    for start in range(0, n + frame // 2, hop):
        seg = x[start:start + frame]
        if len(seg) < frame:
            seg = np.pad(seg, (0, frame - len(seg)))
        u = min(1.0, max(0.0, (start + frame / 2 - frame / 2) / n))
        y = np.fft.irfft(np.fft.rfft(seg * win) * env_fn(f, u), frame) * win
        out[start:start + frame] += y
        norm[start:start + frame] += win ** 2
    return (out / np.maximum(norm, 1e-3))[:n]


def _smooth_noise(n, hz, rs):
    """Bruit lent (passe-bas à hz), écart type 1."""
    x = _spec_filter(rs.randn(n), lambda f: _butter(f, hz, 2))
    return x / (np.std(x) + 1e-12)


# ------------------------------------------------------------------ pluie à la fenêtre

def _wrap_add(out, i, ev):
    """Ajoute ev à partir de l'indice i, en revenant au début (boucle sans couture)."""
    n = len(out)
    m = len(ev)
    end = i + m
    if end <= n:
        out[i:end] += ev
    else:
        k = n - i
        out[i:] += ev[:k]
        out[:m - k] += ev[k:]


SON_RATE = 48000


def rain_glass(k, sec=36.0):
    """Pluie contre la vitre, entendue de la pièce (boucle de sec s) : le ruissellement dehors à travers le
    verre, les gouttes qui claquent sur la vitre (petites résonances du carreau), l'appui de fenêtre qui
    goutte à son rythme, un filet d'eau qui coule de temps en temps. k : variante (1 à 3)."""
    rs = np.random.RandomState(4100 + k)
    n = int(RATE * sec)
    t = np.arange(n) / RATE
    # rafales : modulations lentes de période sec / m (la boucle raccorde)
    gust = 1.0 + 0.16 * np.sin(2 * np.pi * (2 / sec) * t + rs.uniform(0, 6.3)) \
        + 0.09 * np.sin(2 * np.pi * (5 / sec) * t + rs.uniform(0, 6.3)) + 0.05 * np.sin(2 * np.pi * (11 / sec) * t + rs.uniform(0, 6.3))
    # 1) la pluie dehors, à travers le verre : bruit rose, bosse dans le grave-médium, aigus amortis
    wash = _spec_filter(rs.randn(n), lambda f: (np.maximum(f, 30) / 1000.0) ** -0.5 * _butter(f, 3800, 2) * _butter(f, 140, 2, high=True)
                        * (1 + 0.8 * np.exp(-0.5 * ((f - 450) / 260) ** 2)))
    wash = wash / np.std(wash) * 0.0065 * gust
    # 2) les gouttes sur la vitre : impulsions courtes, résonances du carreau entre 1,8 et 6 kHz
    drops = np.zeros(n)
    rate = (22.0 + 5.0 * k) * 1.4            # plus de gouttes, plus petites : un crépitement, pas des claques
    count = int(rate * sec)
    pos = rs.uniform(0, n, count).astype(int)
    for i in pos:
        g = gust[i]
        a = rs.pareto(2.2) * 0.026
        a = 0.022 * np.tanh(a / 0.022) * g     # plafond doux : plus de goutte qui claque seule
        if a < 0.002:
            continue
        m = int(RATE * 0.03)
        tt = np.arange(m) / RATE
        f0 = rs.uniform(1800, 6000)
        ev = (np.sin(2 * np.pi * f0 * tt) * np.exp(-tt / rs.uniform(0.002, 0.006))
              + 0.6 * np.sin(2 * np.pi * f0 * rs.uniform(1.4, 2.2) * tt) * np.exp(-tt / 0.0025)
              + 0.45 * rs.randn(m) * np.exp(-tt / 0.0006)
              + 0.5 * np.sin(2 * np.pi * rs.uniform(350, 800) * tt) * np.exp(-tt / 0.004))
        _wrap_add(drops, i, ev * a)
    drops = _spec_filter(drops, lambda f: _butter(f, 7000, 2) * _butter(f, 200, 1, high=True))
    # 3) l'appui de fenêtre qui goutte, à son rythme (bulle : la hauteur monte), une ou deux sources
    sill = np.zeros(n)
    for src in range(2):
        period = rs.uniform(0.7, 1.6) * (1.0 + src * 0.6)
        beats = max(1, int(round(sec / period)))
        period = sec / beats
        f_b = rs.uniform(900, 1500)
        mute = src == (k % 2)                 # une source sur deux se tait (selon la variante)
        drift = np.cumsum(rs.normal(0, 0.06 * period, beats))
        drift -= np.linspace(0, drift[-1], beats)   # le rythme flotte, mais la boucle raccorde
        for b in range(beats):
            if rs.rand() < 0.3 or mute:
                continue
            i = int((b * period + drift[b] + rs.normal(0, 0.05 * period) + src * 0.37) * RATE) % n
            m = int(RATE * 0.09)
            tt = np.arange(m) / RATE
            fb = f_b * rs.uniform(0.93, 1.07)
            ph = 2 * np.pi * np.cumsum(fb * (1 + 0.9 * (1 - np.exp(-tt / 0.012)))) / RATE
            plip = np.sin(ph) * np.exp(-tt / 0.022) * np.clip(tt / 0.0008, 0, 1)
            tick = rs.randn(m) * np.exp(-tt / 0.0012) * 0.35
            _wrap_add(sill, i, (plip + tick) * rs.uniform(0.6, 1.0) * (0.05 if src == 0 else 0.035))
    sill = _spec_filter(sill, lambda f: _butter(f, 4200, 2) * _butter(f, 300, 2, high=True))
    # 4) un filet d'eau qui coule sur la vitre, par moments (deux passages par boucle)
    trickle = _spec_filter(rs.randn(n), lambda f: np.exp(-0.5 * (np.log(np.maximum(f, 1) / 2200) / 0.45) ** 2))
    flutter = 0.5 + 0.5 * np.clip(_smooth_noise(n, 35, rs), -2, 2) / 2
    swell = np.clip(np.sin(2 * np.pi * (2 / sec) * t + rs.uniform(0, 6.3)), 0, 1) ** 3
    trickle = trickle / np.std(trickle) * flutter * swell * 0.004
    out = wash + drops + sill + trickle
    out = _spec_filter(out, lambda f: _butter(f, 40, 2, high=True))
    return out


def rain_roof(sec=20.0):
    """La pluie sur le toit, à travers le plafond et le grenier : un roulement grave et serré, un crépitement
    étouffé, des rafales lentes. Boucle de sec s."""
    rs = np.random.RandomState(4200)
    n = int(RATE * sec)
    t = np.arange(n) / RATE
    gust = 1.0 + 0.2 * np.sin(2 * np.pi * (1 / sec) * t + 1.3) + 0.12 * np.sin(2 * np.pi * (3 / sec) * t + 0.4)
    rumble = _spec_filter(rs.randn(n), lambda f: (np.maximum(f, 20) / 100.0) ** -0.8 * _butter(f, 420, 3) * _butter(f, 35, 2, high=True))
    rumble = rumble / np.std(rumble)
    patter = np.zeros(n)
    pos = rs.uniform(0, n, int(420 * sec)).astype(int)
    m = int(RATE * 0.02)
    tt = np.arange(m) / RATE
    for i in pos:
        a = min(rs.pareto(3.0) * 0.3, 0.8) * gust[i]
        _wrap_add(patter, i, rs.randn(m) * np.exp(-tt / 0.003) * a)
    patter = _spec_filter(patter, lambda f: _butter(f, 900, 3) * _butter(f, 120, 2, high=True))
    patter = patter / (np.std(patter) + 1e-12)
    out = (rumble * 0.8 + patter * 0.35) * gust
    return out


# ------------------------------------------------------------------ respiration du héros

def _tract(f, form, nasal=0.0, chest=0.0, hiss=0.0, hiss_fc=4500.0):
    """Enveloppe spectrale d'un souffle : formants (form : [(fc, bw, g)]), nasalité (résonance grave et
    creux vers 900 Hz), poitrine (grave, l'oreille interne), sifflement des dents ; son entendu de
    l'intérieur de la tête (grave renforcé, aigus doux)."""
    e = _peaks(f, form)
    if nasal:
        e = e * (1 - nasal * 0.85 * np.exp(-0.5 * ((f - 950) / 260) ** 2)) + nasal * 0.5 * np.exp(-0.5 * ((f - 280) / 90) ** 2)
    if chest:
        e = e + chest * _butter(f, 320, 2) * _butter(f, 70, 2, high=True)
    if hiss:
        e = e + hiss * np.exp(-0.5 * (np.log(np.maximum(f, 1) / hiss_fc) / 0.35) ** 2)
    head = (1 + 0.45 * _butter(f, 500, 1)) * _butter(f, 7000, 2) * _butter(f, 120, 2, high=True)
    return e * head


def _envelope(n, attack, release, shape=1.0, sustain_tilt=0.0):
    """Enveloppe d'un souffle : montée (attack), plateau qui penche (sustain_tilt), descente (release), en
    fractions de la durée ; shape > 1 : descente plus douce."""
    u = np.linspace(0, 1, n)
    a = np.clip(u / max(attack, 1e-4), 0, 1) ** 0.7
    r = np.clip((1 - u) / max(release, 1e-4), 0, 1) ** shape
    s = 1 + sustain_tilt * (u - 0.5)
    return np.sin(np.pi / 2 * a) * r * s


def _voiced(n, f0, form, rs, jitter=0.02):
    """Un peu de voix (glotte) : impulsions de Rosenberg à f0 (hauteur qui flotte), à travers les formants."""
    x = np.zeros(n)
    i = 0.0
    while i < n:
        period = RATE / (f0 * (1 + rs.normal(0, jitter)))
        k = int(i)
        m = int(period * 0.6)
        tt = np.arange(m) / max(m, 1)
        pulse = np.where(tt < 0.7, 0.5 * (1 - np.cos(np.pi * tt / 0.7)), np.cos(np.pi * (tt - 0.7) / 0.6))
        end = min(n, k + m)
        x[k:end] += pulse[:end - k]
        i += period
    x = np.diff(x, prepend=0.0)    # dérivée du débit : le son rayonné
    return _spec_filter(x, lambda f: _peaks(f, form) + 0.05)


BREATH_SPECS = {
    # durée in / out (s), formants in / out, nasalité, poitrine, sifflement, tremblement, voix
    'calme': dict(din=1.45, dout=2.05, fin=[(1700, 1400, 0.7), (3000, 1600, 0.5), (650, 500, 0.3)],
                  fout=[(900, 900, 0.6), (1700, 1200, 0.45), (2900, 1500, 0.2)], nasal=0.9, chest=0.25,
                  hiss=0.12, trem=0.0, voice=0.0, rough=0.1, pause=0.9),
    'tendu': dict(din=0.92, dout=1.25, fin=[(620, 420, 0.8), (1250, 600, 0.65), (2600, 900, 0.5)],
                  fout=[(700, 450, 0.9), (1220, 650, 0.6), (2550, 1000, 0.35)], nasal=0.15, chest=0.45,
                  hiss=0.35, trem=0.12, voice=0.0, rough=0.25, pause=0.45),
    'panique': dict(din=0.52, dout=0.72, fin=[(560, 380, 0.9), (1400, 600, 0.7), (2700, 900, 0.6)],
                    fout=[(760, 420, 1.0), (1250, 600, 0.75), (2600, 1000, 0.45)], nasal=0.0, chest=0.7,
                    hiss=0.55, trem=0.2, voice=0.05, rough=0.4, pause=0.06),
}


def breath(kind, way, k):
    """Un souffle du héros : « in » (inspiration) ou « out » (expiration), ensemble kind (calme, tendu,
    panique), variante k. Synthèse : bruit d'air mis en forme par le conduit vocal (STFT), enveloppe, grain
    de turbulence, tremblement ; en panique, un rien de voix au bout de l'inspiration (le « hh-uh »)."""
    sp = BREATH_SPECS[kind]
    rs = np.random.RandomState(4300 + 100 * list(BREATH_SPECS).index(kind) + (0 if way == 'in' else 50) + k)
    dur = (sp['din'] if way == 'in' else sp['dout']) * rs.uniform(0.88, 1.12)
    n = int(RATE * dur)
    sh = rs.uniform(0.94, 1.06)            # longueur du conduit de cette variante
    form = [(fc * sh * rs.uniform(0.97, 1.03), bw, g) for fc, bw, g in (sp['fin'] if way == 'in' else sp['fout'])]
    drift = rs.uniform(-0.08, 0.08)        # les formants glissent un peu pendant le souffle (mâchoire)

    def env_fn(f, u):
        moved = [(fc * (1 + drift * u), bw, g) for fc, bw, g in form]
        hiss = sp['hiss'] * (1.2 if way == 'in' else 0.7)
        return _tract(f, moved, nasal=sp['nasal'], chest=sp['chest'] * (0.6 if way == 'in' else 1.0), hiss=hiss,
                      hiss_fc=5200 if way == 'in' else 3800)
    x = _shaped_noise(n, env_fn, rs)
    x /= np.std(x) + 1e-12
    # grain de turbulence (le souffle n'est jamais un bruit lisse) et tremblement de la peur
    t = np.arange(n) / RATE
    grain = 1 + sp['rough'] * np.clip(_smooth_noise(n, rs.uniform(25, 45), rs), -2.5, 2.5) / 2.5
    trem = 1 + sp['trem'] * np.sin(2 * np.pi * rs.uniform(5.0, 7.5) * t + rs.uniform(0, 6.3)) \
        + sp['trem'] * 0.5 * np.clip(_smooth_noise(n, 9, rs), -2, 2) / 2
    if way == 'in':
        env = _envelope(n, attack=rs.uniform(0.18, 0.3) if kind != 'panique' else 0.07, release=0.18 if kind != 'panique' else 0.06,
                        shape=1.2, sustain_tilt={'calme': 0.35, 'tendu': 0.3, 'panique': 0.7}[kind])
    else:
        env = _envelope(n, attack=0.07 if kind != 'calme' else 0.12, release=0.75, shape=1.6, sustain_tilt=-0.5)
    y = x * grain * trem * env
    if kind == 'panique' and way == 'in' and rs.rand() < 0.75:
        # le « uh » qui accroche la gorge à la fin de l'inspiration
        m = int(RATE * rs.uniform(0.05, 0.09))
        v = _voiced(m, rs.uniform(105, 135), [(520, 160, 1.0), (1350, 250, 0.5), (2500, 400, 0.25)], rs)
        v = v / (np.std(v) + 1e-12) * np.hanning(m) * 0.35
        at = n - m - int(RATE * 0.02)
        y[at:at + m] += v
    if kind == 'panique' and way == 'out' and rs.rand() < 0.5:
        m = int(RATE * rs.uniform(0.06, 0.12))
        v = _voiced(m, rs.uniform(95, 120), [(700, 180, 1.0), (1200, 250, 0.6), (2550, 400, 0.25)], rs, jitter=0.04)
        v = v / (np.std(v) + 1e-12) * np.hanning(m) * 0.22
        y[:m] += v * np.linspace(1, 0.3, m)
    # les petits bruits de la bouche (lot V2-CREATURE) : la langue qui se décolle au début d'une inspiration
    # par la bouche, quelques bulles de salive ; au calme, le sifflement des narines
    if way == 'in' and kind != 'calme' and rs.rand() < 0.55:
        m = int(RATE * 0.006)
        tm = np.arange(m) / RATE
        click = rs.randn(m) * np.exp(-tm / 0.0012)
        click = _spec_filter(np.concatenate([click, np.zeros(m)]), lambda f: _peaks(f, [(2300, 1400, 1.0), (4200, 1600, 0.5)]))[:m]
        at = int(RATE * rs.uniform(0.0, 0.03))
        y[at:at + m] += click / (np.max(np.abs(click)) + 1e-9) * np.max(np.abs(y)) * 0.18
    for _ in range(rs.poisson(1.2 if kind != 'calme' else 0.5)):
        m = int(RATE * 0.004)
        tm = np.arange(m) / RATE
        bub = np.sin(2 * np.pi * rs.uniform(2500, 4500) * tm) * np.exp(-tm / 0.0009)
        at = int(rs.uniform(0.1, 0.9) * (n - m))
        y[at:at + m] += bub * np.max(np.abs(y)) * rs.uniform(0.04, 0.1)
    if kind == 'calme' and way == 'in':
        whistle = _shaped_noise(n, lambda f, u: np.exp(-0.5 * ((f - 2900 * sh) / 120) ** 2), rs)
        whistle /= np.std(whistle) + 1e-12
        y += whistle * env * np.std(y) * 0.12 * (0.5 + 0.5 * np.clip(_smooth_noise(n, 6, rs), -1, 1))
    fade = int(RATE * 0.012)
    y[:fade] *= np.linspace(0, 1, fade) ** 2
    y[-fade:] *= np.linspace(1, 0, fade) ** 2
    return y


def _active_rms(x):
    e = x ** 2
    w = int(RATE * 0.05)
    s = np.convolve(e, np.ones(w) / w, mode='same')
    thr = s.max() * 0.05
    return np.sqrt(s[s > thr].mean())


BREATH_LEVELS = {('calme', 'in'): -24.0, ('calme', 'out'): -25.5, ('tendu', 'in'): -22.0, ('tendu', 'out'): -21.5,
                 ('panique', 'in'): -19.5, ('panique', 'out'): -20.5}


def _son_rate(fn):
    """Les sons de cette section sont calculés à SON_RATE (48 kHz) : RATE est changé le temps de l'appel."""
    def run():
        global RATE
        old = RATE
        RATE = SON_RATE
        try:
            fn()
        finally:
            RATE = old
    run.__name__ = fn.__name__
    return run


@_son_rate
def breaths():
    for kind in BREATH_SPECS:
        for way in ('in', 'out'):
            for k in range(1, 5):
                y = breath(kind, way, k)
                y *= 10 ** (BREATH_LEVELS[(kind, way)] / 20) / _active_rms(y)
                assert np.max(np.abs(y)) < 0.98, (kind, way, k, np.max(np.abs(y)))
                write_wav('breath_%s_%s_%d.wav' % (kind, way, k), y, SON_RATE)


@_son_rate
def rains():
    for k in (1, 2, 3):
        y = rain_glass(k)
        y *= 10 ** (-20.0 / 20) / np.sqrt(np.mean(y ** 2))
        y *= min(1.0, 0.9 / np.max(np.abs(y)))
        crest = 20 * np.log10(np.max(np.abs(y)) / np.sqrt(np.mean(y ** 2)))
        assert crest <= 20.0, ('rain_glass_%d : facteur de crête %.1f dB' % (k, crest))
        write_wav('rain_glass_%d.wav' % k, y, SON_RATE)
    y = rain_roof()
    y *= 10 ** (-20.0 / 20) / np.sqrt(np.mean(y ** 2))
    y *= min(1.0, 0.9 / np.max(np.abs(y)))
    write_wav('rain_roof.wav', y, SON_RATE)


SON = [rains, breaths]


if __name__ == '__main__':
    import sys
    if len(sys.argv) > 1:   # ne régénérer que certaines ressources : make_assets.py house | music | story | floor | images
        if 'images' in sys.argv:
            images_hd()
        if 'house' in sys.argv:
            for f in HOUSE:
                f()
        if 'music' in sys.argv:
            for f in MUSIC:
                f()
        if 'story' in sys.argv:
            for f in STORY:
                f()
        if 'floor' in sys.argv:
            for f in FLOOR:
                f()
        if 'son' in sys.argv:
            for f in SON:
                f()
        print('ok')
        raise SystemExit
    _hasard_033(HASARD_033[0])   # les images de la 0.3.3 tiraient ici du hasard global (voir HASARD_033)
    room_tone()
    crt_hum()
    drive_seek()
    wallpaper()
    beadboard()
    grime_tile()
    stain_water()
    mold()
    footprint('foot_left.png', 0)
    footprint('foot_right.png', 1)
    scratches()
    _hasard_033(HASARD_033[1])
    neighbor_window()
    rain_loop()
    thunder()
    for f in HOUSE:
        f()
    for f in MUSIC:
        f()
    for f in STORY:
        f()
    for f in FLOOR:   # v0.3.1 : l'étage
        f()
    for f in SON:     # passe « triple A » : pluie aux fenêtres, respiration (hasard propre)
        f()
    images_hd()       # 0.3.4 : les images HD, les photos, et leurs contrôles
    print('ok')
