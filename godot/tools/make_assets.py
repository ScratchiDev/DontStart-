"""Génère les images et sons « faits maison » du jeu (affiches, mot, étiquette, ambiances).

Usage : python3 godot/tools/make_assets.py
        python3 godot/tools/make_assets.py story   (seulement l'acte I ; aussi : house, music, floor)
Dépendances : Pillow, numpy (et ffmpeg pour les .ogg). Les polices viennent de godot/assets/fonts (licence OFL).
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


def grime(img, amount=0.25):
    """Taches, plis et poussière : une affiche de 1984 restée au mur."""
    w, h = img.size
    over = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for _ in range(int(w * h / 900)):
        x, y = random.randrange(w), random.randrange(h)
        a = int(random.random() * 60 * amount)
        d.point((x, y), fill=(0, 0, 0, a))
    for _ in range(6):
        x = random.randrange(w)
        d.line([(x, 0), (x + random.randint(-20, 20), h)], fill=(255, 255, 255, int(18 * amount)), width=1)
    for _ in range(3):
        cx, cy, r = random.randrange(w), random.randrange(h), random.randint(20, 60)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(60, 40, 10, int(40 * amount)))
    over = over.filter(ImageFilter.GaussianBlur(1.2))
    return Image.alpha_composite(img.convert('RGBA'), over).convert('RGB')


def poster_choisis():
    w, h = 512, 736
    img = Image.new('RGB', (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / h
        r = int(42 + (122 - 42) * min(1, t / .6)) if t < .6 else int(122 - (122 - 10) * (t - .6) / .4)
        g = int(11 + 16 * min(1, t / .6))
        b = int(16 + 6 * min(1, t / .6))
        d.line([(0, y), (w, y)], fill=(r, g, b))
    pts = [(0, int(h * .62))]
    for x in range(0, w + 1, 32):
        pts.append((x, int(h * .62 - abs(np.sin(x * .035)) * 80 - (36 if x % 96 < 48 else 0))))
    pts += [(w, h), (0, h)]
    d.polygon(pts, fill=(5, 3, 10))
    d.ellipse([w * .5 - 52, h * .5 - 72, w * .5 + 52, h * .5 + 72], fill=(10, 6, 8))
    d.rectangle([w * .5 - 80, h * .56, w * .5 + 80, h * .56 + 240], fill=(10, 6, 8))
    big = font('IBMPlexMono-Bold.ttf', 92)
    mid = font('IBMPlexMono-Bold.ttf', 54)
    sm = font('IBMPlexMono-Regular.ttf', 22)
    d.text((w / 2, 120), 'CHOISIS', font=big, fill=(242, 228, 200), anchor='mm')
    d.text((w / 2, 196), 'OU SINON', font=mid, fill=(242, 228, 200), anchor='mm')
    d.text((w / 2, h - 40), 'UN FILM DE J. MORVAN · 1983', font=sm, fill=(201, 179, 138), anchor='mm')
    grime(img, .6).save(os.path.join(IMG, 'poster_choisis.png'))


def poster_spectres():
    w = h = 512
    img = Image.new('RGB', (w, h), (17, 17, 17))
    d = ImageDraw.Draw(img)
    for i in range(12, 0, -1):
        r = 40 + i * 22
        d.ellipse([w / 2 - r, h / 2 - r, w / 2 + r, h / 2 + r], fill=(232, 224, 50) if i % 2 else (27, 27, 27))
    d.rectangle([0, h * .38, w, h * .62], fill=(17, 17, 17))
    d.text((w / 2, h * .47), 'LES SPECTRES', font=font('IBMPlexMono-Bold.ttf', 60), fill=(232, 224, 50), anchor='mm')
    d.text((w / 2, h * .56), 'TOURNÉE 84 · COMPLET', font=font('IBMPlexMono-Regular.ttf', 26), fill=(232, 224, 50), anchor='mm')
    grime(img, .5).save(os.path.join(IMG, 'poster_spectres.png'))


def lined_paper(w, h, step):
    img = Image.new('RGB', (w, h), (239, 231, 210))
    d = ImageDraw.Draw(img)
    for y in range(int(step * 1.6), h, step):
        d.line([(0, y), (w, y)], fill=(170, 176, 214), width=1)
    d.line([(int(w * .12), 0), (int(w * .12), h)], fill=(214, 150, 150), width=1)
    return img, d


def note():
    img, d = lined_paper(256, 320, 28)
    hand = font('ReenieBeanie.ttf', 50)
    for i, txt in enumerate(['ne pas', 'jouer', 'après minuit']):
        d.text((128, 92 + i * 56), txt, font=hand, fill=(38, 40, 106), anchor='mm')
    grime(img, .35).rotate(0).save(os.path.join(IMG, 'note.png'))


def floppy_label():
    img, d = lined_paper(256, 96, 22)
    d.text((128, 40), 'NE PAS JOUER', font=font('ReenieBeanie.ttf', 54), fill=(38, 40, 106), anchor='mm')
    d.text((128, 78), 'runtime · 84', font=font('ReenieBeanie.ttf', 30), fill=(38, 40, 106), anchor='mm')
    img.save(os.path.join(IMG, 'floppy_label.png'))


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


def photo():
    """Photo de famille jaunie : un adulte et un enfant devant une maison. Les visages ont été rayés."""
    w, h = 300, 220
    img = Image.new('RGB', (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        k = y / h
        d.line([(0, y), (w, y)], fill=(int(206 - 40 * k), int(190 - 44 * k), int(150 - 50 * k)))
    d.rectangle([0, 168, w, h], fill=(120, 104, 74))
    d.polygon([(18, 112), (82, 62), (146, 112)], fill=(96, 80, 62))
    d.rectangle([30, 112, 134, 172], fill=(150, 130, 100))
    d.rectangle([72, 132, 92, 172], fill=(70, 56, 42))
    d.rectangle([42, 124, 62, 142], fill=(80, 70, 56))

    def person(cx, foot, height, shade):
        head = height * .16
        sh = height * .26
        top = foot - height
        neck = top + head * 2
        d.ellipse([cx - head * .8, top, cx + head * .8, top + head * 2], fill=shade)
        d.polygon([(cx - head * .35, neck - 2), (cx + head * .35, neck - 2), (cx + sh * .55, neck + 6),
                   (cx + sh * .5, foot - height * .42), (cx + sh * .32, foot), (cx - sh * .32, foot),
                   (cx - sh * .5, foot - height * .42), (cx - sh * .55, neck + 6)], fill=shade)
        d.line([(cx - sh * .55, neck + 8), (cx - sh * .7, foot - height * .4)], fill=shade, width=int(height * .07))
        d.line([(cx + sh * .55, neck + 8), (cx + sh * .7, foot - height * .4)], fill=shade, width=int(height * .07))
        for k in range(26):
            y0 = top + random.uniform(-2, head * 2 + 2)
            d.line([(cx - head * 1.1, y0), (cx + head * 1.1, y0 + random.uniform(-6, 6))],
                   fill=(18, 14, 10) if k % 3 else (230, 220, 200), width=2 if k % 3 else 1)

    person(205, 186, 128, (58, 47, 36))
    person(252, 188, 84, (66, 54, 42))
    img = img.filter(ImageFilter.GaussianBlur(.7))
    img = grime(img, 1.2)
    framed = Image.new('RGB', (w + 24, h + 24), (232, 226, 210))
    framed.paste(img, (12, 12))
    framed.save(os.path.join(IMG, 'photo.png'))



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


def calendar():
    """Calendrier de novembre : les jours barrés jusqu'au 12, le 13 entouré."""
    w, h = 300, 420
    img = Image.new('RGB', (w, h), (232, 226, 210))
    d = ImageDraw.Draw(img)
    for y in range(0, 190):
        k = y / 190
        d.line([(10, 10 + y), (w - 10, 10 + y)], fill=(int(30 + 30 * k), int(40 + 20 * k), int(36 + 10 * k)))
    for i in range(14):
        x = 20 + i * 20 + random.randint(-4, 4)
        d.polygon([(x, 200), (x + 9, 60 + random.randint(0, 50)), (x + 18, 200)], fill=(12, 18, 14))
    d.text((w / 2, 222), 'NOVEMBRE', font=font('IBMPlexMono-Bold.ttf', 30), fill=(40, 30, 28), anchor='mm')
    f = font('IBMPlexMono-Regular.ttf', 18)
    day = 1
    for row in range(5):
        for col in range(7):
            if row == 0 and col < 3:
                continue
            if day > 30:
                break
            x, y = 26 + col * 40, 262 + row * 32
            d.text((x, y), str(day), font=f, fill=(50, 44, 40), anchor='mm')
            if day <= 12:
                d.line([(x - 12, y - 10), (x + 12, y + 10)], fill=(170, 30, 30), width=2)
                d.line([(x + 12, y - 10), (x - 12, y + 10)], fill=(170, 30, 30), width=2)
            if day == 13:
                d.ellipse([x - 16, y - 14, x + 16, y + 14], outline=(190, 20, 20), width=3)
            day += 1
    grime(img, .7).save(os.path.join(IMG, 'calendar.png'))


