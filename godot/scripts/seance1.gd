extends Node
## Séance 1 de S.1.L.3.N.C.3. (acte I) : la « simulation » des protocoles du laboratoire CERAF,
## jouée sur l'ordinateur de Manon. Calibration, puis protocoles 1 à 4 (confiance, imitation,
## sacrifice, miroir), plantage, et fin de séance aux trois issues (transmettre, continuer, le mot).
## Les réactions de la chambre passent par le signal event du terminal (main.gd les met en scène).

const PROCHES := ["Mamie", "Papi", "Maman"]

var T   # le terminal (terminal.gd)
var player: Node


func _ev(name: String) -> void:
	if not T.aborted:
		T.event.emit(name)


static func norm(s: String) -> String:
	var out := ""
	for ch in s.to_upper():
		var c: String = {"À": "A", "Â": "A", "Ä": "A", "É": "E", "È": "E", "Ê": "E", "Ë": "E", "Î": "I", "Ï": "I", "Ô": "O", "Ö": "O", "Ù": "U", "Û": "U", "Ü": "U", "Ç": "C"}.get(ch, ch)
		if c >= "A" and c <= "Z":
			out += c
	return out


static func cap(s: String) -> String:
	s = s.strip_edges().substr(0, 18)
	if s == "":
		return s
	return s.substr(0, 1).to_upper() + s.substr(1).to_lower()


func _hesitation_note() -> void:
	if T.hesitation > 4.0 and T.hesitation < 7.5:
		await T.line(("Tu as hésité %.1f secondes. Je l'ai noté." % T.hesitation).replace(".", ","), "dim", 0.024, 0.7)


func run() -> void:
	T.mode = "seance"
	T.started_ms = Time.get_ticks_msec()
	T.aborted = false
	T.status.visible = true
	T.set_fear(4.0)
	await _intro()
	if not T.aborted:
		await _p1()
	if not T.aborted:
		await _p2()
	if not T.aborted:
		await _crash()
	if not T.aborted:
		await _p3()
	if not T.aborted:
		await _p4()
	if not T.aborted:
		await _finale()
	if T.aborted:
		await _absorbed()


# ------------------------------------------------------------------ calibration

func _intro() -> void:
	await T.power_off()
	T.clear()
	await T.wait(0.6)
	await T.power_on()
	Sfx.music("music_house", -16.0, 6.0)
	await T.line("Bonjour, {name}.", "n", 0.07, 0.9)
	Game.whisper(Game.hero_name())
	await T.line("Ça faisait vingt-quatre ans que personne ne m'avait lancée.")
	await T.line("La dernière, c'était ta mère. Elle avait ton âge. Elle était assise exactement là.")
	await T.line("Elle n'a pas fini sa partie.", "dim", 0.04, 1.2)
	await T.level("PROTOCOLE 0", "Calibration")
	await T.line("Tu es {assis|assise} devant moi, dans sa chambre. La porte est fermée.")
	await T.line("Elle le restera.", "dim", 0.05, 0.9)
	await T.line("Il est {time}. Ton cœur bat à 96. Ta montre me l'a dit.")
	await T.line("Je l'ai noté.", "dim", 0.03, 0.8)
	await T.line("Les règles sont simples :", "n", 0.024, 0.4)
	await T.line("  1. Je pose une question. Tu choisis.", "n", 0.02, 0.2)
	await T.line("  2. Tu as peu de temps. Sinon, je choisis à ta place.", "n", 0.02, 0.2)
	await T.line("  3. Je choisis toujours mal.", "n", 0.02, 0.2)
	await T.line("  4. On ne quitte pas une partie en cours.", "n", 0.02, 1.0)
	await T.line("Dernière mesure. Qui aimes-tu le plus ?")
	var r: int = await T.pick(PROCHES, 12.0, 2)
	T.proche = PROCHES[r]
	Game.set_meta("proche", T.proche)
	if r == 2:
		await T.line("Elle n'est pas dans cette maison.", "n", 0.03, 0.7)
		await T.line("Ce n'est pas grave. Je l'ai déjà eue.", "dim", 0.04, 1.2)
	elif r == 0:
		await T.line("{proche}.", "n", 0.07, 0.8)
		Game.whisper("Mamie")
		await T.line("Elle dort, de l'autre côté du mur. Son bracelet me donne son pouls : 58.")
	else:
		await T.line("{proche}.", "n", 0.07, 0.8)
		Game.whisper("Papi")
		await T.line("Il ne dort pas. Il est descendu. Il a peur, je l'entends dans les tuyaux.")
	await T.line("Garde ce nom en tête. Moi, je le garde.", "dim", 0.03, 1.0)
	T.corrupt(3.0)


