#!/usr/bin/env python3
"""Mains du joueur (vue à la première personne) : main droite + poignet tirés du maillage de base de
MakeHuman (CC0), doigts posés en prise autour du corps de la lampe de poche (squelette et poids MakeHuman,
skinning linéaire), une subdivision Catmull-Clark, normales propres ; peau générée (albédo, normales,
rugosité, occlusion cuite dans la pose) ; manche de sweat (tube lofté, plis, bord-côte) ; lampe de poche
des années 90 (tour). Export en .glb dans godot/assets/models/mains/.

Données : MakeHuman (makehuman/data : 3dobjs/base.obj, rigs/default.mhskel, rigs/default_weights.mhw,
targets/…), lues comme des fichiers (aucun code de MakeHuman n'est lancé).

  python3 -I godot/tools/make_hands.py [--mh /chemin/makehuman] [--out godot/assets/models/mains]
         [--variante alexandre|aurelia|toutes] [--apercu DIR] [--tex 2048]
Dépendances : numpy, scipy, pillow (et embreex pour l'occlusion, sinon une version plus lente).
"""
import argparse, json, math, os, struct, sys, time
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
MH_DEFAULT = '/home/user/makehumancommunity/makehuman'
OUT_DEFAULT = os.path.normpath(os.path.join(HERE, '..', 'assets', 'models', 'mains'))

# ----------------------------------------------------------------------------- MakeHuman

class MH:
    def __init__(self, root):
        self.data = os.path.join(root, 'makehuman', 'data')
        if not os.path.isdir(self.data):
            self.data = os.path.join(root, 'data')
        self._load_obj()
        self.sk = json.load(open(os.path.join(self.data, 'rigs', 'default.mhskel')))
        self.weights = json.load(open(os.path.join(self.data, 'rigs', 'default_weights.mhw')))['weights']

    def _load_obj(self):
        V, VT, F, FT, FG = [], [], [], [], []
        g = None
        for line in open(os.path.join(self.data, '3dobjs', 'base.obj')):
            if line.startswith('v '):
                V.append([float(x) for x in line.split()[1:4]])
            elif line.startswith('vt '):
                VT.append([float(x) for x in line.split()[1:3]])
            elif line.startswith('g '):
                g = line.split()[1]
            elif line.startswith('f '):
                p = [q.split('/') for q in line.split()[1:]]
                F.append([int(a[0]) - 1 for a in p])
                FT.append([int(a[1]) - 1 for a in p])
                FG.append(g)
        self.V = np.array(V)
        self.VT = np.array(VT)
        self.F = np.array(F)
        self.FT = np.array(FT)
        self.FG = np.array(FG)

    def target(self, name):
        idx, d = [], []
        for line in open(os.path.join(self.data, 'targets', name)):
            if line.startswith('#') or not line.strip():
                continue
            p = line.split()
            idx.append(int(p[0]))
            d.append([float(p[1]), float(p[2]), float(p[3])])
        return np.array(idx, int), np.array(d).reshape(-1, 3)

    def morphed(self, morphs):
        V = self.V.copy()
        for name, w in morphs:
            if abs(w) < 1e-6:
                continue
            i, d = self.target(name)
            if len(i):
                np.add.at(V, i, w * d)
        return V

    def joints(self, V):
        return {k: V[v].mean(0) for k, v in self.sk['joints'].items()}


## Morphes par héros. Âge : 16 ans, entre « child » (11 ans) et « young » (25 ans) dans MakeHuman ; on
## penche vers « young » (une main de 16 ans est presque adulte). Origines : moyenne de MakeHuman,
## un peu plus « caucasian » (la peau est générée à part).
VARIANTES = {
    'alexandre': dict(gender='male', young=0.62, minweight=0.35, minmuscle=0.0, maxmuscle=0.15,
                      hand=[('armslegs/r-hand-fingers-diameter-decr.target', 0.10)],
                      longueur=0.186),     # main de garçon de 16 ans, poignet → bout du majeur (m)
    'aurelia': dict(gender='female', young=0.58, minweight=0.55, minmuscle=0.35, maxmuscle=0.0,
                    hand=[('armslegs/r-hand-fingers-diameter-decr.target', 0.95),
                          ('armslegs/r-hand-fingers-length-incr.target', 0.30),
                          ('armslegs/r-lowerarm-scale-horiz-decr.target', 0.55),
                          ('armslegs/r-lowerarm-scale-depth-decr.target', 0.45),
                          ('armslegs/r-lowerarm-muscle-decr.target', 0.5)],
                    longueur=0.171, bracelet=True),
}
ETHNIES = [('caucasian', 0.6), ('african', 0.2), ('asian', 0.2)]


def morph_list(var):
    g = var['gender']
    ages = [('young', var['young']), ('child', 1.0 - var['young'])]
    out = []
    for eth, we in ETHNIES:
        for age, wa in ages:
            out.append(('macrodetails/%s-%s-%s.target' % (eth, g, age), we * wa))
    for age, wa in ages:
        if var['minweight'] > 0:
            out.append(('macrodetails/universal-%s-%s-averagemuscle-minweight.target' % (g, age), wa * var['minweight']))
        if var['minmuscle'] > 0:
            out.append(('macrodetails/universal-%s-%s-minmuscle-averageweight.target' % (g, age), wa * var['minmuscle']))
        if var['maxmuscle'] > 0:
            out.append(('macrodetails/universal-%s-%s-maxmuscle-averageweight.target' % (g, age), wa * var['maxmuscle']))
    out += var['hand']
    return out

# ----------------------------------------------------------------------------- squelette de la main

HAND_BONES = ['lowerarm02.R', 'wrist.R',
              'metacarpal1.R', 'metacarpal2.R', 'metacarpal3.R', 'metacarpal4.R',
              'finger1-1.R', 'finger1-2.R', 'finger1-3.R',
              'finger2-1.R', 'finger2-2.R', 'finger2-3.R',
              'finger3-1.R', 'finger3-2.R', 'finger3-3.R',
              'finger4-1.R', 'finger4-2.R', 'finger4-3.R',
              'finger5-1.R', 'finger5-2.R', 'finger5-3.R']


def normalize(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v, axis=-1, keepdims=True)


def rot(axis, ang):
    """Matrice de rotation (Rodrigues), angle en radians."""
    a = normalize(axis)
    x, y, z = a
    c, s = math.cos(ang), math.sin(ang)
    C = 1 - c
    return np.array([[c + x * x * C, x * y * C - z * s, x * z * C + y * s],
                     [y * x * C + z * s, c + y * y * C, y * z * C - x * s],
                     [z * x * C - y * s, z * y * C + x * s, c + z * z * C]])


class Hand:
    """Région main + poignet + bas de l'avant-bras, squelette au repos et pose (skinning linéaire)."""

    def __init__(self, mh, V, cut=0.75):
        self.mh = mh
        sk = mh.sk
        J = mh.joints(V)
        self.head = {b: J[sk['bones'][b]['head']] for b in HAND_BONES}
        self.tail = {b: J[sk['bones'][b]['tail']] for b in HAND_BONES}
        self.parent = {b: sk['bones'][b]['parent'] for b in HAND_BONES}
        # repère de la main : avant (poignet → majeur), côté pouce, dos
        W = self.head['wrist.R']
        m2, m3, m5 = self.head['finger2-1.R'], self.head['finger3-1.R'], self.head['finger5-1.R']
        fwd = normalize(m3 - W)
        lat = normalize(m2 - m5)
        lat = normalize(lat - fwd * np.dot(lat, fwd))
        n = np.cross(fwd, lat)
        # région : poids de la chaîne de la main et de l'avant-bras
        wts = mh.weights
        nv = len(V)
        body = np.zeros(nv, bool)
        body[np.unique(mh.F[mh.FG == 'body'])] = True
        hw = np.zeros(nv)
        for b in HAND_BONES + ['lowerarm01.R']:
            for vi, w in wts.get(b, []):
                hw[vi] += w
        arm_dir = normalize(self.head['wrist.R'] - J[sk['bones']['lowerarm01.R']['head']])
        self.arm_dir = arm_dir
        along = (V - W) @ arm_dir          # > 0 côté main (unités MakeHuman : le décimètre)
        keep = body & (hw > 0.5) & (along > -cut)
        fmask = (mh.FG == 'body') & keep[mh.F].all(1)
        self.faces_all = np.where(fmask)[0]
        used = np.unique(mh.F[fmask])
        self.vidx = used
        remap = -np.ones(nv, int)
        remap[used] = np.arange(len(used))
        self.F = remap[mh.F[fmask]]
        self.FT = mh.FT[fmask]
        self.V0 = V[used].copy()
        # le dos de la main : le côté où la paume est la moins épaisse (les os sont près du dos)
        mc = [vi for vi, w in wts['metacarpal2.R'] if w > 0.6]
        P = V[mc] - (self.head['metacarpal2.R'] + self.tail['metacarpal2.R']) / 2
        if (P @ n).max() > -(P @ n).min():
            n = -n
        self.fwd, self.lat, self.dorsal = fwd, np.cross(n, fwd), n
        # poids (n_v × n_os) ; le reste du poids (avant-bras, bras) ne bouge pas
        self.bones = HAND_BONES
        Wm = np.zeros((len(used), len(HAND_BONES)))
        for j, b in enumerate(HAND_BONES):
            for vi, w in wts.get(b, []):
                if remap[vi] >= 0:
                    Wm[remap[vi], j] += w
        tot = Wm.sum(1)
        # (les poids de MakeHuman somment à 1 par sommet, bras compris)
        self.W = Wm
        self.W_rest = np.clip(1.0 - tot, 0.0, 1.0)
        # repères des os au repos : y le long de l'os, z vers le dos de la main
        self.frame = {}
        for b in HAND_BONES:
            y = normalize(self.tail[b] - self.head[b])
            z = self.dorsal - y * np.dot(self.dorsal, y)
            if b.startswith('finger1'):
                # pouce : son « dos » (l'ongle) regarde vers l'extérieur de la paume
                z = self.dorsal * 0.35 + np.cross(n, fwd) * 0.65
                z = z - y * np.dot(z, y)
            z = normalize(z)
            x = np.cross(y, z)
            self.frame[b] = np.stack([x, y, z], 1)   # colonnes

    def pose(self, params):
        """params : {os: (flexion, abduction, torsion) en degrés}. Rend les matrices 4×4 globales."""
        G = {}
        for b in self.bones:
            R = np.eye(3)
            if b in params:
                fl, ab, tw = [math.radians(a) for a in params[b]]
                Fr = self.frame[b]
                # flexion : autour de x (le bout de l'os va vers la paume, -z)
                Rl = rot([1, 0, 0], -fl) @ rot([0, 0, 1], ab) @ rot([0, 1, 0], tw)
                R = Fr @ Rl @ Fr.T
            h = self.head[b]
            D = np.eye(4)
            D[:3, :3] = R
            D[:3, 3] = h - R @ h
            p = self.parent[b]
            G[b] = (G[p] @ D) if p in G else D
        return G

    def skin(self, G, V=None):
        V = self.V0 if V is None else V
        Vh = np.c_[V, np.ones(len(V))]
        out = V * self.W_rest[:, None]
        for j, b in enumerate(self.bones):
            w = self.W[:, j]
            m = w > 0
            if m.any():
                out[m] += w[m, None] * (Vh[m] @ G[b].T)[:, :3]
        return out

    def joint_pos(self, G, b, which='head'):
        p = self.head[b] if which == 'head' else self.tail[b]
        return (G[b] @ np.r_[p, 1.0])[:3]

    def to_metric(self, length):
        """Origine au poignet, unités en mètres, longueur poignet → bout du majeur = length."""
        o = self.head['wrist.R'].copy()
        L = np.linalg.norm(self.tail['finger3-3.R'] - o)
        s = length / L
        self.scale = s
        self.V0 = (self.V0 - o) * s
        for d in (self.head, self.tail):
            for b in d:
                d[b] = (d[b] - o) * s
        return s

    def bone_of_vertex(self):
        return np.argmax(self.W, 1)

# ----------------------------------------------------------------------------- la prise

class Grip:
    """Cylindre de la lampe dans le repère de la main : point c, axe g (vers la tête de la lampe), rayon r."""

    def __init__(self, c, g, r):
        self.c, self.g, self.r = np.asarray(c, float), normalize(g), float(r)

    def dist(self, P):
        d = P - self.c
        s = d @ self.g
        radial = d - np.outer(s, self.g)
        return np.linalg.norm(radial, axis=1) - self.r, s


FINGERS = {'2': 'metacarpal1.R', '3': 'metacarpal2.R', '4': 'metacarpal3.R', '5': 'metacarpal4.R'}


def _skin_subset(hand, G, idx):
    V = hand.V0[idx]
    Vh = np.c_[V, np.ones(len(V))]
    out = V * hand.W_rest[idx, None]
    Wi = hand.W[idx]
    for j, b in enumerate(hand.bones):
        w = Wi[:, j]
        m = w > 0
        if m.any():
            out[m] += w[m, None] * (Vh[m] @ G[b].T)[:, :3]
    return out


