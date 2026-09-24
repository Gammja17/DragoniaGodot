extends Node
## 습격이 벌어지고 마을 용들이 맞서 싸우는지, 스킬이 나가는지 본다.
##   godot --headless --path . tools/test_raid.tscn


func _ready() -> void:
	Save.slot = 9   # 시험은 9번 칸을 쓴다 (20초마다 저장하는데, 칸을 안 정하면 사람이 쓰는 1번 칸을 덮는다)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	await get_tree().process_frame
	var p: Dragon = GameState.player
	p.max_hp = 3000; p.hp = 3000
	for id in ["TAIL_SWIPE", "METEOR", "ROAR"]: Skills.learn(id, true)
	print("장착: ", p.slots)
	Raid.trigger()
	print("습격 %d차: 사냥꾼 %d명 %s" % [GameState.raid.count, GameState.entities.humans.size(), GameState.entities.humans.map(func(h): return h.type)])
	var t0 := Time.get_ticks_msec()
	var npc_shots := 0
	var cast := false
	while Time.get_ticks_msec() - t0 < 25000 and GameState.raid.active:
		await get_tree().process_frame
		npc_shots = maxi(npc_shots, GameState.entities.bullets.filter(func(b): return b.faction == "ALLY" and not b.from_player).size())
		# 사냥꾼 쪽으로 다가가 기술을 쓴다
		var hs: Array = GameState.entities.humans
		if hs.is_empty(): continue
		var h = hs[0]
		p.x = h.x - 150; p.y = h.y
		if not cast and Util.dist(p, h) < 400:
			for slot in ["Q", "F", "R"]: Skills.use_slot(p, slot)
			cast = true
		if Engine.get_process_frames() % 20 == 0:
			for slot in ["Q", "F", "R"]: Skills.use_slot(p, slot)
	print("%.1f초 뒤: 습격 중 %s, 남은 사냥꾼 %d, 마을 용이 쏜 탄 최대 %d, 쓰러진 사냥꾼 %d, 금화 %d, 대기 %s" % [
		(Time.get_ticks_msec() - t0) / 1000.0, GameState.raid.active, GameState.entities.humans.size(), npc_shots,
		GameState.stats.kills.get("HUNTER", 0), p.gold, p.cooldowns])
	get_tree().quit()
