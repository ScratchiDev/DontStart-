# RUNTIME

Un jeu d'horreur rétro à la première personne, pour PC (clavier et souris), fait avec **Godot 4.7**. Objectif : une sortie sur Steam.

Une disquette trouvée dans un vide-grenier. Une chambre d'ado plongée dans le noir, à 3 h 12. Un vieil ordinateur qui s'allume tout seul et dont l'écran clignote « INSÉRER DISQUETTE ». Et un jeu qui pose des questions, impose des choix à durée limitée, et choisit toujours mal à ta place.

## Jouer (Windows)

1. Télécharge **[RUNTIME-windows.zip](https://github.com/ScratchiDev/DontStart-/releases/download/dev-latest/RUNTIME-windows.zip)** (version de développement, reconstruite automatiquement à chaque modification du jeu).
2. Extrais le dossier, lance `RUNTIME.exe`.
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
| Menu, options | Échap (sensibilité, volume, plein écran, qualité) |

## État du jeu (version 0.2)

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

- La chambre se construit dans `godot/scripts/room.gd` (meubles mis à l'échelle en mètres réels).
- Le joueur : `godot/scenes/player.tscn` et `godot/scripts/player.gd`.
- Le rendu rétro : `godot/shaders/retro_post.gdshader` ; l'écran du moniteur : `godot/shaders/crt_screen.gdshader` et `godot/scripts/terminal.gd`.
- Les images et ambiances faites maison (affiches, photo, mot, souffle de la pièce, lecteur de disquette) sont générées par `godot/tools/make_assets.py`.
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