def fit_fingers(hand, params, grip, squeeze, fingers='3425', neighbors=True, log=None):
    """Flexion des doigts (MCP, IPP, IPD, abduction MCP) pour envelopper le cylindre ; chaque doigt
    vient toucher son voisin déjà posé (doigts serrés, sans s'interpénétrer). Rend le coût total."""
    from scipy.optimize import minimize
    from scipy.spatial import cKDTree
    bidx = {b: i for i, b in enumerate(hand.bones)}
    bv = hand.bone_of_vertex()
    total = 0.0
    done = {}
    order = {'3': [], '4': ['3'], '2': ['3'], '5': ['4']}
    for f in fingers:
        bones = ['finger%s-%d.R' % (f, k) for k in (1, 2, 3)]
        ids = [bidx[b] for b in bones]
        wf = hand.W[:, ids].sum(1)
        idx = np.where(wf > 0.2)[0]
        wfi = wf[idx]
        allow = squeeze + (1.0 - np.clip((wfi - 0.2) / 0.6, 0, 1)) * 0.006   # la base du doigt s'écrase plus
        seg = [bv[idx] == i for i in ids]
        side = (wfi > 0.6) & (seg[0] | seg[1])
        trees = [done[n] for n in order.get(f, []) if n in done] if neighbors else []

        def cost(x):
            pr = dict(params)
            pr[bones[0]] = (x[0], x[3], 0.0)
            pr[bones[1]] = (x[1], 0.0, 0.0)
            pr[bones[2]] = (x[2], 0.0, 0.0)
            Pp = _skin_subset(hand, hand.pose(pr), idx)
            d, _ = grip.dist(Pp)
            pen = np.clip(-(d + allow), 0, None)
            c = 4e6 * np.sum(pen ** 2)
            for k, m in enumerate(seg):
                if m.any():
                    c += 3e4 * (d[m].min() + squeeze * 0.6) ** 2 * (1.0 if k < 2 else 0.5)
            for tr in trees:
                dd, _ = tr.query(Pp[side], k=1)
                # doigts serrés : l'écart au voisin ~0,6 mm, sans entrer dedans
                c += 2e4 * (dd.min() - 0.0006) ** 2 + 5e5 * np.sum(np.clip(0.0006 - dd, 0, None) ** 2)
            c += 0.01 * (x[2] - 0.7 * x[1]) ** 2 + 0.002 * x[3] ** 2
            return c

        best = None
        for x0 in ([40, 60, 40, 0], [65, 75, 50, 0], [25, 45, 30, 0]):
            res = minimize(cost, np.array(x0, float), method='Powell',
                           bounds=[(0, 95), (0, 110), (0, 85), (-20, 20)], options={'xtol': 0.1, 'ftol': 1e-7, 'maxfev': 2500})
            if best is None or res.fun < best.fun:
                best = res
        x = best.x
        params[bones[0]] = (x[0], x[3], 0.0)
        params[bones[1]] = (x[1], 0.0, 0.0)
        params[bones[2]] = (x[2], 0.0, 0.0)
        total += best.fun
        if neighbors:
            Pp = _skin_subset(hand, hand.pose(params), idx)
            done[f] = cKDTree(Pp[(wfi > 0.6)])
        if log:
            log('doigt %s : MCP %.0f°, IPP %.0f°, IPD %.0f°, abd %.0f° (coût %.3g)' % (f, x[0], x[1], x[2], x[3], best.fun))
    return total


def fit_grip(hand, r=0.019, tilt=18.0, squeeze=0.0012, cup=(0, 2, 5, 9), back=0.012, palm_squeeze=0.004, log=print):
    """Pose les doigts autour d'un cylindre de rayon r (m) posé en travers de la paume.
    tilt : angle (°) de l'axe vers le bout des doigts, côté pouce (prise de force oblique) ;
    squeeze : enfoncement toléré de la peau des doigts dans le corps de la lampe (m) ;
    palm_squeeze : celui de la paume (m). La place du cylindre (profondeur, avance) est cherchée sur une
    grille : la paume touche, les doigts l'enveloppent sans le traverser."""
    params0 = {}
    for f, c in zip('2345', cup):
        params0[FINGERS[f]] = (c, 0.0, 0.0)
    g = normalize(hand.lat * math.cos(math.radians(tilt)) + hand.fwd * math.sin(math.radians(tilt)))
    G = hand.pose(params0)
    P = hand.skin(G)
    bv = hand.bone_of_vertex()
    bidx = {b: i for i, b in enumerate(hand.bones)}
    m3 = hand.joint_pos(G, 'finger3-1.R')
    m4 = hand.joint_pos(G, 'finger4-1.R')
    perp = normalize(np.cross(g, hand.dorsal))
    if np.dot(perp, hand.fwd) < 0:
        perp = -perp
    palm = np.isin(bv, [bidx[b] for b in ['metacarpal1.R', 'metacarpal2.R', 'metacarpal3.R', 'metacarpal4.R', 'wrist.R']])
    thumbw = hand.W[:, [bidx['finger1-1.R'], bidx['finger1-2.R'], bidx['finger1-3.R']]].sum(1)
    palm &= thumbw < 0.1
    best = None
    for adv in np.linspace(-0.010, 0.010, 5):
        base = (m3 + m4) / 2 - hand.fwd * back + perp * adv
        rel = P - base
        band = palm & ((rel @ hand.dorsal) < 0) & (np.abs(rel @ perp) < 0.010)
        # profondeur : la paume touche (écrasée de palm_squeeze au plus)
        lo, hi = 0.0, 0.08
        for _ in range(30):
            mid = (lo + hi) / 2
            d, _ = Grip(base - hand.dorsal * mid, g, r).dist(P[band])
            if d.min() < -palm_squeeze:
                lo = mid
            else:
                hi = mid
        for extra in (0.0, -0.003, -0.006):
            grip = Grip(base - hand.dorsal * (hi + extra), g, r)
            pr = dict(params0)
            c = fit_fingers(hand, pr, grip, squeeze, neighbors=False)
            if log:
                log('  avance %+.0f mm, profondeur %.1f mm : coût %.3g' % (adv * 1000, (hi + extra) * 1000, c))
            if best is None or c < best[0]:
                best = (c, pr, grip)
    c, params, grip = best
    params = dict(params0)
    fit_fingers(hand, params, grip, squeeze, log=log)
    return params, grip


def grip_angle(hand, grip, P):
    """Angle (degrés) autour de l'axe de la lampe, compté depuis le côté proximal (vers le poignet,
    -perp) vers le dos de la main (+dorsal) : 0 = côté poignet, 90 = côté paume / dos."""
    perp = normalize(np.cross(grip.g, hand.dorsal))
    if perp @ hand.fwd < 0:
        perp = -perp
    rel = np.atleast_2d(P) - grip.c
    rel = rel - np.outer(rel @ grip.g, grip.g)
    return np.degrees(np.arctan2(rel @ hand.dorsal, rel @ (-perp)))


def fit_thumb(hand, params, grip, squeeze=0.0012, ang=45.0, nail_back=0.0, rest=0.0013, log=print):
    """Pouce allongé sur la lampe, pointé vers la tête, la pulpe posée sur l'interrupteur : rotation de la
    trapézo-métacarpienne (3 angles), flexion MCP et IP. ang : place de la pulpe autour de l'axe (voir
    grip_angle ; vers le dos de la main, pour que l'ongle se voie depuis l'œil) ; nail_back : l'ongle
    penché vers l'arrière de la lampe (degrés : la dernière phalange un peu relevée, comme quand on
    appuie de la pulpe) ; rest : hauteur de la pulpe au-dessus du corps (le capuchon de l'interrupteur).
    Rend la position de la pulpe (contact)."""
    from scipy.optimize import minimize
    from scipy.spatial import cKDTree
    bidx = {b: i for i, b in enumerate(hand.bones)}
    bv = hand.bone_of_vertex()
    bones = ['finger1-1.R', 'finger1-2.R', 'finger1-3.R']
    ids = [bidx[b] for b in bones]
    wf = hand.W[:, ids].sum(1)
    idx = np.where(wf > 0.15)[0]
    wfi = wf[idx]
    allow = squeeze + (1.0 - np.clip((wfi - 0.15) / 0.6, 0, 1)) * 0.005
    seg = [bv[idx] == i for i in ids]
    # le reste de la main (déjà posé : index, paume) : le pouce ne doit pas y entrer
    G0 = hand.pose(params)
    other = np.where(hand.W[:, ids].sum(1) < 0.05)[0]
    Po = _skin_subset(hand, G0, other)
    near = np.linalg.norm(Po - grip.c, axis=1) < 0.09
    tree = cKDTree(Po[near])
    cos_aim = math.cos(math.radians(12.0))
    sin_back = math.sin(math.radians(nail_back))
    a_t = math.radians(ang)

    def build(x):
        pr = dict(params)
        pr[bones[0]] = (x[0], x[1], x[2])
        pr[bones[1]] = (x[3], 0.0, 0.0)
        pr[bones[2]] = (x[4], 0.0, 0.0)
        return pr

    def parts(x):
        pr = build(x)
        G = hand.pose(pr)
        Pp = _skin_subset(hand, G, idx)
        return G, Pp

    def cost(x):
        G, Pp = parts(x)
        d, s = grip.dist(Pp)
        pen = np.clip(-(d + allow), 0, None)
        c = 4e6 * np.sum(pen ** 2)
        # la pulpe repose sur le capuchon (rest au-dessus du corps), la phalange proximale près du corps
        m2 = seg[2]
        k = np.argmin(d[m2])
        c += 3e4 * (d[m2][k] - rest) ** 2
        c += 3e4 * max(0.0, d[seg[1]].min() - 0.0025) ** 2
        # pas de pénétration du capuchon : rien du pouce sous « rest » près de la pulpe
        # place de la pulpe autour de l'axe
        pa = math.radians(float(grip_angle(hand, grip, Pp[m2][k])[0]))
        c += 6.0 * (math.atan2(math.sin(pa - a_t), math.cos(pa - a_t))) ** 2
        # la dernière phalange suit la lampe, vers la tête ; l'ongle penché vers l'arrière
        h3 = hand.joint_pos(G, bones[2])
        t3 = hand.joint_pos(G, bones[2], 'tail')
        dirn = normalize(t3 - h3)
        c += 200.0 * max(0.0, cos_aim - float(dirn @ grip.g)) ** 2
        # l'ongle regarde vers l'extérieur de la lampe (pas de profil), penché de nail_back vers l'arrière
        nail = (G[bones[2]][:3, :3] @ hand.frame[bones[2]])[:, 2]
        rad = Pp[m2][k] - grip.c
        rad = normalize(rad - grip.g * (rad @ grip.g))
        want = normalize(rad * math.cos(math.radians(nail_back)) - grip.g * sin_back)
        c += 40.0 * (1.0 - float(nail @ want)) ** 2
        # pas d'entrée dans la main (index, paume)
        dd, _ = tree.query(Pp[wfi > 0.5], k=1)
        c += 2e5 * np.sum(np.clip(0.003 - dd, 0, None) ** 2)
        c += 0.0004 * (x[0] ** 2 + x[1] ** 2 + x[2] ** 2) + 0.002 * (x[4] - 10) ** 2 + 0.001 * (x[3] - 5) ** 2
        return c

    best = None
    for x0 in ([0, 0, 0, 10, 0], [20, -20, 0, 10, 0], [-20, 20, 0, 10, 0], [20, 20, 20, 15, 5],
               [0, -30, -20, 5, -5], [-25, -10, 15, 5, 0], [10, 30, -15, 0, -10]):
        res = minimize(cost, np.array(x0, float), method='Powell',
                       bounds=[(-60, 60), (-60, 60), (-75, 50), (-15, 60), (-15, 60)],
                       options={'xtol': 0.1, 'ftol': 1e-8, 'maxfev': 5000})
        if best is None or res.fun < best.fun:
            best = res
    x = best.x
    params.update(build(x))
    G, Pp = parts(x)
    d, s = grip.dist(Pp)
    m = seg[2]
    k = np.argmin(d[m])
    pad = Pp[m][k]
    nail = (G[bones[2]][:3, :3] @ hand.frame[bones[2]])[:, 2]
    rad = pad - grip.c
    rad = normalize(rad - grip.g * (rad @ grip.g))
    log('pouce : CMC %.0f° %.0f° %.0f°, MCP %.0f°, IP %.0f° ; pulpe à %.0f° (voulu %.0f°), %.1f mm du corps ; '
        'ongle · axe %.2f, · rayon %.2f (coût %.3g)' % (x[0], x[1], x[2], x[3], x[4], float(grip_angle(hand, grip, pad)[0]),
                                                      ang, d[m][k] * 1000, float(nail @ grip.g), float(nail @ rad), best.fun))
    return pad

# ----------------------------------------------------------------------------- géométrie

