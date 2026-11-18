"""gen_faience.py OUT_DIR : faïence murale de 15 cm, émail crème brillant, joints gris clair de 2 mm
(lot V2-NUIT, œuvre originale, CC0). 2048 px pour 1,2 m (8 x 8 carreaux), périodique.
Sorties : Faience15_albedo.jpg (sRGB), Faience15_normal_gl.jpg (OpenGL), Faience15_orm.jpg
(R occlusion, G rugosité, B métal = 0)."""
import sys, os
import numpy as np
from PIL import Image

N = 2048
T = 8
P = N // T          # 256 px par carreau (15 cm : 1,71 px/mm)
rng = np.random.default_rng(1504)

def lowfreq(sigma_px, seed):
    r = np.random.default_rng(seed).standard_normal((N, N))
    f = np.fft.fft2(r)
    ky = np.fft.fftfreq(N)[:, None]; kx = np.fft.fftfreq(N)[None, :]
    g = np.exp(-2 * (np.pi * sigma_px) ** 2 * (kx ** 2 + ky ** 2))
    out = np.real(np.fft.ifft2(f * g))
    return out / (out.std() + 1e-9)

y, x = np.mgrid[0:N, 0:N].astype(np.float32)
u = (x % P) + 0.5
v = (y % P) + 0.5
ti = (x // P).astype(int); tj = (y // P).astype(int)
e = np.minimum(np.minimum(u, P - u), np.minimum(v, P - v))   # distance au bord du carreau (px)
G = 2.0             # demi-joint : joint de 4 px = 2,3 mm
B = 5.0             # bord arrondi (coussin) : 3 mm
t = np.clip((e - G) / B, 0, 1)
bevel = np.sqrt(1 - (1 - t) ** 2)                       # quart de rond
joint = (e < G).astype(np.float32)
# soft joint mask for colors (antialias)
jm = np.clip(G + 0.5 - e, 0, 1)

# --- par carreau : teinte et valeur (±3 %), un peu de jaune ou de gris
tile_val = 1 + np.clip(rng.normal(0, 0.012, (T, T)), -0.03, 0.03)
tile_warm = np.clip(rng.normal(0, 0.008, (T, T)), -0.02, 0.02)
tile_rough = np.clip(rng.normal(0, 0.02, (T, T)), -0.04, 0.04)
tv = tile_val[tj, ti]; tw = tile_warm[tj, ti]; trg = tile_rough[tj, ti]

base = np.array([236, 232, 220], np.float32) / 255.0
lin = lambda c: np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
srgb = lambda c: np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(np.clip(c, 0, None), 1 / 2.4) - 0.055)
bl = lin(base)
mott = lowfreq(40, 7) * 0.012 + lowfreq(6, 8) * 0.006       # marbrure de l'émail, très douce
glaze = np.empty((N, N, 3), np.float32)
glaze[..., 0] = bl[0] * tv * (1 + tw + mott)
glaze[..., 1] = bl[1] * tv * (1 + mott)
glaze[..., 2] = bl[2] * tv * (1 - 1.6 * tw + mott)
# crasse au ras des joints (l'émail du bord retient la saleté), légère
edge_dirt = np.clip(1 - (e - G) / 6.0, 0, 1) ** 2
dirt_n = np.clip(0.5 + 0.5 * lowfreq(25, 11), 0, 1)
glaze *= (1 - 0.07 * edge_dirt * (0.4 + 0.6 * dirt_n))[..., None]
# tressaillage (fines fissures de l'émail) sur quelques carreaux
craz = np.zeros((N, N), np.float32)
for k in range(9):
    ci, cj = rng.integers(0, T, 2)
    for line in range(rng.integers(3, 7)):
        px = ci * P + rng.uniform(10, P - 10); py = cj * P + rng.uniform(10, P - 10)
        ang = rng.uniform(0, np.pi)
        for s in range(int(rng.uniform(30, 120))):
            ang += rng.normal(0, 0.25)
            px += np.cos(ang); py += np.sin(ang)
            if not (ci * P + 4 < px < ci * P + P - 4 and cj * P + 4 < py < cj * P + P - 4):
                break
            craz[int(py) % N, int(px) % N] = 1.0
craz = np.maximum(craz, 0.5 * (np.roll(craz, 1, 0) + np.roll(craz, 1, 1)))
glaze *= (1 - 0.05 * craz)[..., None]
# joint : gris clair un peu sale, irrégulier
gbase = lin(np.array([152, 148, 139], np.float32) / 255.0)
gn = lowfreq(3, 21) * 0.06 + lowfreq(30, 22) * 0.08
grout = gbase[None, None, :] * (1 + gn)[..., None]
# le joint du bas d'un carreau, un peu plus sale (l'eau coule)
alb = glaze * (1 - jm[..., None]) + grout * jm[..., None]
alb_s = np.clip(srgb(np.clip(alb, 0, 1)) * 255 + rng.uniform(-0.5, 0.5, (N, N, 3)), 0, 255).astype(np.uint8)

# --- relief
wav = lowfreq(60, 31) * 0.05 + lowfreq(15, 32) * 0.012        # ondulation de l'émail
h = bevel * (1.0 + wav) - 0.25 * joint + joint * lowfreq(2, 33) * 0.04
s = 1.6
dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
nx = -dx * s; ny = dy * s; nz = np.ones_like(h)
ln = np.sqrt(nx * nx + ny * ny + nz * nz)
nrm = np.stack([nx / ln, ny / ln, nz / ln], -1)
nrm_s = np.clip((nrm * 0.5 + 0.5) * 255 + 0.5, 0, 255).astype(np.uint8)

# --- ORM
ao = 1.0 - 0.12 * (1 - bevel) - 0.25 * jm
rough = 0.14 + trg + lowfreq(50, 41) * 0.02 + 0.10 * (1 - bevel) + 0.18 * craz
rough = rough * (1 - jm) + (0.86 + lowfreq(4, 42) * 0.04) * jm
orm = np.stack([np.clip(ao, 0, 1), np.clip(rough, 0.05, 1), np.zeros_like(ao)], -1)
orm_s = np.clip(orm * 255 + 0.5, 0, 255).astype(np.uint8)

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
Image.fromarray(alb_s).save(os.path.join(out, 'Faience15_albedo.jpg'), quality=92)
Image.fromarray(nrm_s).save(os.path.join(out, 'Faience15_normal_gl.jpg'), quality=95)
Image.fromarray(orm_s).save(os.path.join(out, 'Faience15_orm.jpg'), quality=92)
print('albedo moyen sRGB', alb_s.reshape(-1, 3).mean(0).round(1), 'rugosité émail moyenne', float(rough[joint < 0.5].mean()))
