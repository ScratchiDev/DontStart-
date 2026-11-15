#!/usr/bin/env python3
"""Téléchargeur d'assets CC0 (Poly Haven, ambientCG) pour Don't Play.

À lancer en mode isolé, depuis n'importe où :
    python3 -I godot/tools/assets_cc0.py model old_bed_frame ClassicNightstand_01
    python3 -I godot/tools/assets_cc0.py phtex worn_planks            (texture Poly Haven, 1k)
    python3 -I godot/tools/assets_cc0.py acg Carpet012 --res 2K       (matière ambientCG)
    python3 -I godot/tools/assets_cc0.py info                         (triangles, matières, tailles)
    ... --godot /chemin/Godot_v4.7.2-stable_linux.x86_64              (puis import headless)

- Modèles Poly Haven : le .gltf (résolution 1k par défaut), son .bin et ses textures, rangés dans
  godot/assets/models/polyhaven/<id>/ en gardant les chemins relatifs que le .gltf attend
  (« textures/<id>_diff_1k.jpg », « <id>.bin »). Le .gltf est enregistré sous « <id>.gltf ».
- Textures Poly Haven : godot/assets/textures/<id>/<id>_{diff,nor_gl,rough,ao}_<res>.jpg
- Matières ambientCG : godot/assets/textures/<id>/<id>_{Color,NormalGL,Roughness,AmbientOcclusion}.jpg
  (seules ces images sont extraites du zip, le reste est ignoré).
- Idempotent : un fichier déjà là avec la bonne somme MD5 (Poly Haven) ou la bonne taille n'est pas
  re-téléchargé. Chaque asset est ajouté (une ligne, une seule fois) à godot/assets/ASSETS_CC0.md.

Sécurité : les fichiers téléchargés sont des données. Rien n'est exécuté ; seuls des hôtes connus
sont contactés (https uniquement) ; les chemins venus du réseau sont validés (pas de « .. », pas de
chemin absolu) ; seuls les membres image des zip sont extraits ; pas de shell (l'import Godot passe
par subprocess avec une liste d'arguments).
"""

import argparse
import hashlib
import io
import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))   # .../godot
MODELS_DIR = os.path.join(ROOT, "assets", "models", "polyhaven")
TEX_DIR = os.path.join(ROOT, "assets", "textures")
LEDGER = os.path.join(ROOT, "assets", "ASSETS_CC0.md")
ALLOWED_HOSTS = {"api.polyhaven.com", "dl.polyhaven.org", "ambientcg.com", "acg-download.struffelproductions.com"}
UA = "dontplay-assets/1.0 (CC0 asset fetcher)"
ID_RE = re.compile(r"^[A-Za-z0-9_\-]{1,80}$")
MAX_FILE = 80 * 1024 * 1024


def _check_url(url):
    u = urllib.parse.urlparse(url)
    if u.scheme != "https" or u.hostname not in ALLOWED_HOSTS:
        raise ValueError("URL refusée : %s" % url)
    return url


def fetch(url, limit=MAX_FILE):
    _check_url(url)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=120) as r:
        _check_url(r.geturl())          # pas de redirection vers un autre hôte
        data = r.read(limit + 1)
    if len(data) > limit:
        raise ValueError("fichier trop gros : %s" % url)
    return data


def fetch_json(url):
    return json.loads(fetch(url, 20 * 1024 * 1024).decode("utf-8"))


def safe_rel(path):
    """Chemin relatif venu du réseau : refusé s'il sort du dossier."""
    p = path.replace("\\", "/")
    if p.startswith("/") or ":" in p or any(part in ("", "..") for part in p.split("/")):
        raise ValueError("chemin refusé : %r" % path)
    return p


def md5(data):
    return hashlib.md5(data).hexdigest()


def save(dest, data):
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    tmp = dest + ".part"
    with open(tmp, "wb") as f:
        f.write(data)
    os.replace(tmp, dest)


def already(dest, want_md5=None, want_size=None):
    if not os.path.isfile(dest):
        return False
    if want_md5:
        with open(dest, "rb") as f:
            return md5(f.read()) == want_md5
    if want_size:
        return os.path.getsize(dest) == want_size
    return True