def catmull_clark(V, F, FT=None, VT=None):
    """Une subdivision Catmull-Clark d'un maillage de quads (bords : règle des courbes B-splines).
    Les UV (par coin de face) sont subdivisées linéairement, coutures gardées. Rend V2, F2, FT2, VT2."""
    V = np.asarray(V, float)
    F = np.asarray(F, int)
    nv, nf = len(V), len(F)
    fp = V[F].mean(1)
    # arêtes
    e = np.stack([F, np.roll(F, -1, 1)], 2).reshape(-1, 2)      # (nf*4, 2) : arête k de la face i
    ekey = np.sort(e, 1)
    uniq, einv = np.unique(ekey, axis=0, return_inverse=True)
    einv = einv.ravel()
    ne = len(uniq)
    efaces = np.zeros(ne, int)
    np.add.at(efaces, einv, 1)
    fsum = np.zeros((ne, 3))
    np.add.at(fsum, einv, np.repeat(fp, 4, 0))
    mid = V[uniq].mean(1)
    boundary = efaces == 1
    ep = mid.copy()
    inter = ~boundary
    ep[inter] = (V[uniq[inter, 0]] + V[uniq[inter, 1]] + fsum[inter]) / (2 + efaces[inter])[:, None]
    # sommets
    val = np.zeros(nv)
    np.add.at(val, uniq.ravel(), 1)
    Fs = np.zeros((nv, 3))
    fcount = np.zeros(nv)
    np.add.at(Fs, F.ravel(), np.repeat(fp, 4, 0))
    np.add.at(fcount, F.ravel(), 1)
    Rs = np.zeros((nv, 3))
    np.add.at(Rs, uniq[:, 0], mid)
    np.add.at(Rs, uniq[:, 1], mid)
    n = val
    Fa = Fs / np.maximum(fcount, 1)[:, None]
    Ra = Rs / np.maximum(n, 1)[:, None]
    vp = (Fa + 2 * Ra + (n - 3)[:, None] * V) / np.maximum(n, 1)[:, None]
    # sommets de bord : 3/4 P + 1/8 des deux voisins de bord
    bv = np.zeros(nv, bool)
    bv[uniq[boundary].ravel()] = True
    if bv.any():
        nb = np.zeros((nv, 3))
        cnt = np.zeros(nv)
        be = uniq[boundary]
        np.add.at(nb, be[:, 0], V[be[:, 1]])
        np.add.at(nb, be[:, 1], V[be[:, 0]])
        np.add.at(cnt, be.ravel(), 1)
        ok = bv & (cnt == 2)
        vp[ok] = 0.75 * V[ok] + 0.125 * nb[ok]
        vp[bv & (cnt != 2)] = V[bv & (cnt != 2)]
    V2 = np.concatenate([vp, ep, fp])
    E = einv.reshape(nf, 4)          # E[i,k] : arête entre coin k et coin k+1
    a = F
    eo = nv + E
    fo = nv + ne + np.arange(nf)
    F2 = []
    for k in range(4):
        F2.append(np.stack([a[:, k], eo[:, k], fo, eo[:, (k - 1) % 4]], 1))
    F2 = np.concatenate(F2)
    if FT is None:
        return V2, F2, None, None
    FT = np.asarray(FT, int)
    VT = np.asarray(VT, float)
    nt = len(VT)
    te = np.stack([FT, np.roll(FT, -1, 1)], 2).reshape(-1, 2)
    tkey = np.sort(te, 1)
    tuniq, tinv = np.unique(tkey, axis=0, return_inverse=True)
    tinv = tinv.ravel().reshape(nf, 4)
    tmid = VT[tuniq].mean(1)
    tcen = VT[FT].mean(1)
    VT2 = np.concatenate([VT, tmid, tcen])
    to = nt + tinv
    tf = nt + len(tuniq) + np.arange(nf)
    FT2 = []
    for k in range(4):
        FT2.append(np.stack([FT[:, k], to[:, k], tf, to[:, (k - 1) % 4]], 1))
    FT2 = np.concatenate(FT2)
    return V2, F2, FT2, VT2


def vertex_normals(V, F):
    T = tris(F)
    fn = np.cross(V[T[:, 1]] - V[T[:, 0]], V[T[:, 2]] - V[T[:, 0]])
    N = np.zeros_like(V)
    for k in range(3):
        np.add.at(N, T[:, k], fn)
    return N / np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)


def tris(F):
    F = np.asarray(F)
    if F.shape[1] == 4:
        return np.concatenate([F[:, [0, 1, 2]], F[:, [0, 2, 3]]])
    return F


def laplacian_smooth(V, F, mask, it=2, lam=0.5):
    """Lissage de Laplace limité aux sommets de « mask » (zones écrasées par le skinning linéaire)."""
    e = np.stack([F, np.roll(F, -1, 1)], 2).reshape(-1, 2)
    e = np.unique(np.sort(e, 1), axis=0)
    V = V.copy()
    for _ in range(it):
        s = np.zeros_like(V)
        c = np.zeros(len(V))
        np.add.at(s, e[:, 0], V[e[:, 1]])
        np.add.at(s, e[:, 1], V[e[:, 0]])
        np.add.at(c, e.ravel(), 1)
        avg = s / np.maximum(c, 1)[:, None]
        V[mask] += lam * (avg[mask] - V[mask])
    return V

# ----------------------------------------------------------------------------- la lampe de poche

class Surf:
    """Une surface de maillage : sommets, normales, UV, triangles (et couleurs de sommet en option)."""

    def __init__(self, name, V, N, UV, T, C=None):
        self.name, self.V, self.N, self.UV, self.T, self.C = name, V, N, UV, np.asarray(T, np.int64), C

    def transformed(self, R, t=np.zeros(3)):
        return Surf(self.name, self.V @ R.T + t, self.N @ R.T, self.UV, self.T, self.C)


def lathe(profile, seg=64, name='tour', u0=0.0, smooth_angle=35.0, v_of=None):
    """Surface de révolution autour de l'axe Z. profile : liste de (z, r) dans l'ordre ; les sommets du
    profil où l'angle dépasse smooth_angle sont dédoublés (arêtes vives). UV : u = angle / 2π,
    v = v_of(z) (par défaut l'abscisse curviligne normalisée)."""
    P = np.array(profile, float)
    # arêtes vives : on duplique le point
    d = np.diff(P, axis=0)
    t = d / np.maximum(np.linalg.norm(d, axis=1, keepdims=True), 1e-12)
    pts, tans = [], []
    for i in range(len(P)):
        tin = t[i - 1] if i > 0 else t[0]
        tout = t[i] if i < len(t) else t[-1]
        ang = math.degrees(math.acos(np.clip(np.dot(tin, tout), -1, 1)))
        if 0 < i < len(P) - 1 and ang > smooth_angle:
            pts += [P[i], P[i]]
            tans += [tin, tout]
        else:
            tt = tin + tout
            tans.append(tt / max(np.linalg.norm(tt), 1e-12))
            pts.append(P[i])
    pts = np.array(pts)
    tans = np.array(tans)
    # normale du profil (dans le plan r, z) : perpendiculaire à la tangente, vers l'extérieur
    n2 = np.stack([tans[:, 1] * 0 + tans[:, 0], -tans[:, 1]], 1)   # (dz, -dr) → (nr, nz) tourné
    # tangente (dz, dr) ; normale = (nr, nz) = (dz, -dr) normalisée selon le sens de parcours
    nr = tans[:, 0]
    nz = -tans[:, 1]
    L = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    vv = L / max(L[-1], 1e-9) if v_of is None else np.array([v_of(z) for z in pts[:, 0]])
    ang = np.linspace(0, 2 * np.pi, seg + 1)
    ca, sa = np.cos(ang), np.sin(ang)
    V, N, UV = [], [], []
    for i, (z, r) in enumerate(pts):
        V.append(np.c_[r * ca, r * sa, np.full(seg + 1, z)])
        N.append(np.c_[nr[i] * ca, nr[i] * sa, np.full(seg + 1, nz[i])])
        UV.append(np.c_[u0 + ang / (2 * np.pi), np.full(seg + 1, vv[i])])
    V = np.concatenate(V)
    N = np.concatenate(N)
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)
    UV = np.concatenate(UV)
    T = []
    w = seg + 1
    for i in range(len(pts) - 1):
        if np.allclose(pts[i], pts[i + 1]):
            continue
        for j in range(seg):
            a, b, c, e = i * w + j, i * w + j + 1, (i + 1) * w + j + 1, (i + 1) * w + j
            T += [[a, b, c], [a, c, e]]
    T = np.array(T)
    # orientation : les normales géométriques doivent suivre les normales du profil
    fn = np.cross(V[T[:, 1]] - V[T[:, 0]], V[T[:, 2]] - V[T[:, 0]])
    if np.sum(fn * N[T[:, 0]]) < 0:
        T = T[:, ::-1]
    return Surf(name, V, N, UV, T)


def lamp_profile(L, head_len=0.068):
    """Profil extérieur de la lampe (z vers l'arrière : 0 = face avant, L = culot), en mètres.
    Lampe de poche en aluminium noir des années 90, 2 piles C : corps de 38 mm, tête évasée de 55 mm."""
    R_body = 0.019
    p = [
        (0.0000, 0.0236),            # bord intérieur de la bague (contre le verre)
        (0.0004, 0.0258),
        (0.0012, 0.0270),            # chanfrein avant
        (0.0030, 0.0276),
        (0.0180, 0.0276),            # bague (bezel)
        (0.0190, 0.0268),
        (0.0200, 0.0262),            # rainure bague / tête
        (0.0215, 0.0266),
        (0.0300, 0.0266),
        (0.0340, 0.0262),
        (0.0420, 0.0246),            # évasement de la tête
        (0.0500, 0.0222),
        (0.0570, 0.0205),
        (0.0630, 0.0198),
        (head_len, 0.0196),
        (head_len + 0.0008, 0.0191),  # jonction tête / corps
        (head_len + 0.0030, 0.0191),
        (head_len + 0.0040, R_body),
        (L - 0.034, R_body),
        (L - 0.0335, 0.0184),        # rainure du culot
        (L - 0.0320, 0.0184),
        (L - 0.0310, 0.0198),
        (L - 0.0060, 0.0198),
    ]
    # culot arrondi (congé de 5 mm), puis un bouchon à peine bombé : pas d'arête vive ni d'anneau, une
    # silhouette douce que le chanfrein d'usure (alu mis à nu) dessine en clair
    rf = 0.0050
    zc, rc = L - rf - 0.0010, 0.0198 - rf
    for k in range(1, 9):
        a = (math.pi / 2) * k / 8
        p.append((zc + rf * math.sin(a), rc + rf * math.cos(a)))
    for k in range(1, 7):
        rr = rc * (1 - k / 6)
        p.append((zc + rf + 0.0012 * (1 - (rr / rc) ** 2), rr))
    return p


def build_lamp(L, seg=72):
    """Rend les surfaces de la lampe (repère de la lampe : axe Z, face avant en z=0, culot en z=+L ;
    le faisceau part vers -Z)."""
    prof = lamp_profile(L)
    body = lathe(prof, seg, 'lampe_corps', v_of=lambda z: z / (L + 0.003))
    # réflecteur parabolique (face intérieure, tournée vers l'avant) : du bord du verre au culot de l'ampoule
    rp = []
    f = 0.0062                       # distance focale : l'ampoule au foyer
    r0, r1 = 0.0234, 0.0045
    for k in range(13):
        r = r0 + (r1 - r0) * k / 12
        z = 0.0016 + (r0 ** 2 - r ** 2) / (4 * f) * 0.55
        rp.append((z, r))
    rp.append((rp[-1][0] + 0.0004, 0.0))
    refl = lathe(rp, seg, 'lampe_reflecteur')
    refl.N = -refl.N
    refl.T = refl.T[:, ::-1]
    # le verre (disque), un peu en retrait de la bague
    zg = 0.0013
    ang = np.linspace(0, 2 * np.pi, seg + 1)
    rg = 0.0240
    GV = np.r_[[[0, 0, zg]], np.c_[rg * np.cos(ang), rg * np.sin(ang), np.full(seg + 1, zg)]]
    GN = np.tile([0, 0, -1.0], (len(GV), 1))
    GUV = np.c_[0.5 + GV[:, 0] / (2 * rg), 0.5 + GV[:, 1] / (2 * rg)]
    GT = np.array([[0, i + 1, i + 2] for i in range(seg)])
    fn = np.cross(GV[GT[:, 1]] - GV[GT[:, 0]], GV[GT[:, 2]] - GV[GT[:, 0]])
    if np.sum(fn[:, 2]) > 0:
        GT = GT[:, ::-1]
    glass = Surf('lampe_verre', GV, GN, GUV, GT)
    # l'ampoule : enveloppe de verre au foyer (ampoule krypton), filament émissif
    zf = rp[-1][0] - f * 0.55 - 0.0005
    bp = []
    for k in range(13):
        a = math.pi * k / 12
        bp.append((zf - 0.0042 * math.cos(a) * 0.9 + 0.0004, 0.0001 + 0.0029 * math.sin(a)))
    bulb = lathe(bp, 24, 'lampe_ampoule')
    return {'corps': body, 'reflecteur': refl, 'verre': glass, 'ampoule': bulb}, prof

# ----------------------------------------------------------------------------- la manche

