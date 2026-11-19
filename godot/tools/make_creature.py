"""Sons de l'entité S.1.L.3.N.C.3. (sans voix) et bruits de la maison (passe « triple A », lot V2-CREATURE).

Usage : python3 -I godot/tools/make_creature.py             (écrit godot/assets/audio/creature/ et maison/)
        python3 -I godot/tools/make_creature.py --rapport   (et, pour chaque son : durée, crête, sonie, bandes)
Dépendances : numpy, et ffmpeg pour lire les .ogg sources. Ce dossier contient un .gdignore : Godot ne l'importe pas.

Tout est synthétisé ici, à graine fixe (relancer l'outil redonne les mêmes fichiers), en 48 kHz, mono, 16 bits
avec un bruit de dither triangulaire. Quelques sons partent de sons CC0 déjà dans le jeu (CREDITS.md), transformés
jusqu'à être méconnaissables : Kenney « Impact Sounds » (kenney/impactWood_light_000 à 002 : l'attaque des
phalanges sur une porte), Kenney « RPG Audio » (cloth1 et 2 : le feutre des pantoufles ; creak1 à 3 : le bois de la
charpente).

L'entité (assets/audio/creature/) :
  signature_1 à 3      SA signature : un bip électronique net qui se déforme (la hauteur s'effondre, l'échantillon
                       se dégrade, le secteur bourdonne dedans) puis se dissout en souffle (phases brouillées,
                       spectre étalé, formants d'une expiration). Les trois variantes gardent le même bip et le même
                       dessin : on la reconnaît, mais jamais deux fois la même.
  souffle_hp, souffle_babyphone, souffle_mur
                       le souffle électrique, en boucle de 24 s sans couture : une respiration trop lente et trop
                       régulière faite de bruit secteur (50 Hz et harmoniques, modulation d'amplitude, grain
                       numérique), colorée par l'appareil (haut-parleur, radio du babyphone, fils dans les murs).
  parasite_1 à 3       l'interférence d'un téléphone près d'un haut-parleur (rafales TDMA à 217 Hz) : elle passe.
  toux_radio, toux_piece        la toux de Mamie, imitée : quatre quintes IDENTIQUES à intervalles exacts (trop
                       régulières), la dernière à l'envers ; par la radio du babyphone, ou dans la pièce.
  pantoufles_piece     ses pantoufles : huit pas de feutre au métronome (0,6 s), le même pas copié, qui s'approchent
                       et s'arrêtent tout près.
  coups_reguliers, coups_envers des coups frappés à une porte : trois fois trois coups identiques au millimètre ;
                       ou trois coups joués à l'envers (la réverbération avant le choc).
  acoup_1 à 4          son corps qui avance par à-coups : un craquement numérique (grains bégayés, échantillon
                       dégradé) et un choc sourd dans les basses (35 à 55 Hz, saturé doucement pour qu'un petit
                       haut-parleur en garde les harmoniques).
  sursaut              le sursaut du visage : un souffle électrique large bande (1 à 6 kHz, attaque < 5 ms) avec la
                       signature écrasée en 0,3 s, puis l'expiration. Joué avec sting.ogg (le grave).
La maison (assets/audio/maison/) :
  vent                 rafales contre la maison (boucle de 48 s) : grondement, sifflement des jours de fenêtre.
  frigo                le compresseur du frigo, en bas, à travers le plancher (boucle de 20 s).
  charpente_1 à 4      la maison qui travaille : craquements lents de bois (frottement collé-glissé), un « toc ».
  tuyau_1 à 3          les tuyaux du chauffage qui se dilatent (tics métalliques) et l'eau qui gargouille.

Niveaux (mesurés ici, pondération K de la BS.1770, blocs de 400 ms) : sons ponctuels à LEVEL_ONESHOT de sonie
momentanée maximale, boucles à LEVEL_LOOP de sonie intégrée ; crête réelle (suréchantillonnée ×4) ≤ PEAK_MAX.
Les rapports entre sons se règlent dans le jeu (creature_sfx.gd, acoustique.gd).
"""
import os
import subprocess
import sys
import wave

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
AUDIO = os.path.join(ROOT, 'assets', 'audio')
SR = 48000
PEAK_MAX = -1.0          # dBFS, crête réelle
LEVEL_ONESHOT = -16.0    # LUFS, sonie momentanée maximale
LEVEL_LOOP = -24.0       # LUFS, sonie intégrée
BEEP_HZ = 1880.0         # le bip de la signature (toujours le même : on doit le reconnaître)

RAPPORT = []


# ------------------------------------------------------------------ outils

def rng(seed):
    return np.random.RandomState(seed)


def tt(n):
    return np.arange(n) / SR


def spec_filter(x, gain):
    """Filtre circulaire dans le domaine fréquentiel (une boucle reste sans couture). gain(f) -> amplitude."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    return np.fft.irfft(np.fft.rfft(x) * gain(f), n)


def lin_filter(x, gain, tail=0.0):
    """Filtre non circulaire (on ajoute du silence avant de filtrer : rien ne revient au début)."""
    pad = int(SR * max(0.05, tail))
    y = spec_filter(np.concatenate([x, np.zeros(pad)]), gain)
    return y[:len(x) + (pad if tail > 0 else 0)]


def butter(f, fc, order, high=False):
    r = (np.maximum(f, 1e-6) / fc) if not high else (fc / np.maximum(f, 1e-6))
    return 1 / np.sqrt(1 + r ** (2 * order))


def band(f, lo, hi, order=2):
    return butter(f, hi, order) * butter(f, lo, order, high=True)


def peaks(f, specs):
    """Résonances : somme de pics de Lorentz [(centre, largeur, gain)]."""
    out = np.zeros_like(f)
    for fc, bw, g in specs:
        out += g / (1 + ((f - fc) / (bw / 2)) ** 2)
    return out


def bell(f, fc, oct_w, gain_db):
    """Cloche en dB sur une échelle d'octaves."""
    return 10 ** (gain_db / 20 * np.exp(-0.5 * (np.log2(np.maximum(f, 1) / fc) / oct_w) ** 2))


def smooth_noise(n, hz, rs, circular=True):
    """Bruit lent (passe-bas à hz), écart type 1."""
    x = spec_filter(rs.randn(n), lambda f: butter(f, hz, 2))
    return x / (np.std(x) + 1e-12)


def wrap_add(out, i, ev):
    """Ajoute ev à partir de i, en revenant au début (boucles sans couture)."""
    n = len(out)
    i %= n
    m = len(ev)
    while m > 0:
        k = min(m, n - i)
        out[i:i + k] += ev[:k]
        ev = ev[k:]
        m -= k
        i = 0


