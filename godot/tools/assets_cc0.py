#!/usr/bin/env python3
"""Téléchargeur d'assets CC0 (Poly Haven, ambientCG, Kenney) pour Don't Play.

À lancer en mode isolé, depuis n'importe où :
    python3 -I godot/tools/assets_cc0.py model old_bed_frame ClassicNightstand_01
    python3 -I godot/tools/assets_cc0.py phtex worn_planks            (texture Poly Haven brute, 1k)
    python3 -I godot/tools/assets_cc0.py acg Carpet012 --res 2K       (matière ambientCG brute)
    python3 -I godot/tools/assets_cc0.py phmat dirty_carpet           (texture Poly Haven « packée »)
    python3 -I godot/tools/assets_cc0.py acgmat Wood008               (matière ambientCG « packée »)
    python3 -I godot/tools/assets_cc0.py decal Leaking001 --res 1K    (décalque ambientCG → decals/acg/)
    python3 -I godot/tools/assets_cc0.py books                        (atlas des couvertures de livres)
    python3 -I godot/tools/assets_cc0.py kenney --src <dossier Audio de Kenney Impact Sounds>
    python3 -I godot/tools/assets_cc0.py kit --godot <Godot>          (toute la liste du lot V1-ASSETS)
    python3 -I godot/tools/assets_cc0.py limits                       (plafonds SIZE_LIMIT dans les .import)
    python3 -I godot/tools/assets_cc0.py import --godot <Godot>       (import headless, puis réglages)
    python3 -I godot/tools/assets_cc0.py pck --godot <Godot> --out <dossier>   (export + pck_report.tsv)
    python3 -I godot/tools/assets_cc0.py info                         (triangles, matières, tailles)
    Options : --cache <dossier> (téléchargements bruts : zips ambientCG, cartes Poly Haven ; par défaut
    $XDG_CACHE_HOME/dontplay_assets), --godot <binaire> (import headless à la fin).

Ce qui est rangé dans le projet :
- Modèles Poly Haven : le .gltf (résolution 1k par défaut), son .bin et ses textures, rangés dans
  godot/assets/models/polyhaven/<id>/ en gardant les chemins relatifs que le .gltf attend
  (« textures/<id>_diff_1k.jpg », « <id>.bin »). Le .gltf est enregistré sous « <id>.gltf ».
- Textures brutes (phtex, acg) : godot/assets/textures/<id>/<id>_{diff,nor_gl,rough,ao}_<res>.jpg ou
  <id>_{Color,NormalGL,Roughness,AmbientOcclusion}.jpg (lues par Surfaces.pbr_acg).
- Matières « packées » (phmat, acgmat ; convention de Surfaces.pbr) : godot/assets/textures/<id>/
  <id>_albedo.jpg (ou <id>_albedo.png en RGBA quand la matière a une carte d'opacité : scotch, cartons),
  <id>_normal_gl.jpg (normale OpenGL, Y vers le haut), <id>_orm.jpg (R = occlusion, G = rugosité,
  B = métal ; 1, rugosité, 0 quand une carte manque). Sources en 1k ; le plafond SIZE_LIMIT réduit à l'import.
- Décalques ambientCG (decal) : godot/assets/decals/acg/<Id>_albedo.png (RGBA : Color + Opacity),
  <Id>_normal.png (NormalGL), <Id>_orm.png (R = 1, G = rugosité, B = 0), à la résolution demandée.
- Livres (books) : godot/assets/textures/books/covers_0.jpg, covers_1.jpg (atlas 2048², 4 × 6 cases de
  512 × 341), covers.json (rectangles et disposition dos | tranche | plat), book_hardcover_01_{diff,nor_gl,
  arm}.jpg (pages et toile de base, normale et ARM du livre relié de Poly Haven).
- Sons Kenney (kenney) : godot/assets/audio/kenney/<nom>.ogg (copiés tels quels de l'archive CC0).
- Idempotent : un fichier déjà là avec la bonne somme MD5 (Poly Haven) ou la bonne taille n'est pas
  re-téléchargé. Chaque asset est ajouté (une ligne, une seule fois) à godot/assets/ASSETS_CC0.md ; la
  table des plafonds y est réécrite entre deux marques.

Plafonds de texture (SIZE_LIMIT, écrit dans process/size_limit des .import par fix_texture_imports) : une
carte 1k coûte 0,7 Mo dans le pck (1,4 Mo pour une normale), quelle que soit la taille du JPG ; règle :
1024 pour les meubles, 512 pour les objets de 10 à 50 cm, 256 sous 10 cm.

Sécurité : les fichiers téléchargés sont des données. Rien n'est exécuté ; seuls des hôtes connus
sont contactés (https uniquement) ; les chemins venus du réseau sont validés (pas de « .. », pas de
chemin absolu) ; seuls les membres image des zip sont lus (en mémoire) ; pas de shell (Godot passe
par subprocess avec une liste d'arguments). Le traitement d'image (PIL, numpy) ne sert qu'à phmat,
acgmat, decal et books.
"""

import argparse
import hashlib
import io
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))   # .../godot
MODELS_DIR = os.path.join(ROOT, "assets", "models", "polyhaven")
TEX_DIR = os.path.join(ROOT, "assets", "textures")
BOOKS_DIR = os.path.join(TEX_DIR, "books")
DECAL_DIR = os.path.join(ROOT, "assets", "decals", "acg")
KENNEY_DIR = os.path.join(ROOT, "assets", "audio", "kenney")
LEDGER = os.path.join(ROOT, "assets", "ASSETS_CC0.md")
ALLOWED_HOSTS = {"api.polyhaven.com", "dl.polyhaven.org", "cdn.polyhaven.com", "ambientcg.com",
                 "acg-download.struffelproductions.com"}
UA = "dontplay-assets/1.1 (CC0 asset fetcher)"
ID_RE = re.compile(r"^[A-Za-z0-9_\-]{1,80}$")
MAX_FILE = 80 * 1024 * 1024
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache"),
                     "dontplay_assets")

# ------------------------------------------------------------------ listes fermées du lot V1-ASSETS

## Modèles Poly Haven déjà livrés (0.3.3) qui sont de petits objets : plafonnés à 512 px.
SMALL_SHIPPED = {
    "bleach_bottle": 512, "drain_cleaner": 512, "plunger": 512, "jug_01": 512, "wall_clock": 512,
    "potted_plant_04": 512, "wicker_basket_02": 512, "cardboard_box_01": 512, "boombox": 512,
    "vintage_suitcase": 512, "painted_wooden_stool": 512,
}

## Modèles Poly Haven du lot (glTF 1k) et leur plafond : 1024 meubles, 512 objets de 10 à 50 cm, 256 sous 10 cm.
KIT_MODELS = {
    "television_02": 1024, "small_wooden_table_01": 1024,
    "alarm_clock_01": 512, "postcard_set_01": 512, "portable_cassette_player": 512, "gamepad": 512,
    "throw_pillows_01": 512, "hanging_picture_frame_02": 512, "hanging_picture_frame_03": 512,
    "brass_vase_03": 512, "wooden_bowl_02": 512, "lightbulb_01": 256, "round_spectacles": 512,
    "rubber_duck_toy": 512, "medical_box": 512, "multi_cleaner_bottle": 512, "tea_set_01": 512,
    "antique_ceramic_vase_01": 512, "ceramic_vase_02": 512, "horse_statue_01": 512, "wooden_crate_01": 512,
    "plastic_crate_01": 512, "Lantern_01": 512, "classic_laptop": 512, "retro_multimeter": 512,
    "circuit_board": 512, "vintage_stapler": 512, "clipboard": 512, "magnifying_glass_01": 512,
    "stationery_supplies": 512, "office_notepads": 512, "binder_notebook": 512, "screwdriver": 256,
    "measuring_tape_01": 256, "book_encyclopedia_set_01": 512, "vintage_oil_lamp": 512,
    "vintage_pocket_watch": 256, "mantel_clock_01": 512, "standing_picture_frame_02": 512,
}

