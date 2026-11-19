# Sources des images HD (0.3.4)

Les images de ce dossier sont générées par `tools/make_assets.py images` (qui lance aussi `tools/make_photos.py`).
Les photos sources restent hors du projet ; seules les images finales sont livrées.

## Photos (Poly Haven, licence CC0)

« Backplates » (photos d'accompagnement) des HDRI de Poly Haven — https://polyhaven.com/license (CC0, domaine public).
Recadrées, réduites, retouchées (couleurs passées, grain, usure du tirage), avec des personnages dessinés par le script.

| Fichier du jeu | HDRI Poly Haven | Image | Adresse |
|---|---|---|---|
| calendar.png (photo du mois) | autumn_park | DSC_0158 | https://dl.polyhaven.org/file/ph-assets/HDRIs/extra/Backplates/autumn_park/jpg_plain/DSC_0158.jpg |
| photos/plage.png | blouberg_sunrise_1 | IMG_0623 | https://dl.polyhaven.org/file/ph-assets/HDRIs/extra/Backplates/blouberg_sunrise_1/jpg_plain/IMG_0623.jpg |
| photos/noel.png | christmas_photo_studio_07 | 15 | https://dl.polyhaven.org/file/ph-assets/HDRIs/extra/Backplates/christmas_photo_studio_07/jpg_plain/15.jpg |
| photos/mariage.png | small_cathedral_02 | DSC_0681 | https://dl.polyhaven.org/file/ph-assets/HDRIs/extra/Backplates/small_cathedral_02/jpg_plain/DSC_0681.jpg |
| photos/gp_mariage.png | small_cathedral_02 | DSC_0701 | https://dl.polyhaven.org/file/ph-assets/HDRIs/extra/Backplates/small_cathedral_02/jpg_plain/DSC_0701.jpg |
| photos/jardin.png | vignaioli | DSC07532 | https://dl.polyhaven.org/file/ph-assets/HDRIs/extra/Backplates/vignaioli/jpg_plain/DSC07532.jpg |
| photos/labo.png | residential_garden | IMG_0603 | https://dl.polyhaven.org/file/ph-assets/HDRIs/extra/Backplates/residential_garden/jpg_plain/IMG_0603.jpg |
| bureau/calendrier_2040.png (photo du mois, bureau) | autumn_road | DSC_0211 | https://dl.polyhaven.org/file/ph-assets/HDRIs/extra/Backplates/autumn_road/jpg_plain/DSC_0211.jpg |

photos/ecole.png, photos/aieule.png, photos/famille.png et photo.png : entièrement dessinées par les scripts.
Les images de `images/bureau/` (calendrier de la pharmacie, diplôme, étiquettes) sont générées par `tools/gen_bureau.py` (lot V2-BUREAU) ; le diplôme est écrit en DejaVu Serif (non livrée : seules les lettres dessinées le sont).

## Matières (ambientCG, licence CC0, déjà dans le projet)

Grain du papier : Paper001, Paper002 ; laine du tapis (textures/runner/) : Carpet016 ; liège : Cork003 —
https://ambientcg.com (CC0).

## Polices (licence OFL)

Reenie Beanie, IBM Plex Mono, UnifrakturMaguntia (dans assets/fonts, avec leur licence). Inter (OFL) sert à la
typographie imprimée (calendrier, horloge…) si elle est installée au moment de la génération ; elle n'est pas livrée :
seules les lettres déjà dessinées dans les images le sont.
