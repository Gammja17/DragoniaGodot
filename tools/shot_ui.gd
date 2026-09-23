extends Node
## 판 화면 찍기 (--write-movie 와 함께). 인자: title · create · settings · help
##   godot --path . --write-movie out.png --quit-after 40 res://tools/shot_ui.tscn -- title

func _ready() -> void:
	var what: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "title"
	if what == "title" or what == "create":
		var t: Node = load("res://scenes/title.tscn").instantiate()
		add_child(t)
		if what == "create":
			await get_tree().process_frame
			t._new(3)
		return
	Save.slot = 9
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	for i in 5: await get_tree().process_frame
	if what == "settings": Hud.current.settings.open()
	if what.begins_with("journal"):
		var p = GameState.player
		p.stage_index = 2
		for i in 5: p.gain_xp(p.max_xp - p.xp)
		for id in ["TAIL_SWIPE", "METEOR", "ROAR"]: Skills.learn(id, true)
		GameState.growth.points = 9
		Growth.invest_node("FANG1")
		Growth.invest_node("FANG1")
		for id in Relics.table().keys().slice(0, 3): Relics.grant(id, p.x, p.y)
		GameState.quests.active.m0 = { step = 2, n = 0 }
		GameState.quests.tracked = "m0"
		GameState.stats.kills = { SLIME = 4, GOBLIN = 2 }
		GameState.visited = ["VILLAGE", "EAST_ROAD", "LAKE"]
		var tab: String = OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "quests"
		Hud.current.journal.toggle_tab(tab)
		if tab == "quests": Hud.current.journal._open_row = "m0"
		if tab == "skills": Hud.current.journal._picked = { kind = "skill", id = "METEOR" }
		if tab == "growth": Hud.current.journal._picked = { kind = "node", id = "FANG2" }
		Hud.current.journal.render()
	if what == "help":
		Hud.current.help.open()
		print("help open=", Hud.current.help.visible)
		for i in 3: await get_tree().process_frame
		print("help later=", Hud.current.help.visible)