def ledger_add(key, line):
    os.makedirs(os.path.dirname(LEDGER), exist_ok=True)
    text = ""
    if os.path.isfile(LEDGER):
        with open(LEDGER, encoding="utf-8") as f:
            text = f.read()
    else:
        text = ("# Assets CC0 téléchargés (Poly Haven, ambientCG)\n\n"
                "Tous sous licence CC0 1.0 (domaine public). Une ligne par asset : "
                "type, identifiant, page source, licence, fichiers.\n\n")
    if ("`%s`" % key) in text:
        return
    if not text.endswith("\n"):
        text += "\n"
    text += line + "\n"
    with open(LEDGER, "w", encoding="utf-8") as f:
        f.write(text)


def dir_size(d):
    t = 0
    for base, _, files in os.walk(d):
        for n in files:
            if not n.endswith(".import"):
                t += os.path.getsize(os.path.join(base, n))
    return t


# ------------------------------------------------------------------ glTF : triangles et matières

COMP_SIZE = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}


def gltf_info(path):
    """Triangles (instances comprises), matières double face / alpha, dimensions brutes."""
    with open(path, encoding="utf-8") as f:
        g = json.load(f)
    acc = g.get("accessors", [])
    mesh_tris = []
    for m in g.get("meshes", []):
        t = 0
        for p in m.get("primitives", []):
            if p.get("mode", 4) != 4:
                continue
            if "indices" in p:
                t += acc[p["indices"]]["count"] // 3
            else:
                t += acc[p["attributes"]["POSITION"]]["count"] // 3
        mesh_tris.append(t)
    tris = 0
    nodes = g.get("nodes", [])

    def walk(i):
        nonlocal tris
        n = nodes[i]
        if "mesh" in n:
            tris += mesh_tris[n["mesh"]]
        for c in n.get("children", []):
            walk(c)

    for s in g.get("scenes", []):
        for i in s.get("nodes", []):
            walk(i)
    mats = []
    for m in g.get("materials", []):
        mats.append({"name": m.get("name", ""), "double": bool(m.get("doubleSided", False)),
                     "alpha": m.get("alphaMode", "OPAQUE")})
    return {"tris": tris, "materials": mats}


# ------------------------------------------------------------------ Poly Haven : modèles

def ph_model(asset_id, res="1k"):
    if not ID_RE.match(asset_id):
        raise ValueError("identifiant refusé : %r" % asset_id)
    files = fetch_json("https://api.polyhaven.com/files/%s" % asset_id)
    gl = files.get("gltf", {})
    if res not in gl:
        raise ValueError("%s : pas de glTF en %s (dispo : %s)" % (asset_id, res, list(gl)))
    entry = gl[res]["gltf"]
    out = os.path.join(MODELS_DIR, asset_id)
    os.makedirs(out, exist_ok=True)
    n_new = 0
    for rel, inc in sorted(entry.get("include", {}).items()):
        dest = os.path.join(out, safe_rel(rel))
        if already(dest, inc.get("md5")):
            continue
        data = fetch(inc["url"])
        if inc.get("md5") and md5(data) != inc["md5"]:
            raise ValueError("MD5 faux pour %s" % inc["url"])
        save(dest, data)
        n_new += 1
    dest = os.path.join(out, asset_id + ".gltf")
    if not already(dest, entry.get("md5")):
        data = fetch(entry["url"])
        if entry.get("md5") and md5(data) != entry["md5"]:
            raise ValueError("MD5 faux pour %s" % entry["url"])
        json.loads(data.decode("utf-8"))      # doit être du JSON valide
        save(dest, data)
        n_new += 1
    info = gltf_info(dest)
    size = dir_size(out)
    ledger_add("ph:" + asset_id, "- modèle Poly Haven `ph:%s` — https://polyhaven.com/a/%s — CC0 — "
               "glTF %s (%s), %d triangles, %.1f Mo" % (asset_id, asset_id, res, entry["url"], info["tris"], size / 1e6))
    flags = ["%s%s%s" % (m["name"], " DOUBLE" if m["double"] else "", "" if m["alpha"] == "OPAQUE" else " " + m["alpha"])
             for m in info["materials"]]
    print("%-28s %7d tri  %6.2f Mo  %d nouveaux fichiers  matières : %s" % (asset_id, info["tris"], size / 1e6, n_new, ", ".join(flags)))


