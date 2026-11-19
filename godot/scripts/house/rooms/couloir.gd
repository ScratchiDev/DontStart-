extends HouseRoom
## Le couloir du premier étage : long, étroit, resté dans les années 90 (tapis rouge élimé, radiateur
## en fonte, console et téléphone sans fil, photos de famille, horloge comtoise arrêtée à 3 h 12 au
## fond, près de la chambre des grands-parents), mais truffé d'appareils imposés de
## l'extérieur : ampoules connectées du fournisseur d'énergie, caméra dôme de l'assurance, thermostat,
## détecteur de fumée, boîtier de téléassistance. Leurs câbles blancs, neufs, sont scotchés sur le
## vieux papier peint.
## Repère : intérieur x 3.3 → 4.7, z −7.3 → 6.3, sol y = 0, plafond 2.6.
## Portes : mur x = 3.25 en z −3.6 (P2), 1.4 (P1), 3.4 (P3) ; mur x = 4.75 en z −4.6 (P4), −1.2 (P5),
## 1.35 (P6, vitrée, s'ouvre dans le couloir), 4.4 (P7). Fenêtre F8 au bout sud (mur z = 6.35).
## Fonctions publiques : flicker(secondes), set_dim(k), chain_lights(), track(cible), look_at_player_once(),
## set_cam_led(on) (la LED rouge de la caméra dôme, réglée par le scénario),
## set_switch(on, quiet, keep_level) (l'interrupteur : coupe ou rend le courant aux trois ampoules),
## unplug_nestor(quiet) (avec le tournevis), photo() (await : image de CAM 1, prête à imprimer), restore().
## Propriétés : nestor (Nestor, « nestor »), feed_cam (FeedCam « CAM 1 COULOIR », sur la tête de la
## caméra dôme), switch_on, nestor_unplugged.
## Ampoules L1 à L3 : smart_bulbs (SmartBulb « ampoule_couloir_1 » à « _3 »).
## Caméra dôme : cam_led_on (LED éteinte 5 s quand on fixe l'objectif 3 s). Radiateur : RADIATOR_POS.
## Événements Haunt.story_event : « lumiere » {room: "couloir", on}, « nestor_debranche »,
## « camera_led_eteinte ».
## Passe « triple A » (lot V2-COULOIR) :
##  - dans tous les profils : photos HD (assets/images/photos/<kind>.png, repli sur le dessin d'avant, même
##    ordre du hasard), câbles en tubes ronds blanc cassé (cavaliers et chaînette au mur et au plafond),
##    console en commode sculptée (GothicCommode_01, dessus à 0,80 m) ;
##  - rendu net seulement (Qualite.extras_on) : plafonniers à −30 %, tulipes au-dessus du seuil du halo ;
##  - dress_details (vraie carte, après B16) : cadres Poly Haven (hanging_picture_frame_02 et 03) à la
##    place des cadres procéduraux (cachés, laissés en place), tulipes ouvertes et vraies ampoules
##    (lightbulb_01), tapis HD (runner_tile, runner_bord) usé au milieu, vase et vide-poche sur la
##    console, verres de cadres marqués, usure (Wear : poignées, bas des portes, plinthes, pied des murs,
##    suie, tache, moisissure, fissure).

const XW := 3.312        # face du papier peint, mur ouest (côté chambres)
const XE := 4.688        # face du papier peint, mur est (côté salle de bain, escalier, bureau)
const ZN := -7.288       # mur nord (le portrait)
const ZS := 6.288        # mur sud (la fenêtre)
const DADO := 0.022      # épaisseur du lambris (sous 0,92 m)
const LIGHT_Z := [-5.0, -0.5, 4.0]
const LIGHT_ENERGY := 0.35
const BULB_GLOW := 2.6
## Rendu net (Qualite.extras_on : vraie carte, hors style rétro) : plafonniers à −30 % (le blanc et le
## contraste d'AgX et le halo des tulipes font le reste ; à pleine énergie, le plafond brûlait autour des
## suspensions) et tulipes au-dessus du seuil du halo (glow_hdr_threshold = 1). Rétro et rendu logiciel :
## les valeurs de la 0.3.3.
const LIGHT_NET_K := 0.7
const SHADE_GLOW := 0.35
## (étalonnage final : 0,6 au lieu de 1,15 ; la tulipe reste un point chaud, pas une source qui remplit)
const SHADE_GLOW_NET := 0.6
## Couleur de l'émission des tulipes : rétro et logiciel, celle de la 0.3.3 ; rendu net, un ambre plus
## franc (à 1,4 et dans l'orange d'avant, AgX blanchissait la cloche entière).
const SHADE_COLOR := Color(1.0, 0.6, 0.3)
const SHADE_COLOR_NET := Color(1.0, 0.5, 0.2)
## Couloir de nuit, rendu net (lot V2-MAISON) : facteur « au repos » de L1 à L3 (SmartBulb.rest_k). L2, devant
## ta chambre, éclaire ; L1, au nord (Henriette, la salle de bain, le portrait), est une ampoule fatiguée ;
## L3, au sud, est grillée : des îlots de lumière séparés par du noir que la lampe traverse. Quand elle
## passe (flicker, Haunt) ou pendant chain_lights, les trois ampoules répondent. Rétro et rendu logiciel :
## les trois à 1, comme dans la 0.3.3.
## Étalonnage final (lot V3-ETALONNAGE) : à 0,3 et 0,45, le couloir restait éclairé comme un couloir
## d'hôtel (médiane 26/255) et le portrait du fond, à 2,3 m de L1, brûlait ; L1 n'est plus qu'une lueur.
const NIGHT_REST := [0.08, 0.18, 0.0]
## Câbles neufs : PVC blanc cassé (sous une ampoule à incandescence, un câble blanc est gris clair, pas un
## trait de lumière), tubes ronds de 4 mm (le câble réseau : 6 mm, § 5.2), coudes arrondis ; au mur et au
## plafond, un cavalier tous les CLIP_STEP et le câble pend de CABLE_SAG entre deux.
const CABLE_R := 0.002
const CABLE_NET_R := 0.003
const CABLE_SIDES := 8
const CLIP_STEP := 0.3
const CABLE_SAG := 0.0028
const CAM_POS := Vector3(4.0, 2.6, -7.1)   # assez loin du mur pour ne pas mordre sur la corniche
const RADIATOR_POS := Vector3(4.62, 0.45, -2.9)   # centre du radiateur (§ 5.2) : les S.O.S. d'Albert
const STARE_SEC := 3.0           # fixer l'objectif de la caméra dôme 3 s…
const STARE_DEG := 6.0           # (à moins de 6° du centre du regard…
const STARE_DIST := 6.0          # … et à moins de 6 m : regarder le fond du couloir ne suffit pas)
const LED_OFF_SEC := 5.0         # … et sa LED s'éteint 5 s
const TXT_CAMERA := "Une caméra. LED rouge. Elle tourne quand tu bouges."
const TXT_CAMERA_LED := "Elle a éteint sa lumière. Elle sait que tu sais."
const TXT_PORTRAIT := "Mamie et Papi, 1996, surexposés. Ils rient. Tu ne les as jamais vus rire comme ça."

var house: House
var rng := RandomNumberGenerator.new()
var bulbs: Array[OmniLight3D] = []          # les lumières de L1, L2, L3 (celles des SmartBulb)
var smart_bulbs: Array[SmartBulb] = []     # L1, L2, L3 : « ampoule_couloir_1 » à « _3 », du nord au sud
var bulb_mats: Array[StandardMaterial3D] = []
var shade_mats: Array[StandardMaterial3D] = []
var dim := 1.0
var _all_bulbs_until_ms := 0                 # flicker() ou chain_lights() en cours : les trois ampoules répondent
var _flicker_id := 0
var _chain_id := 0
var _dim_tw: Tween

var cam_pivot: Node3D
var cam_target: Node3D
var cam_led: OmniLight3D
var _cam_rest := Vector2(-0.42, PI)   # (tangage, lacet) au repos : vers le sud, vers le bas
var _cam_once := false
var _motor_t := 0.0
var cam_led_mat: StandardMaterial3D
var cam_led_on := true           # la LED rouge de la caméra dôme (éteinte 5 s quand on la fixe 3 s)
var _stare_t := 0.0
var _led_off_t := 0.0

var thermostat: Device
var nestor: Nestor
var nestor_it: Interactable
var nestor_plug: Node3D
var nestor_unplugged := false
var switch_on := true            # l'interrupteur mural des trois ampoules
var switch_rocker: Node3D
var switch_it: Interactable
var feed_cam: FeedCam
var cam_ir: SpotLight3D           # l'infrarouge de CAM 1 : allumé seulement quand son image est regardée
var smoke_led: StandardMaterial3D
var phone_led: StandardMaterial3D
var _cable_mat: StandardMaterial3D
var _tape_mat: StandardMaterial3D
var _new_white: StandardMaterial3D
var _glass: StandardMaterial3D
var _lace: StandardMaterial3D
var _photos := {}
var _n_fancy := 0
var _shade_meshes: Array[MeshInstance3D] = []   # tulipes fermées d'origine (cachées par dress_details)
var _bulb_meshes: Array[MeshInstance3D] = []    # ampoules d'origine (sphères), idem
var _old_frames := {}                           # clé de la photo -> cadre procédural ou doré d'origine
var _old_traces := {}                           # décalques de la 0.3.3 (tache, infiltration, moisissures)
var _runner_holder: Node3D
var _runner_parts: Array[MeshInstance3D] = []   # semelle et motif d'origine du tapis (cachés par le tapis HD)
var _runner_fringes: Array[MeshInstance3D] = [] # franges des deux bouts (le tapis HD leur donne les franges de Builder)
var _pending: Array = []                        # [support de Builder.detail, Callable] : à finir une fois posé
var _clip_mat: StandardMaterial3D
var _paper_mat: StandardMaterial3D
var _photo_mats := {}
var _glass_ph := {}                             # id du modèle de cadre -> verre marqué
var _tulip: Mesh
var _cyl_cache := {}


func furnish(h: House) -> void:
	house = h
	rng.seed = 1031
	_cable_mat = _plain(Color(0.6, 0.6, 0.57), 0.5)
	_clip_mat = _plain(Color(0.74, 0.73, 0.7), 0.45)
	_tape_mat = _plain(Color(0.78, 0.76, 0.68), 0.3)
	_new_white = _plain(Color(0.72, 0.72, 0.7), 0.4)
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Color(0.7, 0.75, 0.8, 0.06)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.roughness = 0.18
	_glass.metallic_specular = 0.45
	_runner()
	_radiator(RADIATOR_POS.z)
	_console()
	_plant()
	_clock()
	_frames()
	_portrait()
	_ceiling_lights()
	_camera()
	_thermostat()
	_smoke_detector()
	_traces()
	_nestor()
	_switch()
	_network_cable()
	_feed_cam()
	# (style rétro changé en cours de partie : les plafonniers reprennent leurs valeurs, voir _light_k)
	if not Qualite.soft():
		Game.settings_changed.connect(_on_settings_changed)


# ------------------------------------------------------------------ outils

