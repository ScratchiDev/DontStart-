#!/usr/bin/env python3
"""Toiles drapées de la chambre d'amis (lot V2-AMIS) : la bâche de peintre sur le lit et le drap de la
bergère, simulées HORS JEU (dynamique par positions, PBD) puis écrites en tableaux bruts que
tools/amis_toile.gd (Godot, sans rendu) transforme en maillages .res chargés par amis.gd ; plus deux
textures (froissure de la bâche, tissu à pois de la robe du mannequin).

Usage : python3 -I gen_bache.py <dossier de sortie> [lit|bergere|froissure|pois|tout] [--apercu]
  puis : godot --headless --path godot --script res://tools/amis_toile.gd -- <dossier> bache_lit housse_bergere
  (les .res vont dans assets/models/amis/ ; les textures sont à copier dans assets/textures/amis/).
Sorties : <dossier>/<nom>.bin (float32 : sommets, normales, tangentes, UV ; int32 : indices), <nom>.json
(tailles), et avec --apercu des vues de contrôle <nom>_apercu*.png.

Toile : grille de particules (pas de 3 cm), contraintes de distance (structure, cisaillement, flexion à
deux pas), gravité, amortissement de l'air, collisions avec des volumes à bords arrondis (fonctions de
distance signée), frottement sur les appuis. Résolution par lots indépendants (Gauss-Seidel par parité :
deux contraintes d'un même lot ne partagent aucune particule). Aucune autocollision : les plis restent
larges (flexion) et la toile ne s'empile pas au sol (taille réglée pour finir à 1 ou 2 cm du sol).
Déterministe (graine fixe).
"""
import json
import os
import struct
import sys

import numpy as np


# ------------------------------------------------------------------ volumes (distance signée)

def sd_round_box(p, lo, hi, r):
    """Boîte [lo, hi] aux arêtes arrondies de rayon r (le volume reste dans [lo, hi])."""
    c = (lo + hi) / 2.0
    h = (hi - lo) / 2.0 - r
    q = np.abs(p - c) - h
    out = np.linalg.norm(np.maximum(q, 0.0), axis=1)
    inside = np.minimum(np.max(q, axis=1), 0.0)
    return out + inside - r


def sd_ellipsoid(p, c, rad):
    """Ellipsoïde (distance approchée, bonne près de la surface)."""
    q = (p - c) / rad
    k0 = np.linalg.norm(q, axis=1)
    k1 = np.linalg.norm(q / rad, axis=1)
    return np.where(k1 > 1e-9, k0 * (k0 - 1.0) / np.maximum(k1, 1e-9), -np.min(rad))


def sd_capsule(p, a, b, r):
    pa = p - a
    ba = b - a
    t = np.clip((pa @ ba) / (ba @ ba), 0.0, 1.0)
    return np.linalg.norm(pa - np.outer(t, ba), axis=1) - r


class Scene:
    """Union de volumes ; plan du sol y = 0 et plans de murs (point, normale vers la pièce).
    to_world : (R, t) pour les volumes « world=True » quand la toile est simulée dans un repère local
    (p_monde = p @ R.T + t)."""

    def __init__(self, to_world=None):
        self.shapes = []      # (fonction, frottement)
        self.planes = []      # (point, normale, frottement)
        self.to_world = to_world

    def box(self, lo, hi, r, mu=0.85, world=False):
        lo = np.array(lo, float)
        hi = np.array(hi, float)
        if world and self.to_world is not None:
            R, t = self.to_world
            self.shapes.append((lambda p, lo=lo, hi=hi, r=r: sd_round_box(p @ R.T + t, lo, hi, r), mu))
            return
        self.shapes.append((lambda p, lo=lo, hi=hi, r=r: sd_round_box(p, lo, hi, r), mu))

    def ellipsoid(self, c, rad, mu=0.85):
        c = np.array(c, float)
        rad = np.array(rad, float)
        self.shapes.append((lambda p, c=c, rad=rad: sd_ellipsoid(p, c, rad), mu))

    def capsule(self, a, b, r, mu=0.85):
        a = np.array(a, float)
        b = np.array(b, float)
        self.shapes.append((lambda p, a=a, b=b, r=r: sd_capsule(p, a, b, r), mu))

    def plane(self, point, normal, mu=0.6):
        n = np.array(normal, float)
        self.planes.append((np.array(point, float), n / np.linalg.norm(n), mu))

    def collide(self, X, Xprev, thick):
        """Repousse les particules hors des volumes (à « thick » de la surface) ; frottement de position."""
        for f, mu in self.shapes:
            d = f(X)
            hit = d < thick
            if not np.any(hit):
                continue
            P = X[hit]
            e = 1e-4
            g = np.stack([(f(P + [e, 0, 0]) - f(P - [e, 0, 0])), (f(P + [0, e, 0]) - f(P - [0, e, 0])),
                          (f(P + [0, 0, e]) - f(P - [0, 0, e]))], axis=1) / (2 * e)
            g /= np.maximum(np.linalg.norm(g, axis=1), 1e-9)[:, None]
            P = P + g * (thick - d[hit])[:, None]
            # frottement : on retire une part du déplacement tangent depuis l'image d'avant
            dv = P - Xprev[hit]
            dn = np.sum(dv * g, axis=1)[:, None] * g
            P = Xprev[hit] + dn + (dv - dn) * (1.0 - mu)
            X[hit] = P
        for pt, n, mu in self.planes:
            d = (X - pt) @ n
            hit = d < thick
            if not np.any(hit):
                continue
            P = X[hit] + np.outer(thick - d[hit], n)
            dv = P - Xprev[hit]
            dn = np.outer(dv @ n, n)
            P = Xprev[hit] + dn + (dv - dn) * (1.0 - mu)
            X[hit] = P