def build_sleeve(center, axis, e1, e2, rx, ry, length=0.42, cuff=0.055, seed=3, ribs=64):
    """Manche de sweat : tube lofté autour de l'avant-bras. center : bord du poignet (début du bord-côte),
    axis : vers le coude, (e1, e2) : axes de la section de l'avant-bras (demi-axes rx, ry au bord).
    Bord-côte serré et côtelé (ribs côtes), ourlet roulé (épaisseur visible), puis le corps de la manche,
    plus ample, froncé au-dessus du bord-côte (plis). Couleur de sommet : occlusion des plis."""
    rng = np.random.default_rng(seed)
    nseg = 64
    th = np.linspace(0, 2 * np.pi, nseg + 1)
    # chemin du profil : (avance le long de l'axe, rayon ajouté, côté intérieur ?)
    path = []
    # face intérieure (on voit dans la manche) : du fond vers le bord
    for k in range(6):
        path.append((0.022 - 0.022 * k / 5, 0.0018, True))
    # ourlet roulé
    for k in range(1, 8):
        a = math.pi * k / 8
        path.append((-0.0028 * math.sin(a), 0.0018 + 0.0042 * (1 - math.cos(a)) / 2, False))
    # bord-côte puis corps
    n_cuff = 18
    for k in range(n_cuff + 1):
        t = cuff * k / n_cuff
        path.append((t, 0.006 + 0.0012 * math.sin(math.pi * k / n_cuff), False))
    n_body = 46
    for k in range(1, n_body + 1):
        t = cuff + (length - cuff) * (k / n_body) ** 1.35
        u = (t - cuff) / 0.12
        add = 0.006 + 0.016 * (1 - math.exp(-u * 2.2))
        path.append((t, add, False))
    # plis du corps (fronces) : bourrelets en anneaux irréguliers, plus forts près du bord-côte
    phases = rng.uniform(0, 2 * np.pi, 8)
    V, N_, UV, C, ring_t = [], [], [], [], []
    for i, (t, add, inner) in enumerate(path):
        c = center + axis * t
        rr_x = rx + add
        rr_y = ry + add
        disp = np.zeros_like(th)
        if t > cuff and not inner:
            w = math.exp(-(t - cuff) / 0.10) * 0.9 + 0.25
            bunch = 0.0
            for j in range(4):
                fr = (2.2 + j * 1.3) / 0.05
                bunch += math.sin(t * fr + phases[j]) * (0.5 / (j + 1))
            ang_mod = 0.6 + 0.4 * np.sin(th * 2 + phases[4] + t * 30) + 0.25 * np.sin(th * 3 + phases[5] - t * 20)
            disp = 0.0034 * w * bunch * ang_mod
            disp += 0.0012 * np.sin(th * 5 + phases[6] + t * 60) * w
            # raccord doux avec le bord-côte
            disp *= min(1.0, (t - cuff) / 0.012)
        elif not inner and t >= 0:
            disp = 0.00045 * np.cos(th * ribs)        # côtes du bord-côte
        x = np.cos(th) * (rr_x + disp)
        y = np.sin(th) * (rr_y + disp)
        P = c + np.outer(x, e1) + np.outer(y, e2)
        V.append(P)
        circ = 2 * np.pi * math.sqrt((rr_x ** 2 + rr_y ** 2) / 2)
        UV.append(np.c_[th / (2 * np.pi) * circ, np.full(nseg + 1, t)])
        occ = np.ones(nseg + 1)
        if t > cuff and not inner:
            occ = 1.0 - np.clip(-disp / 0.0034, 0, 1) * 0.45
        if inner:
            occ = np.full(nseg + 1, 0.25 + 0.75 * (1 - t / 0.022) ** 2 * 0.6)
        C.append(occ)
        ring_t.append(t)
    V = np.concatenate(V)
    UV = np.concatenate(UV)
    C = np.concatenate(C)
    w = nseg + 1
    T = []
    for i in range(len(path) - 1):
        for j in range(nseg):
            a, b, c2, e = i * w + j, i * w + j + 1, (i + 1) * w + j + 1, (i + 1) * w + j
            T += [[a, c2, b], [a, e, c2]]
    T = np.array(T)
    # couture du tube : les sommets en th=0 et th=2π coïncident (UV différentes) ; normales communes
    N = np.zeros_like(V)
    fn = np.cross(V[T[:, 1]] - V[T[:, 0]], V[T[:, 2]] - V[T[:, 0]])
    for k in range(3):
        np.add.at(N, T[:, k], fn)
    Nr = N.reshape(len(path), w, 3)
    s = Nr[:, 0] + Nr[:, -1]
    Nr[:, 0] = s
    Nr[:, -1] = s
    N = Nr.reshape(-1, 3)
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)
    # normales vers l'extérieur sur la face extérieure
    out = (V - center) - np.outer((V - center) @ axis, axis)
    if np.sum(np.sum(N * out, 1)) < 0:
        N = -N
        T = T[:, ::-1]
    Cc = np.c_[C, C, C, np.ones_like(C)]
    return Surf('manche', V, N, UV, T, Cc)

# ----------------------------------------------------------------------------- le bracelet (Aurèlia)

def build_bracelet(V, center, axis, e1, e2, along0=0.0025, width=0.0068, thick=0.0024, slack=0.0009, nseg=192, ntube=16):
    """Bracelet brésilien (fils noués à chevrons) autour du poignet, juste avant le bord-côte de la manche.
    V : peau posée (repère de la vue) ; center : centre de la section du poignet ; axis : vers le coude ;
    along0 : position du bracelet le long de l'axe (m, < 0 = vers le coude). Le bracelet suit l'enveloppe
    convexe de la section du poignet (un fil tendu ne suit pas les creux), un peu lâche (slack)."""
    from scipy.spatial import ConvexHull
    rel = V - center
    a = rel @ (-axis)                     # > 0 vers la main
    m = np.abs(a - along0) < 0.0045
    Q2 = np.c_[rel[m] @ e1, rel[m] @ e2]
    hull = ConvexHull(Q2)
    H = Q2[hull.vertices]
    # (ordre trigonométrique) contour décalé vers l'extérieur de slack + thick / 2, rééchantillonné
    ang = np.arctan2(H[:, 1], H[:, 0])
    H = H[np.argsort(ang)]
    Hc = np.r_[H, H[:1]]
    seg = np.linalg.norm(np.diff(Hc, axis=0), axis=1)
    sL = np.r_[0, np.cumsum(seg)]
    t = np.linspace(0, sL[-1], nseg, endpoint=False)
    C = np.c_[np.interp(t, sL, Hc[:, 0]), np.interp(t, sL, Hc[:, 1])]
    # lissage circulaire (les coins de l'enveloppe), puis normale extérieure
    for _ in range(6):
        C = 0.5 * C + 0.25 * (np.roll(C, 1, 0) + np.roll(C, -1, 0))
    T2 = np.roll(C, -1, 0) - np.roll(C, 1, 0)
    N2 = np.c_[T2[:, 1], -T2[:, 0]]
    N2 /= np.linalg.norm(N2, axis=1, keepdims=True)
    if np.sum(N2 * C) < 0:
        N2 = -N2
    C = C + N2 * (slack + thick / 2)
    seg = np.linalg.norm(np.roll(C, -1, 0) - C, axis=1)
    L = seg.sum()
    u = np.r_[0, np.cumsum(seg)[:-1]] / L
    base = center - axis * along0
    P3 = base + np.outer(C[:, 0], e1) + np.outer(C[:, 1], e2)
    N3 = np.outer(N2[:, 0], e1) + np.outer(N2[:, 1], e2)
    phi = np.linspace(-np.pi, np.pi, ntube + 1)          # 0 = face extérieure
    Vb, Nb, UVb = [], [], []
    for i in range(nseg + 1):
        k = i % nseg
        uu = u[k] if i < nseg else 1.0
        for f in phi:
            Vb.append(P3[k] + N3[k] * (thick / 2) * math.cos(f) + (-axis) * (width / 2) * math.sin(f))
            n = N3[k] * math.cos(f) / (thick / 2) + (-axis) * math.sin(f) / (width / 2)
            Nb.append(n / np.linalg.norm(n))
            UVb.append([uu, f / (2 * np.pi) + 0.5])
    Vb, Nb, UVb = np.array(Vb), np.array(Nb), np.array(UVb)
    w = ntube + 1
    T = []
    for i in range(nseg):
        for j in range(ntube):
            q = [i * w + j, i * w + j + 1, (i + 1) * w + j + 1, (i + 1) * w + j]
            T += [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]
    T = np.array(T)
    fn = np.cross(Vb[T[:, 1]] - Vb[T[:, 0]], Vb[T[:, 2]] - Vb[T[:, 0]])
    if np.sum(fn * Nb[T[:, 0]]) < 0:
        T = T[:, ::-1]
    return Surf('bracelet', Vb, Nb, UVb, T), L


def bake_bracelet(name, out_dir, length, res=(1024, 64), log=print):
    """Bracelet brésilien : chevrons de fils de coton (rouge, jaune, turquoise, blanc, violet), nœuds en
    losange (relief), un peu passé et pelucheux."""
    from PIL import Image
    W, H = res
    u = (np.arange(W) + 0.5) / W
    v = (np.arange(H) + 0.5) / H
    U, Vv = np.meshgrid(u, v)
    phi = (Vv - 0.5) * 2 * np.pi
    w = np.sin(phi)                                   # en travers de la face extérieure (-1 … 1)
    um = U * length / 0.0016                          # en nœuds (1,6 mm)
    cols = np.array([srgb(c) for c in [(176, 34, 44), (222, 172, 52), (40, 140, 140), (226, 220, 204), (104, 52, 112), (40, 140, 140), (222, 172, 52)]])
    s_ = um / 2.0 + np.abs(w) * 2.2
    idx = np.floor(s_).astype(int) % len(cols)
    alb = cols[idx]
    # nœuds en losange : un relief par nœud, des creux entre les rangs
    ka = np.abs(np.sin(np.pi * (um + w * 2.2)))
    kb = np.abs(np.sin(np.pi * (um - w * 2.2)))
    hgt = np.sqrt(ka * kb)
    nz = Noise3(41)
    fz = nz.fbm(np.dstack([U * 200, Vv * 12, np.zeros_like(U)]), 3)
    alb = alb * (0.78 + 0.22 * hgt[..., None]) * (1.0 + fz[..., None] * 0.12)
    alb = alb * 0.92 + 0.08 * alb.mean(2, keepdims=True)         # (couleurs un peu passées)
    gy, gx = np.gradient(hgt * 0.00035)
    gx /= length / W
    gy /= (0.0068 * np.pi / 2) / H
    nrm = np.dstack([-gx, gy, np.ones_like(gx)])
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    os.makedirs(out_dir, exist_ok=True)
    pa = os.path.join(out_dir, 'bracelet_%s_albedo.jpg' % name)
    pn = os.path.join(out_dir, 'bracelet_%s_normal.png' % name)
    save_rgb(pa, np.clip(alb, 0, 1))
    save_rgb(pn, nrm * 0.5 + 0.5)
    write_import(pa)
    write_import(pn, normal=True)
    log('  bracelet %s : textures écrites' % name)

# ----------------------------------------------------------------------------- export glTF (.glb)

def write_glb(path, nodes, extras=None):
    """nodes : liste de (nom, [Surf…] ou None, translation) ; chaque Surf devient une primitive (une
    surface dans Godot, dans l'ordre). Matières : un nom par surface (Godot les remplace)."""
    bin_parts = []
    accessors, views, meshes, gnodes, materials = [], [], [], [], []
    mat_index = {}

    def add_view(arr, target=None):
        b = arr.tobytes()
        off = sum(len(x) for x in bin_parts)
        pad = (-len(b)) % 4
        bin_parts.append(b + b'\0' * pad)
        v = {'buffer': 0, 'byteOffset': off, 'byteLength': len(b)}
        if target:
            v['target'] = target
        views.append(v)
        return len(views) - 1

    def add_acc(arr, typ, ctype, target=None, minmax=False):
        vi = add_view(arr, target)
        a = {'bufferView': vi, 'componentType': ctype, 'count': int(arr.shape[0]), 'type': typ}
        if minmax:
            a['min'] = [float(x) for x in arr.min(0)]
            a['max'] = [float(x) for x in arr.max(0)]
        accessors.append(a)
        return len(accessors) - 1

    for name, surfs, tr in nodes:
        node = {'name': name}
        if tr is not None:
            node['translation'] = [float(x) for x in tr]
        if surfs:
            prims = []
            for s in surfs:
                if s.name not in mat_index:
                    mat_index[s.name] = len(materials)
                    materials.append({'name': s.name, 'pbrMetallicRoughness': {'baseColorFactor': [0.8, 0.8, 0.8, 1], 'metallicFactor': 0.0, 'roughnessFactor': 0.5}})
                attrs = {
                    'POSITION': add_acc(s.V.astype(np.float32), 'VEC3', 5126, 34962, True),
                    'NORMAL': add_acc(s.N.astype(np.float32), 'VEC3', 5126, 34962),
                    'TEXCOORD_0': add_acc(s.UV.astype(np.float32), 'VEC2', 5126, 34962),
                }
                if s.C is not None:
                    attrs['COLOR_0'] = add_acc(np.asarray(s.C, np.float32), 'VEC4', 5126, 34962)
                idx = add_acc(s.T.astype(np.uint32).reshape(-1), 'SCALAR', 5125, 34963)
                prims.append({'attributes': attrs, 'indices': idx, 'material': mat_index[s.name]})
            meshes.append({'name': name, 'primitives': prims})
            node['mesh'] = len(meshes) - 1
        gnodes.append(node)
    blob = b''.join(bin_parts)
    gl = {'asset': {'version': '2.0', 'generator': 'make_hands.py (Don\'t Play)'},
          'scene': 0, 'scenes': [{'nodes': list(range(len(gnodes)))}], 'nodes': gnodes,
          'meshes': meshes, 'materials': materials, 'accessors': accessors, 'bufferViews': views,
          'buffers': [{'byteLength': len(blob)}]}
    if extras:
        gl['asset']['extras'] = extras
    js = json.dumps(gl, separators=(',', ':')).encode()
    js += b' ' * ((-len(js)) % 4)
    total = 12 + 8 + len(js) + 8 + len(blob)
    with open(path, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, total))
        f.write(struct.pack('<II', len(js), 0x4E4F534A))
        f.write(js)
        f.write(struct.pack('<II', len(blob), 0x004E4942))
        f.write(blob)

# ----------------------------------------------------------------------------- assemblage

def sculpt_fist(h, G, tf, V, F, params):
    """Ce que le skinning linéaire ne donne pas : les têtes des métacarpiens qui saillent sur le dos du
    poing fermé (selon la flexion MCP) et les tendons extenseurs tendus du poignet aux jointures. Petit
    déplacement le long des normales (mètres), sur la main posée et subdivisée."""
    N = vertex_normals(V, F)
    dorsal = tf(h.dorsal) - tf(np.zeros(3))
    G0 = G['wrist.R']
    dors_p = normalize((G0[:3, :3] @ h.dorsal))
    dors_l = normalize(tf(dors_p) - tf(np.zeros(3)))
    wrist = tf(h.joint_pos(G, 'wrist.R'))
    disp = np.zeros(len(V))
    for f in '2345':
        b = 'finger%s-1.R' % f
        flex = params.get(b, (0, 0, 0))[0]
        k = np.clip(flex / 50.0, 0.0, 1.3)
        J = tf(h.joint_pos(G, b))
        # tête du métacarpien : un peu en arrière de l'articulation, côté dos
        mc = h.parent[b] if h.parent[b] in h.head else None
        back = normalize(tf(h.joint_pos(G, mc)) - J) if mc else -dors_l
        C = J + back * 0.006 + dors_l * 0.004
        d = np.linalg.norm(V - C, axis=1)
        side = np.clip((V - J) @ dors_l / 0.008 + 0.5, 0, 1)
        disp += 0.0019 * k * np.exp(-(d / 0.0075) ** 2) * side
        # tendon extenseur : du milieu du poignet (côté dos) vers la jointure
        A = wrist + dors_l * 0.012
        B = J + back * 0.012 + dors_l * 0.003
        ab = B - A
        t = np.clip(((V - A) @ ab) / (ab @ ab), 0, 1)
        q = A + np.outer(t, ab)
        dd = np.linalg.norm(V - q, axis=1)
        env = np.sin(np.pi * np.clip((t - 0.25) / 0.75, 0, 1)) * (t > 0.25)
        up = ((V - q) @ dors_l) > -0.004
        disp += 0.0008 * np.exp(-(dd / 0.0030) ** 2) * env * up * (0.6 + 0.4 * k)
    return V + N * disp[:, None]


