extends Node
## 말 걸기 화면을 찍는다 (--write-movie 와 함께). 인자: 찍을 것 (hub · tip · den · cave)
##   godot --path . --write-movie out.png --quit-after 60 res://tools/shot_talk.tscn -- hub

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	await get_tree().process_frame
	var what: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "hub"
	var p: Dragon = GameState.player
	GameState.elderTutorialDone = true
	var gron = World.any_npc("Gron")
	match what:
		"hub":
			p.x = gron.x - 70; p.y = gron.y + 10
			for i in 5: await get_tree().process_frame
			Dialogue.start(gron, "TALK")
		"tip":
			p.x = gron.x - 70; p.y = gron.y + 10
		"den":
			World.travel_to("DEN_MINE")
		"cave":
			World.travel_to("EAST_ROAD")
			for i in 3: await get_tree().process_frame
			Delve.enter("FOREST_HOLE")
