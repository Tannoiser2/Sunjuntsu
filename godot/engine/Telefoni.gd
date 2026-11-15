class_name Telefoni
extends Node
## Partita con gli smartphone: il tavolo (TV/computer) crea una stanza su Firebase, i giocatori la
## aprono dal telefono con un QR code. Il tavolo pubblica nella stanza ("game") lo stato visibile e
## le richieste aperte di ogni giocatore; il telefono risponde scrivendo nel registro ("log/<id>").
## Nessuna modifica alle regole del database: "game" lo scrive solo il tavolo, "log" i membri.

signal giocatori_cambiati(posti: Dictionary)

const PAGINA := "https://tannoiser2.github.io/Sunjuntsu/telefono/"
const LIMITE := 3900

var rete: Rete
var codice := ""
var posti_necessari := 2
var posti: Dictionary = {}        ## "1" -> nome
var richieste: Dictionary = {}    ## posto (1, 2) -> richiesta compatta aperta
var prossimo_id := 1
var g: Game
var nomi_pers: Array = []
var _sporco := false
var _invio := false


func crea(cfg: Dictionary) -> bool:
	rete = Rete.new()
	add_child(rete)
	codice = await rete.create_room("Tavolo", cfg)
	return codice != ""


func indirizzo(posto: int) -> String:
	var base := PAGINA
	if OS.has_feature("web"):
		var loc = JavaScriptBridge.eval("location.origin + location.pathname")
		if loc != null and str(loc).begins_with("http"):
			base = str(loc).get_base_dir() + "/telefono/"
	return "%s?c=%s&g=%d" % [base, codice, posto]


## Attende che i telefoni occupino i posti 1..posti_necessari.
func attendi_giocatori() -> void:
	while true:
		var st: Dictionary = await rete.room(codice)
		var s: Dictionary = Rete._as_dict(st.get("seats", {}))
		var nuovi := {}
		for k in s:
			if k != "0" and s[k] is Dictionary:
				nuovi[k] = str(s[k].get("name", "?"))
		if nuovi != posti:
			posti = nuovi
			giocatori_cambiati.emit(posti)
		var tutti := true
		for i in range(1, posti_necessari + 1):
			if not posti.has(str(i)):
				tutti = false
		if tutti:
			return
		await get_tree().create_timer(1.2).timeout


## Chiede al telefono del giocatore p (0 o 1). Ritorna l'indice scelto, oppure -1 se nel frattempo
## ha risposto il tavolo (annulla() chiamato da fuori).
func chiedi(r: Dictionary) -> int:
	var posto: int = int(r.p) + 1
	var id := prossimo_id
	prossimo_id += 1
	richieste[posto] = _compatta(r, id)
	await pubblica()
	while richieste.has(posto) and int(richieste[posto].id) == id:
		await get_tree().create_timer(0.7).timeout
		var d = await rete.get_decision(codice, id)
		if d is Dictionary and d.has("i") and richieste.has(posto) and int(richieste[posto].id) == id:
			richieste.erase(posto)
			pubblica()
			return clampi(int(d.i), 0, r.opts.size() - 1)
	return -1


func annulla(p: int) -> void:
	if richieste.erase(p + 1):
		pubblica()


func _compatta(r: Dictionary, id: int) -> Dictionary:
	var k: String = r.kind
	var o: Array = []
	match k:
		"move", "place", "hex":
			for x in r.opts:
				o.append([x.pos.x, x.pos.y, int(x.face)])
		"card":
			for x in r.opts:
				o.append(int(x.card))
		_:
			for x in r.opts:
				var e := {"l": str(x.get("label", x.get("v", "?")))}
				if x.has("card") and int(x.card) >= 0:
					e["c"] = int(x.card)
				o.append(e)
	var out := {"id": id, "k": k, "t": str(r.text), "o": o}
	if r.has("card"):
		out["c"] = int(r.card)
	if r.get("scarto", false):
		out["s"] = 1
	if r.has("f") and int(r.f) != int(r.p):
		out["f"] = int(r.f)   # la pedina che si muove (es. Hachiko)
	return out


## Stato visibile e richieste aperte; si scrive al massimo una volta alla volta.
func pubblica() -> void:
	_sporco = true
	if _invio:
		return
	_invio = true
	while _sporco:
		_sporco = false
		var dati := {"rq": richieste, "st": _stato()}
		var testo := JSON.stringify(dati)
		if testo.length() > LIMITE:
			dati.st.erase("fig")
			testo = JSON.stringify(dati)
		await rete.db_patch(Rete.ROOT + "/" + codice, {"game": testo})
	_invio = false


func _stato() -> Dictionary:
	if g == null or g.F.is_empty():
		return {}
	var gioc: Array = []
	for i in 2:
		var f: Dictionary = g.F[i]
		gioc.append({"n": f.name, "ch": f.char, "h": f.hand, "fo": f.focus, "w": f.wounds + f.bleeds, "l": int(f.lim),
			"k": Carte.KAMAE.get(f.kamae, ""), "d": f.deck.size(), "sc": f.discard.size(), "ai": f.ai, "dead": f.dead})
	var fig: Array = []
	for f in g.F:
		if f.pos.x < 50 and not f.dead:
			fig.append([f.pos.x, f.pos.y, int(f.face), int(f.owner), f.name.left(2)])
	var ter: Array = []
	for c in g.terreno:
		ter.append([c.x, c.y])
	var tr: Array = []
	for c in g.trappole:
		tr.append([c.x, c.y])
	return {"tu": g.turn, "fa": g.fase, "gi": gioc, "fig": fig, "ter": ter, "tr": tr, "over": g.over, "win": g.winner}