func _m(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	return _grimy(_plain(c, rough, metal))


func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := _plain(c * 0.4, 0.4)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func _mesh(mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Cylindre (ou tronc de cône) : Builder.cylinder_mesh, chanfreiné sur vraie carte, un CylinderMesh comme
## avant en rendu logiciel ; un seul maillage par jeu de mesures (les colonnes du radiateur le partagent).
func _cyl(r_top: float, r_bot: float, hh: float, seg := 16) -> Mesh:
	var key := "%.4f|%.4f|%.4f|%d" % [r_top, r_bot, hh, seg]
	if not _cyl_cache.has(key):
		_cyl_cache[key] = Builder.cylinder_mesh(r_top, r_bot, hh, seg)
	return _cyl_cache[key]


func _sphere(r: float, seg := 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s


## Objet émissif : n'entre pas dans l'éclairage indirect cuit (sinon il brillerait encore éteint).
func _no_gi(mi: GeometryInstance3D) -> GeometryInstance3D:
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _look(label: String, size: Vector3, pos: Vector3, text: String, reach := 2.2) -> Interactable:
	var it := _interactable(label, size, pos, self, LAYER_INTERACT, reach)
	it.used.connect(func(_i: Interactable) -> void: Game.hint(text, 4.5))
	return it


## Câble neuf, en PVC blanc cassé : un tube rond, coudes arrondis, fondu en un seul maillage par appel
## (nœud « Cable »). « normal » : la surface sur laquelle il court (mur, plafond ou sol), vers la pièce ;
## les points sont déjà décollés de la surface. tape : fixé sur les tronçons qui longent la surface (25 cm
## au moins) : au sol, un morceau de scotch tous les 40 cm ; au mur et au plafond, un cavalier en plastique
## tous les CLIP_STEP, et le câble pend un peu entre deux (chaînette ; rien à la verticale).
## (Le hasard du couloir ne bouge pas : un tirage par morceau de scotch d'autrefois, même là où un
## cavalier le remplace.)
func _cable(points: Array, normal: Vector3, tape := true, mat: Material = null, radius := CABLE_R) -> MeshInstance3D:
	if mat == null:
		mat = _cable_mat
	var floor_run := normal.dot(Vector3.UP) > 0.7
	var path := PackedVector3Array()
	var clips := []          # [position, direction]
	var tapes := []          # [position, direction, rotation]
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var d := b - a
		var l := d.length()
		if l < 0.001:
			continue
		var dir := d / l
		var along := absf(dir.dot(normal)) <= 0.1 and l >= 0.25
		var jit := PackedFloat32Array()
		if tape and along:
			for k in maxi(1, int(l / 0.4)):
				jit.append(rng.randf_range(-0.12, 0.12))
		if path.is_empty():
			path.append(a)
		if jit.is_empty() or floor_run:
			for k in jit.size():
				tapes.append([a + dir * (l * (k + 0.5) / jit.size()), dir, jit[k]])
			path.append(b)
			continue
		# cavaliers à 4 cm des bouts puis tous les CLIP_STEP au plus ; entre deux, la chaînette (la
		# pesanteur dans le plan du mur, ou vers la pièce sous un plafond)
		var g := Vector3.DOWN - dir * Vector3.DOWN.dot(dir)
		var sag := g.normalized() * CABLE_SAG * g.length() if g.length() > 0.3 else Vector3.ZERO
		var s0 := minf(0.04, l * 0.2)
		var n := maxi(1, ceili((l - 2.0 * s0) / CLIP_STEP))
		var step := (l - 2.0 * s0) / n
		for k in n + 1:
			var c := a + dir * (s0 + step * k)
			clips.append([c, dir])
			if k > 0:
				for u in [0.25, 0.5, 0.75]:
					path.append(a + dir * (s0 + step * (k - 1 + u)) + sag * 4.0 * u * (1.0 - u))
			path.append(c)
		path.append(b)
	var mi := MeshInstance3D.new()
	mi.name = "Cable"
	mi.mesh = _tube_mesh(_round_corners(path), radius, 6 if Builder.soft_render() else CABLE_SIDES)
	mi.material_override = mat
	add_child(mi, true)
	if not clips.is_empty():
		var st := SurfaceTool.new()
		var hc := radius * 2.0 + 0.0025
		var clip := Builder.box_mesh(Vector3(0.011, hc, 0.007))
		for c in clips:
			var dir: Vector3 = c[1]
			var across := normal.cross(dir).normalized()
			var at: Vector3 = c[0] - normal * (radius + 0.0015) + normal * (hc / 2.0)
			st.append_from(clip, 0, Transform3D(Basis(across, normal, dir), at))
		var cm := MeshInstance3D.new()
		cm.name = "Cavaliers"
		cm.mesh = st.commit()
		cm.material_override = _clip_mat
		cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cm, true)
	if not tapes.is_empty():
		var st := SurfaceTool.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.038, radius * 2.0 + 0.0012, 0.024)
		for t in tapes:
			var dir: Vector3 = t[1]
			var across := normal.cross(dir).normalized()
			st.append_from(tb, 0, Transform3D(Basis(across, normal, dir) * Basis(Vector3.UP, float(t[2])), t[0] - normal * 0.0004))
		var tm := MeshInstance3D.new()
		tm.name = "Scotch"
		tm.mesh = st.commit()
		tm.material_override = _tape_mat
		add_child(tm, true)
	return mi


## Coudes arrondis : chaque angle de plus de 15° devient un petit arc (Bézier quadratique) qui part et
## arrive à 12 mm au plus du sommet. Les points confondus sont retirés.
static func _round_corners(p: PackedVector3Array) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for v in p:
		if pts.is_empty() or v.distance_to(pts[pts.size() - 1]) > 0.0005:
			pts.append(v)
	if pts.size() < 3:
		return pts
	var q := PackedVector3Array([pts[0]])
	var lim := cos(deg_to_rad(15.0))
	for i in range(1, pts.size() - 1):
		var c := pts[i]
		var d0 := c - pts[i - 1]
		var d1 := pts[i + 1] - c
		var l0 := d0.length()
		var l1 := d1.length()
		d0 /= l0
		d1 /= l1
		if d0.dot(d1) > lim:
			q.append(c)
			continue
		var f := minf(0.012, minf(l0, l1) * 0.4)
		var a := c - d0 * f
		var b := c + d1 * f
		for k in 5:
			var t := k / 4.0
			q.append(a * (1.0 - t) * (1.0 - t) + c * 2.0 * t * (1.0 - t) + b * t * t)
	q.append(pts[pts.size() - 1])
	return q


## Tube de rayon r le long d'une ligne brisée : un anneau de « sides » sommets par point, repère
## transporté le long du tube (pas de torsion), joints en onglet (épaisseur constante dans les coudes),
## normales lissées, deux bouchons plats.
static func _tube_mesh(p: PackedVector3Array, r: float, sides := CABLE_SIDES) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var n := p.size()
	if n < 2:
		return mesh
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var prev_t := (p[1] - p[0]).normalized()
	var u := prev_t.cross(Vector3.UP)
	if u.length() < 0.1:
		u = prev_t.cross(Vector3.RIGHT)
	u = u.normalized()
	for i in n:
		var tin := (p[i] - p[i - 1]).normalized() if i > 0 else (p[1] - p[0]).normalized()
		var tout := (p[i + 1] - p[i]).normalized() if i < n - 1 else tin
		var t := tin + tout
		t = t.normalized() if t.length() > 0.1 else tout
		var axis := prev_t.cross(t)
		if axis.length() > 1e-6:
			u = u.rotated(axis.normalized(), prev_t.angle_to(t))
		u = (u - t * u.dot(t)).normalized()
		prev_t = t
		var v := t.cross(u)
		var k := 1.0 / maxf(0.5, t.dot(tin))
		var m := tout - tin
		m -= t * m.dot(t)
		var bend := m.length() > 1e-6
		if bend:
			m = m.normalized()
		for j in sides:
			var a := TAU * j / sides
			var w := u * cos(a) + v * sin(a)
			var off := w + m * (w.dot(m) * (k - 1.0)) if bend else w
			verts.append(p[i] + off * r)
			norms.append(w)
	for i in n - 1:
		for j in sides:
			var a := i * sides + j
			var b := i * sides + (j + 1) % sides
			idx.append_array([a, a + sides, b, b, a + sides, b + sides])
	# bouchons (le premier vu de l'arrière du tube, le dernier de l'avant)
	for e in 2:
		var ring := 0 if e == 0 else (n - 1) * sides
		var tn := (p[1] - p[0]).normalized() * -1.0 if e == 0 else (p[n - 1] - p[n - 2]).normalized()
		var c0 := verts.size()
		verts.append(p[0] if e == 0 else p[n - 1])
		norms.append(tn)
		for j in sides:
			verts.append(verts[ring + j])
			norms.append(tn)
		for j in sides:
			var a := c0 + 1 + j
			var b := c0 + 1 + (j + 1) % sides
			if e == 0:
				idx.append_array([c0, a, b])
			else:
				idx.append_array([c0, b, a])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## Prise de courant (ancienne, jaunie) ou conjoncteur téléphonique en T, sur un mur.
func _socket(pos: Vector3, normal: Vector3, kind := "secteur") -> Node3D:
	var holder := Node3D.new()
	holder.name = "Prise"
	add_child(holder)
	holder.position = pos
	holder.rotation.y = atan2(normal.x, normal.z)
	var plate := _m(Color(0.72, 0.68, 0.58), 0.5)
	if kind == "T":
		_box(Vector3(0.07, 0.05, 0.028), Vector3(0, 0, 0.014), plate, false, holder)
		_box(Vector3(0.03, 0.005, 0.003), Vector3(0, 0.008, 0.029), mats.dark, false, holder)
		_box(Vector3(0.005, 0.022, 0.003), Vector3(0, -0.004, 0.029), mats.dark, false, holder)
	else:
		_box(Vector3(0.075, 0.075, 0.012), Vector3(0, 0, 0.006), plate, false, holder)
		_mesh(_cyl(0.023, 0.023, 0.004), Vector3(0, 0, 0.0125), _m(Color(0.6, 0.56, 0.48), 0.5), Vector3(PI / 2.0, 0, 0), holder)
	return holder


## Fiche blanche branchée dans une prise (repère de la prise).
func _plug(socket: Node3D, grey := false) -> void:
	var m: Material = _m(Color(0.6, 0.6, 0.58), 0.45) if grey else _new_white
	_box(Vector3(0.036, 0.042, 0.03), Vector3(0, 0, 0.03), m, false, socket)


## Décalque (tache, moisissure…) posé sur une surface (même convention que decor.gd).
func _decal(tex: Texture2D, center: Vector3, normal: Vector3, up: Vector3, size_u: float, size_v: float, depth := 0.2, mod := Color.WHITE, mix := 1.0) -> Decal:
	var d := Decal.new()
	d.texture_albedo = tex
	d.size = Vector3(size_u, depth, size_v)
	d.modulate = mod
	d.albedo_mix = mix
	var y := normal.normalized()
	var z := -up.normalized()
	var x := y.cross(z)
	d.transform = Transform3D(Basis(x, y, z), center)
	add_child(d)
	return d


# ------------------------------------------------------------------ images générées (photos, tapis)

func _px_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(maxi(0, int(cy - ry)), mini(img.get_height(), int(cy + ry) + 1)):
		for x in range(maxi(0, int(cx - rx)), mini(img.get_width(), int(cx + rx) + 1)):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, c)


func _px_rect(img: Image, x: float, y: float, w: float, hh: float, c: Color) -> void:
	img.fill_rect(Rect2i(int(x), int(y), maxi(1, int(w)), maxi(1, int(hh))), c)


func _px_vgrad(img: Image, y0_: int, y1: int, c0: Color, c1: Color) -> void:
	for y in range(y0_, y1):
		_px_rect(img, 0, y, img.get_width(), 1, c0.lerp(c1, float(y - y0_) / maxf(1.0, y1 - y0_ - 1)))


## Fond tacheté (fond de studio, mur) : une couleur et un peu de bruit.
func _px_mottle(img: Image, base: Color, amount: float, freq := 0.08, seed_ := 1) -> void:
	var nz := FastNoiseLite.new()
	nz.seed = seed_
	nz.frequency = freq
	for y in img.get_height():
		for x in img.get_width():
			var k := nz.get_noise_2d(x, y) * amount
			img.set_pixel(x, y, base.lightened(k) if k > 0.0 else base.darkened(-k))


## Personnage en pied, vu de loin : jambes, buste (ou robe), tête, cheveux.
func _px_person(img: Image, x: float, foot: float, hgt: float, body: Color, hair: Color, dress := false, skin := Color(0.82, 0.62, 0.5), legs := Color(0.15, 0.15, 0.2)) -> void:
	var hr := hgt * 0.1
	var hy := foot - hgt + hr
	var waist := foot - hgt * 0.45
	if dress:
		for y in range(int(hy + hr), int(foot - hgt * 0.08)):
			var k := (y - (hy + hr)) / (foot - hgt * 0.08 - hy - hr)
			var half := hgt * (0.1 + 0.08 * k)
			_px_rect(img, x - half, y, half * 2.0, 1, body)
		_px_rect(img, x - hgt * 0.05, foot - hgt * 0.08, hgt * 0.035, hgt * 0.08, skin)
		_px_rect(img, x + hgt * 0.015, foot - hgt * 0.08, hgt * 0.035, hgt * 0.08, skin)
	else:
		_px_rect(img, x - hgt * 0.08, waist, hgt * 0.07, foot - waist, legs)
		_px_rect(img, x + hgt * 0.01, waist, hgt * 0.07, foot - waist, legs)
		_px_rect(img, x - hgt * 0.12, hy + hr, hgt * 0.24, waist - hy - hr + 1, body)
	_px_ellipse(img, x, hy - hr * 0.15, hr * 0.95, hr * 0.95, hair)
	_px_ellipse(img, x, hy + hr * 0.12, hr * 0.75, hr * 0.85, skin)


## Buste de face, en gros plan (portraits de studio).
func _px_bust(img: Image, x: float, head_y: float, hr: float, body: Color, hair: Color, skin := Color(0.8, 0.62, 0.52), hair_big := 1.0) -> void:
	_px_ellipse(img, x, head_y + hr * 3.4, hr * 2.6, hr * 2.4, body)
	_px_rect(img, x - hr * 0.35, head_y + hr * 0.6, hr * 0.7, hr * 0.9, skin.darkened(0.1))
	_px_ellipse(img, x, head_y - hr * 0.25, hr * 1.02 * hair_big, hr * 1.0 * hair_big, hair)
	_px_ellipse(img, x, head_y + hr * 0.12, hr * 0.8, hr * 0.95, skin)


func _px_eyes(img: Image, x: float, y: float, gap: float, c := Color(0.08, 0.06, 0.05), look := 0.0) -> void:
	img.set_pixel(int(x - gap + look), int(y), c)
	img.set_pixel(int(x + gap + look), int(y), c)


## Le tirage vieillit : jauni, contraste écrasé, grain, coins assombris.
func _develop(img: Image, warm := 0.16, sepia := false, vignette := 0.55, grain := 0.045) -> ImageTexture:
	var w := img.get_width()
	var hh := img.get_height()
	for y in hh:
		for x in w:
			var c := img.get_pixel(x, y)
			if sepia:
				var l := c.get_luminance()
				c = Color(l * 1.08, l * 0.93, l * 0.72)
			c = c.lerp(Color(0.92, 0.8, 0.6), warm)
			c = c.lerp(Color(0.5, 0.46, 0.4), 0.12) * 0.82
			var u := (x + 0.5) / w - 0.5
			var v := (y + 0.5) / hh - 0.5
			var vig := 1.0 - vignette * (u * u + v * v) * 2.0
			var n := rng.randf_range(-grain, grain)
			img.set_pixel(x, y, Color(clampf(c.r * vig + n, 0, 1), clampf(c.g * vig + n, 0, 1), clampf(c.b * vig + n, 0, 1)))
	# un tirage un peu flou plutôt que des pavés de pixels : réduit puis agrandi ×2 (natif, rapide)
	img.resize(int(w * 0.6), int(hh * 0.6), Image.INTERPOLATE_BILINEAR)
	img.resize(w * 2, hh * 2, Image.INTERPOLATE_CUBIC)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Photos de famille des années 90 : les tirages HD du lot V1-IMAGES (PHOTO_DIR, bord du tirage compris),
## ou, si le fichier manque, dessinées pixel par pixel comme avant. Une seule texture par photo (la photo
## de classe est accrochée deux fois). Avec le fichier, les tirages aléatoires du dessin sont rejoués sans
## rien dessiner (_skip_photo) : la suite du hasard du couloir reste la même.
const PHOTO_DIR := "res://assets/images/photos/%s.png"


func _photo(kind: String) -> Texture2D:
	if not _photos.has(kind):
		var path := PHOTO_DIR % kind
		if ResourceLoader.exists(path):
			_skip_photo(kind)
			_photos[kind] = load(path)
		else:
			_photos[kind] = _draw_photo(kind)
	return _photos[kind]


## Les tirages aléatoires de _draw_photo(kind), dans le même ordre, sans dessiner : ceux du dessin (les
## guirlandes de Noël, les fleurs de la robe du portrait de famille), puis un par pixel (grain de _develop).
func _skip_photo(kind: String) -> void:
	var n := 0
	match kind:
		"plage", "jardin", "labo":
			n = 64 * 48
		"mariage":
			n = 48 * 64
		"noel":
			for k in 14:
				rng.randi_range(38, 54)
				rng.randi_range(12, 40)
			n = 64 * 48
		"ecole", "aieule":
			n = 48 * 60
		_:
			for k in 70:
				rng.randf_range(16, 64)
				rng.randf_range(92, 150)
			n = 120 * 150
	for i in n:
		rng.randf_range(-0.05, 0.05)


func _draw_photo(kind: String) -> Texture2D:
	var img: Image
	var skin := Color(0.82, 0.62, 0.5)
	match kind:
		"plage":   # Mamie et ta mère petite, à la mer, sous un parasol
			img = Image.create_empty(64, 48, false, Image.FORMAT_RGB8)
			_px_vgrad(img, 0, 20, Color(0.5, 0.68, 0.84), Color(0.78, 0.84, 0.88))
			_px_vgrad(img, 20, 28, Color(0.15, 0.36, 0.48), Color(0.25, 0.48, 0.55))
			_px_rect(img, 0, 27, 64, 1, Color(0.85, 0.88, 0.85))
			_px_vgrad(img, 28, 48, Color(0.8, 0.72, 0.55), Color(0.72, 0.62, 0.46))
			_px_rect(img, 49, 14, 1, 30, Color(0.3, 0.3, 0.3))
			for y in range(9, 16):
				var half := (y - 8) * 1.6
				for x in range(int(49 - half), int(49 + half)):
					img.set_pixel(x, y, Color(0.75, 0.18, 0.15) if (x / 3) % 2 == 0 else Color(0.9, 0.88, 0.82))
			_px_person(img, 21, 44, 27, Color(0.7, 0.16, 0.18), Color(0.35, 0.22, 0.12), false, skin, skin)
			_px_person(img, 32, 45, 15, Color(0.85, 0.7, 0.2), Color(0.3, 0.18, 0.1), false, skin, skin)
			return _develop(img, 0.2)
		"jardin":   # Papi devant la maison, l'été où il a repeint les volets
			img = Image.create_empty(64, 48, false, Image.FORMAT_RGB8)
			_px_vgrad(img, 0, 14, Color(0.55, 0.62, 0.72), Color(0.7, 0.74, 0.78))
			_px_rect(img, 6, 10, 52, 26, Color(0.8, 0.74, 0.62))
			for y in range(3, 11):
				var inset := (10 - y) * 2.5
				_px_rect(img, 4 + inset, y, 56 - inset * 2.0, 1, Color(0.38, 0.22, 0.18))
			for wx in [12, 40]:
				_px_rect(img, wx - 1, 15, 12, 10, Color(0.2, 0.32, 0.25))
				_px_rect(img, wx + 1, 16, 8, 8, Color(0.1, 0.1, 0.12))
			_px_rect(img, 27, 21, 9, 15, Color(0.28, 0.2, 0.15))
			_px_vgrad(img, 35, 48, Color(0.3, 0.44, 0.2), Color(0.22, 0.34, 0.15))
			_px_person(img, 20, 45, 28, Color(0.25, 0.3, 0.42), Color(0.3, 0.28, 0.26), false, skin, Color(0.3, 0.27, 0.2))
			_px_person(img, 30, 46, 13, Color(0.75, 0.2, 0.2), Color(0.3, 0.18, 0.1), false, skin, Color(0.2, 0.25, 0.45))
			return _develop(img, 0.18)
		"mariage":   # le mariage d'Henriette et Albert, en sépia
			img = Image.create_empty(48, 64, false, Image.FORMAT_RGB8)
			_px_mottle(img, Color(0.55, 0.5, 0.42), 0.18, 0.1, 4)
			_px_ellipse(img, 24, 22, 16, 22, Color(0.32, 0.27, 0.22))
			_px_rect(img, 8, 22, 32, 42, Color(0.32, 0.27, 0.22))
			_px_person(img, 19, 62, 46, Color(0.08, 0.08, 0.08), Color(0.12, 0.1, 0.08), false, skin, Color(0.06, 0.06, 0.06))
			_px_rect(img, 18, 25, 2, 8, Color(0.9, 0.9, 0.88))
			_px_person(img, 30, 63, 42, Color(0.92, 0.9, 0.86), Color(0.25, 0.18, 0.12), true, skin)
			_px_ellipse(img, 31, 30, 3, 2.5, Color(0.85, 0.8, 0.7))
			return _develop(img, 0.1, true, 0.8)
		"noel":   # ta mère, petite, au flash, devant le sapin (les yeux rouges)
			img = Image.create_empty(64, 48, false, Image.FORMAT_RGB8)
			_px_mottle(img, Color(0.18, 0.12, 0.08), 0.25, 0.12, 9)
			for y in range(4, 42):
				var half := (y - 4) * 0.42
				_px_rect(img, 46 - half, y, half * 2.0, 1, Color(0.1, 0.24, 0.12))
			for k in 14:
				img.set_pixel(rng.randi_range(38, 54), rng.randi_range(12, 40), [Color(0.95, 0.8, 0.3), Color(0.9, 0.2, 0.2), Color(0.4, 0.6, 1.0)][k % 3])
			_px_rect(img, 44, 41, 4, 7, Color(0.3, 0.2, 0.12))
			_px_rect(img, 4, 40, 60, 8, Color(0.35, 0.18, 0.12))
			_px_bust(img, 22, 20, 6.5, Color(0.62, 0.12, 0.14), Color(0.32, 0.2, 0.1), Color(0.95, 0.78, 0.68))
			_px_eyes(img, 22, 21, 2, Color(0.95, 0.1, 0.08))
			_px_rect(img, 28, 34, 10, 8, Color(0.2, 0.35, 0.7))
			_px_rect(img, 32, 34, 2, 8, Color(0.9, 0.8, 0.3))
			return _develop(img, 0.12, false, 1.3, 0.05)
		"labo":   # Papi devant le labo, le jour de sa retraite
			img = Image.create_empty(64, 48, false, Image.FORMAT_RGB8)
			_px_vgrad(img, 0, 16, Color(0.6, 0.62, 0.64), Color(0.68, 0.69, 0.7))
			_px_rect(img, 0, 8, 64, 30, Color(0.52, 0.52, 0.5))
			for row in 3:
				for col in 9:
					_px_rect(img, 3 + col * 7, 11 + row * 8, 4, 4, Color(0.2, 0.24, 0.28))
			_px_rect(img, 20, 3, 24, 6, Color(0.78, 0.78, 0.75))
			for k in 5:
				_px_rect(img, 23 + k * 4, 5, 2, 2, Color(0.1, 0.15, 0.35))
			_px_vgrad(img, 38, 48, Color(0.4, 0.4, 0.4), Color(0.32, 0.32, 0.32))
			_px_person(img, 32, 46, 30, Color(0.2, 0.24, 0.36), Color(0.4, 0.38, 0.36), false, skin, Color(0.18, 0.18, 0.2))
			return _develop(img, 0.14)
		"ecole":   # photo de classe de ta mère, fond bleu marbré
			img = Image.create_empty(48, 60, false, Image.FORMAT_RGB8)
			_px_mottle(img, Color(0.38, 0.48, 0.64), 0.3, 0.07, 12)
			_px_bust(img, 24, 26, 9.0, Color(0.55, 0.6, 0.35), Color(0.3, 0.18, 0.1), Color(0.86, 0.68, 0.58), 1.15)
			_px_rect(img, 18, 20, 12, 3, Color(0.3, 0.18, 0.1))
			_px_eyes(img, 24, 27, 3)
			_px_rect(img, 22, 32, 5, 1, Color(0.55, 0.25, 0.22))
			return _develop(img, 0.15)
		"aieule":   # l'arrière-grand-mère, médaillon ovale
			img = Image.create_empty(48, 60, false, Image.FORMAT_RGB8)
			_px_mottle(img, Color(0.5, 0.45, 0.38), 0.15, 0.1, 21)
			_px_bust(img, 24, 25, 8.5, Color(0.12, 0.1, 0.09), Color(0.62, 0.6, 0.56), Color(0.72, 0.62, 0.55), 1.05)
			_px_eyes(img, 24, 26, 3)
			_px_rect(img, 21, 31, 6, 1, Color(0.3, 0.22, 0.2))
			for y in 60:
				for x in 48:
					var dx := (x + 0.5 - 24.0) / 22.0
					var dy := (y + 0.5 - 30.0) / 28.0
					if dx * dx + dy * dy > 1.0:
						img.set_pixel(x, y, Color(0.85, 0.8, 0.68))
			return _develop(img, 0.12, true, 0.4)
	return _family()


