class_name Carte
extends RefCounted
## Accesso ai dati delle carte e descrizioni in italiano (riga per riga).

const KAMAE := {"aggression": "Aggressione", "balance": "Equilibrio",
	"determination": "Determinazione", "neutral": "Neutrale", "focus": "Punto Focus", "ranged": "Kamae a Distanza"}
const COMPORTAMENTI := ["Sinistra", "Centro", "Destra"]
const TIPI := {"attack": "Attacco", "defence": "Difesa", "meditation": "Meditazione", "core": "Speciale"}
const EFFETTI_CELLA := {"w1": "1 ferita", "w2": "2 ferite", "w3": "3 ferite", "b": "ferita sanguinante",
	"x": "ESECUZIONE", "a": "asterisco", "w1a": "1 ferita + asterisco",
	"ba": "sanguinante + asterisco", "s": "blocco", "sa": "blocco con asterisco", "diff": "ferite pari alla differenza di iniziativa",
	"p": "veleno", "pa": "veleno + asterisco"}

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
	if c.init is String:
		return c.init
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
	if ln.get("o", false):
		s += "[Occultato] "
	if ln.get("d", false):
		s += "[Disperazione] "
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
		"search": return "cerca nel mazzo e prendi 1 carta%s%s di rango %s" % [_tipo(e), " del personaggio" if e.get("pers", "") != "" else "", _rango(e)]
		"search_discard": return "cerca negli scarti e prendi 1 carta%s%s di rango %s" % [_tipo(e), " del personaggio" if e.get("pers", "") != "" else "", _rango(e)]
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
		"illum_search": return "puoi prendere 1 stordimento per cercare nel mazzo e prendere 1 carta Illuminata"
		"search_illum": return "cerca %s e prendi 1 carta Illuminata" % ("negli scarti" if e.get("scarti", false) else "nel mazzo")
		"illumina":
			var bn := {"wounds": "limite di ferite", "hand": "limite di mano", "focus": "limite di focus"}
			return "rimane in gioco: +1 al tuo %s" % bn.get(e.get("bonus", ""), "")
		"wounds_to_stun": return "sostituisci tutte le ferite ricevute in questo turno con stordimenti"
		"flip_dog": return "volta la carta Kamae di Hachiko"
		"heal": return "scarta 1 ferita"
		"bleed1_to_wound": return "sostituisci 1 ferita sanguinante con 1 ferita"
		"dog_adjacent_focus": return "se adiacente all'Ashigaru, ottieni 1 focus"
		"dog_move": return "Hachiko: passo 1 (qualsiasi direzione) facoltativo"
		"ferro": return "rimane in gioco per 4 turni: non prendi ferite se non puoi pescare carte"
		"drag": return "fai 1 passo indietro, poi tira il bersaglio di 1"
		"pull": return "tira il bersaglio di %d" % n
		"self_wound": return "prendi %d ferita" % n
		"draw_return": return "pesca %d carte, poi rimettine altrettante nel mazzo e mischia" % n
		"reveal_take": return "rivela le prime %d carte del tuo mazzo e prendi tutte quelle del tuo personaggio" % n
		"search_stun": return "cerca nel mazzo e prendi 1 Attacco che infligge stordimento"
		"contract_back": return "rimetti nella tua area di gioco un contratto scartato, a faccia in su"
		"lavoro_finito": return "per ogni contratto completato in gioco: +1 focus, pesca 1 carta, rimescola nel mazzo 1 carta Legno dagli scarti; poi scarta tutti i contratti"
		"t_discard_rand": return "il bersaglio scarta 1 carta a caso"
		"discard_hobble": return "scarta 1 azzoppamento"
		"t_stun_per_step": return "il bersaglio prende 1 stordimento per ogni casella in cui ti sei mosso"
		"push_steps": return "spingi il bersaglio di 1, +1 per ogni casella in cui ti sei mosso (solo dopo un attacco)"
		"conceal": return "entra in Occultamento"
		"t_mill_wounds": return "il bersaglio scarta dalla cima del mazzo tante carte quante sono le sue ferite, +1"
		"cancel_rot": return "cancella la rotazione attiva del bersaglio"
		"add_bleed": return "+%d ferita sanguinante" % n
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
			if ln.get("ad", false):
				coda = " (asterisco = blocco solo in Disperazione)"
			if ln.get("retro", false):
				coda += " (requisito: devi essere alle spalle del bersaglio)"
			return g + ("Attacco — " if ln.mode == "atk" else "Blocco — ") + "; ".join(a2) + coda
		"ast": return g + "* = " + effetti(ln.fx)
		"mod": return g + "le ferite di questo attacco diventano sanguinanti"
		"counter":
			var a3: Array = []
			for v in ln.v:
				a3.append(str(int(v)))
			return g + "contrattacco a iniziativa " + ", ".join(a3)
		"ifs": return "SE RIUSCITO:"
		"rng": return g + "la Distanza diventa %d" % int(ln.v)
		"ranged": return "Attacco a distanza — colpisci il bersaglio con iniziativa inferiore: " + EFFETTI_CELLA.get(ln.eff, ln.eff) + ("" if ln.get("fx", []).is_empty() else ", poi " + effetti(ln.fx))
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
	if c.get("req_d", false):
		testa += ", richiede Disperazione"
	if c.has("req_illum"):
		testa += ", requisito: %d carte Illuminate in gioco" % int(c.req_illum)
	if c.has("fisica"):
		testa += "; carta di Hachiko, metà usata in " + ("Aggressione" if int(c.id) < 4000 else "Determinazione")
	if c.get("zanmato", false):
		testa += "; quando rivelata scarta tutti i contratti: per ogni contratto completato +1 iniziativa oppure +1 ferita"
	if c.get("range_contr", false):
		testa += " (+1 per ogni contratto completato)"
	if c.get("counter_only", false):
		testa += ", si gioca solo come contrattacco"
	elif c.get("counter_ok", false):
		testa += ", giocabile anche come contrattacco"
	if c.get("no_play", false):
		testa += ", non si può giocare come carta abilità"
	out.append(testa)
	for i in c.segs.size():
		var s: Dictionary = c.segs[i]
		if s.has("init"):
			if c.get("or", false):
				out.append("— OPPURE, se non può attaccare, a iniziativa %d —" % int(s.init))
			elif s.init is Array:
				out.append("— a iniziativa %d-%d —" % [int(s.init[0]), int(s.init[1])])
			else:
				out.append("— a iniziativa %d —" % int(s.init))
		for ln in s.lines:
			out.append("  " + riga(ln))
	if c.has("note"):
		out.append("Nota: " + c.note)
	return "\n".join(out)
