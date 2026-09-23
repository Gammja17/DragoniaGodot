extends Node
## 보스가 깨어나 패턴을 쓰고, 쓰러지면 보상(숨결·기술·유물)을 주는지 본다.
##   godot --headless --path . tools/test_boss.tscn -- MORGATH_LAIR


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	var map: String = args[0] if args.size() > 0 else "MORGATH_LAIR"
	GameState.story.events = ["ev_morgath", "ev_zalgora", "ev_glacia", "ev_basil", "ev_ignar"]   # 사건을 겪은 뒤라야 둥지에 보스가 있다
	World.travel_to(map)
	await get_tree().process_frame
	var p: Dragon = GameState.player
	var b: Boss = GameState.entities.bosses[0]
	print("보스: %s  체력 %d" % [b.def.name, b.hp])
	p.max_hp = 5000; p.hp = 5000   # 패턴을 오래 보려고 버티게 한다
	p.x = b.x; p.y = b.y + 400
	var patterns := {}
	var hazards := 0
	var shots := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 10000:
		await get_tree().process_frame
		patterns[b.pattern_index] = true
		hazards = maxi(hazards, GameState.entities.hazards.size())
		shots = maxi(shots, GameState.entities.bullets.filter(func(x): return x.faction == "ENEMY").size())
		p.x = b.x; p.y = b.y + 400
	print("10초: 깨어남 %s, 쓴 패턴 %d개, 장판 최대 %d, 적 탄 최대 %d, 내 체력 %d/5000, 보스 막대 %s" % [b.awake, patterns.size() - 1, hazards, shots, p.hp, main.hud.get_node("BossBar").visible])
	# 쓰러뜨려 본다 (모르가스는 한 번 되살아난다)
	b.take_damage(b.hp + 1)
	await get_tree().process_frame
	if is_instance_valid(b) and not b.remove:
		print("한 번 쓰러뜨림: 되살아남 %s, 체력 %d" % [b.revived, b.hp])
		b.take_damage(b.hp + 1)
	# 쓰러지는 장면(느려짐 · 빛가루)이 끝나야 보상이 떨어진다
	var t1 := Time.get_ticks_msec()
	print("쓰러지는 중: %s, 세상 빠르기 %.2f, 이름패 %s" % [b.dying > 0, Engine.time_scale, Cutscene.card.get("sub", "")])
	while is_instance_valid(b) and not b.remove and Time.get_ticks_msec() - t1 < 8000:
		await get_tree().process_frame
		if OS.get_cmdline_user_args().has("debug") and Engine.get_process_frames() % 30 == 0: print("  dying=%.2f dlg=%s cut=%s ts=%.2f chapter=%s" % [b.dying, GameState.isDialogueOpen, Cutscene.on, Engine.time_scale, Hud.chapter_card_on()])
	for i in 3: await get_tree().process_frame
	print("다시 쓰러뜨림 (%.1f초 뒤): 처치 기록 %s, 숨결 %s, 기술 %s, 유물 %s, 레벨 %d, 빠르기 %.2f" % [(Time.get_ticks_msec() - t1) / 1000.0, GameState.bossesDefeated, p.elements, p.skills, GameState.relics, p.level, Engine.time_scale])
	get_tree().quit()