def put(out, i, ev):
    """Ajoute ev à partir de i, sans dépasser."""
    i = int(i)
    if i >= len(out):
        return
    k = min(len(ev), len(out) - i)
    out[i:i + k] += ev[:k]


def fade(x, a=0.004, r=0.02):
    x = x.copy()
    na, nr = int(SR * a), int(SR * r)
    if na:
        x[:na] *= np.sin(np.linspace(0, np.pi / 2, na)) ** 2
    if nr:
        x[-nr:] *= np.cos(np.linspace(0, np.pi / 2, nr)) ** 2
    return x


def smoothstep(a, b, x):
    u = np.clip((x - a) / (b - a), 0, 1)
    return u * u * (3 - 2 * u)


def stft(x, n=2048, hop=256):
    win = np.hanning(n)
    pad = np.concatenate([np.zeros(n), x, np.zeros(n)])
    frames = [np.fft.rfft(pad[i:i + n] * win) for i in range(0, len(pad) - n, hop)]
    return np.array(frames)


def istft(X, length, n=2048, hop=256):
    win = np.hanning(n)
    out = np.zeros((len(X) - 1) * hop + n)
    norm = np.zeros_like(out)
    for k, fr in enumerate(X):
        out[k * hop:k * hop + n] += np.fft.irfft(fr, n) * win
        norm[k * hop:k * hop + n] += win ** 2
    out /= np.maximum(norm, 1e-3)
    return out[n:n + length]


def shaped_noise(n, env_fn, rs, frame=2048, hop=512):
    """Bruit dont l'enveloppe spectrale suit env_fn(f, u), u de 0 à 1 dans le son (STFT)."""
    X = stft(rs.randn(n), frame, hop)
    f = np.fft.rfftfreq(frame, 1 / SR)
    m = len(X)
    for k in range(m):
        u = min(1.0, max(0.0, (k * hop - frame) / max(n, 1)))
        X[k] *= env_fn(f, u)
    return istft(X, n, frame, hop)


def circ_noise(n, env, rs):
    """Bruit filtré circulairement par l'enveloppe fixe env(f) (pour les boucles)."""
    return spec_filter(rs.randn(n), env)


def glottal(n, f0_fn, rs, jitter=0.02, shimmer=0.08, open_q=0.6):
    """Train d'impulsions glottiques de Rosenberg (dérivée du débit), hauteur f0_fn(t)."""
    x = np.zeros(n)
    i = 0.0
    while i < n - 2:
        f0 = f0_fn(i / SR) * (1 + rs.normal(0, jitter))
        period = SR / max(f0, 20)
        k = int(i)
        m = max(4, int(period * open_q))
        u = np.arange(m) / m
        pulse = np.where(u < 0.7, 0.5 * (1 - np.cos(np.pi * u / 0.7)), np.cos(np.pi * (u - 0.7) / 0.6))
        end = min(n, k + m)
        x[k:end] += pulse[:end - k] * (1 + rs.normal(0, shimmer))
        i += period
    return np.diff(x, prepend=0.0)


def crush(x, bits, hold=1):
    """Échantillon dégradé : quantification sur « bits » bits et blocage (sample and hold)."""
    y = x.copy()
    if hold > 1:
        idx = (np.arange(len(y)) // hold) * hold
        y = y[idx]
    q = 2.0 ** (bits - 1)
    return np.round(y * q) / q


def var_crush(x, bits_t, hold_t):
    """Dégradation qui varie dans le temps (bits_t, hold_t : tableaux de même longueur)."""
    y = np.empty_like(x)
    i = 0
    n = len(x)
    held = 0.0
    while i < n:
        h = max(1, int(hold_t[i]))
        q = 2.0 ** (max(1.0, bits_t[i]) - 1)
        held = np.round(x[i] * q) / q
        y[i:i + h] = held
        i += h
    return y


def reverb_ir(seconds, rs, bright=5000.0, predelay=0.008, density=1.0):
    m = int(SR * seconds)
    t = tt(m)
    ir = rs.randn(m) * np.exp(-t * 6.9 / seconds)
    ir = spec_filter(ir, lambda f: butter(f, bright, 1) * butter(f, 120, 1, high=True))
    ir[:int(SR * predelay)] = 0
    return ir / np.sqrt(np.sum(ir ** 2) + 1e-12)


def convolve(x, ir, circular=False):
    n = len(x) if circular else len(x) + len(ir)
    if circular:
        irf = np.zeros(n)
        irf[:min(len(ir), n)] = ir[:min(len(ir), n)]
        return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(irf), n)
    nn = 1 << int(np.ceil(np.log2(n)))
    return np.fft.irfft(np.fft.rfft(x, nn) * np.fft.rfft(ir, nn), nn)[:n]


def room(x, seconds, mix, seed, bright=5000.0, predelay=0.008, circular=False):
    rs = rng(seed)
    wet = convolve(x, reverb_ir(seconds, rs, bright, predelay), circular)
    dry = np.concatenate([x, np.zeros(len(wet) - len(x))])
    return dry * (1 - mix) + wet * mix * 0.7


def softclip(x, drive):
    return np.tanh(x * drive) / np.tanh(drive)


def load(rel):
    """Un son du jeu (ogg/wav), en mono, à 48 kHz (ffmpeg)."""
    path = os.path.join(AUDIO, rel)
    raw = subprocess.run(['ffmpeg', '-v', 'quiet', '-i', path, '-f', 'f64le', '-ac', '1', '-ar', str(SR), '-'],
                         capture_output=True, check=True).stdout
    x = np.frombuffer(raw, dtype=np.float64).copy()
    x -= np.mean(x)
    return lin_filter(x, lambda f: butter(f, 30, 4, high=True))[:len(x)]


# ------------------------------------------------------------------ mesures (BS.1770) et écriture

def k_weight(x):
    """Pondération K (plateau aigu +4 dB, passe-haut RLB), appliquée en fréquence (phase nulle)."""
    def g(f):
        shelf = 10 ** (4.0 / 20 * (1 / (1 + (1681.0 / np.maximum(f, 1)) ** 2)))
        hp = butter(f, 38.0, 2, high=True)
        return shelf * hp
    return lin_filter(x, g)[:len(x)]


def momentary(x):
    """Sonie momentanée (fenêtres de 400 ms, pas de 100 ms), en LUFS."""
    y = k_weight(x)
    w = int(0.4 * SR)
    if len(y) < w:
        y = np.concatenate([y, np.zeros(w - len(y))])
    e = np.convolve(y ** 2, np.ones(w) / w, mode='valid')[::int(0.1 * SR)]
    return -0.691 + 10 * np.log10(e + 1e-20)


