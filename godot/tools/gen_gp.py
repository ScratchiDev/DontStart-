# gen_gp.py <dossier de sortie> : textures générées de la chambre des grands-parents (lot V2-GP), CC0 (faites ici).
#  couette_albedo.jpg / couette_normal.jpg : couvre-lit matelassé en losanges, coton satiné vieux rose imprimé
#      de petites fleurs, 1024 px pour COUETTE_TILE = 0,40 m (raccord parfait) ;
#  cheveux.png : mèches grises (RGB) et masque de mèches (A) pour la tête et les cartes de cheveux ;
#  miroir.png  : glace ancienne (RGB = teinte du tain, A = rugosité), piquée et dépolie sur les bords ;
#  boites.png  : étiquettes de deux boîtes de médicaments (atlas 512 × 256).
import sys, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = sys.argv[1]
FONT = sys.argv[2] if len(sys.argv) > 2 else None
rng = np.random.default_rng(1974)

def tile_noise(n, scale, seed):
    """bruit périodique (filtrage de Fourier) : écart type ~1, longueur de corrélation ~ n/scale px"""
    r = np.random.default_rng(seed)
    w = r.standard_normal((n, n))
    f = np.fft.fft2(w)
    ky = np.fft.fftfreq(n)[:, None]
    kx = np.fft.fftfreq(n)[None, :]
    k = np.sqrt(kx * kx + ky * ky) * n
    filt = np.exp(-(k / scale) ** 2)
    out = np.real(np.fft.ifft2(f * filt))
    return out / (out.std() + 1e-9)

def srgb(c):
    return np.array(c, dtype=float) / 255.0

def normal_from_height(h, strength):
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
    nx, ny, nz = -gx, gy, np.ones_like(h)       # OpenGL (Y vers le haut de l'image)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / l, ny / l, nz / l], -1)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)

# ------------------------------------------------------------------ couette
N = 1024
P = 256                       # période des piqûres (x + y et x - y) : 4 losanges par côté de tuile
yy, xx = np.mgrid[0:N, 0:N].astype(float)
m1 = np.mod(xx + yy, P)
m2 = np.mod(xx - yy, P)
s1 = np.sin(np.pi * m1 / P)
s2 = np.sin(np.pi * m2 / P)
puff = np.clip(s1 * s2, 0, 1) ** 0.55             # cellule gonflée, 0 sur les piqûres
d1 = np.minimum(m1, P - m1) / math.sqrt(2)          # distance (px) à la piqûre la plus proche
d2 = np.minimum(m2, P - m2) / math.sqrt(2)
dmin = np.minimum(d1, d2)
groove = np.exp(-(dmin / 3.0) ** 2)                 # creux de la couture
# points de piqûre : tirets de 9 px tous les 14 px le long de chaque ligne
along1 = np.mod((xx - yy) / math.sqrt(2), 14.0)
along2 = np.mod((xx + yy) / math.sqrt(2), 14.0)
stitch = np.maximum((d1 < 1.3) * (along1 < 9), (d2 < 1.3) * (along2 < 9)).astype(float)
fine = tile_noise(N, 180, 5) * 0.5 + tile_noise(N, 60, 6) * 0.5
wrinkle = tile_noise(N, 10, 7)
height = puff * 1.0 - groove * 0.25 - stitch * 0.08 + wrinkle * 0.05 + fine * 0.008
base = srgb((178, 134, 134))
col = np.ones((N, N, 3)) * base
col *= (1.0 + tile_noise(N, 12, 8)[..., None] * 0.035 + fine[..., None] * 0.015)
# imprimé : petites roses et petites fleurs crème, sur une grille décalée, raccordée (dessin sur 3 × 3)
img = Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8))
big = Image.new('RGBA', (N * 3, N * 3), (0, 0, 0, 0))
dr = ImageDraw.Draw(big)
G = 12
cell = N / G
for gy in range(G):
    for gx in range(G):
        cx = (gx + 0.5 + (0.5 if gy % 2 else 0.0)) * cell + rng.uniform(-9, 9)
        cy = (gy + 0.5) * cell + rng.uniform(-9, 9)
        kind = (gx * 7 + gy * 3) % 3
        rot = rng.uniform(0, math.tau)
        for ox in (0, N, 2 * N):
            for oy in (0, N, 2 * N):
                x, y = cx + ox, cy + oy
                if kind < 2:
                    # rose : 5 pétales et un cœur plus sombre, deux feuilles
                    for k in range(2):
                        a = rot + k * 2.6
                        lx, ly = x + math.cos(a) * 15, y + math.sin(a) * 15
                        dr.ellipse([lx - 7, ly - 4, lx + 7, ly + 4], fill=(108, 122, 86, 200))
                    for k in range(5):
                        a = rot + k * math.tau / 5
                        px, py = x + math.cos(a) * 6, y + math.sin(a) * 6
                        dr.ellipse([px - 6, py - 6, px + 6, py + 6], fill=(158, 70, 84, 215))
                    dr.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(118, 44, 58, 230))
                else:
                    # petite fleur crème à cœur jaune
                    for k in range(5):
                        a = rot + k * math.tau / 5
                        px, py = x + math.cos(a) * 5, y + math.sin(a) * 5
                        dr.ellipse([px - 4, py - 4, px + 4, py + 4], fill=(226, 208, 182, 210))
                    dr.ellipse([x - 2.5, y - 2.5, x + 2.5, y + 2.5], fill=(202, 168, 86, 230))