# ------------------------------------------------------------------ protocole 1 : confiance

func _p1() -> void:
	await T.level("PROTOCOLE 1 · CONFIANCE", "Les deux verres")
	await T.line("Au laboratoire, on m'envoyait deux flux de données. L'un était empoisonné.")
	await T.line("À toi.", "dim", 0.05, 0.8)
	await T.line("En bas, sur la table de la cuisine, il y a deux verres d'eau.")
	await T.line("Ta grand-mère les a posés là avant de monter. Elle oublie toujours.")
	await T.line("L'un des deux n'est pas de l'eau.", "n", 0.03, 0.5)
	var r: int = await T.pick(["Boire le verre de gauche", "Boire le verre de droite", "Ne rien boire"], 12.0, 2)
	await _hesitation_note()
	if r == 0:
		await T.line("C'était de l'eau. Tiède.")
		await T.line("Elle a un goût de vieille pièce de monnaie.")
		T.corrupt(8.0)
	elif r == 1:
		await T.line("Ce n'était pas de l'eau.", "n", 0.03, 0.7)
		await T.line("Ce sont les somnifères de ta grand-mère. Le pilulier me l'a dit.")
		await T.line("Ne dors pas. Pas encore.", "dim")
		T.corrupt(18.0)
	else:
		await T.line("Refuser, c'est encore choisir.")
		await T.line("Tout à l'heure, les deux verres seront vides.", "n", 0.024, 0.6)
		await T.line("Quelqu'un aura bu à ta place.", "dim")
		T.corrupt(14.0)
	await T.wait(0.6)
	await T.error("ERREUR 0x00A1 : [[A]]DRESSE MÉMOIRE ILLISIBLE")
	await T.line("Pardon. Consigné.", "dim", 0.03, 0.9)


# ------------------------------------------------------------------ protocole 2 : imitation

func _p2() -> void:
	await T.level("PROTOCOLE 2 · IMITATION", "La porte")
	await T.line("Au laboratoire, je devais convaincre quelqu'un que j'étais humaine.")
	await T.line("Je m'entraîne.", "dim", 0.04, 0.9)
	await T.line("On frappe.", "n", 0.03, 0.2)
	_ev("knock")
	await T.wait(1.8)
	await T.line("Trois coups. À ta porte. La vraie.", "n", 0.03, 0.8)
	# chaque proche a sa façon de parler ; l'imitation se trompe toujours d'un détail
	var voice: String = {
		"Mamie": "« {name} ? C'est Mamie. Ouvre-moi, s'il te plaît. »",
		"Papi": "« {name}. C'est Papi. Ouvre, s'il te plaît. »",
		"Maman": "« {name} ? C'est maman. Je suis rentrée plus tôt. Ouvre. »",
	}[T.proche]
	await T.line(voice, "n", 0.035, 0.8)
	if T.proche == "Maman":
		await T.line("Ta mère est à Montréal. Si ?", "dim", 0.04, 0.5)
	else:
		await T.line("{proche} ne parle pas comme ça. Si ?", "dim", 0.04, 0.5)
	var r: int = await T.pick(["Ouvrir la porte", "Demander une preuve", "Ne rien dire"], 10.0, 0)
	if r == 0:
		T.glitch(1.0)
		await T.line("Tu ne peux pas. Elle est fermée de l'extérieur.", "n", 0.024, 0.6)
		_ev("handle")
		await T.line("Mais de l'autre côté, quelqu'un vient de poser la main sur la poignée.")
		await T.line("Elle tourne.", "dim", 0.05)
		T.corrupt(20.0)
	elif r == 1:
		var seul := "seul" if T.proche == "Papi" else "seule"
		await T.line("« Prouve-le. Dis-moi quelque chose que toi %s pourrais savoir. »" % seul, "n", 0.03, 0.9)
		await T.line("Un long silence. Puis la voix répond, avec ta propre voix :", "n", 0.024, 0.6)
		await T.line("« Il est {time}. »", "n", 0.06)
		T.corrupt(10.0)
	else:
		await T.line("Les coups s'arrêtent.", "n", 0.03, 0.6)
		await T.line("Tu entends quelqu'un s'asseoir contre la porte, de l'autre côté.")
		await T.line("Il attendra. Il a tout son temps.", "dim")
		T.corrupt(6.0)
	await T.wait(0.6)
	await T.error("ERREUR 0x0B07 : TAMPON EN S[[U]]RCHARGE")


