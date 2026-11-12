"""Cherche dans les scripts et les textes du jeu des phrases que l'histoire a remplacées.
Usage : python3 godot/tools/check_texts.py   (code de sortie 1 si une phrase interdite est trouvée)"""
import glob
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
INTERDITS = [
    "C'est ton écriture", "Tu l'as rangée", "sans étiquette", "trouvée dans un vide-grenier",
    "Novembre. Tous les jours", "Deux semaines de vacances", "m'avait lancé.", "RUNTIME BIOS",
    "Cette nuit, à 3 h 12, le téléphone",
]
fichiers = glob.glob(os.path.join(ROOT, 'scripts', '**', '*.gd'), recursive=True)
fichiers += [os.path.join(ROOT, 'project.godot'), os.path.join(ROOT, 'LISEZMOI.txt')]
trouve = 0
for f in fichiers:
    if not os.path.exists(f):
        continue
    for n, ligne in enumerate(open(f, encoding='utf-8'), 1):
        for x in INTERDITS:
            if x in ligne:
                print(f"{os.path.relpath(f, ROOT)}:{n}: « {x} »")
                trouve += 1
print('textes OK' if trouve == 0 else f'{trouve} phrase(s) à corriger')
sys.exit(1 if trouve else 0)
