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


## Scenario con la strada scelta (rossa o blu) già applicata.
static func con_strada(id: String, strada: String) -> Dictionary:
	var sc: Dictionary = scenario(id).duplicate(true)
	if sc.has("strade"):
		var k := strada if sc.strade.has(strada) else "rosso"
		var s: Dictionary = sc.strade[k]
		for x in s:
			if x == "pezzi":
				sc.pezzi = sc.get("pezzi", []) + s.pezzi
			elif x != "testo":
				sc[x] = s[x]
		sc["strada"] = k
		sc["testo_strada"] = s.get("testo", "")
	return sc


## Strada già decisa da uno scenario precedente (es. il dojo segue la scelta fatta alle porte).
static func strada_imposta(id: String, st: Dictionary) -> String:
	var sc := scenario(id)
	if sc.has("strada_da"):
		return str(st.get("strade", {}).get(sc.strada_da, ""))
	return ""


## Mazzo del Ronin con le modifiche di preparazione dello scenario.
static func mazzo_scenario(sc: Dictionary, mazzo: Dictionary) -> Dictionary:
	var dk: Dictionary = mazzo.duplicate()
	for k in sc.get("aggiungi", {}):
		dk[str(k)] = int(dk.get(str(k), 0)) + int(sc.aggiungi[k])
	for k in sc.get("aggiungi_se_manca", []):
		if int(dk.get(str(k), 0)) == 0:
			dk[str(k)] = 1
	if sc.has("prima_carta") and int(dk.get(str(sc.prima_carta), 0)) == 0:
		dk[str(sc.prima_carta)] = 1
	return dk


## Applica una scelta di fine scenario al mazzo (e alla strada).
static func applica_dopo(st: Dictionary, id: String, scelta: Dictionary, copia: int = -1) -> void:
	for k in scelta.get("rimuovi", {}):
		var n := int(st.mazzo.get(str(k), 0)) - int(scelta.rimuovi[k])
		if n > 0:
			st.mazzo[str(k)] = n
		else:
			st.mazzo.erase(str(k))
	for k in scelta.get("aggiungi", {}):
		st.mazzo[str(k)] = int(st.mazzo.get(str(k), 0)) + int(scelta.aggiungi[k])
	if copia >= 0:
		st.mazzo[str(copia)] = int(st.mazzo.get(str(copia), 0)) + 1
	if scelta.has("strada"):
		if not st.has("strade"):
			st["strade"] = {}
		st.strade[id] = scelta.strada


## Carte d'Acciaio in copia unica nel mazzo (per la scelta dopo «L'occhio nascosto»).
static func acciaio_singole(mazzo: Dictionary) -> Array:
	var out: Array = []
	for k in mazzo:
		if int(mazzo[k]) == 1 and str(Carte.carta(int(k)).get("rank", "")) == "Steel":
			out.append(int(k))
	out.sort()
	return out


## Configurazione della partita per Game.prepara().
static func setup_partita(id: String, st: Dictionary, strada: String = "") -> Dictionary:
	var sc := con_strada(id, strada)
	var r: Dictionary = sc.ronin
	var dk := mazzo_scenario(sc, st.mazzo)
	var ronin := {"char": "ronin", "mazzo": {"deck": dk, "core": dati().core.duplicate()},
		"pos": r.pos, "face": r.face, "kamae": r.get("kamae", "neutral"), "focus": r.get("focus", 0)}
	if sc.get("armatura", false):
		ronin["armatura"] = true
	if sc.has("prima_carta"):
		ronin["prima_carta"] = sc.prima_carta
	var players: Array = [ronin]
	for n in sc.nemici:
		var pl := {"char": n.tipo, "solo": true, "name": n.nome, "ferite": n.ferite, "pos": n.pos, "face": n.face,
			"post": n.post, "comp": n.comp, "owner": 1}
		if n.has("extra"):
			pl["extra_deck"] = n.extra
		players.append(pl)
	for a in sc.get("alleati", []):
		players.append({"char": a.tipo, "protetta": true, "name": a.nome, "ferite": a.ferite, "pos": a.pos,
			"face": a.face, "owner": 0})
	return {"seed": randi(), "map": sc.get("mappa", "villaggio"), "pezzi": sc.get("pezzi", []), "scenario": sc,
		"players": players, "mazzo_dopo": dk}
