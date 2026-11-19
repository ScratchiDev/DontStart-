"""Pas du joueur et lattes qui grincent (passe « triple A », lot V2-PRESENCE).

Usage : python3 -I godot/tools/make_pas.py            (écrit godot/assets/audio/pas/*.wav)
        python3 -I godot/tools/make_pas.py --rapport  (et, pour chaque son, durée, crête, bandes d'énergie)
Dépendances : numpy, et ffmpeg pour lire les .ogg. Ce dossier contient un .gdignore : Godot ne l'importe pas.

Sources, toutes CC0 et déjà dans le jeu (CREDITS.md) : Kenney « RPG Audio » (footstep00 à 09, creak1 à 3,
cloth1 et 2) et Kenney « Impact Sounds » (footstep_carpet_000 et 001, kenney/footstep_carpet_003,
kenney/footstep_concrete_000 à 004, kenney/impactPlank_medium_000 à 004, kenney/impactSoft_medium_000 à 002,
kenney/impactWood_light_000 à 002, kenney/impactTin_medium_000 à 002). footstep_wood_* n'est plus utilisé : 5 ms de choc puis un palier continu
(décalage à -42 dBFS) coupé net, sans bois audible.

Ce que fait l'outil :
- nettoyage de chaque source : passe-haut à 30 Hz (4e ordre : plus de décalage continu ni de palier),
  début ramené à 2 ms avant l'attaque, queue sous -60 dB retirée, fondu de sortie (plus de clic de fin) ;
- un pas = le TALON d'une prise + la PLANTE d'une autre (les prises RPG Audio en ont deux : on les coupe
  au creux entre les deux chocs), décalée de 55 à 115 ms, avec les couches du sol :
    parquet   : semelle souple sur bois (passe-bas 6 kHz), corps du plancher sur solives (lame Kenney,
                passe-bas 320 Hz, -17 dB), parfois le petit « tic » d'une lame ;
    tapis     : le même pas étouffé (passe-bas 1,4 kHz), le plancher dessous à -24 dB, frottement de laine ;
    moquette  : choc mou (moquette Kenney et choc mou, sous 900 Hz), sans claquement, frottement de fibres ;
    carrelage : coup sourd de la dalle (béton Kenney) et claquement net du talon sur l'émail (2-5 kHz) ;
- 8 variantes par sol, toutes différentes (paires talon/plante, retards, couches, hauteur ±4 %) ;
- lattes : 6 grincements de plancher (craquements RPG Audio ralentis de 0,5 à 0,72, passe-bas, avec le
  « toc » sourd de la lame qui fléchit) ;
- niveau : moyenne quadratique des 100 ms les plus fortes à -20 dBFS, crête bornée à -1 dBFS.
Le hasard est à graine fixe : relancer l'outil redonne les mêmes fichiers.
"""
import os
import subprocess
import sys
import wave

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
AUDIO = os.path.join(ROOT, 'assets', 'audio')
OUT = os.path.join(AUDIO, 'pas')
SR = 44100
RNG = np.random.default_rng(3121)
VARIANTS = 8
LATTES = 6


# ------------------------------------------------------------------ entrée, sortie

def load(rel):
    path = os.path.join(AUDIO, rel)
    raw = subprocess.run(['ffmpeg', '-v', 'quiet', '-i', path, '-f', 'f64le', '-ac', '1', '-ar', str(SR), '-'],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float64).copy()


def write(name, x):
    os.makedirs(OUT, exist_ok=True)
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype(np.int16)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())


# ------------------------------------------------------------------ filtres (biquads RBJ, causaux)

def _biquad(x, b0, b1, b2, a1, a2):
    y = np.empty_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, v
        y2, y1 = y1, o
        y[i] = o
    return y


