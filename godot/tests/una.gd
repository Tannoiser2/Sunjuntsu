extends SceneTree
func _initialize() -> void:
	var g := Game.new()
	var b0 := Bot.new(0, 11)
	var b1 := Bot.new(1, 12)
	g.deciders = [b0.decidi, b1.decidi]
	g.logged.connect(func(t): print(t))
	g.start({"seed": 9, "players": [{"char": "warrior"}, {"char": "ronin", "solo": true}]})
	quit(0)