## Matières ambientCG « packées » (assets/textures/<Id>/) et leur plafond.
KIT_ACG = {
    "Wood008": 1024, "Plastic004": 1024, "Plastic013B": 1024, "Porcelain001": 1024, "Metal049B": 1024,
    "Metal046B": 1024, "PaintedMetal010": 1024, "PaintedPlaster012": 1024, "CardboardSet001": 1024,
    "Wallpaper002B": 1024,
    "Leather014": 512, "Cork003": 512, "Tape004": 512, "Paper001": 512, "Paper002": 512,
}

## Textures Poly Haven « packées » (assets/textures/<id>/) et leur plafond.
KIT_PHTEX = {
    "ceiling_interior": 1024, "bark_brown_02": 1024,
    "dirty_carpet": 512, "velour_velvet": 512, "rough_linen": 512, "cotton_jersey": 512, "terry_cloth": 512,
    "curly_teddy_natural": 512, "quatrefoil_jacquard_fabric": 512,
}

## Décalques ambientCG (assets/decals/acg/) et leur résolution.
KIT_DECALS = {
    "Leaking001": 1024, "Leaking003": 1024, "Leaking005": 1024, "Leaking007": 1024,
    "Leaking002": 512, "Leaking009": 512, "SurfaceImperfections005": 512, "SurfaceImperfections006": 512,
    "SurfaceImperfections009": 512, "SurfaceImperfections010": 512, "SurfaceImperfections014": 512,
    "SurfaceImperfections017": 512, "Fingerprints001": 512, "Fingerprints004": 512, "Smear002": 512,
    "Smear005": 512, "Scratches001": 512, "Scratches004": 512, "Rust001": 512,
}

## Sons de Kenney Impact Sounds (CC0) copiés dans assets/audio/kenney/.
KENNEY_SOUNDS = (["footstep_concrete_%03d" % i for i in range(5)] + ["footstep_carpet_003", "footstep_carpet_004"]
                 + ["impactPlank_medium_%03d" % i for i in range(5)] + ["impactSoft_medium_%03d" % i for i in range(3)]
                 + ["impactWood_light_%03d" % i for i in range(3)] + ["impactTin_medium_%03d" % i for i in range(3)])
KENNEY_SRC_GUESS = ("kenney_impactsounds/Audio",)

## Plafond de chaque dossier géré (modèles, matières) : écrit dans process/size_limit.
SIZE_LIMIT = {}
SIZE_LIMIT.update(SMALL_SHIPPED)
SIZE_LIMIT.update(KIT_MODELS)
SIZE_LIMIT.update(KIT_ACG)
SIZE_LIMIT.update(KIT_PHTEX)

# ------------------------------------------------------------------ réseau, fichiers


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


def check_id(asset_id):
    if not ID_RE.match(asset_id):
        raise ValueError("identifiant refusé : %r" % asset_id)


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


def cached(url, name, want_md5=None, limit=MAX_FILE):
    """Téléchargement brut gardé dans le cache (hors du projet) : rend les octets."""
    dest = os.path.join(CACHE, safe_rel(name))
    if already(dest, want_md5):
        with open(dest, "rb") as f:
            return f.read()
    data = fetch(url, limit)
    if want_md5 and md5(data) != want_md5:
        raise ValueError("MD5 faux pour %s" % url)
    save(dest, data)
    return data


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
    begin = text.find(LIMITS_BEGIN)
    if begin >= 0:              # les lignes d'assets restent avant la table des plafonds
        head, tail = text[:begin].rstrip("\n") + "\n", text[begin:]
        text = head + line + "\n\n" + tail
    else:
        if not text.endswith("\n"):
            text += "\n"
        text += line + "\n"
    with open(LEDGER, "w", encoding="utf-8") as f:
        f.write(text)


LIMITS_BEGIN = "<!-- plafonds : début (écrit par tools/assets_cc0.py limits) -->"
LIMITS_END = "<!-- plafonds : fin -->"


def ledger_limits():
    """Réécrit, à la fin de ASSETS_CC0.md, la table des plafonds de texture (SIZE_LIMIT)."""
    if not os.path.isfile(LEDGER):
        return
    with open(LEDGER, encoding="utf-8") as f:
        text = f.read()
    rows = []
    for title, table in (("modèles déjà livrés (petits objets)", SMALL_SHIPPED), ("modèles du lot V1-ASSETS", KIT_MODELS),
                         ("matières ambientCG", KIT_ACG), ("textures Poly Haven", KIT_PHTEX)):
        by = {}
        for k, v in table.items():
            by.setdefault(v, []).append(k)
        for v in sorted(by, reverse=True):
            rows.append("- %s, %d px : %s" % (title, v, ", ".join("`%s`" % k for k in sorted(by[v], key=str.lower))))
    block = (LIMITS_BEGIN + "\n## Plafonds de texture (process/size_limit)\n\n"
             "Une carte 1k coûte 0,7 Mo dans le pck (1,4 Mo pour une normale) quelle que soit la taille du JPG : "
             "les sources restent en 1k sur le disque, l'import les réduit (règle : 1024 pour les meubles, 512 pour "
             "les objets de 10 à 50 cm, 256 sous 10 cm). Les décalques sont écrits directement à leur taille.\n\n"
             + "\n".join(rows) + "\n" + LIMITS_END + "\n")
    i, j = text.find(LIMITS_BEGIN), text.find(LIMITS_END)
    if i >= 0 and j > i:
        text = text[:i] + block + text[j + len(LIMITS_END):].lstrip("\n")
    else:
        text = text.rstrip("\n") + "\n\n" + block
    with open(LEDGER, "w", encoding="utf-8") as f:
        f.write(text)


def dir_size(d):
    t = 0
    for base, _, files in os.walk(d):
        for n in files:
            if not n.endswith(".import"):
                t += os.path.getsize(os.path.join(base, n))
    return t


def _authors(info):
    a = info.get("authors") or {}
    return ", ".join(sorted(a)) if a else "?"


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
    return {"tris": tris, "materials": mats, "nodes": [n.get("name", "") for n in nodes]}


# ------------------------------------------------------------------ Poly Haven : modèles

def ph_model(asset_id, res="1k"):
    check_id(asset_id)
    files = fetch_json("https://api.polyhaven.com/files/%s" % asset_id)
    gl = files.get("gltf", {})
    if res not in gl:
        raise ValueError("%s : pas de glTF en %s (dispo : %s)" % (asset_id, res, list(gl)))
    entry = gl[res]["gltf"]
    out = os.path.join(MODELS_DIR, asset_id)
    os.makedirs(out, exist_ok=True)
    n_new = 0
    # dépendances d'abord, le .gltf en dernier : un import lancé entre-temps ne voit pas de modèle incomplet
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
    try:
        meta = fetch_json("https://api.polyhaven.com/info/%s" % asset_id)
    except Exception:          # l'auteur n'est qu'une information de plus
        meta = {}
    dims = meta.get("dimensions") or []
    dim_txt = (" ; %s cm" % " × ".join("%.0f" % (d / 10.0) for d in dims)) if len(dims) == 3 else ""
    lim = SIZE_LIMIT.get(asset_id, 0)
    ledger_add("ph:" + asset_id, "- modèle Poly Haven `ph:%s` — « %s » par %s — https://polyhaven.com/a/%s — CC0 — "
               "glTF %s (%s), %d triangles, %.1f Mo%s%s"
               % (asset_id, meta.get("name", asset_id), _authors(meta), asset_id, res, entry["url"], info["tris"],
                  size / 1e6, dim_txt, (" ; textures plafonnées à %d px" % lim) if lim and lim < 1024 else ""))
    flags = ["%s%s%s" % (m["name"], " DOUBLE" if m["double"] else "", "" if m["alpha"] == "OPAQUE" else " " + m["alpha"])
             for m in info["materials"]]
    print("%-28s %7d tri  %6.2f Mo  %d nouveaux fichiers  matières : %s" % (asset_id, info["tris"], size / 1e6, n_new, ", ".join(flags)))


# ------------------------------------------------------------------ Poly Haven : textures