## Le grand portrait de famille (studio, vers 2006) : Mamie assise, Papi debout, ta mère à six ans devant
## (photos/famille.png, ou le dessin d'avant).
func _family() -> Texture2D:
	if ResourceLoader.exists(PHOTO_DIR % "famille"):
		_skip_photo("famille")
		return load(PHOTO_DIR % "famille")
	return _draw_family()


func _draw_family() -> ImageTexture:
	var img := Image.create_empty(120, 150, false, Image.FORMAT_RGB8)
	_px_mottle(img, Color(0.22, 0.25, 0.3), 0.35, 0.05, 3)
	_px_ellipse(img, 60, 70, 55, 50, Color(0.3, 0.33, 0.37))
	var halo := FastNoiseLite.new()
	halo.seed = 5
	halo.frequency = 0.06
	for y in 150:
		for x in 120:
			var dx := (x - 60.0) / 55.0
			var dy := (y - 70.0) / 50.0
			if dx * dx + dy * dy < 1.0:
				var k := halo.get_noise_2d(x, y) * 0.2
				img.set_pixel(x, y, img.get_pixel(x, y).lightened(maxf(0.0, k)))
	# Papi, debout à droite : costume sombre, cravate, lunettes, bouche fermée
	_px_bust(img, 82, 50, 11.0, Color(0.1, 0.1, 0.12), Color(0.45, 0.44, 0.42), Color(0.76, 0.6, 0.5))
	_px_ellipse(img, 82, 54, 9.0, 10.5, Color(0.76, 0.6, 0.5))
	for y in range(64, 96):
		var half := maxf(0.0, 7.0 - (y - 64) * 0.2)
		_px_rect(img, 82 - half, y, half * 2.0, 1, Color(0.86, 0.85, 0.8))
	_px_rect(img, 81, 66, 3, 28, Color(0.4, 0.08, 0.09))
	_px_rect(img, 74, 51, 5, 3, Color(0.1, 0.1, 0.1))
	_px_rect(img, 85, 51, 5, 3, Color(0.1, 0.1, 0.1))
	_px_rect(img, 79, 52, 6, 1, Color(0.1, 0.1, 0.1))
	_px_rect(img, 79, 59, 7, 1, Color(0.35, 0.22, 0.2))
	# Mamie, assise à gauche : robe à fleurs, permanente, collier, sourire
	_px_bust(img, 40, 72, 11.0, Color(0.48, 0.18, 0.22), Color(0.62, 0.56, 0.48), Color(0.84, 0.66, 0.56), 1.3)
	for k in 70:
		var p := Vector2(rng.randf_range(16, 64), rng.randf_range(92, 150))
		if (p - Vector2(40, 110)).length() < 34:
			img.set_pixel(int(p.x), int(p.y), Color(0.85, 0.7, 0.68) if k % 2 == 0 else Color(0.9, 0.85, 0.7))
	for k in 11:
		var a := lerpf(0.4, PI - 0.4, k / 10.0)
		img.set_pixel(int(40 + cos(a) * 9.0), int(84 + sin(a) * 5.0), Color(0.95, 0.92, 0.85))
	_px_eyes(img, 40, 73, 3)
	_px_rect(img, 37, 79, 7, 1, Color(0.5, 0.2, 0.2))
	img.set_pixel(36, 78, Color(0.5, 0.2, 0.2))
	img.set_pixel(44, 78, Color(0.5, 0.2, 0.2))
	# ta mère, six ans, devant : robe jaune, col blanc, carré brun. Elle regarde à côté.
	_px_bust(img, 62, 112, 8.0, Color(0.78, 0.62, 0.2), Color(0.3, 0.18, 0.1), Color(0.88, 0.7, 0.6), 1.15)
	_px_rect(img, 54, 104, 16, 3, Color(0.3, 0.18, 0.1))
	_px_ellipse(img, 62, 124, 8, 3, Color(0.92, 0.9, 0.84))
	_px_eyes(img, 62, 113, 3, Color(0.06, 0.04, 0.04), -2.0)
	_px_rect(img, 60, 118, 4, 1, Color(0.45, 0.22, 0.2))
	# signature du photographe
	_px_rect(img, 96, 142, 14, 1, Color(0.7, 0.6, 0.35))
	_px_rect(img, 98, 140, 1, 2, Color(0.7, 0.6, 0.35))
	return _develop(img, 0.14, false, 0.75, 0.035)


