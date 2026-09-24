extends Node
## 보스 결투장을 찍는다 (창을 띄워야 그림이 나온다). 인자: 결투장 지도 · 사진을 둘 폴더
##   godot --path . res://tools/shot_boss.tscn -- MORGATH_LAIR C:/tmp/shots [quick]
## quick 을 붙이면 잠든 결투장 한 장만 찍고 끝낸다 (소품·그림 확인용)
## 잠든 결투장 → 등장 장면(줄마다 한 장) → 싸움 → 되살아남(있으면) → 쓰러짐과 그 뒤 순서로 찍는다.

var _dir := ""
var _n := 0
var _box: DialogueBox


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var map: String = args[0] if args.size() > 0 else "MORGATH_LAIR"
	_dir = args[1] if args.size() > 1 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_dir)
	Save.slot = 9
	Save.delete()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	await get_tree().process_frame
	_box = DialogueBox.current
	GameState.elderTutorialDone = true
	GameState.tutorial.finished = true
	GameState.story.events = ["ev_morgath", "ev_zalgora", "ev_glacia", "ev_basil", "ev_ignar"]   # 사건을 겪은 뒤라야 둥지에 보스가 있다
	World.travel_to(map)
	await _wait(1.0)
	var p: Dragon = GameState.player
	var b: Boss = GameState.entities.bosses[0]
	p.max_hp = 5000; p.hp = 5000
	# 1) 잠든 결투장: 깨우지 않을 만큼 떨어져서
	p.x = b.x; p.y = b.y + 640
	await _wait(1.2)
	_shoot("lair")
	if args.size() > 2 and args[2] == "quick":
		await _wait(0.5)
		get_tree().quit()
		return
	# 2) 다가가 깨운다 → 등장 장면
	p.y = b.y + 460
	await _film(40.0)
	# 3) 싸움: 몇 초 동안
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000:
		await _wait(0.5)
		p.x = b.x + sin(Time.get_ticks_msec() / 700.0) * 260; p.y = b.y + 380
		_shoot("fight")
	# 4) 한 번 쓰러뜨린다 (되살아나는 보스는 여기서 다시 맞춰진다)
	b.take_damage(b.hp + 1)
	if b.yielding: await _film(40.0)   # 장면으로 끝나는 보스 (글라시아): 멈춤 장면을 줄마다 찍는다
	var t1 := Time.get_ticks_msec()
	while is_instance_valid(b) and (b.rising or b.dying > 0) and Time.get_ticks_msec() - t1 < 15000:   # 찍는 동안은 프레임이 느려 게임 시간이 더디 간다
		await _wait(0.3)
		_shoot("revive" if b.rising else "finale")
	# 5) 끝: 쓰러짐과 그 뒤 (서리가 녹는다)
	if is_instance_valid(b) and not b.remove and b.dying <= 0 and not b.lingering: b.take_damage(b.hp + 1)
	var t2 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t2 < 7000:
		await _wait(0.5)
		if DialogueBox.is_open() and not _box.typing(): _box._choose(0)
		_shoot("after")
	get_tree().quit()


## 장면이 끝날 때까지 찍으며 넘긴다 (줄마다 글이 다 찍힌 뒤 한 장)
func _film(limit: float) -> void:
	var t0 := Time.get_ticks_msec()
	var last_shot := 0
	var started := false
	while Time.get_ticks_msec() - t0 < limit * 1000:
		await get_tree().process_frame
		var busy: bool = Cutscene.on or DialogueBox.is_open()
		if busy: started = true
		elif started:
			await _wait(0.6)
			_shoot("start")
			return
		if DialogueBox.is_open():
			if _box.typing(): continue
			await _wait(0.25)
			_shoot("line")
			await _wait(0.2)
			if DialogueBox.is_open() and not _box.typing(): _box._choose(0)
		elif Time.get_ticks_msec() - last_shot > 400:
			last_shot = Time.get_ticks_msec()
			_shoot("beat")


func _shoot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%03d_%s.png" % [_dir, _n, tag])
	_n += 1


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000: await get_tree().process_frame