# ------------------------------------------------------------------ toile

class Cloth:
    def __init__(self, nu, nv, step, origin, axis_u, axis_v, seed=1, flare=None, keep=None):
        self.nu, self.nv, self.step = nu, nv, step
        self.flare = flare
        u = np.arange(nu) * step
        v = np.arange(nv) * step
        U, V = np.meshgrid(u, v)            # [v, u]
        self.uv = np.stack([U.ravel(), V.ravel()], axis=1)
        o = np.array(origin, float)
        au = np.array(axis_u, float)
        av = np.array(axis_v, float)
        self.X = o + np.outer(U.ravel(), au) + np.outer(V.ravel(), av)
        self.rng = np.random.default_rng(seed)
        self.X += self.rng.normal(0.0, 0.0015, self.X.shape)
        self.V = np.zeros_like(self.X)
        self.inv_mass = np.ones(len(self.X))
        # « keep » (u, v) -> bool : la toile n'est pas rectangulaire (un coin replié dessous) ; les particules
        # retirées sont garées hors de tout et ne comptent ni dans les contraintes ni dans le maillage
        self.active = np.ones(len(self.X), bool) if keep is None else keep(self.uv[:, 0], self.uv[:, 1])
        self.X[~self.active] = [0.0, 50.0, 0.0]
        self.inv_mass[~self.active] = 0.0
        self.pin_target = {}
        self.batches = []
        idx = np.arange(nu * nv).reshape(nv, nu)

        def add(a, b, k, parity_axis):
            """Paires (a, b) découpées en lots sans particule commune."""
            rest = self._rest(a, b)
            ok = self.active[a] & self.active[b]
            for key in np.unique(parity_axis):
                m = (parity_axis == key) & ok
                self.batches.append((a[m], b[m], rest[m], k))

        # structure (u puis v), cisaillement, flexion à deux pas
        jj, ii = np.meshgrid(np.arange(nv), np.arange(nu - 1), indexing="ij")
        add(idx[:, :-1].ravel(), idx[:, 1:].ravel(), 1.0, (ii % 2).ravel())
        jj, ii = np.meshgrid(np.arange(nv - 1), np.arange(nu), indexing="ij")
        add(idx[:-1, :].ravel(), idx[1:, :].ravel(), 1.0, (jj % 2).ravel())
        jj, ii = np.meshgrid(np.arange(nv - 1), np.arange(nu - 1), indexing="ij")
        par = ((ii % 2) * 2 + (jj % 2)).ravel()
        add(idx[:-1, :-1].ravel(), idx[1:, 1:].ravel(), 0.9, par)
        add(idx[:-1, 1:].ravel(), idx[1:, :-1].ravel(), 0.9, par)
        self.bend = []
        jj, ii = np.meshgrid(np.arange(nv), np.arange(nu - 2), indexing="ij")
        self.bend.append((idx[:, :-2].ravel(), idx[:, 2:].ravel(), (ii % 4).ravel()))
        jj, ii = np.meshgrid(np.arange(nv - 2), np.arange(nu), indexing="ij")
        self.bend.append((idx[:-2, :].ravel(), idx[2:, :].ravel(), (jj % 4).ravel()))

    def _rest(self, a, b):
        """Longueur au repos ; avec « flare », les bords libres sont plus amples que le milieu (la jupe
        doit onduler pour tenir : des plis qui s'évasent vers l'ourlet, comme une toile qui pend)."""
        d = self.uv[b] - self.uv[a]
        rest = np.linalg.norm(d, axis=1)
        if self.flare is not None:
            m = (self.uv[a] + self.uv[b]) / 2.0
            dirn = np.abs(d) / np.maximum(rest, 1e-9)[:, None]
            rest = rest * self.flare(m, dirn)
        return rest

    def set_bending(self, k):
        for a, b, par in self.bend:
            rest = self._rest(a, b)
            ok = self.active[a] & self.active[b]
            for key in np.unique(par):
                m = (par == key) & ok
                self.batches.append((a[m], b[m], rest[m], k))

    def solve(self, X):
        w = self.inv_mass
        for a, b, rest, k in self.batches:
            d = X[b] - X[a]
            ln = np.linalg.norm(d, axis=1)
            wa = w[a]
            wb = w[b]
            ws = wa + wb
            ok = (ln > 1e-9) & (ws > 0)
            c = np.where(ok, (ln - rest) / np.maximum(ln, 1e-9) / np.maximum(ws, 1e-9), 0.0) * k
            corr = d * c[:, None]
            X[a] += corr * wa[:, None]
            X[b] -= corr * wb[:, None]

    def run(self, scene, frames, iters, dt=1.0 / 90.0, thick=0.006, damping=0.985, pin_fn=None, extra=None):
        g = np.array([0.0, -9.81, 0.0])
        for f in range(frames):
            Xprev = self.X.copy()
            self.V = self.V * damping + g * dt * (self.inv_mass > 0)[:, None]
            X = self.X + self.V * dt
            if pin_fn:
                pin_fn(f, X)
            for _ in range(iters):
                self.solve(X)
                if extra:
                    extra(f, X)
                scene.collide(X, Xprev, thick)
                if pin_fn:
                    pin_fn(f, X)
            self.V = (X - self.X) / dt
            self.X = X
        return self.X

    def triangles(self):
        nu, nv = self.nu, self.nv
        idx = np.arange(nu * nv).reshape(nv, nu)
        a = idx[:-1, :-1].ravel()
        b = idx[:-1, 1:].ravel()
        c = idx[1:, :-1].ravel()
        d = idx[1:, 1:].ravel()
        # diagonale alternée (moins de facettes en biais visibles)
        jj, ii = np.meshgrid(np.arange(nv - 1), np.arange(nu - 1), indexing="ij")
        alt = ((ii + jj) % 2 == 0).ravel()
        t1 = np.where(alt[:, None], np.stack([a, c, b], 1), np.stack([a, c, d], 1))
        t2 = np.where(alt[:, None], np.stack([b, c, d], 1), np.stack([a, d, b], 1))
        T = np.concatenate([t1, t2])
        return T[np.all(self.active[T], axis=1)]