## Tapis de couloir : champ rouge, galon bleu nuit, médaillons ; râpé jusqu'à la trame au milieu.
func _runner_texture(w: int, hgt: int) -> ImageTexture:
	var img := Image.create_empty(w, hgt, false, Image.FORMAT_RGB8)
	var red := Color(0.4, 0.075, 0.065)
	var red2 := Color(0.52, 0.14, 0.1)
	var navy := Color(0.1, 0.09, 0.15)
	var ochre := Color(0.56, 0.4, 0.17)
	var dark := Color(0.16, 0.035, 0.03)
	var weft := Color(0.46, 0.38, 0.32)
	var nz := FastNoiseLite.new()
	nz.seed = 31
	nz.frequency = 0.04
	var stains := FastNoiseLite.new()
	stains.seed = 7
	stains.frequency = 0.09
	var period := 64
	var fw := (w - 18) / 2.0
	for y in hgt:
		for x in w:
			var e := mini(x, w - 1 - x)
			var c: Color = red
			if e < 2:
				c = dark
			elif e == 2 or e == 8:
				c = ochre
			elif e < 8:
				c = navy
				if e == 5 and y % 6 < 2:
					c = ochre
			else:
				var dx := absf(x - (w - 1) / 2.0) / fw
				var dy := absf(float(y % period) - period / 2.0) / (period * 0.42)
				var dd := dx + dy
				if dd < 0.3:
					c = ochre
				elif dd < 0.55:
					c = red2
				elif dd < 0.7:
					c = navy
				elif dd > 0.98 and dd < 1.08:
					c = dark
			var u := float(x) / (w - 1)
			var path := exp(-pow((u - 0.5) / 0.26, 2.0))
			var wear := clampf(path * (0.7 + 1.1 * nz.get_noise_2d(x, y * 0.5)), 0.0, 1.0)
			var ends := clampf(1.0 - minf(y, hgt - 1 - y) / 40.0, 0.0, 1.0)
			c = c.lerp(weft, clampf(wear * 0.85 + ends * 0.4, 0.0, 0.9))
			c = c.lerp(Color(0.3, 0.24, 0.2), 0.28)
			if stains.get_noise_2d(x, y) > 0.42:
				c = c.darkened(0.35)
			c = c.darkened(rng.randf() * 0.14)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _fringe_texture() -> ImageTexture:
	var img := Image.create_empty(96, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(0, 96, 2):
		var l := rng.randi_range(4, 8)
		for y in l:
			img.set_pixel(x, y, Color(0.6, 0.54, 0.44, 1.0).darkened(rng.randf() * 0.25))
	return ImageTexture.create_from_image(img)


## Napperon en dentelle (crochet de Mamie).
func _lace_texture() -> ImageTexture:
	var n := 64
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0) / (n / 2.0)
			var r := p.length()
			if r > 1.0:
				continue
			var a := atan2(p.y, p.x)
			var holes := sin(a * 14.0) * sin(r * PI * 7.0)
			var edge := r > 0.9 and sin(a * 28.0) < 0.2
			if holes < 0.45 and not edge:
				img.set_pixel(x, y, Color(0.82, 0.78, 0.68, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Matière du napperon (une seule, partagée par la console et la sellette).
## (pas de _grimy ici : détail + transparence découpée bloque le rendu avec llvmpipe)
func _lace_mat() -> StandardMaterial3D:
	if _lace == null:
		_lace = StandardMaterial3D.new()
		_lace.albedo_texture = _lace_texture()
		_lace.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_lace.roughness = 1.0
	return _lace


## Trace laissée sur le papier peint par un cadre qu'on a décroché : le papier a jauni et noirci
## autour, pas dessous. On dessine le liseré sombre autour du rectangle resté propre.
func _ghost_texture() -> ImageTexture:
	var w := 40
	var hh := 48
	var m := 6
	var img := Image.create_empty(w, hh, false, Image.FORMAT_RGBA8)
	for y in hh:
		for x in w:
			var dx := maxf(0.0, maxf(m - x, x - (w - 1 - m)))
			var dy := maxf(0.0, maxf(m - y, y - (hh - 1 - m)))
			var d := Vector2(dx, dy).length()
			var a := 0.0
			if d > 0.0:
				a = clampf(1.0 - d / m, 0.0, 1.0) * 0.75
			img.set_pixel(x, y, Color(0.16, 0.12, 0.08, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ sol : tapis, radiateur, plante

## Le tapis du couloir, motif de _runner_texture() recalculé à 192 × 2976 px (outil de l'agent de
## corrections : agents_gfx/corrections/tools/gen_runner.gd). Sur vraie carte, dress_details pose par-dessus
## le tapis HD (_dress_runner) et cache celui-ci (même nœud « Tapis », même empreinte, pour _scan_rugs).
const RUNNER_TEX := "res://assets/textures/runner_couloir.png"
const RUNNER_W := 0.8
const RUNNER_Z0 := -6.75
const RUNNER_Z1 := 5.65


func _runner() -> void:
	var z0 := RUNNER_Z0
	var z1 := RUNNER_Z1
	var w := RUNNER_W
	var l := z1 - z0
	var holder := Node3D.new()
	holder.name = "Tapis"
	add_child(holder)
	holder.position = Vector3(4.0, 0, (z0 + z1) / 2.0)
	holder.rotation.y = 0.005   # posé à la main, pas tout à fait droit
	_runner_holder = holder
	_runner_parts.append(_box(Vector3(w, 0.007, l), Vector3(0, 0.0035, 0), _plain(Color(0.1, 0.035, 0.03), 1.0), false, holder))
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, l)
	var mat := StandardMaterial3D.new()
	if ResourceLoader.exists(RUNNER_TEX):
		# le motif d'origine recalculé à 4 × la résolution (240 px/m : net en 1080p), même trame
		mat.albedo_texture = load(RUNNER_TEX)
		for i in 48 * int(l * 60.0):
			rng.randf()      # (même suite aléatoire qu'avant pour le reste du couloir)
	else:
		mat.albedo_texture = _runner_texture(48, int(l * 60.0))
	mat.roughness = 1.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_runner_parts.append(_mesh(pm, Vector3(0, 0.0072, 0), _grimy(mat, 0.5), Vector3.ZERO, holder))
	var fr := StandardMaterial3D.new()
	fr.albedo_texture = _fringe_texture()
	fr.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	fr.roughness = 1.0
	for s in [-1.0, 1.0]:
		var fp := PlaneMesh.new()
		fp.size = Vector2(w * 0.96, 0.055)
		_runner_fringes.append(_mesh(fp, Vector3(0, 0.0022, s * (l / 2.0 + 0.026)), fr, Vector3(0, 0.0 if s > 0.0 else PI, 0), holder))


## Radiateur en fonte à colonnes (1 m, 0,6 m de haut, centré en y 0,45), peint crème (la peinture
## s'écaille), avec sa tête thermostatique connectée toute neuve. Contre le mur est (§ 5.2), centré en z :
## c'est lui qui transmet les S.O.S. d'Albert.
func _radiator(z: float) -> void:
	var n := 16
	var step := 0.062
	var l := n * step
	var depth := 0.15
	var x := XE - DADO - 0.04 - depth / 2.0
	# fonte peinte en crème, écaillée : la peinture des portes (PaintedWood009C), plus jaune et plus sombre
	var paint := Surfaces.grime(Surfaces.pbr("PaintedWood009C/PaintedWood009C", 0.6, Color(0.66, 0.6, 0.5), 0.5, false), 1.2)
	var y0_ := RADIATOR_POS.y - 0.3
	var hh := 0.6
	for i in n:
		var zz := z - l / 2.0 + step * (i + 0.5)
		for side in [-1.0, 1.0]:
			_mesh(_cyl(0.019, 0.019, hh - 0.06, 8), Vector3(x + side * 0.045, y0_ + hh / 2.0, zz), paint)
		_box(Vector3(depth - 0.02, 0.05, 0.052), Vector3(x, y0_ + hh - 0.03, zz), paint)
		_box(Vector3(depth - 0.02, 0.05, 0.052), Vector3(x, y0_ + 0.03, zz), paint)
		_box(Vector3(0.03, hh - 0.1, 0.05), Vector3(x, y0_ + hh / 2.0, zz), paint)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.1, y0_ + 0.02, 0.05), Vector3(x, (y0_ + 0.02) / 2.0, z + side * (l / 2.0 - 0.09)), paint)
	# tuyau d'arrivée qui sort du parquet, robinet, tête connectée blanche
	var pipe := _m(Color(0.5, 0.47, 0.4), 0.45, 0.5)
	var pz := z + l / 2.0 + 0.045
	_mesh(_cyl(0.011, 0.011, y0_ + hh - 0.06, 8), Vector3(x + 0.03, (y0_ + hh - 0.06) / 2.0, pz), pipe)
	_mesh(_cyl(0.011, 0.011, 0.06, 8), Vector3(x + 0.03, y0_ + hh - 0.06, pz - 0.03), pipe, Vector3(PI / 2.0, 0, 0))
	_mesh(_cyl(0.016, 0.016, 0.04, 10), Vector3(x + 0.03, y0_ + hh - 0.04, pz), _m(Color(0.55, 0.45, 0.22), 0.35, 0.7))
	_mesh(_cyl(0.026, 0.026, 0.075, 16), Vector3(x + 0.03, y0_ + hh + 0.02, pz), _new_white)
	var led := _no_gi(_mesh(_sphere(0.0035, 6), Vector3(x + 0.03 - 0.024, y0_ + hh + 0.035, pz), _glow(Color(0.2, 1.0, 0.35), 2.5)))
	led.name = "LedVanne"
	_collider(Vector3(depth + 0.04, y0_ + hh + 0.08, l + 0.1), Vector3(x, (y0_ + hh + 0.08) / 2.0, z + 0.02))


## Sous la fenêtre du bout : la sellette et la plante grasse de Mamie, qu'elle arrose tous les
## dimanches, sur un napperon (modèles Poly Haven, CC0).
func _plant() -> void:
	var c := Vector3(4.0, 0.0, ZS - 0.26)
	var stand := model("side_table_tall_01", c, 20.0, Vector3.ZERO, true,
		{"name": "Sellette", "tint": Color(0.62, 0.52, 0.44)})
	var top := (stand.get_meta("size") as Vector3).y
	var lq := PlaneMesh.new()
	lq.size = Vector2(0.27, 0.27)
	_mesh(lq, c + Vector3(0.01, top + 0.0015, 0.0), _lace_mat(), Vector3(0, 0.5, 0))
	model("potted_plant_04", c + Vector3(0.0, top + 0.003, 0.0), 35.0, Vector3(0, 0.42, 0), false, {"name": "pottedPlant"})


## L'horloge comtoise de Papi, au fond du couloir, à côté de la chambre des grands-parents (modèle Poly
## Haven, CC0, à 90 % : 1,97 m). Elle s'est arrêtée à 3 h 12 : ses deux aiguilles sont des nœuds du
## glTF, tournées depuis leur position d'origine (heures sur 312,7°, minutes sur 222,7°, en degrés
## comptés dans le sens horaire depuis midi ; vu de face, une rotation positive autour de z tourne dans
## le sens inverse).
const CLOCK_Z := -6.25
const CLOCK_HANDS := {"Hour": [312.68, 96.0], "Minute": [222.74, 72.0]}


func _clock() -> void:
	var depth := 0.426 * 0.9
	var clk := model("vintage_grandfather_clock_01", Vector3(XW + DADO + 0.008 + depth / 2.0, 0, CLOCK_Z), 90.0,
		Vector3(0, 1.97, 0), true, {"name": "Horloge", "tint": Color(0.8, 0.74, 0.68)})
	for n in clk.find_children("*Hand*", "Node3D", true, false):
		var nd := n as Node3D
		for k in CLOCK_HANDS:
			if String(nd.name).contains(k):
				nd.rotation.z = deg_to_rad(float(CLOCK_HANDS[k][0]) - float(CLOCK_HANDS[k][1]))


# ------------------------------------------------------------------ la console et le téléphone

const CONSOLE_PH := "GothicCommode_01"


func _console() -> void:
	var cz := -1.0          # § 5.2 : console en (3.52, 0, −1.0) ; Nestor au milieu, la base du téléphone en z −0.8
	var phz := cz + 0.2     # base du téléphone sans fil
	var taz := cz - 0.2     # boîtier de téléassistance
	var depth := 0.38
	var cx := XW + DADO + 0.01 + depth / 2.0
	# la console : une petite commode sculptée (GothicCommode_01, Poly Haven, CC0 ; celle des grands-parents,
	# déjà chargée), à la place et à la hauteur du § 5.2 : dessus à 0,80 m, 0,38 m de profondeur, 0,79 m le
	# long du mur. Sans elle (« -- --kenney », fichier absent), le sideTable Kenney d'avant, à sa taille.
	var ph_ok := not OS.get_cmdline_user_args().has("--kenney") and ResourceLoader.exists(PH_PATH % [CONSOLE_PH, CONSOLE_PH])
	var table := prop("sideTable", Vector3(cx, 0, cz), 90.0, Vector3(0.9, 0.8, 0.0 if ph_ok else depth), true, {}, "",
		CONSOLE_PH if ph_ok else "")
	var top := (table.get_meta("size") as Vector3).y
	var half := (table.get_meta("size") as Vector3).x / 2.0     # demi-longueur le long du mur
	# (Kenney : un merisier foncé, ciré, plutôt que le bois clair des meubles neufs : le bois des meubles,
	# Wood027, plus sombre ; la commode garde ses matières)
	var cherry := Surfaces.grime(Surfaces.pbr("Wood027/Wood027", 1.2, Color(0.46, 0.31, 0.24), 1.0, false))
	for n in table.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var sm := mi.mesh.surface_get_material(i)
			if sm and sm.resource_name.to_lower() == "wood":
				mi.set_surface_override_material(i, cherry)
	# napperon au crochet
	var lq := PlaneMesh.new()
	lq.size = Vector2(0.3, 0.3)
	_mesh(lq, Vector3(cx + 0.02, top + 0.0015, phz + 0.04), _lace_mat(), Vector3(0, 0.3, 0))
	# téléphone sans fil sur sa base : combiné debout, petite antenne, LED verte
	var ph := Node3D.new()
	ph.name = "Telephone"
	add_child(ph)
	ph.position = Vector3(cx + 0.02, top + 0.003, phz)
	ph.rotation.y = PI / 2.0 - 0.25
	var grey := _m(Color(0.16, 0.16, 0.17), 0.45)
	_box(Vector3(0.12, 0.032, 0.15), Vector3(0, 0.016, 0), grey, false, ph)
	_box(Vector3(0.07, 0.03, 0.05), Vector3(0, 0.045, -0.035), grey, false, ph)
	var hs := _box(Vector3(0.05, 0.19, 0.03), Vector3(0, 0.125, -0.03), _m(Color(0.2, 0.2, 0.21), 0.4), false, ph)
	hs.rotation.x = -0.22
	_box(Vector3(0.036, 0.03, 0.002), Vector3(0, 0.07, 0.016), _m(Color(0.4, 0.4, 0.38), 0.5), false, hs)
	_no_gi(_box(Vector3(0.03, 0.018, 0.002), Vector3(0, 0.045, 0.016), _glow(Color(0.35, 0.55, 0.3), 0.35), false, hs))
	_mesh(_cyl(0.005, 0.006, 0.05, 6), Vector3(0.018, 0.115, -0.003), grey, Vector3.ZERO, hs)
	phone_led = _glow(Color(0.15, 1.0, 0.3), 4.0)
	_no_gi(_box(Vector3(0.008, 0.005, 0.004), Vector3(0.035, 0.024, 0.075), phone_led, false, ph))
	# l'étiquette de la téléassistance collée au feutre sous la base : on ne la voit pas, on la lit
	# boîtier de téléassistance : blanc, neuf, gros bouton rouge
	var ta := Node3D.new()
	ta.name = "Teleassistance"
	add_child(ta)
	ta.position = Vector3(cx + 0.03, top, taz)
	ta.rotation.y = PI / 2.0 + 0.08
	_box(Vector3(0.16, 0.045, 0.11), Vector3(0, 0.0225, 0), _new_white, false, ta)
	_mesh(_cyl(0.026, 0.028, 0.014, 16), Vector3(0, 0.052, 0.005), _glow(Color(0.7, 0.06, 0.05), 0.25), Vector3.ZERO, ta)
	_no_gi(_box(Vector3(0.006, 0.004, 0.003), Vector3(0.06, 0.03, 0.056), _glow(Color(0.2, 1.0, 0.3), 3.0), false, ta))
	# carnet et stylo (les numéros importants, de la main de Mamie), au coin du plateau
	var pad := _box(Vector3(0.1, 0.012, 0.15), Vector3(cx + 0.06, top + 0.006, cz - minf(0.36, half - 0.06)), _m(Color(0.8, 0.76, 0.62), 0.9))
	pad.rotation.y = 0.2
	_mesh(_cyl(0.004, 0.004, 0.13, 6), Vector3(cx + 0.1, top + 0.016, cz - minf(0.34, half - 0.08)), _m(Color(0.1, 0.15, 0.4), 0.4), Vector3(PI / 2.0, 0.5, 0))
	# prises sous la console : l'ancien conjoncteur en T et une prise ; câbles qui pendent
	var t_sock := _socket(Vector3(XW + DADO, 0.24, cz + 0.62), Vector3.RIGHT, "T")
	_plug(t_sock, true)
	var p_sock := _socket(Vector3(XW + DADO, 0.24, cz + 0.76), Vector3.RIGHT)
	_plug(p_sock)
	# (le long du fond du plateau, puis par-dessus son bord, jusqu'aux prises)
	var bx := XW + DADO + 0.012
	_cable([Vector3(cx - 0.03, top + 0.004, phz), Vector3(bx + 0.02, top + 0.004, phz + 0.06),
		Vector3(bx + 0.02, top + 0.004, cz + half - 0.02), Vector3(bx + 0.008, top - 0.03, cz + half + 0.05), Vector3(bx + 0.01, 0.262, cz + 0.62)],
		Vector3.RIGHT, false, _m(Color(0.36, 0.35, 0.33), 0.5))
	_cable([Vector3(cx - 0.04, top + 0.004, taz), Vector3(bx + 0.03, top + 0.004, taz + 0.06),
		Vector3(bx + 0.03, top + 0.004, cz + half - 0.01), Vector3(bx + 0.006, top - 0.02, cz + half + 0.07), Vector3(bx + 0.01, 0.262, cz + 0.76)],
		Vector3.RIGHT, false)
	# (boîte basse et étroite : elle ne doit pas masquer Nestor, juste derrière, au joueur qui arrive du sud)
	_look("Regarder le téléphone", Vector3(0.18, 0.12, 0.18), Vector3(cx + 0.02, top + 0.06, phz),
		"Le sans-fil de Mamie. Sous la base, l'étiquette de la téléassistance : « En cas de chute, ne bougez pas. On vous voit. »")
	# la chaise du téléphone, de l'autre côté
	prop("chair", Vector3(XW + DADO + 0.222, 0, cz - 0.9), 90.0 + 5.0, Vector3(0.4, 0.86, 0.4))


# ------------------------------------------------------------------ murs : cadres, portrait

## Cadre accroché au mur. « facing » : vers la pièce. tilt : de travers (radians).
func _frame(pos: Vector3, facing: Vector3, size: Vector2, tex: Texture2D, style := "bois", tilt := 0.0, margin := 0.0) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Cadre"
	add_child(holder)
	holder.position = pos
	holder.rotation = Vector3(0, atan2(facing.x, facing.z), tilt)
	var b := 0.026 if size.x < 0.5 else 0.06
	var d := 0.022 if size.x < 0.5 else 0.04
	var fm: Material
	match style:
		"dore":
			fm = _m(Color(0.52, 0.4, 0.18), 0.4, 0.6)
		"pin":
			fm = mats.wood
		"noir":
			fm = _m(Color(0.05, 0.05, 0.05), 0.3)
		_:
			fm = mats.wood_dark
	_box(Vector3(size.x - 0.01, size.y - 0.01, 0.006), Vector3(0, 0, 0.003), mats.dark, false, holder)
	_box(Vector3(size.x, b, d), Vector3(0, size.y / 2.0 - b / 2.0, d / 2.0), fm, false, holder)
	_box(Vector3(size.x, b, d), Vector3(0, -size.y / 2.0 + b / 2.0, d / 2.0), fm, false, holder)
	_box(Vector3(b, size.y - 2.0 * b, d), Vector3(-size.x / 2.0 + b / 2.0, 0, d / 2.0), fm, false, holder)
	_box(Vector3(b, size.y - 2.0 * b, d), Vector3(size.x / 2.0 - b / 2.0, 0, d / 2.0), fm, false, holder)
	var inner := size - Vector2(2.0 * b, 2.0 * b)
	var pic := StandardMaterial3D.new()
	pic.albedo_texture = tex
	pic.roughness = 0.8
	pic.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if margin > 0.0:
		_quad(inner, Vector3(0, 0, d * 0.4), _m(Color(0.78, 0.74, 0.64), 0.9), 0.0, holder)
		_quad(inner - Vector2(2.0 * margin, 2.0 * margin), Vector3(0, 0, d * 0.4 + 0.001), pic, 0.0, holder)
	else:
		_quad(inner, Vector3(0, 0, d * 0.4), pic, 0.0, holder)
	var g := _quad(inner, Vector3(0, 0, d * 0.8), _glass, 0.0, holder)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return holder


## Cadre doré mouluré (fancy_picture_frame_01, Poly Haven, CC0 : 0,603 × 0,464, toile 0,539 × 0,400,
## face avant +z, épaisseur 2 cm). « size » : taille extérieure voulue ; le grand côté est respecté, le
## cadre est tourné d'un quart de tour s'il est plus haut que large. La toile du modèle est retirée : la
## photo (quad) est posée à sa place, sous un verre ; « margin » : passe-partout crème.
const FANCY := "fancy_picture_frame_01"
const FANCY_SIZE := Vector2(0.603, 0.464)
const FANCY_CANVAS := Vector2(0.539, 0.4)


func _fancy_frame(pos: Vector3, facing: Vector3, size: Vector2, tex: Texture2D, tilt := 0.0, margin := 0.0) -> Node3D:
	var holder := Node3D.new()
	holder.name = "CadreDore"
	add_child(holder)
	holder.position = pos
	holder.rotation = Vector3(0, atan2(facing.x, facing.z), tilt)
	var portrait := size.y > size.x
	var s := maxf(size.x, size.y) / FANCY_SIZE.x
	var roll := Node3D.new()
	holder.add_child(roll)
	roll.rotation.z = PI / 2.0 if portrait else 0.0
	_n_fancy += 1
	var fr := model(FANCY, Vector3(0, -FANCY_SIZE.y * s / 2.0, 0.01 * s), 0.0, Vector3(FANCY_SIZE.x * s, 0, 0), false,
		{"name": "CadreDore%d" % _n_fancy, "parent": roll})
	for n in fr.find_children("*canvas*", "MeshInstance3D", true, false):
		n.queue_free()
	var canvas := FANCY_CANVAS * s
	if portrait:
		canvas = Vector2(canvas.y, canvas.x)
	var z := 0.0047 * s + 0.001
	var pic := StandardMaterial3D.new()
	pic.albedo_texture = tex
	pic.roughness = 0.8
	pic.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if margin > 0.0:
		_quad(canvas, Vector3(0, 0, z), _m(Color(0.78, 0.74, 0.64), 0.9), 0.0, holder)
		_quad(canvas - Vector2(2.0 * margin, 2.0 * margin), Vector3(0, 0, z + 0.001), pic, 0.0, holder)
	else:
		_quad(canvas, Vector3(0, 0, z), pic, 0.0, holder)
	var g := _quad(canvas, Vector3(0, 0, z + 0.004), _glass, 0.0, holder)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return holder


func _frames() -> void:
	var w := Vector3.RIGHT     # accrochés au mur ouest, ils regardent vers +x
	var e := Vector3.LEFT      # mur est, vers -x
	# (les cadres procéduraux restent en rendu logiciel ; sur vraie carte, dress_details les cache sous
	# les cadres Poly Haven posés à leur place, voir PH_FRAMES)
	# bout nord, mur est : Papi au labo, la plage
	_old_frames["labo"] = _frame(Vector3(XE, 1.66, -6.3), e, Vector2(0.34, 0.27), _photo("labo"), "noir", 0.0, 0.03)
	# mur ouest, entre le portrait et la porte des grands-parents : l'arrière-grand-mère
	_old_frames["aieule"] = _fancy_frame(Vector3(XW, 1.6, -5.6), w, Vector2(0.3, 0.38), _photo("aieule"), -0.025)
	# mur ouest, de part et d'autre de la console : le mariage, la photo de classe ; Noël au-dessus
	_fancy_frame(Vector3(XW, 1.72, -2.0), w, Vector2(0.26, 0.34), _photo("mariage"), 0.02, 0.022)
	_old_frames["noel"] = _frame(Vector3(XW, 1.5, -1.0), w, Vector2(0.36, 0.28), _photo("noel"), "pin", -0.015)
	_old_frames["ecole"] = _frame(Vector3(XW, 1.66, 0.2), w, Vector2(0.2, 0.25), _photo("ecole"), "bois", 0.04)
	# mur est, au-dessus du radiateur : la trace d'un cadre décroché
	_decal(_ghost_texture(), Vector3(XE, 1.62, -2.5), Vector3.LEFT, Vector3.UP, 0.34, 0.41, 0.06)
	_mesh(_cyl(0.003, 0.003, 0.02, 6), Vector3(XE - 0.01, 1.83, -2.5), mats.metal, Vector3(0, 0, PI / 2.0))
	# bout sud, mur ouest : la plage ; mur est, près de la fenêtre : le jardin
	_old_frames["plage"] = _frame(Vector3(XW, 1.6, 5.2), w, Vector2(0.4, 0.31), _photo("plage"), "bois", 0.03, 0.03)
	_old_frames["jardin"] = _frame(Vector3(XE, 1.58, 5.6), e, Vector2(0.42, 0.32), _photo("jardin"), "pin", 0.0, 0.03)
	# mur est, entre l'escalier et le bureau
	_fancy_frame(Vector3(XE, 1.62, 2.6), e, Vector2(0.3, 0.38), _photo("ecole"), -0.03)


## Le portrait « 1996 » au bout nord (§ 5.2) : image 0,6 × 0,8 (portrait_1996.png, surexposé, sans
## visages) dans un cadre doré.
func _portrait() -> void:
	var c := Vector3(4.0, 1.6, ZN)
	_fancy_frame(c, Vector3.BACK, Vector2(0.72, 0.92), load("res://assets/images/portrait_1996.png"))
	# le cordon, le clou
	_mesh(_cyl(0.004, 0.004, 0.02, 6), Vector3(4.0, 2.16, ZN + 0.01), mats.metal, Vector3(PI / 2.0, 0, 0))
	_cable([Vector3(3.85, 2.05, ZN + 0.008), Vector3(4.0, 2.16, ZN + 0.008), Vector3(4.15, 2.05, ZN + 0.008)],
		Vector3.BACK, false, _m(Color(0.3, 0.25, 0.15), 0.8), 0.0015)
	_look("Regarder le portrait", Vector3(0.76, 0.96, 0.1), c + Vector3(0, 0, 0.05), TXT_PORTRAIT)


# ------------------------------------------------------------------ plafond : ampoules connectées

## L1, L2, L3 : tulipes des années 70 et, dedans, les ampoules connectées du fournisseur d'énergie
## (SmartBulb « ampoule_couloir_1 » à « _3 », du nord au sud) : Haunt.move les fait vaciller quand elle
## passe ; le couloir les pilote (flicker, set_dim, chain_lights) par leur niveau.
func _ceiling_lights() -> void:
	for li in LIGHT_Z.size():
		var z: float = LIGHT_Z[li]
		var top := Vector3(4.0, 2.6, z)
		_mesh(_cyl(0.05, 0.055, 0.022), top + Vector3(0, -0.011, 0), _m(Color(0.7, 0.66, 0.58), 0.6))
		_mesh(_cyl(0.0035, 0.0035, 0.22, 6), top + Vector3(0, -0.13, 0), _plain(Color(0.12, 0.08, 0.05), 0.8))
		_mesh(_cyl(0.018, 0.02, 0.05), top + Vector3(0, -0.26, 0), _m(Color(0.5, 0.4, 0.2), 0.4, 0.7))
		# tulipe en verre ambré, des années 70, et dedans l'ampoule du fournisseur d'énergie
		var shade := _cyl(0.03, 0.115, 0.14, 20)
		# (pas de CULL_DISABLED : avec llvmpipe, cette variante de shader bloque le rendu)
		var sm := _plain(Color(0.55, 0.36, 0.18), 0.35)
		sm.emission_enabled = true
		sm.emission = _shade_color()
		sm.emission_energy_multiplier = 0.35
		shade_mats.append(sm)
		_shade_meshes.append(_no_gi(_mesh(shade, top + Vector3(0, -0.31, 0), sm)) as MeshInstance3D)
		_mesh(_cyl(0.02, 0.02, 0.03, 12), top + Vector3(0, -0.3, 0), _new_white)
		var bm := _glow(Color(1.0, 0.78, 0.5), BULB_GLOW)
		bulb_mats.append(bm)
		_bulb_meshes.append(_no_gi(_mesh(_sphere(0.032), top + Vector3(0, -0.37, 0), bm)) as MeshInstance3D)
		var sb := SmartBulb.new()
		sb.name = "L%d" % (li + 1)
		sb.device_id = "ampoule_couloir_%d" % (li + 1)
		sb.room_id = "couloir"
		sb.energy = LIGHT_ENERGY * _light_k()
		sb.light_range = 4.0
		sb.bulb_glow = BULB_GLOW
		sb.show_bulb = false          # (l'ampoule visible est celle de la tulipe)
		add_child(sb)
		sb.position = top + Vector3(0, -0.345, 0)
		sb.build()
		sb.add_glow_material(bm, BULB_GLOW)
		sb.add_glow_material(sm, _shade_glow())
		smart_bulbs.append(sb)
		bulbs.append(sb.light)
		sb.set_rest(_rest(li))


## Plafonniers : facteur d'énergie et émission des tulipes selon le rendu (net : LIGHT_NET_K et
## SHADE_GLOW_NET ; rétro et rendu logiciel : la 0.3.3).
func _light_k() -> float:
	return LIGHT_NET_K if Qualite.extras_on() else 1.0


func _shade_glow() -> float:
	return Main.tune("tulipe", SHADE_GLOW_NET) if Qualite.extras_on() else SHADE_GLOW


## Facteur au repos de l'ampoule i (voir NIGHT_REST).
func _rest(i: int) -> float:
	if not Qualite.extras_on() or Time.get_ticks_msec() < _all_bulbs_until_ms:
		return 1.0
	return Main.tune("couloir_l%d" % (i + 1), float(NIGHT_REST[i]))


func _shade_color() -> Color:
	return SHADE_COLOR_NET if Qualite.extras_on() else SHADE_COLOR


## Un réglage a changé (le style rétro, en cours de partie) : énergie de base des ampoules et émission de
## base des tulipes (SmartBulb._extra, lu prudemment), puis réapplication du niveau courant.
func _on_settings_changed() -> void:
	for i in smart_bulbs.size():
		var sb := smart_bulbs[i]
		sb.energy = LIGHT_ENERGY * _light_k()
		shade_mats[i].emission = _shade_color()
		var ex: Variant = sb.get("_extra")
		if ex is Array:
			for e in ex:
				if e is Array and (e as Array).size() >= 2 and e[0] == shade_mats[i]:
					e[1] = _shade_glow()
		sb.rest_k = _rest(i)
		sb.set_powered(sb.powered)


func _apply_bulb(i: int, k: float) -> void:
	if not switch_on:
		k = 0.0                  # interrupteur coupé : plus de courant, rien ne s'allume
	# (l'ampoule connectée applique le niveau à sa lumière, à l'ampoule et à la tulipe)
	smart_bulbs[i].rest_k = _rest(i)
	smart_bulbs[i].set_level(k)


func _apply_all() -> void:
	for i in bulbs.size():
		_apply_bulb(i, dim)
	_update_switch_label()


## Le libellé de l'interrupteur suit ce qu'on voit : couloir noir (coupé, ou ampoules baissées à 0
## par elle), « Allumer la lumière » ; sinon « Éteindre la lumière ».
func _update_switch_label() -> void:
	if switch_it:
		switch_it.label = "Éteindre la lumière" if switch_on and dim >= 0.05 else "Allumer la lumière"


## Les ampoules connectées vacillent pendant « seconds » secondes, puis reviennent à leur niveau
## (celui de set_dim, même s'il a changé pendant ce temps).
func flicker(seconds := 1.5) -> void:
	_flicker_id += 1
	_chain_id += 1
	var my := _flicker_id
	var t := 0.0
	_all_bulbs_until_ms = Time.get_ticks_msec() + int(seconds * 1000.0) + 400
	if not bulbs.is_empty():
		Sfx.play_at("metalClick", bulbs[1].global_position, -16.0, 0.45)
	while t < seconds and my == _flicker_id:
		for i in bulbs.size():
			var k := 0.0 if rng.randf() < 0.45 else rng.randf_range(0.25, 1.6)
			_apply_bulb(i, k * dim)
		var step := rng.randf_range(0.04, 0.15)
		await get_tree().create_timer(step, false).timeout
		if not is_inside_tree():
			return
		t += step
	if my == _flicker_id:
		_all_bulbs_until_ms = 0
		_apply_all()


## Les ampoules s'allument l'une après l'autre, du sud vers le nord (vers la porte d'Henriette),
## puis s'éteignent toutes et restent éteintes (dim = 0). Un flicker() ou un set_dim() lancé pendant
## la séquence l'interrompt.
func chain_lights(step := 0.7, hold := 1.0) -> void:
	_flicker_id += 1
	_chain_id += 1
	var my := _chain_id
	if _dim_tw:
		_dim_tw.kill()
	_all_bulbs_until_ms = Time.get_ticks_msec() + int((step * bulbs.size() + hold) * 1000.0) + 1500
	for i in bulbs.size():
		_apply_bulb(i, 0.0)
	for i in range(bulbs.size() - 1, -1, -1):   # LIGHT_Z va du nord au sud : on part du sud
		await get_tree().create_timer(step, false).timeout
		if not is_inside_tree() or my != _chain_id:
			return
		_apply_bulb(i, 1.0)
		Sfx.play_at("metalClick", bulbs[i].global_position, -20.0, 0.5)
	await get_tree().create_timer(hold, false).timeout
	if not is_inside_tree() or my != _chain_id:
		return
	dim = 0.0
	_all_bulbs_until_ms = 0
	_apply_all()


## Règle les ampoules : 1 = normal, 0 = éteintes. « seconds » : fondu.
func set_dim(k: float, seconds := 0.0) -> void:
	_chain_id += 1
	_all_bulbs_until_ms = 0
	if _dim_tw:
		_dim_tw.kill()
	k = clampf(k, 0.0, 1.0)
	if seconds <= 0.0:
		dim = k
		_apply_all()
		return
	_dim_tw = create_tween()
	_dim_tw.tween_method(func(v: float) -> void:
		dim = v
		_apply_all(), dim, k, seconds)


# ------------------------------------------------------------------ la caméra de l'assurance

func _camera() -> void:
	var root := Node3D.new()
	root.name = "CameraDome"
	add_child(root)
	root.position = CAM_POS
	_mesh(_cyl(0.075, 0.08, 0.028, 24), Vector3(0, -0.014, 0), _new_white, Vector3.ZERO, root)
	_mesh(_cyl(0.066, 0.072, 0.012, 24), Vector3(0, -0.034, 0), _plain(Color(0.7, 0.7, 0.68), 0.35), Vector3.ZERO, root)
	# le micro, côté couloir : Papi a mis un bout de scotch dessus
	_box(Vector3(0.006, 0.006, 0.004), Vector3(0, -0.014, 0.078), mats.dark, false, root)
	var tape := _box(Vector3(0.032, 0.02, 0.003), Vector3(0.002, -0.014, 0.0805), _plain(Color(0.7, 0.62, 0.45), 0.5), false, root)
	tape.rotation.z = 0.15
	# la tête mobile, sous le dôme fumé
	cam_pivot = Node3D.new()
	cam_pivot.name = "Tete"
	cam_pivot.position = Vector3(0, -0.07, 0)
	root.add_child(cam_pivot)
	cam_pivot.rotation = Vector3(_cam_rest.x, _cam_rest.y, 0)
	var black := _plain(Color(0.05, 0.05, 0.055), 0.35)
	_mesh(_sphere(0.034, 16), Vector3.ZERO, black, Vector3.ZERO, cam_pivot)
	_mesh(_cyl(0.017, 0.017, 0.034, 16), Vector3(0, 0, -0.03), black, Vector3(PI / 2.0, 0, 0), cam_pivot)
	var lens := _plain(Color(0.03, 0.04, 0.08), 0.05)
	lens.metallic_specular = 1.0
	_mesh(_cyl(0.011, 0.011, 0.003, 16), Vector3(0, 0, -0.048), lens, Vector3(PI / 2.0, 0, 0), cam_pivot)
	cam_led_mat = _glow(Color(1.0, 0.06, 0.04), 7.0)
	_no_gi(_mesh(_sphere(0.0045, 8), Vector3(0.021, 0.012, -0.036), cam_led_mat, Vector3.ZERO, cam_pivot))
	cam_led = OmniLight3D.new()
	cam_led.name = "LedCamera"
	cam_led.light_color = Color(1.0, 0.08, 0.05)
	cam_led.light_energy = 0.08
	cam_led.omni_range = 0.5
	cam_led.position = Vector3(0.02, 0.0, -0.08)
	cam_pivot.add_child(cam_led)
	var dome := SphereMesh.new()
	dome.radius = 0.066
	dome.height = 0.132
	dome.is_hemisphere = true
	dome.radial_segments = 24
	dome.rings = 8
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.05, 0.05, 0.06, 0.5)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.06
	glass.metallic_specular = 1.0
	var dm := _mesh(dome, Vector3(0, -0.04, 0), glass, Vector3(PI, 0, 0), root)
	dm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# son câble : au plafond jusqu'au coin, puis dans l'angle des murs, jusqu'à l'alimentation
	var cy := 2.6 - 0.0035
	_cable([Vector3(4.07, cy, CAM_POS.z), Vector3(4.56, cy, CAM_POS.z), Vector3(4.56, cy, -7.25)], Vector3.DOWN)
	# (dans l'angle, mais à 3 mm des deux murs : à moitié dans le plâtre, il sortait en pointillés)
	_cable([Vector3(4.676, 2.49, ZN + 0.009), Vector3(4.676, 1.19, ZN + 0.009), Vector3(4.66, 1.165, ZN + 0.009)], Vector3.BACK)
	_box(Vector3(0.07, 0.11, 0.035), Vector3(4.645, 1.12, ZN + 0.0175), _new_white)
	_no_gi(_box(Vector3(0.006, 0.006, 0.003), Vector3(4.66, 1.15, ZN + 0.036), _glow(Color(0.2, 0.6, 1.0), 3.0)))
	var zc := ZN + 0.008
	_cable([Vector3(4.645, 1.065, zc), Vector3(4.645, 0.97, zc), Vector3(4.645, 0.97, ZN + 0.06),
		Vector3(4.645, 0.913, ZN + 0.06), Vector3(4.645, 0.913, ZN + DADO + 0.008), Vector3(4.645, 0.3, ZN + DADO + 0.008),
		Vector3(4.625, 0.262, ZN + DADO + 0.03)], Vector3.BACK)
	var sock := _socket(Vector3(4.62, 0.24, ZN + DADO), Vector3.BACK)
	_plug(sock)
	var it := _interactable("Regarder la caméra", Vector3(0.24, 0.2, 0.24), CAM_POS + Vector3(0, -0.07, 0), self, LAYER_INTERACT, 2.8)
	it.used.connect(func(_i: Interactable) -> void:
		Game.hint(TXT_CAMERA, 4.5)
		look_at_player_once())