pr = big.crop((N, N, 2 * N, 2 * N)).filter(ImageFilter.GaussianBlur(0.6))
img.paste(pr, (0, 0), pr)
col = np.asarray(img).astype(float) / 255.0
# les piqûres : fil un peu plus clair ; l'ombre des creux (occlusion) ; l'usure (passé, boulochage)
col = col * (1 - stitch[..., None] * 0.25) + srgb((206, 176, 170)) * stitch[..., None] * 0.25
col *= (0.85 + 0.15 * np.clip(puff, 0, 1) ** 0.5)[..., None]
col *= (1.0 + tile_noise(N, 4, 9)[..., None] * 0.04)
Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).save(OUT + '/couette_albedo.jpg', quality=92)
Image.fromarray(normal_from_height(height, 14.0)).save(OUT + '/couette_normal.jpg', quality=94)

# ------------------------------------------------------------------ cheveux (u : à travers les mèches, v : le long)
W, H = 256, 512
r2 = np.random.default_rng(58)
u = np.arange(W)[None, :].astype(float)
v = np.arange(H)[:, None].astype(float)
cols = np.ones((H, W, 3)) * 0.68
alpha = np.zeros((H, W))
strands = 260
for s in range(strands):
    x0 = r2.uniform(0, W)
    w = r2.uniform(0.6, 1.4)
    amp = r2.uniform(1.0, 4.0)
    ph = r2.uniform(0, math.tau)
    freq = r2.uniform(0.008, 0.02)
    x = x0 + np.sin(v * freq + ph) * amp
    for o in (-W, 0, W):
        d = np.abs(u - (x + o))
        m = np.clip(1.0 - d / w, 0, 1)
        g = r2.choice([0.62, 0.66, 0.7, 0.72, 0.76])
        tone = np.array([g, g * 0.985, g * 0.97])
        cols = cols * (1 - m[..., None] * 0.3) + tone * m[..., None] * 0.3
        alpha = np.maximum(alpha, m * (1.0 - np.clip((v - H * r2.uniform(0.75, 1.0)) / 40.0, 0, 1)))
base_h = 0.6 + tile_noise(256, 8, 11)[:, :1].repeat(1, 1)[:1, :1] * 0
cols = np.where(cols.sum(-1, keepdims=True) < 0.01, 0.62, cols)
cols = np.clip(cols * (0.96 + 0.04 * np.sin(v / 9.0 + u / 31.0))[..., None], 0, 1)
rgba = np.dstack([cols, np.clip(alpha, 0, 1)])
Image.fromarray((rgba * 255).astype(np.uint8), 'RGBA').save(OUT + '/cheveux.png')

