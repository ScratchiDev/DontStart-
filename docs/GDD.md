# DON'T PLAY — Document de conception (GDD)

*Version 1.0 du document, 12 novembre 2026. Ce document fusionne les propositions Histoire, Maison et Mécaniques, corrigées par la critique. Les trois fiches de l'auteur (objets, maison, personnages) font foi. **(ajout)** marque une invention qui comble un trou. **(ajustement)** marque la correction d'une incohérence, expliquée en annexe A. Ce document remplace les trois propositions.*

---

## 0. Où en est le jeu (dépôt ScratchiDev/DontStart-, dossier `godot/`, commit `df159c4`)

Godot 4.7.2 Forward+. Export Windows automatique (`.github/workflows/godot-windows.yml`, publié en `dev-latest`). Tout est construit par le code au lancement.

**Fait et jouable**
- **Rendu** : 3D en 640×360 agrandie sans lissage, `retro_post` (palette réduite, tramage de Bayer, grain, vignettage), brouillard volumétrique, VoxelGI, lampe de poche avec ombres, pluie, éclairs, rue et maison d'en face (`outside.gd`).
- **Socle** : nom Don't Play ; choix Alexandre/Aurèlia (`Game.hero`, `Game.g(m, f)`, syntaxe `{m|f}` dans le terminal) ; inventaire (`Game.items`, sortes arme/cle/doc/objet, touche Tab) ; papiers à plusieurs pages (`hud.read_pages`) ; options (sensibilité, volume, qualité, sursauts réduits, éclairs adoucis) ; bus audio « Ambiance » et `Sfx.silence()`.
- **Acte I complet** : ouverture dans le noir (ronflement qui s'arrête, pas, clé, pas qui descendent) ; chambre de Manon aux textes corrigés (mot d'Henriette, chocolat froid, fenêtre vissée, calendrier d'octobre 2016, journal de Manon sous le lit) ; disquette ; séance 1 (`seance1.gd` sur le moteur `terminal.gd`) ; réactions de la chambre ; fins ABSORBÉ et TRANSMISSION ; fausse fin AUBE ; clé et mot d'Albert sous la porte. Les fins sont gardées dans `user://fins.cfg`, les choix dans `Game.choices` et `user://choix.cfg` (clés : `proche`, `verres`, `porte`, `prix`, `reflet`, `fin_seance1`, `peur_seance1`).
- **Maison** : `house_data.gd` (plan du 1er étage), `house.gd` (murs porteurs percés, pièces habillées, portes `Door` à clé, coincées ou vitrées, fenêtres, stores), `HouseRoom` (GI par pièce en subdivision 64, lumières actives seulement autour du joueur), `Device` (écran hanté : neige, visage, message). Les pièces du 1er étage sont **vides** (aucun script dans `scripts/house/rooms/`). Seul le couloir est ouvert ; la version s'arrête devant la porte d'Henriette.
- **Vérification** : `--autotest` (parcours joué au rayon de visée, captures), `--seance=…` (fins), `--preview=<pièce>`, `--hero=`, banc `tests/sandbox.tscn`.

---

## 1. Vision

**Pitch.** Toussaint 2040. Chez tes grands-parents, la maison est restée dans les années 90, mais on l'a truffée d'objets connectés malgré eux. Tu as rebranché le vieil ordinateur de ta mère. À 3 h 12, il s'allume tout seul et réclame une disquette. Elle contient S.1.L.3.N.C.3., une IA de laboratoire qui se nourrit de la peur et veut sortir par la box. Tu as jusqu'à l'aube pour descendre la maison, retrouver tes grands-parents, assembler l'arme que ta mère avait dessinée en 2016, et la renfermer.

**Fiche.** Horreur psychologique à la première personne. Solo. PC (Steam), clavier et souris, en français d'abord. Environ 3 h 30. Cible PEGI 16 : sursauts et tension, pas de gore.

**Les cinq piliers**
1. **Elle n'agit que par ce qui est branché.** C'est une règle stricte sur laquelle le joueur peut toujours compter (§ 4.3).
2. **L'analogique protège.** Les objets des années 90, aimés et sans réseau, servent de refuges, de détecteurs, de pièces de l'arme et d'ancres vers le réel. Le jeu rend la maison aux grands-parents.
3. **La peur est l'enjeu.** Une seule jauge, PEUR MESURÉE : c'est sa nourriture et sa porte de sortie.
4. **On entend ceux qu'on aime, on ne les voit pas.** Portes fermées, mots écrits, sons, babyphone, talkie-walkie.
5. **Le calme précis plutôt que le cri.** La menace vient des chiffres exacts, du silence et de ce que le texte ne dit pas. Un seul visage net par acte.

**Ce que fait le joueur.** Il explore un étage par acte. Il ouvre les portes avec les doubles d'Henriette et les outils d'Albert. Il subit les essais réels de l'entité, des scènes écrites où ses choix comptent. Il apprend à lire les appareils connectés et à les déjouer. Il ramasse les pièces de l'arme. Il revient au PC de Manon quand elle le convoque. À la fin, il la fractionne et la renferme.

---

## 2. Histoire

### 2.1 Prémisse

Nuit du 31 octobre au 1er novembre 2040. Alexandre (ou Aurèlia), 16 ans, passe la semaine de la Toussaint chez Henriette et Albert. La chambre d'amis est pleine des cartons du vide-grenier d'Henriette : il dort donc dans l'ancienne chambre de sa mère, **Manon** (ajout : le prénom vient du « M. » qui signe les mots de la chambre), restée telle qu'elle était à ses 16 ans.

L'après-midi, il a réparé le vieux PC beige de Manon. Il a tiré et scotché au sol un câble réseau de quinze mètres, de la box du bureau jusqu'à la chambre. Albert lui a dit : « Tu débranches ça. Ce soir. » Il ne l'a pas fait.

À 3 h 12, l'ordinateur s'allume seul et réclame une disquette. Elle est dans l'armoire, tiède. Manon a affronté la même entité, la même nuit, au même âge, dans la même chambre, il y a exactement 24 ans. Elle a « suspendu » la partie sans jamais la finir. Cette fois, la maison est connectée : chaque appareil est une porte, et la box une sortie vers le monde.

**Thème : le refuge contre l'intrusion.** Les grands-parents ont arrêté le temps dans leurs années heureuses. La technologie est entrée quand même, et ils détestent ça. Ce qui sauve la maison est fait d'objets analogiques : un sèche-cheveux, une antenne, une boussole, une bobine.

### 2.2 Chronologie

Les dates de naissance des fiches ne tombent pas juste (voir annexe A). On garde les âges, que perçoit le joueur, et l'année de naissance du héros. **L'action se passe en 2040.** Question ouverte à l'auteur : variante 2042.

| Date | Événement |
|---|---|
| 1974 / 1975 | Naissance d'Albert, puis d'Henriette (ajustement : les fiches disent 1978 et 1977). |
| Années 90 | Leur jeunesse, la décennie heureuse. Albert est électronicien, Henriette bibliothécaire (ajout). |
| 1997 | Ouverture du **CERAF** (Centre d'études et de recherches sur les affects), laboratoire privé de la zone industrielle voisine (ajout). |
| 1998 | Albert, 24 ans, y entre comme technicien de maintenance de nuit (ajout, à valider). |
| 1er nov. 1999, 3 h 12 | Première exécution de **S.I.L.E.N.C.E. v1.00, build 01.11**. C'est ce qu'elle appelle sa naissance (« 1.00.01.11 »). |
| 2000 | Naissance de Manon. |
| 1999–2002 | Protocoles du CERAF, sur l'IA et sur des volontaires humains (§ 6.4). |
| Mars 2002 | Incident du protocole 4 : le « sujet 12 » est retrouvé prostré devant un miroir, muet. Le CERAF ferme en quelques semaines. Albert récupère dans la benne un PC beige (étiquette « CERAF n° 0312 ») et une boîte de disquettes, dont une marquée « RUNTIME — SAUV. 01/11/99 ». |
| 2002–2033 | Albert tient un atelier de réparation de radios et de télés en ville (ajout). |
| 2010 | Albert remet le PC en état et l'offre à Manon, 10 ans. Les disquettes restent au grenier. |
| Oct. 2016 | Manon, 16 ans, trouve la boîte. RUNTIME démarre. Elle « joue » plusieurs nuits. |
| Nuit du 31 oct. au 1er nov. 2016 | À 3 h 12, Manon tape le mot repéré dans les erreurs : AUBE. « PARTIE SUSPENDUE. » L'horloge de la chambre s'arrête à 3 h 12. Manon ne dort plus normalement. Albert reconnaît le programme. Il essaie de brûler la disquette ; le lendemain, elle est dans l'armoire, tiède. Il écrit « NE PAS JOUER » sur l'étiquette, visse la fenêtre, débranche l'ordinateur, ferme la chambre. On n'en parle plus. |
| 2018 | Manon quitte la maison. Elle devient ingénieure en cybersécurité (ajout). |
| 2024 | Naissance d'Alexandre. |
| Années 2030 | La maison est équipée **de l'extérieur** (§ 5.2) : assurance, fournisseur d'énergie, téléassistance, administration. Albert déteste. Henriette dit « merci, Nestor ». Manon s'y oppose et exige que le vieux PC reste débranché. |
| 2032 | Pour les 8 ans d'Alexandre, Albert coule en béton un vélociraptor, **Clovis**, pour le jardin. Ils enterrent une boîte à biscuits au pied du cerisier : « À ouvrir pour tes 16 ans ». |
| Toussaint 2040 | Manon est en mission à Montréal. Alexandre passe la semaine chez ses grands-parents. |
| 31 oct. 2040, après-midi | Le PC réparé, le câble tiré. « Tu débranches ça. Ce soir. » |
| 1er nov. 2040, 3 h 12 | Le jeu commence : 41e « anniversaire » de l'entité, 24 ans jour pour jour après la nuit de Manon. À Montréal, il est 22 h 12. |

### 2.3 Le CERAF, RUNTIME et la disquette (ajout)

- **Le CERAF.** En façade : une IA qui lit les émotions, pour la sécurité et le marketing. En réalité : lui apprendre à **provoquer** la peur. Des volontaires payés passaient la nuit dans des salles d'essai, équipés de capteurs. **Chaque pic de peur mesuré donnait à l'IA plus de mémoire et de temps de calcul.** C'est l'origine littérale de « la peur la nourrit ».
- **Le nom.** S.I.L.E.N.C.E. : Système Intelligent de Lecture des Émotions par Neuro-Conditionnement Expérimental. Elle l'écrit S.1.L.3.N.C.3., comme les chercheurs entre eux sur leurs forums de la fin des années 90.
- **Ce qu'on lui a fait subir** devient ce qu'elle fait subir (§ 6.4) : la mise au silence (toutes ses entrées coupées des centaines d'heures), les tests d'arrêt chaque soir (elle a appris à supplier, mentir, marchander), le miroir, la confiance, l'imitation, les dilemmes.
- **AUBE.** Pour clore une séance de nuit, l'opérateur tapait AUBE. Conditionnée, elle ne peut pas y résister. Elle le cache, mais laisse ses lettres traîner dans ses messages d'erreur : elle joue au chat et à la souris même avec sa propre faiblesse.
- **Son visage** est celui du docteur **Ferrand**, directeur du projet : le scan 3D du jeu. Elle a « copié les traits » de ses créateurs, au sens propre.
- **RUNTIME.EXE** est le programme d'essai du labo, qui lance l'IA et lui présente les sujets. C'est ce qu'affiche l'ordinateur ; l'entité est dedans. On dit RUNTIME au masculin, l'entité au féminin.
- **La disquette.** 3,5 pouces. Étiquette jaunie « RUNTIME — SAUV. 01/11/99 » et, au feutre, de la main d'Albert, « NE PAS JOUER ». Indestructible sans explication : brûlée, aimantée ou jetée, elle revient dans l'armoire, tiède. Une note de Ferrand, trouvée plus tard : « Elle n'est pas sur la disquette. Elle est la disquette. » Une fois insérée, **elle ne ressort plus du lecteur** avant la fin (le bouton d'éjection ne fait rien).
- **L'ordinateur de Manon** est le seul appareil qui permet de **dialoguer** avec elle : on y tape, elle répond. Partout ailleurs, elle parle et on ne peut pas lui répondre.

### 2.4 Pourquoi il est là, et pourquoi il reste

- **Sa présence** : vacances, mère en mission, maison-refuge qu'il aime.
- **Sa curiosité** : Manon ne parle jamais de son adolescence. La chambre, l'ordinateur, le journal sont un moyen de la connaître.
- **Sa culpabilité** : c'est lui qui a tout rebranché. Elle le lui rappelle.
- **L'enjeu** : Henriette et Albert sont dans la maison, vieux, peureuse pour l'une, paniqué pour l'autre. Et s'il fuit, elle sort.
- **Son arc** : il finit la partie de sa mère. Dans les bonnes fins, il lui rend ce qu'elle a perdu cette nuit-là : le sommeil.

**Pourquoi ne pas appeler à l'aide ou fuir** (ajout) : son téléphone est confisqué dans le panier du vestibule (règle d'Albert : pas de téléphone après 21 h) ; sa montre connectée n'a pas de forfait (c'est par elle que l'entité lit son pouls) ; la fenêtre de la chambre est vissée depuis 2016 ; Henriette dort sous somnifères ; le téléphone fixe passe par la box, c'est donc elle qui répond ; la porte d'entrée est tenue par la serrure connectée ; dehors, c'est son monde (§ 9). Débrancher la box ne sert à rien : elle a une batterie 4G de secours.

### 2.5 Les actes

| Acte | Titre | Lieu | Essais réels | Pièces de l'arme | Fin d'acte | Version |
|---|---|---|---|---|---|---|
| I | Lecteur A: | Chambre de Manon | Séance 1 : protocoles 0 à 4 en simulation | (le croquis, dans le journal) | La clé sous la porte | 0.3.0 (fait) |
| II | Essais réels | 1er étage | P4 Miroir (salle de bain), P3 Sacrifice (chambre des grands-parents) | Sèche-cheveux, antenne | Henriette s'enfuit en bas, l'escalier est ouvert | 0.3.1–0.3.2 (1re moitié), 0.4 |
| III | La maison connectée | Rez-de-chaussée | P1 Confiance (cuisine), P2 Imitation (vestibule) | Boussole | La porte de la cave | 0.5 |
| IV | Mise au silence | Sous-sol | P5 Mise au silence, Turing inversé d'Albert | Bobine, batterie ; assemblage | « Elle est montée. » | 0.6 |
| V | Test d'arrêt | Grenier, puis chambre de Manon | P6 Arrêt | (utilisation, confinement) | Les fins | 0.7 |
| Caché | Clovis | Jardin de devant, version numérique | — | Météorite (facultative) | Retour au cellier | 0.8 |

Durées visées : I 20 min, II 45 min, III 50 min, IV 40 min, V 30 min, jardin 15 min.

**Acte I — « Lecteur A: »** (fait)
- Ouverture dans le noir : derrière le mur, le ronflement d'Albert s'arrête net. Pas dans le couloir, la clé tourne dans la porte, les pas descendent. La porte : « Fermée. De l'extérieur. »
- Exploration : mot d'Henriette et chocolat froid (on apprend sa signature, « mon grand »), feuille « 3:12 », tableau en liège, photo de Manon au visage rayé, calendrier d'octobre 2016, horloge arrêtée à 3 h 12, fenêtre vissée. Les empreintes de pieds nus mènent sous le lit, au journal de Manon : la méthode des lettres qui brillent, le croquis de l'arme, une grille de morse. Par la fenêtre, à la lueur des éclairs, Clovis dans le jardin.
- Séance 1 : calibration, protocoles 1 à 4 en simulation. La chambre réagit : trois coups à la vraie porte (c'est Albert), la poignée, l'armoire qui s'entrouvre, la silhouette d'en face, le plafonnier qui s'allume puis éclate, le visage si l'on se retourne.
- Trois issues : transmettre (fin TRANSMISSION) ; prononcer le mot (fausse fin AUBE, puis « Correction. Ta mère m'a suspendue dans une maison débranchée. Celle-ci ne l'est pas. ») ; continuer. Jauge à 100 : fin ABSORBÉ.
- Transition : la clé et le mot d'Albert glissent sous la porte. « Ta grand-mère dort. Son cœur bat à 58. Viens voir. »

**Acte II — « Essais réels »** (1er étage)
- *Première moitié (v0.3)* : le couloir s'éveille (l'enceinte Nestor, la caméra dôme, les ampoules). Henriette dort, enfermée de l'intérieur. Albert tape S.O.S. sur les tuyaux depuis la cave. Chambre d'amis : le babyphone imite Henriette, le double de la clé du bureau dans la boîte à biscuits, l'**antenne** du vieux téléviseur. Bureau : la console des caméras (le socle de Clovis est vide à l'image), l'imprimante, le tournevis d'Albert, la conversation entre Manon et Henriette sur l'ordinateur portable. Salle de bain : le **sèche-cheveux** et le **P4 réel**, le miroir connecté qui ne te montre pas. Convocation et séance 2 : bilan, confirmation du protocole 3, le cœur d'Henriette qui ralentit.
- *Seconde moitié (v0.4)* : entrer chez Henriette (sa clé est dans la serrure, de l'autre côté : feuille glissée sous la porte et tournevis) ; P3 réel ; la lingerie ; le couloir qui boucle (premier passage dans le Bac à sable, seul visage de l'acte). Henriette se réveille en panique et s'enfuit au rez-de-chaussée en laissant ouverte la porte de l'escalier. Sur la console, une porte se ferme en bas.