def make_flare(W, L, depth, amount, sides=("u0", "u1", "v0", "v1")):
    """Évasement des bords : à moins de « depth » m d'un bord libre, les longueurs parallèles à ce bord
    grandissent jusqu'à « amount » (fraction) sur le bord même (profil en t²)."""
    def f(m, dirn):
        k = np.ones(len(m))
        for sd in sides:
            if sd == "u0":
                t, par = 1 - m[:, 0] / depth, dirn[:, 1]
            elif sd == "u1":
                t, par = 1 - (W - m[:, 0]) / depth, dirn[:, 1]
            elif sd == "v0":
                t, par = 1 - m[:, 1] / depth, dirn[:, 0]
            else:
                t, par = 1 - (L - m[:, 1]) / depth, dirn[:, 0]
            t = np.clip(t, 0.0, 1.0)
            k += amount * t * t * par
        return k
    return f


# ------------------------------------------------------------------ maillage

def vertex_normals(X, T):
    n = np.zeros_like(X)
    fn = np.cross(X[T[:, 1]] - X[T[:, 0]], X[T[:, 2]] - X[T[:, 0]])
    for k in range(3):
        np.add.at(n, T[:, k], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1), 1e-12)[:, None]


def smooth(X, nu, nv, passes=1, active=None):
    """Lissage laplacien léger (retire le bruit de la simulation, garde les plis) ; seulement entre
    particules actives."""
    G = X.reshape(nv, nu, 3).copy()
    A = np.ones((nv, nu)) if active is None else active.reshape(nv, nu).astype(float)
    for _ in range(passes):
        acc = 4 * G[1:-1, 1:-1] * A[1:-1, 1:-1, None]
        cnt = 4 * A[1:-1, 1:-1]
        for sl in ((slice(None, -2), slice(1, -1)), (slice(2, None), slice(1, -1)),
                   (slice(1, -1), slice(None, -2)), (slice(1, -1), slice(2, None))):
            acc = acc + G[sl] * A[sl][..., None]
            cnt = cnt + A[sl]
        S = G.copy()
        inner = A[1:-1, 1:-1] > 0
        S[1:-1, 1:-1][inner] = (acc / np.maximum(cnt, 1e-9)[..., None])[inner]
        G = S
    return G.reshape(-1, 3)