# ------------------------------------------------------------------ miroir (u, v sur la boîte de la glace)
MW, MH = 256, 384
yy, xx = np.mgrid[0:MH, 0:MW].astype(float)
ex = np.minimum(xx, MW - 1 - xx) / MW
ey = np.minimum(yy, MH - 1 - yy) / MH
edge = np.minimum(ex * 1.0, ey * 1.5)
band = np.clip(1.0 - edge / 0.09, 0, 1)                   # bord dépoli (0 au centre)
spots = np.zeros((MH, MW))
r3 = np.random.default_rng(31)
for k in range(70):
    near = r3.random() < 0.8
    if near:
        side = r3.integers(4)
        t = r3.random()
        cx = [t * MW, t * MW, r3.uniform(0, 14), MW - r3.uniform(0, 14)][side]
        cy = [r3.uniform(0, 18), MH - r3.uniform(0, 18), t * MH, t * MH][side]
    else:
        cx, cy = r3.uniform(0, MW), r3.uniform(0, MH)
    rad = r3.uniform(1.0, 5.5) if near else r3.uniform(0.6, 2.0)
    spots = np.maximum(spots, np.clip(1.0 - np.hypot(xx - cx, yy - cy) / rad, 0, 1) ** 0.7)
haze = np.clip(tile_noise(MW, 6, 12)[:1, :1] * 0 + 0, 0, 1)
tint = np.ones((MH, MW, 3)) * srgb((228, 226, 216))
tint *= (1.0 - band * 0.35)[..., None]
tint = tint * (1 - spots[..., None] * 0.75) + srgb((70, 60, 48)) * spots[..., None] * 0.75
rough = 0.05 + band * 0.4 + spots * 0.5
rgba = np.dstack([np.clip(tint, 0, 1), np.clip(rough, 0, 1)])
Image.fromarray((rgba * 255).astype(np.uint8), 'RGBA').save(OUT + '/miroir.png')

# ------------------------------------------------------------------ boîtes de médicaments (2 étiquettes)
lab = Image.new('RGB', (512, 256), (236, 236, 232))
d = ImageDraw.Draw(lab)
f1 = ImageFont.truetype(FONT, 30) if FONT else ImageFont.load_default()
f2 = ImageFont.truetype(FONT, 18) if FONT else ImageFont.load_default()
# boîte 1 (u 0-256) : somnifère, bande bleue ; boîte 2 (u 256-512) : cœur, bande verte et orange
d.rectangle([0, 0, 255, 255], fill=(240, 240, 236))
d.rectangle([0, 150, 255, 196], fill=(52, 92, 164))
d.text((14, 40), "ZOPICLONE", font=f1, fill=(30, 40, 70))
d.text((14, 80), "7,5 mg", font=f2, fill=(40, 50, 80))
d.text((14, 110), "14 comprimés", font=f2, fill=(80, 80, 90))
d.text((14, 160), "Générique", font=f2, fill=(240, 240, 240))
d.rectangle([256, 0, 511, 255], fill=(244, 242, 236))
d.rectangle([256, 140, 511, 170], fill=(64, 140, 92))
d.rectangle([256, 170, 511, 186], fill=(232, 140, 52))
d.text((270, 40), "BISOPROLOL", font=f1, fill=(30, 70, 50))
d.text((270, 80), "2,5 mg", font=f2, fill=(40, 70, 50))
d.text((270, 104), "30 comprimés", font=f2, fill=(80, 80, 90))
# l'étiquette de la pharmacie, collée de travers (posologie à la main)
d.polygon([(280, 196), (420, 192), (422, 240), (282, 244)], fill=(250, 250, 246))
d.text((290, 202), "Mme H.  1 le soir", font=f2, fill=(60, 60, 120))
lab = lab.filter(ImageFilter.GaussianBlur(0.4))
lab.save(OUT + '/boites.png')
print('ok', OUT)