## La caméra suit doucement une cible (null : elle retourne au repos).
func track(target: Node3D) -> void:
	cam_target = target
	_cam_once = false


## La caméra se tourne vers le joueur, une fois, et reste pointée là (si elle le suit déjà, elle continue).
func look_at_player_once() -> void:
	var p: Node3D = house.player if house else null
	if p == null or (cam_target == p and not _cam_once):
		return
	cam_target = p
	_cam_once = true


## Le joueur suivi n'est filmé que dans le couloir : ailleurs, la caméra revient au repos (vers le
## sud, le long du couloir), au lieu de fixer un mur derrière lequel il se trouve.
func _target_here(target: Node3D) -> bool:
	if house == null or target != house.player:
		return true
	return house.current == self


## La caméra vise-t-elle sa cible (à moins de max_deg degrés) ? (photo du couloir : on attend qu'elle
## ait trouvé le joueur.)
func cam_on_target(max_deg := 8.0) -> bool:
	if cam_pivot == null or cam_target == null or not is_instance_valid(cam_target):
		return false
	var want := _aim_of(cam_target)
	return rad_to_deg(absf(wrapf(want.y - cam_pivot.rotation.y, -PI, PI))) <= max_deg \
		and rad_to_deg(absf(want.x - cam_pivot.rotation.x)) <= max_deg


func _aim_of(target: Node3D) -> Vector2:
	var tp := target.global_position
	if target is CharacterBody3D:
		tp.y += 1.35
	var d := tp - cam_pivot.global_position
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	return Vector2(clampf(pitch, -1.45, -0.05), yaw)