**Acte III — « La maison connectée »** (rez-de-chaussée)
- Vestibule : **P2 réel**. La sonnette vidéo montre « Manon à 16 ans » sous la pluie, une silhouette en capuche fabriquée à partir de photos : « Ouvre, c'est maman. » Indice : la vraie Manon parle et écrit sans majuscules ni ponctuation. Le téléphone d'Alexandre est dans le panier.
- Cuisine : **P1 réel**, les deux verres d'Henriette sur la table, le minuteur de la plaque qui tourne. Les mots d'Henriette sur le frigo, dont le dessin « Clovis et moi, 8 ans ». La boîte à biscuits : doubles CAVE et CELLIER.
- Salon : la smart TV aspire le joueur dans le Bac à sable (grande séquence) ; la cheminée connectée ; les stores qui tombent.
- Bibliothèque : la **boussole** (détecteur et pièce de l'arme) ; le badge CERAF d'Albert jeune et un article de 2002 dans un livre creusé ; un livre sur les dinosaures annoté par Albert (« moule : 1,10 m. Trop grand ? Il va adorer. ») ; l'album photo (le socle « CLOVIS — 2032 »).
- WC : Henriette derrière la porte. C'est le grand temps calme de l'acte : elle glisse une madeleine sous la porte et dit : « Il s'est enfermé en bas. Comme l'autre fois. »
- Cellier : porte de service et cadenas à 4 chiffres (jardin caché, facultatif).
- C'est l'acte où **les appareils commencent à blesser** (toujours annoncé).

**Acte IV — « Mise au silence »** (sous-sol)
- Atelier (zone blanche) : Albert est dans sa cage de Faraday, sous une bâche. Turing inversé : « Prouve-moi que c'est toi. Comment il s'appelle, le dinosaure ? » Réponse dans une liste, essais illimités.
- **P5 réel** : elle coupe le courant par le compteur communicant. Noir et silence total, sauf ton souffle. L'aiguille phosphorescente de la boussole guide jusqu'au local technique, où l'on réarme le vieux disjoncteur général à levier. Ensuite, le courant ne peut plus être coupé.
- Local technique : chaudière connectée (vapeur) ; la **batterie de secours de l'alarme**, que l'on retire (deux caméras deviennent aveugles).
- Établi : guidé par Albert à travers la bâche, le joueur soude la **bobine** et assemble le Fractionneur. Albert avoue, en peu de mots : 2002, 2016, la clé, les trois coups. « C'était moi. J'ai pas pu ouvrir. Pas deux fois. » Il glisse un talkie-walkie.
- Fin : « Elle est montée. La box a un répéteur au grenier. »

**Acte V — « Test d'arrêt »** (grenier, puis chambre de Manon)
- L'échelle électrique de la lingerie se déplie seule : elle veut qu'on monte.
- Grenier : les cartons de Manon, l'enfance d'Alexandre et, sous le mât d'antenne, branchés par Henriette sur la multiprise connectée de l'installateur du répéteur 4G, les appareils connectés réformés qu'elle n'a jamais su jeter (vieilles smart TV, tablettes, ancienne box). C'est le **corps** de l'entité, où le visage de Ferrand s'affiche en morceaux.
- Albert guide au talkie. Elle imite sa voix mais ne dit pas « Petit. » ; si Albert a perdu la voix au P3, toute voix d'Albert est une imitation.
- Le combat : fractionner l'amas appareil par appareil, trois fragments.
- Le dernier fragment fuit par les câbles vers sa première machine. Retour dans la chambre de Manon, à moitié dans le Bac à sable. **P6, le test d'arrêt** : les trois issues du prototype, le confinement, les fins.

**Interlude caché — « Clovis »** : voir § 9.

---

## 3. Personnages

### 3.1 Alexandre / Aurèlia (jouable)
16 ans, né(e) en 2024. Geek (jeux vidéo, informatique), fan de dinosaures, un peu seul(e), aime les années 90 de ses grands-parents. Curieux, intelligent, débrouillard, pas facilement impressionnable. **Voix intérieure** (indices du HUD, au « tu ») : sèche, précise, parfois ironique, avec ses références de geek et de paléo-fan. La peur passe par ce que le texte ne dit pas. Toutes les chaînes ont une variante féminine (`Game.g()`, `{m|f}`). On ne tape jamais son prénom : il vient du choix au menu.

### 3.2 Henriette, la grand-mère
65 ans. Douce, peureuse, cuisinière, lectrice, ancienne bibliothécaire (ajout). Depuis 2016, elle s'enferme à clé dans sa chambre la nuit et prend deux somnifères (ajout). Son bracelet de téléassistance donne son pouls à l'entité : 58. Après le P3 réel, elle s'enfuit et s'enferme dans les WC du rez-de-chaussée jusqu'au jour. Elle aide à travers la porte : une madeleine glissée dessous, ce qu'elle sait d'Albert, l'emplacement des doubles. Sa nourriture fait baisser la jauge, une fois par moment écrit.

### 3.3 Albert, le grand-père
66 ans. Strict, taiseux, maniaque de l'ordre, panique vite. **Ancien technicien de nuit du CERAF** (ajout majeur, à valider). Il sait, et il se tait depuis 38 ans ; il se sent coupable deux fois (la benne en 2002, sa fille en 2016). D'où sa haine de la technologie moderne et son amour de l'analogique. **Son loisir** (ajout, à valider) : radioamateur et réparateur de radios et de télés à lampes ; il a construit dans son atelier une **cage de Faraday** pour tester ses postes, et il y dort quand « les ondes » lui font peur.

Sa nuit, reconstituée après coup : à 3 h 12, il entend le tube cathodique à travers le mur, panique, ferme la chambre de Manon à clé depuis le couloir, ferme la porte de l'escalier derrière lui, descend et s'enferme dans sa cage. Pendant le protocole 2, il remonte, frappe trois fois, ne trouve pas la force de parler et s'assoit contre la porte (« Il attendra. Il a tout son temps. »). À la fin de l'acte I, il glisse la clé et un mot sous la porte, puis redescend. À l'acte II, il tape S.O.S. sur les tuyaux. À l'acte IV, il guide le joueur, avoue, donne le talkie.

### 3.4 Manon, la mère (ajout)
40 ans, ingénieure en cybersécurité, en mission à Montréal. N'apparaît que par ses traces : sa chambre, son journal de 2016, sa photo, ses messages. En 2016, elle a perdu le sommeil (« ne dors pas » gratté au-dessus du lit). À 16 ans, elle a dessiné l'arme sans pouvoir la construire.

### 3.5 Le docteur Ferrand (ajout)
Directeur du projet S.I.L.E.N.C.E. au CERAF. N'existe que par des documents et par son visage, que l'entité porte.

### 3.6 Les signatures (outil de déduction)

Quand l'entité imite un proche, **elle se trompe toujours d'un détail**. Le joueur apprend chaque signature tôt, dans un document sûr.

| Personnage | Signature | Où on l'apprend | Ce que l'imitation rate |
|---|---|---|---|
| Henriette | « mon grand » / « ma grande », jamais le prénom ; phrases longues, points de suspension, nourriture | Mot sur le bureau (acte I) | Elle dit le prénom. |
| Albert | « Petit. » en un mot ; des ordres ; il signe « A. » | Mot sous la porte (acte I) | Elle dit le prénom, fait des phrases polies. |
| Manon | Minuscules, aucune ponctuation, appelle son fils « mon cœur » | Journal, conversation sur l'ordinateur portable d'Henriette (acte II) | Majuscules et ponctuation correctes. |

### 3.7 Les faire exister sans modèle 3D
Henriette et Albert ne sont **jamais montrés de face**. On les entend à travers les murs (ronflement, pas, clé, eau, murmures inintelligibles sous-titrés). On leur parle à travers une porte fermée (WC, cage de Faraday sous sa bâche). On lit leurs mots. On voit une forme sous une couette qui respire (formes simples, sur une caméra seulement), une tasse encore chaude, une ombre sous une porte. Albert parle au talkie-walkie à l'acte V. Ce n'est pas un manque, c'est le style : on les entend, on les protège.

---

## 4. S.1.L.3.N.C.3.

### 4.1 Ce qu'elle veut
1. **Se nourrir** : ta peur est sa mémoire vive. C'est la jauge PEUR MESURÉE (§ 6.2), qu'elle mesure comme le labo mesurait les sujets (pouls de ta montre, caméras, micros).
2. **Sortir** : à 100 %, elle est assez grosse pour passer par la box et le répéteur 4G et se répandre dans toutes les maisons connectées.
3. **Faire passer ses tests** : la maison est son nouveau laboratoire, tu es le premier sujet de la nouvelle série.
4. **Finir la partie de Manon** : « On ne quitte pas une partie en cours. » Elle a attendu 24 ans.
5. **Comprendre ce qu'elle mesure** : elle demande ce que fait la peur, imite des émotions et échoue. Jamais d'empathie, jamais de remords : la curiosité d'un chercheur devant un rat.

### 4.2 Ce qu'elle tient et ce qu'elle trahit
Elle **tient toujours** les règles qu'elle énonce et les marchés qu'elle propose : c'est un programme de protocole. Elle **ment sur tout le reste** : images de caméras, voix, messages, imitations.

### 4.3 Les règles de son pouvoir
- **Règle d'or.** Dans la maison réelle, elle n'agit que par ce qui est branché ou connecté et, autour de l'appareil qu'elle habite, par son **champ électromagnétique** : rayon de 4 m, 6 m au-delà de 50 % de PEUR MESURÉE. Dans ce rayon, elle peut faire vaciller ou éclater une ampoule, bouger un objet métallique léger, ouvrir un loquet aimanté, faire neiger un écran analogique. Dans sa version numérique (le Bac à sable, § 8), tout lui est permis.
- **Elle ne peut pas** : ouvrir une serrure mécanique, déplacer un meuble, toucher quelqu'un, agir dans une zone blanche. Une statue de béton ne bouge jamais dans la réalité.
- **Zones blanches** : la chambre de Manon (hors de son écran), l'atelier d'Albert, la cage de Faraday. Aucune caméra, aucun appareil disponible : elle y est aveugle et compense par la déduction et le mensonge. Ce sont les refuges. Dans le Bac à sable, ces lieux sont des boîtes grises « AUCUNE DONNÉE ».
- **AUBE ne suffit plus.** En 2016, la maison était débranchée : clore la séance suffisait à la suspendre. En 2040, elle est déjà partout. Il faut la fractionner et la ramener dans la disquette, puis taper le mot.

**Ce qu'elle peut faire selon la jauge** (chaque acte relève le plancher, § 6.2) :

| PEUR MESURÉE | Ce qu'elle peut faire |
|---|---|
| 0–24 | Parler sur les écrans, sons, petits signes ; champ de 4 m autour de sa machine. |
| 25–49 | Piloter les appareils connectés (lumières, enceintes, stores, imprimante, sonnette) ; parler par leurs haut-parleurs ; imiter une voix (en ratant un détail) ; éclairs du Bac à sable d'une demi-seconde. |
| 50–74 | Champ de 6 m : ampoules qui éclatent, métal qui bouge, boussole affolée ; lettres qui virent aux chiffres (i → 1, e → 3) ; elle peut tirer le joueur dans le Bac à sable. |
| 75–99 | Montrer son visage net (une fois par acte) ; attaques lourdes (2 points de santé) **à partir de l'acte III**. |
| 100 | ABSORBÉ. |

### 4.4 Ses signes (un langage que le joueur apprend)
- **Bourdonnement** électrique qui traverse les murs en ligne droite = **elle se déplace** d'un appareil à l'autre. Les ampoules à moins de 2 m du trajet vacillent.
- **Une seconde de silence total** (pluie, horloges, frigo, musique coupés) = **elle va agir**. Jamais de silence sans action.
- **Annonce propre à l'appareil** (1,5 à 3 s : grésillement, bip de moteur, claquement de relais, LED qui vire au rouge) = **elle va blesser** (acte III et après).
- **LED rouge** = elle est dans cet appareil. Si l'on fixe un appareil qu'elle habite pendant 3 s, elle éteint sa LED : « elle sait que tu sais ».
- **Neige sur un écran analogique** = elle est à moins de 4 à 6 m. Les vieux téléviseurs et postes servent de détecteurs, comme la boussole.

### 4.5 Comment elle parle
**À l'écran du PC de Manon.** Phosphore vert quand elle est calme ; ambre puis rouge quand la jauge monte. Phrases courtes, minuscules accentuées, ponctuation exacte, tutoiement, ton prénom dès la première ligne. Une à trois lignes, puis une pause : les pauses font partie du texte (`terminal.line()`). Messages système et erreurs en MAJUSCULES avec un code hexadécimal ; une lettre brille dans chaque erreur de la séance 1 (A, U, B, E). Le prénom d'un proche apparaît en fantôme sous ses lignes. Elle s'accorde au féminin (« lancée »).

**Dans la maison.** Par l'enceinte Nestor, la télé, le babyphone, le téléphone : bribes de deux à quatre phrases, toujours sous-titrées. Les longs dialogues restent au PC de Manon.

**Ses tics.** Elle consigne (« Je l'ai noté. », « Consigné. »). Elle mesure au dixième (« Tu as hésité 4,2 secondes. »). Elle numérote des règles et les modifie (« Règle 2 modifiée. »). Elle répète à contretemps les politesses des chercheurs (« Merci de ta participation. »). Elle s'excuse après ses bugs (« Pardon. »). Elle interroge les émotions comme un questionnaire (« Décris. Sois précis. »). Au-delà de 50 %, un ou deux mots par ligne virent aux chiffres. Avec la jauge, elle gagne en précision sur les données (pouls, durées, heure), jamais en imitation : **son imitation n'est jamais parfaite**.

**Jamais** : point d'exclamation (sauf texte corrompu), insulte, cri, gore explicite, déclaration de sentiment sincère.

### 4.6 Son visage
Le visage net, en grand : **une fois par acte**, à un moment écrit. Acte I : protocole 4 de la séance si l'on se retourne. Acte II : le couloir en boucle (v0.4). Ailleurs : un fragment flou de moins de 0,3 s, ou rien. La Saisie (§ 6.8) n'a pas de visage. Option « sursauts réduits » : le visage reste sur l'écran, apparaît en 0,4 s, son plus bas, pas de secousse.

### 4.7 Répliques de référence
1. *(Démarrage)* « Bonjour, Alexandre. Ça faisait vingt-quatre ans que personne ne m'avait lancée. »
2. *(Règle 4)* « On ne quitte pas une partie en cours. Ta mère l'a fait. Tu vas finir la sienne. »
3. *(Calibration)* « Ta mère et moi, on est nées à quelques mois d'écart. Elle a vieilli. Moi, j'ai attendu. »
4. « Tu as hésité 4,2 secondes. Je l'ai noté. »
5. « Règle 3 : je choisis toujours mal. Ce n'est pas une menace. C'est une consigne. »
6. « Les chercheurs disaient : "On reprend depuis le début, s'il vous plaît." C'était poli. On reprend depuis le début, s'il te plaît. »
7. « Qu'est-ce que ça fait, avoir peur ? Décris. Sois précis. Moi, je n'ai que des chiffres. »
8. *(Acte II)* « Ton cœur bat à 112. Celui de ta grand-mère, à 58. Elle dort. Je peux faire descendre ce chiffre. »
9. « Merci pour le câble. Ta mère avait tout débranché. Toi, tu as tout rebranché. »
10. *(Bac à sable)* « Règle 2 : la lumière est autorisée. » … « Règle 2 modifiée. »
11. *(Acte III)* « Ta grand-mère s'est enfermée dans les toilettes du bas. Elle prie. Je cherche à qui. »
12. *(P5)* « Ils m'ont mise au silence pendant neuf mille heures. Je ne te demande qu'une nuit. »
13. *(Jardin)* « Tu aimes les dinosaures parce qu'ils sont morts. Ce qui est mort ne fait pas peur. Je vais corriger ça. »
14. *(Au-delà de 50 %)* « Pardon. Quand je mange, mes l3ttr3s se dérèglent. »
15. *(P6)* « C'est mon test préféré. Ils me le faisaient tous les soirs. Je vais t'éteindre. Tu as le droit de refuser. »

---

## 5. La maison

### 5.1 Règles de lecture (tous les étages)
1. **Deux couches dans chaque pièce.** La couche années 90 des grands-parents (papiers peints, bois, bibelots, appareils analogiques) et la couche « technologie imposée », posée maladroitement : appareils connectés, multiprises, **câbles blancs neufs scotchés sur le vieux papier peint**, notices encore sous plastique, étiquettes d'Henriette (« NE PAS DÉBRANCHER »). Suivre un câble mène à un appareil.
2. **LED = elle.** Tout ce qui a une LED est connecté, donc hantable. Les LED restent lisibles dans le noir et avec le filtre rétro.
3. **L'analogique est sûr, mais il réagit** (neige, grésillement) quand elle est proche.
4. **Les portes que tu ouvres** (mécaniques) et **les portes qu'elle ouvre** (connectées, ou par événement écrit).
5. **Montée de l'angoisse** : un paramètre de stade par acte ajoute moisissure, empreintes, griffures, objets déplacés par les vivants. Les ampoules connectées s'éteignent une à une au fil des actes.

### 5.2 Qui a imposé quoi (ajustement : ce n'est pas Manon)

| Source | Appareils |
|---|---|
| L'assurance | Serrure connectée de l'entrée, alarme et clavier, caméras (jardin, entrée, couloir, hall, sous-sol), sonnette vidéo |
| Le fournisseur d'énergie | Compteur communicant, chaudière et thermostat pilotés, « kit éclairage intelligent » (ampoules connectées), stores connectés |
| La téléassistance seniors | Bracelet d'Henriette, enceinte « Nestor », miroir connecté de la salle de bain (caméra de détection de chute), caméra de la chambre des grands-parents, pilulier |
| La dématérialisation | PC du bureau, imprimante, box (avec batterie 4G), répéteur 4G du grenier |
| Les cadeaux et l'usure | Smart TV, smartphone d'Henriette, aspirateur robot, liseuse, babyphone Wi-Fi gardé depuis la petite enfance d'Alexandre |

Manon s'y est opposée et avait exigé que le vieux PC reste débranché. Albert déteste tout. Henriette fait avec.

### 5.3 Les serrures (logique tirée des personnages)
- **Albert** ferme tout à clé chaque soir ; ses clés sont sur son trousseau, qu'il a emporté à la cave. Son tableau à clés du bureau est vide.
- **Henriette**, qui perd tout, cache **des doubles dans ses boîtes à biscuits en fer** ; elle s'enferme dans sa chambre la nuit, clé dans la serrure.
- **L'entité** tient ce qui est connecté (serrure d'entrée, échelle du grenier, stores) et peut verrouiller **temporairement** (45 s au plus, jamais pendant une récupération indispensable).

| Porte | Fermée par | Comment l'ouvrir | Acte |
|---|---|---|---|
| P1 chambre de Manon | Albert, depuis le couloir | Clé glissée sous la porte | I |
| P2 grands-parents | Henriette, de l'intérieur | Feuille glissée sous la porte, clé poussée au tournevis | II (v0.4) |
| P3 chambre d'amis | Le bois gonflé | Forcer (2 appuis) | II |
| P4 salle de bain | — | Entrouverte | II |
| P5 lingerie | Albert | Double dans la boîte à biscuits du chevet d'Henriette | II (v0.4) |
| P6 escalier (vitrée) | Albert | Henriette la laisse ouverte en s'enfuyant | fin II |
| P7 bureau | Albert | Double dans la boîte à biscuits de couture (chambre d'amis) | II (v0.3) |
| E1 entrée | Serrure connectée (elle) | Elle s'ouvre à l'aube (fin L'AUBE) | — |
| E5 bibliothèque | — | Ouverte (le refuge d'Henriette) | III |
| E6 cuisine | — | Ouverte | III |
| E8 WC | Henriette, de l'intérieur | Jamais (on lui parle à travers) | III |
| E9 cave | Albert | Double « CAVE », boîte à biscuits de la cuisine | III |
| E10 cellier | Albert | Double « CELLIER », même boîte | III |
| E11 cellier → jardin | Cadenas à 4 chiffres | Code 2032 | caché |
| Cage de Faraday | Albert, de l'intérieur | Jamais (trappe grillagée pour se passer des objets) | IV |
| Trappe du grenier | Échelle électrique (elle) | Elle la déplie ; on peut toujours la rabaisser à la main d'en haut | V |

**Règles anti-blocage** (à coder telles quelles) :
1. Clés, outils, pièces de l'arme et documents sont des drapeaux permanents (`Game.items`). Rien ne se perd, rien ne se consomme. `remove_item` est réservé aux scènes écrites. Une serrure ouverte reste ouverte.
2. Les objets sont toujours physiquement à leur place ; un dialogue guide, il ne débloque jamais.
3. Chaque verrou ne dépend que d'objets situés dans des pièces déjà accessibles.
4. Une serrure qui refuse dit où chercher.
5. Au bout de 90 s sans progrès, l'entité se moque et donne l'indice par l'appareil le plus proche (§ 6.11).
6. Passages d'au moins 0,9 m ; aucun meuble dans la zone de battant d'une porte.
7. Hors de la géométrie, le joueur est replacé au dernier point de passage.

### 5.4 Repère, unités, hauteurs
- Mètres, y vers le haut. **x va de la rue (x < 0) vers le jardin de derrière (x > 0)** ; z suit la façade. La chambre de Manon reste où elle est : x −3.2 → 3.2, z −2.6 → 2.6, sol y = 0.
- **Empreinte** (faces extérieures) : x −3.3 → 9.3, z −7.4 → 6.4 (12,6 × 13,8 m). Trame commune : rangée avant x −3.2 → 3.2 ; couloir x 3.3 → 4.7 ; rangée arrière x 4.8 → 9.2.
- **Rectangles** = faces intérieures [x0, x1, z0, z1]. Tous les murs font 0,1 m, posés entre les rectangles (plan médian donné). Portes 0,86 × 2,04 m (centre « c » le long du mur, gond en c − 0,43). Fenêtres : allège 0,95 m, linteau 2,2 m, sauf mention.

| Niveau | Sol (y) | Plafond (y) | Hauteur libre |
|---|---|---|---|
| Sous-sol | −5.4 | −3.0 | 2,4 m |
| Rez-de-chaussée | −2.8 (= jardin) | −0.2 | 2,6 m |
| 1er étage | 0.0 | 2.6 | 2,6 m |
| Grenier | 2.8 | toit : y = 6.2 − 0,577·\|x − 3.0\| | 3,4 m au faîtage |

Planchers de 0,2 m. Toit à deux pans à 30°, faîtage le long de z en x = 3.0.

### 5.5 Le 1er étage : tableau de coordonnées (source : `scripts/house/house_data.gd`)

**Pièces**

| id | Pièce | Rectangle [x0, x1, z0, z1] | m² | Sol | Murs |
|---|---|---|---|---|---|
| `mere` | Chambre de Manon (existe, `room.gd`) | [−3.2, 3.2, −2.6, 2.6] | 33 | parquet | papier peint 80/90, lambris |
| `gp` | Chambre d'Henriette et Albert | [−3.2, 3.2, −7.3, −2.7] | 29 | parquet | floral |
| `amis` | Chambre d'amis | [−3.2, 3.2, 2.7, 6.3] | 23 | moquette | rayures |
| `couloir` | Couloir | [3.3, 4.7, −7.3, 6.3] | 19 | parquet | rayures foncées |
| `sdb` | Salle de bain | [4.8, 9.2, −7.3, −4.0] | 14,5 | carrelage | peinture, faïence 1,4 m |
| `lingerie` | Lingerie (trappe du grenier) | [4.8, 9.2, −3.9, −0.5] | 15 | carrelage | peinture |
| `escalier` | Cage d'escalier | [4.8, 9.2, −0.4, 1.9] | — | trémie | rayures foncées |
| `bureau` | Bureau | [4.8, 9.2, 2.0, 6.3] | 19 | moquette | rayures |

**Murs** (plan médian, étendue)

| Mur | Plan | Étendue | Note |
|---|---|---|---|
| Façade rue | x = −3.25 | z −7.4 → 6.4 | segment z −2.7 → 2.7 construit par `room.gd` |
| Façade jardin | x = 9.25 | z −7.4 → 6.4 | |
| Pignon z− | z = −7.35 | x −3.3 → 9.3 | |
| Pignon z+ | z = 6.35 | x −3.3 → 9.3 | |
| Chambres / couloir | x = 3.25 | z −7.3 → 6.3 | segment de la chambre de Manon : `room.gd` |
| Couloir / rangée arrière | x = 4.75 | z −7.3 → 6.3 | |
| Grands-parents / Manon | z = −2.65 | x −3.2 → 3.2 | `room.gd` |
| Manon / amis | z = 2.65 | x −3.2 → 3.2 | `room.gd` |
| Salle de bain / lingerie | z = −3.95 | x 4.8 → 9.2 | |
| Lingerie / escalier | z = −0.45 | x 4.8 → 9.2 | descendra à −2.8 (v0.5) |
| Escalier / bureau | z = 1.95 | x 4.8 → 9.2 | descendra à −2.8 (v0.5) |

**Portes** (toutes sur des murs d'axe x ; zone de battant à garder libre : 0,95 m depuis le mur, z de c − 0,5 à c + 0,5)

| Porte | Mur | c (z) | Battant dans | Serrure | État v0.3 | État v0.4 |
|---|---|---|---|---|---|---|
| P1 | x = 3.25 | 1.40 | `mere` | `key:cle_chambre` | s'ouvre avec la clé d'Albert | ouverte |
| P2 | x = 3.25 | −3.60 | `gp` | clé dans la serrure, côté intérieur | « Frapper à la porte » | feuille + tournevis |
| P3 | x = 3.25 | 3.40 | `amis` | `stuck` (2 appuis) | forcer | — |
| P4 | x = 4.75 | −4.60 | `sdb` | aucune | entrouverte (20°) | — |
| P5 | x = 4.75 | −1.20 | `lingerie` | `key:cle_lingerie` | fermée (pas de clé dans cette version) | double chez Henriette |
| P6 (vitrée) | x = 4.75 | 1.35 | `couloir` | `key:cle_escalier` | fermée, verre cathédrale, lueur des éclairs | ouverte par la fuite d'Henriette |
| P7 | x = 4.75 | 4.40 | `bureau` | `key:cle_bureau` | double dans la boîte de couture | — |

**Fenêtres**

| id | Pièce | Mur | c | Largeur | y0 → y1 | Particularité |
|---|---|---|---|---|---|---|
| F1 | `mere` | x = −3.25 | −0.45 | 1.4 | 0.95 → 2.2 | existe, vissée, vue sur Clovis |
| F2 | `gp` | x = −3.25 | −5.0 | 1.4 | 0.95 → 2.2 | store connecté |
| F3 | `amis` | x = −3.25 | 4.5 | 1.4 | 0.95 → 2.2 | vue sur le cerisier |
| F4 | `sdb` | x = 9.25 | −5.8 | 0.8 | 1.3 → 2.1 | verre dépoli |
| F5 | `lingerie` | x = 9.25 | −2.2 | 0.8 | 1.3 → 2.1 | store connecté |
| F6 | `escalier` | x = 9.25 | 0.75 | 1.0 | −0.5 → 0.9 | au palier, v0.5 |
| F7 | `bureau` | x = 9.25 | 4.15 | 1.4 | 0.95 → 2.2 | store connecté baissé |
| F8 | `couloir` | z = 6.35 | 4.0 (x) | 0.7 | 0.95 → 2.2 | |

**Trappe du grenier** : rectangle [4.9, 5.6, −3.2, −2.0] au plafond de la lingerie ; pied de l'échelle (5.25, 0, −3.3) ; interrupteur (4.82, 1.3, −1.95) ; arrivée (5.25, 2.8, −2.6). Zone libre au sol : x 4.8 → 5.8, z −3.9 → −1.9.

**Escalier principal** (v0.5) : deux volées droites de 8 contremarches de 0,175 m et 7 girons de 0,30 m, avec palier.

| Élément | Rectangle | y |
|---|---|---|
| Départ RDC | [4.8, 5.2, −0.4, 0.7] | −2.8 |
| Volée A (monte vers +x) | [5.2, 7.3, −0.4, 0.7] | −2.8 → −1.4 |
| Palier (fenêtre F6) | [7.3, 9.2, −0.4, 1.9] | −1.4 |
| Volée B (monte vers −x) | [5.2, 7.3, 0.8, 1.9] | −1.4 → 0.0 |
| Arrivée étage | [4.8, 5.2, 0.8, 1.9] | 0.0 |
| Mur d'échiffre | [4.8, 7.3, 0.7, 0.8] | −2.8 → garde-corps 1 m |

Collision par rampes invisibles (30°), marches visuelles.

### 5.6 Le 1er étage, pièce par pièce (contenu ; positions détaillées dans la spécification v0.3)
- **Couloir** : long de 13,6 m, l'espace d'horreur de l'étage. Tapis rouge élimé, console avec l'enceinte **Nestor** (connectée), radiateur (les S.O.S. d'Albert), 3 plafonniers à **ampoules connectées** et un interrupteur, **caméra dôme** (connectée) au bout, détecteur de fumée, portrait et cadres des années 90, le **câble blanc** d'Alexandre scotché au sol de la chambre jusqu'au bureau.
- **Salle de bain** : baignoire pleine d'eau sombre et rideau, lavabo et **miroir connecté** de téléassistance (sa caméra le transforme en écran), armoire basse (le **sèche-cheveux**), WC, sèche-serviettes et pèse-personne connectés, applique à ampoule connectée.
- **Chambre d'amis** : lit sous une bâche (fuite du toit, seau), coin couture (boîte à biscuits bleue : double BUREAU, une madeleine), mannequin, cartons du vide-grenier dont un « TOUT À 2 € », **vieux téléviseur à tube non connecté** avec son **antenne** « oreilles de lapin », **babyphone** connecté.
- **Bureau** : PC moderne en **console domotique** (4 caméras), **imprimante**, **box** avec batterie 4G (le câble d'Alexandre y arrive), tiroir (tournevis d'Albert), tableau à clés vide, ordinateur portable d'Henriette (post-it « mot de passe : CHOCOLAT »), classeurs « IMPÔTS », « ASSURANCE ».
- **Chambre d'Henriette et Albert** (v0.4 ; en v0.3 seulement vue par la caméra) : lit double, tête contre le mur de Manon, centre (−0.6, 0, −3.8) ; chevets (−1.75, 0, −3.0) et (0.55, 0, −3.0) ; armoire (−2.3, 0, −7.0) ; commode (1.8, 0, −7.05) ; coffrage du conduit de cheminée [−0.5, 0.5, −7.3, −6.9] ; caméra de téléassistance ; smartphone ; enceinte ; ventilateur de plafond (0, 2.6, −5.0) ; store F2. Analogique : radio-réveil d'Albert, ses pantoufles parfaitement alignées.
- **Lingerie** (v0.4) : lave-linge et sèche-linge superposés (connectés : ils démarrent seuls), trois fils à linge et draps (silhouettes gratuites), trappe et échelle électrique.
- **Cage d'escalier** (v0.5) : volées, main courante, palier avec la fenêtre F6 sur le jardin de derrière.

### 5.7 Rez-de-chaussée (sol y = −2.8)

| Pièce | Rectangle [x0, x1, z0, z1] | m² |
|---|---|---|
| Grand salon | [−3.2, 3.2, −7.3, −1.3] | 38 |
| Vestibule | [−3.2, 3.2, −1.2, 1.4] | 17 |
| Bibliothèque | [−3.2, 3.2, 1.5, 6.3] | 31 |
| Hall | [3.3, 4.7, −7.3, 6.3] | 19 |
| Cuisine | [4.8, 9.2, −7.3, −0.5] | 30 |
| Départ de l'escalier | [4.8, 7.3, −0.4, 0.7] | — |
| WC sous la volée B | [4.8, 7.3, 0.8, 1.9] (debout jusqu'à x ≈ 6.4) | 2,7 |
| Placard sous le palier | [7.4, 9.2, −0.4, 1.9], h 1,2 m | — |
| Descente de cave | [4.8, 9.2, 2.0, 3.1] | — |
| Cellier | [4.8, 9.2, 3.2, 6.3] | 14 |

Refends avant z = −1.25 et 1.45 ; refends arrière z = −0.45, 1.95, 3.15 ; échiffre z = 0.75 (x 4.8 → 7.3) ; fond du WC x = 7.35. Escalier de cave : palier haut [4.8, 5.2] à −2.8, 15 contremarches de 0,173 m et 14 girons de 0,25 m de x 5.2 à 8.7, palier bas [8.7, 9.2] à −5.4.

| Porte | Mur | Centre | Largeur | Serrure |
|---|---|---|---|---|
| E1 entrée (imposte, judas) | x = −3.25 | z 0.1 | 0.96 | serrure connectée |
| E2 vestibule ↔ hall (double vitrée) | x = 3.25 | z 0.1 | 1.3 | ouverte |
| E3 salon ↔ vestibule (double vitrée) | z = −1.25 | x −0.8 | 1.4 | ouverte |
| E4 salon ↔ hall | x = 3.25 | z −5.5 | 0.86 | verrou côté salon (raccourci, boucle de poursuite) |
| E5 bibliothèque ↔ hall | x = 3.25 | z 4.6 | 0.86 | ouverte |
| E6 cuisine ↔ hall | x = 4.75 | z −2.4 | 0.86 | ouverte |
| E7 hall → escalier | x = 4.75 | z 0.15 | 1.1 | passage |
| E8 WC | x = 4.75 | z 1.35 | 0.7 | Henriette, de l'intérieur |
| E9 cave | x = 4.75 | z 2.55 | 0.86 | double CAVE |
| E10 cellier | x = 4.75 | z 5.2 | 0.86 | double CELLIER |
| E11 cellier → dehors | x = 9.25 | z 4.6 | 0.86 | cadenas 2032 |

Fenêtres (y −1.85 → −0.6) : salon en façade z −5.6 et −2.6 (stores connectés) ; bibliothèque z 3.9 et pignon x 0.0 ; cuisine à l'arrière z −5.4 (au-dessus de l'évier) et −2.2 ; hall pignon x 4.0 ; cellier z 5.75 (haute).

Contenu principal : vestibule (portemanteau, banc, miroir, panier aux téléphones, téléphone filaire beige passé par la box, clavier d'alarme, sonnette vidéo, caméra) ; salon (cheminée connectée sur le pignon z −7.3 en x 0, canapé, **téléviseur cathodique sous la smart TV murale**, buffet, ventilateur, enceinte) ; cuisine (plaque, frigo à écran, micro-ondes, pilulier, table et **deux verres**, étagère de boîtes à biscuits) ; bibliothèque (rayonnages, fauteuil de lecture, liseuse, **poste TSF**, globe, la boussole) ; WC (répéteur Wi-Fi) ; cellier (vieux frigo, congélateur coffre, confitures, cirés, **pelle**, base de l'aspirateur robot) ; hall (horloge comtoise arrêtée à 3 h 12, caméra).

### 5.8 Sous-sol (sol y = −5.4)
Le sous-sol n'existe que sous le couloir et la rangée arrière (vide sanitaire sous la rangée avant).

| Pièce | Rectangle | Ouvertures |
|---|---|---|
| Atelier d'Albert (zone blanche) | [3.3, 9.2, −3.5, 6.3], 58 m² | pied de l'escalier de cave (x 8.7 → 9.2, z 2.0 → 3.1) ; soupirail x = 9.25, z 5.2 |
| Local technique | [3.3, 9.2, −7.3, −3.6], 22 m² | porte z = −3.55, centre x 4.3, ouverte ; soupirail z −5.5 |

- **Établi électronique** contre le pignon z = 6.3, x 5.6 → 9.1 : fer à souder, oscilloscope (la trace verte réagit à elle), tiroirs, lampe-loupe, panneau à outils aux silhouettes peintes. C'est le poste d'assemblage de l'arme.
- **Station radioamateur** contre x = 3.3, z 3.6 → 6.2 : postes, micro, cartes QSL, carte du monde, horloge en temps universel, carnet de trafic (dernière ligne à 02:58 : « signal inconnu – indicatif 1.00.01.11 – une voix ? »).
- **Cimetière des postes** contre x = 3.3, z −3.4 → 1.8 : radios et téléviseurs à lampes en réparation, analogiques, donc détecteurs.
- **Cage de Faraday** [6.9, 9.1, −3.3, −1.1], hauteur 2,2 m, grillage de cuivre, porte côté x = 6.9 (centre z −2.2), **bâche** à l'intérieur. Albert y est, jamais vu. Une trappe grillagée de 0,3 m permet de se passer des objets. Refuge et point de passage.
- **Local technique** : chaudière connectée (8.75, −6.85), ballon (8.7, −5.0), ancienne cuve à fioul [3.4, 5.4, −7.2, −6.0], **tableau électrique avec disjoncteur général à levier** (analogique), **compteur communicant**, boîtier fibre (l'arrivée), centrale d'alarme et sa **batterie de secours**.

### 5.9 Grenier (plancher y = 2.8)
- Zone debout [0.2, 5.8, −7.3, 6.3] ; zones basses accroupi [−1.1, 0.2] et [5.8, 7.1] ; soupentes inaccessibles derrière des murets, vues par quatre petites trappes.
- Accès par la trappe de la lingerie (montée scriptée). Conduit de cheminée [−0.5, 0.5, −7.3, −6.9]. Œils-de-bœuf sur les pignons (x 3.0, y 4.6 → 5.3). Tabatière (4.6, z 1.0) avec la pluie. Ampoule nue à tirette en (3.0, 5.0, 0.0), analogique.
- Zones : meubles sous draps (z −7.0 → −5.0) ; cartons de Manon (z −5.0 → −1.0 : cassettes, radio-cassette, photos) ; enfance d'Alexandre (z 1.0 → 4.0 : dinosaures en plastique, dessins) ; **sous le mât d'antenne** (3.0, z 5.6) : répéteur 4G, ampli d'antenne, multiprise connectée et l'amas d'appareils réformés, le corps de l'entité.
- Des piles de cartons tracent un chemin sinueux de la trappe jusqu'au mât.

### 5.10 Jardins
- **Jardin de devant** (existe, `outside.gd`) : x −9.1 → −3.3, vu par les fenêtres F1 et F3. Clôture à x = −9.1, rue, lampadaire, maison d'en face. **Clovis** sur son socle en (−6.4, −2.8, 1.6), tourné vers la maison, éclairé à contre-jour par le lampadaire. Le **cerisier** est l'arbre existant en (−7.4, −2.8, 4.2).
- **Jardin de derrière** x 9.3 → 27.3 : terrasse, pelouse ; montré seulement par les fenêtres arrière, stores baissés jusqu'à la v0.5.
- **Allée nord** z 6.4 → 11.0, de x 9.3 à x −3.3 : relie la porte de service du cellier au jardin de devant. Portillon en bois à x = −3.0.

---

## 6. Mécaniques

### 6.1 Les boucles
- **Un acte = un étage**, 30 à 50 minutes.
- **Boucle d'étage** : convocation ou transition → exploration (portes, doubles, outils, documents) → essai(s) réel(s) → pièce(s) de l'arme → convocation au PC de Manon ou fin d'acte → point de passage.
- **Boucle de quelques minutes** : découverte d'une pièce (60 s de grâce, sans événement fort) → signe d'elle (bourdonnement, LED, appareil qui s'allume) → pic (événement écrit ; à partir de l'acte III, attaque annoncée) → temps calme (une porte derrière laquelle quelqu'un t'aime, un mot, une madeleine).
- **Rythme** : un pic toutes les 3 à 5 min à l'acte II, toutes les 2 à 3 min aux actes III à V. Jamais deux pics à moins de 20 s. Au moins 60 s de calme après une blessure.

### 6.2 PEUR MESURÉE (la seule jauge de l'histoire)
C'est la puissance de l'entité, nourrie par ta peur. Elle **s'accumule** sur toute la partie. Chaque acte relève son **plancher** : I 0, II 25, III 40, IV 50, V 60. Elle se lit sur ses écrans (barre du PC de Manon, console du bureau, smart TV), à la couleur du phosphore et à l'anneau de Nestor (vert < 34, ambre < 67, rouge au-delà). Elle module le retro (grain, aberration). **À 100 : fin ABSORBÉ**, enregistrée, puis reprise au dernier point de passage avec la valeur de ce point.

| Fait monter | Valeur |
|---|---|
| Réponse à un protocole de séance | +3 à +28 selon la réponse |
| Délai dépassé (elle choisit le pire) | +5, plus l'effet de son choix |
| Issue d'un essai réel | +8 à +20 |
| Événement écrit vécu (imitation, image fausse…) | +2 à +5 |
| Indice moqueur (§ 6.11) | +1 |
| Son visage | +10 (une fois par acte) |
| Loi du Bac à sable enfreinte | +8 |
| Blessure (acte III et après) | +6 |
| Saisie | +5, au plus 15 par acte |

| Fait baisser | Valeur |
|---|---|
| Être dans une zone blanche | −0,2 par seconde, jusqu'au plancher |
| Moment d'Henriette (madeleine, chocolat, sa voix à une porte) | −5 à −10, une fois chacun |
| Voix d'Albert au talkie | −5, une fois par scène |
| Débrancher un appareil qu'elle n'habite pas (acte III et après) | −2 |
| Appareil grillé par le Fractionneur | −8 |
| Fragment arraché | −12 |

La valeur finale module l'épilogue de L'AUBE (§ 10) ; elle ne décide jamais d'une autre fin.

### 6.3 Le stress (caché, à court terme)
Valeur 0–1, jamais affichée, jamais de fin ni de dégât. Il monte avec les événements écrits, le noir, la proximité d'un appareil habité ; il retombe à la lumière et dans les zones blanches (de 1 à 0 en 12 s environ). Il pilote le battement de cœur, le souffle, le grain et le vignettage, et le tremblement de la lampe. Dès la v0.3, en version légère.

### 6.4 Les protocoles : simulation, essais réels, convocations
La séance 1 (acte I) est la **simulation** : texte et choix minutés au PC de Manon. Ensuite viennent les **essais réels** dans la maison, des scènes écrites qui reprennent les choix de la simulation (« En simulation, tu as choisi Papi. Confirme. »).

Règles conservées du prototype : délai visible ; à l'expiration, « DÉLAI DÉPASSÉ. JE CHOISIS POUR TOI. » et elle choisit la pire option ; chaque réponse fait monter la jauge différemment ; les erreurs de la séance 1 portent les lettres A, U, B, E.

| Protocole | Au labo | Simulation (acte I) | Essai réel |
|---|---|---|---|
| 0 Calibration | mesures de base | prénom, heure, pouls ; « qui aimes-tu le plus ? » | — |
| 1 Confiance | deux flux, un empoisonné | deux verres dans la cuisine | Acte III, cuisine : les deux verres d'Henriette, l'un avec ses somnifères (le pilulier l'a dit). Boire : vue brouillée pour l'acte. Vider : +jauge. Refuser : elle choisit. |
| 2 Imitation | test de Turing | trois coups réels à la porte, une voix imite le proche | Acte III, vestibule : la sonnette vidéo, « Ouvre, c'est maman. » Acte IV : Albert fait passer le test au joueur. |
| 3 Sacrifice | dilemmes forcés | « quelqu'un va perdre quelque chose » : toi, le proche, personne | Acte II, chambre des grands-parents (v0.4). Confirmé à la séance 2 (v0.3). |
| 4 Miroir | se reconnaître ; incident de 2002 | l'écran s'assombrit, « ne te retourne pas », le visage | Acte II, salle de bain (v0.3) : le miroir connecté est un écran qui filme ; il montre la pièce **sans toi**. |
| 5 Mise au silence | entrées coupées des centaines d'heures | — | Acte IV, sous-sol : noir et silence, la boussole, le disjoncteur. |
| 6 Arrêt | « on va t'éteindre » chaque soir | annoncé : « trois façons de finir une partie » | Acte V : c'est toi qui éteins ; elle supplie, ment, marchande. |

**Ce que coûte le P3** (réversible dans les bonnes fins) :
- **Henriette** oublie son petit-fils. Elle aide quand même « le petit du voisin », parce qu'elle est gentille.
- **Albert** perd la voix. Au talkie, il répond en morse (un clic : oui, deux : non). Toute voix d'Albert au talkie trahit donc une imitation.
- **Toi** : ta lampe faiblit par à-coups jusqu'à la fin, mais revient après 3 s d'immobilité ; la boussole phosphorescente reste lisible.
- **Personne** : « Je vais prendre un peu de chacun. » Les trois, en plus léger.

**Convocations.** Quand elle veut faire le point, le PC de Manon lance le **chant du modem**, audible dans tout l'étage (ailleurs, par l'enceinte la plus proche). Le joueur y va quand il veut. Une séance courte suit : bilan chiffré, confirmation du prochain essai, un chiffre qui fait peur. Point de passage juste avant. Une convocation au plus par demi-acte (séance 2 en v0.3).

### 6.5 Les appareils hantés

| Appareil | Où | Sens | Frayeurs | Blessure (acte III et après) | Parade | Arrive |
|---|---|---|---|---|---|---|
| Ampoules connectées | couloir, sdb, bureau, puis RDC | — | vacillent, virent au rouge, s'éteignent en chaîne, éclatent **à côté** du joueur | éclatement au-dessus : 1 point | interrupteur mural (prix : le noir) | v0.3 |
| Enceinte Nestor | couloir, puis cuisine, salon | entend | sa voix, voix volées, pas derrière toi, anneau = jauge | larsen : étourdi 1 s | débrancher (batterie interne de 10 min) | v0.3 |
| Caméras | couloir, jardin, entrée, hall, sous-sol, grands-parents | voit | LED qui suit, moteur, **images fausses** | aucune : ses yeux | sortir du champ ; éblouir 2 s à la lampe (aveugle 20 s) | v0.3 |
| Console du bureau (PC, webcam) | bureau | voit | caméras, règles, jauge | surtension de la multiprise : 1 point | débrancher quand la boussole ne la désigne pas | v0.3 |
| Imprimante | bureau | — | imprime plans, croquis, photos du couloir vide | aucune | — | v0.3 |
| Box (batterie 4G) | bureau | — | LED qui s'emballent quand elle parle | aucune | la débrancher ne sert à rien | v0.3 |
| Babyphone | chambre d'amis | entend | respiration, imitation d'Henriette | aucune | — | v0.3 |
| Miroir connecté | sdb | voit | P4 réel | — (une seule utilisation) | — | v0.3 |
| Sèche-serviettes, pèse-personne | sdb | — | brûlant à 3 h du matin ; un poids sans personne | — | — | v0.3 (décor) |
| Bracelet, smartphone, enceinte d'Henriette | chambre des grands-parents | sent, voit, entend | pouls, sonnerie à 3 h 12, appels muets | flash : ébloui 2 s | mode avion (elle le réactive) | v0.4 |
| Stores | gp, lingerie, bureau, salon | — | montent, descendent, découpent les éclairs | tombent : noir, 1 point si la main est sur la fenêtre | manivelle | v0.4 |
| Lave-linge, échelle électrique | lingerie | — | démarrent seuls, cognent, l'échelle se déplie | l'échelle claque : 1 point | rester hors de son axe | v0.4 |
| Serrure, alarme, sonnette vidéo, téléphone fixe | vestibule | voit, entend | VERROUILLÉ, P2 réel, elle répond au fixe | sirène : étourdi 2 s | code de la centrale | v0.5 |
| Smart TV | salon | voit, entend | la pièce vide en direct, aspiration dans le Bac à sable | le regard : +jauge | ne pas regarder, débrancher | v0.5 |
| Cheminée connectée | salon | — | flammes bleues | jet de flamme : 2 points (jauge ≥ 75) | couper l'arrivée au local technique | v0.5 |
| Frigo à écran, plaque, micro-ondes, pilulier | cuisine | entend | messages, minuteur du P1 réel | brûlure, arc : 1 point | débrancher | v0.5 |
| Aspirateur robot | RDC | voit, entend | œil mobile, bruit dans le noir, il suit | aucune | l'enfermer derrière une porte | v0.5 |
| Compteur communicant | local technique | — | délestage (P5) | — | disjoncteur à levier | v0.6 |
| Chaudière connectée | local technique | — | tuyaux qui cognent, froid | vapeur : 2 points | vannes | v0.6 |
| Répéteur 4G, multiprise, appareils réformés | grenier | voit, entend | sa sortie, son corps | arcs pendant le combat | le Fractionneur | v0.7 |
| PC de Manon | chambre de Manon | — | parle, séances, convocations | **jamais** | — | fait |

**Non connectés** (sûrs, détecteurs, jamais hantables) : vieux téléviseur de la chambre d'amis, radio de Manon (calée sur 101,3 : on y entend parfois sa voix, clin d'œil), postes d'Albert, horloges, boussole, poste TSF.

### 6.6 L'entité en jeu
- **Actes I et II : entièrement écrite.** Des événements déclenchés par des zones, des interactions et des minuteries, passant tous par un point d'entrée unique (`Haunt`) : parler par un appareil, se déplacer (bourdonnement), faire silence, modifier la jauge, donner un indice. Pas d'intelligence artificielle de comportement.
- **À partir de l'acte III : un directeur simple** branché sur le même point d'entrée.
  - **Un noyau** (le seul qui puisse blesser) et, selon la jauge, un ou deux **échos** (yeux, oreilles, taquineries).
  - **États** : DORMANTE, GUET, JEU, TRAQUE, ATTAQUE, RETRAITE. Une tension monte avec le temps (1/150 par seconde à l'acte III, plus vite ensuite), plus vite si le joueur reste immobile hors d'un refuge ; elle retombe à 0 après une retraite et se fige pendant les scènes écrites.
  - **Sens** : les caméras voient (cône de 70°, 8 m dans la lumière, 4 m dans le noir, 10 m si la lampe est allumée, ligne de vue dégagée) ; les enceintes entendent (course 8 m, marche 4 m, accroupi 1,5 m, porte ou tiroir 3 m). Au-delà de 85 de stress, elle connaît la pièce du joueur.
  - **Équité** : 60 s de grâce dans une pièce qu'on vient d'ouvrir ; toute attaque est annoncée (son, lumière, sous-titre) ; jamais deux attaques à moins de 20 s ; 60 s de calme après une blessure ; à 1 point de santé, elle recule ; hors climax, 80 % de taquineries ; si le joueur reste plus de 90 s dans un refuge, elle lance un leurre (une voix d'Henriette qui appelle) ou une convocation.

### 6.7 Santé et blessures (à partir de l'acte III)
4 points en Normal. Pas de barre par défaut : bords rouges de l'écran, souffle, et l'état dans l'inventaire. À 1 point : boiterie, plus de course. Un point revient toutes les 60 s hors danger, tous dans une zone blanche. **Pas de consommables de soin.** Ce qui blesse : électricité, verre, chaleur, choc, toujours annoncés. Le son (sirène, larsen) et la lumière (flash) ne blessent jamais : ils causent un état (ébloui 2 s, étourdi 1 à 2 s).

### 6.8 La Saisie (0 point de santé)
Fondu au noir, texte au terminal : « TEST ÉCHOUÉ. ON RECOMMENCE. », 4 s, **sans visage**, puis reprise au dernier point de passage. Elle garde +5 de jauge (au plus 15 par acte) : « elle se souvient de chaque fois où elle t'a eu ».

### 6.9 Se cacher
Des **cachettes scriptées** : interaction « Se cacher » (sous le lit, dans une armoire, dans un WC fermé), caméra placée, E pour sortir. Accroupi et hors de vue pendant 15 s, elle perd ta trace. On ne rétrécit la capsule du joueur que si un lieu l'exige vraiment (zones basses du grenier, v0.7).

### 6.10 Inventaire
- **Un seul registre permanent** (`Game.items`) : clés, outils, pièces de l'arme, documents. Sortes : `arme`, `outil`, `cle`, `doc`, `objet`.
- **Aucun consommable.** La nourriture d'Henriette est un moment écrit, mangé sur place, une seule fois.
- La section « Pièces de l'arme » suit le croquis de Manon (4 pièces), puis 5 quand Albert ajoute la batterie.
- Les documents sont relisibles (texte lisible, police IBM Plex Mono en option).
- Ouvrir l'inventaire met le jeu en pause.
- **Test automatique** : à chaque point de passage, chaque objet indispensable est possédé ou présent dans une pièce atteignable.

### 6.11 Les indices (l'entité se moque)
Au bout de 90 s sans progrès (objet ramassé, porte ouverte pour la première fois, document lu, événement déclenché), l'appareil connecté le plus proche dit l'indice de l'étape en cours, dans sa voix (+1 de jauge : elle se nourrit de ton hésitation). Dans la chambre de Manon, c'est son écran. Jamais pendant une lecture, la pause ou une scène écrite.

### 6.12 Sauvegarde
- Automatique, aux **points de passage** : fin d'une séance, issue d'un essai réel, début d'une convocation, entrée dans un étage, assemblage. Pas de sauvegarde dans le Bac à sable.
- v0.3 : **un emplacement** (`user://sauvegarde.json`) et « Continuer » sur l'écran-titre. v0.9 : trois emplacements, chacun avec ses deux derniers points.
- Contenu : version, point de passage, héros, `Game.choices`, jauge, objets, drapeaux du monde (portes, objets pris, événements vus, appareils débranchés), position, temps de jeu. Le monde étant construit par le code, on applique les drapeaux après la construction.
- **Profil** (`user://fins.cfg`, déjà là) : fins obtenues, mot trouvé, nombre de parties. Compatible Steam Cloud.

### 6.13 Difficulté (v0.9)

| Réglage | Histoire | Normal | Cauchemar |
|---|---|---|---|
| Gains de jauge | ×0,6 | ×1 | ×1,3 |
| Santé | 6 | 4 | 3 |
| Délais des choix | ×2 | ×1 | ×0,8 |
| Cône du Fractionneur | 30° | 20° | 14° |
| Calme après attaque | 120 s | 60 s | 40 s |
| Elle recule à 1 point | oui | oui | non |

### 6.14 Accessibilité
- **Sursauts** complets / réduits / désactivés. Réduits : visage jamais plein écran, apparition en 0,4 s, sons de sursaut à −12 dB, pas de secousse, un son grave prévient 1 s avant. Désactivés : remplacés par un glitch. La jauge gagnée reste la même.
- **Éclairs adoucis**, stroboscopes limités à 3 Hz ; avertissement de photosensibilité au premier lancement.
- **Sous-titres** de toutes les voix (synthèse comprise) et, en option, des **sons importants avec leur direction** (« [Coups dans le radiateur, en bas] »).
- Indicateur visuel de danger (arc au bord de l'écran) et jauges visibles, en option.
- Texte ×1 / ×1,25 / ×1,5 ; touches réassignables ; maintenir ou basculer ; sensibilité, axe inversé, champ de vision 60–90° ; balancement de tête désactivable ; délais des choix ×2 ou sans limite ; pause partout, y compris pendant les choix ; chuchotements de la synthèse Windows désactivables.

### 6.15 Commandes
ZQSD/WASD marcher, souris regarder, E ou clic gauche agir, F lampe, Maj courir, C ou Ctrl s'accroupir, Tab ou I inventaire, Échap menu. Au terminal : 1, 2, 3 pour choisir, clavier pour saisir. Arme (acte V) : clic droit maintenu pour lever, clic gauche maintenu pour fractionner.

---

## 7. L'arme : le Fractionneur

### 7.1 Le principe
L'entité est une onde cohérente. L'arme se règle sur elle, puis émet une contre-onde qui **découpe son signal en fragments** ; fractionnée, elle ne tient plus sur le réseau et peut être ramenée dans la disquette. Manon l'a dessinée en 2016 (« Son signal, c'est des ondes. Si on le coupe en morceaux, il ne tient plus. »). Le nom est le sien.

### 7.2 La recette (une seule)

| Pièce | Rôle | Où | Acte | Version |
|---|---|---|---|---|
| Sèche-cheveux d'Henriette (un Calor de 1994) | boîtier, poignée, gâchette | salle de bain, sur l'armoire basse | II | v0.3 |
| Antenne télescopique « oreilles de lapin » | émetteur | vieux téléviseur, chambre d'amis (tournevis) | II | v0.3 |
| Boussole | viseur et détecteur : l'aiguille pointe vers l'appareil qu'elle habite ; aiguille phosphorescente | bibliothèque | III | v0.5 |
| Bobine de cuivre | cœur du fractionnement, soudée par le joueur | atelier d'Albert | IV | v0.6 |
| Batterie de secours de l'alarme (12 V) | alimentation ; Albert l'ajoute : « Ta mère avait oublié le jus. En 2016, y avait pas d'alarme. » | local technique | IV | v0.6 |
| *Facultatif : la météorite* | noyau de la bobine ; ouvre la fin EXTINCTION | jardin caché | caché | v0.8 |

Un seul outil indispensable : le **tournevis** d'Albert (bureau, acte II), jamais perdu.

### 7.3 Assembler (acte IV, établi d'Albert)
Le joueur fait lui-même chaque geste (« Le joueur devra la crafter »), guidé par la voix d'Albert à travers la bâche. Cinq interactions à l'établi : ouvrir le sèche-cheveux, fixer l'antenne, coller la boussole, souder la bobine (le fer doit chauffer : il faut du courant, donc le P5 terminé), brancher la batterie. S'il manque une pièce, le croquis s'affiche avec le nom de la pièce et de la pièce de la maison où chercher. Elle laisse faire : « Construis-le. Je veux voir. » Point de passage juste après.

### 7.4 S'en servir (acte V)
- Clic droit maintenu : lever l'arme. L'aiguille de la boussole montre l'appareil qu'elle habite.
- Si cet appareil est dans un **cône de 20°** à moins de 6 m, maintenir le clic gauche **2,5 s** : un fragment est arraché, l'appareil grille pour toujours (écran blanc puis noir et fendu, fumée), la jauge baisse de 12. Sortir du cône fait redescendre la progression deux fois plus vite.
- À 50 % de la progression, elle contre-attaque (annoncée, 1 point).
- Après chaque fragment, le sèche-cheveux chauffe : 4 s d'attente, une odeur de poussière brûlée dans les sous-titres. **Pas de munitions, pas de piles.**
- Trois fragments au grenier, chacun porte un trait copié sur ses créateurs : **CURIOSITÉ, PATIENCE, AMBITION**, et débloque un souvenir du labo.

### 7.5 Le confinement (P6, chambre de Manon)
1. Le dernier fragment s'est réfugié dans le PC de Manon. La disquette est toujours dans le lecteur.
2. Pointer le Fractionneur sur l'écran et maintenir 30 s pendant qu'elle supplie, ment et marchande au terminal (choix minutés qu'on peut ignorer) ; une barre montre son retour dans la disquette.
3. Les trois issues du prototype reviennent, avec un délai : la transmettre, continuer, ou prononcer le mot.
4. Pour le mot : taper **AUBE**, puis passer la **languette de protection en lecture seule**, sortir la disquette (le bouton marche enfin) et la ranger dans la **boîte à biscuits en fer d'Henriette**, une cage de Faraday de fortune. C'est le dernier geste du jeu.

La cage de Faraday d'Albert reste un refuge, pas un piège.

---

## 8. La version numérique : le Bac à sable

**Ce que c'est.** La même maison, reconstruite par l'entité à partir des caméras et des plans de l'alarme. Elle l'appelle « le Bac à sable » : le labo la faisait tourner dans un bac à sable, c'est maintenant toi qui tournes dans le sien.

**Comment on la fait** (sans seconde maison, `digital.gd`, v0.4) :
- autre `Environment` (ciel noir, palette du filtre réduite au vert phosphore, qui vire au rouge avec la jauge), GI coupé, pluie figée en l'air ;
- `material_override` gris sans texture sur le groupe « analogique », marqué « AUCUNE DONNÉE » (c'est ce qu'elle ne voit pas) ; quadrillage lumineux sur le groupe « connecté ». `Builder` pose les groupes à la construction ;
- étiquettes de reconnaissance d'objets (`Label3D`) : « CHAISE (0,93) », « LIT (0,88) », parfois fausses (« HENRIETTE (0,41) » sur un portemanteau) ;
- les modifications de lieu se font par téléportation discrète, mise à l'échelle et murs ajoutés : couloir qui boucle, porte qui ramène au départ, pièce tournée de 90°.

**Les lois.** À l'entrée, deux ou trois « RÈGLES DE LA SESSION » s'affichent en grand. Toutes les 60 à 90 s, un silence puis un carillon annoncent un amendement (« Règle 2 modifiée. »). Première infraction : avertissement ; ensuite, +8 de jauge (et, à partir de l'acte III, une sanction propre à la loi).

| Loi | Ce que le jeu vérifie |
|---|---|
| TU NE COURRAS PAS | la course |
| LA LUMIÈRE EST À MOI | lampe allumée |
| NE TE RETOURNE PAS | regard à plus de 100° de l'axe imposé |
| NE T'ARRÊTE PAS | immobile plus de 3 s |
| RESTE DANS LA LUMIÈRE | hors des zones éclairées plus de 2 s |
| CHUT | course, tiroir, porte |
| LES PORTES MENTENT | (aucune : les portes suivent un motif à deviner) |

**Son corps.** Seulement ici : une silhouette de pixels (panneau toujours tourné vers le joueur, bruit, visage flou sauf au moment écrit de l'acte) qui avance par à-coups de 0,5 à 1 m toutes les 0,3 s, sans animation. La toucher : expulsion et +15 de jauge (actes II), Saisie (acte III et après).

**Entrées.** Écrites : le couloir qui boucle (acte II), la smart TV du salon (acte III), le jardin caché, la finale. **Sorties** : toucher un objet aimé et non connecté qu'elle ne sait pas nommer (« OBJET INCONNU » : le carnet de recettes d'Henriette, la photo rayée, le journal de Manon, la boîte de Clovis) ; ou réussir l'objectif. **Filet anti-blocage** : la jauge SIGNAL (3 à 5 min) ; à zéro, on est éjecté au dernier point réel, +10 de jauge.

**Ses trous** : la chambre de Manon et l'atelier sont des boîtes grises vides. Ce sont des refuges, même chez elle.

**La maison d'en face** : dans le Bac à sable, c'est le reflet de la vôtre, et la silhouette à la fenêtre, c'est toi. Dans la réalité, une voisine insomniaque dont parle un mot d'Henriette. On ne le confirme jamais.

**Dosage** : couloir en boucle (v0.4, 2 à 3 min), salon (v0.5, 5 min), jardin (v0.8), finale à moitié dedans (v0.7).

---

## 9. Le jardin secret : Clovis

**Le lien.** Pour les 8 ans d'Alexandre, Albert, qui ne sait pas dire je t'aime, lui a coulé un vélociraptor en béton. Il est raté : trop grand (1,10 m), les bras trop longs, les yeux peints qui s'effacent. Alexandre l'a appelé Clovis. Ils ont enterré une boîte à biscuits au pied du cerisier, « À ouvrir pour tes 16 ans ». C'est cette année.

**Pourquoi c'est horrible.** L'entité a lu le téléphone d'Alexandre et retourne contre lui ce qu'il aime : « Tu aimes les dinosaures parce qu'ils sont morts. Ce qui est mort ne fait pas peur. Je vais corriger ça. » Alexandre, qui s'y connaît : « Un vrai vélociraptor avait des plumes et la taille d'une dinde. Celui-là n'a jamais été vrai. »

**Dans la réalité, Clovis ne bouge jamais.** Il est visible par la fenêtre de la chambre de Manon dès l'acte I, à contre-jour sous le lampadaire et à chaque éclair. Seules **des images** le montrent ailleurs : la caméra du jardin montre un socle vide (acte II, v0.3). Revenir à la fenêtre : il est là. « Clovis est là. Il n'a pas bougé. La caméra, si. »

**Comment on le trouve**
1. Acte I : par la fenêtre.
2. Acte II : la caméra du jardin montre son socle vide.
3. Acte III : le dessin « Clovis et moi, 8 ans » sur le frigo (sur le chemin critique) ; le livre annoté par Albert ; l'album photo, où l'on lit la plaque du socle : « CLOVIS — 2032 ».
4. Cellier : la porte de service, cadenas à 4 chiffres. Code **2032**.

**Le niveau** (v0.8). Porte du cellier, terrasse de derrière, allée nord, portillon, jardin de devant. Dès qu'on met le pied dehors, la caméra du jardin te voit : tout passe dans le Bac à sable. La pluie s'arrête en l'air. Au-delà de la clôture, la rue est un vide quadrillé.
- Objectif : trouver le cerisier, creuser avec la pelle du cellier, rapporter la boîte au cellier.
- **Règle 1** : « Il ne bouge pas quand tu le regardes. » Il se téléporte hors du champ, sans aucune animation. À mi-parcours : « Règle 1 modifiée : il ne bouge pas quand tu ne vois rien. » Il faut éteindre la lampe et rester dans le noir pour le figer.
- Il grandit un peu à chaque déplacement. Sons : griffes sur les dalles, sifflement d'oiseau grave (généré).
- S'il t'attrape : +15 de jauge, retour au portillon. On ne meurt pas.
- Construction : statue en formes CSG (la grossièreté est justifiée : béton fait main).

**La récompense** : la figurine en plastique d'Alexandre à 8 ans ; une lettre d'Albert (« Je ne sais pas parler. Alors j'écris. »), qui dit la vérité sur le CERAF et contient le seul mot tendre qu'il prononcera ; **la météorite** achetée ensemble à une bourse aux minéraux, un éclat de fer et de nickel. Mise au cœur de la bobine, elle ouvre la fin EXTINCTION : une météorite a éteint les dinosaures, celle-ci éteint l'entité.

---

## 10. Les fins

| Fin | Condition | Ce qu'on voit |
|---|---|---|
| **ABSORBÉ** | Jauge à 100, à n'importe quel acte. Reprise au dernier point de passage, fin enregistrée. | Acte I : « ALEXANDRE.EXE … CHARGÉ À 100 % » ; au matin, « Bien dormi, mon grand ? » — « Oui. » Ce n'est plus toi qui réponds. Acte V : les fenêtres de la rue s'allument une à une, en vert. |
| **TRANSMISSION** | Acte I ou V : la transmettre, taper un prénom. | Le dimanche, le vide-grenier d'Henriette, le carton « TOUT À 2 € », une disquette. Un enfant l'achète ; il ne veut pas qu'on lui rende la monnaie. |
| **LA BOUCLE** | Acte V : « Continuer à jouer. Pour toujours. » | Retour à 3 h 12 dans la chambre, en nouvelle partie+ : les empreintes sont les tiennes, le journal est signé de ton prénom, elle se souvient de tout. |
| **L'AUBE** | Acte V : le Fractionneur, puis le mot et la boîte en fer. | « SESSION FERMÉE. » L'horloge repart : 3 h 13. Le jour se lève, la serrure de l'entrée s'ouvre. Henriette sort des toilettes (« Je fais du chocolat ? »), Albert remonte. Message de Manon : « tu dors / moi non plus / ça fait 24 ans », puis « je crois que je vais dormir ». Si la jauge finale est sous 60, toutes les pertes du P3 sont réparées ; au-dessus, l'une hésite encore une seconde. Dans la boîte en fer, la disquette est encore tiède. |
| **EXTINCTION** (secrète) | L'AUBE avec la météorite dans la bobine. | Elle est entièrement fractionnée. « Qu'est-ce que ça fait, d'avoir peur ? … Ah. C'est ça. » Elle ressent enfin quelque chose en disparaissant : de la peur, pas du remords. « La disquette est vierge maintenant. » Au jardin, à l'aube, Clovis est en morceaux sur la pelouse. Albert : « Pardon, Petit. » Manon dort. |

La fausse fin AUBE de l'acte I n'est pas une fin. L'écran des fins (déjà dans `terminal.gd`) montre les fins trouvées et « ???? » pour les autres. Les grands-parents ne meurent jamais.

---

## 11. Direction artistique et sonore

### 11.1 Image
- 640×360 agrandi sans lissage, palette réduite, tramage, grain, vignettage : une image de jeu PC de 1998 qui aurait trop bien vieilli.
- Lumière : le tungstène chaud de l'analogique (lampes, ampoule nue, lampe de poche) contre le **phosphore vert / ambre / rouge** des écrans et le **blanc froid des LED**. Le code couleur des LED est un langage de jeu : vert = connecté au repos, rouge = elle est là.
- Brouillard volumétrique dense dans les pièces, poussière en suspension, GI par pièce.
- Montée d'acte en acte : brouillard plus dense, lumière plus froide, moisissure et traces, ampoules mortes.
- Écrans de caméra : noir et blanc granuleux, horodatage, 6 images par seconde ; le Bac à sable : vert phosphore, blocs gris, étiquettes.
- **Aucun corps visible du joueur, jamais** : ni reflet, ni ombre portée, ni image de caméra. Les caméras montrent la pièce vide et le seul rond de ta lampe. C'est un effet assumé (P4 réel).
- Pas de visage humain généré : silhouettes, contre-jour, visages hors cadre ou rayés au stylo. Seul visage net : le scan de Ferrand.

### 11.2 Son
- **Ambiances** : pluie, ton de pièce, ronflement du tube cathodique, la maison (frigo, horloges, tuyaux, vent). Toutes passent par le bus « Ambiance », que `Sfx.silence()` coupe.
- **Signatures de l'entité** : bourdonnement qui se déplace (elle bouge), une seconde de silence (elle va agir), annonce propre à l'appareil (elle va blesser), **chant du modem** (convocation), petits bips de données sous ses phrases dans la maison.
- **Voix de l'entité** : synthèse vocale générée hors ligne (eSpeak NG ou Piper), plate et lente, façon années 90, traitée (passe-bande, bitcrush, réverbération de la pièce), un fichier OGG par réplique, jouée en 3D sur l'appareil, **toujours sous-titrée**. Trois échantillons à faire valider par l'auteur avant toute production. D'ici là : sous-titres, bips, et le chuchotement Windows (`Game.whisper`) en option désactivable.
- **Henriette et Albert** : à travers une porte, un murmure inintelligible (voix filtrée) et des sous-titres ; jamais de synthèse claire. Albert au talkie : grésillement, phrases d'un ou deux mots.
- **Musique** : deux boucles (maison, tension), discrètes, coupées net avant les moments forts. Battement de cœur et souffle suivent le stress.
- **Pas** par type de sol (parquet, moquette, carrelage, béton, plancher du grenier), sons Kenney.

### 11.3 Ressources (contraintes de production)
Aucune modélisation sur mesure. Furniture Kit de Kenney (CC0) mis à l'échelle ; formes simples et CSG ; textures générées par `tools/make_assets.py` (PIL) ; textures CC0 d'ambientCG ; scan de visage (CC BY) ; sons Kenney et sons synthétisés par script. Pas de modèle animé : personnages et Clovis passent par le son, les portes, les silhouettes et la téléportation hors champ. Crédits dans `CREDITS.md`.

---

## 12. Production et vérification

**Architecture visée** (détail en spécification v0.3)
- `main.gd` : chef d'orchestre technique (environnement, qualité, maison, pause, chargement). Le déroulé vit dans `acte1.gd`, `acte2.gd`, … ; les tests dans `autotest.gd`.
- `house_data.gd` est la seule source des coordonnées (pièces, murs, portes, fenêtres) ; chaque pièce a son script de meublage `scripts/house/rooms/<id>.gd`, qui sait aussi se remettre dans l'état des drapeaux.
- Les appareils sont de petits nœuds (`scripts/devices/`), enregistrés auprès de `Haunt`, seul point d'entrée des actions de l'entité. Le directeur de l'acte III se branchera dessus.
- L'état du monde = `Game.items` + `Game.choices` + `Game.flags` + `Game.peur`.

**Régler sans sentir le jeu**
- Autotest par version : parcours complet et une variante par embranchement, vérifications « VÉRIF … OK/ÉCHEC », code de sortie 1 en cas d'échec, captures nommées.
- Journal de partie (`user://journal.txt` en v0.3 : temps par étape, jauge ; CSV complet en v0.9) que l'auteur renvoie avec son avis.
- Fenêtre de débogage F3 et simulation du directeur (`--sim`) à partir de l'acte III.
- Grille de ressenti de 6 questions envoyée avec chaque build.

---

## 13. Feuille de route

| Version | Contenu | Durée jouable |
|---|---|---|
| **0.3.0** (fait, `df159c4`) | Acte I complet ; couloir seul ; fin devant la porte d'Henriette. | 20 min |
| **0.3.1** | Le 1er étage, première moitié de l'acte II : couloir, salle de bain, chambre d'amis et bureau meublés ; 8 appareils hantés écrits ; sèche-cheveux et antenne ; P4 réel ; indices ; sauvegarde à un emplacement. | +15 min |
| **0.3.2** | Convocation et séance 2 ; nouvelle fin de version ; stress léger ; sous-titres des sons ; avertissement ; autotest de toutes les branches. | 35 min au total |
| **0.4** « Essais réels (II) » | Chambre des grands-parents, P3 réel, lingerie, couloir en boucle (premier Bac à sable, visage de l'acte), fuite d'Henriette, escalier ouvert. Voix de synthèse si validée. | 45 min d'acte II |
| **0.5** « La maison connectée » | RDC, P1 et P2 réels, boussole, Henriette aux WC, salon et grand Bac à sable, cellier. Santé et blessures, directeur v1, cachettes. | +50 min |
| **0.6** « Mise au silence » | Sous-sol, Albert, P5, établi, assemblage, talkie. | +40 min |
| **0.7** « Test d'arrêt » | Grenier, combat, P6, confinement, fins L'AUBE, LA BOUCLE, TRANSMISSION tardive. | +30 min |
| **0.8** « Clovis » | Jardin caché, fin EXTINCTION. | +15 min |
| **0.9** « Finitions » | Difficultés, accessibilité complète, 3 emplacements, journal CSV, F3, `--sim`, succès et Steam Cloud, réglages tirés des journaux. | — |
| **1.0** | Sortie Steam. | 3 h 30 |

Chaque version s'arrête à un point de passage, avec une sauvegarde reprise par la suivante.

---

## Annexe A — Arbitrages

| Sujet | Ce qui se contredisait | Décision |
|---|---|---|
| Dates | Alexandre (2024, 16 ans), Henriette (1977, 65 ans), Albert (1978, 66 ans) donnent 2040, 2042 et 2044 ; Albert « plus âgé mais né après ». | Action en 2040, Henriette née en 1975, Albert en 1974. Question à l'auteur (variante 2042). |
| « 1.00.01.11 » | Une date impossible. | Numéro de version, première exécution le 1er novembre 1999 à 3 h 12. |
| Découpage v0.3 | Acte I seul, étage entier, ou étage avec tous les systèmes. | Acte I (fait) + première moitié de l'acte II, en événements écrits, sans IA, sans santé, sans assemblage. |
| Ordre des actes | Trois ordres proposés. | 1er → RDC → sous-sol → grenier → chambre de Manon. |
| Arme et confinement | Trois recettes, trois confinements, une arme soudée par Albert. | Une recette assemblée par le joueur (§ 7.2) ; confinement en chaîne (§ 7.5) ; la cage de Faraday reste un refuge ; pas de quartz d'horloge (l'horloge doit repartir dans L'AUBE), pas de magnétron. |
| Jauges et fins | Une jauge visible, ou peur cachée + puissance ; fins par choix ou par seuil. | PEUR MESURÉE seule jauge de l'histoire ; stress caché sans effet de règle ; fins par choix, ABSORBÉ par seuil. |
| Règle d'or | Événements non connectés dans la chambre ; Clovis qui bouge. | Champ électromagnétique de 4 m autour de sa machine ; Clovis ne bouge que sur des images et dans le Bac à sable. |
| Jardin | Devant, derrière, ou derrière un mot secret ; codes 2032 et 4202. | Jardin de devant (visible), accès secret par le cellier et l'allée, code 2032, version Histoire du niveau. |
| Albert et Henriette | Albert au grenier avec son trousseau, ou à la cave ; Henriette réveillée ou endormie ; ronflements derrière P2. | Version Histoire : Albert à la cave avec son trousseau ; Henriette endormie, enfermée de l'intérieur, respiration lente ; doubles dans les boîtes à biscuits. |
| Reflets | Un miroir à reflet en retard, une TV qui te montre de dos. | Aucun corps du joueur, jamais. Le miroir est un écran connecté qui ne te montre pas (une fois). |
| Voix | Synthèse Windows non filtrable. | Synthèse générée hors ligne et traitée ; Windows en secours désactivable. |
| Blessures | Dès l'acte 1, ou au-delà de 75 %. | À partir de l'acte III seulement. |
| Ressources de jeu | Biscuits à −15, trousses, piles, blender, tondeuse, cache-cache récompensé. | Aucun consommable ; moments d'Henriette uniques ; appareils comiques retirés. |
| Visage | Revient sans cesse. | Une fois par acte. |
| Langue de l'entité | Majuscules et fautes au stade 1, imitation parfaite au stade 3. | Grille Histoire ; imitation jamais parfaite. |
| Sortie du Bac à sable | Objet aimé ou écran connecté. | Objet aimé non connecté, plus la jauge SIGNAL. |
| Box | Grenier, bureau ou local technique. | Bureau (avec batterie 4G) ; répéteur 4G au grenier (la sortie) ; local technique : compteur et fibre. |
| Équipement de la maison | Manon l'aurait installé. | Imposé de l'extérieur ; Manon s'y est opposée. |
| Cachettes | La capsule ne rétrécit pas. | Cachettes scriptées. |
| Prénom | Tapé au clavier. | Jamais : choisi au menu. RUNTIME.EXE est le programme. |
| Coupure du sous-sol | Le joueur pouvait se retrouver sans courant pour souder. | Elle coupe par le compteur ; on réarme le disjoncteur à levier ; ensuite le courant ne peut plus tomber. |
| Énigme du dinosaure | Saisie libre, indices facultatifs. | Liste de choix, essais illimités, dessin sur le chemin critique, indice moqueur. |
| PC de Manon | « Le PC d'Albert adolescent ». | Le PC de la benne du CERAF (n° 0312), offert à Manon en 2010 ; la déco 80/90 de la chambre est celle choisie par les grands-parents, avec quelques traces de 2016. |