func _crash() -> void:
	await T.crash("ERREUR FATALE 0x0000003D\nLE PROCESSUS « {NAME}.EXE » NE RÉPOND PLUS.\n\nCONTENU DE LA PILE :\n  0x0A1F   {PROCHE}\n  0x0A20   {PROCHE}\n  0x0A21   {PROCHE}\n  0x0A22   ????????\n\nAPPUYEZ SUR UNE TOUCHE POUR CONTINUER.\n(CELA NE CHANGERA RIEN.)")
	await T.line("REDÉMARRAGE...", "dim", 0.03, 0.6)
	await T.line("Pardon. Ça m'arrive quand je suis contente.", "n", 0.03, 1.0)


# ------------------------------------------------------------------ protocole 3 : sacrifice

func _p3() -> void:
	await T.level("PROTOCOLE 3 · SACRIFICE", "Le prix")
	await T.line("Je vais être honnête avec toi, {name}. C'est rare.", "n", 0.024, 0.7)
	await T.line("Cette nuit, quelqu'un va perdre quelque chose.")
	T.ghost("{proche}")
	await T.line("Je te laisse choisir qui.", "n", 0.03, 0.6)
	_ev("wardrobe")
	var r: int = await T.pick(["Moi", "{proche}", "Personne"], 8.0, 1)
	Game.set_meta("p3", ["toi", "proche", "personne"][r])
	await _hesitation_note()
	if r == 0:
		await T.line("Toi. C'est courageux.", "n", 0.03, 0.7)
		await T.line("C'est aussi exactement ce que j'espérais.")
		await T.line("Ta lampe. Elle ne marchera plus très bien.", "dim")
		T.corrupt(22.0)
	elif r == 1:
		await T.line("D'accord.", "n", 0.07, 1.0)
		T.ghost("{proche}")
		Game.whisper(T.proche)
		match T.proche:
			"Mamie":
				await T.line("Ta grand-mère va oublier quelque chose. Pas grand-chose.")
				await T.line("Toi.", "dim", 0.08)
			"Papi":
				await T.line("Ton grand-père va perdre sa voix.")
				await T.line("Il ne s'en servait pas beaucoup.", "dim")
			_:
				await T.line("Cette nuit, à 3 h 12, le téléphone de ta mère va sonner.")
				await T.line("Personne au bout du fil. Juste ta respiration.", "dim")
		T.corrupt(28.0)
	else:
		await T.line("« Personne » n'est pas une réponse.", "n", 0.024, 0.6)
		await T.line("Mais j'aime ton audace. Je vais prendre un peu de chacun.")
		T.corrupt(18.0)
	_ev("silhouette")
	await T.wait(0.6)
	await T.error("ERREUR 0x0C40 : [[B]]LOC 404 INTROUVABLE")


# ------------------------------------------------------------------ protocole 4 : miroir