def integrated(x, circular=True):
    """Sonie intégrée (portes -70 et -10), en LUFS ; circulaire pour une boucle."""
    y = k_weight(np.concatenate([x, x[:int(0.4 * SR)]]) if circular else x)
    w = int(0.4 * SR)
    blocks = np.array([np.mean(y[i:i + w] ** 2) for i in range(0, len(y) - w + 1, w // 4)])
    lk = -0.691 + 10 * np.log10(blocks + 1e-20)
    b = blocks[lk > -70]
    if len(b) == 0:
        return -99.0
    rel = -0.691 + 10 * np.log10(np.mean(b) + 1e-20) - 10
    b = blocks[(lk > -70) & (lk > rel)]
    return -0.691 + 10 * np.log10(np.mean(b) + 1e-20)


def true_peak(x):
    n = len(x)
    X = np.fft.rfft(x)
    up = np.fft.irfft(X, 4 * n) * 4
    return 20 * np.log10(max(np.max(np.abs(up)), np.max(np.abs(x)), 1e-12))


def bands(x):
    X = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(len(x), 1 / SR)
    tot = X.sum() + 1e-20
    edges = [0, 100, 500, 1000, 2000, 6000, SR]
    return [100 * X[(f >= a) & (f < b)].sum() / tot for a, b in zip(edges[:-1], edges[1:])]


def level(x, target, loop=False):
    """Règle le niveau (sonie) puis borne la crête réelle à PEAK_MAX (gain seul : pas de limiteur)."""
    cur = integrated(x) if loop else float(np.max(momentary(x)))
    y = x * 10 ** ((target - cur) / 20)
    tp = true_peak(y)
    if tp > PEAK_MAX:
        y *= 10 ** ((PEAK_MAX - tp) / 20)
    return y


def write(sub, name, x, loop=False, target=None):
    """Écrit assets/audio/<sub>/<name>.wav (48 kHz, 16 bits, dither triangulaire)."""
    x = np.asarray(x, dtype=np.float64)
    x = x - np.mean(x) if loop else x
    if not loop:
        # pas de décalage : passe-haut à 18 Hz, puis fondus de 2 ms au début et de 10 ms à la fin
        x = lin_filter(x, lambda f: butter(f, 18, 2, high=True))[:len(x)]
        x = fade(x, 0.002, 0.01)
    x = level(x, LEVEL_LOOP if loop and target is None else (LEVEL_ONESHOT if target is None else target), loop)
    rs = rng(sum(map(ord, name)) * 7 + 3)
    d = (rs.rand(len(x)) - rs.rand(len(x))) / 32767.0
    pcm = np.clip(np.round((x + d) * 32767), -32767, 32767).astype(np.int16)
    folder = os.path.join(AUDIO, sub)
    os.makedirs(folder, exist_ok=True)
    with wave.open(os.path.join(folder, name + '.wav'), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())
    xs = pcm.astype(np.float64) / 32767
    seam = abs(xs[-1] - xs[0]) / (np.percentile(np.abs(np.diff(xs)), 99) + 1e-9) if loop else 0.0
    RAPPORT.append((sub + '/' + name, len(xs) / SR, true_peak(xs), integrated(xs, loop) if loop else float(np.max(momentary(xs))),
                    'I' if loop else 'M', float(np.mean(xs)), seam, bands(xs)))
    return xs


# ------------------------------------------------------------------ la signature : bip -> souffle

def breath_env(f, kind='out', open_=1.0):
    """Enveloppe spectrale d'une expiration (« haaa », gorge ouverte) ou d'une inspiration (plus sifflante)."""
    if kind == 'out':
        e = peaks(f, [(640 * open_, 260, 1.0), (1150 * open_, 380, 0.75), (2550, 700, 0.45), (3600, 1000, 0.18)])
    else:
        e = peaks(f, [(900, 500, 0.7), (1800, 900, 0.6), (3200, 1400, 0.5), (5200, 2400, 0.35)])
    return e * band(f, 120, 7500, 2)


def beep_tone(n, f_t, rs, harm=(1.0, 0.22, 0.07)):
    """Le bip : quasi-carré doux (harmoniques impaires), fréquence f_t (tableau)."""
    ph = 2 * np.pi * np.cumsum(f_t) / SR
    y = np.zeros(n)
    for k, a in enumerate(harm):
        h = 2 * k + 1
        y += a * np.sin(h * ph) * (h * f_t < 18000)
    return y


def signature(variant):
    """La signature de l'entité. variant 1 à 3 : même bip, même dessin, détails différents."""
    rs = rng(9100 + variant)
    dur = 2.75 + 0.15 * (variant - 2)
    n = int(SR * dur)
    t = tt(n)
    # 1) le bip, net pendant 0,17 s, puis sa hauteur s'effondre (une bande qui ralentit) et tremble
    t_def = 0.17
    drop = smoothstep(t_def, t_def + 0.75 + 0.08 * variant, t) ** 1.6 * (1.45 + 0.12 * variant)
    vib_depth = smoothstep(t_def, 0.9, t) * (0.06 + 0.02 * variant)
    vib = vib_depth * np.sin(2 * np.pi * (7.0 + variant) * t + rs.uniform(0, 6.3)) \
        + 0.4 * vib_depth * np.clip(smooth_noise(n, 18, rs), -2, 2)
    f_t = BEEP_HZ * 2 ** (-drop + vib)
    tone = beep_tone(n, f_t, rs)
    # bégaiement : à mi-chemin, 3 ou 4 fragments de 25 ms se répètent (le signal se coince)
    st0 = int(SR * (0.42 + 0.03 * variant))
    g = int(SR * (0.024 + 0.003 * variant))
    orig = tone.copy()
    frag = orig[st0:st0 + g]
    xf = int(SR * 0.003)
    ramp = np.sin(np.linspace(0, np.pi / 2, xf)) ** 2
    cont = orig[st0 + g:st0 + g + xf]          # ce qui suivrait le fragment : on en part en fondu
    reps = 2 + variant % 2
    for k in range(reps):
        a = st0 + (k + 1) * g
        seg = frag.copy()
        seg[:xf] = frag[:xf] * ramp + cont * (1 - ramp)
        tone[a:a + g] = seg
    e = st0 + (reps + 1) * g
    tone[e:e + xf] = orig[e:e + xf] * ramp + cont * (1 - ramp)
    # le secteur s'en mêle (modulation à 50 et 100 Hz), l'échantillon se dégrade (bits, blocage)
    mains = smoothstep(0.25, 1.0, t)
    tone *= 1 - 0.55 * mains * (0.5 + 0.5 * np.sin(2 * np.pi * 50 * t)) - 0.2 * mains * (0.5 + 0.5 * np.sin(2 * np.pi * 100 * t + 1.0))
    bits = 16 - 12.5 * smoothstep(0.2, 0.95, t)
    hold = 1 + 22 * smoothstep(0.3, 1.1, t) ** 1.5
    tone = var_crush(tone * 0.7, bits, hold) / 0.7
    tone = lin_filter(tone, lambda f: butter(f, 9000, 2))[:n]
    amp = np.clip(t / 0.004, 0, 1) * (1 - 0.25 * smoothstep(0.17, 0.9, t))
    tone *= amp
    # 2) il se dissout : phases brouillées et spectre étalé (STFT), puis formants d'une expiration
    N, H = 2048, 256
    X = stft(tone, N, H)
    f = np.fft.rfftfreq(N, 1 / SR)
    env_out = breath_env(f, 'out', 1.0 + 0.04 * (variant - 2))
    env_out /= env_out.max()
    for k in range(len(X)):
        tk = (k * H - N) / SR
        m = float(smoothstep(0.45, 1.35, tk))
        if m <= 0:
            continue
        mag = np.abs(X[k])
        sig = 1 + 60 * m
        ker = np.exp(-0.5 * (np.arange(-int(3 * sig), int(3 * sig) + 1) / sig) ** 2)
        blurred = np.convolve(mag, ker / ker.sum(), mode='same')
        blurred *= (np.sum(mag) + 1e-12) / (np.sum(blurred) + 1e-12)
        mag2 = blurred * env_out ** (0.9 * m) * (1 + 1.5 * m)
        ph = np.angle(X[k]) + m * np.pi * rs.uniform(-1, 1, len(mag))
        X[k] = mag2 * np.exp(1j * ph)
    dissolve = istft(X, n, N, H)
    dissolve *= 1 - smoothstep(1.4, 1.75, t)
    # 3) le souffle : une expiration lente, rauque, traversée de secteur et d'un reste de craquements
    def env_fn(ff, u):
        o = 1.0 - 0.12 * u
        return breath_env(ff, 'out', o) * (1 + 0.6 * peaks(ff, [(BEEP_HZ / 2.9, 120, 1.0)]))
    br = shaped_noise(n, env_fn, rs)
    br /= np.std(br) + 1e-12
    shape = smoothstep(0.75, 1.3, t) * np.exp(-np.maximum(0, t - 1.3) / (0.55 + 0.05 * variant))
    grain = 1 + 0.35 * np.clip(smooth_noise(n, 30, rs), -2.5, 2.5) / 2.5
    br *= shape * grain * (1 - 0.25 * (0.5 + 0.5 * np.sin(2 * np.pi * 50 * t)))
    crackle = np.zeros(n)
    for _ in range(26 + 4 * variant):
        i = int(SR * rs.uniform(0.6, dur - 0.4))
        m = int(SR * 0.004)
        crackle[i:i + m] += rs.randn(m) * np.exp(-tt(m) / 0.0008) * rs.uniform(0.2, 1.0)
    crackle = lin_filter(crackle, lambda ff: band(ff, 1500, 7000, 2))[:n]
    crackle *= np.exp(-np.maximum(0, t - 1.0) / 0.7) * smoothstep(0.5, 0.8, t)
    tone_part = tone * (1 - smoothstep(0.45, 1.05, t))
    y = tone_part * 0.5 + dissolve * 0.6 + br * 0.5 + crackle * 0.06
    # la fin est une expiration : sombre, sans aigus de numérique
    dark = lin_filter(y, lambda ff: butter(ff, 3200, 2))[:n]
    w = smoothstep(1.0, 1.6, t)
    y = y * (1 - w) + dark * w
    y = fade(y, 0.002, 0.25)
    return y


def signature_short(seed=9200):
    """La signature écrasée en 0,35 s (pour le sursaut) : bip, effondrement brutal, souffle."""
    rs = rng(seed)
    n = int(SR * 0.6)
    t = tt(n)
    drop = smoothstep(0.035, 0.3, t) ** 1.2 * 1.9
    f_t = BEEP_HZ * 2 ** (-drop + 0.12 * smoothstep(0.03, 0.2, t) * np.sin(2 * np.pi * 23 * t))
    tone = beep_tone(n, f_t, rs)
    tone *= 1 - 0.6 * smoothstep(0.04, 0.2, t) * (0.5 + 0.5 * np.sin(2 * np.pi * 50 * t))
    tone = var_crush(tone * 0.7, 16 - 12 * smoothstep(0.03, 0.25, t), 1 + 18 * smoothstep(0.05, 0.3, t)) / 0.7
    tone *= np.clip(t / 0.002, 0, 1) * (1 - smoothstep(0.2, 0.45, t))
    return lin_filter(tone, lambda f: butter(f, 9000, 2))[:n]


# ------------------------------------------------------------------ le souffle électrique (boucles)

def electric_breath(kind, sec=24.0):
    """Respiration de l'entité dans un appareil, boucle de sec s. kind : hp, babyphone, mur."""
    seed = {'hp': 9300, 'babyphone': 9310, 'mur': 9320}[kind]
    rs = rng(seed)
    n = int(SR * sec)
    t = tt(n)
    # trois cycles trop lents et trop réguliers (7 à 9 s), inspiration longue, expiration en paliers
    cycles = [7.6, 8.8, 7.6] if kind != 'mur' else [8.0, 8.0, 8.0]
    starts = np.cumsum([0.0] + cycles[:-1])
    amp_in = np.zeros(n)
    amp_out = np.zeros(n)
    for s, c in zip(starts, cycles):
        i_len, o_len = 0.38 * c, 0.46 * c
        u = ((t - s) % sec) / i_len
        inside = (u >= 0) & (u < 1)
        amp_in += np.where(inside, np.sin(np.pi * np.clip(u, 0, 1)) ** 1.5 * (0.6 + 0.4 * np.clip(u, 0, 1)), 0)
        u2 = ((t - s - i_len - 0.08 * c) % sec) / o_len
        inside2 = (u2 >= 0) & (u2 < 1)
        env2 = np.where(inside2, np.clip(u2 / 0.06, 0, 1) * (1 - np.clip(u2, 0, 1)) ** 1.4, 0)
        # l'expiration descend par paliers (un réglage de volume numérique, pas un poumon)
        env2 = np.round(env2 * 9) / 9
        amp_out += env2
    amp_out = spec_filter(amp_out, lambda f: butter(f, 40, 2))
    amp_in = np.maximum(amp_in, 0)
    amp_out = np.maximum(amp_out, 0)

    def unit(x):
        return x / (np.std(x) + 1e-12)
    nin = unit(circ_noise(n, lambda f: breath_env(f, 'in'), rs))
    nin2 = unit(circ_noise(n, lambda f: breath_env(f, 'out', 1.35) + 0.4 * breath_env(f, 'in'), rs))
    nout = unit(circ_noise(n, lambda f: breath_env(f, 'out', 1.1), rs))
    nout2 = unit(circ_noise(n, lambda f: breath_env(f, 'out', 0.72), rs))
    # position dans le cycle (0 au début du souffle, 1 à la fin) : les formants glissent
    pos = np.zeros(n)
    for s, c in zip(starts, cycles):
        pos = np.maximum(pos, np.where(((t - s) % sec) < c, ((t - s) % sec) / c, 0))
    pos = spec_filter(pos, lambda f: butter(f, 3, 1))
    pos = np.clip(pos, 0, 1)
    grain = 1 + 0.4 * np.clip(smooth_noise(n, 22, rs), -2.5, 2.5) / 2.5
    breath = (nin * (1 - pos) + nin2 * pos) * amp_in * 0.7 * grain + (nout * (1 - pos) + nout2 * pos) * amp_out * grain
    # le secteur : modulation d'amplitude à 50 et 100 Hz (entiers de cycles sur la boucle), et le bourdon,
    # que le souffle fait gonfler
    level_ = np.clip(amp_in * 0.7 + amp_out, 0, 1.2)
    breath *= 1 - 0.45 * (0.5 + 0.5 * np.sin(2 * np.pi * 50 * t)) - 0.15 * (0.5 + 0.5 * np.sin(2 * np.pi * 100 * t + 0.7))
    hum = np.zeros(n)
    for h, a in [(1, 1.0), (2, 0.5), (3, 0.55), (5, 0.3), (7, 0.18), (9, 0.1), (11, 0.06)]:
        hum += a * np.sin(2 * np.pi * 50 * h * t + rs.uniform(0, 6.3))
    hum *= (0.25 if kind != 'mur' else 0.1) + 0.9 * level_
    # grain numérique : le souffle quantifié (8 bits) se mêle au propre
    crushed = crush(breath / (np.max(np.abs(breath)) + 1e-9), 6, 3) * np.max(np.abs(breath))
    breath = breath * 0.7 + crushed * 0.3
    # craquements rares (plus nombreux dans l'expiration)
    crack = np.zeros(n)
    for _ in range(int(sec * 2.2)):
        i = int(rs.uniform(0, n))
        m = int(SR * 0.003)
        a = rs.uniform(0.2, 1.0) * (0.3 + level_[i])
        wrap_add(crack, i, rs.randn(m) * np.exp(-tt(m) / 0.0007) * a)
    crack = spec_filter(crack, lambda f: band(f, 1200, 6500, 2))
    if kind == 'hp':
        y = breath * 1.0 + hum * 0.035 + crack * 0.08
        y = spec_filter(y, lambda f: band(f, 170, 8000, 2) * bell(f, 1100, 0.5, 4.0) * bell(f, 3200, 0.4, 2.0))
        y = softclip(y / (np.std(y) * 4), 1.6)
    elif kind == 'babyphone':
        hiss = spec_filter(rs.randn(n), lambda f: band(f, 400, 3800, 3))
        hiss /= np.std(hiss)
        squelch = 0.35 + 0.65 * np.clip(level_ * 1.5, 0, 1)
        y = breath * 1.0 + hum * 0.025 + crack * 0.1 + hiss * 0.12 * squelch
        y = spec_filter(y, lambda f: band(f, 320, 3400, 3) * bell(f, 1400, 0.6, 3.0))
        y = softclip(y / (np.std(y) * 3.5), 2.2)
        y = crush(y / (np.max(np.abs(y)) + 1e-9), 8, 2) * np.max(np.abs(y))
        y = spec_filter(y, lambda f: band(f, 300, 3600, 2))
    else:
        y = breath * 0.8 + hum * 0.12 + crack * 0.03
        y = spec_filter(y, lambda f: butter(f, 900, 3) * butter(f, 40, 2, high=True) * bell(f, 140, 0.6, 3.0))
    return spec_filter(y, lambda f: butter(f, 25, 2, high=True))


# ------------------------------------------------------------------ parasite (téléphone près d'un haut-parleur)

def parasite(variant):
    rs = rng(9400 + variant)
    sec = 1.4 + 0.3 * variant
    n = int(SR * sec)
    t = tt(n)
    frame = 1 / 217.0
    pulses = ((t % frame) < 0.000577 * 1.2).astype(float)
    pulses = lin_filter(pulses, lambda f: butter(f, 6000, 2))[:n]
    # rafales : « ti-ti-ti, tititititi, tiii »
    gate = np.zeros(n)
    pos = 0.05
    while pos < sec - 0.15:
        ln = rs.choice([0.07, 0.07, 0.12, 0.3, 0.55])
        a = int(SR * pos)
        b = int(SR * min(sec - 0.05, pos + ln))
        gate[a:b] = rs.uniform(0.6, 1.0)
        pos += ln + rs.choice([0.05, 0.08, 0.12, 0.25])
    gate = lin_filter(gate, lambda f: butter(f, 120, 2))[:n]
    y = pulses * gate
    y = lin_filter(y, lambda f: band(f, 180, 6500, 2) * bell(f, 1100, 0.6, 3.0))[:n]
    y = softclip(y / (np.max(np.abs(y)) + 1e-9), 1.5)
    return fade(y, 0.002, 0.03)


# ------------------------------------------------------------------ imitations : toux, pantoufles, coups

def cough_one(rs, f0=205.0, strength=1.0):
    """Une quinte de toux d'une vieille dame : éclat de la glotte, souffle rauque formé, un peu de voix."""
    n = int(SR * 0.42)
    t = tt(n)
    form = [(620, 320, 1.0), (1480, 420, 0.7), (2850, 600, 0.45), (3900, 900, 0.2)]

    def env_fn(f, u):
        return (peaks(f, [(fc * (1 - 0.08 * u), bw, g) for fc, bw, g in form]) + 0.06) * band(f, 150, 7000, 2)
    noise = shaped_noise(n, env_fn, rs, 1024, 256)
    noise /= np.std(noise) + 1e-12
    env = np.clip(t / 0.0025, 0, 1) * (0.25 + 0.75 * np.exp(-t / 0.018)) * np.exp(-t / 0.11)
    rattle = 1 + 0.35 * np.sin(2 * np.pi * 27 * t) * smoothstep(0.03, 0.08, t)
    burst = rs.randn(n) * np.exp(-t / 0.004) * np.clip(t / 0.0006, 0, 1)
    burst = lin_filter(burst, lambda f: band(f, 300, 8000, 1))[:n]
    v = glottal(n, lambda x: f0 * (1.08 - 0.25 * min(1.0, x / 0.2)), rs, jitter=0.05, shimmer=0.15)
    v = spec_filter(v, lambda f: peaks(f, form) + 0.03)
    v /= np.std(v) + 1e-12
    venv = smoothstep(0.004, 0.02, t) * np.exp(-t / 0.07)
    y = noise * env * rattle + burst * 0.8 + v * venv * 0.45
    return fade(y * strength, 0.0005, 0.06)


def inhale_wheeze(rs, sec=0.7):
    n = int(SR * sec)
    t = tt(n)

    def env_fn(f, u):
        return (peaks(f, [(1700, 600, 0.6), (2900, 900, 0.6), (4200, 1500, 0.3)])
                + 0.5 * peaks(f, [(1180 + 300 * u, 40, 1.0)])) * band(f, 300, 8000, 2)
    x = shaped_noise(n, env_fn, rs, 1024, 256)
    x /= np.std(x) + 1e-12
    return fade(x * np.sin(np.pi * np.clip(t / sec, 0, 1)) ** 0.8 * 0.35, 0.01, 0.05)


def radio(x, seed, hiss=0.02):
    """Par la radio du babyphone : bande 300-3400 Hz, saturation, souffle radio, grain 8 bits."""
    rs = rng(seed)
    y = lin_filter(x, lambda f: band(f, 320, 3400, 3) * bell(f, 1500, 0.7, 3.0))[:len(x)]
    y = softclip(y / (np.max(np.abs(y)) + 1e-9) * 1.2, 2.0)
    h = lin_filter(rs.randn(len(y)), lambda f: band(f, 400, 3800, 3))[:len(y)]
    y = y + h / np.std(h) * hiss
    y = crush(y / (np.max(np.abs(y)) + 1e-9), 8, 2)
    return lin_filter(y, lambda f: band(f, 300, 3600, 2))[:len(y)]


def toux(medium):
    """La toux de Mamie, imitée : quatre fois LA MÊME quinte, à 0,40 s pile ; la cinquième, à l'envers."""
    rs = rng(9500)
    one = cough_one(rs, 205.0, 1.0)
    one_room = fade(room(one, 0.45, 0.22, 9501, bright=4000)[:int(SR * 0.6)], 0.0, 0.12)
    sec = 3.6
    y = np.zeros(int(SR * sec))
    for k in range(4):
        put(y, SR * (0.05 + 0.40 * k), one_room)
    # la cinquième à l'envers (la réverbération avant l'éclat), puis l'inspiration, à l'envers elle aussi
    put(y, SR * 1.85, one_room[::-1] * 0.9)
    wz = inhale_wheeze(rng(9502), 0.75)
    wz = fade(room(wz, 0.4, 0.2, 9503, bright=4000)[:len(wz) + int(SR * 0.15)], 0.0, 0.1)
    put(y, SR * 2.6, wz[::-1] * 0.8)
    if medium == 'radio':
        y = radio(y, 9504, 0.025)
    else:
        y = lin_filter(y, lambda f: butter(f, 7000, 2))[:len(y)]
    return fade(y, 0.002, 0.08)


def pantoufles():
    """Ses pantoufles : huit pas de feutre au métronome (le même pas, copié), qui s'approchent puis s'arrêtent."""
    rs = rng(9600)
    cl = [load('cloth1.ogg'), load('cloth2.ogg')]
    # un pas : le frottement du feutre (tissu ralenti, passe-bande), et le talon mou sur le parquet
    base = cl[0][:int(SR * 0.5)]
    base = np.interp(np.arange(0, len(base), 0.72), np.arange(len(base)), base)[:int(SR * 0.42)]
    n = len(base)
    t = tt(n)
    scuff = lin_filter(base, lambda f: band(f, 350, 4500, 2) * bell(f, 1200, 0.8, 2.0))[:n]
    scuff *= smoothstep(0.0, 0.05, t) * (1 - smoothstep(0.2, 0.4, t))
    scuff /= np.max(np.abs(scuff)) + 1e-9
    slide = shaped_noise(n, lambda f, u: band(f, 500, 3500, 2) * (np.maximum(f, 50) / 1000) ** -0.6, rs, 1024, 256)
    slide /= np.std(slide) + 1e-12
    slide *= smoothstep(0.02, 0.1, t) * (1 - smoothstep(0.16, 0.3, t)) * (1 + 0.5 * np.clip(smooth_noise(n, 45, rs), -2, 2) / 2)
    heel = np.sin(2 * np.pi * 95 * t) * np.exp(-t / 0.035) * np.clip(t / 0.003, 0, 1)
    heel += lin_filter(rs.randn(n), lambda f: band(f, 60, 400, 2))[:n] * np.exp(-t / 0.02) * 0.4
    step = scuff * 0.6 + slide * 0.12 + np.roll(heel, int(SR * 0.17)) * 0.5
    step = fade(step, 0.002, 0.05)
    sec = 6.4
    y = np.zeros(int(SR * sec) + SR)
    for k in range(8):
        d = 1 - k / 7                        # de loin (1) à tout près (0)
        s = step * 10 ** ((-14 * d) / 20)
        s = lin_filter(s, lambda f, d=d: butter(f, 1500 + 6000 * (1 - d) ** 1.5, 2))[:len(s)]
        s = room(s, 0.7, 0.15 + 0.45 * d, 9601 + k, bright=3500)
        put(y, SR * (0.1 + 0.6 * k), s)
    return fade(y[:int(SR * sec)], 0.002, 0.3)


def knock_one(rs, src):
    """Un coup de phalange sur une porte : l'attaque d'un choc de bois (Kenney), le panneau qui résonne."""
    n = int(SR * 0.35)
    t = tt(n)
    a = src[:n] if len(src) >= n else np.pad(src, (0, n - len(src)))
    a = lin_filter(a, lambda f: band(f, 200, 6000, 2))[:n] * np.exp(-t / 0.03)
    a /= np.max(np.abs(a)) + 1e-9
    modes = np.zeros(n)
    for fc, dec, g in [(118, 0.07, 1.0), (176, 0.06, 0.8), (243, 0.05, 0.7), (338, 0.04, 0.5), (472, 0.03, 0.35),
                       (655, 0.022, 0.25), (910, 0.015, 0.15)]:
        modes += g * np.sin(2 * np.pi * fc * rs.uniform(0.99, 1.01) * t + rs.uniform(0, 1)) * np.exp(-t / dec)
    modes *= np.clip(t / 0.0015, 0, 1)
    modes /= np.max(np.abs(modes)) + 1e-9
    return fade(a * 0.55 + modes * 0.8, 0.0005, 0.05)


def coups(kind):
    """Coups frappés à une porte. reguliers : trois fois trois coups identiques au millimètre ; envers : trois
    coups joués à l'envers (la réverbération du couloir monte, le choc arrive, puis rien)."""
    rs = rng(9700)
    src = load('kenney/impactWood_light_001.ogg')
    k1 = knock_one(rs, src)
    if kind == 'reguliers':
        sec = 4.6
        y = np.zeros(int(SR * sec))
        for g in range(3):
            for k in range(3):
                put(y, SR * (0.05 + 1.5 * g + 0.26 * k), k1)
        y = room(y, 0.9, 0.25, 9701, bright=4500, predelay=0.012)[:len(y)]
    else:
        sec = 3.4
        y = np.zeros(int(SR * 1.6))
        for k in range(3):
            put(y, SR * (0.05 + 0.26 * k), k1 * (1.0 - 0.06 * k))
        y = room(y, 1.4, 0.45, 9702, bright=4500, predelay=0.012)
        y = y[::-1]
        y = np.concatenate([np.zeros(int(SR * 0.05)), y, np.zeros(int(SR * sec) - len(y) - int(SR * 0.05))])
    return fade(y, 0.003, 0.15)


# ------------------------------------------------------------------ à-coups (son corps qui avance)

def acoup(variant):
    rs = rng(9800 + variant)
    sec = 1.1
    n = int(SR * sec)
    t = tt(n)
    # 1) craquement numérique : des grains de 6 à 22 ms (bip abîmé, bruit) bégayés, échantillon dégradé
    mat = beep_tone(int(SR * 0.05), np.full(int(SR * 0.05), BEEP_HZ * rs.uniform(0.3, 0.6)), rs) * 0.6 \
        + rs.randn(int(SR * 0.05)) * 0.5
    crack = np.zeros(n)
    pos = 0
    for k in range(rs.randint(8, 13)):
        g = int(SR * rs.uniform(0.006, 0.022))
        off = rs.randint(0, len(mat) - g)
        grain = mat[off:off + g] * rs.uniform(0.5, 1.0)
        grain = crush(grain, rs.randint(3, 6), rs.randint(2, 9))
        m = int(SR * 0.0005)
        grain[:m] *= np.linspace(0, 1, m)
        grain[-m:] *= np.linspace(1, 0, m)
        put(crack, pos, grain)
        pos += g + int(SR * rs.uniform(0.0, 0.012))
    crack = lin_filter(crack, lambda f: band(f, 400, 9000, 2))[:n]
    # 2) le choc sourd : sinus qui tombe de 55 à 33 Hz, saturé (harmoniques pour les petits haut-parleurs)
    hit = int(SR * rs.uniform(0.035, 0.06))
    th = np.maximum(0, t - hit / SR)
    f_t = 33 + 22 * np.exp(-th / 0.05)
    ph = 2 * np.pi * np.cumsum(f_t) / SR
    sub = np.sin(ph) * np.clip(th / 0.002, 0, 1) * np.exp(-th / 0.2) * (t >= hit / SR)
    sub = softclip(sub * 1.8, 2.0)
    body = lin_filter(rs.randn(n), lambda f: band(f, 50, 260, 2))[:n] * np.exp(-th / 0.04) * (t >= hit / SR)
    body /= np.max(np.abs(body)) + 1e-9
    y = crack * 0.9 + sub * 0.85 + body * 0.35
    return fade(y, 0.001, 0.2)


# ------------------------------------------------------------------ le sursaut (visage)

def sursaut():
    rs = rng(9900)
    sec = 2.2
    n = int(SR * sec)
    t = tt(n)
    # souffle électrique large bande : bruit formé (1 à 6 kHz, criard), attaque < 5 ms, 250 ms de corps
    def env_fn(f, u):
        return (peaks(f, [(1250, 500, 0.8), (2450, 800, 1.0), (3800, 1200, 0.8), (5200, 1600, 0.4)]) + 0.08) \
            * band(f, 600, 9000, 2) * (1 - 0.5 * u)
    hiss = shaped_noise(n, env_fn, rs, 1024, 256)
    hiss /= np.std(hiss) + 1e-12
    env = np.clip(t / 0.003, 0, 1) * (0.55 + 0.45 * np.exp(-t / 0.06)) * np.exp(-np.maximum(0, t - 0.22) / 0.16)
    hiss *= env * (1 - 0.5 * (0.5 + 0.5 * np.sin(2 * np.pi * 50 * t)))
    hiss = 0.7 * hiss + 0.3 * crush(hiss / (np.max(np.abs(hiss)) + 1e-9), 5, 4) * np.max(np.abs(hiss))
    sig = np.zeros(n)
    put(sig, 0, signature_short())
    # l'expiration qui suit
    br = shaped_noise(n, lambda f, u: breath_env(f, 'out', 0.9), rs)
    br /= np.std(br) + 1e-12
    br *= smoothstep(0.2, 0.5, t) * np.exp(-np.maximum(0, t - 0.5) / 0.5)
    y = hiss * 0.5 + sig * 0.35 + br * 0.12
    y = room(y, 0.6, 0.18, 9901, bright=6000)[:n]
    return fade(y, 0.0008, 0.3)


# ------------------------------------------------------------------ la maison

def vent(sec=48.0):
    """Rafales contre la maison : grondement, sifflement des jours de fenêtre qui monte avec la rafale."""
    rs = rng(9050)
    n = int(SR * sec)
    t = tt(n)
    gust = 0.55 + 0.25 * np.sin(2 * np.pi * (2 / sec) * t + 0.4) + 0.12 * np.sin(2 * np.pi * (5 / sec) * t + 2.1) \
        + 0.15 * np.clip(smooth_noise(n, 0.35, rs), -2, 2) / 2
    gust = np.clip(gust, 0.22, 1.2)
    rumble = spec_filter(rs.randn(n), lambda f: (np.maximum(f, 15) / 60) ** -0.7 * band(f, 30, 600, 2)
                         * bell(f, 260, 0.8, 5.0))
    rumble /= np.std(rumble)
    rumble *= gust ** 1.5
    whistle = np.zeros(n)
    for fc, q, a in [(640, 25, 1.0), (1090, 30, 0.6), (1710, 35, 0.25)]:
        w = spec_filter(rs.randn(n), lambda f, fc=fc, q=q: 1 / (1 + ((f - fc) / (fc / q)) ** 2))
        w /= np.std(w)
        whistle += a * w * np.clip(gust - 0.55, 0, 1) ** 2
    hiss = spec_filter(rs.randn(n), lambda f: band(f, 300, 2500, 1))
    hiss /= np.std(hiss)
    y = rumble * 0.8 + whistle * 0.45 + hiss * 0.12 * gust ** 2
    return spec_filter(y, lambda f: butter(f, 25, 2, high=True) * butter(f, 4000, 2))


def frigo(sec=20.0):
    """Le compresseur du frigo, en bas : bourdon de moteur (100 Hz, harmoniques), à travers le plancher."""
    rs = rng(9060)
    n = int(SR * sec)
    t = tt(n)
    y = np.zeros(n)
    for h, a in [(1, 0.35), (2, 1.0), (3, 0.3), (4, 0.45), (6, 0.2), (8, 0.12), (10, 0.06)]:
        f = round(49.7 * h * sec) / sec
        y += a * np.sin(2 * np.pi * f * t + rs.uniform(0, 6.3))
    beat = 1 + 0.08 * np.sin(2 * np.pi * (3 / sec) * t)
    flow = spec_filter(rs.randn(n), lambda f: band(f, 80, 600, 2))
    flow /= np.std(flow)
    y = y * beat + flow * 0.15
    return spec_filter(y, lambda f: butter(f, 380, 3) * butter(f, 35, 2, high=True))


def charpente(variant):
    """La maison qui travaille : un craquement de bois lent (frottement collé-glissé) et parfois un « toc »."""
    rs = rng(9070 + variant)
    sec = 2.2 + 0.4 * variant
    n = int(SR * sec)
    t = tt(n)
    src = load(['creak1.ogg', 'creak2.ogg', 'creak3.ogg', 'creak2.ogg'][variant - 1])
    ratio = [0.55, 0.6, 0.5, 0.68][variant - 1]
    slow = np.interp(np.arange(0, len(src), ratio), np.arange(len(src)), src)
    slow = lin_filter(slow, lambda f: band(f, 90, 1800, 2))[:len(slow)]
    slow = fade(slow, 0.01, 0.15)
    slow /= np.max(np.abs(slow)) + 1e-9
    # collé-glissé : impulsions dont la cadence glisse, à travers les résonances d'une poutre
    stick = np.zeros(n)
    a0, a1 = rs.uniform(0.3, 0.6), rs.uniform(0.9, 1.4)
    pos = a0
    rate = rs.uniform(18, 30)
    while pos < a1:
        i = int(SR * pos)
        put(stick, i, np.array([1.0, -0.6, 0.2]) * rs.uniform(0.5, 1.0))
        rate *= rs.uniform(0.97, 1.05)
        pos += 1 / rate
    stick = lin_filter(stick, lambda f: peaks(f, [(180, 40, 1.0), (410, 80, 0.7), (760, 150, 0.4)]) * band(f, 80, 2000, 2))[:n]
    stick /= np.max(np.abs(stick)) + 1e-9
    y = np.zeros(n)
    put(y, int(SR * rs.uniform(0.05, 0.3)), slow * 0.8)
    y += stick * 0.5
    if variant % 2 == 0:
        toc = np.sin(2 * np.pi * 140 * t) * np.exp(-t / 0.03) * np.clip(t / 0.001, 0, 1)
        put(y, int(SR * (a1 + 0.1)), fade(toc[:int(SR * 0.3)], 0.0, 0.1) * 0.7)
    y = room(y, 0.9, 0.35, 9075 + variant, bright=2500)[:n]
    return fade(y, 0.005, 0.3)


def tuyau(variant):
    """Les tuyaux du chauffage : tics métalliques de dilatation, puis l'eau qui gargouille (variante 3)."""
    rs = rng(9080 + variant)
    sec = 3.0
    n = int(SR * sec)
    t = tt(n)
    y = np.zeros(n)
    pos = 0.1
    for k in range(rs.randint(4, 9)):
        m = int(SR * 0.12)
        tm = tt(m)
        tick = np.zeros(m)
        for fc, dec in [(1250, 0.012), (2380, 0.008), (3610, 0.005), (5020, 0.003)]:
            tick += np.sin(2 * np.pi * fc * rs.uniform(0.97, 1.03) * tm) * np.exp(-tm / dec) * rs.uniform(0.4, 1.0)
        tick += np.sin(2 * np.pi * 210 * tm) * np.exp(-tm / 0.02) * 0.4
        put(y, SR * pos, fade(tick, 0.0003, 0.03) * rs.uniform(0.3, 1.0))
        pos += rs.choice([0.12, 0.3, 0.45, 0.7, 0.18]) * rs.uniform(0.8, 1.3)
        if pos > sec - 0.5:
            break
    if variant == 3:
        for k in range(14):
            m = int(SR * rs.uniform(0.03, 0.08))
            tm = tt(m)
            f0 = rs.uniform(250, 600)
            bub = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 2.5 * tm / tm[-1])) / SR) * np.sin(np.pi * tm / tm[-1]) ** 2
            bub = fade(bub, 0.002, 0.005)
            put(y, SR * rs.uniform(0.6, 2.4), bub * rs.uniform(0.2, 0.6))
    y = lin_filter(y, lambda f: band(f, 120, 6000, 2))[:n]
    y = room(y, 0.6, 0.3, 9085 + variant, bright=3000)[:n]
    return fade(y, 0.003, 0.3)


