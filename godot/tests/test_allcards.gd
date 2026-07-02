## Risolve OGNI carta (44) tramite il flusso reale per scovare errori a runtime.
extends Node

func _mk(ch, stance) -> GameState.Fighter:
	var f = GameState.Fighter.new()
	f.character = ch; f.stance = stance
	f.cell = Vector2i(0, 0); f.facing = 0
	f.wound_limit = 5; f.hand_limit = 5
	return f

func _ready() -> void:
	var ids := CardDB.by_id.keys()
	ids.sort()
	var tested := 0
	for cid in ids:
		var g := CardDB.geometry(cid)
		if g.is_empty():
			continue   # solo le 44 con geometria
		tested += 1
		var s := GameState.new()
		var a := _mk("Warrior", Domain.Stance.NEUTRAL)
		var b := _mk("Ronin", Domain.Stance.NEUTRAL)
		# nemico in vari punti per coprire archi/anelli
		b.cell = HexGrid.DIRS[0] * 2; b.facing = 3
		a.draw_pile.assign([116, 116, 116, 116, 116])
		b.draw_pile.assign([21, 22, 23, 24, 25])
		s.fighters.append(a); s.fighters.append(b)
		var duel := Duel.new(s)
		# soddisfa eventuale kamae_req (String o Array in OR: basta una)
		var req_list := Kamae.gate_values(g.get("kamae_req", ""))
		if not req_list.is_empty():
			a.stance = Domain.STANCE_FROM_SLUG[req_list[0]]
		a.focus = 5
		a.planned = cid
		b.planned = -1
		var log: Array = []
		duel._resolve_chosen_speeds({})
		duel._resolve_card(0, {}, log)
		print("#%d %s -> ok" % [cid, CardDB.card(cid).get("name","?")])
	print("ALLCARDS DONE testate=", tested)
	get_tree().quit(0)