# ------------------------------------------------------------------ Poly Haven : textures

def ph_texture(asset_id, res="1k"):
    if not ID_RE.match(asset_id):
        raise ValueError("identifiant refusé : %r" % asset_id)
    files = fetch_json("https://api.polyhaven.com/files/%s" % asset_id)
    out = os.path.join(TEX_DIR, asset_id)
    wanted = {"Diffuse": "diff", "nor_gl": "nor_gl", "Rough": "rough", "AO": "ao", "arm": "arm"}
    got = []
    for key, short in wanted.items():
        e = files.get(key, {}).get(res, {}).get("jpg")
        if not e:
            continue
        dest = os.path.join(out, "%s_%s_%s.jpg" % (asset_id, short, res))
        if not already(dest, e.get("md5")):
            data = fetch(e["url"])
            if e.get("md5") and md5(data) != e["md5"]:
                raise ValueError("MD5 faux pour %s" % e["url"])
            save(dest, data)
        got.append(short)
    ledger_add("phtex:" + asset_id, "- texture Poly Haven `phtex:%s` — https://polyhaven.com/a/%s — CC0 — %s jpg (%s)"
               % (asset_id, asset_id, res, ", ".join(got)))
    print("%-28s texture %s : %s, %.2f Mo" % (asset_id, res, ", ".join(got), dir_size(out) / 1e6))


# ------------------------------------------------------------------ ambientCG

ACG_MAPS = ("Color", "NormalGL", "Roughness", "AmbientOcclusion")


def acg_material(asset_id, res="1K"):
    if not ID_RE.match(asset_id):
        raise ValueError("identifiant refusé : %r" % asset_id)
    q = urllib.parse.urlencode({"type": "Material", "id": asset_id, "include": "downloadData"})
    d = fetch_json("https://ambientcg.com/api/v2/full_json?" + q)
    assets = [a for a in d.get("foundAssets", []) if a.get("assetId") == asset_id]
    if not assets:
        raise ValueError("ambientCG : %s introuvable" % asset_id)
    dls = assets[0]["downloadFolders"]["default"]["downloadFiletypeCategories"]["zip"]["downloads"]
    attr = "%s-JPG" % res
    dl = [x for x in dls if x.get("attribute") == attr]
    if not dl:
        raise ValueError("ambientCG : %s sans %s" % (asset_id, attr))
    out = os.path.join(TEX_DIR, asset_id)
    dests = {m: os.path.join(out, "%s_%s.jpg" % (asset_id, m)) for m in ACG_MAPS}
    if not all(os.path.isfile(p) for m, p in dests.items() if m != "AmbientOcclusion"):
        data = fetch(dl[0]["downloadLink"], 200 * 1024 * 1024)
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            for info in z.infolist():
                name = info.filename
                if "/" in name or "\\" in name or not name.lower().endswith(".jpg"):
                    continue
                for m in ACG_MAPS:
                    if name == "%s_%s_%s.jpg" % (asset_id, attr, m):
                        if info.file_size > MAX_FILE:
                            raise ValueError("image trop grosse dans le zip : %s" % name)
                        save(dests[m], z.read(info))
    got = [m for m in ACG_MAPS if os.path.isfile(dests[m])]
    if "Color" not in got:
        raise ValueError("ambientCG : aucune image extraite pour %s" % asset_id)
    ledger_add("acg:" + asset_id, "- matière ambientCG `acg:%s` — https://ambientcg.com/view?id=%s — CC0 — %s (%s)"
               % (asset_id, asset_id, attr, ", ".join(got)))
    print("%-28s ambientCG %s : %s, %.2f Mo" % (asset_id, attr, ", ".join(got), dir_size(out) / 1e6))


# ------------------------------------------------------------------ inventaire