func _process(delta: float) -> void:
	if not _pending.is_empty():
		_run_pending()
	if cam_pivot == null:
		return
	if cam_ir and feed_cam and cam_ir.visible != feed_cam.active:
		cam_ir.visible = feed_cam.active
	_update_cam_led(delta)
	var want := _cam_rest
	if cam_target and is_instance_valid(cam_target) and _target_here(cam_target):
		want = _aim_of(cam_target)
	var dyaw := wrapf(want.y - cam_pivot.rotation.y, -PI, PI)
	var dpitch := want.x - cam_pivot.rotation.x
	# moteur pas à pas : vitesse limitée, ralentit en arrivant
	var vy := clampf(absf(dyaw) * 2.2, 0.1, 0.9) * delta
	var vp := clampf(absf(dpitch) * 2.2, 0.08, 0.6) * delta
	cam_pivot.rotation.y += clampf(dyaw, -vy, vy)
	cam_pivot.rotation.x += clampf(dpitch, -vp, vp)
	var moving := absf(dyaw) > 0.015 or absf(dpitch) > 0.015
	if moving:
		_motor_t -= delta
		if _motor_t <= 0.0:
			_motor_t = 0.26
			Sfx.play_at("metalClick", cam_pivot.global_position, -27.0, 0.42, 1.2)
	else:
		_motor_t = 0.0
		if _cam_once:
			_cam_once = false
			_cam_rest = Vector2(cam_pivot.rotation.x, cam_pivot.rotation.y)
			cam_target = null


## LED de la caméra dôme : si le joueur, dans le couloir, fixe l'objectif STARE_SEC secondes, elle
## s'éteint LED_OFF_SEC secondes (indice « Elle a éteint sa lumière… », événement « camera_led_eteinte »).
func _update_cam_led(delta: float) -> void:
	if _led_off_t > 0.0:
		_led_off_t -= delta
		if _led_off_t <= 0.0:
			_set_cam_led(true)
		return
	var p: Node3D = house.player if house else null
	var watching := cam_led_on and p != null and house.current == self and p.has_method("looking_at_point") \
		and bool(p.call("looking_at_point", cam_pivot.global_position, STARE_DEG, STARE_DIST))
	_stare_t = _stare_t + delta if watching else 0.0
	if _stare_t >= STARE_SEC:
		_stare_t = 0.0
		_led_off_t = LED_OFF_SEC
		_set_cam_led(false)
		var hn := Haunt.of(get_tree())
		# la pensée, une seule fois (sinon elle revient à chaque regard et couvre H-P2a ou H-SOS), et
		# jamais par-dessus une scène écrite ; ensuite, la LED s'éteint sans rien dire
		if not bool(Game.flag("camera_led_vue", false)) and (hn == null or not hn.is_busy()):
			Game.set_flag("camera_led_vue", true)
			Game.hint(TXT_CAMERA_LED, 4.0)
		if hn:
			hn.story_event("camera_led_eteinte")


## LED rouge de la caméra dôme, réglée par le scénario : éteinte tant que la maison dort (début de
## l'acte II), allumée quand la caméra s'éveille (première entrée dans le couloir).
func set_cam_led(on: bool) -> void:
	_led_off_t = 0.0
	_stare_t = 0.0
	_set_cam_led(on)


func _set_cam_led(on: bool) -> void:
	cam_led_on = on
	if cam_led_mat:
		cam_led_mat.emission_energy_multiplier = 7.0 if on else 0.0
	if cam_led:
		cam_led.light_energy = 0.08 if on else 0.0


# ------------------------------------------------------------------ thermostat, détecteur de fumée

func _thermostat() -> void:
	var c := Vector3(XE, 1.5, -0.1)
	_box(Vector3(0.024, 0.13, 0.12), c + Vector3(-0.012, 0, 0), _new_white)
	_box(Vector3(0.004, 0.06, 0.086), c + Vector3(-0.025, 0.014, 0), _plain(Color(0.02, 0.02, 0.025), 0.2))
	for k in 2:
		_box(Vector3(0.006, 0.014, 0.022), c + Vector3(-0.026, -0.042, -0.02 + k * 0.04), _plain(Color(0.75, 0.75, 0.73), 0.4))
	thermostat = Device.new()
	thermostat.name = "Thermostat"
	thermostat.kind = "thermostat"
	thermostat.screen_size = Vector2(0.078, 0.052)
	thermostat.res = Vector2i(120, 80)
	thermostat.glow_color = Color(0.55, 0.8, 1.0)
	thermostat.glow_energy = 0.1
	thermostat.glow_range = 1.2
	add_child(thermostat)
	thermostat.position = c + Vector3(-0.0275, 0.014, 0)
	thermostat.rotation.y = -PI / 2.0
	thermostat.build()
	thermostat.label.add_theme_font_size_override("font_size", 34)
	thermostat.say("3:12", Color(0.75, 0.92, 1.0), Color(0.01, 0.02, 0.03))
	thermostat.is_on = true
	thermostat.set_param("power", 1.0)
	thermostat.set_param("brightness", 0.75)
	thermostat.light.light_energy = thermostat.glow_energy
	thermostat.light.shadow_enabled = false
	for mi in thermostat.find_children("*", "MeshInstance3D", false, false):
		_no_gi(mi as MeshInstance3D)
	# (alimenté par le mur : un fil de 5,6 mm, ou même une goulotte, montant au plafond s'affichait en
	# trait irisé, sans anticrénelage et avec l'aberration chromatique, sur toutes les vues du couloir)
	_look("Regarder le thermostat", Vector3(0.1, 0.18, 0.18), c + Vector3(-0.03, 0, 0),
		"Le thermostat du fournisseur d'énergie. Il devrait afficher la température. Il affiche 3:12.")


func _smoke_detector() -> void:
	var p := Vector3(4.0, 2.6, 2.2)
	_mesh(_cyl(0.06, 0.066, 0.034, 24), p + Vector3(0, -0.017, 0), _new_white)
	_mesh(_cyl(0.04, 0.04, 0.006, 20), p + Vector3(0, -0.036, 0), _plain(Color(0.45, 0.45, 0.44), 0.6))
	for k in 3:
		_mesh(_cyl(0.012 + k * 0.01, 0.012 + k * 0.01, 0.002, 20), p + Vector3(0, -0.0405 - (2 - k) * 0.0005, 0), _plain(Color(0.2, 0.2, 0.2) if k % 2 == 0 else Color(0.6, 0.6, 0.58), 0.6))
	smoke_led = _glow(Color(0.15, 1.0, 0.3), 0.0)
	_no_gi(_mesh(_sphere(0.004, 8), p + Vector3(0.042, -0.034, 0), smoke_led))
	var tw := create_tween().set_loops()
	tw.tween_interval(2.3)
	tw.tween_callback(func() -> void: smoke_led.emission_energy_multiplier = 8.0)
	tw.tween_interval(0.08)
	tw.tween_callback(func() -> void: smoke_led.emission_energy_multiplier = 0.0)
	# détecteur « connecté » : son câble file au plafond vers le mur est
	var cy := 2.6 - 0.0035
	_cable([Vector3(4.066, cy, 2.2), Vector3(4.635, cy, 2.2)], Vector3.DOWN)   # jusque sous la corniche


# ------------------------------------------------------------------ traces

func _traces() -> void:
	var stain: Texture2D = load("res://assets/decals/stain_water.png")
	var mold: Texture2D = load("res://assets/decals/mold.png")
	# infiltration sous la fenêtre du bout, et auréole au plafond (remplacées sur vraie carte, hors Basse,
	# par les décalques de Wear : _dress_wear)
	_old_traces["tache"] = _decal(stain, Vector3(4.15, 2.6, 5.5), Vector3.DOWN, Vector3.BACK, 1.1, 0.9, 0.3)
	_old_traces["infiltration"] = _decal(stain, Vector3(3.7, 0.55, ZS), Vector3.FORWARD, Vector3.UP, 0.6, 0.7, 0.2, Color(1, 1, 1, 0.7))
	# moisissure dans l'angle nord-ouest, sous le plafond
	_old_traces["moisissure_ouest"] = _decal(mold, Vector3(XW, 2.25, -6.95), Vector3.RIGHT, Vector3.UP, 0.9, 0.7, 0.2)
	_old_traces["moisissure_nord"] = _decal(mold, Vector3(3.55, 2.3, ZN), Vector3.BACK, Vector3.UP, 0.6, 0.6, 0.2, Color(1, 1, 1, 0.6))


# ------------------------------------------------------------------ Nestor, sur la console

const NESTOR_POS := Vector2(3.52, -1.0)   # (x, z) ; posé sur le plateau de la console
const TXT_NESTOR := "L'enceinte de la téléassistance. Un anneau de lumière, %s selon la jauge."
const TXT_NESTOR_DEBRANCHE := "La prise est débranchée. L'anneau reste allumé : batterie interne, dix heures, dit l'étiquette."
const TXT_CABLE := "Ton câble. Quinze mètres, de la box du bureau jusqu'à la chambre. Scotché par toi, cet après-midi."


## L'enceinte Nestor, entre le téléphone et le boîtier de téléassistance ; son câble blanc descend
## derrière la console jusqu'à une prise que l'installateur a fermée d'un cache vissé.
func _nestor() -> void:
	var table: Node3D = props.get("sideTable")
	var top := 0.8
	if table:
		top = (table.get_meta("size") as Vector3).y
	nestor = Nestor.new()
	nestor.name = "Nestor"
	nestor.device_id = "nestor"
	nestor.room_id = "couloir"
	add_child(nestor)
	nestor.position = Vector3(NESTOR_POS.x, top, NESTOR_POS.y)
	nestor.rotation.y = PI / 2.0      # face avant vers le couloir (+x)
	nestor.build()
	# câble : de l'arrière de l'enceinte au bord du plateau, puis le long du mur jusqu'à la prise
	var bx := XW + DADO + 0.012
	var sz := NESTOR_POS.y - 0.42
	var half := 0.45
	if table:
		half = (table.get_meta("size") as Vector3).x / 2.0
	_cable([Vector3(NESTOR_POS.x - 0.05, top + 0.004, NESTOR_POS.y), Vector3(bx + 0.04, top + 0.004, NESTOR_POS.y - 0.02),
		Vector3(bx + 0.04, top + 0.004, NESTOR_POS.y - 0.25), Vector3(bx + 0.012, top + 0.004, NESTOR_POS.y - half + 0.02),
		Vector3(bx + 0.008, top - 0.025, NESTOR_POS.y - half - 0.02), Vector3(bx + 0.006, 0.4, sz), Vector3(bx + 0.006, 0.28, sz)],
		Vector3.RIGHT, false)
	var sock := _socket(Vector3(XW + DADO, 0.24, sz), Vector3.RIGHT)
	nestor_plug = Node3D.new()
	nestor_plug.name = "FicheNestor"
	sock.add_child(nestor_plug)
	_box(Vector3(0.036, 0.042, 0.03), Vector3(0, 0, 0.03), _new_white, false, nestor_plug)
	# le cache-prise vissé de l'installateur (il faut un tournevis)
	var cover := _plain(Color(0.85, 0.85, 0.83, 1.0), 0.35)
	_box(Vector3(0.09, 0.1, 0.004), Vector3(0, 0, 0.047), cover, false, nestor_plug)
	_mesh(_cyl(0.004, 0.004, 0.003, 8), Vector3(0, 0.04, 0.05), mats.metal, Vector3(PI / 2.0, 0, 0), nestor_plug)
	_mesh(_cyl(0.004, 0.004, 0.003, 8), Vector3(0, -0.04, 0.05), mats.metal, Vector3(PI / 2.0, 0, 0), nestor_plug)
	nestor_it = _interactable("Regarder l'enceinte", Vector3(0.14, 0.22, 0.14), Vector3(NESTOR_POS.x, top + 0.09, NESTOR_POS.y), self, LAYER_INTERACT, 2.2)
	nestor_it.used.connect(func(_i: Interactable) -> void:
		if not nestor_unplugged and Game.has_item("tournevis"):
			unplug_nestor()
		elif nestor_unplugged:
			Game.hint(TXT_NESTOR_DEBRANCHE, 5.0)
		else:
			Game.hint(TXT_NESTOR % nestor.ring_color_name(), 4.5))
	Game.inventory_changed.connect(_update_nestor_label)
	_update_nestor_label()


func _update_nestor_label() -> void:
	if nestor_it == null or not is_instance_valid(nestor_it):
		return
	nestor_it.label = "Débrancher l'enceinte" if Game.has_item("tournevis") and not nestor_unplugged else "Regarder l'enceinte"


## Débrancher Nestor (avec le tournevis) : la fiche sort, l'anneau reste allumé (batterie interne).
func unplug_nestor(quiet := false) -> void:
	if nestor_unplugged:
		return
	nestor_unplugged = true
	Game.set_flag("nestor_debranche", true)
	if nestor_plug:
		nestor_plug.visible = false
	_update_nestor_label()
	if quiet:
		return
	Sfx.play_at("metalClick", nestor.global_position, -10.0, 0.9, 1.5)
	Game.hint(TXT_NESTOR_DEBRANCHE, 5.5)
	var hn := Haunt.of(get_tree())
	if hn:
		hn.story_event("nestor_debranche")


# ------------------------------------------------------------------ l'interrupteur des trois ampoules

const SWITCH_POS := Vector3(3.31, 1.1, 0.75)


func _switch() -> void:
	var holder := Node3D.new()
	holder.name = "Interrupteur"
	add_child(holder)
	holder.position = Vector3(XW, SWITCH_POS.y, SWITCH_POS.z)
	holder.rotation.y = PI / 2.0      # face +x
	_box(Vector3(0.082, 0.082, 0.006), Vector3(0, 0, 0.003), _m(Color(0.5, 0.47, 0.4), 0.5), false, holder)
	_box(Vector3(0.074, 0.074, 0.01), Vector3(0, 0, 0.005), _m(Color(0.66, 0.62, 0.53), 0.5), false, holder)
	for sy in [-1.0, 1.0]:
		_mesh(_cyl(0.003, 0.003, 0.002, 8), Vector3(0, sy * 0.028, 0.0105), mats.metal, Vector3(PI / 2.0, 0, 0), holder)
	switch_rocker = Node3D.new()
	switch_rocker.position = Vector3(0, 0, 0.011)
	holder.add_child(switch_rocker)
	_box(Vector3(0.034, 0.042, 0.008), Vector3(0, 0, 0.003), _m(Color(0.7, 0.67, 0.58), 0.45), false, switch_rocker)
	switch_rocker.rotation.x = -0.16 if switch_on else 0.16
	switch_it = _interactable("Éteindre la lumière", Vector3(0.12, 0.14, 0.14), Vector3(XW + 0.05, SWITCH_POS.y, SWITCH_POS.z), self, LAYER_INTERACT, 2.0)
	_update_switch_label()
	switch_it.used.connect(func(_i: Interactable) -> void:
		# ampoules éteintes par elle, interrupteur sur marche : le geste est « allumer » (on bascule,
		# coupure puis remise, et les ampoules connectées repartent à pleine puissance)
		if switch_on and dim < 0.05:
			set_switch(true)
		else:
			set_switch(not switch_on)
		var hn := Haunt.of(get_tree())
		if hn:
			hn.story_event("lumiere", {"room": "couloir", "on": switch_on}))


## L'interrupteur mural : coupé, plus aucune ampoule ne s'allume (ni chain_lights, ni flicker) ;
## remis, les ampoules connectées repartent à pleine puissance (comme toutes les ampoules connectées
## après une coupure), jusqu'à ce qu'elle les baisse.
## keep_level : ne pas remettre les ampoules à pleine puissance (rechargement d'une sauvegarde).
func set_switch(on: bool, quiet := false, keep_level := false) -> void:
	switch_on = on
	_all_bulbs_until_ms = 0
	Game.set_flag("interrupteur_couloir", on)
	if switch_rocker:
		switch_rocker.rotation.x = -0.16 if on else 0.16
	_update_switch_label()
	for n in find_children("*", "", true, false):
		if n is SmartBulb:
			(n as SmartBulb).set_powered(on)
	if on and not keep_level:
		_chain_id += 1
		_flicker_id += 1
		if _dim_tw:
			_dim_tw.kill()
		dim = 1.0
	_apply_all()
	if not quiet:
		Sfx.play_at("metalClick", Vector3(XW, SWITCH_POS.y, SWITCH_POS.z), -10.0, 1.3, 1.5)


# ------------------------------------------------------------------ le câble réseau d'Alexandre

