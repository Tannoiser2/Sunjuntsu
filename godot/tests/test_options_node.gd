## Test headless: "OPPURE" applica UNA sola opzione (carta #23) + verbi stun/discard self.
## #23 corretto: a=scarta 1 · b=pesca 2 · c=+1 stordito + passa Kamae · d=cambia Kamae.
extends Node
func _mk() -> GameState.Fighter:
	var f := GameState.Fighter.new()
	f.character="Ronin"; f.stance=Domain.Stance.NEUTRAL; f.cell=Vector2i(0,0); f.wound_limit=8; f.hand_limit=9
	return f
func _ready():
	var ok := true
	# ── Opzione A (auto = prima applicabile): scarta 1; niente pesca/stordimento ──
	var s := GameState.new()
	var f := _mk(); f.planned=23; f.hand=[100,101]; f.draw_pile=[200,201,202]
	s.fighters.append(f); s.fighters.append(_mk())
	var duel := Duel.new(s)
	var hand0 := f.hand.size()
	duel._resolve_card(0, {}, [])
	if f.stun != 0:
		print("FAIL: opzione A non dovrebbe dare stordimento (stun=%d)" % f.stun); ok=false
	elif Domain.STANCE_SLUG[f.stance] != "neutral":
		print("FAIL: opzione A non dovrebbe cambiare kamae (%s)" % Domain.STANCE_SLUG[f.stance]); ok=false
	elif f.hand.size() != hand0 - 1:
		print("FAIL: opzione A mano attesa %d, ottenuta %d" % [hand0-1, f.hand.size()]); ok=false
	else:
		print("OK: opzione A → scarta 1 (mano %d→%d), nessuna pesca/stordimento" % [hand0, f.hand.size()])

	# ── Opzione C (scelta): +1 stordito + passa a kamae qualsiasi; niente pesca/scarto ──
	var s2 := GameState.new()
	var f2 := _mk(); f2.planned=23; f2.hand=[100,101]; f2.draw_pile=[200,201,202]
	s2.fighters.append(f2); s2.fighters.append(_mk())
	var duel2 := Duel.new(s2)
	duel2.set_option_choice(0, "c")
	var hand2 := f2.hand.size()
	duel2._resolve_card(0, {}, [])
	if f2.stun != 1:
		print("FAIL: opzione C dovrebbe dare +1 stordimento (stun=%d)" % f2.stun); ok=false
	elif Domain.STANCE_SLUG[f2.stance] == "neutral":
		print("FAIL: opzione C dovrebbe cambiare kamae"); ok=false
	elif f2.hand.size() != hand2:
		print("FAIL: opzione C non dovrebbe pescare/scartare (mano %d→%d)" % [hand2, f2.hand.size()]); ok=false
	else:
		print("OK: opzione C → +1 stordito, kamae %s, mano invariata" % Domain.STANCE_SLUG[f2.stance])

	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
