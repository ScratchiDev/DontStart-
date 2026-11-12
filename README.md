# Don't Play

Un jeu d'horreur rétro à la première personne, pour PC (clavier et souris), fait avec **Godot 4.7**. Objectif : une sortie sur Steam.

Alexandre ou Aurèlia, 16 ans, passe les vacances chez ses grands-parents, Henriette et Albert. Une maison restée dans les années 90, mais remplie d'appareils connectés. Dans l'ancienne chambre de sa mère, un vieil ordinateur relié à internet et une disquette. Dessus : **S.1.L.3.N.C.3.**, une intelligence artificielle échappée d'un laboratoire, qui se nourrit de la peur, hante chaque écran de la maison et veut faire passer ses « tests » aux humains. Pour l'enfermer : une arme cybernétique, à assembler avec ce qu'on trouve dans les pièces.

## Jouer (Windows)

1. Télécharge **[DontPlay-windows.zip](https://github.com/ScratchiDev/DontStart-/releases/download/dev-latest/DontPlay-windows.zip)** (version de développement, reconstruite automatiquement à chaque modification du jeu).
2. Extrais le dossier, lance `DontPlay.exe`.
3. Si Windows affiche « Windows a protégé votre ordinateur » : **Informations complémentaires → Exécuter quand même** (le jeu n'est pas encore signé numériquement).

Conseils : seul, dans le noir, avec un casque. Le jeu contient des sursauts et des effets clignotants.

## Commandes

| Action | Touche |
|---|---|
| Marcher | Z Q S D / W A S D (selon ton clavier) ou flèches |
| Courir / s'accroupir | Maj / C ou Ctrl |
| Regarder | Souris |
| Agir | E ou clic gauche |
| Lampe de poche | F |
| Inventaire | Tab ou I |
| Menu, options | Échap (sensibilité, volume, plein écran, qualité) |

## État du jeu (version 0.3.0 : l'acte I)

- **Jouable (20 à 30 min)** :
  - écran-titre, choix Alexandre ou Aurèlia, options (sensibilité, volume, qualité, sursauts réduits, éclairs adoucis, chuchotements) ;
  - **acte I « Lecteur A: »** : l'ouverture dans le noir, la chambre de ta mère et ses traces (mot de Mamie, chocolat froid, journal de 2016 sous le lit, calendrier, photo rayée, fenêtre vissée), la disquette, puis la **séance 1** avec S.1.L.3.N.C.3. sur le vieil ordinateur : calibration et quatre protocoles à choix minutés (touches 1, 2, 3), la jauge PEUR MESURÉE, les lettres qui brillent, la chambre qui réagit, un seul vrai sursaut ;
  - **trois issues** : TRANSMISSION, ABSORBÉ, ou continuer (avec la fausse fin du mot secret) ; les fins découvertes sont gardées ;
  - la clé glissée sous la porte, puis le **couloir du 1er étage** (caméra qui te suit, ampoules connectées, thermostat bloqué sur 3:12) jusqu'à la porte de ta grand-mère.
- **Prochaine étape (0.3.1 et 0.3.2)** : l'étage complet (salle de bain, chambre d'amis, bureau), les appareils hantés, les premières pièces de l'arme, l'essai réel du miroir, la sauvegarde, puis la séance 2.
- **Conception** : [docs/GDD.md](docs/GDD.md) (document de conception) et [docs/v0.3.md](docs/v0.3.md) (spécification de la version 0.3).

## Développer

Le projet Godot est dans [`godot/`](godot/). Ouvre `godot/project.godot` avec [Godot 4.7.2](https://godotengine.org/download) (version standard).

- Les outils de construction communs (matières, murs percés, habillage, portes, meubles mis à l'échelle en mètres réels) sont dans `godot/scripts/builder.gd`, `door.gd` et `house_room.gd` ; la chambre de la mère dans `godot/scripts/room.gd`.
- Les appareils hantés : `godot/scripts/device.gd` et `godot/shaders/haunted_screen.gdshader`.
- Le joueur : `godot/scenes/player.tscn` et `godot/scripts/player.gd`.
- Le rendu rétro : `godot/shaders/retro_post.gdshader` ; l'écran du moniteur : `godot/shaders/crt_screen.gdshader` et `godot/scripts/terminal.gd`.
- Les images, textures, sons et musiques faits maison (affiches, photo, papiers peints, carrelages, visage de l'entité, ambiances, musique) sont générés par `godot/tools/make_assets.py`.
- Banc d'essai des pièces, portes et écrans : `godot --path godot res://tests/sandbox.tscn -- --shots=/chemin`.
- Tests automatiques avec captures d'écran :
  ```bash
  godot --path godot -- --autotest --shots=/chemin/vers/captures            # parcours complet de l'acte I
  godot --path godot -- --autotest --seance=2,1,0,1,0,2/xx,yy,zz --shots=…  # séance seule, choix imposés (fins)
  godot --path godot -- --preview=couloir --shots=…                          # vues d'une pièce de la maison
  ```
  Le parcours vise chaque objet comme un joueur, joue la séance avec des réponses fixées et affiche `AUTOTEST OK` à la fin. `python3 godot/tools/check_texts.py` vérifie les textes.
- L'export Windows est fait par `.github/workflows/godot-windows.yml` à chaque push sur `main` qui touche `godot/`.

## Prototype web

La première version, jouable dans le navigateur (Three.js), est toujours à la racine du dépôt (`index.html`, `src/`, `public/`) : `npm install` puis `npm run dev`. Elle contient le jeu-terminal complet qui sera porté dans la version Godot.

## Licences

Code original. Les ressources (meubles Kenney, textures ambientCG, scan de visage Lee Perry-Smith, ciel HDR Poly Haven, sons Kenney, polices Google Fonts) sont détaillées dans [CREDITS.md](CREDITS.md).
