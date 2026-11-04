# RUNTIME

Un jeu d'horreur rétro à la première personne, pour PC (clavier et souris), jouable dans le navigateur.

Une disquette trouvée dans un vide-grenier. Une chambre d'ado plongée dans le noir, la nuit. Un vieil ordinateur dont l'écran clignote « INSÉRER DISQUETTE ». Et un jeu qui pose des questions, impose des choix à durée limitée, et choisit toujours mal à ta place.

## Jouer

- **En ligne** : https://d4w647nmnx-hub.github.io/Claude-/ (une fois GitHub Pages activé, voir plus bas).
- **En local** :
  ```bash
  npm install
  npm run dev
  ```
  puis ouvre l'adresse affichée (`http://localhost:5173/Claude-/`).

Conseils : seul, dans le noir, avec un casque. Le jeu contient des sursauts, des cris et des effets clignotants.

## Commandes

| Action | Touche |
|---|---|
| Marcher | Z Q S D, W A S D ou flèches (Maj pour courir) |
| Regarder | Souris (clic pour capturer la souris) |
| Agir | E (ouvrir, lire, insérer la disquette…) |
| Dans le jeu-terminal | 1 / 2 / 3 pour choisir, clavier pour écrire, Espace pour accélérer le texte |
| Reposer un papier | Échap |

Pendant le jeu-terminal, tu peux toujours tourner la tête. Ce n'est pas toujours une bonne idée.

## Ce qu'il y a dedans

- Une chambre en 3D (Three.js) : meubles, textures PBR, clair de lune par la fenêtre, lampe de poche avec vraies ombres, poussière, post-traitement (occlusion ambiante, bloom, grain, vignettage, aberration chromatique).
- Un jeu-terminal RUNTIME affiché sur l'écran du moniteur, dans la 3D (CSS3D) : tube cathodique courbé, phosphore vert qui vire au rouge, texte qui pourrit, décors tramés par niveau, 4 fins.
- Une bande-son synthétisée en direct (Tone.js) : berceuse de boîte à musique qui se dérègle, battement de cœur, respiration binaurale, chuchotements, cris. Plus des sons positionnés dans la pièce (pas, grincements, coups à la porte).
- Des événements dans la chambre pendant la partie : l'armoire qui s'ouvre dans ton dos, une silhouette à la fenêtre, le plafonnier qui claque, et un visage scanné en 3D qui surgit si tu te retournes quand on te dit de ne pas le faire.

## Mettre en ligne (GitHub Pages)

Le dépôt contient un workflow (`.github/workflows/deploy.yml`) qui construit et publie le jeu à chaque push sur `main`.

1. Sur GitHub, ouvre **Settings → Pages**.
2. Dans **Build and deployment → Source**, choisis **GitHub Actions**.
3. Pousse un commit (ou relance le workflow dans l'onglet **Actions**).
4. Le jeu est servi sur `https://d4w647nmnx-hub.github.io/Claude-/`.

## Qualité et performances

- La case **Qualité élevée** de l'écran-titre active l'occlusion ambiante, l'anti-aliasing et les ombres fines. Décoche-la sur un PC modeste.
- `?lite` dans l'adresse force un mode très léger (utilisé pour les tests automatisés).

## Structure

```
index.html            écran-titre, HUD
src/main.js           enchaînement : titre → chambre → terminal → fins
src/room/             la chambre 3D (Room), contrôleur (Player), interactions (Interact), post-traitement (PostFX), affiches
src/terminal/         le jeu-terminal (Terminal), tramage et décors (dither), feuille de style
src/audio/            synthèse Tone.js + échantillons positionnés
src/events/           événements de la chambre liés à l'histoire
public/assets/        modèles, textures, HDR, sons (voir CREDITS.md)
```

## Licences

Code original. Les ressources (meubles Kenney, textures ambientCG, scan de visage Lee Perry-Smith, HDRI Poly Haven, sons Kenney) sont détaillées dans [CREDITS.md](CREDITS.md).
