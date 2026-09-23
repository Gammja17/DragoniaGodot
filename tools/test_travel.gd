extends Node
## 포탈로 지도를 오가는지 본다.
##   godot --headless --path . tools/test_travel.tscn


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	await get_tree().process_frame
	var p: Dragon = GameState.player
	var alive := 0
	for pr in GameState.entities.props: if is_instance_valid(pr): alive += 1
	print("시작: ", GameState.map_id, " 소품 ", GameState.entities.props.size(), " 살아 있는 것 ", alive, " 방문 ", GameState.visited)
	for side in ["E", "W", "S"]:
		var gate = null
		for pr in GameState.entities.props:
			if pr.portal and pr.portal.side == side: gate = pr
		var to: String = gate.portal.to
		p.x = gate.x; p.y = gate.y
		for i in 3: await get_tree().process_frame
		print("%s 문(%s)을 밟음 → 지금 %s, 선 자리 (%d, %d), 방문 %s" % [side, to, GameState.map_id, p.x, p.y, GameState.visited])
		if GameState.map_id != "VILLAGE":
			# 돌아오는 문을 밟는다
			await get_tree().create_timer(0.4).timeout
			var back = null
			for pr in GameState.entities.props:
				if pr.portal and pr.portal.to == "VILLAGE": back = pr
			p.x = back.x; p.y = back.y
			for i in 3: await get_tree().process_frame
			print("   돌아옴 → %s (%d, %d), 마을 용 %d마리" % [GameState.map_id, p.x, p.y, GameState.entities.npcs.size()])
			await get_tree().create_timer(0.4).timeout
	var toasts: Node = main.hud.get_node("ToastBox")
	for t in toasts.get_children(): print("알림: ", t.get_node("Label").text)
	get_tree().quit()
