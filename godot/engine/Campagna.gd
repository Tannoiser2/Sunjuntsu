class_name Campagna
extends RefCounted
## Campagna «Path of the Ronin»: scenari in ordine, mazzo del Ronin che cambia con le scelte,
## progressi salvati sul dispositivo.

const FILE := "user://campagna.json"


static func dati() -> Dictionary:
	return Carte.db().campagna


static func carica() -> Dictionary:
	if FileAccess.file_exists(FILE):
		var f := FileAccess.open(FILE, FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary and d.has("fatti"):
				return d
	return nuova()


static func nuova() -> Dictionary:
	var deck := {}
	for k in dati().mazzo:
		deck[str(k)] = int(dati().mazzo[k])
	return {"fatti": [], "mazzo": deck, "strada": "", "prove": {}}


static func salva(st: Dictionary) -> void:
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(st))


static func scenario(id: String) -> Dictionary:
	for sc in dati().scenari:
		if sc.id == id:
			return sc
	return {}


## Primo scenario non ancora vinto.
static func prossimo(st: Dictionary) -> String:
	for sc in dati().scenari:
		if not st.fatti.has(sc.id):
			return sc.id
	return ""


## Configurazione della partita per Game.prepara().
static func setup_partita(id: String, st: Dictionary) -> Dictionary:
	var sc := scenario(id)
	var r: Dictionary = sc.ronin
	var players: Array = [{"char": "ronin", "mazzo": {"deck": st.mazzo.duplicate(), "core": dati().core.duplicate()},
		"pos": r.pos, "face": r.face, "kamae": r.get("kamae", "neutral"), "focus": r.get("focus", 0)}]
	var primo := true
	for n in sc.nemici:
		var pl := {"char": n.tipo, "solo": true, "name": n.nome, "ferite": n.ferite, "pos": n.pos, "face": n.face,
			"post": n.post, "comp": n.comp, "owner": 1}
		if n.has("extra"):
			pl["extra_deck"] = n.extra
		players.append(pl)
		primo = false
	for a in sc.get("alleati", []):
		players.append({"char": a.tipo, "protetta": true, "name": a.nome, "ferite": a.ferite, "pos": a.pos,
			"face": a.face, "owner": 0})
	return {"seed": randi(), "map": sc.get("mappa", "villaggio"), "pezzi": sc.get("pezzi", []), "scenario": sc,
		"players": players}
