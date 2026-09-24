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
	_lair_report(b, "깨기 전")
	p.max_hp = 5000; p.hp = 5000   # 패턴을 오래 보려고 버티게 한다
	if map == "IGNAR_LAIR": p.elements = ["FIRE", "ICE", "THUNDER"]   # 마지막 판의 거울 불을 보려고
	p.x = b.x; p.y = b.y + 400
	var patterns := {}
	var hazards := 0
	var shots := 0
	var near_guard := 0   # 지키는 것(알 벽) 가까이 날아간 적 탄
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 10000:
		await get_tree().process_frame
		_advance()   # 등장 장면의 한마디는 넘긴다
		patterns[b.pattern_index] = true
		hazards = maxi(hazards, GameState.entities.hazards.size())
		shots = maxi(shots, GameState.entities.bullets.filter(func(x): return x.faction == "ENEMY").size())
		if b.guard != null: near_guard += GameState.entities.bullets.filter(func(x): return x.faction == "ENEMY" and Vector2(x.x, x.y).distance_to(b.guard) < 130).size()
		p.x = b.x; p.y = b.y + 400
	print("10초: 깨어남 %s, 쓴 패턴 %d개, 장판 최대 %d, 적 탄 최대 %d, 내 체력 %d/5000, 보스 막대 %s" % [b.awake, patterns.size() - 1, hazards, shots, p.hp, main.hud.get_node("BossBar").visible])
	_lair_report(b, "싸우는 중")
	if b.def.get("bumpSay"):   # 잘고라: 두 머리가 들이받으면 휘청인다
		b._fire("BUMP")
		await get_tree().process_frame
		print("박치기: 빈틈 %s, 자막 %s" % [b.opening, Cutscene.subtitle])
	if b.def.get("spears"):   # 바실: 돌진이 끝나면 창끝이 빛나는 빈틈
		b.charge = { windup = 0.0, time = 0.001, angle = 0.0, chain = 1 }
		for i in 3: await get_tree().process_frame
		print("돌진 끝: 빈틈 %s, 창끝 %d개" % [b.opening, b.def.spears.size()])
	if b.guard != null: print("지키는 것 %s: 그 가까이 날아간 적 탄 %d (0 이어야)" % [b.def.guards, near_guard])
	if b.guard != null:   # 알 벽 가까이 가면 몸으로 막아서 밀어낸다
		p.x = b.guard.x; p.y = b.guard.y + 140
		var d0: float = Vector2(p.x, p.y).distance_to(b.guard)
		var tg := Time.get_ticks_msec()
		var pushed := false
		while Time.get_ticks_msec() - tg < 3000:
			await get_tree().process_frame
			_advance()
			if b.shove > 0: pushed = true
		print("알 벽 가까이: 밀려남 %s, 거리 %d → %d, 자막 %s" % [pushed, int(d0), int(Vector2(p.x, p.y).distance_to(b.guard)), Cutscene.subtitle])
		p.x = b.x; p.y = b.y + 400
	# 쓰러뜨려 본다 (모르가스는 한 번 되살아난다. 뼈가 다시 맞춰지는 동안은 맞지 않는다)
	b.take_damage(b.hp + 1)
	await get_tree().process_frame
	if b.yielding:   # 장면이 있는 판: 한 방에 쓰러뜨려도 그 장면을 거친다
		print("장면 판: 체력 %d, 판 %s" % [b.hp, b.def.phases[b.phase].name])
		var ty := Time.get_ticks_msec()
		var saw_kairon := false
		while b.yielding and b.dying <= 0 and not b.lingering and Time.get_ticks_msec() - ty < 30000:
			await get_tree().process_frame
			if Cutscene.on_stage(World.any_npc("Kairon")) and Cutscene.on: saw_kairon = true
			_advance()
		for i in 30: await get_tree().process_frame   # 장면이 닫히고 잠드는 데까지
		print("장면 끝 (%.1f초): 카이론 %s, 알 벽 앞으로 %s (거리 %d), 잠드는 중 %s, 합류 %s" % [(Time.get_ticks_msec() - ty) / 1000.0, saw_kairon, b.facing == "up", int(Vector2(b.x, b.y).distance_to(b.guard)) if b.guard != null else -1, b.dying > 0 or b.lingering, b.ally != null])
		if b.dying <= 0 and not b.lingering:   # 판 사이 장면(이그나르): 싸움이 이어진다. 마지막 판을 잠깐 보고 쓰러뜨린다
			var els := {}
			var shots_ally := 0
			var tm := Time.get_ticks_msec()
			while Time.get_ticks_msec() - tm < 5000:
				await get_tree().process_frame
				_advance()
				for x in GameState.entities.bullets:
					if x.faction == "ENEMY": els[x.element] = true
					elif x.faction == "ALLY": shots_ally += 1
				p.x = b.x; p.y = b.y + 400
			var kd: int = int(Util.dist(b.ally, p)) if b.ally else -1
			print("마지막 판 %s: 적 탄 속성 %s, 카이론 곁에 %s (거리 %d), 아군 탄 %s, 카이론 상태 %s" % [b.def.phases[b.phase].name, els.keys(), b.ally != null and GameState.entities.npcs.has(b.ally), kd, shots_ally > 0, b.ally.state if b.ally else "-"])
			b.take_damage(b.hp + 1)
			await get_tree().process_frame
			print("무릎: 카이론 공격 멈춤 %s" % [b.ally.passive if b.ally else "-"])
	elif is_instance_valid(b) and not b.remove and b.dying <= 0:   # 되살아난 보스만
		print("한 번 쓰러뜨림: 되살아남 %s, 체력 %d, 다시 일어서는 중 %s (몸 %.2f), 자막 %s" % [b.revived, b.hp, b.rising, b.risen, Cutscene.subtitle])
		var tr := Time.get_ticks_msec()
		while b.rising and Time.get_ticks_msec() - tr < 5000:
			await get_tree().process_frame
		var hp_before: float = b.hp
		print("다시 일어섬 (%.1f초): 몸 %.2f" % [(Time.get_ticks_msec() - tr) / 1000.0, b.risen])
		b.take_damage(b.hp + 1)
		if hp_before == b.hp: print("!! 일어선 뒤에도 맞지 않는다")
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
	_lair_report(b, "보낸 뒤")
	get_tree().quit()


