# Crédits et licences des ressources

Le code du jeu RUNTIME est original. Les ressources ci-dessous sont libres de droits ou utilisées sous licence libre, avec attribution. Les chemins valent pour la version Godot (`godot/assets/`) ; la version web en garde une copie dans `public/assets/`.

## Moteur et bibliothèques

- [Godot Engine](https://godotengine.org) 4.7 — licence **MIT** (© Juan Linietsky, Ariel Manzur et les contributeurs de Godot).
- Version web : [three.js](https://threejs.org) (MIT), [Tone.js](https://tonejs.github.io) (MIT), [GSAP](https://gsap.com) (licence standard GSAP), [Vite](https://vitejs.dev) (MIT).

## Modèles 3D

- **Furniture Kit** par [Kenney](https://kenney.nl) — licence **CC0 1.0** (domaine public). `godot/assets/models/kenney/`.
- **Lee Perry-Smith head scan** par Lee Perry-Smith / Infinite-Realities — licence **CC BY 3.0**. Distribué avec les exemples de [three.js](https://github.com/mrdoob/three.js). `godot/assets/models/face/`.
- **Mains du joueur** (`godot/assets/models/mains/`) : générées par `godot/tools/make_hands.py` à partir des données **CC0 1.0** de [MakeHuman](https://github.com/makehumancommunity/makehuman) (maillage de base, squelette, poids, morphes). Manche teinte à partir de `Fabric045` (ambientCG, CC0) ; peau, lampe de poche et bracelet générés pour le jeu.

## Modèles et matières photoréalistes (Poly Haven, ambientCG)

Tous sous licence **CC0 1.0** (domaine public), téléchargés depuis [Poly Haven](https://polyhaven.com) et [ambientCG](https://ambientcg.com) (glTF et textures en 1k, 2k pour les grandes surfaces ; décalques en 1k ou 512 px). Le détail (page source, fichiers, nombre de triangles) est dans `godot/assets/ASSETS_CC0.md` (dans le zip du jeu : `licences/ASSETS_CC0.md`), une ligne par asset.

- Modèles Poly Haven (`godot/assets/models/polyhaven/`) : `boombox`, `bleach_bottle`, `cardboard_box_01`, `Chandelier_02`, `ClassicNightstand_01`, `desk_lamp_arm_01`, `dining_chair_02`, `drain_cleaner`, `fancy_picture_frame_01`, `GothicBed_01`, `GothicCabinet_01`, `GothicCommode_01`, `jug_01`, `ornate_mirror_01`, `painted_wooden_cabinet`, `painted_wooden_chair_01`, `painted_wooden_nightstand`, `painted_wooden_shelves`, `painted_wooden_stool`, `plunger`, `potted_plant_04`, `Rockingchair_01`, `side_table_tall_01`, `Television_01`, `vintage_grandfather_clock_01`, `vintage_suitcase`, `wall_clock`, `wicker_basket_02`, `wooden_table_02` ; et, pour l'habillage des pièces : `alarm_clock_01`, `ArmChair_01`, `antique_ceramic_vase_01`, `binder_notebook`, `book_encyclopedia_set_01`, `brass_vase_03`, `ceramic_vase_02`, `circuit_board`, `classic_laptop`, `clipboard`, `gamepad`, `hanging_picture_frame_02`, `hanging_picture_frame_03`, `horse_statue_01`, `Lantern_01`, `lightbulb_01`, `magnifying_glass_01`, `mantel_clock_01`, `measuring_tape_01`, `medical_box`, `multi_cleaner_bottle`, `office_notepads`, `plastic_crate_01`, `portable_cassette_player`, `postcard_set_01`, `retro_multimeter`, `round_spectacles`, `rubber_duck_toy`, `screwdriver`, `small_wooden_table_01`, `standing_picture_frame_02`, `stationery_supplies`, `tea_set_01`, `television_02`, `throw_pillows_01`, `vintage_oil_lamp`, `vintage_pocket_watch`, `vintage_stapler`, `wooden_bowl_02`, `wooden_crate_01`. Les auteurs de chaque modèle sont nommés dans `ASSETS_CC0.md` ; les textures des petits objets sont réduites à 512 ou 256 px à l'import.
- Matières Poly Haven (`godot/assets/textures/`) : `herringbone_parquet`, `stair_planks`, `floor_tiles_06`, `decrepit_wallpaper`, `terlenka`, `ceiling_interior`, `bark_brown_02`, `dirty_carpet`, `velour_velvet`, `rough_linen`, `cotton_jersey`, `terry_cloth`, `curly_teddy_natural`, `quatrefoil_jacquard_fabric`.
- Matières ambientCG (`godot/assets/textures/`) : `PaintedPlaster017`, `PaintedWood009C`, `Wood027`, `Tiles133B`, `Carpet016`, `Fabric045`, `Wood008`, `Plastic004`, `Plastic013B`, `Porcelain001`, `Metal049B`, `Metal046B`, `PaintedMetal010`, `PaintedPlaster012`, `CardboardSet001`, `Wallpaper002B`, `Leather014`, `Cork003`, `Tape004`, `Paper001`, `Paper002`.
- Décalques ambientCG (`godot/assets/decals/acg/`) : `Leaking001`, `Leaking002`, `Leaking003`, `Leaking005`, `Leaking007`, `Leaking009`, `SurfaceImperfections005`, `SurfaceImperfections006`, `SurfaceImperfections009`, `SurfaceImperfections010`, `SurfaceImperfections014`, `SurfaceImperfections017`, `Fingerprints001`, `Fingerprints004`, `Smear002`, `Smear005`, `Scratches001`, `Scratches004`, `Rust001` (couleur et opacité réunies en PNG, rugosité rangée dans une carte ORM).
- Livres (`godot/assets/textures/books/`) : couvertures, toile, normale et ARM de `decorative_book_set_01` (Poly Haven, CC0). Les reliures anciennes de l'atlas sont générées pour le jeu par `godot/tools/assets_cc0.py` sur la toile et le cuir de ce même lot ; leurs titres dorés sont écrits en Liberation Serif (Red Hat, licence **SIL Open Font License 1.1** ; la police elle-même n'est pas distribuée).
- Les papiers peints, le damier et les cartes ORM (occlusion, rugosité, dont `herringbone_parquet_orm_v2.jpg`) sont retravaillés à partir de ces textures ; la faïence de la salle de bain (`textures/Faience15/`) et la variation de la moquette (`Carpet016/moquette_var.png`), les lambris (`textures/Lambris/`, d'après Wood027), `herringbone_parquet_orm_v3.jpg` et `Carpet016/moquette_var2.png` sont générés pour le jeu ; le tapis du couloir (`runner_couloir.png`, puis `textures/runner/` sur la laine de `Carpet016`), les motifs des tapis (`textures/rugs/`, `godot/tools/make_rugs.py`, tissage de `Fabric045`) et le masque de la lampe de poche (`flashlight_cookie.png`) sont générés pour le jeu.
- Photos d'accompagnement (« backplates ») de HDRI [Poly Haven](https://polyhaven.com), licence **CC0 1.0** : `autumn_park` (DSC_0158), `blouberg_sunrise_1` (IMG_0623), `christmas_photo_studio_07` (15), `small_cathedral_02` (DSC_0681, DSC_0701), `vignaioli` (DSC07532), `residential_garden` (IMG_0603), `autumn_road` (DSC_0211, photo du calendrier du bureau, `godot/assets/images/bureau/calendrier_2040.png`, par `godot/tools/gen_bureau.py`). Recadrées, vieillies et peuplées de silhouettes dessinées (de dos, à contre-jour ou floues ; visage rayé au stylo sur la photo de classe ; aucun visage généré) par `godot/tools/make_photos.py` : photo du calendrier et `godot/assets/images/photos/`. Détail dans `godot/assets/images/SOURCES.md` et `ASSETS_CC0.md`.

## Textures

- `asphalt_wet_*` (asphalte mouillé de la rue) : [ambientCG](https://ambientcg.com) — licence **CC0 1.0**, via le miroir [itz019/tls-textures](https://github.com/itz019/tls-textures). Redimensionnée en 512 px.

## Ciel

- `moonless_golf_1k.hdr` : [Poly Haven](https://polyhaven.com) — licence **CC0 1.0**, via les exemples de three.js.

## Sons

- **RPG Audio** et **Impact Sounds** par [Kenney](https://kenney.nl) — licence **CC0 1.0**. `godot/assets/audio/*.ogg` et `godot/assets/audio/kenney/` (pas sur béton et moquette, lames de parquet, chocs mous, bois léger, fer-blanc) ; pas du joueur et lattes qui grincent (`godot/assets/audio/pas/`) fabriqués à partir de ces sons par `godot/tools/make_pas.py`.
- `room_tone.wav`, `crt_hum.wav`, `drive_seek.wav`, `rain_loop.wav`, `thunder.wav` : générés pour le jeu par `godot/tools/make_assets.py`.
- Pluie contre les vitres et sur le toit (`rain_glass_1` à `3`, `rain_roof`), respiration du personnage (`breath_*`) : synthétisées pour le jeu par `godot/tools/make_assets.py son`.
- Sons de l'entité (`creature/` : signature, souffle électrique, interférence, imitations de toux, de pantoufles et de coups, à-coups, sursaut) et de la maison (`maison/` : vent, frigo, charpente, tuyaux) : synthétisés pour le jeu par `godot/tools/make_creature.py`, en partie à partir des sons Kenney ci-dessus (CC0).

## Images

- Affiches, mot punaisé, étiquette de disquette, photo de famille, calendrier, tableau en liège, horloge, papiers, manuel, fenêtre d'en face, papier peint, lambris, crasse, décalques (taches, moisissure, griffures, empreintes) : générés pour le jeu par `godot/tools/make_assets.py`.
- Images haute définition de la 0.3.4 (papiers, affiches, étiquettes, calendrier, horloge, liège, tableau des clés, photos, étiquettes des classeurs) : générées par `godot/tools/make_assets.py images` et `godot/tools/make_photos.py`, sur le grain des matières ambientCG `Paper001`, `Paper002`, `Cork003` (CC0) ; photos de fond Poly Haven ci-dessus.
- Décalques d'usure (`godot/assets/decals/gen/` : taches de plafond, moisissure, fissures, suie, usure de passage, empreintes, crasse de pied de mur, masques de crasse HD) : générés pour le jeu par `godot/tools/make_wear.py` ; `decals/gen/acg/` : bords adoucis des décalques ambientCG ci-dessus (CC0).
- Textures de la chambre des grands-parents (`godot/assets/textures/gp/` : couvre-lit matelassé, cheveux, tain du miroir, étiquettes de médicaments aux noms de molécules génériques, sans marque) : générées pour le jeu par `godot/tools/gen_gp.py` (CC0) ; lettrage en IBM Plex Mono.
- Images du bureau (`godot/assets/images/bureau/` : calendrier de la pharmacie, diplôme de la médaille du travail, étiquettes) : générées par `godot/tools/gen_bureau.py`.

## Polices

- VT323 (The VT323 Project Authors, Peter Hull), IBM Plex Mono (IBM Corp.), UnifrakturMaguntia (j. 'mach' wust, Peter Wiegel), Reenie Beanie (James Grieshaber) — via [Google Fonts](https://fonts.google.com), licence **SIL Open Font License 1.1**. Les textes de licence sont à côté des fichiers, dans `godot/assets/fonts/OFL-*.txt` (dans le zip du jeu : dossier `licences/`).
- Inter (Rasmus Andersson, licence **SIL Open Font License 1.1**) : typographie imprimée de certaines images générées (calendrier, horloge) ; seules les lettres déjà dessinées dans les PNG sont livrées, pas la police.
- DejaVu Serif (licence DejaVu / Bitstream Vera, libre) : typographie du diplôme du bureau ; seules les lettres dessinées dans le PNG sont livrées, pas la police.
