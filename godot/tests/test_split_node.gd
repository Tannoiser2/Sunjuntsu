## Test headless: iniziativa divisa (#26 Carica del Toro): sopra (init7, 2 ferite)
## + sotto (init5, 1 ferita) = 3 ferite; la parte sotto è un attacco a parte.
extends Node
func _mk(ch: String) -> GameState.Fighter:
	var f := GameState.Fighter.new()
	f.character=ch; f.stance=Domain.Stance.AGGRESSION; f.cell=Vector2i(0,0); f.facing=0
	f.wound_limit=12; f.hand_limit=5
	return f
func _ready():
	var ok := true
	var s := GameState.new()
	var a := _mk("Ronin"); a.planned = 26
	var b := _mk("Warrior"); b.cell = HexGrid.DIRS[0]; b.facing = 3
	s.fighters.append(a); s.fighters.append(b)
	var duel := Duel.new(s)
	duel._resolve_card(0, {}, [])
	if b.wounds.size() != 3:
		print("FAIL: attese 3 ferite (2 sopra + 1 sotto), ottenute %d" % b.wounds.size()); ok=false
	else:
		print("OK: iniziativa divisa #26 → 3 ferite totali (sopra 2 + sotto 1)")

	# La parte SOTTO (vel 5) è bloccabile separatamente: difesa a vel 5 che copre
	# l'attaccante ferma SOLO la parte sotto → restano le 2 ferite della parte sopra.
	var s2 := GameState.new()
	var a2 := _mk("Ronin"); a2.planned = 26
	var b2 := _mk("Warrior"); b2.cell = HexGrid.DIRS[0]; b2.facing = 3; b2.planned = 63  # Blocco Cinereo (copre il fronte)
	s2.fighters.append(a2); s2.fighters.append(b2)
	var duel2 := Duel.new(s2)
	duel2._block_ready = {1: 5}   # la difesa aggancia velocità 5 (parte sotto)
	duel2._resolve_card(0, duel2._block_ready, [])
	if b2.wounds.size() != 2:
		print("FAIL: difesa a vel5 doveva fermare solo la parte sotto (atteso 2, ottenuto %d)" % b2.wounds.size()); ok=false
	else:
		print("OK: difesa a vel5 ferma la parte sotto, la parte sopra (2 ferite) passa")

	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