# ------------------------------------------------------------------ tout

def main():
    C, M = 'creature', 'maison'
    for v in (1, 2, 3):
        write(C, 'signature_%d' % v, signature(v))
    for k in ('hp', 'babyphone', 'mur'):
        write(C, 'souffle_' + k, electric_breath(k), loop=True)
    for v in (1, 2, 3):
        write(C, 'parasite_%d' % v, parasite(v), target=-18.0)
    write(C, 'toux_radio', toux('radio'))
    write(C, 'toux_piece', toux('piece'))
    write(C, 'pantoufles_piece', pantoufles())
    write(C, 'coups_reguliers', coups('reguliers'))
    write(C, 'coups_envers', coups('envers'))
    for v in (1, 2, 3, 4):
        write(C, 'acoup_%d' % v, acoup(v), target=-14.0)
    write(C, 'sursaut', sursaut(), target=-11.0)
    write(M, 'vent', vent(), loop=True)
    write(M, 'frigo', frigo(), loop=True)
    for v in (1, 2, 3, 4):
        write(M, 'charpente_%d' % v, charpente(v))
    for v in (1, 2, 3):
        write(M, 'tuyau_%d' % v, tuyau(v))
    if '--rapport' in sys.argv:
        print('%-26s %6s %7s %7s  %8s %6s | %s' % ('son', 'durée', 'crête', 'sonie', 'décal.', 'raccord',
                                                     '<100 100-500 .5-1k 1-2k 2-6k >6k (%)'))
        for name, d, tp, lu, kind, dc, seam, bb in RAPPORT:
            print('%-26s %5.2fs %6.1f %6.1f%s %+8.5f %6.2f | %s' % (name, d, tp, lu, kind, dc, seam,
                                                                  ' '.join('%4.0f' % b for b in bb)))
    print('ok')


if __name__ == '__main__':
    main()
