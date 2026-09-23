extends Node
## 원하는 지도로 옮겨 놓고 화면을 찍는다 (--write-movie 와 함께).
##   godot --path . --write-movie out.png --quit-after 40 tools/shot.tscn -- EAST_ROAD


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] != "VILLAGE": World.travel_to(args[0], main.hud)