def _coefs(kind, f, q=0.7071, gain_db=0.0):
    w = 2.0 * np.pi * f / SR
    cw, sw = np.cos(w), np.sin(w)
    al = sw / (2.0 * q)
    A = 10.0 ** (gain_db / 40.0)
    if kind == 'lp':
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        a = [1 + al, -2 * cw, 1 - al]
    elif kind == 'hp':
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        a = [1 + al, -2 * cw, 1 - al]
    else:   # cloche
        b = [1 + al * A, -2 * cw, 1 - al * A]
        a = [1 + al / A, -2 * cw, 1 - al / A]
    return [b[0] / a[0], b[1] / a[0], b[2] / a[0], a[1] / a[0], a[2] / a[0]]


def lp(x, f, order=2):
    for _ in range(order // 2):
        x = _biquad(x, *_coefs('lp', f))
    return x


def hp(x, f, order=2):
    for _ in range(order // 2):
        x = _biquad(x, *_coefs('hp', f))
    return x


def peak(x, f, gain_db, q=1.0):
    return _biquad(x, *_coefs('peak', f, q, gain_db))


# ------------------------------------------------------------------ outils

def env_db(x, win=0.005):
    w = int(win * SR)
    n = max(1, len(x) // w)
    e = np.sqrt((x[:n * w].reshape(n, w) ** 2).mean(1)) + 1e-9
    return 20 * np.log10(e / e.max()), w


def fade(x, fin=0.0, fout=0.03):
    x = x.copy()
    a = int(fin * SR)
    b = min(len(x), int(fout * SR))
    if a > 0:
        x[:a] *= 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, a))
    if b > 0:
        x[-b:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, b))
    return x


def clean(x):
    """Sans décalage ni palier, attaque à 2 ms, queue sous -60 dB coupée, fondu de sortie."""
    x = hp(x - x.mean(), 30.0, 4)
    pk = np.abs(x).max() + 1e-12
    on = int(np.argmax(np.abs(x) > pk * 0.05))
    x = x[max(0, on - int(0.002 * SR)):]
    e, w = env_db(x)
    keep = np.where(e > -60.0)[0]
    end = (keep[-1] + 2) * w if len(keep) else len(x)
    x = x[:min(len(x), end)]
    return fade(x, 0.001, min(0.04, len(x) / SR * 0.3))


def split(x):
    """Talon et plante d'une prise RPG Audio : coupée au creux entre les deux chocs."""
    e, w = env_db(x)
    p1 = int(np.argmax(e[:14]))
    after = e[p1 + 8:]
    if len(after) < 4:
        return x, None
    p2 = p1 + 8 + int(np.argmax(after))
    v = p1 + int(np.argmin(e[p1:p2 + 1]))
    cut = v * w
    heel = fade(x[:cut + int(0.004 * SR)], 0.0, 0.008)
    toe = fade(x[max(0, cut - int(0.002 * SR)):], 0.002, 0.03)
    t_on = int(np.argmax(np.abs(toe) > np.abs(toe).max() * 0.1))
    toe = toe[max(0, t_on - int(0.002 * SR)):]
    return heel, toe


def resample(x, ratio):
    """Hauteur × ratio (la durée ÷ ratio)."""
    n = max(2, int(len(x) / ratio))
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)


def mix(parts, length=None):
    """parts : [(signal, départ en s, gain en dB)]."""
    end = max(int(t * SR) + len(s) for s, t, _ in parts)
    y = np.zeros(length or end)
    for s, t, g in parts:
        i = int(t * SR)
        n = min(len(s), len(y) - i)
        if n > 0:
            y[i:i + n] += s[:n] * 10.0 ** (g / 20.0)
    return y


def level(x, rms_db=-20.0, ceil_db=-1.0):
    w = int(0.1 * SR)
    if len(x) <= w:
        r = np.sqrt((x ** 2).mean())
    else:
        c = np.cumsum(np.concatenate([[0.0], x ** 2]))
        r = np.sqrt((c[w:] - c[:-w]).max() / w)
    x = x * (10 ** (rms_db / 20.0) / (r + 1e-12))
    ceil = 10 ** (ceil_db / 20.0)
    t = 0.7 * ceil
    a = np.abs(x)
    over = a > t     # au-delà de 70 % du plafond : coude doux (tanh) qui tend vers le plafond
    x[over] = np.sign(x[over]) * (t + (ceil - t) * np.tanh((a[over] - t) / (ceil - t)))
    return x