## Le câble blanc d'Alexandre : il sort sous la porte de la chambre (P1), longe la plinthe ouest,
## traverse le couloir sur le tapis et passe sous la porte du bureau (P7). Scotch gris aux endroits
## du plan (z 1.6, 2.6, 3.6 et x 4.0). La suite, dans le bureau, est posée par bureau.gd.
func _network_cable() -> void:
	var xw := XW + DADO + 0.04   # devant la plinthe (le plan dit 3.34 : la plinthe est là)
	var z := 4.15
	var y := CABLE_NET_R + 0.0005   # posé sur le parquet (le tube de 6 mm du § 5.2 flottait à 8 mm)
	var yr := 0.0105                # sur le tapis
	var yt := 0.012 + CABLE_NET_R   # sur le seuil de P7 (12 mm)
	var pts := [Vector3(3.26, y, 1.0), Vector3(3.3, y, 1.0), Vector3(xw, y, 1.0), Vector3(xw, y, z),
		Vector3(3.585, y, z), Vector3(3.6, yr, z), Vector3(4.4, yr, z), Vector3(4.415, y, z),
		Vector3(4.676, y, z), Vector3(4.69, yt, z), Vector3(4.81, yt, z)]
	# (le câble d'Alexandre, acheté le jour même : le plus blanc des câbles du couloir, sans être un trait de
	# lumière)
	var mat := _plain(Color(0.62, 0.62, 0.59), 0.5)
	_cable(pts, Vector3.UP, false, mat, CABLE_NET_R)
	var grey := _plain(Color(0.5, 0.5, 0.49), 0.45, 0.2)
	for p in [Vector3(xw, y, 1.6), Vector3(xw, y, 2.6), Vector3(xw, y, 3.6), Vector3(4.0, yr, z)]:
		var along := Vector3.BACK if p.z != z else Vector3.RIGHT
		var t := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.055, CABLE_NET_R * 2.0 + 0.002, 0.036)
		t.mesh = tb
		t.material_override = grey
		t.transform = Transform3D(Basis(Vector3.UP.cross(along).normalized(), Vector3.UP, along), p + Vector3(0, -0.0006, 0))
		t.rotate_object_local(Vector3.UP, rng.randf_range(-0.15, 0.15))
		add_child(t)
	var it := _interactable("Regarder le câble", Vector3(0.16, 0.1, 1.0), Vector3(xw + 0.02, 0.05, 2.4), self, LAYER_INTERACT, 2.0)
	it.used.connect(func(_i: Interactable) -> void: Game.hint(TXT_CABLE, 5.0))
	# (là où il traverse le couloir et passe sous P7, « Ton câble passe sous la porte » : on le vise aussi)
	var it2 := _interactable("Regarder le câble", Vector3(1.1, 0.08, 0.16), Vector3((xw + 4.69) / 2.0, 0.04, z), self, LAYER_INTERACT, 2.0)
	it2.used.connect(func(_i: Interactable) -> void: Game.hint(TXT_CABLE, 5.0))


# ------------------------------------------------------------------ CAM 1, dans la caméra dôme

## Le flux de la caméra dôme (CAM 1 COULOIR, 160 × 90, 6 images/s, fov 80°) : posé sur la tête mobile,
## il suit ses mouvements. Coupé tant qu'on ne regarde pas son image (console du bureau).
func _feed_cam() -> void:
	if cam_pivot == null:
		return
	feed_cam = FeedCam.new()
	feed_cam.name = "CamFlux1"
	feed_cam.title = "CAM 1 COULOIR"
	feed_cam.fov = 80.0
	feed_cam.ir = 3.5      # le couloir est noir (ampoules éteintes) : l'infrarouge de la caméra le révèle
	cam_pivot.add_child(feed_cam)
	feed_cam.position = Vector3(0, 0, -0.055)
	feed_cam.build()
	# son éclairage infrarouge (comme CAM 2 et CAM 3) : sans lui, le couloir éteint est noir à l'écran.
	# Il ne s'allume que lorsque la console montre l'image (le joueur est alors dans le bureau) ;
	# une photo prise par la caméra (couloir.photo()) se fait sans lui : le rond de la lampe, seul.
	cam_ir = SpotLight3D.new()
	cam_ir.name = "InfrarougeCam1"
	cam_ir.light_color = Color(0.85, 0.88, 1.0)
	cam_ir.light_energy = 4.0
	cam_ir.spot_range = 13.0
	cam_ir.spot_angle = 28.0
	cam_ir.spot_attenuation = 0.35
	cam_ir.shadow_enabled = false
	cam_ir.visible = false
	cam_ir.set_meta("always_on", true)
	cam_pivot.add_child(cam_ir)
	cam_ir.position = Vector3(0, -0.02, -0.06)


## Une image de CAM 1, telle que l'imprimante la sort (await couloir.photo()). Elle est exposée sur
## elle-même, comme par un appareil automatique : brute, la photo du couloir éteint sortait noire
## (moyenne 6/255), sans même le rond de la lampe.
func photo() -> Image:
	if feed_cam == null:
		return null
	var raw: Image = await feed_cam.capture()
	return FeedCam.cctv_image(auto_expose(raw), "CAM 1")


## Exposition automatique : le point le plus clair (le rond de la lampe, 99,5e centile) est porté à
## 0,85, puis les ombres sont relevées (gamma 0,55) pour que le couloir vide se devine autour.
static func auto_expose(src: Image) -> Image:
	if src == null or src.is_empty():
		return src
	var img := src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var lum := PackedFloat32Array()
	lum.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			lum[y * w + x] = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	var sorted := lum.duplicate()
	sorted.sort()
	var hi := maxf(sorted[int((sorted.size() - 1) * 0.995)], 0.004)
	var gain := clampf(0.85 / hi, 1.0, 24.0)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(pow(clampf(c.r * gain, 0.0, 1.0), 0.55), pow(clampf(c.g * gain, 0.0, 1.0), 0.55),
				pow(clampf(c.b * gain, 0.0, 1.0), 0.55), 1.0))
	return img


# ------------------------------------------------------------------ habillage (passe « triple A »)

## Objets de détail, matières HD et usure du couloir (vraie carte seulement : Main l'appelle après la
## mesure de B16, jamais en rendu logiciel). Les objets d'origine restent en place, cachés dès que leur
## remplaçant est posé (cadres, tulipes, ampoules, tapis, décalques de la 0.3.3) : props, collisions et
## boîtes d'interaction ne changent pas. Les décalques suivent Wear (rien en Basse).
func dress_details() -> void:
	_dress_frames()
	_dress_lights()
	_dress_runner()
	_dress_console()
	_dress_wear()
	_dress_glass()


## Habillage en attente de son modèle (Builder.detail le pose quelques images plus tard) : fini dès qu'il
## est là (méta « ready »), oublié si le support a disparu.
func _run_pending() -> void:
	var i := 0
	while i < _pending.size():
		var e: Array = _pending[i]
		var h: Object = e[0]
		if not is_instance_valid(h):
			_pending.remove_at(i)
		elif (h as Node).has_meta("ready"):
			_pending.remove_at(i)
			(e[1] as Callable).call()
		else:
			i += 1


## La première surface d'un modèle dont la matière porte ce mot (« artwork », « glass ») : [MeshInstance3D,
## indice], ou [].
static func _surface_of(root: Node, word: String) -> Array:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m and m.resource_name.to_lower().contains(word):
				return [mi, i]
	return []


# ---- cadres

const FRAME02 := "hanging_picture_frame_02"
const FRAME03 := "hanging_picture_frame_03"
## hanging_picture_frame_02 (Poly Haven, CC0 ; bois peint en blanc, à teinter) dans son repère, relevé dans
## le glTF : boîte du cadre (face avant +z), rectangle de l'image (matière « artwork ») et plan du verre.
const FRAME02_SIZE := Vector3(0.752, 0.5, 0.0331)
const FRAME02_ART := Rect2(-0.3005, -0.2084, 0.604, 0.3541)
const FRAME02_ART_Z := 0.0094
const FRAME02_GLASS_Z := 0.0107
## hanging_picture_frame_03 : cadre ovale sculpté en acajou, verre bombé ; l'image ovale occupe
## [u0, v0, u1, v1] de sa texture.
const FRAME03_SIZE := Vector3(0.385, 0.502, 0.0318)
const FRAME03_ART_UV := [0.144, 0.006, 0.857, 0.997]
## Les verres des deux cadres n'occupent qu'un coin de leur texture : [u0, v0, u1, v1] (pour y étaler les
## traces de chiffon).
const GLASS_UV := {FRAME02: [0.002, 0.689, 0.531, 0.998], FRAME03: [0.413, 0.514, 0.765, 0.999]}
## Cadres Poly Haven posés sur vraie carte à la place des cadres procéduraux (même place, même
## inclinaison, mêmes photos) : clé de la photo -> [centre sur le mur, regard, taille extérieure,
## teinte du bois peint, passe-partout minimal (m), inclinaison]. Teintes : noir laqué, pin miel, noyer.
## Un cadre plus haut que large est le même modèle, tourné d'un quart de tour ; le modèle est mis à la
## taille par axe (« stretch »), le passe-partout crème absorbe le reste.
const PH_FRAMES := {
	"labo": [Vector3(XE, 1.66, -6.3), Vector3.LEFT, Vector2(0.34, 0.265), Color(0.15, 0.14, 0.13), 0.022, 0.0],
	"noel": [Vector3(XW, 1.5, -1.0), Vector3.RIGHT, Vector2(0.36, 0.28), Color(0.8, 0.64, 0.45), 0.008, -0.015],
	"ecole": [Vector3(XW, 1.66, 0.2), Vector3.RIGHT, Vector2(0.2, 0.25), Color(0.46, 0.31, 0.21), 0.006, 0.04],
	"plage": [Vector3(XW, 1.6, 5.2), Vector3.RIGHT, Vector2(0.37, 0.31), Color(0.46, 0.31, 0.21), 0.03, 0.03],
	"jardin": [Vector3(XE, 1.58, 5.6), Vector3.LEFT, Vector2(0.39, 0.32), Color(0.8, 0.64, 0.45), 0.03, 0.0],
}
## Le médaillon de l'aïeule (cadre ovale) : la partie de la photo qui remplit l'ovale (le cache crème de
## l'image en épouse le bord) : [u0, v0, u1, v1].
const AIEULE_CROP := [0.08, 0.06, 0.92, 0.94]


func _dress_frames() -> void:
	for key in PH_FRAMES:
		var s: Array = PH_FRAMES[key]
		_ph_frame(String(key), s[0], s[1], s[2], s[3], s[4], s[5])
	_oval_frame("aieule", Vector3(XW, 1.6, -5.6), Vector3.RIGHT, 0.38, -0.025, AIEULE_CROP)


## Un cadre hanging_picture_frame_02 : pivot au centre du cadre, sur le mur, tourné comme l'ancien.
func _ph_frame(key: String, pos: Vector3, facing: Vector3, size: Vector2, tint: Color, mat_min: float, tilt: float) -> void:
	var tex := _photo(key)
	var portrait := size.y > size.x
	var pivot := Node3D.new()
	pivot.name = "CadrePH_" + key
	add_child(pivot)
	pivot.position = pos
	pivot.rotation = Vector3(0, atan2(facing.x, facing.z), tilt)
	var roll := Node3D.new()
	pivot.add_child(roll)
	roll.rotation.z = PI / 2.0 if portrait else 0.0
	var mw := size.y if portrait else size.x
	var mh := size.x if portrait else size.y
	var depth := FRAME02_SIZE.z * mh / FRAME02_SIZE.y
	var h := detail(FRAME02, Vector3(0, -mh / 2.0, depth / 2.0), 0.0, Vector3(mw, mh, 0.0),
		{"parent": roll, "stretch": true, "tint": tint, "range": 0.0})
	if h == null:
		pivot.queue_free()
		return
	_pending.append([h, _finish_ph_frame.bind(h, pivot, key, tex, mat_min)])


## Le modèle est posé : passe-partout crème sur l'« artwork », la photo par-dessus (à sa proportion, centrée,
## sous le verre), verre marqué ; l'ancien cadre se cache.
func _finish_ph_frame(h: Node3D, pivot: Node3D, key: String, tex: Texture2D, mat_min: float) -> void:
	var art := _surface_of(h, "artwork")
	if art.is_empty() or tex == null:
		return
	var art_mi: MeshInstance3D = art[0]
	art_mi.set_surface_override_material(art[1], _paper())
	var gl := _surface_of(h, "glass")
	if not gl.is_empty():
		(gl[0] as MeshInstance3D).set_surface_override_material(gl[1], _ph_glass(FRAME02))
	# rectangle de l'image dans le repère du pivot (x horizontal, y vertical, z vers la pièce)
	var xf := pivot.global_transform.affine_inverse() * art_mi.global_transform
	var a := xf * Vector3(FRAME02_ART.position.x, FRAME02_ART.position.y, FRAME02_ART_Z)
	var b := xf * Vector3(FRAME02_ART.end.x, FRAME02_ART.end.y, FRAME02_ART_Z)
	var gz := (xf * Vector3(0.0, 0.0, FRAME02_GLASS_Z)).z
	var c := (a + b) / 2.0
	var aw := absf(b.x - a.x) - 2.0 * mat_min
	var ah := absf(b.y - a.y) - 2.0 * mat_min
	var aspect := float(tex.get_width()) / float(tex.get_height())
	var pw := aw
	var ph := pw / aspect
	if ph > ah:
		ph = ah
		pw = ph * aspect
	var q := _quad(Vector2(pw, ph), Vector3(c.x, c.y, lerpf(c.z, gz, 0.4)), _photo_mat(key, tex), 0.0, pivot)
	q.name = "Photo"
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var old: Node3D = _old_frames.get(key)
	if old:
		old.visible = false


## Le cadre ovale (hanging_picture_frame_03), à l'échelle uniforme (bois sculpté) : la photo remplit
## l'ovale de l'image du modèle (« crop » : la partie de la photo qui s'y voit).
func _oval_frame(key: String, pos: Vector3, facing: Vector3, height: float, tilt: float, crop: Array) -> void:
	var tex := _photo(key)
	var pivot := Node3D.new()
	pivot.name = "CadrePH_" + key
	add_child(pivot)
	pivot.position = pos
	pivot.rotation = Vector3(0, atan2(facing.x, facing.z), tilt)
	var depth := FRAME03_SIZE.z * height / FRAME03_SIZE.y
	var h := detail(FRAME03, Vector3(0, -height / 2.0, depth / 2.0), 0.0, Vector3(0, height, 0), {"parent": pivot, "range": 0.0})
	if h == null:
		pivot.queue_free()
		return
	_pending.append([h, _finish_oval.bind(h, key, tex, crop)])


func _finish_oval(h: Node3D, key: String, tex: Texture2D, crop: Array) -> void:
	var art := _surface_of(h, "artwork")
	if art.is_empty() or tex == null:
		return
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.6
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var r: Array = FRAME03_ART_UV
	var sx := (float(crop[2]) - float(crop[0])) / (float(r[2]) - float(r[0]))
	var sy := (float(crop[3]) - float(crop[1])) / (float(r[3]) - float(r[1]))
	m.uv1_scale = Vector3(sx, sy, 1.0)
	m.uv1_offset = Vector3(float(crop[0]) - float(r[0]) * sx, float(crop[1]) - float(r[1]) * sy, 0.0)
	(art[0] as MeshInstance3D).set_surface_override_material(art[1], m)
	var gl := _surface_of(h, "glass")
	if not gl.is_empty():
		(gl[0] as MeshInstance3D).set_surface_override_material(gl[1], _ph_glass(FRAME03))
	var old: Node3D = _old_frames.get(key)
	if old:
		old.visible = false


## Passe-partout : carton crème un peu jauni.
func _paper() -> StandardMaterial3D:
	if _paper_mat == null:
		_paper_mat = _m(Color(0.8, 0.76, 0.66), 0.92)
		if not Builder.soft_render():
			Builder.paper_albedo(_paper_mat, 0.83)      # vraie carte : ne brille pas la nuit (V2-NUIT)
	return _paper_mat


## Tirage photo (papier semi-brillant, derrière le verre).
func _photo_mat(key: String, tex: Texture2D) -> StandardMaterial3D:
	if not _photo_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.roughness = 0.55
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_photo_mats[key] = m
	return _photo_mats[key]


## Traînées de chiffon et traces de doigts (ambientCG Smear002, genre « trainee » de Wear) : l'alpha de la
## traînée donne la rugosité d'un verre, de 0 (propre) à 0,5 (gras).
func _smear() -> Texture2D:
	var f := Wear.files("trainee", 0)
	if f.is_empty():
		return null
	return load(String(f.albedo)) as Texture2D


