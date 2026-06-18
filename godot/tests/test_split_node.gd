## Test headless: iniziativa divisa (#24 Vortice Cremisi): sopra (init8) colpisce
## il fronte a distanza 2; sotto (init5) avanza di 1 e colpisce il fronte a dist1 →
## un bersaglio due esagoni davanti subisce entrambe le parti (2 + 2 = 4 ferite).
## La parte sotto è un attacco separato, bloccabile alla propria velocità.
extends Node
func _mk(ch: String) -> GameState.Fighter:
	var f := GameState.Fighter.new()
	f.character=ch; f.stance=Domain.Stance.AGGRESSION; f.cell=Vector2i(0,0); f.facing=0
	f.wound_limit=12; f.hand_limit=5
	return f
func _ready():
	var ok := true
	var s := GameState.new()
	var a := _mk("Ronin"); a.planned = 24
	# #24: sopra colpisce il fronte a dist2; sotto avanza e colpisce il fronte a dist1.
	# Bersaglio due esagoni davanti → entrambe le parti vanno a segno (2 + 2 = 4).
	var b := _mk("Warrior"); b.cell = HexGrid.DIRS[0] * 2; b.facing = 3
	s.fighters.append(a); s.fighters.append(b)
	var duel := Duel.new(s)
	duel._resolve_card(0, {}, [])
	if b.wounds.size() != 4:
		print("FAIL: attese 4 ferite (2 sopra + 2 sotto), ottenute %d" % b.wounds.size()); ok=false
	else:
		print("OK: iniziativa divisa #24 → 4 ferite totali (sopra 2 + sotto 2)")

	# La parte SOTTO (vel 5) è bloccabile separatamente: difesa a vel 5 che copre
	# l'attaccante ferma SOLO la parte sotto → restano le 2 ferite della parte sopra.
	var s2 := GameState.new()
	var a2 := _mk("Ronin"); a2.planned = 24
	var b2 := _mk("Warrior"); b2.cell = HexGrid.DIRS[0] * 2; b2.planned = 63  # Blocco Cinereo
	b2.facing = AI.facing_toward(b2.cell, Vector2i(0,0))  # fronte (blocco) verso l'attaccante
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