def body(planks, i, lp_hz, ms=170):
    """Corps du plancher (la lame qui sonne sous le pas), court et sourd."""
    s = planks[i % len(planks)]
    s = lp(s, lp_hz, 4)[:int(ms / 1000 * SR)]
    return fade(s, 0.0, ms / 1000 * 0.6)


def scuff(cloths, i, hp_hz, ms):
    s = cloths[i % len(cloths)]
    on = int(np.argmax(np.abs(s) > np.abs(s).max() * 0.2))
    s = hp(s[on:on + int(ms / 1000 * SR)], hp_hz, 2)
    return fade(s, 0.01, ms / 1000 * 0.5)


# ------------------------------------------------------------------ fabrication

def build():
    rpg = [clean(load('footstep%02d.ogg' % i)) for i in range(10)]
    halves = [split(x) for x in rpg]
    heels = [h for h, _ in halves]
    toes = [t if t is not None else h for h, t in halves]
    planks = [clean(load('kenney/impactPlank_medium_%03d.ogg' % i)) for i in range(5)]
    ticks = [hp(clean(load('kenney/impactWood_light_%03d.ogg' % i)), 1800.0, 4) for i in range(3)]
    carpets = [clean(load(p)) for p in ['footstep_carpet_000.ogg', 'footstep_carpet_001.ogg', 'kenney/footstep_carpet_003.ogg']]
    softs = [clean(load('kenney/impactSoft_medium_%03d.ogg' % i)) for i in range(3)]
    concretes = [clean(load('kenney/footstep_concrete_%03d.ogg' % i)) for i in range(5)]
    tins = [clean(load('kenney/impactTin_medium_%03d.ogg' % i)) for i in range(3)]
    cloths = [clean(load('cloth%d.ogg' % i)) for i in (1, 2)]
    creaks = [clean(load('creak%d.ogg' % i)) for i in (1, 2, 3)]
    out = {}
    # paires talon / plante : jamais la même prise, jamais deux fois la même paire
    pairs = []
    order = RNG.permutation(10)
    for k in range(VARIANTS):
        h = int(order[k % 10])
        t = int(order[(k * 3 + 5) % 10])
        if t == h:
            t = (t + 1) % 10
        pairs.append((h, t))
    for k, (h, t) in enumerate(pairs):
        d = float(RNG.uniform(0.055, 0.115))
        tg = float(RNG.uniform(-8.0, -3.0))
        ratio = float(RNG.uniform(0.96, 1.04))
        heel, toe = heels[h], toes[t]
        # parquet : semelle souple sur un plancher sur solives
        parts = [(heel, 0.0, 0.0), (toe, d, tg), (body(planks, k, 320.0), 0.004, -17.0)]
        if k % 3 == 1:
            parts.append((ticks[k % 3], d + 0.01, -26.0))
        x = mix(parts)
        x = lp(x, 6000.0, 2)
        x = peak(x, 190.0, 2.5, 0.9)
        x = hp(x, 45.0, 2)
        out['parquet_%d' % k] = level(fade(resample(x, ratio), 0.0, 0.03))
        # tapis sur parquet : étouffé, le plancher dessous, un frottement de laine
        parts = [(lp(heel, 1400.0, 4), 0.0, 0.0), (lp(toe, 1100.0, 4), d * 1.1, tg - 2.0),
                 (body(planks, k + 2, 260.0), 0.006, -24.0), (scuff(cloths, k, 900.0, 90), d * 0.9, -27.0)]
        x = mix(parts)
        x = hp(x, 50.0, 2)
        out['tapis_%d' % k] = level(fade(resample(x, ratio * 0.98), 0.0, 0.03), -21.0)
        # moquette : choc mou, fibres
        c = carpets[k % 3]
        sft = softs[(k + 1) % 3]
        parts = [(lp(c, 900.0, 4), 0.0, 0.0), (lp(sft, 400.0, 2), 0.003, -6.0),
                 (lp(toe, 800.0, 4), d * 1.15, tg - 3.0), (scuff(cloths, k + 1, 1200.0, 110), d, -29.0)]
        x = mix(parts)
        x = hp(x, 55.0, 2)
        out['moquette_%d' % k] = level(fade(resample(x, ratio), 0.0, 0.03), -21.0)
        # carrelage : dalle (coup sourd) et claquement du talon sur l'émail
        cc = concretes[k % 5]
        c2 = concretes[(k + 2) % 5]
        bright = [1, 8, 0, 2, 9]          # (les prises RPG Audio qui ont le plus d'aigu)
        click = hp(heels[bright[k % 5]], 1200.0, 4)
        tclick = hp(toes[bright[(k + 2) % 5]], 1400.0, 4)
        glaze = hp(tins[k % 3], 2500.0, 4)[:int(0.05 * SR)]
        parts = [(cc, 0.0, 0.0), (click, 0.001, 3.0), (fade(glaze, 0.0, 0.03), 0.002, -20.0),
                 (c2, d * 0.85, tg - 2.0), (tclick, d * 0.85, tg)]
        x = mix(parts)
        x = peak(x, 3400.0, 5.0, 1.0)
        x = hp(x, 60.0, 2)
        out['carrelage_%d' % k] = level(fade(resample(x, ratio * 1.02), 0.0, 0.025))
    # lattes : grincement de plancher (craquement ralenti) et « toc » sourd de la lame qui fléchit
    spans = [(0, 0.15, 0.58), (1, 0.0, 0.62), (2, 0.02, 0.5), (0, 0.32, 0.6), (1, 0.28, 0.66), (2, 0.0, 0.72)]
    for k, (ci, start, ratio) in enumerate(spans):
        s = creaks[ci]
        a = int(start * SR)
        seg = s[a:a + int((0.18 + 0.05 * k) * SR)]
        seg = fade(resample(seg, ratio), 0.012, 0.09)
        seg = lp(hp(seg, 140.0, 2), 2600.0, 4)
        seg = peak(seg, 700.0, 3.0, 1.0)
        thunk = body(planks, k + 1, 220.0, 140)
        x = mix([(thunk, 0.0, -9.0), (seg, 0.03 + 0.01 * (k % 3), 0.0)])
        out['latte_%d' % k] = level(fade(x, 0.002, 0.06), -22.0)
    return out


def bands(x):
    X = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    tot = X.sum() + 1e-20
    return [100 * X[(f >= a) & (f < b)].sum() / tot for a, b in
            [(0, 20), (20, 60), (60, 150), (150, 400), (400, 1000), (1000, 3000), (3000, 8000), (8000, 22050)]]


def main():
    out = build()
    for name, x in sorted(out.items()):
        write(name, x)
    # aucune paire identique
    keys = sorted(out)
    same = [(a, b) for i, a in enumerate(keys) for b in keys[i + 1:]
            if len(out[a]) == len(out[b]) and np.allclose(out[a], out[b])]
    print('%d sons écrits dans %s ; doublons : %s' % (len(out), OUT, same or 'aucun'))
    if '--rapport' in sys.argv:
        print('bandes : <20 20-60 60-150 150-400 400-1k 1-3k 3-8k 8k+ (% de l\'énergie)')
        for name in keys:
            x = out[name]
            tail = np.abs(x[-int(0.01 * SR):]).max()
            print('%-12s %4d ms  crête %5.2f  fin %.4f | %s' % (name, len(x) * 1000 // SR, np.abs(x).max(), tail,
                  ' '.join('%5.1f' % v for v in bands(x))))


if __name__ == '__main__':
    main()
