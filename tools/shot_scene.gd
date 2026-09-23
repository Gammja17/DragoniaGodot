extends Node
## 컷씬 연출을 찍는다 (창을 띄워야 그림이 나온다). 인자: 찍을 장면 · 사진을 둘 폴더
##   godot --path . res://tools/shot_scene.tscn -- demo C:/tmp/shots
## 장면: demo(연출 박자 전부) · event:<사건 id> · prologue
## 장면이 흐르는 동안 0.5초마다 한 장씩, 대화창이 뜨면 글이 다 찍힌 뒤 한 장 찍고 넘긴다.

var _dir := ""
var _n := 0
var _box: DialogueBox


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var what: String = args[0] if args.size() > 0 else "demo"
	_dir = args[1] if args.size() > 1 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_dir)
	Save.slot = 9
	Save.delete()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = what == "prologue"
	main.load_save = false
	add_child(main)
	await get_tree().process_frame
	_box = DialogueBox.current
	GameState.elderTutorialDone = true
	GameState.tutorial.finished = true
	var p: Dragon = GameState.player
	if what == "prologue":
		await _film(40.0)
		get_tree().quit()
		return
	await _wait(1.5)
	if what.begins_with("boss:"):
		# 보스 둥지에 들어가 깨운다 → 등장 장면 → 몇 초 싸우다 쓰러뜨려 끝 장면
		GameState.story.events = ["ev_morgath", "ev_zalgora", "ev_glacia", "ev_basil", "ev_ignar"]
		World.travel_to(what.substr(5))
		await _wait(0.5)
		var b: Boss = GameState.entities.bosses[0]
		p.max_hp = 5000; p.hp = 5000
		p.x = b.x; p.y = b.y + 460
		var t0 := Time.get_ticks_msec()
		var shots := 0
		while Time.get_ticks_msec() - t0 < 9000:
			await get_tree().process_frame
			if Time.get_ticks_msec() - t0 > 300 * shots:
				shots += 1
				_shoot("fight")
		b.take_damage(b.hp + 1)
		await get_tree().process_frame
		if not b.remove and b.dying <= 0: b.take_damage(b.hp + 1)
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 4000:
			await _wait(0.25)
			_shoot("finale")
		get_tree().quit()
		return
	if what.begins_with("event:"):
		var id := what.substr(6)
		for ev in Data.get_module("chronicle").CHRONICLE:
			if ev.id == id: Chronicle._fire(ev)
	elif what == "demo":
		var elder = World.any_npc("Elder")
		p.x = elder.x - 200; p.y = elder.y + 40
		await _wait(0.5)
		Chronicle.play_scene("연출 시험", [
			{ who = "나", text = "(광장이 조용하다. 너무 조용하다.)", do = [{ bgm = "none" }, { tone = "dread" }, { cam = [0, -160], zoom = 1.0, time = 1.6 }] },
			{ who = "Poco", text = "저기… 저기! 큰일 났어!", do = [{ cam = "auto" }, { move = "Poco", to = [140, 0] }, { emote = "Poco", icon = "!" }, { shake = 6 }] },
			{ who = "Elder", text = "…무슨 일이냐.", zoom = 1.5, do = [{ emote = "Elder", icon = "…" }] },
			{ who = "Poco", text = "숲에서, 숲에서 연기가…!", do = [{ face = "Poco", to = "right" }, { sfx = "horn" }, { wait = 0.6 }] },
			{ do = [{ fade = "out", time = 0.8, text = "그날 밤" }, { wait = 1.2 }, { tone = "memory" }, { fade = "in", time = 0.8 }] },
			{ who = "나", text = "(모두가 말없이 모닥불만 바라봤다.)", auto = 1.5 },
			{ who = "Elder", text = "…자거라. 내일 얘기하자꾸나.", do = [{ tone = "none" }, { exit = "Poco" }] },
		])
	await _film(40.0)
	get_tree().quit()


## 장면이 끝날 때까지 찍으며 넘긴다
func _film(limit: float) -> void:
	var t0 := Time.get_ticks_msec()
	var last_shot := 0
	var started := false
	while Time.get_ticks_msec() - t0 < limit * 1000:
		await get_tree().process_frame
		var busy: bool = Cutscene.on or GameState.prologue != null or DialogueBox.is_open()
		if busy: started = true
		elif started:
			await _wait(1.0)
			_shoot("end")
			return
		if DialogueBox.is_open():
			if _box.typing(): continue
			await _wait(0.25)
			_shoot("line")
			await _wait(0.2)
			if DialogueBox.is_open() and not _box.typing(): _box._choose(0)
		elif Time.get_ticks_msec() - last_shot > 500:
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
