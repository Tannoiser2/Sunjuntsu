class_name Carte
extends RefCounted
## Accesso ai dati delle carte e descrizioni in italiano (riga per riga).

const KAMAE := {"aggression": "Aggressione", "balance": "Equilibrio",
	"determination": "Determinazione", "neutral": "Neutrale", "focus": "Punto Focus"}
const COMPORTAMENTI := ["Sinistra", "Centro", "Destra"]
const TIPI := {"attack": "Attacco", "defence": "Difesa", "meditation": "Meditazione", "core": "Speciale"}
const EFFETTI_CELLA := {"w1": "1 ferita", "w2": "2 ferite", "b": "ferita sanguinante",
	"x": "ESECUZIONE", "a": "asterisco", "w1a": "1 ferita + asterisco",
	"ba": "sanguinante + asterisco", "s": "blocco", "sa": "blocco con asterisco"}

static var _db: Dictionary = {}


static func db() -> Dictionary:
	if _db.is_empty():
		ricarica()
	return _db


static func ricarica() -> void:
	var percorso := "user://carte.json"
	if not FileAccess.file_exists(percorso):
		percorso = "res://data/carte.json"
	_db = JSON.parse_string(FileAccess.get_file_as_string(percorso))
	# Le righe "A poi B" diventano righe di movimento consecutive.
	for c in _db.cards.values():
		for s in c.segs:
			s.lines = _espandi(s.lines)


static func _espandi(lines: Array) -> Array:
	var out: Array = []
	for ln in lines:
		if ln.t == "move" and ln.get("seq", false):
			for p in ln.parts:
				var n: Dictionary = ln.duplicate()
				n.erase("seq")
				n.parts = [p]
				out.append(n)
		elif ln.t == "or":
			var n2: Dictionary = ln.duplicate()
			n2.opts = []
			for o in ln.opts:
				n2.opts.append(_espandi(o))
			out.append(n2)
		else:
			out.append(ln)
	return out


static func carta(id: int) -> Dictionary:
	return db().cards[str(id)]


static func nome(id: int) -> String:
	if id == -2:
		return "Veleno Debilitante"
	if id < 0:
		return "Stordimento"
	return carta(id).name


static func iniz_testo(c: Dictionary) -> String:
	if c.init is Array:
		return "%d-%d" % [int(c.init[0]), int(c.init[1])]
	return str(c.init) if c.init is String else str(int(c.init))


static func _dirs(d: Array) -> String:
	if d.size() == 6:
		return "qualsiasi direzione"
	var n: Array = []
	for x in d:
		n.append(Hex.NOMI_DIR[int(x)])
	return " / ".join(n)


static func _parte(p: Dictionary) -> String:
	var s := ""
	if p.m == "step":
		s = "passo %d (%s)" % [int(p.n), _dirs(p.dirs)]
	else:
		s = "rotazione %d" % int(p.n)
	return s + (" facoltativo" if p.opt else " OBBLIGATORIO")


static func _porta(ln: Dictionary) -> String:
	var s := ""
	if ln.has("k"):
		var ks: Array = ln.k if ln.k is Array else [ln.k]
		var nn: Array = []
		for k in ks:
			nn.append(KAMAE[k])
		s += "[%s] " % " o ".join(nn)
	if ln.has("f"):
		s += "[costo %d focus] " % int(ln.f)
	return s


static func effetto(e: Dictionary) -> String:
	var n := int(e.get("n", 1))
	match e.v:
		"discard": return "scarta %d carta/e" % n
		"draw": return "pesca fino a %d carta/e" % n
		"draw_exact": return "pesca %d carte" % n
		"focus": return "ottieni %d focus" % n
		"lose_focus_all": return "scarta tutto il focus"
		"lose_focus_all_but": return "scarta tutto il focus tranne %d" % n
		"switch": return "passa a " + ("una qualsiasi Kamae" if e.to == "any" else KAMAE[e.to])
		"change": return "cambia Kamae fino a %d ramo/i" % n
		"push": return "spingi il bersaglio di %d" % n
		"t_stun": return "il bersaglio prende 1 stordimento"
		"t_hobble": return "il bersaglio viene azzoppato"
		"t_rot": return "ruota il bersaglio di %d" % n
		"t_lose_focus": return "il bersaglio scarta %d focus" % n
		"t_switch": return "il bersaglio passa a " + ("una Kamae a tua scelta" if e.to == "any" else KAMAE[e.to])
		"t_discard_type": return "il bersaglio scarta %d carta %s" % [n, TIPI[e.type]]
		"self_stun": return "prendi 1 stordimento"
		"self_hobble": return "prendi 1 azzoppamento"
		"t_wound": return "il bersaglio subisce %d ferita" % n
		"t_wound_to_bleed": return "il bersaglio sostituisce 1 ferita con 1 sanguinante"
		"search": return "cerca nel mazzo e prendi 1 carta%s di rango %s" % [_tipo(e), _rango(e)]
		"search_discard": return "cerca negli scarti e prendi 1 carta%s di rango %s" % [_tipo(e), _rango(e)]
		"search_top": return "guarda le prime %d carte del mazzo e prendine 1" % n
		"discard_stun": return "scarta fino a %d stordimenti" % n
		"bleed_to_wound": return "sostituisci tutte le ferite sanguinanti con ferite"
		"view_hand": return "guarda la mano del bersaglio"
		"steal_focus": return "ruba %d focus al bersaglio" % n
		"swap": return "scambia posizione con il bersaglio"
		"t_step": return "sposta il bersaglio di %d nella sua direzione %s" % [n, Hex.NOMI_DIR[int(e.get("dir", 0))]]
		"trade": return "scarta 1 carta di rango %s, poi cerca negli scarti e prendi 1 carta di rango %s" % [_rango({"rank": e.drop}), _rango(e)]
		"all_draw": return "tutti i giocatori pescano %d carte" % n
		"counter_now":
			var cv: Array = []
			for v in e.v2:
				cv.append(str(int(v)))
			return "contrattacco a iniziativa " + ", ".join(cv)
		"t_poison": return "il bersaglio è avvelenato (Veleno Debilitante)"
		"t_shuffle_type": return "il bersaglio rimescola nel mazzo 1 carta %s dalla mano" % TIPI[e.type]
		"t_draw": return "il bersaglio pesca %d carte" % n
		"t_give_top": return "guarda le prime %d carte del mazzo del bersaglio: ne scegli 1, che lui prende in mano" % n
		"pull_or_push": return "tira o spingi il bersaglio di %d" % n
		"nota": return str(e.get("txt", "")) + " (non automatizzato)"
		"reshuffle": return "mischia nel mazzo tutte le tue carte abilità non speciali"
		"cancel_cards": return "ogni bersaglio a distanza cancella le sue carte abilità attive"
		"each_stun": return "ogni bersaglio a distanza prende 1 stordimento"
		"cancel_move": return "cancella il movimento attivo del bersaglio"
		"advantage": return "ottieni il Vantaggio"
		"add_wound": return "+%d ferita" % n
		"armour": return "rimane in gioco: riduci di 1 le ferite di ogni attacco subito (minimo 1); a ogni riduzione [Determinazione] ottieni 1 focus, poi prendi 1 azzoppamento"
		"ai_change": return "cambia Comportamento IA"
		"ai_reset": return "ricomponi il mazzo (a fine turno)"
		"ai_recycle": return "mischia nel mazzo la prima carta Attacco degli scarti"
		"t_discard": return "il bersaglio scarta %d carta/e" % n
		"broad_block": return "aumenta di 1 l'intervallo d'iniziativa del tuo blocco"
	return str(e.v)


