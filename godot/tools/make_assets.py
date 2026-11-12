"""Génère les images et sons « faits maison » du jeu (affiches, mot, étiquette, ambiances).

Usage : python3 godot/tools/make_assets.py
        python3 godot/tools/make_assets.py story   (seulement l'acte I ; aussi : house, music)
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


if __name__ == '__main__':
    import sys
    if len(sys.argv) > 1:   # ne régénérer que certaines ressources : make_assets.py house | music | story
        if 'house' in sys.argv:
            for f in HOUSE:
                f()
        if 'music' in sys.argv:
            for f in MUSIC:
                f()
        if 'story' in sys.argv:
            for f in STORY:
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
    for f in STORY:   # en dernier : remplace calendar.png, floppy_label.png et photo.png
        f()
    print('ok')