def ph_texture(asset_id, res="1k"):
    """Texture brute (noms de Poly Haven), comme en 0.3.3."""
    check_id(asset_id)
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


def _img(data, mode=None):
    from PIL import Image
    im = Image.open(io.BytesIO(data))
    im.load()
    return im.convert(mode) if mode else im


def _save_jpg(im, dest, quality=94):
    # 4:4:4 (pas de sous-échantillonnage de la chrominance) : les canaux packés ne se mélangent pas
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=quality, subsampling=0, optimize=True)
    save(dest, buf.getvalue())


def _save_png(im, dest):
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    save(dest, buf.getvalue())


def _orm(size, ao=None, rough=None, metal=None, rough_default=255):
    """ORM packé : R = occlusion (blanc si absente), G = rugosité, B = métal (noir si absent)."""
    from PIL import Image
    chans = []
    for im, default in ((ao, 255), (rough, rough_default), (metal, 0)):
        if im is None:
            chans.append(Image.new("L", size, default))
        else:
            im = im.convert("L")
            chans.append(im if im.size == size else im.resize(size, Image.LANCZOS))
    return Image.merge("RGB", chans)


def ph_material(asset_id, res="1k"):
    """Texture Poly Haven packée pour Surfaces.pbr : <id>_albedo.jpg, <id>_normal_gl.jpg, <id>_orm.jpg (ARM)."""
    check_id(asset_id)
    files = fetch_json("https://api.polyhaven.com/files/%s" % asset_id)

    def get(key):
        e = files.get(key, {}).get(res, {}).get("jpg")
        if not e:
            return None
        return cached(e["url"], "polyhaven/%s/%s_%s_%s.jpg" % (asset_id, asset_id, key, res), e.get("md5"))

    diff, nor, arm = get("Diffuse"), get("nor_gl"), get("arm")
    if diff is None or nor is None:
        raise ValueError("%s : pas de diff ou de nor_gl en %s" % (asset_id, res))
    out = os.path.join(TEX_DIR, asset_id)
    base = os.path.join(out, asset_id)
    save(base + "_albedo.jpg", diff)         # octets d'origine : pas de recompression
    save(base + "_normal_gl.jpg", nor)
    if arm is not None:
        save(base + "_orm.jpg", arm)         # ARM de Poly Haven = occlusion, rugosité, métal : déjà l'ORM
    else:
        size = _img(diff).size
        ao, rough, metal = get("AO"), get("Rough"), get("Metal")
        _save_jpg(_orm(size, _img(ao) if ao else None, _img(rough) if rough else None, _img(metal) if metal else None),
                  base + "_orm.jpg")
    try:
        meta = fetch_json("https://api.polyhaven.com/info/%s" % asset_id)
    except Exception:
        meta = {}
    dims = meta.get("dimensions") or []
    real = (" ; motif de %s m" % ("%.2f" % (dims[0] / 1000.0)).replace(".", ",")) if dims else ""
    lim = SIZE_LIMIT.get(asset_id, 0)
    ledger_add("phmat:" + asset_id, "- texture Poly Haven `phmat:%s` — « %s » par %s — https://polyhaven.com/a/%s — CC0 — "
               "%s jpg (diff, nor_gl, arm) → textures/%s/%s_{albedo,normal_gl,orm}.jpg%s%s"
               % (asset_id, meta.get("name", asset_id), _authors(meta), asset_id, res, asset_id, asset_id, real,
                  (" ; plafond %d px" % lim) if lim and lim < 1024 else ""))
    print("%-28s Poly Haven packée %s%s, %.2f Mo" % (asset_id, res, real, dir_size(out) / 1e6))


# ------------------------------------------------------------------ ambientCG

ACG_MAPS = ("Color", "NormalGL", "Roughness", "AmbientOcclusion")


def _acg_zip(asset_id, res="1K"):
    """Le zip « <res>-JPG » d'un asset ambientCG (matière, atlas ou décalque), gardé dans le cache.
    Rend (ZipFile, attribut, métadonnées de l'asset)."""
    check_id(asset_id)
    q = urllib.parse.urlencode({"id": asset_id, "include": "downloadData"})
    d = fetch_json("https://ambientcg.com/api/v2/full_json?" + q)
    assets = [a for a in d.get("foundAssets", []) if a.get("assetId") == asset_id]
    if not assets:
        raise ValueError("ambientCG : %s introuvable" % asset_id)
    dls = assets[0]["downloadFolders"]["default"]["downloadFiletypeCategories"]["zip"]["downloads"]
    attr = "%s-JPG" % res
    dl = [x for x in dls if x.get("attribute") == attr]
    if not dl:
        raise ValueError("ambientCG : %s sans %s" % (asset_id, attr))
    data = cached(dl[0]["downloadLink"], "ambientcg/%s_%s.zip" % (asset_id, attr), None, 200 * 1024 * 1024)
    if dl[0].get("size") and len(data) != dl[0]["size"]:
        os.remove(os.path.join(CACHE, "ambientcg/%s_%s.zip" % (asset_id, attr)))
        raise ValueError("ambientCG : taille inattendue pour %s (cache effacé, relancer)" % asset_id)
    return zipfile.ZipFile(io.BytesIO(data)), attr, assets[0]


def _acg_read(z, asset_id, attr, m):
    name = "%s_%s_%s.jpg" % (asset_id, attr, m)
    try:
        info = z.getinfo(name)
    except KeyError:
        return None
    if info.file_size > MAX_FILE:
        raise ValueError("image trop grosse dans le zip : %s" % name)
    return z.read(info)


def acg_material(asset_id, res="1K"):
    """Matière brute (noms d'ambientCG), comme en 0.3.3 : lue par Surfaces.pbr_acg."""
    z, attr, _ = _acg_zip(asset_id, res)
    out = os.path.join(TEX_DIR, asset_id)
    got = []
    for m in ACG_MAPS:
        data = _acg_read(z, asset_id, attr, m)
        if data is not None:
            save(os.path.join(out, "%s_%s.jpg" % (asset_id, m)), data)
            got.append(m)
    if "Color" not in got:
        raise ValueError("ambientCG : aucune image extraite pour %s" % asset_id)
    ledger_add("acg:" + asset_id, "- matière ambientCG `acg:%s` — https://ambientcg.com/view?id=%s — CC0 — %s (%s)"
               % (asset_id, asset_id, attr, ", ".join(got)))
    print("%-28s ambientCG %s : %s, %.2f Mo" % (asset_id, attr, ", ".join(got), dir_size(out) / 1e6))


def _acg_dims(meta):
    x, y = meta.get("dimensionX") or 0, meta.get("dimensionY") or 0
    return (" ; %d × %d cm réels" % (x, y)) if x and y else ""


def acg_pack(asset_id, res="1K"):
    """Matière ambientCG packée pour Surfaces.pbr : <Id>_albedo.jpg (.png RGBA s'il y a une opacité),
    <Id>_normal_gl.jpg, <Id>_orm.jpg (R = AmbientOcclusion ou 1, G = Roughness, B = Metalness ou 0)."""
    from PIL import Image
    z, attr, meta = _acg_zip(asset_id, res)
    color = _acg_read(z, asset_id, attr, "Color")
    nor = _acg_read(z, asset_id, attr, "NormalGL")
    if color is None or nor is None:
        raise ValueError("ambientCG : %s sans Color ou NormalGL" % asset_id)
    out = os.path.join(TEX_DIR, asset_id)
    base = os.path.join(out, asset_id)
    col = _img(color, "RGB")
    opacity = _acg_read(z, asset_id, attr, "Opacity")
    if opacity is not None:
        a = _img(opacity, "L")
        if a.size != col.size:
            a = a.resize(col.size, Image.LANCZOS)
        rgba = col.copy()
        rgba.putalpha(a)
        _save_png(rgba, base + "_albedo.png")
        albedo = "albedo.png (RGBA)"
    else:
        save(base + "_albedo.jpg", color)
        albedo = "albedo.jpg"
    save(base + "_normal_gl.jpg", nor)
    maps = {}
    for m in ("AmbientOcclusion", "Roughness", "Metalness"):
        b = _acg_read(z, asset_id, attr, m)
        maps[m] = _img(b, "L") if b is not None else None
    _save_jpg(_orm(col.size, maps["AmbientOcclusion"], maps["Roughness"], maps["Metalness"]), base + "_orm.jpg")
    srcs = ["Color"] + (["Opacity"] if opacity is not None else []) + ["NormalGL"] + [m for m in maps if maps[m] is not None]
    lim = SIZE_LIMIT.get(asset_id, 0)
    ledger_add("acgmat:" + asset_id, "- matière ambientCG `acgmat:%s` — « %s » — https://ambientcg.com/view?id=%s — CC0 — "
               "%s (%s) → textures/%s/%s_{%s, normal_gl.jpg, orm.jpg}%s%s"
               % (asset_id, meta.get("displayName", asset_id), asset_id, attr, ", ".join(srcs), asset_id, asset_id,
                  albedo, _acg_dims(meta), (" ; plafond %d px" % lim) if lim and lim < 1024 else ""))
    print("%-28s ambientCG packée %s : %s%s, %.2f Mo" % (asset_id, attr, ", ".join(srcs), _acg_dims(meta), dir_size(out) / 1e6))