def compact(X, uv, T):
    """Ne garde que les sommets utilisés par les triangles."""
    used = np.unique(T)
    remap = -np.ones(len(X), int)
    remap[used] = np.arange(len(used))
    return X[used], uv[used], remap[T]


def build(X, uv, T, outward_hint, offset=0.0015):
    """Double face : face extérieure (normales vers outward_hint en moyenne) et face intérieure décalée de
    « offset » vers l'intérieur, aux normales et au sens inversés. Tangentes le long de u."""
    N = vertex_normals(X, T)
    # orientation : la majorité des normales doit pointer vers le haut / l'extérieur
    if np.mean(np.sum(N * outward_hint(X), axis=1)) < 0:
        T = T[:, [0, 2, 1]]
        N = -N
    # tangente : dérivée de la position selon u (différences sur la grille)
    tan = np.zeros_like(X)
    fu = np.zeros_like(X)
    e1 = X[T[:, 1]] - X[T[:, 0]]
    e2 = X[T[:, 2]] - X[T[:, 0]]
    d1 = uv[T[:, 1]] - uv[T[:, 0]]
    d2 = uv[T[:, 2]] - uv[T[:, 0]]
    r = d1[:, 0] * d2[:, 1] - d2[:, 0] * d1[:, 1]
    r = np.where(np.abs(r) < 1e-12, 1e-12, r)
    t = (e1 * d2[:, 1:2] - e2 * d1[:, 1:2]) / r[:, None]
    b = (e2 * d1[:, 0:1] - e1 * d2[:, 0:1]) / r[:, None]
    bit = np.zeros_like(X)
    for k in range(3):
        np.add.at(tan, T[:, k], t)
        np.add.at(bit, T[:, k], b)
    tan = tan - N * np.sum(tan * N, axis=1)[:, None]
    tan /= np.maximum(np.linalg.norm(tan, axis=1), 1e-12)[:, None]
    w = np.where(np.sum(np.cross(N, tan) * bit, axis=1) < 0, -1.0, 1.0)
    n = len(X)
    Xi = X - N * offset
    Xa = np.concatenate([X, Xi])
    Na = np.concatenate([N, -N])
    Ta = np.concatenate([np.c_[tan, w], np.c_[tan, -w]])
    UVa = np.concatenate([uv, uv])
    Ia = np.concatenate([T, T[:, [0, 2, 1]] + n])
    return Xa, Na, Ta, UVa, Ia


def write(out, name, Xa, Na, Ta, UVa, Ia, info):
    # Godot : triangles dans le sens horaire vu de face ; nos triangles sont dans le sens direct
    Ia = Ia[:, [0, 2, 1]]
    with open(os.path.join(out, name + ".bin"), "wb") as f:
        for arr in (Xa, Na, Ta, UVa):
            f.write(np.asarray(arr, np.float32).tobytes())
        f.write(np.asarray(Ia, np.int32).tobytes())
    info = dict(info)
    info.update({"vertices": int(len(Xa)), "indices": int(Ia.size)})
    with open(os.path.join(out, name + ".json"), "w") as f:
        json.dump(info, f, indent=1)


# ------------------------------------------------------------------ aperçu (contrôle, sans Godot)

def preview(path, X, T, eye, target, size=(640, 400), fov=60.0, floor=None):
    from PIL import Image
    W, H = size
    shade = None
    if floor is not None:
        # sol : un grand carré gris (repère visuel de la hauteur de l'ourlet)
        x0, x1, z0, z1 = floor
        base = len(X)
        X = np.concatenate([X, [[x0, 0, z0], [x1, 0, z0], [x0, 0, z1], [x1, 0, z1]]])
        T = np.concatenate([T, [[base, base + 2, base + 1], [base + 1, base + 2, base + 3]]])
    f = np.array(target, float) - np.array(eye, float)
    f /= np.linalg.norm(f)
    r = np.cross(f, [0, 1, 0])
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    P = X - eye
    x = P @ r
    y = P @ u
    z = P @ f
    k = (H / 2) / np.tan(np.radians(fov / 2))
    sx = W / 2 + k * x / z
    sy = H / 2 - k * y / z
    zb = np.full((H, W), np.inf)
    img = np.zeros((H, W))
    N = vertex_normals(X, T)
    light = np.array([0.4, 0.8, 0.3])
    light /= np.linalg.norm(light)
    for t in T:
        xs = sx[t]
        ys = sy[t]
        x0, x1 = int(max(np.floor(xs.min()), 0)), int(min(np.ceil(xs.max()), W - 1))
        y0, y1 = int(max(np.floor(ys.min()), 0)), int(min(np.ceil(ys.max()), H - 1))
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        d = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
        if abs(d) < 1e-9:
            continue
        l0 = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / d
        l1 = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / d
        l2 = 1 - l0 - l1
        m = (l0 >= 0) & (l1 >= 0) & (l2 >= 0)
        if not m.any():
            continue
        zz = l0 * z[t[0]] + l1 * z[t[1]] + l2 * z[t[2]]
        nn = l0[..., None] * N[t[0]] + l1[..., None] * N[t[1]] + l2[..., None] * N[t[2]]
        sh = np.abs(nn @ light) * 0.8 + 0.15
        if floor is not None and t[0] >= len(X) - 4:
            sh = np.full_like(sh, 0.3) + 0.08 * ((np.floor(gx / 8) + np.floor(gy / 8)) % 2)
        sub = zb[y0:y1 + 1, x0:x1 + 1]
        upd = m & (zz < sub)
        sub[upd] = zz[upd]
        img[y0:y1 + 1, x0:x1 + 1][upd] = sh[upd]
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(path)


