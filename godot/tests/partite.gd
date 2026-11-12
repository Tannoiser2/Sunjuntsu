extends SceneTree
## Partite automatiche IA contro IA: verifica che il motore regga fino alla fine.

func _initialize() -> void:
	var n := 200
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			n = int(a)
	var vittorie := [0, 0, 0]
	var turni := 0
	var kinds := {}
	for s in n:
		var g := Game.new()
		var b0 := Bot.new(0, s * 2 + 1)
		var b1 := Bot.new(1, s * 2 + 2)
		g.deciders = [func(gg, r): kinds[r.kind] = kinds.get(r.kind, 0) + 1; return b0.decidi(gg, r),
			func(gg, r): kinds[r.kind] = kinds.get(r.kind, 0) + 1; return b1.decidi(gg, r)]
		var stato := {"fine": false}
		g.finished.connect(func(_w): stato.fine = true)
		var chars := ["warrior", "ronin"] if s % 2 == 0 else ["ronin", "warrior"]
		g.start({"seed": s + 1, "players": [{"char": chars[0]}, {"char": chars[1]}]})
		if not stato.fine:
			printerr("Partita %d NON terminata (turno %d, fase %s, pending %s)" % [s, g.turn, g.fase, g.pending])
			quit(1)
			return
		var w := g.winner
		vittorie[2 if w < 0 else (0 if g.F[w].char == "warrior" else 1)] += 1
		turni += g.turn
	print("Partite: %d — Guerriero %d, Ronin %d, pari %d — turni medi %.1f" % [n, vittorie[0], vittorie[1], vittorie[2], float(turni) / n])
	print("Decisioni: ", kinds)
	quit(0)
