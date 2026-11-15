# Crédits et licences des ressources

Le code du jeu RUNTIME est original. Les ressources ci-dessous sont libres de droits ou utilisées sous licence libre, avec attribution. Les chemins valent pour la version Godot (`godot/assets/`) ; la version web en garde une copie dans `public/assets/`.

## Moteur et bibliothèques

- [Godot Engine](https://godotengine.org) 4.7 — licence **MIT** (© Juan Linietsky, Ariel Manzur et les contributeurs de Godot).
- Version web : [three.js](https://threejs.org) (MIT), [Tone.js](https://tonejs.github.io) (MIT), [GSAP](https://gsap.com) (licence standard GSAP), [Vite](https://vitejs.dev) (MIT).

## Modèles 3D

- **Furniture Kit** par [Kenney](https://kenney.nl) — licence **CC0 1.0** (domaine public). `godot/assets/models/kenney/`.
- **Lee Perry-Smith head scan** par Lee Perry-Smith / Infinite-Realities — licence **CC BY 3.0**. Distribué avec les exemples de [three.js](https://github.com/mrdoob/three.js). `godot/assets/models/face/`.

## Modèles et matières photoréalistes (Poly Haven, ambientCG)

Tous sous licence **CC0 1.0** (domaine public), téléchargés depuis [Poly Haven](https://polyhaven.com) et [ambientCG](https://ambientcg.com) (glTF et textures en 1k, 2k pour les grandes surfaces). Le détail (page source, fichiers, nombre de triangles) est dans `godot/assets/ASSETS_CC0.md`, une ligne par asset.

- Modèles Poly Haven (`godot/assets/models/polyhaven/`) : `boombox`, `bleach_bottle`, `cardboard_box_01`, `Chandelier_02`, `ClassicNightstand_01`, `desk_lamp_arm_01`, `dining_chair_02`, `drain_cleaner`, `fancy_picture_frame_01`, `GothicBed_01`, `GothicCabinet_01`, `GothicCommode_01`, `jug_01`, `ornate_mirror_01`, `painted_wooden_cabinet`, `painted_wooden_chair_01`, `painted_wooden_nightstand`, `painted_wooden_shelves`, `painted_wooden_stool`, `plunger`, `potted_plant_04`, `Rockingchair_01`, `side_table_tall_01`, `Television_01`, `vintage_grandfather_clock_01`, `vintage_suitcase`, `wall_clock`, `wicker_basket_02`, `wooden_table_02`.
- Matières Poly Haven (`godot/assets/textures/`) : `herringbone_parquet`, `stair_planks`, `floor_tiles_06`, `decrepit_wallpaper`, `terlenka`.
- Matières ambientCG (`godot/assets/textures/`) : `PaintedPlaster017`, `PaintedWood009C`, `Wood027`, `Tiles133B`, `Carpet016`, `Fabric045`.
- Les papiers peints, le damier et les cartes ORM (occlusion, rugosité) sont retravaillés à partir de ces textures ; le tapis du couloir (`runner_couloir.png`) et le masque de la lampe de poche (`flashlight_cookie.png`) sont générés pour le jeu.

## Textures

- `wall_plaster_dirty_*`, `hospital_floor_*`, `wall_brick_*`, `asphalt_wet_*` (asphalte mouillé de la rue) : [ambientCG](https://ambientcg.com) — licence **CC0 1.0**, via le miroir [itz019/tls-textures](https://github.com/itz019/tls-textures). Redimensionnées en 1024 px (512 px pour l'asphalte).
- `hardwood2_*` : textures de plancher des exemples de [three.js](https://github.com/mrdoob/three.js/tree/dev/examples/textures) (licence MIT du dépôt three.js).

## Ciel

- `moonless_golf_1k.hdr` : [Poly Haven](https://polyhaven.com) — licence **CC0 1.0**, via les exemples de three.js.

## Sons

- **RPG Audio** et **Impact Sounds** par [Kenney](https://kenney.nl) — licence **CC0 1.0**. `godot/assets/audio/*.ogg`.
- `room_tone.wav`, `crt_hum.wav`, `drive_seek.wav`, `rain_loop.wav`, `thunder.wav` : générés pour le jeu par `godot/tools/make_assets.py`.

## Images

- Affiches, mot punaisé, étiquette de disquette, photo de famille, calendrier, tableau en liège, horloge, papiers, manuel, fenêtre d'en face, papier peint, lambris, crasse, décalques (taches, moisissure, griffures, empreintes) : générés pour le jeu par `godot/tools/make_assets.py`.

## Polices

- VT323 (The VT323 Project Authors, Peter Hull), IBM Plex Mono (IBM Corp.), UnifrakturMaguntia (j. 'mach' wust, Peter Wiegel), Reenie Beanie (James Grieshaber) — via [Google Fonts](https://fonts.google.com), licence **SIL Open Font License 1.1**. Les textes de licence sont à côté des fichiers, dans `godot/assets/fonts/OFL-*.txt`.
