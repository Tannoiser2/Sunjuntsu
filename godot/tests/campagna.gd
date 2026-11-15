extends SceneTree
## Partite automatiche degli scenari della campagna (bot per entrambe le parti).
func _initialize() -> void:
	var vinte := 0
	var a := OS.get_cmdline_user_args()
	var n := int(a[0]) if a.size() > 0 else 20
	var id: String = a[1] if a.size() > 1 else "onore"
	var strada: String = a[2] if a.size() > 2 else "rosso"
	var st := Campagna.nuova()
	for s in n:
		var g := Game.new()
		var b0 := Bot.new(0, s * 2 + 1)
		var b1 := Bot.new(1, s * 2 + 2)
		g.deciders = [func(gg, r): return b0.decidi(gg, r), func(gg, r): return b1.decidi(gg, r)]
		var cfg := Campagna.setup_partita(id, st, strada)
		cfg.seed = s + 1
		g.start(cfg)
		var guard := 0
		while not g.over and guard < 5000:
			await process_frame
			guard += 1
		if g.winner == 0:
			vinte += 1
		print("partita ", s, " vincitore ", g.winner, " turni ", g.turn, " fig ", g.F.map(func(f): return "%s %d/%d%s" % [f.name, f.wounds, f.lim, " X" if f.dead else ""]))
	print("Scenario ", id, " ", strada, ": vinte dal Ronin ", vinte, "/", n)
	quit(0)
