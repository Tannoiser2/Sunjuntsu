class_name Mazzi
extends RefCounted
## Mazzi personalizzati (Regolamento 1a ed., "Deck Construction"):
## 30 carte (40 per il gioco competitivo), oltre alla carta speciale e all'arma che non contano.
## Legno fino a 3 copie, Acciaio fino a 2, Oro 1 (al massimo 8 Oro in tutto), Giada 1 sola.
## Carte base (Gen. Ability) per tutti, carte firma solo del proprio personaggio.

const FILE := "user://mazzi.json"
const COPIE := {"Wood": 3, "Steel": 2, "Gold": 1, "Jade": 1}
const RANGHI := {"Wood": "Legno", "Steel": "Acciaio", "Gold": "Oro", "Jade": "Giada"}
const MAX_ORO := 8
const MAX_GIADA := 1


static func carica() -> Dictionary:
	if not FileAccess.file_exists(FILE):
		return {}
	var f := FileAccess.open(FILE, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


static func salva(tutti: Dictionary) -> void:
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(tutti))


## Sigla delle carte firma del personaggio (es. "Warrior").
static func firma(k: String) -> String:
	var cd: Dictionary = Carte.db().characters[k]
	for id in cd.deck:
		var p: String = str(Carte.carta(int(id)).get("pers", ""))
		if p != "Gen. Ability" and not p.contains("/"):
			return p
	return ""


static func carta_speciale(k: String) -> int:
	for id in Carte.db().characters[k].core:
		if not Carte.carta(int(id)).has("weapon"):
			return int(id)
	return -1


## Carte che il personaggio può mettere nel mazzo, in ordine di rango e numero.
static func disponibili(k: String) -> Array:
	var sig := firma(k)
	var ordine := {"Wood": 0, "Steel": 1, "Gold": 2, "Jade": 3}
	var out: Array = []
	for c in Carte.db().cards.values():
		if int(c.id) >= 1000 or c.get("core", false) or c.has("weapon") or not COPIE.has(str(c.get("rank", ""))):
			continue
		var p: String = str(c.get("pers", ""))
		if p == "Gen. Ability" or p == sig:
			out.append(int(c.id))
	out.sort_custom(func(a, b):
		var ca := Carte.carta(a)
		var cb := Carte.carta(b)
		var fa: int = 0 if str(ca.pers) == sig else 1
		var fb: int = 0 if str(cb.pers) == sig else 1
		if fa != fb:
			return fa < fb
		if ordine[ca.rank] != ordine[cb.rank]:
			return ordine[ca.rank] < ordine[cb.rank]
		return a < b)
	return out


## Carte arma che il personaggio può scegliere.
static func armi(k: String) -> Array:
	var cd: Dictionary = Carte.db().characters[k]
	var sig := firma(k)
	var out: Array = []
	for c in Carte.db().cards.values():
		if not c.has("weapon") or int(c.id) >= 1000:
			continue
		var p: String = str(c.get("pers", ""))
		if not cd.get("armi", []).has(str(c.weapon)):
			continue
		if p == "Weapon" or p == sig + "/Weapon":
			out.append(int(c.id))
	out.sort()
	return out


static func base(k: String) -> Dictionary:
	var cd: Dictionary = Carte.db().characters[k]
	var deck := {}
	for id in cd.deck:
		deck[str(id)] = int(cd.deck[id])
	var ar: Array = []
	for id in cd.core:
		if Carte.carta(int(id)).has("weapon"):
			ar.append(int(id))
	return {"deck": deck, "armi": ar, "dim": 30}


static func conta(deck: Dictionary) -> int:
	var n := 0
	for id in deck:
		n += int(deck[id])
	return n


## Errori di costruzione (vuoto = mazzo valido).
static func errori(k: String, m: Dictionary) -> Array:
	var err: Array = []
	var deck: Dictionary = m.get("deck", {})
	var dim: int = int(m.get("dim", 30))
	var n := conta(deck)
	if n != dim:
		err.append("Il mazzo ha %d carte: ne servono %d." % [n, dim])
	var oro := 0
	var giada := 0
	var ok := disponibili(k)
	for id in deck:
		var c := Carte.carta(int(id))
		var q := int(deck[id])
		if not ok.has(int(id)):
			err.append("«%s» non è permessa a questo personaggio." % c.name)
			continue
		if q > int(COPIE[c.rank]):
			err.append("«%s»: al massimo %d copie (%s)." % [c.name, COPIE[c.rank], RANGHI[c.rank]])
		if c.rank == "Gold":
			oro += q
		elif c.rank == "Jade":
			giada += q
	if oro > MAX_ORO:
		err.append("Troppe carte Oro: %d su %d." % [oro, MAX_ORO])
	if giada > MAX_GIADA:
		err.append("Si può avere una sola carta Giada.")
	var na: int = int(Carte.db().characters[k].get("n_armi", 1))
	if m.get("armi", []).size() != na:
		err.append("Scegli %d arma/i." % na)
	return err


## Mazzo da usare in partita per il personaggio: {} = mazzo base.
static func in_uso(k: String) -> Dictionary:
	var tutti := carica()
	var m: Dictionary = tutti.get(k, {})
	if not m.get("attivo", false) or not errori(k, m).is_empty():
		return {}
	return per_partita(k, m)


## Formato passato al motore: mazzo {id: copie} e carte iniziali in mano (speciale + armi).
static func per_partita(k: String, m: Dictionary) -> Dictionary:
	var core: Array = [carta_speciale(k)]
	for a in m.get("armi", []):
		core.append(int(a))
	return {"deck": m.deck.duplicate(), "core": core}