# ------------------------------------------------------------------ le lit (repère de la pièce)

# Lit Kenney « bedDouble » posé par amis.gd : prop(bedDouble, (0, 0, 5.25), 180°, (1.5, 0, 2.0)) ;
# boîtes mesurées sur le .glb (outil bed_height.py du lot) : cadre x ±0.745, z 4.25 → 6.25 ; housse
# (cover) jusqu'à 0.435 ; oreillers x ±(0.04 → 0.57), z 5.72 → 6.07, 0.474 ; tête de lit z 6.07 → 6.25,
# 0.628. Dessus, sous la bâche : le carton droit (x 0.13 → 0.55, z 4.46 → 4.84, 0.445 → 0.745) et les
# couvertures pliées (x −0.62 → −0.10, z 4.56 → 5.14, jusqu'à 0.585). Mur du pignon : z = 6.288.
LIT = {
    "W": 2.49, "L": 2.39, "step": 0.03, "dx": 0.026, "flare": 0.16, "pin_y": 0.648, "pin_z": 6.19,
}


def bed_scene():
    s = Scene()
    s.box([-0.748, 0.0, 4.255], [0.748, 0.437, 6.075], 0.05, 0.9)          # cadre, matelas, housse
    for sx in (-1, 1):
        s.ellipsoid([sx * 0.306, 0.425, 5.895], [0.27, 0.052, 0.18], 0.9)   # oreillers
    s.box([-0.748, 0.0, 6.07], [0.748, 0.632, 6.252], 0.03, 0.9)           # tête de lit
    s.box([0.125, 0.43, 4.455], [0.555, 0.748, 4.845], 0.012, 0.9)         # le carton
    s.box([-0.625, 0.43, 4.555], [-0.095, 0.588, 5.145], 0.03, 0.9)        # couvertures pliées
    s.plane([0, 0, 0], [0, 1, 0], 0.7)                                     # sol
    s.plane([0, 0, 6.284], [0, 0, -1], 0.3)                                # pignon
    # voisins (mesurés dans le jeu, banc du lot) : le chevet (et ce qui est posé dessus : la bâche ne s'y
    # pose pas), le tapis (8 mm)
    s.box([0.962, 0.0, 5.808], [1.338, 0.95, 6.092], 0.01, 0.0)
    s.box([-1.095, -0.05, 3.345], [0.695, 0.0088, 4.455], 0.004, 0.7)
    return s


