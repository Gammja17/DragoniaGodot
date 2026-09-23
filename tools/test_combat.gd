extends Node
## 싸움이 도는지 본다. 숲길에서 슬라임을 세워 두고 마우스로 겨눠 쏜다.
##   godot --headless --path . tools/test_combat.tscn


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	World.travel_to("EAST_ROAD")
	var p: Dragon = GameState.player
	await get_tree().process_frame
	# 들판에 저절로 나온 적
	var types := {}
	for e in GameState.entities.enemies: types[e.type] = types.get(e.type, 0) + 1
	print("숲길에 나온 적: ", types)
	# 바로 앞에 슬라임 셋을 세우고 겨눈다
	for i in 3:
		var s := Enemy.make(p.x + 200 + i * 30, p.y - 20 + i * 20, "SLIME")
		World.add_entity("enemies", s)
	var target: Enemy = GameState.entities.enemies[-1]
	var hp0 := p.hp
	var xp0 := p.xp
	GameInput.mouse_inside = true
	GameInput.mouse_down = true
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000:
		var alive: Array = GameState.entities.enemies.filter(func(e): return e.type == "SLIME" and Util.dist(e, p) < 600)
		if alive.is_empty(): break
		var a = alive[0]
		GameInput.mouse_pos = (Vector2(a.x, a.y - 20) - GameCamera.current.position) * GameCamera.current.zoom.x
		await get_tree().process_frame
	GameInput.mouse_down = false
	var left: int = GameState.entities.enemies.filter(func(e): return e.type == "SLIME" and Util.dist(e, p) < 600).size()
	var items := {}
	for it in GameState.entities.items: items[it.type] = items.get(it.type, 0) + 1
	print("쏜 뒤: 남은 슬라임 %d, 잡은 수 %s, 경험치 %.0f → %.0f, 떨어진 것 %s, 기세 %.0f" % [left, GameState.stats.kills, xp0, p.xp, items, Flow.momentum()])
	# 가만히 서서 슬라임에게 맞아 본다
	var s2 := Enemy.make(p.x + 60, p.y, "SLIME")
	World.add_entity("enemies", s2)
	s2.aggro = true
	for i in 180: await get_tree().process_frame
	print("슬라임 곁에 3초: 체력 %.0f → %.0f (한 방 8)" % [hp0, p.hp])
	get_tree().quit()