var _last_click := 0
func _advance() -> void:
	if Time.get_ticks_msec() - _last_click < 250: return
	_last_click = Time.get_ticks_msec()
	if Cutscene.busy() and not DialogueBox.is_open(): Cutscene.rush()
	elif DialogueBox.is_open():
		DialogueBox.current._text.visible_characters = -1
		DialogueBox.current._choose(0)


## 결투장의 서리·도깨비불과 뼈 무더기가 보스를 따라 바뀌는지 본다 (모르가스의 무덤)
func _lair_report(b, when: String) -> void:
	var frost: Array = GameState.entities.props.filter(func(q): return q.type == "FROST")
	var wisps: Array = GameState.entities.props.filter(func(q): return q.type == "WISP")
	var walls: Array = GameState.entities.props.filter(func(q): return q.type == "EGG_WALL")
	var marks: Array = GameState.entities.props.filter(func(q): return q.type == "MARK_STONE")
	if not marks.is_empty(): print("[결투장 %s] 무늬 돌 %d개, 빛 %.2f" % [when, marks.size(), BossShow.lair_alpha(marks[0].x, marks[0].y, 1.0)])
	if not walls.is_empty(): print("[결투장 %s] 알 벽의 얼음 %.2f" % [when, BossShow.lair_alpha(walls[0].x, walls[0].y, 1.0)])
	if frost.is_empty() and wisps.is_empty(): return
	var near := 0.0
	var far := 0.0
	if not frost.is_empty():
		var home: Vector2 = Vector2(1008, 624) if not is_instance_valid(b) else b.home
		frost.sort_custom(func(p1, p2): return Vector2(p1.x, p1.y).distance_to(home) < Vector2(p2.x, p2.y).distance_to(home))
		near = BossShow.lair_alpha(frost[0].x, frost[0].y, 0.35, true)
		far = BossShow.lair_alpha(frost[-1].x, frost[-1].y, 0.35, true)
	var wisp: float = BossShow.lair_alpha(wisps[0].x, wisps[0].y, 1.0) if not wisps.is_empty() else -1.0
	print("[결투장 %s] 몸 %s · 서리 %d개 (가까운 곳 %.2f · 먼 곳 %.2f) · 도깨비불 %d개 (%.2f)" % [when, ("%.2f" % b.risen) if is_instance_valid(b) else "-", frost.size(), near, far, wisps.size(), wisp])
