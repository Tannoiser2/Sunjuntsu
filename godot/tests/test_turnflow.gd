## Test flusso di turno completo: gioca → risolvi → scarta/pesca, su mazzi reali.
extends Node

func _mk(ch, stance) -> GameState.Fighter:
	var f = GameState.Fighter.new()
	f.character = ch; f.stance = stance
	f.cell = Vector2i(0, 0); f.facing = 0
	f.wound_limit = 5; f.hand_limit = 5
	return f

func _ready() -> void:
	var s := GameState.new()
	var a := _mk("Warrior", Domain.Stance.NEUTRAL); a.is_ai = false; a.cell = Vector2i(0, 0); a.facing = 0
	var b := _mk("Ronin", Domain.Stance.NEUTRAL); b.is_ai = true; b.cell = HexGrid.DIRS[0]; b.facing = 3
	a.draw_pile.assign(CardDB.draw_pile_for("warrior"))
	b.draw_pile.assign(CardDB.draw_pile_for("ronin"))
	s.fighters.append(a); s.fighters.append(b)
	var duel := Duel.new(s)
	duel.start()
	print("start: mano A=", a.hand.size(), " mano B=", b.hand.size())

	var turns := 0
	while s.phase != Domain.Phase.GAME_OVER and turns < 12:
		if a.planned == -1:
			var played := false
			for cid in a.hand.duplicate():
				if Duel.playable(a, cid):
					var disc_before := a.discard.size()
					var ok := duel.plan_card(0, cid)
					if ok:
						played = true
						print("turno %d: gioco #%d (%s) | mano A=%d scarti A=%d (era %d) | mano B=%d scarti B=%d" % [
							turns, cid, CardDB.card(cid).get("name","?"),
							a.hand.size(), a.discard.size(), disc_before, b.hand.size(), b.discard.size()])
						break
			if not played:
				print("turno %d: NESSUNA carta giocabile in %s (mano %d)" % [turns, Domain.STANCE_NAMES[a.stance], a.hand.size()])
				# sblocca: prova a cambiare in aggression
				a.stance = Domain.Stance.AGGRESSION
		turns += 1

	print("TURNFLOW DONE turni=", turns, " fase=", s.phase)
	get_tree().quit(0)