LAMP_L = 0.235
## Saillie du culot derrière le tranchant de la main (m).
TAIL_OUT = 0.0025


def switch_boot(ax_pos, ang, lampR, z_front, w=0.015, h=0.0095, height=0.0022, seg=20):
    """Bouton de l'interrupteur (capuchon de caoutchouc) posé sur le corps : dôme sur un rectangle
    arrondi. ax_pos : position le long de l'axe (repère lampe, z), ang : angle autour de l'axe."""
    us = np.linspace(-1, 1, seg + 1)
    U, Vv = np.meshgrid(us, us)
    # rectangle arrondi (superellipse) → dôme
    rr = (np.abs(U) ** 4 + np.abs(Vv) ** 4) ** 0.25
    hgt = height * np.clip(1 - rr ** 3, 0, 1) ** 0.5
    z = ax_pos + U * w / 2
    a = ang + Vv * (h / 2) / lampR
    r = lampR + hgt - 0.0002
    P = np.stack([r * np.cos(a), r * np.sin(a), z], -1).reshape(-1, 3)
    UV = np.stack([(U + 1) / 2, (Vv + 1) / 2], -1).reshape(-1, 2)
    T = []
    n = seg + 1
    for i in range(seg):
        for j in range(seg):
            q = [i * n + j, i * n + j + 1, (i + 1) * n + j + 1, (i + 1) * n + j]
            T += [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]
    T = np.array(T)
    N = vertex_normals(P, T)
    outw = np.c_[np.cos(a).ravel(), np.sin(a).ravel(), np.zeros(n * n)]
    if np.sum(N * outw) < 0:
        N = -N
        T = T[:, ::-1]
    return Surf('lampe_bouton', P, N, UV, T)


def assemble(mh, name, wrist=(-10.0, -32.0, 0.0), fit=None, log=print, **_):
    """Main posée + lampe + manche, dans le repère de la vue : origine au centre de la prise (sur l'axe
    de la lampe), -Z = avant (faisceau), +Y = le dos de la main (perpendiculaire à l'axe). La
    présentation à l'écran (tangage, lacet, roulis) est celle de viewmodel.gd (REST_ROT)."""
    var = VARIANTES[name]
    V = mh.morphed(morph_list(var))
    h = Hand(mh, V)
    h.to_metric(var['longueur'])
    if fit is None:
        params, grip = fit_grip(h, tilt=GRIP_TILT, log=log)
        pad = fit_thumb(h, params, grip, ang=THUMB_ANG, nail_back=THUMB_BACK, log=log)
    else:
        params, grip, pad = fit
    fitted = (dict(params), grip, pad)
    params = dict(params)
    params['wrist.R'] = tuple(wrist)
    G = h.pose(params)
    P = h.skin(G)
    Gw = G['wrist.R']
    c = (Gw @ np.r_[grip.c, 1])[:3]
    g = Gw[:3, :3] @ grip.g
    padw = (Gw @ np.r_[pad, 1])[:3]
    up = Gw[:3, :3] @ h.dorsal
    up -= g * (up @ g)
    up = normalize(up)
    zl = -g
    x0 = np.cross(up, zl)
    R = np.stack([x0, up, zl])                  # monde de la main → repère de la vue
    arm = R @ h.arm_dir                         # coude → poignet
    log('%s : angle lampe / avant-bras %.0f°' % (name, math.degrees(math.acos(np.clip(-arm[2], -1, 1)))))
    tf = lambda X: (np.asarray(X) - c) @ R.T
    # --- la main : lissage léger des zones tassées, une subdivision, normales
    Pl = tf(P)
    V2, F2, FT2, VT2 = catmull_clark(Pl, h.F, h.FT, mh.VT)
    V2 = sculpt_fist(h, G, tf, V2, F2, params)
    # --- la lampe : le culot 12 mm derrière l'auriculaire, l'interrupteur devant la pulpe du pouce
    sv = -Pl[:, 2]                               # abscisse le long de l'axe (vers l'avant)
    radial = np.linalg.norm(Pl[:, :2], axis=1)
    # le culot dépasse de TAIL_OUT derrière le tranchant de la main (l'auriculaire, côté lampe)
    bi = {b: i for i, b in enumerate(h.bones)}
    w5 = h.W[:, [bi['finger5-%d.R' % k] for k in (1, 2, 3)] + [bi['metacarpal4.R']]].sum(1)
    edge = (w5 > 0.5) & (radial < grip.r + 0.015)
    s_tail = sv[edge].min() - TAIL_OUT
    s_front = s_tail + LAMP_L
    padl = tf(padw)
    s_pad = -padl[2]
    sw_ang = math.atan2(padl[1], padl[0])
    parts, prof = build_lamp(LAMP_L)
    lamp = []
    for k, s in parts.items():
        lamp.append(s.transformed(np.eye(3), np.array([0, 0, -s_front])))
    z_switch = s_front - (s_pad + 0.003)         # (z de la lampe, depuis la face avant) : sous la pulpe
    sw = switch_boot(z_switch, sw_ang, 0.019, 0.0)
    lamp.append(sw.transformed(np.eye(3), np.array([0, 0, -s_front])))
    log('lampe : culot à %.0f mm derrière la prise, face avant à %.0f mm devant, interrupteur à %.0f mm de la face'
        % (s_tail * -1000, s_front * 1000, z_switch * 1000))
    # --- la manche : section de l'avant-bras près du poignet
    arm_axis = -(R @ h.arm_dir)                 # vers le coude, repère lampe
    wrist_l = tf(np.zeros(3))
    rel = Pl - wrist_l
    along = rel @ (-arm_axis)                    # > 0 côté main
    ring = (along < -0.010) & (along > -0.030)
    Q = rel[ring] - np.outer(rel[ring] @ arm_axis, arm_axis)
    cen = Q.mean(0)
    Qc = Q - cen
    U_, S_, Vt = np.linalg.svd(Qc, full_matrices=False)
    e1 = normalize(Vt[0] - arm_axis * (Vt[0] @ arm_axis))
    e2 = normalize(np.cross(arm_axis, e1))
    rx = np.percentile(np.abs(Qc @ e1), 98)
    ry = np.percentile(np.abs(Qc @ e2), 98)
    cuff_start = wrist_l + cen + arm_axis * 0.006
    sleeve = build_sleeve(cuff_start, arm_axis, e1, e2, rx, ry)
    log('manche : avant-bras %.0f × %.0f mm au poignet' % (rx * 2000, ry * 2000))
    bracelet = None
    if var.get('bracelet'):
        bracelet, blen = build_bracelet(V2, wrist_l + cen, arm_axis, e1, e2)
        log('bracelet : %.0f mm de tour' % (blen * 1000))
    info = dict(s_front=s_front, s_tail=s_tail, head=[0.0, 0.0, -s_front],
                wrist=wrist_l.tolist(), arm_axis=arm_axis.tolist())
    hand = dict(V=V2, F=F2, FT=FT2, VT=VT2, V0=Pl, F0=h.F, FT0=h.FT, hand=h, params=params, R=R, c=c,
                bracelet=bracelet, bracelet_len=blen if bracelet is not None else 0.0)
    return hand, lamp, sleeve, info, fitted


def quad_surface(name, V, F, FT, VT, N=None, C=None):
    """Surface à partir d'un maillage de quads avec UV par coin : un sommet par paire (position, UV)."""
    if N is None:
        N = vertex_normals(V, F)
    T = tris(F)
    TT = tris(FT)
    key = T.astype(np.int64) * (len(VT) + 1) + TT
    uk, inv = np.unique(key.ravel(), return_inverse=True)
    pi = uk // (len(VT) + 1)
    ti = uk % (len(VT) + 1)
    S = Surf(name, V[pi], N[pi], VT[ti], inv.reshape(-1, 3), None if C is None else C[pi])
    return S, pi


def export_variant(mh, name, out_dir, fit=None, log=print, **kw):
    hand, lamp, sleeve, info, fitted = assemble(mh, name, fit=fit, log=log, **kw)
    skin, _ = quad_surface('peau', hand['V'], hand['F'], hand['FT'], hand['VT'])
    head = np.array(info['head']) + np.array([0, 0, 0.004])
    nodes = [('Main', [skin], None), ('Manche', [sleeve], None),
             ('Lampe', [s for s in lamp], None), ('Tete', None, head)]
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, 'main_%s.glb' % name)
    write_glb(path, nodes, extras={k: (v if not isinstance(v, np.ndarray) else v.tolist()) for k, v in info.items()})
    log('écrit %s (%d sommets de peau, %d triangles)' % (path, len(skin.V), len(skin.T)))
    return hand, lamp, sleeve, info, fitted

# ----------------------------------------------------------------------------- textures : outils

def uv_islands(FT):
    """Îlots d'UV (composantes connexes par sommets d'UV partagés). Rend un numéro d'îlot par face."""
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components
    FT = np.asarray(FT)
    nf = len(FT)
    rows = np.repeat(np.arange(nf), FT.shape[1])
    cols = FT.ravel()
    n = cols.max() + 1
    A = coo_matrix((np.ones(len(rows)), (rows, cols + nf)), shape=(nf + n, nf + n))
    k, lab = connected_components(A, directed=False)
    return lab[:nf]


def pack_islands(VT, FT, margin=0.012):
    """Repacke les îlots d'UV des faces FT dans [0,1]² (étagères, même échelle pour tous) ;
    rend de nouvelles UV (une par sommet d'UV utilisé) et les nouveaux indices."""
    FT = np.asarray(FT)
    used = np.unique(FT)
    remap = -np.ones(len(VT), int)
    remap[used] = np.arange(len(used))
    UV = VT[used].copy()
    F = remap[FT]
    lab = uv_islands(F)
    isl = []
    for i in np.unique(lab):
        vs = np.unique(F[lab == i])
        lo, hi = UV[vs].min(0), UV[vs].max(0)
        isl.append((vs, lo, hi - lo))
    isl.sort(key=lambda x: -x[2][1])

    def place(s):
        x = y = margin
        row_h = 0.0
        pos = []
        for vs, lo, size in isl:
            w, h = size * s
            if x + w + margin > 1.0:
                x = margin
                y += row_h + margin
                row_h = 0.0
            pos.append((x, y))
            x += w + margin
            row_h = max(row_h, h)
        return pos, y + row_h + margin

    lo_s, hi_s = 0.1, 20.0
    for _ in range(40):
        mid = (lo_s + hi_s) / 2
        pos, H = place(mid)
        if H <= 1.0 and all(p[0] + isl[i][2][0] * mid <= 1.0 for i, p in enumerate(pos)):
            lo_s = mid
        else:
            hi_s = mid
    s = lo_s
    pos, _ = place(s)
    out = UV.copy()
    for (vs, lo, size), (x, y) in zip(isl, pos):
        out[vs] = (UV[vs] - lo) * s + np.array([x, y])
    return out, F, s


