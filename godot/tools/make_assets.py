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


if __name__ == '__main__':
    photo()
    poster_choisis()
    poster_spectres()
    note()
    floppy_label()
    room_tone()
    crt_hum()
    drive_seek()
    print('ok')
