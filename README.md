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

## État du jeu (version 0.3 en cours)

- **En cours (v0.3)** : nouveau nom, choix Alexandre/Aurèlia, inventaire, portes, appareils hantés, musique ; prochainement le premier étage de la maison, le réveil de S.1.L.3.N.C.3. et les premières pièces de l'arme.

### Version 0.2

- **Fait** :
  - écran-titre, menus et options sauvegardées ;
  - la chambre en 3D au premier étage : papier peint années 80, lambris, moulures, meubles salis par le temps, vraie porte à panneaux, couette froissée, et tout le désordre d'une chambre habitée (livres, cassettes VHS, disquettes, manuel, mug, crayons, câble, tableau en liège, calendrier, horloge arrêtée, linge, chaussures, sac) ;
  - des traces : taches d'humidité au plafond, moisissure, griffures et mots grattés au-dessus du lit, empreintes de pieds nus de la porte jusque sous le lit ;
  - dehors : jardin, clôture, rue mouillée, lampadaire orange, maison d'en face avec une fenêtre allumée (et quelqu'un derrière), arbres nus dans le vent, pluie, gouttes qui glissent sur la vitre, éclairs qui illuminent la pièce, tonnerre ;
  - lumière : lampe de poche, lampadaire et éclairs qui projettent l'ombre des croisillons dans la pièce, lueur de l'écran, éclairage indirect (la lumière rebondit sur les murs), brouillard volumétrique, rendu rétro 640×360 avec tramage ;
  - déplacements et interactions (armoire, disquette, ordinateur, mot, photo, tableau, calendrier, horloge, manuel, réveil, porte, interrupteur, radio, fenêtre) ; s'asseoir devant l'ordinateur, insérer la disquette, démarrage de l'écran ;
  - export Windows automatique.
- **Prochaine version** : le jeu-terminal complet sur l'écran du moniteur (les 4 niveaux, les choix à durée limitée, la corruption, les 4 fins), la musique et les sons de tension, les événements dans la chambre pendant la partie, l'entité et les screamers.

## Développer

Le projet Godot est dans [`godot/`](godot/). Ouvre `godot/project.godot` avec [Godot 4.7.2](https://godotengine.org/download) (version standard).

- Les outils de construction communs (matières, murs percés, habillage, portes, meubles mis à l'échelle en mètres réels) sont dans `godot/scripts/builder.gd`, `door.gd` et `house_room.gd` ; la chambre de la mère dans `godot/scripts/room.gd`.
- Les appareils hantés : `godot/scripts/device.gd` et `godot/shaders/haunted_screen.gdshader`.
- Le joueur : `godot/scenes/player.tscn` et `godot/scripts/player.gd`.
- Le rendu rétro : `godot/shaders/retro_post.gdshader` ; l'écran du moniteur : `godot/shaders/crt_screen.gdshader` et `godot/scripts/terminal.gd`.
- Les images, textures, sons et musiques faits maison (affiches, photo, papiers peints, carrelages, visage de l'entité, ambiances, musique) sont générés par `godot/tools/make_assets.py`.
- Banc d'essai des pièces, portes et écrans : `godot --path godot res://tests/sandbox.tscn -- --shots=/chemin`.
- Test automatique avec captures d'écran :
  ```bash
  godot --path godot -- --autotest --shots=/chemin/vers/captures
  ```
  Il joue le parcours (armoire → disquette → photo → ordinateur) en visant chaque objet comme un joueur et affiche `AUTOTEST OK` à la fin.
- L'export Windows est fait par `.github/workflows/godot-windows.yml` à chaque push sur `main` qui touche `godot/`.

## Prototype web

La première version, jouable dans le navigateur (Three.js), est toujours à la racine du dépôt (`index.html`, `src/`, `public/`) : `npm install` puis `npm run dev`. Elle contient le jeu-terminal complet qui sera porté dans la version Godot.

## Licences

Code original. Les ressources (meubles Kenney, textures ambientCG, scan de visage Lee Perry-Smith, ciel HDR Poly Haven, sons Kenney, polices Google Fonts) sont détaillées dans [CREDITS.md](CREDITS.md).