def acg_decal(asset_id, size=1024):
    """Décalque ambientCG pour Decal (Wear.decal, lot V1-USURE) : dans assets/decals/acg/,
    <Id>_albedo.png (RGBA : Color + Opacity), <Id>_normal.png (NormalGL), <Id>_orm.png (R = 1,
    G = Roughness, B = 0), à « size » px. Sans carte de rugosité (cernes de SurfaceImperfections) :
    G = 0,6 + 0,3 × opacité (un dépôt sec est plus mat que le vernis qu'il tache)."""
    from PIL import Image
    z, attr, meta = _acg_zip(asset_id, "1K" if size <= 1024 else "2K")
    color, opacity, nor = (_acg_read(z, asset_id, attr, m) for m in ("Color", "Opacity", "NormalGL"))
    rough = _acg_read(z, asset_id, attr, "Roughness")
    if color is None or (opacity is None and rough is None):
        raise ValueError("ambientCG : %s sans Color ou Opacity (pas un décalque)" % asset_id)
    col = _img(color, "RGB")
    op_note = "Opacity"
    if opacity is not None:
        a = _img(opacity, "L")
    else:
        # traînée couvrante (Smear002 : pas de carte d'opacité, couleur presque noire faite pour moduler
        # une rugosité) : l'opacité suit la rugosité, étalée entre ses centiles 2 et 99,5 puis adoucie
        # (le fond lisse devient transparent, plafond 0,6) ; la couleur devient un dépôt gris clair (gras,
        # savon) qui garde le dessin des traînées
        import numpy as np
        from PIL import Image as _I
        r = np.asarray(_img(rough, "L"), np.float32)
        lo, hi = np.percentile(r, 2.0), np.percentile(r, 99.5)
        a = _I.fromarray((((r - lo) / max(1.0, hi - lo)).clip(0.0, 1.0) ** 1.3 * 0.6 * 255.0).astype(np.uint8), "L")
        c = np.asarray(col, np.float32)
        clo, chi = np.percentile(c, 2.0), np.percentile(c, 99.5)
        c = 150.0 + 70.0 * ((c - clo) / max(1.0, chi - clo)).clip(0.0, 1.0)
        col = _I.fromarray(c.astype(np.uint8), "RGB")
        op_note = "opacité tirée de la rugosité, couleur éclaircie"
    target = (size, size * col.size[1] // col.size[0])
    col = col.resize(target, Image.LANCZOS) if col.size != target else col
    a = a.resize(target, Image.LANCZOS) if a.size != target else a
    rgba = col.copy()
    rgba.putalpha(a)
    base = os.path.join(DECAL_DIR, asset_id)
    _save_png(rgba, base + "_albedo.png")
    if nor is not None:
        n = _img(nor, "RGB")
        _save_png(n.resize(target, Image.LANCZOS) if n.size != target else n, base + "_normal.png")
    else:
        _save_png(Image.new("RGB", target, (128, 128, 255)), base + "_normal.png")
    if rough is not None:
        r = _img(rough, "L")
        r = r.resize(target, Image.LANCZOS) if r.size != target else r
        rough_note = "Roughness"
    else:
        r = a.point(lambda v: int(round(255 * (0.6 + 0.3 * v / 255.0))))
        rough_note = "rugosité tirée de l'opacité"
    _save_png(_orm(target, None, r, None), base + "_orm.png")
    ledger_add("acgdecal:" + asset_id, "- décalque ambientCG `acgdecal:%s` — « %s » — https://ambientcg.com/view?id=%s — CC0 — "
               "%s (Color, %s, NormalGL, %s) → decals/acg/%s_{albedo,normal,orm}.png en %d px%s"
               % (asset_id, meta.get("displayName", asset_id), asset_id, attr, op_note, rough_note, asset_id, size, _acg_dims(meta)))
    print("%-28s décalque %d px (%s)%s" % (asset_id, size, rough_note, _acg_dims(meta)))


# ------------------------------------------------------------------ livres (decorative_book_set_01)

BOOK_SET = "decorative_book_set_01"
CELL_W, CELL_H, COLS, ROWS = 512, 341, 4, 6        # 24 couvertures par atlas de 2048²
## Couvertures réelles gardées (tranche sobre, sans texte étranger lisible à 512 px) : relié cuir rouge,
## cuir brun à fers dorés, cuir rouge, toile jaune à étiquette, et un titre français (La culture de la framboise).
BOOK_REAL = ["book_hardcover_01_cover51", "book_hardcover_01_cover08", "book_hardcover_01_cover87",
             "book_hardcover_01_cover47"]
## Couvertures dont la tranche porte un titre anglais (en relief ou sur l'étiquette) : la tranche est lissée
## (filtre médian) jusqu'à ce que le texte disparaisse, la peau et les filets restent.
BOOK_CLEAN_SPINE = {"book_hardcover_01_cover08": 17, "book_hardcover_01_cover87": 15}
## Grain de cuir photographique pris dans une zone sans décor de la couverture 51 (cuir brun patiné).
BOOK_LEATHER = ("book_hardcover_01_cover51", (110, 150, 410, 560))
## Reliures générées sur la toile de book_hardcover_01_diff : teinte, matière, décor de tranche, décor du plat.
## (couleurs de reliures françaises anciennes ; titres d'œuvres du domaine public, en lettres dorées)
BOOK_CLOTH = [
    # teinte (R, G, B), grain (« toile », « cuir », « chagrin »), tranche, plat, titre de tranche
    ((92, 24, 26), "cuir", "nerfs", "filets", "HUGO|LES MISÉRABLES|I"),
    ((92, 24, 26), "cuir", "nerfs", "filets", "HUGO|LES MISÉRABLES|II"),
    ((28, 44, 32), "toile", "bandes", "nu", "ZOLA|GERMINAL"),
    ((24, 30, 52), "toile", "etiquette", "nu", "BALZAC|EUGÉNIE GRANDET"),
    ((58, 36, 22), "cuir", "nerfs", "fers", "MAUPASSANT|CONTES"),
    ((40, 24, 18), "chagrin", "nerfs", "filets", "FLAUBERT|MADAME BOVARY"),
    ((120, 92, 52), "toile", "bandes", "nu", "JULES VERNE|L'ÎLE MYSTÉRIEUSE"),
    ((30, 30, 30), "toile", "etiquette", "nu", "DUMAS|LES TROIS MOUSQUETAIRES"),
    ((70, 18, 32), "chagrin", "nerfs", "filets", "STENDHAL|LE ROUGE ET LE NOIR"),
    ((44, 52, 40), "toile", "bandes", "nu", "LA FONTAINE|FABLES"),
    ((96, 66, 40), "cuir", "nerfs", "fers", "VOLTAIRE|CANDIDE"),
    ((22, 36, 60), "toile", "bandes", "nu", "ENCYCLOPÉDIE|TOME III"),
    ((22, 36, 60), "toile", "bandes", "nu", "ENCYCLOPÉDIE|TOME IV"),
    ((22, 36, 60), "toile", "bandes", "nu", "ENCYCLOPÉDIE|TOME V"),
    ((110, 30, 22), "toile", "etiquette", "nu", "DICTIONNAIRE|A – K"),
    ((110, 30, 22), "toile", "etiquette", "nu", "DICTIONNAIRE|L – Z"),
    ((52, 58, 66), "toile", "simple", "nu", "RADIO|ÉLECTRICITÉ"),
    ((60, 48, 30), "toile", "simple", "nu", "ÉLECTRONIQUE|PRATIQUE"),
    ((38, 40, 44), "toile", "simple", "nu", "MATHÉMATIQUES|TOME II"),
    ((80, 70, 50), "toile", "simple", "nu", "HISTOIRE|DE FRANCE"),
    ((66, 22, 22), "cuir", "nerfs", "fers", "RACINE|THÉÂTRE"),
    ((34, 26, 20), "chagrin", "nerfs", "filets", "MOLIÈRE|ŒUVRES"),
    ((48, 60, 34), "toile", "bandes", "nu", "BOTANIQUE"),
    ((102, 84, 60), "toile", "simple", "nu", "ATLAS"),
    ((18, 18, 20), "chagrin", "nerfs", "filets", "PASCAL|PENSÉES"),
    ((84, 40, 26), "cuir", "nerfs", "fers", "MONTAIGNE|ESSAIS"),
    ((40, 48, 72), "toile", "etiquette", "nu", "LAMARTINE|POÉSIES"),
    ((90, 78, 40), "toile", "bandes", "nu", "CHIMIE"),
    ((58, 22, 40), "toile", "simple", "nu", "MÉMOIRES"),
    ((70, 64, 58), "toile", "simple", "nu", ""),
    ((32, 50, 46), "toile", "bandes", "nu", ""),
    ((112, 48, 30), "cuir", "nerfs", "filets", ""),
    ((26, 26, 34), "toile", "simple", "nu", ""),
    ((126, 108, 76), "toile", "simple", "nu", ""),
    ((76, 30, 30), "toile", "bandes", "nu", ""),
    ((46, 34, 26), "cuir", "nerfs", "nu", ""),
    ((64, 72, 80), "toile", "simple", "nu", ""),
    ((100, 52, 28), "toile", "etiquette", "nu", ""),
    ((36, 58, 30), "chagrin", "nerfs", "filets", ""),
    ((140, 120, 92), "toile", "simple", "nu", ""),
    ((54, 40, 60), "toile", "bandes", "nu", ""),
    ((84, 84, 74), "toile", "simple", "nu", ""),
    ((24, 22, 20), "toile", "bandes", "nu", ""),
    ((60, 26, 20), "cuir", "nerfs", "filets", "CORNEILLE|THÉÂTRE"),
]
FONT_CANDIDATES = ("/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf",
                   "/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf")


def _book_files():
    files = fetch_json("https://api.polyhaven.com/files/%s" % BOOK_SET)

    def get(key):
        e = files[key]["1k"]["jpg"]
        return cached(e["url"], "polyhaven/%s/%s_1k.jpg" % (BOOK_SET, key), e.get("md5"))
    return get


def _book_layout(get):
    """Rangées des pages et de la couverture dans la disposition 1024² de book_hardcover_01 (masques 01 et
    02), et colonnes de la tranche (bords de la carte du masque 01)."""
    import numpy as np
    m1 = np.asarray(_img(get("book_hardcover_01_mask01"), "L"), dtype=np.float32)
    m2 = np.asarray(_img(get("book_hardcover_01_mask02"), "L"), dtype=np.float32)
    h = m1.shape[0]
    cover_top = int(np.argmax(m1.mean(axis=1) > 20))
    pages_bottom = int(np.argmax(m2.mean(axis=1) < 128))
    band = m1[cover_top + 150:h - 100].mean(axis=0)
    mid = band.shape[0] // 2
    left = int(np.argmax(band[mid - 150:mid]) + mid - 150)
    right = int(np.argmax(band[mid:mid + 150]) + mid)
    return {"size": h, "cover_top": cover_top, "pages_bottom": pages_bottom, "spine": (left, right)}


def _fit_font(draw, text, max_w, max_h, start):
    from PIL import ImageFont
    path = next((p for p in FONT_CANDIDATES if os.path.isfile(p)), None)
    size = start
    while size > 6:
        font = ImageFont.truetype(path, size) if path else ImageFont.load_default()
        box = draw.textbbox((0, 0), text, font=font)
        if box[2] - box[0] <= max_w and box[3] - box[1] <= max_h:
            return font, box
        size -= 1
    font = ImageFont.truetype(path, 6) if path else ImageFont.load_default()
    return font, draw.textbbox((0, 0), text, font=font)


def _gilt(img, mask, strength=1.0):
    """Dorure : or patiné posé à travers un masque (L), avec un léger relief sombre en dessous."""
    from PIL import Image, ImageChops, ImageFilter
    w, h = img.size
    shadow = mask.filter(ImageFilter.GaussianBlur(1.2))
    dark = Image.new("RGB", (w, h), (12, 8, 4))
    img.paste(dark, (0, 0), shadow.point(lambda v: int(v * 0.35 * strength)))
    gold = Image.new("RGB", (w, h), (204, 162, 84))
    # usure de la dorure : un bruit grossier qui la ternit par endroits
    import random
    rnd = random.Random(w * 7 + h)
    noise = Image.new("L", (w // 8 + 1, h // 8 + 1))
    noise.putdata([rnd.randint(150, 255) for _ in range(noise.size[0] * noise.size[1])])
    noise = noise.resize((w, h), Image.BICUBIC)
    img.paste(gold, (0, 0), ImageChops.multiply(mask, noise).point(lambda v: int(v * strength)))


def _make_binding(spec, base_cover, layout, idx, leather=None):
    """Une reliure générée (1024 × 693, disposition dos | tranche | plat de book_hardcover_01)."""
    from PIL import Image, ImageDraw, ImageFilter, ImageOps
    import numpy as np
    tint, grain, spine_style, plat_style, title = spec
    w, h = base_cover.size
    lum = np.asarray(ImageOps.grayscale(base_cover), dtype=np.float32) / 255.0
    lum = lum / max(1e-3, float(np.median(lum)))           # 1 = toile moyenne, < 1 dans les bords de carte
    rng = np.random.default_rng(1000 + idx)
    if grain in ("cuir", "chagrin") and leather is not None:
        # grain photographique (cuir 51 en miroir) : rapport au flou, contraste plus fort pour le chagrin
        ox, oy = int(rng.integers(0, leather.shape[1])), int(rng.integers(0, leather.shape[0]))
        tile = np.roll(np.roll(leather, -oy, axis=0), -ox, axis=1)
        reps = (h // tile.shape[0] + 1, w // tile.shape[1] + 1)
        big = np.block([[tile if (i + j) % 2 == 0 else tile[::-1, ::-1] for j in range(reps[1])] for i in range(reps[0])])
        lum = lum * (1.0 + (big[:h, :w] - 1.0) * (1.4 if grain == "chagrin" else 1.0))
    col = np.empty((h, w, 3), dtype=np.float32)
    for c in range(3):
        col[..., c] = tint[c] * lum
    # usure : les coins et les bords de la tranche pâlissent (le frottement de la main)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    s0, s1 = layout["spine"]
    edge = np.exp(-np.minimum.reduce([xx, w - 1 - xx, yy, h - 1 - yy]) / 18.0)
    hinge = np.exp(-np.minimum(np.abs(xx - s0), np.abs(xx - s1)) / 6.0)
    wear = (0.35 * edge + 0.25 * hinge) * (0.6 + 0.4 * rng.random((h, w), dtype=np.float32))
    col = col * (1.0 - wear[..., None] * 0.35) + wear[..., None] * np.array([150, 132, 110], np.float32) * 0.35
    img = Image.fromarray(col.clip(0, 255).astype(np.uint8), "RGB")
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    sw = s1 - s0
    if spine_style == "nerfs":          # nerfs (bourrelets) et filets dorés entre les caissons
        for k in range(5):
            y = int(h * (0.16 + 0.17 * k))
            d.rectangle([s0 + 6, y - 2, s1 - 6, y + 2], fill=255)
            d.line([s0 + 6, y - 8, s1 - 6, y - 8], fill=200, width=1)
            d.line([s0 + 6, y + 8, s1 - 6, y + 8], fill=200, width=1)
    elif spine_style == "bandes":       # deux groupes de filets en tête et en queue
        for y in (int(h * 0.07), int(h * 0.10), int(h * 0.90), int(h * 0.93)):
            d.rectangle([s0 + 4, y - 2, s1 - 4, y + 1], fill=255)
    elif spine_style == "etiquette":    # pièce de titre (cuir plus sombre) bordée d'un filet
        y0, y1 = int(h * 0.16), int(h * 0.36)
        label = Image.new("RGB", (sw - 16, y1 - y0), tuple(int(c * 0.45) for c in tint))
        img.paste(label, (s0 + 8, y0))
        d.rectangle([s0 + 8, y0, s1 - 8, y1], outline=230, width=2)
        for y in (int(h * 0.06), int(h * 0.94)):
            d.rectangle([s0 + 4, y - 1, s1 - 4, y + 1], fill=255)
    else:                               # « simple » : un filet en tête et en queue
        for y in (int(h * 0.05), int(h * 0.95)):
            d.rectangle([s0 + 4, y - 1, s1 - 4, y + 1], fill=220)
    if title:
        parts = title.split("|")
        if spine_style == "nerfs":
            slots = [(int(h * 0.16) + 12, int(h * 0.33) - 12), (int(h * 0.33) + 12, int(h * 0.50) - 12),
                     (int(h * 0.67) + 12, int(h * 0.84) - 12)]
        elif spine_style == "etiquette":
            y0, y1 = int(h * 0.16), int(h * 0.36)
            n = len(parts[:2])
            slots = [(y0 + 10 + k * (y1 - y0 - 20) // n, y0 + 10 + (k + 1) * (y1 - y0 - 20) // n) for k in range(n)]
            if len(parts) > 2:
                slots.append((int(h * 0.42), int(h * 0.50)))
        else:
            slots = [(int(h * 0.14), int(h * 0.24)), (int(h * 0.26), int(h * 0.40)), (int(h * 0.44), int(h * 0.52))]
        for k, text in enumerate(parts[:len(slots)]):
            a, b = slots[k]
            font, box = _fit_font(d, text, sw - 22, b - a, 30)
            words = text.split(" ")
            if box[2] - box[0] > sw - 22 or (len(words) > 1 and box[3] - box[1] < (b - a) / 2.6 and len(text) > 9):
                # titre long : sur deux lignes centrées, de la même taille
                half = (len(words) + 1) // 2
                lines = [" ".join(words[:half]), " ".join(words[half:])]
                lh = (b - a) // 2
                fs = min(_fit_font(d, ln, sw - 22, lh - 2, 26)[0].size for ln in lines)
                for li, ln in enumerate(lines):
                    f2, bx = _fit_font(d, ln, sw - 22, lh - 2, fs)
                    tx = s0 + (sw - (bx[2] - bx[0])) // 2 - bx[0]
                    d.text((tx, a + li * lh + (lh - (bx[3] - bx[1])) // 2 - bx[1]), ln, fill=255, font=f2)
            else:
                tx = s0 + (sw - (box[2] - box[0])) // 2 - box[0]
                d.text((tx, a + (b - a - (box[3] - box[1])) // 2 - box[1]), text, fill=255, font=font)
    if plat_style in ("filets", "fers"):    # encadrement doré (et fleurons) sur les deux plats
        for x0, x1 in ((22, s0 - 22), (s1 + 22, w - 22)):
            d.rectangle([x0, 24, x1, h - 24], outline=210, width=2)
            if plat_style == "fers":
                for cx, cy in ((x0 + 14, 38), (x1 - 14, 38), (x0 + 14, h - 38), (x1 - 14, h - 38)):
                    d.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], outline=220, width=2)
                    d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=220)
    mask = mask.filter(ImageFilter.GaussianBlur(0.6))
    _gilt(img, mask, 0.95)
    return img


def books():
    """Deux atlas de couvertures (4 × 6 cases de 512 × 341) et leurs rectangles, plus la toile, la normale et
    l'ARM de book_hardcover_01 (même disposition 1024² : pages en haut, couverture en bas)."""
    from PIL import Image
    get = _book_files()
    layout = _book_layout(get)
    os.makedirs(BOOKS_DIR, exist_ok=True)
    for key in ("book_hardcover_01_diff", "book_hardcover_01_nor_gl", "book_hardcover_01_arm"):
        save(os.path.join(BOOKS_DIR, key + ".jpg"), get(key))
    diff = _img(get("book_hardcover_01_diff"), "RGB")
    size = layout["size"]
    base_cover = diff.crop((0, layout["cover_top"], size, size))
    import numpy as np
    from PIL import ImageFilter
    s0, s1 = layout["spine"]
    cells = []
    for key in BOOK_REAL:
        im = _img(get(key), "RGB")
        if key in BOOK_CLEAN_SPINE:
            k = s0 * im.size[0] // size, s1 * im.size[0] // size
            box = (k[0] + 8, 0, k[1] - 8, im.size[1])
            strip = im.crop(box).filter(ImageFilter.MedianFilter(BOOK_CLEAN_SPINE[key]))
            noise = np.random.default_rng(7).normal(0, 3.0, (strip.size[1], strip.size[0], 1))
            strip = Image.fromarray((np.asarray(strip, np.float32) + noise).clip(0, 255).astype(np.uint8), "RGB")
            im.paste(strip, box[:2])
        cells.append(({"id": key, "kind": "hardcover", "source": "polyhaven"}, im))
    lk, lbox = BOOK_LEATHER
    lum = np.asarray(_img(get(lk), "L").crop(lbox), np.float32) + 1.0
    blur = np.asarray(Image.fromarray(lum.clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(24)), np.float32) + 1.0
    leather = (lum / blur).clip(0.55, 1.6)
    for i, spec in enumerate(BOOK_CLOTH):
        im = _make_binding(spec, base_cover, layout, i, leather)
        cells.append(({"id": "reliure_%02d" % i, "kind": "hardcover", "source": "generee",
                       "titre": spec[4].replace("|", " / ")}, im))
    per = COLS * ROWS
    n_atlas = (len(cells) + per - 1) // per
    rects = []
    for a in range(n_atlas):
        atlas = Image.new("RGB", (COLS * CELL_W, COLS * CELL_W), (60, 52, 44))
        for k, (meta, im) in enumerate(cells[a * per:(a + 1) * per]):
            cx, cy = (k % COLS) * CELL_W, (k // COLS) * CELL_H
            atlas.paste(im.resize((CELL_W, CELL_H), Image.LANCZOS), (cx, cy))
            r = dict(meta)
            r.update({"atlas": a, "index": len(rects), "rect": [cx / atlas.size[0], cy / atlas.size[1],
                                                                 CELL_W / atlas.size[0], CELL_H / atlas.size[1]]})
            rects.append(r)
        _save_jpg(atlas, os.path.join(BOOKS_DIR, "covers_%d.jpg" % a), 92)
    doc = {
        "atlases": ["res://assets/textures/books/covers_%d.jpg" % a for a in range(n_atlas)],
        "cell_px": [CELL_W, CELL_H], "grid": [COLS, ROWS],
        "layout": {"comment": "couverture dépliée, en fractions de la largeur : dos (4e de couverture) | tranche | plat",
                   "back": [0.0, round(s0 / size, 4)], "spine": [round(s0 / size, 4), round(s1 / size, 4)],
                   "front": [round(s1 / size, 4), 1.0]},
        "base": {"comment": "book_hardcover_01_{diff,nor_gl,arm}.jpg (1024²) : rectangles [x, y, l, h] en UV",
                 "diff": "res://assets/textures/books/book_hardcover_01_diff.jpg",
                 "normal": "res://assets/textures/books/book_hardcover_01_nor_gl.jpg",
                 "arm": "res://assets/textures/books/book_hardcover_01_arm.jpg",
                 "pages_rect": [0.0, 0.0, 1.0, round(layout["pages_bottom"] / size, 4)],
                 "cover_rect": [0.0, round(layout["cover_top"] / size, 4), 1.0, round(1.0 - layout["cover_top"] / size, 4)]},
        "covers": rects,
    }
    save(os.path.join(BOOKS_DIR, "covers.json"), (json.dumps(doc, ensure_ascii=False, indent=1) + "\n").encode("utf-8"))
    ledger_add("phbooks:" + BOOK_SET, "- couvertures Poly Haven `phbooks:%s` — « Decorative Book Set 01 » — "
               "https://polyhaven.com/a/%s — CC0 — 1k jpg : %s ; book_hardcover_01_{diff, nor_gl, arm, mask01, mask02} → "
               "textures/books/covers_0.jpg, covers_1.jpg (atlas 2048², %d couvertures dont %d reliures générées sur la "
               "toile de book_hardcover_01_diff, titres en Liberation Serif, OFL), covers.json, book_hardcover_01_{diff,nor_gl,arm}.jpg"
               % (BOOK_SET, BOOK_SET, ", ".join(k.replace("book_", "") for k in BOOK_REAL), len(rects), len(BOOK_CLOTH)))
    print("livres : %d couvertures dans %d atlas, tranche %d-%d px, couverture à partir de %d px"
          % (len(rects), n_atlas, s0, s1, layout["cover_top"]))


# ------------------------------------------------------------------ sons Kenney

def kenney(src):
    if not src or not os.path.isdir(src):
        raise ValueError("dossier Audio de Kenney Impact Sounds introuvable : %r (option --src)" % src)
    os.makedirs(KENNEY_DIR, exist_ok=True)
    n = 0
    for name in KENNEY_SOUNDS:
        s = os.path.join(src, name + ".ogg")
        with open(s, "rb") as f:
            data = f.read()
        if data[:4] != b"OggS":
            raise ValueError("pas un fichier Ogg : %s" % s)
        dest = os.path.join(KENNEY_DIR, name + ".ogg")
        if not already(dest, md5(data)):
            save(dest, data)
            n += 1
    ledger_add("kenney:impactsounds", "- sons Kenney `kenney:impactsounds` — « Impact Sounds » 1.0 par Kenney — "
               "https://kenney.nl/assets/impact-sounds — CC0 — %d fichiers .ogg tels quels → audio/kenney/ : %s"
               % (len(KENNEY_SOUNDS), ", ".join(KENNEY_SOUNDS)))
    print("sons Kenney : %d fichiers (%d nouveaux)" % (len(KENNEY_SOUNDS), n))


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
            print("%-28s %7d tri  %6.2f Mo  plafond %4s  %s" % (asset_id, inf["tris"], size / 1e6,
                                                                SIZE_LIMIT.get(asset_id, "-"), ", ".join(flags)))
    print("modèles : %.1f Mo" % (total / 1e6))


def _ledger_ids():
    if not os.path.isfile(LEDGER):
        return set()
    with open(LEDGER, encoding="utf-8") as f:
        return set(re.findall(r"`[a-z]+:([A-Za-z0-9_\-]+)`", f.read()))


def _managed_texture_imports():
    """Les .import des images rangées par cet outil : modèles Poly Haven, dossiers de textures inscrits au
    registre (ou des listes du lot), livres, décalques ambientCG. Les dossiers des autres (rugs, runner…)
    ne sont pas touchés."""
    known = _ledger_ids() | set(KIT_ACG) | set(KIT_PHTEX) | {"books"}
    roots = [MODELS_DIR, DECAL_DIR]
    if os.path.isdir(TEX_DIR):
        roots += [os.path.join(TEX_DIR, d) for d in sorted(os.listdir(TEX_DIR))
                  if d in known and os.path.isdir(os.path.join(TEX_DIR, d))]
    for r in roots:
        for base, _, files in os.walk(r):
            for n in files:
                if n.lower().endswith((".jpg.import", ".png.import")):
                    yield os.path.join(base, n)


def _limit_for(p):
    """Plafond (px) d'une image gérée, d'après le dossier de son asset ; None : ne pas toucher."""
    rel = os.path.relpath(p, ROOT).replace("\\", "/").split("/")
    if rel[:3] == ["assets", "models", "polyhaven"] and len(rel) > 3:
        return SIZE_LIMIT.get(rel[3])
    if rel[:2] == ["assets", "textures"] and len(rel) > 2:
        return SIZE_LIMIT.get(rel[2])
    return None


def _ours(p):
    """Dossiers créés par ce lot (réglages forcés même si un import les a déjà réglés)."""
    rel = os.path.relpath(p, ROOT).replace("\\", "/").split("/")
    if rel[:3] == ["assets", "models", "polyhaven"]:
        return True
    if rel[:3] == ["assets", "decals", "acg"]:
        return True
    return rel[:2] == ["assets", "textures"] and len(rel) > 2 and (rel[2] in KIT_ACG or rel[2] in KIT_PHTEX or rel[2] == "books")


def fix_texture_imports():
    """Textures 3D : compressées en VRAM (S3TC/BPTC, RGTC pour les normales) avec mipmaps, et plafonnées
    (process/size_limit) selon SIZE_LIMIT. (Sans éditeur, la détection « utilisée en 3D » de Godot ne passe
    jamais : on le règle ici.) Rend le nombre de fichiers .import modifiés."""
    changed = 0
    for p in _managed_texture_imports():
        with open(p, encoding="utf-8") as f:
            text = f.read()
        if 'importer="texture"' not in text:
            continue
        want = {}
        if _ours(p) or "compress/mode=0" in text:
            name = os.path.basename(p).lower()
            normal = "nor_gl" in name or "normalgl" in name or "_normal" in name
            want = {"compress/mode": "2", "mipmaps/generate": "true", "detect_3d/compress_to": "0",
                    "compress/normal_map": "1" if normal else "0"}
            if normal:
                want["roughness/mode"] = "0"
        lim = _limit_for(p)
        if lim is not None:
            want["process/size_limit"] = str(lim if lim < 1024 else 0)
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
    errors = 0
    for step in (1, 2, 3):
        print("import headless (%d)…" % step, flush=True)
        r = subprocess.run([godot, "--headless", "--path", ROOT, "--import"], timeout=2400,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        lines = [l for l in r.stdout.splitlines() if "ERROR" in l or "WARNING" in l]
        errors = sum(1 for l in lines if "ERROR" in l)
        for l in lines[:40]:
            print("  " + l)
        print("import terminé (code %d, %d lignes ERROR)" % (r.returncode, errors))
        n = fix_texture_imports()
        print("%d réglages de textures corrigés (VRAM, mipmaps, plafonds)" % n)
        if n == 0:
            break
    return errors


# ------------------------------------------------------------------ export et taille du pck

def pck_entries(path):
    """(chemin, taille) de chaque fichier d'un .pck de Godot 4."""
    with open(path, "rb") as f:
        if f.read(4) != b"GDPC":
            raise ValueError("pas un pck : %s" % path)
        ver, _, _, _, _ = struct.unpack("<5I", f.read(20))
        f.read(8)
        if ver >= 3:
            diro, = struct.unpack("<Q", f.read(8))
            f.seek(diro)
        else:
            f.read(64)
        n, = struct.unpack("<I", f.read(4))
        out = []
        for _ in range(n):
            sl, = struct.unpack("<I", f.read(4))
            p = f.read(sl).rstrip(b"\0").decode("utf-8")
            _, size = struct.unpack("<QQ", f.read(16))
            f.read(16)
            if ver >= 2:
                f.read(4)
            out.append((p, size))
    return out


def _import_sources():
    """.godot/imported/<fichier> -> dossier de la source (d'après les dest_files des .import)."""
    m = {}
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for n in files:
            if not n.endswith(".import"):
                continue
            p = os.path.join(base, n)
            try:
                with open(p, encoding="utf-8") as f:
                    text = f.read()
            except (OSError, UnicodeDecodeError):
                continue
            src = os.path.relpath(p[:-len(".import")], ROOT).replace("\\", "/")
            for d in re.findall(r'"res://(\.godot/imported/[^"]+)"', text):
                m[d] = src
    return m


def _group(src):
    parts = src.split("/")
    if parts[:3] == ["assets", "models", "polyhaven"] and len(parts) > 3:
        return "/".join(parts[:4])
    if parts[:2] == ["assets", "textures"] and len(parts) > 3:
        return "/".join(parts[:3])
    return "/".join(parts[:-1]) or "."


def pck_report(godot, out, preset="Windows Desktop"):
    godot = os.path.abspath(godot)
    os.makedirs(out, exist_ok=True)
    exe = os.path.join(os.path.abspath(out), "DontPlay.exe")
    print("export « %s » → %s …" % (preset, exe), flush=True)
    r = subprocess.run([godot, "--headless", "--path", ROOT, "--export-release", preset, exe], timeout=3600,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    with open(os.path.join(out, "export.log"), "w", encoding="utf-8") as f:
        f.write(r.stdout)
    errs = [l for l in r.stdout.splitlines() if "ERROR" in l]
    print("export terminé (code %d, %d lignes ERROR)" % (r.returncode, len(errs)))
    for l in errs[:20]:
        print("  " + l)
    pck = os.path.join(out, "DontPlay.pck")
    if r.returncode != 0 or not os.path.isfile(pck):
        raise ValueError("export raté (modèles d'export absents de $XDG_DATA_HOME/godot/export_templates ?) : voir %s"
                         % os.path.join(out, "export.log"))
    entries = pck_entries(pck)
    srcmap = _import_sources()
    groups = {}
    for p, size in entries:
        rel = p[len("res://"):] if p.startswith("res://") else p
        src = srcmap.get(rel)
        if src is None:
            g = "/".join(rel.split("/")[:2]) if rel.startswith(".godot/") else _group(rel)
        else:
            g = _group(src)
        s, n = groups.get(g, (0, 0))
        groups[g] = (s + size, n + 1)
    tops = {}
    for g, (s, n) in groups.items():
        parts = g.split("/")
        t = "/".join(parts[:3]) if parts[0] == "assets" else parts[0]
        ts, tn = tops.get(t, (0, 0))
        tops[t] = (ts + s, tn + n)
    # zip de publication (exe + pck, compression par défaut) : taille seulement
    with tempfile.NamedTemporaryFile(dir=out, suffix=".zip", delete=False) as tmp:
        zpath = tmp.name
    try:
        with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
            for n in ("DontPlay.exe", "DontPlay.pck"):
                z.write(os.path.join(out, n), "DontPlay/" + n)
        zsize = os.path.getsize(zpath)
    finally:
        os.remove(zpath)
    total = os.path.getsize(pck)
    rows = ["# pck %s : %d octets (%.1f Mo), %d fichiers ; zip (exe + pck) %.1f Mo" % (pck, total, total / 1e6, len(entries), zsize / 1e6),
            "octets\tMo\tfichiers\tdossier"]
    for g, (s, n) in sorted(groups.items(), key=lambda kv: -kv[1][0]):
        rows.append("%d\t%.2f\t%d\t%s" % (s, s / 1e6, n, g))
    rows.append("")
    rows.append("# totaux par grand dossier")
    for t, (s, n) in sorted(tops.items(), key=lambda kv: -kv[1][0]):
        rows.append("%d\t%.2f\t%d\t%s" % (s, s / 1e6, n, t))
    with open(os.path.join(out, "pck_report.tsv"), "w", encoding="utf-8") as f:
        f.write("\n".join(rows) + "\n")
    print("pck %.1f Mo (%d fichiers), zip %.1f Mo ; tableau : %s" % (total / 1e6, len(entries), zsize / 1e6,
                                                                     os.path.join(out, "pck_report.tsv")))
    for t, (s, n) in sorted(tops.items(), key=lambda kv: -kv[1][0])[:12]:
        print("  %8.1f Mo  %4d  %s" % (s / 1e6, n, t))
    return total, zsize


# ------------------------------------------------------------------ le lot complet

def kit(src_kenney):
    """Toute la liste fermée du lot V1-ASSETS (idempotent). Rend le nombre d'échecs."""
    errors = 0
    steps = ([(ph_model, i, "1k") for i in KIT_MODELS] + [(acg_pack, i, "1K") for i in KIT_ACG]
             + [(ph_material, i, "1k") for i in KIT_PHTEX] + [(acg_decal, i, KIT_DECALS[i]) for i in KIT_DECALS])
    for fn, i, arg in steps:
        try:
            fn(i, arg)
        except Exception as e:
            errors += 1
            print("ÉCHEC %s : %s" % (i, e), file=sys.stderr)
    for name, fn in (("books", books), ("kenney", lambda: kenney(src_kenney))):
        try:
            fn()
        except Exception as e:
            errors += 1
            print("ÉCHEC %s : %s" % (name, e), file=sys.stderr)
    ledger_limits()
    return errors


def _guess_kenney():
    for base in (os.path.join(os.path.expanduser("~"), "Downloads"), CACHE):
        for g in KENNEY_SRC_GUESS:
            p = os.path.join(base, g)
            if os.path.isdir(p):
                return p
    return None


def main():
    global CACHE
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("kind", choices=["model", "phtex", "acg", "phmat", "acgmat", "decal", "books", "kenney", "kit",
                                     "limits", "info", "import", "pck"])
    ap.add_argument("ids", nargs="*")
    ap.add_argument("--res", default=None, help="1k/2k (Poly Haven) ou 1K/2K (ambientCG) ; décalques : 1K ou 512")
    ap.add_argument("--godot", default=None, help="binaire Godot : lance l'import headless à la fin")
    ap.add_argument("--cache", default=None, help="dossier des téléchargements bruts (hors du projet)")
    ap.add_argument("--src", default=None, help="kenney, kit : dossier Audio de Kenney Impact Sounds")
    ap.add_argument("--out", default=None, help="pck : dossier de l'export et de pck_report.tsv")
    a = ap.parse_args()
    if a.cache:
        CACHE = os.path.abspath(a.cache)
    errors = 0
    for i in a.ids:
        try:
            if a.kind == "model":
                ph_model(i, a.res or "1k")
            elif a.kind == "phtex":
                ph_texture(i, a.res or "1k")
            elif a.kind == "acg":
                acg_material(i, (a.res or "1K").upper())
            elif a.kind == "phmat":
                ph_material(i, a.res or "1k")
            elif a.kind == "acgmat":
                acg_pack(i, (a.res or "1K").upper())
            elif a.kind == "decal":
                res = (a.res or "").upper()
                acg_decal(i, 512 if res == "512" else 2048 if res == "2K" else KIT_DECALS.get(i, 1024) if not res else 1024)
        except Exception as e:     # un asset raté n'arrête pas les autres
            errors += 1
            print("ÉCHEC %s : %s" % (i, e), file=sys.stderr)
    try:
        if a.kind == "books":
            books()
        elif a.kind == "kenney":
            kenney(a.src or _guess_kenney())
        elif a.kind == "kit":
            errors += kit(a.src or _guess_kenney())
        elif a.kind == "info":
            info_all()
        elif a.kind == "limits":
            print("%d réglages de textures corrigés (VRAM, mipmaps, plafonds)" % fix_texture_imports())
            ledger_limits()
    except Exception as e:
        errors += 1
        print("ÉCHEC %s : %s" % (a.kind, e), file=sys.stderr)
    if a.godot and a.kind != "pck":
        if godot_import(a.godot):
            errors += 1
    if a.kind == "pck":
        if not a.godot or not a.out:
            print("pck : --godot et --out sont requis", file=sys.stderr)
            return 2
        try:
            pck_report(a.godot, a.out)
        except Exception as e:
            print("ÉCHEC pck : %s" % e, file=sys.stderr)
            return 1
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
