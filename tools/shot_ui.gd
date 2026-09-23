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
	if what == "help":
		Hud.current.help.open()
		print("help open=", Hud.current.help.visible)
		for i in 3: await get_tree().process_frame
		print("help later=", Hud.current.help.visible)
