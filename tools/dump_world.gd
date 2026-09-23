extends Node
## 지도를 채운 결과(NPC 자리, 소품 종류별 수)를 찍는다. 2D판과 대조용.
##   godot --headless --path . tools/dump_world.tscn -- VILLAGE LAKE


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	for id in OS.get_cmdline_user_args():
		if id != "VILLAGE": World.travel_to(id, main.hud)
		World._travel_lock = 0
		var E: Dictionary = GameState.entities
		var npcs := []
		for n in E.npcs: npcs.append("%s@%d,%d" % [n.config.get("name"), roundi(n.home_x), roundi(n.home_y)])
		var types := {}
		for p in E.props: types[p.type] = types.get(p.type, 0) + 1
		print(id, " npcs=", npcs, " props=", E.props.size(), " ", types)
	get_tree().quit()