def corkboard():
    """Tableau en liège : polaroids, notes, un ticket."""
    w, h = 512, 384
    cork = fbm_tile(512, 0.7, 71)[:h, :w]
    big = fbm_tile(512, 2.2, 72)[:h, :w]
    base = np.dstack([0.62 + 0.2 * cork, 0.43 + 0.15 * cork, 0.25 + 0.1 * cork]) * (0.85 + 0.2 * big)[..., None]
    img = Image.fromarray((np.clip(base, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], outline=(70, 46, 28), width=14)
    hand = font('ReenieBeanie.ttf', 27)

    def pin(x, y):
        d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=(190, 30, 30))
        d.ellipse([x - 2, y - 4, x + 1, y - 1], fill=(240, 160, 160))

    for (x, y, rot, shade) in [(40, 40, -6, 90), (190, 30, 4, 60), (340, 52, -3, 120)]:
        pol = Image.new('RGB', (120, 140), (236, 232, 222))
        pd = ImageDraw.Draw(pol)
        pd.rectangle([10, 10, 110, 105], fill=(shade, shade - 10, shade - 20))
        pd.ellipse([45, 30, 75, 62], fill=(shade - 40, shade - 46, shade - 50))
        pd.rectangle([40, 60, 80, 105], fill=(shade - 40, shade - 46, shade - 50))
        pol = pol.rotate(rot, expand=True, fillcolor=(0, 0, 0))
        mask = pol.convert('L').point(lambda v: 255 if v > 4 else 0)
        img.paste(pol, (x, y), mask)
        pin(x + 60, y + 12)
    notes = [(40, 220, (238, 220, 110), ['rendre la K7', 'à Karim']), (210, 230, (246, 240, 228), ['14h dentiste', '(mardi)']),
             (360, 200, (200, 225, 240), ['elle me', 'regarde', 'la nuit'])]
    for x, y, col, lines in notes:
        d.rectangle([x, y, x + 130, y + 110], fill=col)
        for i, t in enumerate(lines):
            d.text((x + 10, y + 18 + i * 32), t, font=hand, fill=(30, 30, 80))
        pin(x + 65, y + 8)
    grime(img, .5).save(os.path.join(IMG, 'corkboard.png'))


def clock_face():
    """Horloge murale arrêtée à 3 h 12."""
    n = 256
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([4, 4, n - 4, n - 4], fill=(226, 220, 204, 255), outline=(30, 28, 26, 255), width=10)
    f = font('IBMPlexMono-Bold.ttf', 26)
    for hr in range(1, 13):
        ang = np.pi / 2 - hr * np.pi / 6
        d.text((n / 2 + 92 * np.cos(ang), n / 2 - 92 * np.sin(ang)), str(hr), font=f, fill=(30, 28, 26), anchor='mm')
    def hand_(angle, length, width):
        d.line([(n / 2, n / 2), (n / 2 + length * np.cos(angle), n / 2 - length * np.sin(angle))], fill=(20, 18, 16), width=width)
    hand_(np.pi / 2 - (3 + 12 / 60) * np.pi / 6, 58, 8)
    hand_(np.pi / 2 - 12 * np.pi / 30, 88, 5)
    d.ellipse([n / 2 - 7, n / 2 - 7, n / 2 + 7, n / 2 + 7], fill=(20, 18, 16))
    img.save(os.path.join(IMG, 'clock_face.png'))