static func _tipo(e: Dictionary) -> String:
	return "" if e.get("type", "") == "" else " " + TIPI[e.type]


static func _rango(e: Dictionary) -> String:
	var nomi := {"Wood": "Legno", "Steel": "Acciaio", "Gold": "Oro", "Jade": "Giada"}
	var a: Array = []
	for r in (e.rank if e.rank is Array else [e.rank]):
		a.append(nomi.get(r, r))
	return " o ".join(a)


static func effetti(fx: Array) -> String:
	var a: Array = []
	for e in fx:
		a.append(effetto(e))
	return ", poi ".join(a)


static func riga(ln: Dictionary) -> String:
	var g := _porta(ln)
	match ln.t:
		"alt": return g + "iniziativa alternativa %d" % int(ln.v)
		"move":
			var a: Array = []
			for p in ln.parts:
				a.append(_parte(p))
			return g + " + ".join(a)
		"grid":
			var a2: Array = []
			for c in ln.cells:
				a2.append("%s: %s" % [cella_nome(c), EFFETTI_CELLA.get(ln.cells[c], ln.cells[c])])
			var coda := ""
			if ln.has("ak"):
				coda = " (asterisco = blocco solo in %s)" % KAMAE[ln.ak]
			return g + ("Attacco — " if ln.mode == "atk" else "Blocco — ") + "; ".join(a2) + coda
		"ast": return g + "* = " + effetti(ln.fx)
		"mod": return g + "le ferite di questo attacco diventano sanguinanti"
		"counter":
			var a3: Array = []
			for v in ln.v:
				a3.append(str(int(v)))
			return g + "contrattacco a iniziativa " + ", ".join(a3)
		"ifs": return "SE RIUSCITO:"
		"unblockable": return "NON BLOCCABILE"
		"fx": return g + effetti(ln.fx)
		"or":
			var a4: Array = []
			for o in ln.opts:
				var b: Array = []
				for l in o:
					b.append(riga(l))
				a4.append(" · ".join(b))
			return "  OPPURE  ".join(a4)
	return "?"


static func cella_nome(c: String) -> String:
	if c.length() == 1:
		return Hex.NOMI_DIR[int(c)]
	if c[0] == c[1]:
		return Hex.NOMI_DIR[int(c[0])] + " a distanza 2"
	return "%s+%s (dist. 2)" % [Hex.NOMI_DIR[int(c[0])], Hex.NOMI_DIR[int(c[1])]]


## Testo completo della carta (per tooltip, editor e verifica).
static func testo(c: Dictionary) -> String:
	var out: Array = []
	var testa := "%s — %s, iniziativa %s" % [c.name, TIPI[c.type], iniz_testo(c)]
	if int(c.focus) > 0:
		testa += ", costo %d focus" % int(c.focus)
	if c.has("req"):
		var rq: Array = []
		for k in (c.req if c.req is Array else [c.req]):
			rq.append(KAMAE[k])
		testa += ", richiede " + " o ".join(rq)
	if c.has("instant"):
		testa += ", " + ("Sostituzione istantanea" if c.instant == "rep" else "Aggiunta istantanea")
	if c.has("range"):
		testa += ", Distanza %d" % int(c.range)
	out.append(testa)
	for i in c.segs.size():
		var s: Dictionary = c.segs[i]
		if s.has("init"):
			if c.get("or", false):
				out.append("— OPPURE, se non può attaccare, a iniziativa %d —" % int(s.init))
			else:
				out.append("— a iniziativa %d —" % int(s.init))
		for ln in s.lines:
			out.append("  " + riga(ln))
	if c.has("note"):
		out.append("Nota: " + c.note)
	return "\n".join(out)
