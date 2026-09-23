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
		_advance()   # 등장 장면의 한마디는 넘긴다
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
	# 쓰러지는 순간 보상을 받는다. 무너진 뒤에는 흐릿하게 남았다가(이그나르는 무릎을 꿇은 채) 흩어진다
	var t1 := Time.get_ticks_msec()
	print("쓰러지는 중: %s, 세상 빠르기 %.2f, 이름패 %s · 보상 숨결 %s 유물 %s" % [b.dying > 0, Engine.time_scale, Cutscene.card.get("sub", ""), p.elements, GameState.relics])
	while is_instance_valid(b) and b.dying > 0 and Time.get_ticks_msec() - t1 < 8000:
		await get_tree().process_frame
	print("무너짐 끝 (%.1f초): 남음 %s, 흩어짐 %s, 빠르기 %.2f" % [(Time.get_ticks_msec() - t1) / 1000.0, b.lingering, b.remove, Engine.time_scale])
	var t2 := Time.get_ticks_msec()
	while is_instance_valid(b) and not b.remove and Time.get_ticks_msec() - t2 < 12000:
		await get_tree().process_frame
		_advance()   # 작별 장면을 넘긴다
	for i in 3: await get_tree().process_frame
	print("끝 (%.1f초 뒤): 처치 기록 %s, 숨결 %s, 기술 %s, 유물 %s, 레벨 %d, 남은 보스 %s, 퀘스트 장면 %d" % [(Time.get_ticks_msec() - t1) / 1000.0, GameState.bossesDefeated, p.elements, p.skills, GameState.relics, p.level,
		"무릎 꿇음" if is_instance_valid(b) and b.lingering else "없음", GameState.questScenes.size()])
	get_tree().quit()


var _last_click := 0
func _advance() -> void:
	if Time.get_ticks_msec() - _last_click < 250: return
	_last_click = Time.get_ticks_msec()
	if Cutscene.busy() and not DialogueBox.is_open(): Cutscene.rush()
	elif DialogueBox.is_open():
		DialogueBox.current._text.visible_characters = -1
		DialogueBox.current._choose(0)