## Verre des cadres Poly Haven : presque transparent (comme _fix_ph_materials), marqué de traînées étalées
## sur la partie de la texture qu'occupe le verre.
func _ph_glass(id: String) -> Material:
	if not _glass_ph.has(id):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.82, 0.86, 0.88, 0.12)
		m.metallic_specular = 0.8
		m.roughness = 0.06
		var smear := _smear()
		if smear:
			m.roughness = 0.5
			m.roughness_texture = smear
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_ALPHA
			var r: Array = GLASS_UV.get(id, [0.0, 0.0, 1.0, 1.0])
			var su := 1.0 / (float(r[2]) - float(r[0]))
			var sv := 1.0 / (float(r[3]) - float(r[1]))
			m.uv1_scale = Vector3(su, sv, 1.0)
			m.uv1_offset = Vector3(-float(r[0]) * su, -float(r[1]) * sv, 0.0)
		_glass_ph[id] = m
	return _glass_ph[id]


## Les verres des cadres d'origine restés en place (dorés : le mariage, la photo de classe, le portrait) :
## les mêmes traînées.
func _dress_glass() -> void:
	var smear := _smear()
	if smear and _glass:
		_glass.roughness = 0.45
		_glass.roughness_texture = smear
		_glass.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_ALPHA


# ---- plafonniers

const BULB := "lightbulb_01"


## Tulipes ouvertes (on voit l'ampoule par-dessous), vraies ampoules (lightbulb_01, tête en bas dans la
## douille, verre émissif de l'ampoule connectée) et auréole de suie au plafond au-dessus de chacune.
func _dress_lights() -> void:
	for i in LIGHT_Z.size():
		var top := Vector3(4.0, 2.6, float(LIGHT_Z[i]))
		if i < _shade_meshes.size() and i < shade_mats.size():
			var shell := MeshInstance3D.new()
			shell.name = "Tulipe%d" % (i + 1)
			shell.mesh = _tulip_mesh()
			shell.material_override = shade_mats[i]
			_no_gi(shell)
			add_child(shell)
			shell.position = top + Vector3(0, -0.31, 0)
			_shade_meshes[i].visible = false
		var b := detail(BULB, top + Vector3(0, -0.302, 0), 0.0, Vector3(0, 0.086, 0), {"range": 0.0})
		if b:
			b.rotation.x = PI       # le culot en haut, dans la douille ; le verre vers le sol
			_pending.append([b, _finish_bulb.bind(b, i)])
		Wear.decal(self, "suie", top, Vector3.DOWN, Vector3.BACK, 0.95, 0.95, {"variant": 0, "mix": 1.0, "name": "Suie%d" % (i + 1)})


func _finish_bulb(b: Node3D, i: int) -> void:
	var gl := _surface_of(b, "glass")
	if gl.is_empty() or i >= bulb_mats.size():
		return
	(gl[0] as MeshInstance3D).set_surface_override_material(gl[1], bulb_mats[i])
	for g in b.find_children("*", "GeometryInstance3D", true, false):
		_no_gi(g as GeometryInstance3D)
	if i < _bulb_meshes.size():
		_bulb_meshes[i].visible = false


## Tulipe en verre ambré, ouverte en bas : une coque de 3 mm en cloche (bord roulé, trou de la douille en
## haut), même encombrement que l'ancien cône (rayons 0,03 et 0,115, 14 cm de haut, centrée).
func _tulip_mesh() -> Mesh:
	if _tulip == null:
		var outer := PackedVector2Array()
		var n := 8
		for k in n + 1:
			var t := float(k) / n
			outer.append(Vector2(0.03 + 0.085 * pow(1.0 - t, 1.6), -0.07 + 0.14 * t))
		var prof := PackedVector2Array([Vector2(outer[0].x - 0.003, -0.07)])
		prof.append_array(outer)
		for k in range(n, -1, -1):
			prof.append(Vector2(outer[k].x - 0.003, minf(outer[k].y, 0.067)))
		_tulip = Builder.lathe_mesh(prof, 28, 1.0, 0.0012)
	return _tulip


# ---- tapis

const RUNNER_TILE := "res://assets/textures/runner/runner_tile.png"
const RUNNER_BORD := "res://assets/textures/runner/runner_bord.png"
## Champ et galon du tapis HD (constantes de tools/make_assets.py, lot V1-IMAGES) : carreau du champ de
## 0,52 m ; galon de 0,13 m de large et 0,52 m de long, bord extérieur à u = 0.
const RUNNER_TILE_M := 0.52
const RUNNER_BORD_M := Vector2(0.13, 0.52)
## Velours de 6 mm, chant biseauté sur 8 mm (la semelle d'avant faisait 7,2 mm : même empreinte, même
## hauteur pour _scan_rugs et pour le câble réseau qui le traverse).
const RUNNER_TOP := 0.006
## Usure du passage sur le tapis (Wear.path) : le velours tassé, plus clair et plus gris que le rouge.
const RUNNER_WEAR := Color(0.64, 0.47, 0.38)


func _dress_runner() -> void:
	if _runner_holder and ResourceLoader.exists(RUNNER_TILE) and ResourceLoader.exists(RUNNER_BORD):
		var mi := MeshInstance3D.new()
		mi.name = "TapisHD"
		mi.mesh = _runner_mesh(RUNNER_W, RUNNER_Z1 - RUNNER_Z0)
		mi.set_surface_override_material(0, _runner_mat(RUNNER_TILE))
		mi.set_surface_override_material(1, _runner_mat(RUNNER_BORD))
		_runner_holder.add_child(mi)
		for p in _runner_parts:
			p.visible = false
		# franges en coton des tapis de Builder (rug_franges.png : u = 10 cm de bord, v = 0 au tapis)
		if ResourceLoader.exists(RUG_DIR + "rug_franges.png"):
			var fm := Builder._rug_fringe_mat("oriental").duplicate() as StandardMaterial3D
			fm.albedo_color = Color(0.86, 0.8, 0.68)
			fm.uv1_scale = Vector3(RUNNER_W * 0.96 / 0.1, 1.0, 1.0)
			for f in _runner_fringes:
				f.material_override = fm
	# l'usure du passage, au milieu (coupée à l'endroit où passe le câble réseau, posé après elle)
	var o := {"color": RUNNER_WEAR, "mix": 0.9}
	Wear.path(self, [Vector2(4.0, -6.3), Vector2(3.98, -3.6), Vector2(4.02, -1.0), Vector2(3.99, 1.4), Vector2(4.0, 3.95)], 0.46, o)
	Wear.path(self, [Vector2(4.0, 4.35), Vector2(4.0, 5.25)], 0.46, o)


## Le tapis HD, centré sur le support « Tapis » : surface 0 = le champ (runner_tile, médaillon centré),
## surface 1 = les deux galons (runner_bord) ; UV2 = le tissage (m / RUG_WEAVE). Velours de RUNNER_TOP,
## chant biseauté, ondulations de moins d'un millimètre loin des bords.
static func _runner_mesh(w: float, l: float) -> ArrayMesh:
	var hw := w / 2.0
	var hl := l / 2.0
	var fh := hw - RUNNER_BORD_M.x
	var zs := PackedFloat32Array([-hl, -hl + 0.0025, -hl + 0.0055, -hl + 0.008])
	var nz := ceili((l - 0.016) / 0.2)
	for k in range(1, nz):
		zs.append(-hl + 0.008 + (l - 0.016) * k / nz)
	zs.append_array(PackedFloat32Array([hl - 0.008, hl - 0.0055, hl - 0.0025, hl]))
	var field := PackedFloat32Array([-fh, -fh / 2.0, 0.0, fh / 2.0, fh])
	var left := PackedFloat32Array([-hw, -hw + 0.0025, -hw + 0.0055, -hw + 0.008, -hw + 0.07, -fh])
	var right := PackedFloat32Array([fh, hw - 0.07, hw - 0.008, hw - 0.0055, hw - 0.0025, hw])
	var mesh := ArrayMesh.new()
	_runner_surface(mesh, [field], zs, hw, hl, true)
	_runner_surface(mesh, [left, right], zs, hw, hl, false)
	return mesh


static func _runner_h(x: float, z: float, hw: float, hl: float) -> float:
	var e := minf(hw - absf(x), hl - absf(z))
	var k := clampf(e / 0.008, 0.0, 1.0)
	var calm := clampf(e / 0.06, 0.0, 1.0)
	return RUNNER_TOP * (0.25 + 0.75 * sin(k * PI / 2.0)) \
		+ calm * (0.00035 * sin(z * 1.9 + 0.6) * cos(x * 3.5) + 0.00025 * sin(z * 4.7 + 1.3))


static func _runner_surface(mesh: ArrayMesh, groups: Array, zs: PackedFloat32Array, hw: float, hl: float, is_field: bool) -> void:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	for g in groups:
		var xs: PackedFloat32Array = g
		var base := verts.size()
		var nx := xs.size()
		for j in zs.size():
			var z := zs[j]
			for i in nx:
				var x := xs[i]
				var y := _runner_h(x, z, hw, hl)
				var dx := (_runner_h(x + 0.001, z, hw, hl) - _runner_h(x - 0.001, z, hw, hl)) / 0.002
				var dz := (_runner_h(x, z + 0.001, hw, hl) - _runner_h(x, z - 0.001, hw, hl)) / 0.002
				var nrm := Vector3(-dx, 1.0, -dz).normalized()
				var t := Vector3(1.0, dx, 0.0)
				t = (t - nrm * nrm.dot(t)).normalized()
				verts.append(Vector3(x, y, z))
				norms.append(nrm)
				tans.append_array([t.x, t.y, t.z, 1.0])
				if is_field:
					uvs.append(Vector2(x / RUNNER_TILE_M + 0.5, z / RUNNER_TILE_M + 0.5))
				else:
					uvs.append(Vector2(maxf(0.0, (hw - absf(x)) / RUNNER_BORD_M.x), z / RUNNER_BORD_M.y + 0.5))
				uv2.append(Vector2(x, z) / RUG_WEAVE)
		for j in zs.size() - 1:
			for i in nx - 1:
				var a := base + j * nx + i
				idx.append_array([a, a + 1, a + nx + 1, a, a + nx + 1, a + nx])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TANGENT] = tans
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)


## Laine du tapis HD : le motif, et le tissage des tapis de Builder (Fabric045 : normale de détail et
## occlusion sur UV2).
func _runner_mat(path: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.roughness = 0.96
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if ResourceLoader.exists(RUG_TEX % "NormalGL"):
		m.normal_enabled = true
		m.normal_texture = Builder._flat_normal()
		m.detail_enabled = true
		m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
		m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		m.detail_normal = load(RUG_TEX % "NormalGL")
		if ResourceLoader.exists(RUG_TEX % "AmbientOcclusion"):
			m.ao_enabled = true
			m.ao_on_uv2 = true
			m.ao_texture = load(RUG_TEX % "AmbientOcclusion")
			m.ao_light_affect = 0.25
	return m


# ---- console

## Sur la commode : un vase en laiton (brass_vase_03) au fond, côté sud, à côté du napperon ; un vide-poche
## en bois (wooden_bowl_02) au fond, côté nord, derrière le boîtier de téléassistance. Hors des places et des
## boîtes d'interaction de Nestor, du téléphone et de la téléassistance, et hors du trajet des câbles.
func _dress_console() -> void:
	var table: Node3D = props.get("sideTable")
	if table == null:
		return
	var size: Vector3 = table.get_meta("size")
	var top := size.y
	var half := size.x / 2.0
	var cz := table.global_position.z
	detail("brass_vase_03", Vector3(3.43, top, cz + half - 0.06), 25.0, Vector3.ZERO, {"range": 12.0, "shadow": true})
	detail("wooden_bowl_02", Vector3(3.44, top, cz - half + 0.085), 0.0, Vector3(0.1, 0.0, 0.0), {"range": 12.0, "shadow": true})


# ---- usure

## Les décalques de Wear (rien en Basse ni en rendu logiciel) ; un décalque de la 0.3.3 se cache quand son
## remplaçant est posé.
func _dress_wear() -> void:
	_wear_doors()
	# crasse en pied de mur, sauf derrière ce qui est contre le mur (console, chaise, radiateur, horloge,
	# sellette)
	Wear.wall_base(self, 0.22, {"gaps": [Rect2(3.3, -1.45, 0.45, 0.9), Rect2(3.3, -2.15, 0.5, 0.5), Rect2(4.45, -3.45, 0.3, 1.1),
		Rect2(3.3, -6.55, 0.45, 0.6), Rect2(3.75, 5.85, 0.5, 0.5)]})
	# coins du plafond, au fond nord (la chambre des grands-parents, le portrait)
	Wear.ceiling_corners(self, {"only": [0, 1], "size": 0.7})
	# auréole au plafond devant la fenêtre (la variante du couloir), infiltration sous l'appui, moisissure
	_replace_trace("tache", Wear.decal(self, "tache_plafond", Vector3(4.15, 2.6, 5.45), Vector3.DOWN, Vector3.BACK, 1.3, 1.05,
		{"variant": 1, "color": Color(0.85, 0.74, 0.58), "mix": 1.0}))
	_replace_trace("infiltration", Wear.decal(self, "coulure", Vector3(3.74, 0.6, ZS), Vector3.FORWARD, Vector3.UP, 0.48, 0.66,
		{"variant": 0, "color": Color(0.62, 0.56, 0.46)}))
	_replace_trace("moisissure_ouest", Wear.decal(self, "moisissure", Vector3(XW, 2.3, -6.95), Vector3.RIGHT, Vector3.UP, 0.62, 0.5, {"variant": 1}))
	_replace_trace("moisissure_nord", Wear.decal(self, "moisissure", Vector3(3.64, 2.46, ZN), Vector3.BACK, Vector3.UP, 0.68, 0.28, {"variant": 0}))
	# une fissure qui monte de l'angle du chambranle de la porte des grands-parents (P2) vers le plafond
	Wear.decal(self, "fissure", Vector3(XW, 2.36, -3.31), Vector3.RIGHT, Vector3.UP, 0.46, 0.46, {"variant": 1})
	# éraflures sur les plinthes : la chaise du téléphone, devant la salle de bain, près du bureau
	var k := 0
	for p in [Vector3(XW + 0.02, 0.06, -1.95), Vector3(XE - 0.02, 0.06, -3.9), Vector3(XE - 0.02, 0.06, 3.7)]:
		Wear.decal(self, "eraflure", p, Vector3.RIGHT if p.x < 4.0 else Vector3.LEFT, Vector3.UP, 0.55, 0.1,
			{"variant": k % 2, "depth": 0.08})
		k += 1


func _replace_trace(key: String, d: Decal) -> void:
	var old: Node3D = _old_traces.get(key)
	if d and old:
		old.visible = false


## Autour des poignées, côté couloir : crasse grasse et traces de doigts (une main entière sur la porte des
## grands-parents) ; salissures de chaussures en bas des battants. Décalques enfants du battant : ils suivent
## la porte quand elle s'ouvre. Poignée : à 7,5 cm du bord libre, à 1 m (door.gd).
func _wear_doors() -> void:
	if house == null:
		return
	for id in ["P1", "P2", "P3", "P4", "P5", "P6", "P7"]:
		var dr := house.doors.get(id) as Door
		if dr == null or dr.leaf == null:
			continue
		var leaf := dr.leaf
		var dir := 1.0 if dr.hinge_left else -1.0
		var lp := leaf.global_position
		var side := 1.0 if leaf.global_transform.basis.z.dot(Vector3(4.0, lp.y, lp.z) - lp) > 0.0 else -1.0
		var face := side * 0.0245
		var nrm := Vector3(0, 0, side)
		var hx := dir * (dr.width - 0.075)
		var n := int(id.substr(1))
		Wear.decal(leaf, "salissure", Vector3(hx - dir * 0.01, 1.0, face), nrm, Vector3.UP, 0.2, 0.34,
			{"variant": 0, "mix": 0.95, "color": Color(0.85, 0.76, 0.6), "depth": 0.04, "rot": float(n * 7 % 11) - 5.0, "name": "Crasse_poignee"})
		Wear.decal(leaf, "traces_doigts", Vector3(hx - dir * 0.02, 1.08 if id == "P2" else 1.05, face), nrm, Vector3.UP,
			0.2 if id == "P2" else 0.15, 0.24 if id == "P2" else 0.2, {"variant": 1 if id == "P2" else 0, "mix": 0.75, "depth": 0.04, "name": "Doigts_poignee"})
		Wear.decal(leaf, "salissure", Vector3(dir * dr.width / 2.0, 0.14, face), nrm, Vector3.UP, dr.width * 0.9, 0.28,
			{"variant": 0, "mix": 0.85, "color": Color(0.8, 0.72, 0.58), "rot": 180.0, "depth": 0.04, "name": "Salissures_bas"})


# ------------------------------------------------------------------ sauvegarde

## Réapplique l'état après un chargement (interrupteur, enceinte débranchée). Le niveau des ampoules
## (set_dim) appartient au scénario.
func restore() -> void:
	set_switch(bool(Game.flag("interrupteur_couloir", true)), true, true)
	if Game.flag("nestor_debranche", false):
		unplug_nestor(true)