def gen_bed(out, apercu):
    p = LIT
    step = p["step"]
    nu = int(round(p["W"] / step)) + 1
    nv = int(round(p["L"] / step)) + 1
    W = (nu - 1) * step
    L = (nv - 1) * step
    # toile à plat au-dessus du lit (u le long de x, v de la tête vers le pied)
    # côté chevet (tête, x > 0), la bâche a été recoupée : le chevet n'est qu'à 21 cm du lit, elle s'y
    # accrocherait (encoche droite, le long des fils de la grille : pas d'escalier)
    def keep(u, v):
        return ~(((W - u) < 0.15) & (v < 0.36))

    cl = Cloth(nu, nv, step, [-W / 2 + p["dx"], 0.80, p["pin_z"]], [1, 0, 0], [0, 0, -1], seed=7,
               flare=make_flare(W, L, 0.5, p["flare"], ("u0", "u1", "v1")), keep=keep)
    # ourlet irrégulier : la coupe n'est pas droite (± 2 cm) — on raccourcit les bords libres au hasard
    idx = np.arange(nu * nv).reshape(nv, nu)
    cl.set_bending(0.06)
    head = idx[0]
    pin_x = cl.X[head, 0]
    pinned = head[(np.abs(pin_x - p["dx"]) <= 0.69) & cl.active[head]]
    cl.inv_mass[pinned] = 0.0
    start = cl.X[pinned].copy()
    goal = start.copy()
    goal[:, 1] = p["pin_y"]
    goal[:, 2] = p["pin_z"]

    def pin_fn(f, X):
        k = min(1.0, f / 60.0)
        X[pinned] = start * (1 - k) + goal * k

    scene = bed_scene()
    X = cl.run(scene, 520, 14, pin_fn=pin_fn)
    X = smooth(X, nu, nv, 1, cl.active)
    scene.collide(X, X.copy(), 0.004)
    T = cl.triangles()
    uv = cl.uv.copy()

    def outward(Xp):
        c = np.array([0.0, 0.2, 5.2])
        d = Xp - c
        d[:, 1] *= 2.0
        return d

    hem = X.reshape(nv, nu, 3)
    act = cl.active.reshape(nv, nu)
    for nm, e in (("pied", hem[-1][act[-1]]), ("gauche (x<0)", hem[:, 0][act[:, 0]]), ("droite (x>0)", hem[:, -1][act[:, -1]])):
        print("lit, ourlet %s : y min %.3f, médiane %.3f, max %.3f" % (nm, e[:, 1].min(), np.median(e[:, 1]), e[:, 1].max()))
    print("lit : %d × %d particules ; sous 1 cm : %d" % (nu, nv, int(np.sum(X[:, 1] < 0.01))))
    Xc, uvc, Tc = compact(X, uv, T)
    Xa, Na, Ta, UVa, Ia = build(Xc, uvc, Tc, outward)
    write(out, "bache_lit", Xa, Na, Ta, UVa, Ia, {"nu": nu, "nv": nv, "step": step})
    if apercu:
        fl = (-3.2, 3.2, 2.7, 6.3)
        preview(os.path.join(out, "bache_lit_apercu.png"), X, T, [2.85, 1.6, 2.95], [0.0, 0.4, 4.5], floor=fl)
        preview(os.path.join(out, "bache_lit_apercu2.png"), X, T, [-2.85, 1.6, 2.95], [0.0, 0.4, 4.5], floor=fl)
        preview(os.path.join(out, "bache_lit_apercu3.png"), X, T, [2.2, 0.5, 5.25], [0.0, 0.3, 5.25], floor=fl)
    return X


# ------------------------------------------------------------------ la bergère (repère du fauteuil, avant vers +z)

BERGERE = {"W": 1.82, "L": 2.12, "step": 0.03, "tuck_v": 1.02, "flare": 0.14}


# Bergère de amis.gd : FauteuilHousse en ARMCHAIR_POS (1.95, 0, 5.74), rotation.y = PI + 0.12.
CHAIR_POS = np.array([1.95, 0.0, 5.74])
CHAIR_YAW = np.pi + 0.12


def chair_to_world():
    c, s_ = np.cos(CHAIR_YAW), np.sin(CHAIR_YAW)
    R = np.array([[c, 0, s_], [0, 1, 0], [-s_, 0, c]])
    return R, CHAIR_POS


def chair_scene():
    s = Scene(chair_to_world())
    s.box([-0.30, 0.0, -0.24], [0.30, 0.44, 0.33], 0.07, 0.95)            # assise (coussin) et ceinture
    for sx in (-1, 1):
        lo = [0.27, 0.0, -0.31] if sx > 0 else [-0.38, 0.0, -0.31]
        hi = [0.38, 0.58, 0.31] if sx > 0 else [-0.27, 0.58, 0.31]
        s.box(lo, hi, 0.04, 0.95)                                          # joues des accoudoirs
        s.capsule([sx * 0.325, 0.60, -0.30], [sx * 0.325, 0.60, 0.29], 0.055, 0.95)   # manchettes
    s.box([-0.37, 0.0, -0.38], [0.37, 0.86, -0.21], 0.06, 0.95)            # dossier
    s.ellipsoid([0.0, 0.86, -0.295], [0.31, 0.13, 0.085], 0.95)            # chapeau de gendarme
    s.plane([0, 0, 0], [0, 1, 0], 0.75)
    # voisins, dans le repère de la pièce : chevet, cartons fermés, pignon
    s.box([0.962, 0.0, 5.808], [1.338, 0.95, 6.092], 0.01, 0.0, world=True)
    s.box([2.53, 0.0, 5.18], [2.97, 0.425, 5.62], 0.01, 0.0, world=True)
    s.box([2.526, 0.0, 5.72], [2.974, 0.345, 6.29], 0.01, 0.0, world=True)
    s.box([-5.0, 0.0, 6.284], [5.0, 3.0, 7.0], 0.0, 0.3, world=True)
    return s