def poster_corbeaux():
    w, h = 400, 560
    img = Image.new('RGB', (w, h), (18, 16, 22))
    d = ImageDraw.Draw(img)
    for i in range(9):
        x, y, s = random.randint(30, w - 30), random.randint(120, 380), random.randint(18, 46)
        d.polygon([(x - s, y), (x - s // 3, y - s // 4), (x, y - s // 8), (x + s // 3, y - s // 4), (x + s, y), (x, y + s // 6)], fill=(4, 4, 6))
    d.ellipse([w / 2 - 110, 140, w / 2 + 110, 360], outline=(150, 20, 24), width=6)
    d.text((w / 2, 70), 'Les Corbeaux', font=font('UnifrakturMaguntia-Book.ttf', 46), fill=(200, 190, 170), anchor='mm')
    d.text((w / 2, 440), 'EN CONCERT', font=font('IBMPlexMono-Bold.ttf', 36), fill=(150, 20, 24), anchor='mm')
    d.text((w / 2, 490), 'SALLE DES FÊTES · 31 OCTOBRE', font=font('IBMPlexMono-Regular.ttf', 18), fill=(170, 160, 150), anchor='mm')
    grime(img, .8).save(os.path.join(IMG, 'poster_corbeaux.png'))


def papers():
    img, d = lined_paper(256, 340, 22)
    hand = font('ReenieBeanie.ttf', 30)
    for i in range(12):
        d.text((40, 30 + i * 22), '3:12  3:12  3:12  3:12' if i % 3 == 2 else 'ne pas jouer ne pas jouer', font=hand, fill=(40, 40, 110))
    grime(img, .4).save(os.path.join(IMG, 'paper_312.png'))
    img2 = Image.new('RGB', (256, 340), (238, 236, 228))
    d2 = ImageDraw.Draw(img2)
    d2.text((20, 18), 'RUNTIME', font=font('IBMPlexMono-Bold.ttf', 30), fill=(30, 30, 30))
    d2.text((20, 56), 'MANUEL DE L\'UTILISATEUR', font=font('IBMPlexMono-Regular.ttf', 14), fill=(60, 60, 60))
    for i in range(12):
        d2.line([(20, 96 + i * 18), (236 - random.randint(0, 80), 96 + i * 18)], fill=(120, 120, 120), width=2)
    d2.text((20, 316), '© 1984', font=font('IBMPlexMono-Regular.ttf', 14), fill=(60, 60, 60))
    grime(img2, .5).save(os.path.join(IMG, 'manual.png'))


def vhs_label():
    img, d = lined_paper(256, 48, 16)
    d.text((128, 26), 'NE PAS EFFACER', font=font('ReenieBeanie.ttf', 34), fill=(30, 30, 90), anchor='mm')
    img.save(os.path.join(IMG, 'vhs_label.png'))


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
    """Comme grime(), mais avec son propre générateur (random.Random) : ne touche pas au hasard global."""
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


def _wobbly(pts, rng, amp):
    """Petit tremblement de la main sur une suite de points."""
    return [(x + rng.uniform(-amp, amp), y + rng.uniform(-amp, amp)) for x, y in pts]


def calendar_octobre():
    """Calendrier d'octobre 2016, dans l'ancienne chambre de Manon : tous les jours barrés en rouge
    jusqu'au 30, de plus en plus rageusement ; le 31 entouré si fort que le stylo a troué le papier."""
    w, h = 300, 420
    rng = random.Random(301)
    rs = np.random.RandomState(301)
    img = Image.new('RGB', (w, h), (232, 226, 210))
    d = ImageDraw.Draw(img)
    # le haut illustré : nuit, lune, sapins noirs
    top, bot = 14, 168
    sky = lambda y: (int(30 + 30 * (y - top) / (bot - top)), int(40 + 20 * (y - top) / (bot - top)),
                     int(36 + 10 * (y - top) / (bot - top)))
    for y in range(top, bot):
        d.line([(10, y), (w - 11, y)], fill=sky(y))
    d.ellipse([212, 34, 240, 62], fill=(168, 170, 150))
    d.ellipse([219, 30, 247, 58], fill=sky(44))                      # croissant de lune
    trees = Image.new('L', (w, h), 0)
    dtr = ImageDraw.Draw(trees)
    for i in range(15):
        x = 6 + i * 19 + rng.randint(-4, 4)
        tip = 58 + rng.randint(0, 50)
        dtr.polygon([(x, bot), (x + 10, tip), (x + 20, bot)], fill=255)
        for k in range(4):   # étages de branches
            yy = tip + (bot - tip) * (0.3 + 0.18 * k)
            half = 4 + (yy - tip) * 0.16
            dtr.polygon([(x + 10 - half - 3, yy + 4), (x + 10, yy - 8), (x + 10 + half + 3, yy + 4)], fill=255)
    dtr.rectangle([0, bot - 6, w, bot], fill=255)
    clip = Image.new('L', (w, h), 0)
    ImageDraw.Draw(clip).rectangle([10, top, w - 11, bot - 1], fill=255)
    img.paste((12, 18, 14), (0, 0), Image.fromarray(np.minimum(np.asarray(trees), np.asarray(clip))))
    d.ellipse([w / 2 - 4, 3, w / 2 + 4, 11], fill=(90, 80, 70))       # trou du clou
    # le mois
    d.text((w / 2, 188), 'OCTOBRE 2016', font=font('IBMPlexMono-Bold.ttf', 27), fill=(40, 30, 28), anchor='mm')
    small = font('IBMPlexMono-Bold.ttf', 12)
    f = font('IBMPlexMono-Regular.ttf', 18)
    x0, dx, y0, dy = 32, 40, 238, 29
    for col, lettre in enumerate('LMMJVSD'):
        d.text((x0 + col * dx, 213), lettre, font=small, fill=(150, 60, 50) if col == 6 else (110, 100, 92), anchor='mm')
    d.line([(14, 222), (w - 14, 222)], fill=(190, 180, 164), width=1)
    ink = Image.new('RGBA', (w, h), (0, 0, 0, 0))   # l'encre rouge, sur un calque
    di = ImageDraw.Draw(ink)
    pos = {}
    for day in range(1, 32):
        i = day - 1 + 5                              # le 1er octobre 2016 est un samedi
        row, col = divmod(i, 7)
        x, y = x0 + col * dx, y0 + row * dy
        pos[day] = (x, y)
        d.text((x, y), str(day), font=f, fill=(150, 60, 50) if col == 6 else (50, 44, 40), anchor='mm')
        if day <= 30:
            k = day / 30.0                           # de plus en plus fort
            s = 10 + 5 * k
            wd = 2 if day < 20 else 3
            col_ink = (165 + rng.randint(0, 25), 22 + rng.randint(0, 14), 26 + rng.randint(0, 10), 235)
            for a, b in (((-s, -s * .8), (s, s * .8)), ((s, -s * .8), (-s, s * .8))):
                mid = (x + (a[0] + b[0]) / 2 + rng.uniform(-2, 2), y + (a[1] + b[1]) / 2 + rng.uniform(-2, 2))
                di.line(_wobbly([(x + a[0], y + a[1]), mid, (x + b[0], y + b[1])], rng, 1.2), fill=col_ink, width=wd)
            if day >= 27:                            # repasser plusieurs fois
                di.line(_wobbly([(x - s, y - s * .7), (x + s, y + s * .9)], rng, 1.5), fill=col_ink, width=2)
    # le 31 : le cercle repassé encore et encore
    cx, cy = pos[31]
    rx, ry = 20, 16
    for k in range(14):
        ph = rng.uniform(0, 2 * np.pi)
        a = np.linspace(ph, ph + 2 * np.pi * rng.uniform(1.0, 1.25), 60)
        jr = 1 + 0.08 * np.sin(a * 3 + rng.uniform(0, 6))
        pts = [(cx + rng.uniform(-1.5, 1.5) + rx * jr[j] * np.cos(a[j]), cy + rng.uniform(-1.5, 1.5) + ry * jr[j] * np.sin(a[j]))
               for j in range(len(a))]
        di.line(pts, fill=(150 + rng.randint(0, 40), 14, 18, 220), width=rng.choice([2, 2, 3]))
    img = Image.alpha_composite(img.convert('RGBA'), ink.filter(ImageFilter.GaussianBlur(0.35))).convert('RGB')
    # le trou : une déchirure le long du cercle, en bas à droite, là où la pointe a traversé
    hole = Image.new('L', (w, h), 0)
    dh = ImageDraw.Draw(hole)
    a = np.linspace(-0.75, 2.3, 44)
    wid = 1.5 + 7.5 * np.sin(np.pi * (a - a[0]) / (a[-1] - a[0])) ** 0.7 * (1 + 0.25 * np.sin(a * 7))
    outer = [(cx + (rx + wid[j] * .6 + rng.uniform(-1, 1.2)) * np.cos(a[j]), cy + (ry + wid[j] * .6 + rng.uniform(-1, 1.2)) * np.sin(a[j]))
             for j in range(len(a))]
    inner = [(cx + (rx - wid[j] * .55 + rng.uniform(-1.2, 1)) * np.cos(a[j]), cy + (ry - wid[j] * .55 + rng.uniform(-1.2, 1)) * np.sin(a[j]))
             for j in range(len(a))][::-1]
    dh.polygon(outer + inner, fill=255)
    bx, by = cx + (rx + 1) * np.cos(0.9), cy + (ry + 1) * np.sin(0.9)    # là où la pointe a percé
    dh.polygon([(bx + 9 * np.cos(t) * rng.uniform(.6, 1.15), by + 8 * np.sin(t) * rng.uniform(.6, 1.15))
                for t in np.linspace(0, 2 * np.pi, 18, endpoint=False)], fill=255)
    px, py = cx + rx * np.cos(-1.6), cy + ry * np.sin(-1.6)              # une seconde petite perforation
    dh.polygon([(px + 2.5 * np.cos(t) * rng.uniform(.6, 1.2), py + 2.5 * np.sin(t) * rng.uniform(.6, 1.2))
                for t in np.linspace(0, 2 * np.pi, 9, endpoint=False)], fill=255)
    # un lambeau de papier replié vers l'intérieur du trou
    fx, fy = cx + (rx + 2) * np.cos(0.35), cy + (ry + 2) * np.sin(0.35)
    flap = [(fx - 2, fy - 4), (fx + 3, fy - 2), (fx - 3, fy + 5)]
    m = np.asarray(hole).astype(np.float32) / 255.0
    rim = np.asarray(hole.filter(ImageFilter.MaxFilter(3))).astype(np.float32) / 255.0 - m
    rim *= rs.rand(h, w) < 0.7                                           # fibres déchirées, irrégulières
    halo = np.asarray(hole.filter(ImageFilter.GaussianBlur(3))).astype(np.float32) / 255.0
    arr = _to_arr(img)
    crush = 0.5 * np.clip(halo * 2, 0, 1) * (1 - m)                      # encre et papier écrasés autour
    arr = arr * (1 - crush[..., None]) + arr * np.array([0.7, 0.2, 0.2]) * crush[..., None]
    arr = arr * (1 - rim[..., None] * 0.85) + rim[..., None] * np.array([0.95, 0.93, 0.87]) * 0.85  # fibres claires
    # derrière le trou : le mur, dans l'ombre, un peu plus clair d'un côté (épaisseur du papier)
    inner_light = np.asarray(hole.filter(ImageFilter.GaussianBlur(2))).astype(np.float32) / 255.0
    void = np.array([0.06, 0.05, 0.045]) * (0.6 + 0.8 * (1 - inner_light))[..., None] + 0.02 * rs.rand(h, w, 1)
    arr = arr * (1 - m[..., None]) + void * m[..., None]
    img = _to_img(arr)
    ImageDraw.Draw(img).polygon(flap, fill=(176, 160, 140))
    arr = _to_arr(img)
    # papier jauni, gondolé
    stain = fbm_tile(512, 2.3, 3011)[:h, :w]
    arr *= (0.88 + 0.16 * stain)[..., None] * np.array([1.0, 0.98, 0.93])
    img = _grime_local(_to_img(arr), .7, rng)
    img.save(os.path.join(IMG, 'calendar.png'))


def floppy_label_albert():
    """Étiquette de disquette jaunie : « RUNTIME — SAUV. 01/11/99 » tapé à la machine, et par-dessus,
    au feutre noir, de travers, l'écriture d'Albert : NE PAS JOUER."""
    w, h = 256, 96
    rng = random.Random(302)
    rs = np.random.RandomState(302)
    stain = fbm_tile(256, 2.4, 3021)[:h, :w]
    fib = fbm_tile(256, 0.5, 3022)[:h, :w]
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
    arr = np.array([0.89, 0.84, 0.66]) * ((0.86 + 0.18 * stain) * (0.96 + 0.06 * fib)
                                          * (0.8 + 0.2 * np.clip(edge / 9.0, 0, 1)))[..., None]
    img = _to_img(arr)
    d = ImageDraw.Draw(img)
    for y in (38, 60, 82):                                   # lignes pré-imprimées
        d.line([(8, y), (w - 9, y)], fill=(168, 160, 150), width=1)
    d.rectangle([0, 0, w - 1, 4], fill=(150, 48, 40))         # liseré rouge du haut de l'étiquette
    # la machine à écrire : chaque lettre un peu décalée, plus ou moins encrée
    typed = Image.new('L', (w, h), 0)
    dt = ImageDraw.Draw(typed)
    tf = font('IBMPlexMono-Regular.ttf', 15)
    txt = 'RUNTIME — SAUV. 01/11/99'
    adv = tf.getlength('M')
    x0 = (w - adv * len(txt)) / 2
    for i, ch in enumerate(txt):
        dt.text((x0 + i * adv + rng.uniform(-.3, .3), 22 + rng.uniform(-.7, .7)), ch, font=tf,
                fill=int(255 * rng.uniform(.62, 1.0)), anchor='lm')
    t = np.asarray(typed.filter(ImageFilter.GaussianBlur(.45))).astype(np.float32) / 255.0
    t = np.clip(t * (0.8 + 0.35 * rs.rand(h, w)), 0, 1)    # ruban fatigué
    arr = _to_arr(img)
    arr = arr * (1 - t[..., None] * .92) + np.array([0.1, 0.09, 0.12]) * t[..., None] * .92
    # le feutre : gros trait noir, penché, qui déborde sur le texte tapé
    hand = None
    for size in range(64, 30, -2):
        hand = font('ReenieBeanie.ttf', size)
        x_a, y_a, x_b, y_b = hand.getbbox('NE PAS JOUER', stroke_width=2)
        if x_b - x_a < 226:
            break
    big = Image.new('L', (w * 2, h * 2), 0)
    db = ImageDraw.Draw(big)
    cx, cy = w, h + 8
    words = [('NE', -.9), ('PAS', .1), ('JOUER', 1.0)]   # chaque mot un peu plus bas : la main qui descend
    total = hand.getlength('NE PAS JOUER')
    x = cx - total / 2
    for word, drop in words:
        db.text((x, cy + drop * 3), word, font=hand, fill=255, anchor='lm', stroke_width=2, stroke_fill=255)
        x += hand.getlength(word + ' ')
    big = big.rotate(-7.5, resample=Image.BICUBIC, center=(cx, cy))
    big = big.crop((w // 2, h // 2, w // 2 + w, h // 2 + h))
    m = np.asarray(big.filter(ImageFilter.GaussianBlur(.6))).astype(np.float32) / 255.0
    streak = 0.88 + 0.12 * np.repeat(rs.rand(1, w), h, axis=0)   # feutre qui sèche un peu
    m = np.clip(m * 1.15, 0, 1) * streak
    arr = arr * (1 - m[..., None] * .93) + np.array([0.05, 0.045, 0.05]) * m[..., None] * .93
    _grime_local(_to_img(arr), .45, rng).save(os.path.join(IMG, 'floppy_label.png'))


PHOTO_DATE = "'16 10 31"   # dateur orange dans le coin de la photo (appareil réglé sur l'année, mois, jour)


def photo_manon():
    """Photo jaunie de 2016 : Manon, de dos et de trois-quarts, assise à son bureau devant un écran
    cathodique vert, dans cette même chambre. Son visage a été rayé au stylo à bille."""
    w, h = 300, 220
    rng = random.Random(303)
    rs = np.random.RandomState(303)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    scx, scy = 207.0, 92.0                                   # centre de l'écran
    glow = np.exp(-(((xx - scx) / 85) ** 2 + ((yy - scy) / 70) ** 2))
    glow_wide = np.exp(-(((xx - scx) / 170) ** 2 + ((yy - scy) / 130) ** 2))
    green = np.array([0.32, 0.78, 0.42])
    # la pièce : mur sombre à rayures, fenêtre de nuit à gauche, une affiche
    stripes = 0.92 + 0.08 * (np.sin(xx * 0.42) > 0)
    arr = (np.array([0.10, 0.085, 0.07]) * stripes[..., None]
           + green * (glow * 0.55 + glow_wide * 0.12)[..., None] * stripes[..., None])
    img = _to_img(arr)
    d = ImageDraw.Draw(img)
    d.rectangle([6, 14, 58, 104], fill=(14, 20, 34))                      # fenêtre noire bleutée
    d.line([(32, 14), (32, 104)], fill=(6, 6, 8), width=3)
    d.line([(6, 58), (58, 58)], fill=(6, 6, 8), width=3)
    d.rectangle([0, 8, 14, 120], fill=(26, 20, 18))                       # rideau
    d.rectangle([94, 18, 132, 66], fill=(46, 52, 44))                     # affiche, à peine éclairée
    d.rectangle([98, 22, 128, 46], fill=(30, 34, 30))
    # le bureau
    d.polygon([(70, 150), (300, 142), (300, 220), (70, 220)], fill=(34, 30, 24))
    d.polygon([(70, 150), (300, 142), (300, 150), (70, 158)], fill=(70, 96, 70))   # chant éclairé
    # l'écran cathodique : caisse beige, dalle verte bombée
    d.polygon([(158, 50), (256, 46), (262, 142), (152, 146)], fill=(64, 70, 58))
    d.rectangle([174, 142, 238, 150], fill=(44, 46, 40))                   # pied
    d.polygon([(164, 160), (250, 156), (256, 170), (160, 174)], fill=(40, 44, 38))   # clavier
    for k in range(4):
        d.line([(166 + k, 163 + k * 3), (250 + k, 159 + k * 3)], fill=(70, 96, 72), width=1)
    scr = Image.new('L', (w, h), 0)
    ds = ImageDraw.Draw(scr)
    ds.rounded_rectangle([170, 60, 246, 128], radius=9, fill=255)
    sm = np.asarray(scr.filter(ImageFilter.GaussianBlur(1.0))).astype(np.float32) / 255.0
    curve = 1 - 0.45 * (((xx - 208) / 40) ** 2 + ((yy - 94) / 36) ** 2)  # coins plus sombres
    lines = 0.82 + 0.18 * (np.sin(yy * np.pi / 1.5) > 0)                  # lignes de balayage
    text = np.ones_like(xx)
    for r in range(8):                                                     # lignes de texte vert pâle
        ty = 66 + r * 7
        ln = rng.randint(20, 66)
        text[ty:ty + 3, 176:176 + ln] = 1.35
    arr = _to_arr(img)
    screen = np.array([0.5, 1.0, 0.6]) * (np.clip(curve, 0, 1) * lines * text * 0.85)[..., None]
    arr = arr * (1 - sm[..., None]) + screen * sm[..., None]
    # Manon, de dos, tournée vers l'écran : une silhouette en contre-jour
    sil = Image.new('L', (w, h), 0)
    dp = ImageDraw.Draw(sil)
    dp.ellipse([97, 62, 141, 112], fill=255)                               # tête
    dp.polygon([(98, 88), (140, 84), (147, 116), (151, 146), (124, 152), (93, 148), (95, 116)], fill=255)  # cheveux
    dp.ellipse([70, 122, 170, 172], fill=255)                              # épaules arrondies
    dp.polygon([(72, 146), (168, 146), (160, 220), (80, 220)], fill=255)   # dos
    dp.line([(158, 138), (182, 160), (204, 160)], fill=255, width=13, joint='curve')  # bras vers le clavier
    dp.ellipse([198, 154, 212, 165], fill=255)                             # main
    dp.rounded_rectangle([54, 158, 84, 220], radius=5, fill=255)           # dossier de la chaise
    s = np.asarray(sil.filter(ImageFilter.GaussianBlur(.8))).astype(np.float32) / 255.0
    body = np.array([0.03, 0.035, 0.03])
    arr = arr * (1 - s[..., None]) + body * s[..., None]
    # liseré vert sur les bords tournés vers l'écran (contre-jour)
    shifted = np.roll(s, -3, axis=1)
    rim = np.clip(s - shifted, 0, 1) * np.clip(glow * 2.2, 0, 1)
    arr += green * rim[..., None] * 0.9
    # la joue, de trois-quarts, à peine éclairée par l'écran
    cheek = Image.new('L', (w, h), 0)
    ImageDraw.Draw(cheek).chord([116, 68, 144, 110], -80, 80, fill=255)
    c = np.asarray(cheek.filter(ImageFilter.GaussianBlur(1.5))).astype(np.float32) / 255.0
    arr += np.array([0.1, 0.26, 0.14]) * c[..., None]
    hair = Image.new('L', (w, h), 0)                                       # mèches éclairées
    dhr = ImageDraw.Draw(hair)
    for k in range(9):
        x = 128 + rng.uniform(0, 12)
        dhr.line([(x, 66 + rng.uniform(0, 8)), (x + rng.uniform(6, 14), 118 + rng.uniform(0, 28))], fill=150, width=1)
    hm = np.asarray(hair.filter(ImageFilter.GaussianBlur(.5))).astype(np.float32) / 255.0 * s
    arr += green * hm[..., None] * 0.35
    # dateur orange
    stamp = Image.new('L', (w, h), 0)
    ImageDraw.Draw(stamp).text((w - 12, h - 12), PHOTO_DATE, font=font('IBMPlexMono-Bold.ttf', 12), fill=255, anchor='rb')
    st = np.asarray(stamp).astype(np.float32) / 255.0
    stg = np.asarray(stamp.filter(ImageFilter.GaussianBlur(1.6))).astype(np.float32) / 255.0
    arr += np.array([1.0, 0.5, 0.12]) * np.clip(st * .8 + stg * .5, 0, 1)[..., None]
    # tirage de 2016 qui a vieilli : flou, grain, noirs délavés, jaunissement, vignette
    img = _to_img(arr).filter(ImageFilter.GaussianBlur(.7))
    arr = _to_arr(img)
    arr += rs.randn(h, w, 1) * 0.025 + rs.randn(h, w, 3) * 0.01
    lum = arr @ np.array([0.3, 0.55, 0.15])
    arr = arr * 0.72 + (lum[..., None] * np.array([1.05, 0.95, 0.7])) * 0.28
    arr = 0.12 + arr * 0.86
    arr *= np.array([1.0, 0.93, 0.7])
    vig = 1 - 0.35 * (((xx - w / 2) / (w * .62)) ** 2 + ((yy - h / 2) / (h * .62)) ** 2)
    stain = fbm_tile(512, 2.4, 3031)[:h, :w]
    arr *= (vig * (0.9 + 0.16 * stain))[..., None]
    img = _grime_local(_to_img(arr), .9, rng)
    # le visage rayé au stylo à bille, par-dessus le tirage : des allers-retours serrés, rageurs
    ink = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    di = ImageDraw.Draw(ink)
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
        di.line(pts, fill=(14, 12, 22, 225), width=1)
        if layer % 2:                                                       # reflet de l'encre fraîche
            di.line([(x + 1, y) for x, y in pts[::4]], fill=(96, 104, 140, 45), width=1)
    for k in range(7):                                                     # quelques coups qui débordent
        a0 = rng.uniform(0, 2 * np.pi)
        r0 = rng.uniform(14, 22)
        di.line([(fx + r0 * np.cos(a0), fy + r0 * np.sin(a0)),
                 (fx - (r0 + rng.uniform(6, 16)) * np.cos(a0), fy - (r0 + rng.uniform(4, 12)) * np.sin(a0))],
                fill=(14, 12, 22, 210), width=rng.choice([1, 2]))
    for k in range(4):                                                     # sillons clairs dans l'émulsion
        a0 = rng.uniform(0, 2 * np.pi)
        pts = [(fx + rng.uniform(-8, 8), fy + rng.uniform(-10, 10))]
        for j in range(5):
            a0 += rng.uniform(-0.5, 0.5)
            pts.append((pts[-1][0] + 5 * np.cos(a0), pts[-1][1] + 5 * np.sin(a0)))
        di.line(pts, fill=(214, 206, 184, 85), width=1)
    img = Image.alpha_composite(img.convert('RGBA'), ink.filter(ImageFilter.GaussianBlur(.3))).convert('RGB')
    framed = Image.new('RGB', (w + 24, h + 24), (226, 218, 196))
    framed.paste(img, (12, 12))
    fa = _to_arr(framed)
    fs = fbm_tile(512, 2.2, 3032)[:h + 24, :w + 24]
    fa *= (0.9 + 0.12 * fs)[..., None] * np.array([1.0, 0.98, 0.9])
    _to_img(fa).save(os.path.join(IMG, 'photo.png'))


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


def ceraf_label():
    """Autocollant d'inventaire en alu brossé, usé : CERAF · INVENTAIRE N° 0312, code-barres,
    PROPRIÉTÉ DU CERAF — NE PAS SORTIR DU SITE. Collé sur le matériel qu'Albert a ramené du labo."""
    w, h = 256, 96
    rng = random.Random(304)
    rs = np.random.RandomState(304)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    # alu brossé : stries horizontales (bruit étalé le long de x), reflet en bande
    raw = rs.randn(h, w + 64)
    k = np.ones(48) / 48
    brushed = np.array([np.convolve(r, k, mode='same') for r in raw])[:, 32:32 + w]
    brushed = brushed / (np.abs(brushed).max() + 1e-9)
    sheen = 0.58 + 0.28 * np.exp(-((yy - 26 - 0.12 * xx) / 26) ** 2)
    metal = sheen + 0.07 * brushed + 0.02 * rs.randn(h, w)
    metal = metal[..., None] * np.array([0.97, 0.98, 1.0])
    # tout ce qui est imprimé en noir, sur un masque
    ink = Image.new('L', (w, h), 0)
    di = ImageDraw.Draw(ink)
    di.rectangle([5, 5, w - 6, 28], fill=255)                                # bandeau noir
    di.text((w / 2, 17), 'CERAF · INVENTAIRE N° 0312', font=font('IBMPlexMono-Bold.ttf', 14), fill=0, anchor='mm')
    x = 14
    for wd, bar in _code39('0312'):
        if bar:
            di.rectangle([x, 35, x + wd - 1, 62], fill=255)
        x += wd
    di.text((14 + (x - 14) / 2, 69), '0312', font=font('IBMPlexMono-Regular.ttf', 10), fill=255, anchor='mm')
    di.text((178, 47), 'N° 0312', font=font('IBMPlexMono-Bold.ttf', 24), fill=255, anchor='mm')
    di.line([(118, 63), (w - 10, 63)], fill=255, width=1)
    di.text((w / 2, 83), 'PROPRIÉTÉ DU CERAF — NE PAS SORTIR DU SITE', font=font('IBMPlexMono-Bold.ttf', 9),
            fill=255, anchor='mm')
    di.rectangle([2, 2, w - 3, h - 3], outline=255, width=1)                 # filet du bord
    m = np.asarray(ink).astype(np.float32) / 255.0
    # usure : l'encre part sur les bords, aux frottements et le long des rayures
    wear = fbm_tile(256, 1.6, 3041)[:h, :w]
    edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
    keep = np.clip((wear + 0.55 * np.clip(edge / 14, 0, 1) - 0.42) * 6, 0, 1)
    scr = Image.new('L', (w, h), 0)
    dsc = ImageDraw.Draw(scr)
    for _ in range(18):
        x0, y0 = rng.uniform(0, w), rng.uniform(0, h)
        a = rng.uniform(-0.5, 0.5) + (np.pi / 2 if rng.random() < .2 else 0)
        ln = rng.uniform(6, 42)
        dsc.line([(x0, y0), (x0 + ln * np.cos(a), y0 + ln * np.sin(a))], fill=rng.randint(70, 190), width=1)
    sc = np.asarray(scr).astype(np.float32) / 255.0
    m = m * keep * (1 - sc * 0.75)
    arr = metal * (1 - m[..., None]) + np.array([0.06, 0.06, 0.07]) * m[..., None]
    arr += sc[..., None] * 0.12 * (1 - m[..., None])                         # rayures brillantes dans l'alu
    dirt = fbm_tile(256, 2.6, 3042)[:h, :w]
    arr *= (0.78 + 0.25 * dirt * (0.6 + 0.4 * np.clip(edge / 10, 0, 1)))[..., None]
    arr *= (0.75 + 0.25 * np.clip(edge / 4, 0, 1))[..., None]                # bords encrassés
    # le coin en bas à droite se décolle
    img = _to_img(arr)
    d = ImageDraw.Draw(img)
    d.polygon([(w - 1, h - 16), (w - 1, h - 1), (w - 16, h - 1)], fill=(40, 40, 42))
    d.polygon([(w - 1, h - 16), (w - 12, h - 12), (w - 16, h - 1)], fill=(206, 204, 196))
    d.line([(w - 1, h - 16), (w - 16, h - 1)], fill=(120, 118, 112), width=1)
    img.save(os.path.join(IMG, 'ceraf_label.png'))


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


STORY = [calendar_octobre, floppy_label_albert, photo_manon, ceraf_label, snore, breath_slow, door_slide]


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


def tin_lid():
    """Couvercle de la boîte à biscuits bleue d'Henriette (boîte danoise en fer, vue de dessus) :
    bleu roi, frise blanche, filets dorés, médaillon crème avec un village danois dessiné en bleu
    (maisons à pignons à redans, église, moulin). Rayé, frotté sur le bord, quelques points de rouille.
    512 × 512, RGBA : hors du disque, alpha 0 (la couleur du bord reste dessous)."""
    n = 512
    rng, _rs = _rngs(315)
    c = n / 2
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot(xx - c + 0.5, yy - c + 0.5) / (c - 3)
    th = np.arctan2(yy - c, xx - c)
    blue = np.array([0.075, 0.17, 0.47])
    gold = np.array([0.74, 0.6, 0.3])
    cream = np.array([0.92, 0.9, 0.82])
    arr = np.ones((n, n, 3), np.float32) * blue
    arr *= (0.92 + 0.12 * fbm_tile(512, 2.2, 3151))[..., None]           # laque inégale
    # le bord roulé : ombre et lumière d'un cylindre, filet doré
    rim = np.clip((r - 0.935) / 0.065, 0, 1)
    roll = 0.55 + 0.6 * np.clip(np.sin(np.pi * rim), 0, 1) ** 0.7 - 0.25 * rim
    arr = np.where((r > 0.935)[..., None], blue * roll[..., None] * 0.95, arr)
    for r0, wd in ((0.925, 0.006), (0.905, 0.0035), (0.79, 0.0035), (0.655, 0.008), (0.625, 0.003)):
        arr = _lay(arr, np.clip(1 - np.abs(r - r0) / wd, 0, 1), gold)
    # la frise blanche entre deux filets : volutes et points, 32 fois
    ss = 3
    frieze = Image.new('L', (n * ss, n * ss), 0)
    d = ImageDraw.Draw(frieze)
    R = (c - 3) * ss
    for i in range(32):
        a = i * 2 * np.pi / 32
        for sgn in (-1, 1):                                              # deux volutes en C, dos à dos
            pts = []
            for t in np.linspace(0, 1.6 * np.pi, 30):
                rr = 0.848 + 0.03 * np.cos(t) * (1 - t / 6)
                aa = a + sgn * (0.035 + 0.032 * np.sin(t) * (1 - t / 7))
                pts.append((c * ss + R * rr * np.cos(aa), c * ss + R * rr * np.sin(aa)))
            d.line(pts, fill=255, width=int(2.2 * ss), joint='curve')
        ad = a + np.pi / 32                                              # le point entre deux motifs
        for rr, rad in ((0.848, 0.011), (0.88, 0.006), (0.816, 0.006)):
            px, py = c * ss + R * rr * np.cos(ad), c * ss + R * rr * np.sin(ad)
            d.ellipse([px - rad * R, py - rad * R, px + rad * R, py + rad * R], fill=255)
    for i in range(72):                                                  # perles dorées autour du médaillon
        a = i * 2 * np.pi / 72
        px, py = c * ss + R * 0.64 * np.cos(a), c * ss + R * 0.64 * np.sin(a)
        d.ellipse([px - 0.006 * R, py - 0.006 * R, px + 0.006 * R, py + 0.006 * R], fill=128)
    fm = np.asarray(frieze.resize((n, n), Image.BOX)).astype(np.float32) / 255.0
    arr = _lay(arr, np.clip(fm * 2 - 0.0, 0, 1) * (fm > 0.3), cream * 0.97)
    arr = _lay(arr, np.clip((fm - 0.2) * 4, 0, 1) * (np.abs(r - 0.64) < 0.01), gold)
    # le médaillon : un village danois l'hiver, au trait bleu sur fond crème
    med = r < 0.62
    arr = np.where(med[..., None], cream * (0.95 + 0.06 * fbm_tile(512, 1.8, 3152))[..., None], arr)
    scene = Image.new('L', (n * ss, n * ss), 0)
    d = ImageDraw.Draw(scene)
    S = lambda x, y: (c * ss + x * R, c * ss + y * R)                   # coordonnées du médaillon (-0.6..0.6)
    lw = int(1.6 * ss)
    d.line([S(-0.6, 0.2), S(-0.3, 0.17), S(0.0, 0.19), S(0.3, 0.16), S(0.6, 0.18)], fill=255, width=lw)
    d.line([S(-0.55, 0.32), S(-0.1, 0.3), S(0.4, 0.33)], fill=200, width=int(1.2 * ss))

    def house(x0, w_, h_, steps, y0=0.18):
        d.line([S(x0, y0), S(x0, y0 - h_), S(x0 + w_, y0 - h_), S(x0 + w_, y0)], fill=255, width=lw)
        st = []                                                          # pignon à redans
        for k in range(steps + 1):
            fx = k / (steps + 1) / 2
            st += [S(x0 + w_ * fx, y0 - h_ - 0.035 * k), S(x0 + w_ * (fx + 0.5 / (steps + 1)), y0 - h_ - 0.035 * k)]
        top = y0 - h_ - 0.035 * steps
        st += [S(x0 + w_ * 0.5, top - 0.02)]
        for k in range(steps, -1, -1):
            fx = 1 - k / (steps + 1) / 2
            st += [S(x0 + w_ * (fx - 0.5 / (steps + 1)), y0 - h_ - 0.035 * k), S(x0 + w_ * fx, y0 - h_ - 0.035 * k)]
        d.line(st, fill=255, width=lw)
        for wx in np.linspace(x0 + w_ * 0.22, x0 + w_ * 0.78, 2 if w_ < 0.16 else 3):   # fenêtres à croisillons
            d.rectangle([S(wx - 0.018, y0 - h_ * 0.75), S(wx + 0.018, y0 - h_ * 0.4)], outline=255, width=int(1.1 * ss))
            d.line([S(wx, y0 - h_ * 0.75), S(wx, y0 - h_ * 0.4)], fill=255, width=int(0.9 * ss))
        d.rectangle([S(x0 + w_ * 0.45, y0 - h_ * 0.35), S(x0 + w_ * 0.58, y0)], outline=255, width=int(1.1 * ss))
        for k in range(1, 4):                                            # colombages
            d.line([S(x0, y0 - h_ * k / 4 + 0.01), S(x0 + w_, y0 - h_ * k / 4 + 0.01)], fill=150, width=int(0.8 * ss))

    house(-0.47, 0.17, 0.13, 3)
    house(-0.27, 0.13, 0.17, 2)
    house(0.06, 0.15, 0.12, 3)
    # l'église : tour carrée et flèche
    d.line([S(-0.11, 0.18), S(-0.11, -0.12), S(0.02, -0.12), S(0.02, 0.18)], fill=255, width=lw)
    d.line([S(-0.125, -0.12), S(-0.045, -0.36), S(0.035, -0.12)], fill=255, width=lw)
    d.line([S(-0.045, -0.36), S(-0.045, -0.44)], fill=255, width=lw)
    d.line([S(-0.07, -0.41), S(-0.02, -0.41)], fill=255, width=lw)
    d.ellipse([S(-0.07, -0.06), S(-0.02, -0.01)], outline=255, width=int(1.2 * ss))       # l'horloge
    d.arc([S(-0.08, 0.06), S(-0.01, 0.2)], 180, 360, fill=255, width=int(1.2 * ss))
    # le moulin, à droite
    d.line([S(0.33, 0.17), S(0.37, -0.12), S(0.45, -0.12), S(0.49, 0.17)], fill=255, width=lw)
    d.line([S(0.36, -0.12), S(0.41, -0.19), S(0.46, -0.12)], fill=255, width=lw)
    hub = (0.41, -0.15)
    for a in (0.5, 0.5 + np.pi / 2, 0.5 + np.pi, 0.5 + 3 * np.pi / 2):
        e = (hub[0] + 0.16 * np.cos(a), hub[1] + 0.16 * np.sin(a))
        d.line([S(*hub), S(*e)], fill=255, width=lw)
        p1 = (hub[0] + 0.05 * np.cos(a) + 0.03 * np.cos(a + np.pi / 2), hub[1] + 0.05 * np.sin(a) + 0.03 * np.sin(a + np.pi / 2))
        p2 = (e[0] + 0.03 * np.cos(a + np.pi / 2), e[1] + 0.03 * np.sin(a + np.pi / 2))
        d.line([S(*p1), S(*p2), S(*e)], fill=200, width=int(1.1 * ss))
    # un sapin, des flocons, un traîneau
    for k in range(4):
        d.line([S(0.25 - 0.05 + 0.012 * k, 0.17 - 0.07 * k), S(0.25, 0.08 - 0.07 * k), S(0.25 + 0.05 - 0.012 * k, 0.17 - 0.07 * k)],
               fill=255, width=int(1.3 * ss))
    for _ in range(46):
        a_ = rng.uniform(0, 2 * np.pi)
        rr = 0.58 * np.sqrt(rng.random())
        x, y = rr * np.cos(a_), rr * np.sin(a_)
        if y < 0.12 and not (-0.15 < x < 0.06 and y > -0.45):
            d.ellipse([S(x - 0.007, y - 0.007), S(x + 0.007, y + 0.007)], fill=230)
    d.line([S(-0.32, 0.27), S(-0.12, 0.27), S(-0.1, 0.24)], fill=255, width=lw)            # le traîneau
    d.line([S(-0.3, 0.27), S(-0.3, 0.23), S(-0.16, 0.23), S(-0.15, 0.2)], fill=255, width=int(1.2 * ss))
    d.line([S(-0.1, 0.24), S(0.0, 0.25)], fill=180, width=int(0.9 * ss))
    d.ellipse([S(0.0, 0.2), S(0.09, 0.26)], outline=255, width=int(1.2 * ss))               # le cheval, rond comme un biscuit
    d.line([S(0.08, 0.21), S(0.12, 0.16)], fill=255, width=lw)
    for lx in (0.015, 0.035, 0.06, 0.08):
        d.line([S(lx, 0.255), S(lx, 0.29)], fill=255, width=int(1.1 * ss))
    sm = np.asarray(scene.resize((n, n), Image.BOX)).astype(np.float32) / 255.0 * med
    arr = _lay(arr, sm, blue * 1.1, 1.05)
    # usure : rayures qui montrent le fer, frottements sur le bord, points de rouille
    scr = Image.new('L', (n * 2, n * 2), 0)
    ds = ImageDraw.Draw(scr)
    for _ in range(70):
        x, y = rng.uniform(40, n - 40) * 2, rng.uniform(40, n - 40) * 2
        a_ = rng.uniform(0, np.pi)
        ln = rng.uniform(8, 90) * 2
        bend = rng.uniform(-0.15, 0.15)
        pts = [(x + ln * t * np.cos(a_ + bend * t), y + ln * t * np.sin(a_ + bend * t)) for t in np.linspace(0, 1, 8)]
        ds.line(pts, fill=rng.randint(90, 230), width=rng.choice([1, 1, 2]))
    for _ in range(9):                                                   # rayures en arc (boîtes empilées, tournées)
        rr = rng.uniform(0.2, 0.85) * c * 2
        a0 = rng.uniform(0, 360)
        ds.arc([c * 2 - rr, c * 2 - rr, c * 2 + rr, c * 2 + rr], a0, a0 + rng.uniform(15, 60), fill=rng.randint(60, 160), width=1)
    sc = np.asarray(scr.resize((n, n), Image.BOX)).astype(np.float32) / 255.0
    metal = np.array([0.7, 0.7, 0.68])
    arr = _lay(arr, sc * (r < 0.93), metal, 1.4)
    rub = np.clip((fbm_tile(512, 1.4, 3153) - 0.55) * 5, 0, 1) * np.clip((r - 0.92) / 0.05, 0, 1)
    arr = _lay(arr, rub, metal * 0.9)
    rust_n = fbm_tile(512, 1.0, 3154)
    rust = np.clip((rust_n - 0.66) * 8, 0, 1) * np.clip((r - 0.84) / 0.08, 0, 1) * (np.sin(th * 3 + 1) > 0.1)
    arr = _lay(arr, rust, np.array([0.42, 0.22, 0.1]), 0.9)
    dent = fbm_tile(512, 3.2, 3155)
    arr *= (0.9 + 0.16 * dent)[..., None]                               # cabossé, terni, doigts
    alpha = np.clip((1.0 - r) * (c - 3) + 0.5, 0, 1)
    rgb = (np.clip(arr, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(np.dstack([rgb, (alpha * 255).astype(np.uint8)]), 'RGBA').save(os.path.join(IMG, 'tin_lid.png'))


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


def carton_2euros():
    """L'écriteau du vide-grenier d'Henriette : un rabat de carton découpé, « TOUT À 2 € » au gros
    feutre noir, souligné ; un reste d'impression du carton (HAUT, flèches) et du ruban adhésif. 512 × 320."""
    w, h, ss = 512, 320, 2
    rng, _rs = _rngs(317)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    mott = fbm_tile(512, 2.2, 3171)[:h, :w]
    fib = fbm_tile(512, 0.4, 3172)[:h, :w]
    flute = 0.5 + 0.5 * np.cos(xx * 2 * np.pi / 8.5)                    # les cannelures, sous la surface
    kraft = np.array([0.6, 0.45, 0.29])
    arr = kraft * (0.86 + 0.18 * mott + 0.06 * fib + 0.03 * flute)[..., None]
    arr *= (1 - 0.12 * (np.abs(yy - 34) < 1.5))[..., None]               # le pli du rabat
    edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
    arr *= (0.78 + 0.22 * np.clip(edge / 5, 0, 1))[..., None]           # tranches écrasées, plus sombres
    # l'ancienne impression du carton, à moitié coupée
    old = _mask(w, h, ss, lambda d, k: (
        d.text((w * k - 18 * k, 6 * k), 'HAUT', font=font('IBMPlexMono-Bold.ttf', int(26 * k)), fill=255, anchor='ra'),
        [d.polygon([((w - 110 - i * 26) * k, 30 * k), ((w - 100 - i * 26) * k, 12 * k), ((w - 90 - i * 26) * k, 30 * k)], fill=255)
         for i in range(2)],
        [d.line([((w - 100 - i * 26) * k, 30 * k), ((w - 100 - i * 26) * k, 40 * k)], fill=255, width=int(4 * k)) for i in range(2)]))
    arr = _lay(arr, old * (0.35 + 0.25 * fib), np.array([0.45, 0.2, 0.15]))
    # le feutre : gros trait noir, un peu baveux
    for size in range(170, 60, -4):
        hand = font('ReenieBeanie.ttf', size * ss)
        if hand.getlength('TOUT À 2 €') + 9 * ss < 430 * ss:
            break
    big = Image.new('L', (w * ss, h * ss), 0)
    d = ImageDraw.Draw(big)
    x = w * ss / 2 - hand.getlength('TOUT À 2 €', ) / 2
    cap = hand.getbbox('T', anchor='lm')
    for i, word in enumerate(['TOUT', 'À', '2', '€']):
        yc = (158 + [0, 4, -2, 3][i]) * ss
        if word == '2':                                                  # le 2 d'Henriette, bien rond (celui de la police ressemble à un z)
            ch = cap[3] - cap[1]
            x0, y0 = x + 0.05 * ch, yc + cap[1]
            arc = [(x0 + 0.3 * ch + 0.29 * ch * np.cos(a), y0 + 0.3 * ch + 0.3 * ch * np.sin(a))
                   for a in np.linspace(-2.7, 0.55, 18)]
            path = [(x0 + 0.02 * ch, y0 + 0.32 * ch)] + arc + [(x0 + 0.02 * ch, y0 + 0.98 * ch), (x0 + 0.68 * ch, y0 + 0.95 * ch)]
            d.line(path, fill=255, width=int(13 * ss), joint='curve')
            x += 0.75 * ch + hand.getlength(' ')
            continue
        d.text((x, yc), word, font=hand, fill=255, anchor='lm', stroke_width=int(4.5 * ss), stroke_fill=255)
        x += hand.getlength(word + ' ')
    pts = [(62 + t * 392, 218 + 5 * np.sin(t * 5.5) - 10 * t) for t in np.linspace(0, 1, 30)]
    d.line([(px * ss, py * ss) for px, py in pts], fill=255, width=int(6 * ss), joint='curve')
    big = big.rotate(2.5, resample=Image.BICUBIC, center=(w * ss / 2, h * ss / 2))
    m = np.asarray(big.resize((w, h), Image.BOX)).astype(np.float32) / 255.0
    bleed = _gblur(m, 1.4)
    dry = 0.8 + 0.2 * np.clip(fbm_tile(512, 0.6, 3173)[:h, :w] * 1.6, 0, 1)
    arr = _lay(arr, np.clip(bleed * 0.35, 0, 1), np.array([0.2, 0.15, 0.1]))
    arr = _lay(arr, m * dry, np.array([0.04, 0.035, 0.04]))
    # du ruban adhésif marron sur un coin, du transparent jauni sur l'autre
    tape = _mask(w, h, ss, lambda d, k: d.polygon([(0, 52 * k), (52 * k, 0), (92 * k, 0), (0, 92 * k)], fill=255))
    arr = _lay(arr, tape * 0.6, np.array([0.5, 0.31, 0.12]))
    arr += (tape * 0.06 * (0.5 + fib))[..., None]
    clear = _mask(w, h, ss, lambda d, k: d.polygon([((w - 120) * k, h * k), ((w - 70) * k, (h - 70) * k),
                                                     ((w - 40) * k, (h - 40) * k), ((w - 90) * k, h * k)], fill=255))
    arr = arr * (1 - clear[..., None] * 0.08) + clear[..., None] * np.array([0.08, 0.07, 0.02])
    _grime_local(_to_img(arr), 0.6, rng).save(os.path.join(IMG, 'carton_2euros.png'))


def postit_chocolat():
    """Le post-it collé sur l'ordinateur portable d'Henriette : « mot de passe : CHOCOLAT », de son
    écriture penchée et tremblée, au stylo bille bleu, CHOCOLAT souligné deux fois. 256 × 256."""
    n, ss = 256, 3
    rng, _rs = _rngs(318)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    yellow = np.array([0.98, 0.88, 0.4])
    arr = yellow * (0.95 + 0.06 * fbm_tile(256, 1.4, 3181))[..., None]
    arr = arr * (1 - 0.05 * (yy < 46))[..., None]                         # la bande de colle
    arr = arr * (1 + 0.06 * np.clip((yy - 180) / 76, 0, 1) ** 2)[..., None]   # le bas qui rebique
    arr *= (0.93 + 0.07 * np.clip(np.minimum(np.minimum(xx, n - 1 - xx), np.minimum(yy, n - 1 - yy)) / 4, 0, 1))[..., None]
    ink = Image.new('L', (n * ss, n * ss), 0)
    for txt, (cx, cy), size, ang in (('mot de passe :', (128, 84), 46, 6), ('CHOCOLAT', (128, 152), 62, 4)):
        for i in range(2):                                              # le stylo repasse, la main tremble
            _hand_text(ink, ((cx + i * 0.6) * ss, (cy + i * 0.4) * ss), txt, font('ReenieBeanie.ttf', size * ss),
                       ang + rng.uniform(-0.6, 0.6), 230 - 60 * i, shear=-0.28)
    d = ImageDraw.Draw(ink)
    for j, yb in enumerate((188, 197)):
        pts = [(46 + t * 168, yb - 8 * t + 1.6 * np.sin(t * 31 + j) + rng.uniform(-0.4, 0.4)) for t in np.linspace(0, 1, 40)]
        d.line([(x * ss, y * ss) for x, y in pts], fill=225, width=int(1.6 * ss), joint='curve')
    m = np.asarray(ink.resize((n, n), Image.BOX)).astype(np.float32) / 255.0
    m *= 0.8 + 0.2 * fbm_tile(256, 1.2, 3182)
    arr = _lay(arr, m, np.array([0.12, 0.17, 0.5]))
    _grime_local(_to_img(arr), 0.12, rng).save(os.path.join(IMG, 'postit_chocolat.png'))


def tableau_cles():
    """Le tableau à clés d'Albert : planche vernie, sept crochets de laiton sous sept étiquettes en relief
    (étiqueteuse à ruban : CAVE, ESCALIER, CUISINE, BIBLIO, CELLIER, BUREAU, LINGERIE). Tous les
    crochets sont vides : sous chacun, le bois resté clair dessine la clé qui n'est plus là.
    512 × 384. Crochets (u, v) : rangée 1 en v = 0,22, u = 0,125 / 0,375 / 0,625 / 0,875 ;
    rangée 2 en v = 0,635, u = 0,25 / 0,5 / 0,75."""
    w, h, ss = 512, 384, 3
    rng, _rs = _rngs(319)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    grain = fbm_tile(512, 1.6, 3191)[:h, :w]
    rings = np.sin((yy + 26 * fbm_tile(512, 2.4, 3192)[:h, :w]) * 0.55 + xx * 0.012)
    wood = np.array([0.5, 0.32, 0.15])
    arr = wood * (0.8 + 0.18 * grain + 0.07 * rings)[..., None]
    # la clé fantôme sous chaque crochet : le bois protégé de la lumière, resté plus clair
    names = ['CAVE', 'ESCALIER', 'CUISINE', 'BIBLIO', 'CELLIER', 'BUREAU', 'LINGERIE']
    hooks = [(64, 84), (192, 84), (320, 84), (448, 84), (128, 244), (256, 244), (384, 244)]

    def ghosts(d, k):
        for i, (hx, hy) in enumerate(hooks):
            sw = rng.uniform(-0.08, 0.08)                                # la clé pendait un peu de travers
            X = lambda x, t, hx=hx, sw=sw: (hx + x + sw * t) * k
            Y = lambda t, hy=hy: (hy + t) * k
            d.ellipse([X(-11, 12), Y(2), X(11, 12), Y(24)], outline=255, width=int(3 * k))           # l'anneau
            d.rounded_rectangle([X(-10, 34), Y(22), X(10, 34), Y(42)], radius=int(7 * k), fill=255)  # la tête
            d.ellipse([X(-3, 30), Y(27), X(3, 30), Y(33)], fill=0)
            d.rectangle([X(-2.5, 60), Y(42), X(2.5, 60), Y(84)], fill=255)                       # la tige
            for j in range(3):                                           # le panneton
                d.rectangle([X(2, 70 + 5 * j), Y(66 + 6 * j), X(6 + rng.randint(1, 5), 70 + 5 * j), Y(70 + 6 * j)], fill=255)

    g = _gblur(_mask(w, h, ss, ghosts), 0.9)
    arr = arr * (1 + 0.13 * g[..., None]) + g[..., None] * np.array([0.02, 0.012, 0.0])
    # le cadre mouluré
    edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
    frame = edge < 16
    arr = np.where(frame[..., None], arr * 0.72, arr)
    arr *= (1 + 0.28 * np.clip(1 - np.abs(edge - 4) / 3, 0, 1) - 0.3 * np.clip(1 - np.abs(edge - 15) / 2, 0, 1))[..., None]
    # rayures en arc sous les crochets : les clés qui se balançaient
    scr = Image.new('L', (w * 2, h * 2), 0)
    ds = ImageDraw.Draw(scr)
    for (hx, hy) in hooks:
        for _ in range(5):
            rr = rng.uniform(30, 60) * 2
            a0 = rng.uniform(55, 80)
            ds.arc([(hx * 2 - rr), (hy * 2 + 4 - rr), (hx * 2 + rr), (hy * 2 + 4 + rr)], a0, a0 + rng.uniform(15, 40),
                   fill=rng.randint(60, 140), width=1)
    sc = np.asarray(scr.resize((w, h), Image.BOX)).astype(np.float32) / 255.0
    arr = _lay(arr, sc, np.array([0.78, 0.6, 0.38]), 0.8)
    # les crochets en laiton et leur ombre
    hk = Image.new('L', (w * ss, h * ss), 0)
    dh = ImageDraw.Draw(hk)
    for (hx, hy) in hooks:
        dh.ellipse([(hx - 5) * ss, (hy - 13) * ss, (hx + 5) * ss, (hy - 3) * ss], fill=255)          # la rosace
        dh.line([(hx * ss, (hy - 8) * ss), (hx * ss, (hy + 4) * ss)], fill=255, width=int(3 * ss))
        dh.arc([(hx - 7) * ss, (hy - 4) * ss, (hx + 7) * ss, (hy + 10) * ss], 0, 180, fill=255, width=int(3 * ss))
        dh.line([((hx + 7) * ss, (hy + 3) * ss), ((hx + 7) * ss, (hy - 1) * ss)], fill=255, width=int(3 * ss))
    hm = np.asarray(hk.resize((w, h), Image.BOX)).astype(np.float32) / 255.0
    shadow = np.roll(np.roll(_gblur(hm, 2.0), 3, 0), 2, 1)
    arr *= (1 - 0.5 * shadow)[..., None]
    shine = 0.75 + 0.5 * np.clip(np.roll(hm, 1, 1) - hm + 0.5, 0, 1)
    arr = _lay(arr, hm, np.array([0.7, 0.55, 0.25]) * shine[..., None] * 0.85)
    # les étiquettes en relief : ruban noir brillant, lettres blanchies par l'embossage
    lab = Image.new('L', (w * ss, h * ss), 0)
    txt = Image.new('L', (w * ss, h * ss), 0)
    f = font('IBMPlexMono-Bold.ttf', 18 * ss)
    for (hx, hy), name in zip(hooks, names):
        tw = f.getlength(name) + 2.2 * ss * (len(name) - 1)
        lw_ = tw / ss + 18
        cy = hy - 34
        r_ = [hx - lw_ / 2, cy - 13, hx + lw_ / 2, cy + 13]
        tmp_l = Image.new('L', (w * ss, h * ss), 0)
        tmp_t = Image.new('L', (w * ss, h * ss), 0)
        ImageDraw.Draw(tmp_l).rounded_rectangle([v * ss for v in r_], radius=int(3 * ss), fill=255)
        x = hx * ss - tw / 2
        for ch in name:
            ImageDraw.Draw(tmp_t).text((x, cy * ss + 1 * ss), ch, font=f, fill=255, anchor='lm')
            x += f.getlength(ch) + 2.2 * ss
        ang = rng.uniform(-1.2, 1.2)
        from PIL import ImageChops
        lab = ImageChops.lighter(lab, tmp_l.rotate(ang, resample=Image.BICUBIC, center=(hx * ss, cy * ss)))
        txt = ImageChops.lighter(txt, tmp_t.rotate(ang, resample=Image.BICUBIC, center=(hx * ss, cy * ss)))
    lm = np.asarray(lab.resize((w, h), Image.BOX)).astype(np.float32) / 255.0
    tm = np.asarray(txt.resize((w, h), Image.BOX)).astype(np.float32) / 255.0 * lm
    arr *= (1 - 0.35 * np.roll(np.roll(_gblur(lm, 1.5), 2, 0), 1, 1) * (1 - lm))[..., None]  # ombre portée
    arr = _lay(arr, lm, np.array([0.07, 0.07, 0.08]))
    top_band = lm * np.clip(lm - np.roll(lm, 4, 0), 0, 1)                # reflet sur le haut du ruban
    arr += top_band[..., None] * 0.18
    sh_t, hl_t = _emboss(tm)
    letters = np.array([0.86, 0.86, 0.84]) * (0.85 + 0.15 * fbm_tile(512, 0.8, 3193)[:h, :w])[..., None]
    arr = _lay(arr, tm * 0.95, letters)
    arr = arr * (1 - 0.3 * sh_t[..., None]) + 0.1 * hl_t[..., None]
    _grime_local(_to_img(arr), 0.35, rng).save(os.path.join(IMG, 'tableau_cles.png'))


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


FLOOR = [plan_etage, croquis_fractionneur, photo_couloir, silhouette_feed, tin_lid, clovis_plaque, carton_2euros,
         postit_chocolat, tableau_cles, portrait_1996, modem_chant, hum_move, chirps, babyphone_breath, pipe_knock,
         printer, fans_spinup, servo, curtain_rings, drip, wet_steps, heartbeat_loop, breath_near]


if __name__ == '__main__':
    import sys
    if len(sys.argv) > 1:   # ne régénérer que certaines ressources : make_assets.py house | music | story | floor
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
        print('ok')
        raise SystemExit
    photo()
    poster_choisis()
    poster_spectres()
    note()
    floppy_label()
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
    calendar()
    corkboard()
    clock_face()
    poster_corbeaux()
    papers()
    vhs_label()
    neighbor_window()
    rain_loop()
    thunder()
    for f in HOUSE:
        f()
    for f in MUSIC:
        f()
    for f in STORY:   # remplace calendar.png, floppy_label.png et photo.png
        f()
    for f in FLOOR:   # v0.3.1 : l'étage
        f()
    print('ok')
