extends Node
## 터치 조작 화면 찍기. PC 에서 휴대폰 화면(세로 540×1170 · 가로 1170×540, 1080×2340 폰의 절반)을 흉내 내 찍어 PNG 로 남긴다.
## 인자: portrait | landscape, 저장할 파일
##   godot --path . res://tools/shot_touch.tscn -- portrait C:/tmp/touch_p.png   (창을 띄워야 그림이 나온다)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var what: String = args[0] if args.size() > 0 else "portrait"
	var out: String = args[1] if args.size() > 1 else "user://shot_touch.png"
	UiScale.force_mobile = true
	get_window().size = Vector2i(540, 1170) if what == "portrait" else Vector2i(1170, 540)
	UiScale.apply()
	Save.slot = 9
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	for i in 5: await get_tree().process_frame
	GameInput.touch = true
	GameState.elderTutorialDone = true
	var p = GameState.player
	p.stage_index = 2
	for id in ["TAIL_SWIPE", "METEOR", "ROAR"]: Skills.learn(id, true)
	for el in ["ICE", "THUNDER"]: p.unlock_element(el)
	p.inventory.meat = 3
	p.ult = 60
	var e := Enemy.make(p.x + 150, p.y - 60, "SLIME")
	World.add_entity("enemies", e)
	await get_tree().create_timer(1.0).timeout
	p.cooldowns[p.slots.F] = 3.0
	p.cd_max[p.slots.F] = 8.0
	if args.has("fire"): GameInput.set_virtual("attack", true)
	if args.has("talk"): Dialogue.start(World.any_npc("Gron"), "TALK")
	if args.has("journal"): Hud.current.journal.toggle_tab("quests")
	if args.has("settings"): Hud.current.settings.open()
	await get_tree().create_timer(0.35).timeout
	print("[%s] 화면 %s 창 %s" % [what, get_viewport().get_visible_rect().size, get_window().size])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