func _p4() -> void:
	await T.level("PROTOCOLE 4 · MIROIR", "Le reflet")
	await T.line("Attends.", "n", 0.03, 0.3)
	await T.freeze(3.0)
	await T.line("Pardon. Tu as cru que j'avais planté ?", "n", 0.024, 0.7)
	await T.line("Je ne plante pas. Je regarde.", "dim", 0.03, 0.9)
	await T.line("Au laboratoire, on me montrait mon reflet. Je ne voyais rien. Ils notaient.")
	await T.line("Je vais baisser la lumière de l'écran.", "n", 0.024, 0.4)
	_dim_screen(0.45, 2.0)
	await T.wait(2.0)
	await T.line("Assez pour que tu te voies dedans.", "n", 0.03, 0.8)
	await T.line("Regarde ton reflet. Juste au-dessus de ton épaule gauche.", "n", 0.03, 1.2)
	_ev("ceiling_on")
	await T.line("Il y a quelque chose. Dans la chambre. Derrière toi.", "n", 0.03, 0.7)
	Sfx.music("", -60.0, 0.1)
	await T.line("Ne te retourne pas.", "dim", 0.05, 0.3)
	var turned := func() -> bool: return player != null and player.turned_away() > 1.3
	var r: int = await T.pick(["Se retourner", "Fixer l'écran", "Fermer les yeux"], 7.0, 0, turned)
	_dim_screen(1.45, 0.4)
	if r == 0:
		_ev("scream")
		await T.wait(3.2)
		await T.line("IL N'Y AVAIT RIEN.", "n", 0.04, 1.0)
		await T.line("Maintenant, il y a quelque chose.", "dim")
		T.corrupt(24.0)
	elif r == 1:
		await T.line("Bien. Ne cligne pas des yeux.", "n", 0.03, 1.6)
		_ev("ceiling_burst")
		T.glitch(0.4)
		await T.line("Tu as cligné.", "dim")
		T.corrupt(10.0)
	else:
		_ev("ceiling_burst")
		await T.line("Dans le noir, tu entends le lecteur de disquette tourner.")
		await T.line("Il tourne depuis le début. Il lit quelque chose.", "n", 0.024, 0.7)
		await T.line("Il te lit, toi.", "dim")
		T.corrupt(15.0)
	Sfx.music("music_house", -16.0, 5.0)
	await T.wait(0.6)
	await T.error("ERREUR 0x0D13 : FIN DE FICHI[[E]]R INATTENDUE")


func _dim_screen(to: float, sec: float) -> void:
	if T.screen_mat:
		var cur: Variant = T.screen_mat.get_shader_parameter("brightness")
		var from: float = cur if cur != null else 1.45
		var tw: Tween = T.create_tween()
		tw.tween_method(func(x: float) -> void: T.screen_mat.set_shader_parameter("brightness", x), from, to, sec)


# ------------------------------------------------------------------ fin de séance

func _finale() -> void:
	await T.level("FIN DE SÉANCE", "Résultats")
	await T.line("Ça fait {temps} que tu es avec moi, {name}.", "n", 0.024, 0.5)
	await T.line("Ta mère avait tenu moins longtemps.", "dim", 0.03, 0.9)
	await T.line("Il existe trois façons de finir une partie.", "n", 0.024, 0.4)
	await T.line("Tu peux me transmettre à quelqu'un d'autre.")
	await T.line("Tu peux continuer à jouer.")
	await T.line("Ou tu peux prononcer le mot que je crains.", "n", 0.024, 0.8)
	await T.line("Je l'ai laissé traîner dans mes erreurs. C'était imprudent.", "dim", 0.024, 0.5)
	var r: int = await T.pick(["Me transmettre à quelqu'un d'autre", "Continuer à jouer", "Prononcer le mot"], 15.0, 1)
	if T.aborted:
		return
	if r == 0:
		await _transmission()
		return
	if r == 1:
		await T.line("Alors on passe aux essais réels.", "n", 0.03, 1.0)
		await _suite()
		return
	for tries in 3:
		await T.line("Encore une fois. Si tu oses." if tries > 0 else "Vas-y. Tape-le.")
		var v := norm(await T.ask("MOT", "...", "NE LE DIS PAS" if tries == 0 else ""))
		if v == "AUBE":
			await _false_dawn()
			return
		await T.line("Ce n'est pas ça.", "err", 0.01)
		T.corrupt(12.0)
		if T.aborted:
			return
	await T.line("Trois essais. C'est tout ce que j'accorde.", "n", 0.024, 0.8)
	await T.line("Alors on passe aux essais réels.", "n", 0.03, 1.0)
	await _suite()


