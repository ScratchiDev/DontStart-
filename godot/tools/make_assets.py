"""Génère les images et sons « faits maison » du jeu (affiches, mot, étiquette, ambiances).

Usage : python3 godot/tools/make_assets.py
Dépendances : Pillow, numpy. Les polices viennent de godot/assets/fonts (licence OFL).
Ce dossier contient un fichier .gdignore : Godot ne l'importe pas.
"""
import os
import random
import wave

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


if __name__ == '__main__':
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
    print('ok')