def info_all():
    total = 0
    if os.path.isdir(MODELS_DIR):
        for asset_id in sorted(os.listdir(MODELS_DIR)):
            p = os.path.join(MODELS_DIR, asset_id, asset_id + ".gltf")
            if not os.path.isfile(p):
                continue
            inf = gltf_info(p)
            size = dir_size(os.path.join(MODELS_DIR, asset_id))
            total += size
            flags = [m["name"] + (" DOUBLE" if m["double"] else "") + ("" if m["alpha"] == "OPAQUE" else " " + m["alpha"])
                     for m in inf["materials"]]
            print("%-28s %7d tri  %6.2f Mo  %s" % (asset_id, inf["tris"], size / 1e6, ", ".join(flags)))
    print("modèles : %.1f Mo" % (total / 1e6))


def _managed_texture_imports():
    """Les .import des images rangées par cet outil (modèles Poly Haven, dossiers de textures)."""
    roots = [MODELS_DIR] + [os.path.join(TEX_DIR, d) for d in (os.listdir(TEX_DIR) if os.path.isdir(TEX_DIR) else [])
                            if os.path.isdir(os.path.join(TEX_DIR, d))]
    for r in roots:
        for base, _, files in os.walk(r):
            for n in files:
                if n.lower().endswith((".jpg.import", ".png.import")):
                    yield os.path.join(base, n)


def fix_texture_imports():
    """Textures 3D : compressées en VRAM (S3TC/BPTC, RGTC pour les normales) avec mipmaps.
    (Sans éditeur, la détection « utilisée en 3D » de Godot ne passe jamais : on le règle ici.)
    Rend le nombre de fichiers .import modifiés."""
    changed = 0
    for p in _managed_texture_imports():
        with open(p, encoding="utf-8") as f:
            text = f.read()
        if 'importer="texture"' not in text:
            continue
        if not p.startswith(MODELS_DIR) and "compress/mode=0" not in text:
            continue      # un dossier de textures déjà réglé par quelqu'un : on n'y touche pas
        name = os.path.basename(p).lower()
        normal = "nor_gl" in name or "normalgl" in name or "_normal" in name
        want = {"compress/mode": "2", "mipmaps/generate": "true", "detect_3d/compress_to": "0",
                "compress/normal_map": "1" if normal else "0"}
        if normal:
            want["roughness/mode"] = "0"
        new = text
        for k, v in want.items():
            new = re.sub(r"(?m)^%s=.*$" % re.escape(k), "%s=%s" % (k, v), new)
        if new != text:
            with open(p, "w", encoding="utf-8") as f:
                f.write(new)
            changed += 1
    return changed


def godot_import(godot):
    godot = os.path.abspath(godot)
    if not os.path.isfile(godot):
        raise ValueError("Godot introuvable : %s" % godot)
    for step in (1, 2):
        print("import headless (%d)…" % step, flush=True)
        r = subprocess.run([godot, "--headless", "--path", ROOT, "--import"], timeout=1200,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        lines = [l for l in r.stdout.splitlines() if "ERROR" in l or "WARNING" in l]
        for l in lines[:40]:
            print("  " + l)
        print("import terminé (code %d)" % r.returncode)
        n = fix_texture_imports()
        print("%d réglages de textures corrigés (VRAM + mipmaps)" % n)
        if n == 0:
            break


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("kind", choices=["model", "phtex", "acg", "info", "import"], help="import : seulement l import headless (avec --godot)")
    ap.add_argument("ids", nargs="*")
    ap.add_argument("--res", default=None, help="1k/2k (Poly Haven) ou 1K/2K (ambientCG)")
    ap.add_argument("--godot", default=None, help="binaire Godot : lance l'import headless à la fin")
    a = ap.parse_args()
    errors = 0
    for i in a.ids:
        try:
            if a.kind == "model":
                ph_model(i, a.res or "1k")
            elif a.kind == "phtex":
                ph_texture(i, a.res or "1k")
            elif a.kind == "acg":
                acg_material(i, (a.res or "1K").upper())
        except Exception as e:     # un asset raté n'arrête pas les autres
            errors += 1
            print("ÉCHEC %s : %s" % (i, e), file=sys.stderr)
    if a.kind == "info":
        info_all()
    if a.godot:
        godot_import(a.godot)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
