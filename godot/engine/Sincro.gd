class_name Sincro
extends Node
## Partita online a due: ogni dispositivo fa girare lo stesso motore con lo stesso seme e
## le decisioni (numerate in ordine) passano da Firebase. Chi rientra rigioca il registro.

signal tocca_a_me(req: Dictionary)
signal attesa(testo: String)

var rete: Rete
var codice := ""
var posto := 0
var g: Game
var arretrati: Dictionary = {}   ## decisioni già registrate (per chi rientra)
var recupero := false
var chiuso := false


func avvia(gioco: Game) -> void:
	g = gioco
	arretrati = await rete.get_decisions(codice, 0)
	recupero = not arretrati.is_empty()
	g.ask.connect(_su_richiesta)


func _su_richiesta(req: Dictionary) -> void:
	var n: int = g.journal.size()
	if arretrati.has(n):
		var d: Dictionary = arretrati[n]
		arretrati.erase(n)
		if arretrati.is_empty():
			recupero = false
		g.answer.call_deferred(int(d.get("i", 0)))
		return
	recupero = false
	if int(req.p) == posto:
		tocca_a_me.emit(req)
		return
	attesa.emit("In attesa di %s…" % g.F[req.p].name)
	while not chiuso:
		var d2 = await rete.get_decision(codice, n)
		if d2 is Dictionary and d2.has("i"):
			g.answer(int(d2.i))
			return
		await get_tree().create_timer(1.0).timeout


## La mia risposta: prima la pubblico, poi la applico.
func rispondi(idx: int) -> void:
	var n: int = g.journal.size()
	while not chiuso:
		if await rete.post_decision(codice, n, {"p": posto, "i": idx}):
			break
		# forse era già stata scritta (richiesta ripetuta dopo un errore di rete)
		var gia = await rete.get_decision(codice, n)
		if gia is Dictionary and gia.has("i"):
			idx = int(gia.i)
			break
		attesa.emit("Connessione assente, riprovo…")
		await get_tree().create_timer(2.0).timeout
	g.answer(idx)
