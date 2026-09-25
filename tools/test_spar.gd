extends Node
## 대련에서 내 숨결과 스킬이 상대에게 실제로 닿는지 본다 (티아맷 SPAR · 카이론 DUEL).
## 기력을 코드로 0 으로 만들지 않는다. 마우스로 겨눠 쏜 탄이 깎아서 이겨야 한다.
## 줄마다 [대련] OK/FAIL 을 찍고, 끝에 실패 수를 센다. 저장은 9번 칸만 쓴다.
##   godot --headless --path . res://tools/test_spar.tscn

var _fails := 0


func _ok(label: String, cond: bool) -> void:
	print("[대련] %s %s" % ["OK" if cond else "FAIL", label])
	if not cond: _fails += 1


func _ready() -> void:
	Save.slot = 9
	Save.delete()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	await get_tree().process_frame
	var G := GameState
	G.elderTutorialDone = true
	G.tutorial.finished = true
	G.raidTimer = 99999
	var p: Dragon = G.player
	p.max_hp = 5000.0; p.hp = 5000.0

	# 1) 티아맷: 수련장으로 옮겨 가서 숨결만으로 이긴다
	var tia = World.any_npc("Tiamat")
	NpcActions._go_spar(tia)
	var t0 := Time.get_ticks_msec()
	while G.activity == null and Time.get_ticks_msec() - t0 < 5000: await get_tree().process_frame
	_ok("수련장에서 대련이 시작된다", G.activity != null and G.activity.type == "SPAR" and G.map_id == "DOJO")
	var gold0 := p.gold
	var low := await _shoot_until_done(tia, 30000)
	_ok("숨결이 티아맷의 기력을 깎는다 (가장 낮을 때 %.0f / %.0f)" % [low, NpcActions.SPAR_HP], low < NpcActions.SPAR_HP)
	_ok("기력을 다 깎으면 이긴다", G.activity == null and p.gold > gold0)
	_ok("판이 끝나면 티아맷의 상태 이상이 털린다", tia.status.is_empty())

	# 2) 카이론: 연습 대련. 꼬리 휘두르기가 닿고, 기절은 짧고, 숨결로 끝까지 깎는다
	var kai = World.any_npc("Kairon")
	var xp0 := p.xp
	Story.start_drill(kai, { type = "DUEL", hp = 220 + p.level * 12 }, { practice = true })
	await get_tree().process_frame
	var a: Dictionary = G.activity
	kai.x = p.x + 120; kai.y = p.y
	var hp0: float = a.hp
	Skills.cast("TAIL_SWIPE", p, 1.0)
	_ok("꼬리 휘두르기가 카이론에게 닿는다 (%.0f → %.0f)" % [hp0, a.hp], a.hp < hp0)
	Status.apply(kai, "STUN", 1.2)
	_ok("대련 상대는 보스처럼 기절이 짧다 (%.2f초)" % kai.status.STUN, absf(kai.status.STUN - 0.42) < 0.01)
	var sx: float = kai.x
	var sy: float = kai.y
	for i in 5: await get_tree().process_frame
	_ok("기절한 동안은 제자리에 선다", kai.x == sx and kai.y == sy and not kai.moving)
	var burned := false
	t0 = Time.get_ticks_msec()
	while G.activity != null and Time.get_ticks_msec() - t0 < 40000:
		_aim_at(kai)
		if kai.status.get("BURN", 0) > 0: burned = true
		p.hp = p.max_hp
		await get_tree().process_frame
	GameInput.mouse_down = false
	print("  카이론 대련: %.1f초" % ((Time.get_ticks_msec() - t0) / 1000.0))
	_ok("불 숨결을 맞은 카이론이 불붙는다", burned)
	_ok("연습 대련을 숨결로 이긴다 (경험치 %.0f → %.0f)" % [xp0, p.xp], G.activity == null and p.xp > xp0)
	_ok("판이 끝나면 카이론의 상태 이상이 털린다", kai.status.is_empty())

	print("[끝] 실패 %d" % _fails)
	get_tree().quit(1 if _fails else 0)


## 상대를 마우스로 겨눠 계속 쏜다. 판이 끝나거나 시간이 다 되면 멈추고, 그동안 가장 낮았던 기력을 돌려준다
func _shoot_until_done(npc, ms: int) -> float:
	var G := GameState
	var p: Dragon = G.player
	var low: float = G.activity.hp
	var t0 := Time.get_ticks_msec()
	while G.activity != null and Time.get_ticks_msec() - t0 < ms:
		_aim_at(npc)
		low = minf(low, G.activity.hp)
		p.hp = p.max_hp
		await get_tree().process_frame
	GameInput.mouse_down = false
	print("  티아맷 대련: %.1f초" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return low


## 사람이 하듯 상대를 가리키고 쏜다 (앞질러 겨누지 않는다)
func _aim_at(npc) -> void:
	GameInput.mouse_inside = true
	GameInput.mouse_down = true
	GameInput.mouse_pos = (Vector2(npc.x, npc.y - 20) - GameCamera.current.position) * GameCamera.current.zoom.x