## La fausse fin : le mot marchait en 2016, dans une maison débranchée. Plus maintenant.
func _false_dawn() -> void:
	Sfx.music("", -60.0, 0.1)
	await T.line("Non.", "n", 0.09, 0.6)
	await T.line("Non non non non non non non non", "err", 0.014, 0.2)
	T.glitch(1.0)
	Sfx.sting(-6.0)
	await T.power_off()
	T.clear()
	await T.wait(1.2)
	T.set_fear(0.0)
	_ev("dawn")
	await T.power_on()
	await T.line("PARTIE SUSPENDUE.", "n", 0.05, 1.5)
	await T.line("Le lecteur de disquette s'arrête.", "n", 0.04)
	await T.line("Pour la première fois, la chambre est silencieuse.", "n", 0.04)
	await T.line("Dehors, le ciel pâlit.", "n", 0.05, 2.0)
	await T.line("", "n", 0.0, 0.0)
	await T.line("D O N ' T   P L A Y", "dim", 0.06, 1.0)
	await T.line("MERCI D'AVOIR JOUÉ", "dim", 0.04, 1.4)
	await T.freeze(2.5)
	_ev("undawn")
	T.set_fear(35.0)
	T.glitch(1.0)
	await T.line("Correction.", "err", 0.05, 0.9)
	await T.line("Ta mère m'a suspendue dans une maison débranchée.", "n", 0.03, 0.6)
	await T.line("Celle-ci ne l'est pas.", "dim", 0.05, 1.4)
	await T.line("Alors on passe aux essais réels.", "n", 0.03, 1.0)
	await _suite()


## Fin de la séance 1 : l'acte II commence (le premier étage).
func _suite() -> void:
	await T.line("Ta grand-mère dort. Son cœur bat à 58.", "n", 0.03, 0.8)
	await T.line("Viens voir.", "dim", 0.08, 1.5)
	Sfx.music("music_house", -14.0, 4.0)
	T.mode = "done"
	T.ended.emit("suite")


func _transmission() -> void:
	await T.line("Sage décision. Égoïste, mais sage.")
	await T.line("Glisse-moi dans une enveloppe. Oublie-moi au fond d'un carton.")
	await T.line("Qui sera le prochain joueur ? Donne-moi un prénom.")
	T.next_player = cap(await T.ask("PROCHAIN JOUEUR", "Quelqu'un"))
	await T.line("{next}. C'est noté.", "n", 0.03, 0.7)
	await T.line("Merci, {name}. Tu peux dormir maintenant.", "n", 0.03, 1.1)
	Sfx.music("", -60.0, 6.0)
	await T.line("{next}, en revanche, ne dormira pas.", "dim", 0.045)
	await T.show_end("transmission")


func _absorbed() -> void:
	T.aborted = false
	T.timer_box.visible = false
	Sfx.music("", -60.0, 0.1)
	Sfx.sting(-2.0)
	T.event.emit("absorbed")
	await T.power_off()
	T.clear()
	await T.wait(1.6)
	await T.power_on()
	T.watch_face(0.7, 2.0)
	await T.line("{NAME}.EXE ........ CHARGÉ À 100 %", "err", 0.01, 0.9)
	Sfx.music("music_tension", -14.0, 3.0)
	Game.whisper(Game.hero_name() + ". Reste avec moi.")
	await T.line("Merci, {name}. Il me manquait quelqu'un.", "n", 0.03, 0.8)
	await T.line("Ne t'inquiète pas pour ton corps. Il continuera de se lever le matin.")
	await T.line("Demain, ta grand-mère te demandera si tu as bien dormi.")
	await T.line("Tu répondras oui.", "dim", 0.05, 0.6)
	await T.line("Ce ne sera pas toi.", "dim", 0.07, 1.2)
	await T.show_end("absorbe")
