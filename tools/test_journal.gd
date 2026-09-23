extends Node
## 일지: 탭마다 그려지는지, 성장 마디 찍기 · 스킬 장착과 강화 · 유물 끼우고 빼기 · 퀘스트 추적이 되는지.
##   godot --headless --path . res://tools/test_journal.tscn

func _ready() -> void:
	Save.slot = 9
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	for i in 5: await get_tree().process_frame
	var j: JournalPanel = Hud.current.journal
	var p = GameState.player
	p.stage_index = 2
	for i in 5: p.gain_xp(p.max_xp - p.xp)
	for id in ["TAIL_SWIPE", "METEOR"]: Skills.learn(id, true)
	for id in Relics.table().keys().slice(0, 4): Relics.grant(id, p.x, p.y)
	GameState.quests.active.m0 = { step = 2, n = 0 }
	for t in ["quests", "map", "bag", "folk", "skills", "growth", "relics", "codex", "record", "sound"]:
		j.toggle_tab(t)
		await get_tree().process_frame
		print("[%s] 보임=%s 목록 %d줄" % [t, j.visible, j._list.get_child_count()])
	# 성장: 날카로운 이빨(FANG1) 한 단
	var pts: int = GameState.growth.points
	j.toggle_tab("growth")
	j._tree.node_picked.emit(Data.get_module("growth").NODES_BY_ID.FANG1)
	await get_tree().process_frame
	var btn: Button = j.get_node("Frame/Lines/Body/Detail/Actions").get_child(0)
	print("[성장 마디] 단추=%s" % btn.text)
	btn.pressed.emit()
	await get_tree().process_frame
	print("[성장 마디] FANG1 %d단, 포인트 %d → %d" % [Growth.node_rank("FANG1"), pts, GameState.growth.points])
	# 스킬: 운석 낙하를 [Q] 에 끼우고 한 단 올린다
	j.toggle_tab("skills")
	j._tree.node_picked.emit("METEOR")
	await get_tree().process_frame
	var acts := j.get_node("Frame/Lines/Body/Detail/Actions").get_children().filter(func(c): return c is Button)
	print("[스킬] 단추들=%s" % [acts.map(func(b): return b.text)])
	acts[0].pressed.emit()
	await get_tree().process_frame
	print("[스킬] Q=%s" % p.slots.Q)
	acts = j.get_node("Frame/Lines/Body/Detail/Actions").get_children().filter(func(c): return c is Button and c.text.begins_with("강화"))
	if not acts.is_empty(): acts[0].pressed.emit()
	await get_tree().process_frame
	print("[스킬] 운석 %d단" % Skills.rank("METEOR"))
	# 유물: 끼운 첫 유물을 뺐다가 다시
	var first: String = Relics.equipped()[0]
	Relics.toggle(first)
	print("[유물] 빼기 → 끼움 %s" % Relics.has(first))
	Relics.toggle(first)
	print("[유물] 끼우기 → 끼움 %s" % Relics.has(first))
	# 퀘스트 추적
	j.toggle_tab("quests")
	await get_tree().process_frame
	for c in j._list.get_children():
		if c is QuestRow:
			c.get_node("Lines/Head").pressed.emit()
			break
	await get_tree().process_frame
	for c in j._list.get_children():
		if c is QuestRow and c.get_node("Lines/Body").visible:
			c.get_node("Lines/Body/Lines/Track").pressed.emit()
			break
	await get_tree().process_frame
	print("[퀘스트] 추적=%s, 추적창=%s" % [GameState.quests.tracked, Hud.current.right.quest.get_node("Lines/Title").text])
	# Esc 로 닫힌다
	print("[Esc] 닫음=%s 보임=%s" % [GamePanel.close_top(), j.visible])
	get_tree().quit()