def gen_chair(out, apercu):
    p = BERGERE
    step = p["step"]
    nu = int(round(p["W"] / step)) + 1
    nv = int(round(p["L"] / step)) + 1
    W = (nu - 1) * step
    L = (nv - 1) * step
    # drap jeté par-dessus le dossier (v de l'arrière vers l'avant), à plat au-dessus du fauteuil ; la
    # ligne v = tuck_v (du bord arrière) tombe dans le creux entre l'assise et le dossier, où le drap est
    # rentré (épinglé : le coussin le serre)
    tv = p["tuck_v"]
    z_back = -0.19 - tv
    cl = Cloth(nu, nv, step, [-W / 2, 1.12, z_back], [1, 0, 0], [0, 0, 1], seed=11,
               flare=make_flare(W, L, 0.45, p["flare"]))
    # (départ : la partie arrière pend déjà derrière le dossier, à z = -0.44 : à plat, elle traverserait
    # le mur du pignon, 16 cm derrière)
    zb = -0.44
    back = cl.X[:, 2] < zb
    cl.X[back, 1] = 1.12 - (zb - cl.X[back, 2])
    cl.X[back, 2] = zb
    cl.set_bending(0.09)
    scene = chair_scene()
    G = np.arange(nu * nv).reshape(nv, nu)
    row = int(round(tv / step))
    cols = [i for i in range(nu) if abs(i * step - W / 2) <= 0.21]
    tuck = G[row, cols]
    cl.inv_mass[tuck] = 0.0
    t_start = cl.X[tuck].copy()
    t_goal = t_start.copy()
    t_goal[:, 1] = 0.47 - 0.02 * np.cos(np.linspace(-1.2, 1.2, len(cols)))
    t_goal[:, 2] = -0.185

    def pin_fn(f, X):
        k = min(1.0, f / 90.0)
        k = k * k * (3 - 2 * k)
        X[tuck] = t_start * (1 - k) + t_goal * k

    X = cl.run(scene, 560, 14, pin_fn=pin_fn)
    X = smooth(X, nu, nv, 1)
    scene.collide(X, X.copy(), 0.004)
    T = cl.triangles()

    def outward(Xp):
        d = Xp - np.array([0.0, 0.3, 0.0])
        return d

    hem = X.reshape(nv, nu, 3)
    for nm, e in (("arrière", hem[0]), ("avant", hem[-1]), ("gauche", hem[:, 0]), ("droite", hem[:, -1])):
        print("bergère, bord %s : y min %.3f, médiane %.3f, max %.3f" % (nm, e[:, 1].min(), np.median(e[:, 1]), e[:, 1].max()))
    print("bergère : %d × %d particules ; sous 1 cm : %d" % (nu, nv, int(np.sum(X[:, 1] < 0.01))))
    Xc, uvc, Tc = compact(X, cl.uv.copy(), T)
    Xa, Na, Ta, UVa, Ia = build(Xc, uvc, Tc, outward)
    write(out, "housse_bergere", Xa, Na, Ta, UVa, Ia, {"nu": nu, "nv": nv, "step": step})
    if apercu:
        fl = (-1.5, 1.5, -1.5, 1.5)
        preview(os.path.join(out, "housse_apercu.png"), X, T, [0.9, 1.4, 1.9], [0.0, 0.45, 0.0], floor=fl)
        preview(os.path.join(out, "housse_apercu2.png"), X, T, [-1.6, 1.3, 0.8], [0.0, 0.45, 0.0], floor=fl)
        preview(os.path.join(out, "housse_apercu3.png"), X, T, [1.8, 0.45, 0.1], [0.0, 0.4, 0.0], floor=fl)
    return X


# ------------------------------------------------------------------ froissure du polyéthylène (normale)