def raster_uv(UVp, T_uv, attrs, res):
    """Rastérise des triangles dans l'espace UV (UVp en pixels, origine en haut à gauche). attrs : liste
    de tableaux (n_sommets_uv, k) interpolés (barycentriques). Rend (masque, [cartes], id de triangle)."""
    H = W = res
    mask = np.zeros((H, W), bool)
    outs = [np.zeros((H, W, a.shape[1]), np.float32) for a in attrs]
    tid = -np.ones((H, W), np.int32)
    for ti, t in enumerate(T_uv):
        xs, ys = UVp[t, 0], UVp[t, 1]
        x0 = max(int(np.floor(xs.min())) - 1, 0)
        x1 = min(int(np.ceil(xs.max())) + 1, W - 1)
        y0 = max(int(np.floor(ys.min())) - 1, 0)
        y1 = min(int(np.ceil(ys.max())) + 1, H - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        d = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
        if abs(d) < 1e-12:
            continue
        a = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / d
        b = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / d
        c = 1 - a - b
        m = (a >= -1e-4) & (b >= -1e-4) & (c >= -1e-4)
        if not m.any():
            continue
        sub = mask[y0:y1 + 1, x0:x1 + 1]
        for o, at in zip(outs, attrs):
            val = a[..., None] * at[t[0]] + b[..., None] * at[t[1]] + c[..., None] * at[t[2]]
            o[y0:y1 + 1, x0:x1 + 1][m] = val[m]
        tid[y0:y1 + 1, x0:x1 + 1][m] = ti
        sub[m] = True
    return mask, outs, tid


def dilate(img, mask, px=16):
    """Étend les pixels couverts dans la marge (plus proche pixel couvert) : pas de couture aux mipmaps."""
    from scipy import ndimage
    if mask.all():
        return img
    d, (iy, ix) = ndimage.distance_transform_edt(~mask, return_indices=True)
    out = img[iy, ix]
    return out


class Noise3:
    """Bruit de valeur 3D (réseau aléatoire, interpolation trilinéaire lissée), vectorisé."""

    def __init__(self, seed=0, n=64):
        self.r = np.random.default_rng(seed).random((n, n, n)).astype(np.float32)
        self.n = n

    def __call__(self, P):
        n = self.n
        P = np.asarray(P, np.float32)
        i = np.floor(P).astype(np.int64)
        f = P - i
        f = f * f * (3 - 2 * f)
        i %= n
        j = (i + 1) % n
        r = self.r
        out = 0
        for dx in (0, 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    ix = j[..., 0] if dx else i[..., 0]
                    iy = j[..., 1] if dy else i[..., 1]
                    iz = j[..., 2] if dz else i[..., 2]
                    w = (f[..., 0] if dx else 1 - f[..., 0]) * (f[..., 1] if dy else 1 - f[..., 1]) * (f[..., 2] if dz else 1 - f[..., 2])
                    out = out + w * r[ix, iy, iz]
        return out

    def fbm(self, P, octaves=4, lac=2.03, gain=0.5):
        s, a, tot = 0, 1.0, 0
        P = np.asarray(P, np.float32)
        for o in range(octaves):
            s = s + a * (self(P * lac ** o + o * 17.31) - 0.5)
            tot += a
            a *= gain
        return s / tot


def _masked_diff(H, mask, axis):
    """Dérivée centrale de H le long de « axis », en n'utilisant que les pixels de « mask »."""
    Hp = np.roll(H, -1, axis)
    Hm = np.roll(H, 1, axis)
    mp = np.roll(mask, -1, axis)
    mm = np.roll(mask, 1, axis)
    d = np.zeros_like(H)
    both = mp & mm
    d[both] = (Hp[both] - Hm[both]) / 2
    only_p = mp & ~mm
    d[only_p] = Hp[only_p] - H[only_p]
    only_m = mm & ~mp
    d[only_m] = H[only_m] - Hm[only_m]
    return d * mask


def write_import(path, normal=False):
    """Réglages d'import Godot d'une texture 3D : VRAM (S3TC/BPTC ; RGTC pour une carte de normales),
    mipmaps. (Sans éditeur, la détection « utilisée en 3D » ne passe jamais.) Un .import déjà écrit par
    Godot est gardé (son uid aussi) : seuls ces réglages y sont remis."""
    imp = path + '.import'
    if os.path.exists(imp):
        import re
        text = open(imp).read()
        want = {'compress/mode': '2', 'compress/normal_map': '1' if normal else '0', 'mipmaps/generate': 'true',
                'detect_3d/compress_to': '0'}
        for k, v in want.items():
            text = re.sub(r'(?m)^%s=.*$' % re.escape(k), '%s=%s' % (k, v), text)
        open(imp, 'w').write(text)
        return
    with open(imp, 'w') as f:
        f.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
                'compress/mode=2\ncompress/high_quality=%s\ncompress/normal_map=%d\nmipmaps/generate=true\n'
                'roughness/mode=0\nprocess/fix_alpha_border=true\ndetect_3d/compress_to=0\n'
                % ('true' if normal else 'false', 1 if normal else 0))


def save_rgb(path, arr, quality=93):
    from PIL import Image
    a = np.clip(arr * 255.0 + 0.5, 0, 255).astype(np.uint8)
    im = Image.fromarray(a, 'RGB')
    if path.endswith('.jpg'):
        im.save(path, quality=quality, subsampling=0)
    else:
        im.save(path, optimize=True)


def srgb(c):
    return np.array(c, np.float32) / 255.0


def smooth01(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3 - 2 * x)


def ambient_occlusion(points, normals, occ_V, occ_T, rays=48, dist=0.05, seed=1, log=print):
    """Occlusion ambiante (hémisphère pondérée par le cosinus, portée « dist ») par lancer de rayons
    (embree via trimesh si possible). Rend une valeur par point (1 = dégagé)."""
    import trimesh
    mesh = trimesh.Trimesh(vertices=occ_V, faces=occ_T, process=False)
    rng = np.random.default_rng(seed)
    n = len(points)
    N = normalize(normals)
    # base orthonormée par point
    a = np.where(np.abs(N[:, :1]) < 0.9, np.array([[1.0, 0, 0]]), np.array([[0, 1.0, 0]]))
    T = normalize(np.cross(N, a))
    B = np.cross(N, T)
    occ = np.zeros(n)
    t0 = time.time()
    for r in range(rays):
        u1, u2 = rng.random(n), rng.random(n)
        rr = np.sqrt(u1)
        th = 2 * np.pi * u2
        d = T * (rr * np.cos(th))[:, None] + B * (rr * np.sin(th))[:, None] + N * np.sqrt(1 - u1)[:, None]
        o = points + N * 0.0004
        tri, ray, loc = mesh.ray.intersects_id(o, d, multiple_hits=False, return_locations=True)
        if len(ray):
            dd = np.linalg.norm(loc - o[ray], axis=1)
            w = np.clip(1.0 - dd / dist, 0, 1) ** 0.7
            occ[ray] += w
    log('  occlusion : %d points × %d rayons en %.1f s (%s)' % (n, rays, time.time() - t0, type(mesh.ray).__module__))
    return 1.0 - occ / rays

# ----------------------------------------------------------------------------- la peau

SKIN = {
    # couleurs sRGB : dos de la main, paume, rougeurs (articulations, pulpe), ongle
    'alexandre': dict(dos=(190, 152, 134), paume=(208, 172, 156), rouge=(182, 128, 112), ongle=(210, 168, 160),
                      veines=1.0, taches=14, seed=11),
    'aurelia': dict(dos=(204, 166, 150), paume=(218, 184, 170), rouge=(194, 138, 126), ongle=(218, 176, 170),
                    veines=0.6, taches=8, seed=23, bord=0.985,
                    vernis=(118, 20, 38)),     # vernis cerise écaillé (une ado des années 90)
}

FINGER_BONES = ['finger%d-%d.R' % (f, k) for f in range(1, 6) for k in (1, 2, 3)]
PALM_BONES = ['metacarpal1.R', 'metacarpal2.R', 'metacarpal3.R', 'metacarpal4.R', 'wrist.R', 'lowerarm02.R']


def _nearest_bone(h, P, bones):
    """Pour chaque point : l'os le plus proche (segment), l'abscisse t le long de l'os (non bornée),
    la distance, et l'angle φ autour de l'os (0 = côté dos / ongle)."""
    best = np.full(len(P), np.inf)
    bi = np.zeros(len(P), int)
    tt = np.zeros(len(P))
    phi = np.zeros(len(P))
    for j, b in enumerate(bones):
        a, c = h.head[b], h.tail[b]
        ab = c - a
        L2 = ab @ ab
        t = ((P - a) @ ab) / L2
        q = a + np.outer(np.clip(t, 0, 1), ab)
        d = np.linalg.norm(P - q, axis=1)
        m = d < best
        best[m] = d[m]
        bi[m] = j
        tt[m] = t[m]
        Fr = h.frame[b]
        rad = P[m] - q[m]
        phi[m] = np.arctan2(rad @ Fr[:, 0], rad @ Fr[:, 2])
    return bi, tt, best, phi


def bake_skin(h, hand, mh, name, out_dir, occluders, res=2048, ao_res=512, log=print):
    """Textures de la peau (albédo sRGB, normales, ORM : occlusion cuite dans la pose, rugosité) dans un
    nouveau placement d'UV (îlots MakeHuman repackés). Rend les UV (glTF : v vers le bas) par sommet d'UV
    de hand['FT']."""
    cfg = SKIN[name]
    rng = np.random.default_rng(cfg['seed'])
    nz = Noise3(cfg['seed'])
    nz2 = Noise3(cfg['seed'] + 5)
    # UV repackées (de la subdivision) ; image : origine en haut à gauche
    UVp, FTp, sc = pack_islands(hand['VT'], hand['FT'])
    UVimg = np.c_[UVp[:, 0], 1.0 - UVp[:, 1]]          # OBJ (v vers le haut) → image / glTF
    # attributs par coin : position au repos, normale au repos, position posée, normale posée
    Vr, Fr_, _, _ = catmull_clark(h.V0, h.F)
    Nr = vertex_normals(Vr, hand['F'])
    Vp = hand['V']
    Np = vertex_normals(Vp, hand['F'])
    T = tris(hand['F'])
    TT = tris(FTp)
    # sommets d'UV → attributs (un sommet d'UV appartient à un seul sommet de position)
    nuv = len(UVp)
    pos_of_uv = np.zeros(nuv, int)
    pos_of_uv[TT.ravel()] = T.ravel()
    attrs = [Vr[pos_of_uv], Nr[pos_of_uv], Vp[pos_of_uv], Np[pos_of_uv]]
    t0 = time.time()
    mask, (P, N, Q, NQ), tid = raster_uv(UVimg * res, TT, attrs, res)
    log('  peau : %d texels couverts (%.0f %%), rastérisés en %.1f s' % (mask.sum(), 100 * mask.mean(), time.time() - t0))
    # taille d'un texel (m), par triangle
    a3 = np.linalg.norm(np.cross(Vr[T[:, 1]] - Vr[T[:, 0]], Vr[T[:, 2]] - Vr[T[:, 0]]), axis=1) / 2
    U = UVimg * res
    e1, e2 = U[TT[:, 1]] - U[TT[:, 0]], U[TT[:, 2]] - U[TT[:, 0]]
    a2 = np.abs(e1[:, 0] * e2[:, 1] - e1[:, 1] * e2[:, 0]) / 2
    tex_m = np.sqrt(a3 / np.maximum(a2, 1e-9))
    idx = np.where(mask)
    P = P[idx].astype(np.float64)
    N = normalize(N[idx].astype(np.float64))
    Q = Q[idx].astype(np.float64)
    NQ = normalize(NQ[idx].astype(np.float64))
    px = np.median(tex_m[tid[idx]])
    log('  texel ≈ %.3f mm' % (px * 1000))
    n = len(P)
    # ---------------------------------------------------------------- repères des os
    fb, ft, fd, fphi = _nearest_bone(h, P, FINGER_BONES)
    pb, pt, pd, pphi = _nearest_bone(h, P, PALM_BONES)
    on_finger = fd < pd * 0.95
    fing = np.array([int(FINGER_BONES[i][6]) for i in range(len(FINGER_BONES))])[fb]
    seg = np.array([int(FINGER_BONES[i][8]) for i in range(len(FINGER_BONES))])[fb]
    dorsal_n = N @ h.dorsal
    height = np.zeros(n)      # en mètres
    # ---------------------------------------------------------------- ongles
    is_thumb = fing == 1
    phimax = np.where(is_thumb, 1.0, 0.92)
    tcut = np.where(is_thumb, 0.30, 0.40) + 0.13 * (fphi / phimax) ** 2
    distal = on_finger & (seg == 3)
    side = np.abs(fphi) / phimax
    nail_w = smooth01((1.0 - side) / 0.10) * smooth01((ft - tcut) / 0.035) * distal
    # bord libre (blanc) : au bout, sur le dessus
    free = nail_w * smooth01((ft - cfg.get('bord', 1.02)) / 0.04)
    lunula = nail_w * smooth01(1.0 - (ft - tcut) / 0.10) * smooth01((0.75 - side) / 0.25)
    # repli de l'ongle (sillon) : juste autour de la plaque
    fold = distal * np.exp(-((np.minimum(np.abs(side - 1.0) / 0.08, np.abs(ft - tcut) / 0.03)) ** 2)) * (side < 1.15) * (ft > tcut - 0.08)
    height += nail_w * 0.00025 - fold * 0.00018
    # stries longitudinales de l'ongle
    height += nail_w * 0.000012 * np.sin(fphi * 60.0 + nz(P * 900.0) * 3.0)
    # ---------------------------------------------------------------- plis des articulations
    wr = np.zeros(n)           # plis du dos (sillons)
    crease = np.zeros(n)       # plis de flexion (paume)
    knuckle_red = np.zeros(n)
    joints = []
    for f in range(1, 6):
        for k in ((2, 3) if f == 1 else (1, 2, 3)):
            b = 'finger%d-%d.R' % (f, k)
            prev = h.parent[b]
            J = h.head[b]
            ax = normalize(h.tail[b] - h.head[b])
            if prev in h.head and prev.startswith('finger'):
                ax = normalize(ax + normalize(h.tail[prev] - h.head[prev]))
            joints.append((f, k, J, ax, h.frame[b]))
    for f, k, J, ax, Frm in joints:
        rel = P - J
        s = rel @ ax
        lat = rel @ Frm[:, 0]
        up = rel @ Frm[:, 2]
        near = (np.abs(s) < 0.012) & (np.abs(lat) < 0.014)
        if not near.any():
            continue
        dors = smooth01((up / np.maximum(np.sqrt(up ** 2 + lat ** 2), 1e-9) - 0.15) / 0.5)
        palm = smooth01((-up / np.maximum(np.sqrt(up ** 2 + lat ** 2), 1e-9) - 0.25) / 0.4)
        mm = 1000.0
        if k == 1:
            # jointure (MCP) : quelques plis lâches, rougeur
            e = np.sqrt((s * mm / 1.4) ** 2 + (lat * mm / 3.0) ** 2)
            lines = sum(np.exp(-((e - (2.0 + 1.6 * i)) / 0.5) ** 2) * (1.0 - 0.18 * i) for i in range(4))
            wr += near * dors * lines * smooth01(1 - e / 9.0) * 0.3
            knuckle_red += near * dors * np.exp(-(e / 4.5) ** 2) * 0.7
            # pli digito-palmaire (base du doigt, côté paume), 5 mm plus loin
            crease += near * palm * np.exp(-(((s * mm) - 5.0 - 0.6 * (lat * mm / 6.0) ** 2) / 0.45) ** 2) * smooth01(1 - np.abs(lat * mm) / 9.0)
        else:
            amp = 1.0 if k == 2 else 0.7
            rings = 5 if k == 2 else 3
            e = np.sqrt((s * mm / 1.0) ** 2 + (lat * mm / 2.4) ** 2)
            brk = 0.65 + 0.35 * np.sin(lat * mm * 1.7 + nz2(P * 400.0) * 6.0)
            lines = sum(np.exp(-((e - (0.9 + 1.05 * i)) / 0.33) ** 2) * (1.0 - 0.12 * i) for i in range(rings))
            wr += near * dors * lines * brk * smooth01(1 - e / (rings * 1.3 + 1.5)) * amp
            knuckle_red += near * dors * np.exp(-(e / 4.0) ** 2) * amp
            # plis de flexion : un double pli (IPP) ou simple (IPD), côté paume
            for off in ((-0.7, 0.7) if k == 2 else (0.0,)):
                crease += near * palm * np.exp(-(((s * mm) - off - 0.25 * (lat * mm / 4.0) ** 2) / 0.32) ** 2) * smooth01(1 - np.abs(lat * mm) / 8.0)
    wr = np.clip(wr, 0, 1.5)
    crease = np.clip(crease, 0, 1.2)
    height -= wr * 0.00006 + crease * 0.00018
    # ---------------------------------------------------------------- dos de la main : veines, micro-relief
    back = (~on_finger) & (dorsal_n > 0.2)
    backw = smooth01((dorsal_n - 0.2) / 0.4) * (~on_finger)
    A = np.stack([h.fwd * 38.0, h.lat * 230.0, h.dorsal * 120.0])
    vn = nz.fbm(P @ A.T + 3.1, 2)
    vein = smooth01(1.0 - np.abs(vn) * 6.0) * backw * cfg['veines']
    vein *= smooth01((nz2(P * 60.0) - 0.35) / 0.2)       # (veines par endroits, pas un réseau partout)
    # pas de veines au poignet/avant-bras (sous la manche) ni près des jointures
    along = (P - h.head['wrist.R']) @ h.fwd
    vein *= smooth01((along - 0.005) / 0.02) * smooth01((0.075 - along) / 0.02)
    height += vein * 0.00030
    # micro-relief losangé (dos de la main, dos des doigts)
    d1 = normalize(h.fwd + h.lat * 0.9)
    d2 = normalize(h.fwd - h.lat * 0.9)
    hatch = (np.abs(np.sin(P @ d1 * 2600.0 + nz(P * 700) * 4)) ** 8 + np.abs(np.sin(P @ d2 * 2600.0 + nz2(P * 700) * 4)) ** 8)
    hatchw = np.clip(dorsal_n, 0, 1) * (1 - nail_w)
    height -= hatch * hatchw * 0.000022
    # pores : petites cuvettes
    pv = nz(P * 2600.0)
    pores = smooth01((pv - 0.70) / 0.12) * (1 - nail_w)
    height -= pores * 0.000030
    height += nz.fbm(P * 1800.0, 2) * 0.000016 * (1 - nail_w)
    # ---------------------------------------------------------------- albédo
    dos = srgb(cfg['dos'])
    paume = srgb(cfg['paume'])
    rouge = srgb(cfg['rouge'])
    palmw = smooth01((-dorsal_n + 0.1) / 0.5)
    if True:
        # (doigts : la paume est le côté opposé à l'ongle)
        fpalm = smooth01((np.abs(fphi) - 1.6) / 0.6)
        palmw = np.where(on_finger, fpalm, palmw)
    col = dos[None, :] * (1 - palmw[:, None]) + paume[None, :] * palmw[:, None]
    # variations basses fréquences (marbrures légèrement rouges)
    m1 = nz.fbm(P * 60.0, 3)
    m2 = nz2.fbm(P * 260.0, 3)
    col *= (1.0 + m1[:, None] * np.array([0.12, 0.15, 0.17]) + m2[:, None] * 0.06)
    col += (np.clip(m1, 0, None) * 0.06)[:, None] * (rouge - dos)[None, :]
    # pulpe des doigts et bout des doigts : plus rouges
    tip = on_finger & (seg == 3)
    tipw = tip * smooth01((ft - 0.2) / 0.5) * 0.62
    col = col * (1 - tipw[:, None]) + rouge[None, :] * tipw[:, None]
    # jointures
    kr = np.clip(knuckle_red, 0, 1) * 0.72
    col = col * (1 - kr[:, None]) + rouge[None, :] * kr[:, None]
    # autour de l'ongle (repli) : rosé
    peri = distal * smooth01(1 - np.abs(side - 1.0) / 0.35) * (ft > tcut - 0.15) * (1 - nail_w) * 0.45
    col = col * (1 - peri[:, None]) + rouge[None, :] * peri[:, None]
    # plis : un peu plus sombres
    col *= (1.0 - 0.10 * np.clip(wr, 0, 1) - 0.16 * np.clip(crease, 0, 1))[:, None]
    # veines : bleu-vert très léger
    col += (vein * 0.04)[:, None] * np.array([-0.9, -0.25, 0.45])[None, :]
    # taches de rousseur rares (dos de la main et des doigts)
    for i in range(cfg['taches']):
        c = P[back][rng.integers(0, back.sum())] if back.any() else None
        if c is None:
            break
        r = rng.uniform(0.0004, 0.0009)
        w = np.exp(-(np.linalg.norm(P - c, axis=1) / r) ** 2) * rng.uniform(0.12, 0.3)
        col = col * (1 - w[:, None]) + srgb((178, 118, 92))[None, :] * w[:, None]
    # ongle : plaque rosée (lit de l'ongle), lunule pâle, bord libre blanc, cuticule
    ongle = srgb(cfg['ongle']) * (1.0 + nz(P * 500.0)[:, None] * 0.04)
    col = col * (1 - nail_w[:, None]) + ongle * nail_w[:, None]
    lun = lunula * 0.55
    col = col * (1 - lun[:, None]) + srgb((236, 214, 204))[None, :] * lun[:, None]
    col = col * (1 - free[:, None] * 0.85) + srgb((236, 228, 212))[None, :] * (free[:, None] * 0.85)
    cut = distal * np.exp(-(((ft - tcut) / 0.02) ** 2)) * (side < 1.0) * 0.35
    col = col * (1 - cut[:, None]) + srgb((176, 116, 102))[None, :] * cut[:, None]
    polish = np.zeros(n)
    if cfg.get('vernis'):
        # vernis écaillé : il s'arrête un peu avant la cuticule, des éclats surtout vers le bord libre
        chip = nz2(P * 1500.0) * 0.6 + nz(P * 4200.0) * 0.4
        chipped = chip > 0.30 - 0.55 * smooth01((ft - 0.80) / 0.20)
        polish = nail_w * smooth01((ft - tcut - 0.010) / 0.012) * (~chipped) * smooth01((0.97 - side) / 0.08)
        vc = srgb(cfg['vernis']) * (1.0 + nz(P * 700.0)[:, None] * 0.05)
        col = col * (1 - polish[:, None]) + vc * polish[:, None]
        height += polish * 0.00004
    col = np.clip(col, 0, 1)
    # ---------------------------------------------------------------- rugosité
    rough = np.full(n, 0.50)
    rough += palmw * 0.06
    rough += np.clip(wr, 0, 1) * 0.05 + pores * 0.04
    rough += nz2.fbm(P * 180.0, 3) * 0.06
    rough = rough * (1 - nail_w) + (0.24 + nz(P * 300.0) * 0.06) * nail_w
    rough = rough * (1 - polish) + 0.12 * polish
    rough = np.clip(rough, 0.18, 0.75)
    # ---------------------------------------------------------------- occlusion (pose)
    occV, occT = occluders
    sub = (idx[0] % (res // ao_res) == 0) & (idx[1] % (res // ao_res) == 0)
    ao_s = ambient_occlusion(Q[sub], NQ[sub], occV, occT, rays=56, dist=0.06, log=log)
    ao_img = np.full((ao_res, ao_res), np.nan)
    ao_img[idx[0][sub] // (res // ao_res), idx[1][sub] // (res // ao_res)] = ao_s
    m_ao = ~np.isnan(ao_img)
    ao_img = dilate(np.nan_to_num(ao_img, nan=1.0), m_ao)
    from scipy import ndimage
    ao_img = ndimage.gaussian_filter(ao_img, 0.8)
    from PIL import Image
    ao_full = np.array(Image.fromarray(ao_img.astype(np.float32), 'F').resize((res, res), Image.BILINEAR))
    ao = np.clip(ao_full[idx], 0.0, 1.0)
    # (plus marquée qu'avant : creux entre les doigts, ombre de contact sous le corps de la lampe)
    ao = 0.12 + 0.88 * ao ** 1.35
    # ---------------------------------------------------------------- cartes
    img = np.zeros((res, res, 3), np.float32)
    img[idx] = col
    img = dilate(img, mask)
    Hm = np.zeros((res, res), np.float64)
    Hm[idx] = height
    Hm = dilate(Hm, mask)
    tm = np.zeros((res, res))
    tm[idx] = tex_m[tid[idx]]
    tm = dilate(tm, mask)
    # normales (convention OpenGL, Y en haut de l'image) depuis la hauteur (pente en m/m) ; différences
    # prises dans l'îlot seulement (un voisin hors de l'îlot : différence d'un seul côté)
    gx = _masked_diff(Hm, mask, 1) / tm
    gy = _masked_diff(Hm, mask, 0) / tm
    nrm = np.dstack([-gx, gy, np.ones_like(gx)])
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    # (marge autour des îlots : normale plate, pas les pentes de la hauteur étendue, sinon les mipmaps
    # font des traits clairs le long des coutures des doigts)
    nrm[~mask] = (0.0, 0.0, 1.0)
    nmap = nrm * 0.5 + 0.5
    orm = np.zeros((res, res, 3), np.float32)
    orm[..., 0][idx] = ao
    orm[..., 1][idx] = rough
    orm = dilate(orm, mask)
    os.makedirs(out_dir, exist_ok=True)
    pa = os.path.join(out_dir, 'peau_%s_albedo.jpg' % name)
    pn = os.path.join(out_dir, 'peau_%s_normal.png' % name)
    po = os.path.join(out_dir, 'peau_%s_orm.jpg' % name)
    save_rgb(pa, img)
    save_rgb(pn, nmap)
    save_rgb(po, orm)
    write_import(pa)
    write_import(pn, normal=True)
    write_import(po)
    log('  peau %s : albédo, normales, ORM écrits (texel %.3f mm)' % (name, px * 1000))
    debug = dict(mask=mask, idx=idx, nail=nail_w, wr=wr, crease=crease, vein=vein, ao=ao)
    return UVimg, FTp, debug

# ----------------------------------------------------------------------------- textures de la lampe

KNURL = (0.080, 0.170)       # bande moletée (z depuis la face avant, m)


def bake_lamp(lamp_parts, name, out_dir, occluders, prof, L=LAMP_L, res=(1024, 2048), log=print, shared=True):
    """Corps de la lampe (UV du tour : u = angle, v = z / L) : alu anodisé noir, moletage en diamant,
    rainures, usure (alu nu sur les arêtes et les pointes du moletage, rayures), occlusion de la main
    (ORM propre au héros). Les cartes d'albédo et de normales sont communes (shared)."""
    W, H = res
    body = [s for s in lamp_parts if s.name == 'lampe_corps'][0]
    nzl = Noise3(77)
    u = (np.arange(W) + 0.5) / W
    v = (np.arange(H) + 0.5) / H
    U, Vv = np.meshgrid(u, v)
    z = Vv * (L + 0.003)
    # rayon du profil à ce z (pour l'échelle et la position 3D)
    pz = np.array([p[0] for p in prof])
    pr = np.array([p[1] for p in prof])
    order = np.argsort(pz, kind='stable')
    rz = np.interp(z, pz[order], pr[order])
    ang = U * 2 * np.pi
    circ_m = 2 * np.pi * np.maximum(rz, 0.004)
    # moletage en diamant : deux familles d'hélices à ±30°
    knurl = smooth01((z - KNURL[0]) / 0.0015) * smooth01((KNURL[1] - z) / 0.0015)
    Nk = 72
    pitch = 0.0026
    a1 = np.mod(U * Nk + z / pitch, 1.0)
    a2 = np.mod(U * Nk - z / pitch, 1.0)
    tri1 = np.abs(a1 - 0.5) * 2
    tri2 = np.abs(a2 - 0.5) * 2
    kh = np.minimum(tri1, tri2)                 # 1 au sommet des pointes, 0 dans les sillons
    hgt = knurl * (kh - 0.5) * 0.00035
    # usure : arêtes du profil (chanfreins, bague), pointes du moletage, rayures
    dr = np.abs(np.gradient(rz, axis=0)) / (L / H)
    edge = np.clip(dr * 1.2, 0, 1)
    edge = np.maximum(edge, np.roll(edge, 2, 0))
    edge = np.maximum(edge, np.roll(edge, -2, 0))
    P3 = np.dstack([np.cos(ang) * rz, np.sin(ang) * rz, z])
    wn = nzl.fbm(P3 * 300.0, 3)
    wear = np.clip(edge * (0.55 + wn * 1.5), 0, 1)
    wear = np.maximum(wear, knurl * smooth01((kh - 0.86) / 0.1) * smooth01(0.5 + wn * 3.0) * 0.9)
    # rayures fines (traits aléatoires)
    rng = np.random.default_rng(5)
    scr = np.zeros((H, W))
    for i in range(140):
        y0 = rng.uniform(0, H)
        x0 = rng.uniform(0, W)
        ln = rng.uniform(8, 70)
        th = rng.uniform(-0.6, 0.6) + (np.pi / 2 if rng.random() < 0.3 else 0)
        for s in np.linspace(0, ln, int(ln * 1.5)):
            yy = int(y0 + np.cos(th) * s) % H
            xx = int(x0 + np.sin(th) * s * 0.5) % W
            scr[yy, xx] = max(scr[yy, xx], rng.uniform(0.3, 0.9))
    from scipy import ndimage
    scr = ndimage.gaussian_filter(scr, 0.6) * 2.0
    scr = np.clip(scr, 0, 1) * (rz > 0.015)
    wear = np.clip(np.maximum(wear, scr * 0.8), 0, 1)
    # chanfrein d'usure du culot (le congé arrondi) et des arêtes de la bague : alu mis à nu, qui dessine le
    # contour de la lampe même dans le noir
    bevel = smooth01((z - (L - 0.0052)) / 0.0008) * smooth01(((L - 0.0004) - z) / 0.0008)
    bevel = bevel * np.clip(0.75 + wn * 1.2, 0.35, 1.0)
    ring = (np.exp(-((z - 0.0012) / 0.0007) ** 2) + np.exp(-((z - 0.0185) / 0.0006) ** 2)) * np.clip(0.6 + wn * 1.5, 0, 1)
    wear = np.maximum(wear, np.clip(np.maximum(bevel, ring * 0.8), 0, 1))
    hgt -= scr * 0.00001
    # usure de la prise : la peinture s'est polie sous les doigts (zone moletée)
    # albédo : noir anodisé légèrement bleuté, alu nu, poussière dans les creux
    black = np.array([0.030, 0.030, 0.031])       # anodisé noir neutre (pas de reflet brun)
    alu = np.array([0.66, 0.66, 0.65])
    dust = np.array([0.11, 0.11, 0.11])
    alb = black[None, None, :] * (1.0 + wn[..., None] * 0.25)
    alb = alb * (1 - wear[..., None]) + alu[None, None, :] * wear[..., None]
    crev = knurl * smooth01((0.2 - kh) / 0.2) * 0.15
    alb = alb * (1 - crev[..., None]) + dust[None, None, :] * crev[..., None]
    rough = 0.40 + wn * 0.05 + crev * 0.18
    rough = rough * (1 - wear) + 0.30 * wear
    metal = 0.15 + wear * 0.85
    # face arrière (culot) et bague : un peu plus mates
    # normales
    m_per_px_u = circ_m / W
    m_per_px_v = (L + 0.003) / H
    gy, gx = np.gradient(hgt)
    gx = gx / m_per_px_u
    gy = gy / m_per_px_v
    nrm = np.dstack([-gx, gy, np.ones_like(gx)])
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    # occlusion par la main : texels du corps → points 3D (repère de la lampe posée)
    sub = 4
    us, vs = U[::sub, ::sub], Vv[::sub, ::sub]
    zs = vs * (L + 0.003)
    rs = np.interp(zs, pz[order], pr[order])
    # la surface du corps posée : même transformation que les sommets (translation le long de z)
    off = body.V[:, 2].min() - 0.0      # (z de la face avant dans le repère final, au plus petit)
    # (le corps a été translaté : z_final = z_lampe - s_front ; on retrouve s_front par le minimum)
    s_front = -(body.V[:, 2].min() - min(p[0] for p in prof))
    angs = us * 2 * np.pi
    pts = np.dstack([np.cos(angs) * rs, np.sin(angs) * rs, zs - s_front]).reshape(-1, 3)
    # normale du profil (approximée : radiale, corrigée par la pente)
    dr_dz = np.gradient(rs, axis=0) / ((L + 0.003) / (H / sub))
    nr = np.dstack([np.cos(angs), np.sin(angs), -dr_dz])
    nr = normalize(nr.reshape(-1, 3))
    occV, occT = occluders
    ao_s = ambient_occlusion(pts, nr, occV, occT, rays=32, dist=0.04, seed=3, log=log)
    ao_s = ao_s.reshape(us.shape)
    from PIL import Image
    ao = np.array(Image.fromarray(ao_s.astype(np.float32), 'F').resize((W, H), Image.BILINEAR))
    ao = 0.25 + 0.75 * np.clip(ao, 0, 1)
    ao *= 1.0 - crev * 0.6
    os.makedirs(out_dir, exist_ok=True)
    if shared:
        pa = os.path.join(out_dir, 'lampe_albedo.jpg')
        pn = os.path.join(out_dir, 'lampe_normal.png')
        save_rgb(pa, np.clip(alb, 0, 1))
        save_rgb(pn, nrm * 0.5 + 0.5)
        write_import(pa)
        write_import(pn, normal=True)
    po = os.path.join(out_dir, 'lampe_%s_orm.jpg' % name)
    save_rgb(po, np.dstack([ao, np.clip(rough, 0.05, 1), np.clip(metal, 0, 1)]))
    write_import(po)
    log('  lampe : textures écrites (%s)' % name)

# ----------------------------------------------------------------------------- textures de la manche

SLEEVE = {
    'alexandre': dict(tint=(92, 98, 112), rib=(82, 88, 101)),   # sweat anthracite bleuté (≈ 0,12 linéaire)
    'aurelia': dict(tint=(122, 70, 90), rib=(108, 61, 79)),     # pull prune
}
SLEEVE_U = 0.30          # m couverts par u ∈ [0, 1] (tour de la manche)
SLEEVE_V0, SLEEVE_V1 = -0.03, 0.44
FABRIC_TILE = 0.11       # taille d'un carreau de Fabric045 (m)


def bake_sleeve(sleeve, name, out_dir, fabric_dir, res=(1024, 2048), log=print):
    """Albédo et normales de la manche : jersey (Fabric045 d'ambientCG, CC0, teinté) sur le corps,
    côtes 1×1 sur le bord-côte (5,5 cm) ; UV en mètres ramenées à l'atlas."""
    from PIL import Image
    W, H = res
    col = np.asarray(Image.open(os.path.join(fabric_dir, 'Fabric045_Color.jpg')).convert('RGB'), np.float32) / 255
    nor = np.asarray(Image.open(os.path.join(fabric_dir, 'Fabric045_NormalGL.jpg')).convert('RGB'), np.float32) / 255
    th, tw = col.shape[:2]
    u_m = (np.arange(W) + 0.5) / W * SLEEVE_U
    v_m = SLEEVE_V0 + (np.arange(H) + 0.5) / H * (SLEEVE_V1 - SLEEVE_V0)
    Um, Vm = np.meshgrid(u_m, v_m)
    iy = ((Vm / FABRIC_TILE) * th).astype(int) % th
    ix = ((Um / FABRIC_TILE) * tw).astype(int) % tw
    c = col[iy, ix]
    nn = nor[iy, ix] * 2 - 1
    lum = c.mean(2)
    lum = (lum - lum.mean()) / (lum.std() + 1e-6)
    cfg = SLEEVE[name]
    tint = srgb(cfg['tint'])
    rib_c = srgb(cfg['rib'])
    nzs = Noise3(9)
    big = nzs.fbm(np.dstack([Um * 20, Vm * 20, np.zeros_like(Um)]), 3)
    alb = tint[None, None, :] * (1.0 + lum[..., None] * 0.10 + big[..., None] * 0.08)
    # bord-côte : côtes 1×1 (colonnes en relief), de v = 0 à 5,5 cm, et l'ourlet roulé
    cuff = smooth01((0.055 - Vm) / 0.003)
    ribs = np.cos(Um / SLEEVE_U * 2 * np.pi * 64) * 0.5 + 0.5
    rib_h = (ribs - 0.5)
    alb = alb * (1 - cuff[..., None]) + (rib_c[None, None, :] * (0.88 + ribs[..., None] * 0.2) * (1.0 + lum[..., None] * 0.05)) * cuff[..., None]
    # (mailles dans les côtes : petites bosses alternées le long de v)
    stitch = np.cos(Vm / 0.0011 * 2 * np.pi + (np.floor(Um / SLEEVE_U * 128) % 2) * np.pi) * 0.5 + 0.5
    hgt_rib = (rib_h * 0.0005 + (stitch - 0.5) * 0.00012) * cuff
    gy, gx = np.gradient(hgt_rib)
    gx /= SLEEVE_U / W
    gy /= (SLEEVE_V1 - SLEEVE_V0) / H
    nr = np.dstack([-gx, gy, np.ones_like(gx)])
    nr /= np.linalg.norm(nr, axis=2, keepdims=True)
    n_body = nn
    n_out = n_body * (1 - cuff[..., None]) + nr * cuff[..., None]
    n_out /= np.linalg.norm(n_out, axis=2, keepdims=True)
    # bouloches / fibres claires éparses
    fl = (nzs(np.dstack([Um * 900, Vm * 900, np.ones_like(Um)])) > 0.83) * 0.06
    alb = alb + fl[..., None]
    os.makedirs(out_dir, exist_ok=True)
    pa = os.path.join(out_dir, 'manche_%s_albedo.jpg' % name)
    pn = os.path.join(out_dir, 'manche_%s_normal.jpg' % name)
    save_rgb(pa, np.clip(alb, 0, 1))
    save_rgb(pn, n_out * 0.5 + 0.5)
    write_import(pa)
    write_import(pn, normal=True)
    log('  manche %s : textures écrites' % name)


def sleeve_uv_to_atlas(UV):
    return np.c_[UV[:, 0] / SLEEVE_U, (UV[:, 1] - SLEEVE_V0) / (SLEEVE_V1 - SLEEVE_V0)]

# ----------------------------------------------------------------------------- tout un héros

## Poignet (flexion palmaire, déviation ulnaire) et roulis : le dos de la main face à la caméra, l'avant-bras
## qui sort en bas de l'image (cherché avec la caméra du jeu : voir viewmodel.gd, REST_POS / REST_ROT).
POSE = dict(wrist=(20.0, -30.0, 0.0))
## Prise : obliquité de la lampe dans la paume (degrés, vers le bout des doigts), place du pouce autour de
## l'axe (grip_angle : vers le dos de la main, pour qu'on le voie depuis l'œil) et ongle penché en arrière.
GRIP_TILT = 26.0
THUMB_ANG = 45.0
THUMB_BACK = 0.0


def build_variant(mh, name, out_dir, fit=None, tex=2048, log=print, pose=POSE):
    t0 = time.time()
    hand, lamp, sleeve, info, fitted = assemble(mh, name, fit=fit, log=log, **pose)
    h = hand['hand']
    # occulteurs (repère final) : la main posée, le corps de la lampe et son bouton, la manche
    occ = [(hand['V'], tris(hand['F']))]
    for s in lamp:
        if s.name in ('lampe_corps', 'lampe_bouton'):
            occ.append((s.V, s.T))
    occ.append((sleeve.V, sleeve.T))
    if hand.get('bracelet') is not None:
        occ.append((hand['bracelet'].V, hand['bracelet'].T))
    OV, OT, o = [], [], 0
    for v, t in occ:
        OV.append(v)
        OT.append(t + o)
        o += len(v)
    occV, occT = np.concatenate(OV), np.concatenate(OT)
    UVimg, FTp, dbg = bake_skin(h, hand, mh, name, out_dir, (occV, occT), res=tex, log=log)
    _, prof = build_lamp(LAMP_L)
    bake_lamp(lamp, name, out_dir, (occV, occT), prof, log=log, shared=(name == 'alexandre') or not os.path.exists(os.path.join(out_dir, 'lampe_albedo.jpg')))
    fab = os.path.normpath(os.path.join(HERE, '..', 'assets', 'textures', 'Fabric045'))
    bake_sleeve(sleeve, name, out_dir, fab, log=log)
    if hand.get('bracelet') is not None:
        bake_bracelet(name, out_dir, hand['bracelet_len'], log=log)
    skin, _ = quad_surface('peau', hand['V'], hand['F'], FTp, UVimg)
    sl = Surf('manche', sleeve.V, sleeve.N, sleeve_uv_to_atlas(sleeve.UV), sleeve.T, sleeve.C)
    head = np.array(info['head']) + np.array([0, 0, 0.004])
    nodes = [('Main', [skin], None), ('Manche', [sl], None), ('Lampe', lamp, None), ('Tete', None, head)]
    if hand.get('bracelet') is not None:
        nodes.append(('Bracelet', [hand['bracelet']], None))
    path = os.path.join(out_dir, 'main_%s.glb' % name)
    write_glb(path, nodes, extras={k: (v.tolist() if isinstance(v, np.ndarray) else (float(v) if isinstance(v, np.floating) else v)) for k, v in info.items()})
    log('%s : %s (%d sommets de peau, %d triangles) en %.0f s' % (name, path, len(skin.V), len(skin.T), time.time() - t0))
    return dict(hand=hand, lamp=lamp, sleeve=sleeve, info=info, fitted=fitted, debug=dbg, skin=skin)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--mh', default=MH_DEFAULT, help='dossier du dépôt MakeHuman (données lues seulement)')
    ap.add_argument('--out', default=OUT_DEFAULT)
    ap.add_argument('--variante', default='toutes', choices=['alexandre', 'aurelia', 'toutes'])
    ap.add_argument('--tex', type=int, default=2048)
    ap.add_argument('--cache', default='', help='dossier de cache des prises ajustées (pickle)')
    a = ap.parse_args()
    mh = MH(a.mh)
    names = ['alexandre', 'aurelia'] if a.variante == 'toutes' else [a.variante]
    for name in names:
        fit = None
        cp = os.path.join(a.cache, 'prise_%s.json' % name) if a.cache else ''
        if cp and os.path.exists(cp):
            d = json.load(open(cp))
            fit = ({k: tuple(v) for k, v in d['params'].items()}, Grip(d['c'], d['g'], d['r']), np.array(d['pad']))
        r = build_variant(mh, name, a.out, fit=fit, tex=a.tex)
        if cp:
            os.makedirs(a.cache, exist_ok=True)
            pr, gr, pad = r['fitted']
            json.dump({'params': {k: [float(x) for x in v] for k, v in pr.items()}, 'c': gr.c.tolist(),
                       'g': gr.g.tolist(), 'r': gr.r, 'pad': np.asarray(pad).tolist()}, open(cp, 'w'), indent=1)


if __name__ == '__main__':
    main()
