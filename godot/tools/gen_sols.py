"""gen_sols.py TEXTURES_DIR OUT_DIR : (lot V2-NUIT, dérivés CC0)
 - herringbone_parquet_orm_v2.jpg : l'ORM du parquet (Poly Haven, CC0) avec une vraie carte de rugosité,
   tirée de l'albédo : vernis de 0,53 à 0,8 selon les lames et le passage, joints et pores à 0,9 ;
 - moquette_var.png : variation basse fréquence de la moquette (couche de détail multipliée, moyenne 0,92,
   ±8 %), périodique, 512 px."""
import sys, os
import numpy as np
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)

def blur_fft(a, sigma):
    n0, n1 = a.shape
    ky = np.fft.fftfreq(n0)[:, None]; kx = np.fft.fftfreq(n1)[None, :]
    g = np.exp(-2 * (np.pi * sigma) ** 2 * (kx ** 2 + ky ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))

def lowfreq(n, sigma, seed):
    r = np.random.default_rng(seed).standard_normal((n, n))
    o = blur_fft(r, sigma)
    return o / (o.std() + 1e-9)

# --- parquet
alb = np.asarray(Image.open(os.path.join(src, 'herringbone_parquet/herringbone_parquet_albedo.jpg')).convert('RGB')).astype(np.float32) / 255
orm = np.asarray(Image.open(os.path.join(src, 'herringbone_parquet/herringbone_parquet_orm.jpg')).convert('RGB')).astype(np.float32) / 255
L = alb @ np.array([0.2126, 0.7152, 0.0722], np.float32)
N = L.shape[0]
# joints, pores, rayures : plus sombres que leur voisinage immédiat
hp = blur_fft(L, 2.5) - L
joint = np.clip((hp - 0.015) / 0.06, 0, 1)
# lames : écart de teinte à moyenne échelle (une lame claire, une sombre) -> vernis plus ou moins usé
plank = blur_fft(L, 6) - blur_fft(L, 40)
plank = plank / (plank.std() + 1e-9)
# passage : très basse fréquence (3,4 m pour 2048 px : sigma 120 px ~ 20 cm)
traffic = lowfreq(N, 120, 5)
rough = 0.66 + 0.05 * np.clip(plank, -2, 2) + 0.045 * np.clip(traffic, -2, 2)
rough = np.clip(rough, 0.53, 0.8)
rough = rough * (1 - joint) + 0.9 * joint
o2 = np.stack([orm[..., 0], rough, np.zeros_like(rough)], -1)
Image.fromarray(np.clip(o2 * 255 + 0.5, 0, 255).astype(np.uint8)).save(os.path.join(out, 'herringbone_parquet_orm_v2.jpg'), quality=92)
print('parquet : rugosité moyenne %.3f, p5 %.3f, p95 %.3f, joints %.1f %%' % (rough.mean(), np.percentile(rough, 5), np.percentile(rough, 95), 100 * (joint > 0.5).mean()))

# --- moquette
n = 512
v = 0.92 + 0.045 * np.clip(lowfreq(n, 22, 9), -2, 2) + 0.012 * lowfreq(n, 4, 10)
v = np.clip(v, 0.8, 1.0)
Image.fromarray(np.clip(v * 255 + 0.5, 0, 255).astype(np.uint8), 'L').convert('RGB').save(os.path.join(out, 'moquette_var.png'))
print('moquette : moyenne %.3f, min %.3f, max %.3f' % (v.mean(), v.min(), v.max()))