def gen_crinkle(path, size=1024, tile=0.8, seed=5):
    """Carte de normales (OpenGL, raccordable) d'une bâche de peintre en polyéthylène froissée : la hauteur
    est faite de « tentes » (profil en V, pentes droites : des facettes) le long de plis rectilignes —
    une grille de plis d'emballage (la bâche a été pliée en paquet : 4 × 3 par tuile, soit tous les 20 à
    27 cm) et des centaines de faux plis de 2 à 25 cm de toutes orientations — plus un grain fin.
    « tile » m par répétition (UV de la toile en m)."""
    from PIL import Image
    rng = np.random.default_rng(seed)
    px = tile / size
    H = np.zeros((size, size))

    def crease(cx, cy, ang, length, width, slope):
        # pli rectiligne (pixels) : tente de demi-largeur « width », pente « slope », bouts effilés (tore)
        r = int(length / 2 + width) + 2
        x0, y0 = int(cx) - r, int(cy) - r
        ys = (np.arange(y0, y0 + 2 * r + 1)) % size
        xs = (np.arange(x0, x0 + 2 * r + 1)) % size
        gy, gx = np.mgrid[y0:y0 + 2 * r + 1, x0:x0 + 2 * r + 1].astype(float)
        dx, dy = gx - cx, gy - cy
        c, s_ = np.cos(ang), np.sin(ang)
        along = dx * c + dy * s_
        perp = -dx * s_ + dy * c
        t = np.clip(1.0 - np.abs(along) / (length / 2), 0.0, 1.0)
        prof = slope * np.maximum(0.0, width - np.abs(perp)) * np.minimum(1.0, 3.0 * t)
        H[np.ix_(ys, xs)] += prof

    # plis d'emballage : droites qui traversent toute la tuile (distance mesurée sur le tore)
    ii = np.arange(size, dtype=float)
    for k in range(4):
        x = (k + 0.5) * size / 4 + rng.normal(0, 3)
        d = np.abs((ii - x + size / 2) % size - size / 2)
        H += rng.choice([-1, 1]) * 0.09 * np.maximum(0.0, 0.03 / px - d)[None, :]
    for k in range(3):
        y = (k + 0.5) * size / 3 + rng.normal(0, 3)
        d = np.abs((ii - y + size / 2) % size - size / 2)
        H += rng.choice([-1, 1]) * 0.09 * np.maximum(0.0, 0.03 / px - d)[:, None]
    for _ in range(700):
        L = np.exp(rng.uniform(np.log(0.02 / px), np.log(0.25 / px)))
        w = L * rng.uniform(0.06, 0.16)
        crease(rng.uniform(0, size), rng.uniform(0, size), rng.uniform(0, np.pi), L, w,
               rng.choice([-1, 1]) * rng.uniform(0.02, 0.08))
    g = rng.normal(0, 1, (size, size))
    for _ in range(3):
        g = (g + np.roll(g, 1, 0) + np.roll(g, -1, 0) + np.roll(g, 1, 1) + np.roll(g, -1, 1)) / 5
    H += g * 0.25
    gx = (np.roll(H, -1, 1) - np.roll(H, 1, 1)) / 2
    gr = (np.roll(H, -1, 0) - np.roll(H, 1, 0)) / 2
    k = 1.0
    n = np.stack([-gx * k, gr * k, np.ones_like(H)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    img = ((n * 0.5 + 0.5) * 255).round().clip(0, 255).astype(np.uint8)
    Image.fromarray(img).save(path, quality=92)
    print("froissure :", path, "pente moyenne %.3f" % float(np.mean(np.hypot(gx, gr) * k)))


# ------------------------------------------------------------------ tissu de la robe (albédo)

def gen_dots(path, size=256, cells=8, seed=3):
    """Tissu bleu marine à pois crème (la robe du mannequin) : « cells » × « cells » pois en quinconce par
    tuile, bords adoucis, léger chiné du fil. Une tuile = cells × 2,4 cm (pois de 1 cm) : uv1_scale de la
    robe = 1 / (cells × 0,024) avec des UV en mètres."""
    from PIL import Image
    rng = np.random.default_rng(seed)
    c = size / cells
    yy, xx = np.mgrid[0:size, 0:size].astype(float) + 0.5
    row = np.floor(yy / c)
    cx = c * 0.5 + np.where(row % 2 == 1, c * 0.5, 0.0)
    dx = (xx - cx) % c - c / 2
    dy = yy % c - c / 2
    r = np.hypot(dx, dy)
    k = np.clip(c * 0.205 - r + 0.5, 0.0, 1.0)
    navy = np.array([0.105, 0.12, 0.2])
    cream = np.array([0.8, 0.78, 0.72])
    yarn = rng.normal(0, 1, (size, size))
    yarn = (yarn + np.roll(yarn, 1, 1)) / 2
    base = navy * (1.0 + 0.06 * yarn)[..., None]
    img = base * (1 - k[..., None]) + cream * (1.0 + 0.03 * yarn)[..., None] * k[..., None]
    Image.fromarray((np.clip(img, 0, 1) ** (1 / 1.0) * 255).round().astype(np.uint8)).save(path)
    print("pois :", path)


if __name__ == "__main__":
    out = sys.argv[1]
    what = sys.argv[2] if len(sys.argv) > 2 else "tout"
    apercu = "--apercu" in sys.argv
    os.makedirs(out, exist_ok=True)
    if what in ("lit", "tout"):
        gen_bed(out, apercu)
    if what in ("bergere", "tout"):
        gen_chair(out, apercu)
    if what in ("froissure", "tout"):
        gen_crinkle(os.path.join(out, "bache_normal_gl.jpg"))
    if what in ("pois", "tout"):
        gen_dots(os.path.join(out, "robe_pois.png"))
