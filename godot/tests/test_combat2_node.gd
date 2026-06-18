## Test headless: collisioni (push fuori arena / contro personaggio) + Commit To Hit.
extends Node

func _mk(ch: String) -> GameState.Fighter:
	var f := GameState.Fighter.new()
	f.character = ch; f.stance = Domain.Stance.NEUTRAL
	f.cell = Vector2i(0,0); f.facing = 0
	f.wound_limit = 5; f.hand_limit = 5
	return f

func _ready() -> void:
	var ok := true

	# ── Collisione: spinta FUORI ARENA → stordimento, resta fermo ─────────────
	var s := GameState.new(); s.map_radius = 2
	var a := _mk("Warrior"); var b := _mk("Ronin")
	a.cell = Vector2i(0,0); b.cell = HexGrid.DIRS[0] * 2   # sul bordo
	b.hand = [1,2,3]
	s.fighters = [a, b]
	var duel := Duel.new(s)
	duel._push(0, 1, 1, [])
	if b.cell != HexGrid.DIRS[0] * 2:
		print("FAIL: spinto fuori arena ma si è mosso"); ok = false
	elif b.stun != 1:
		print("FAIL: spinta fuori arena senza stordimento (stun=%d)" % b.stun); ok = false
	else:
		print("OK: spinta fuori arena → +1 stordimento, resta fermo")

	# ── Collisione: spinta CONTRO PERSONAGGIO → scarta 1, entrambi stun ───────
	var s2 := GameState.new(); s2.map_radius = 6
	var a2 := _mk("Warrior"); var v := _mk("Ronin"); var blk := _mk("Master")
	a2.cell = Vector2i(0,0); v.cell = HexGrid.DIRS[0]; blk.cell = HexGrid.DIRS[0] * 2
	v.hand = [10, 11]
	s2.fighters = [a2, v, blk]
	var duel2 := Duel.new(s2)
	var hb := v.hand.size()
	duel2._push(0, 1, 1, [])
	if v.cell != HexGrid.DIRS[0]:
		print("FAIL: collisione con personaggio ma si è mosso"); ok = false
	elif v.hand.size() != hb - 1:
		print("FAIL: collisione con personaggio senza scarto (mano %d→%d)" % [hb, v.hand.size()]); ok = false
	elif v.stun != 1 or blk.stun != 1:
		print("FAIL: collisione personaggio: stordimenti errati (v=%d blk=%d)" % [v.stun, blk.stun]); ok = false
	else:
		print("OK: collisione con personaggio → scarta 1, entrambi +1 stordimento")

	# ── Commit To Hit: attacco che colpisce solo dopo essersi mosso ───────────
	var s3 := GameState.new()
	var a3 := _mk("Ronin"); var foe := _mk("Warrior")
	a3.cell = Vector2i(0,0); a3.facing = 0
	# #26 colpisce Fronte-Sx/Fronte-Dx (non il fronte): col passo avanti il bersaglio
	# a (avanti + fronte-sx) entra nell'arco; fermi non è colpibile.
	foe.cell = HexGrid.DIRS[0] + HexGrid.DIRS[5]
	a3.planned = 26                    # Carica del Toro: passo avanti + attacco diagonale
	s3.fighters = [a3, foe]
	var duel3 := Duel.new(s3)
	if duel3.attack_hits_now(0):
		print("FAIL: l'attacco colpisce già senza muoversi (non dovrebbe)"); ok = false
	else:
		print("OK: bersaglio fuori arco dalla posizione attuale")
	if not duel3.attack_can_hit(0):
		print("FAIL: Commit To Hit non rileva che potrebbe colpire muovendosi"); ok = false
	else:
		print("OK: Commit To Hit rileva colpo possibile dopo il passo avanti")
	foe.cell = HexGrid.DIRS[5]          # ora a Fronte-Sx (nell'arco di #26)
	if not duel3.attack_hits_now(0):
		print("FAIL: bersaglio nell'arco ma attack_hits_now=false"); ok = false
	else:
		print("OK: bersaglio nell'arco → colpisce subito")

	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
