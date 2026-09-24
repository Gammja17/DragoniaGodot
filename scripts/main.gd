extends Node2D
## 2D판 main.js 의 게임 루프. 갱신 순서가 결과를 바꾸는 곳이 많아서
## 노드마다 _process 를 돌리지 않고 여기서 2D판과 같은 순서로 부른다.
## 그리는 순서는 main.tscn 의 노드 순서가 맡는다 (2D판 render() 순서).

const AUTOSAVE_INTERVAL := 20.0   # 초

@onready var terrain: Terrain = $Terrain
@onready var world: Node2D = $World          # y 정렬: 아래쪽 개체가 앞에 온다
@onready var camera: GameCamera = $Camera
@onready var overlay: Overlay = $CrispLayer/Overlay
@onready var cutscene_view: CutsceneView = $CutsceneLayer/CutsceneView
@onready var hud: Hud = $Hud

## 새 게임이면 프롤로그부터 튼다. 시험 장면은 끄고 곧바로 마을에서 시작한다
@export var play_intro := true
## 세이브가 있으면 이어 한다. 시험 장면은 끄고 늘 새 판으로 시작한다
@export var load_save := true

var _save_timer := 0.0


func _ready() -> void:
	World.container = world
	overlay.camera = camera
	$LightLayer/Lighting.camera = camera
	$WeatherLayer/Weather.camera = camera
	overlay.world = world
	cutscene_view.camera = camera
	$Marks.camera = camera
	# 시스템끼리 서로 불러들이지 않게 여기서 이어 준다
	Quests.on_flag = Story.on_flag
	Quests.on_change = hud.refresh_tracker
	Training.install()
	Chores.install()
	Launch.reset_run()
	# 처음 화면(Title)에서 왔으면 거기서 고른 칸과 새 용 설정을 쓴다.
	# main 을 곧바로 띄웠으면(편집기 F6 · 시험 장면) 1번 칸을 이어 하거나 기본 외형의 해츨링으로 시작한다
	var save = null
	var cfg: Dictionary = { name = "용", species = "LOOK", look = 0 }
	if Launch.ready:
		Save.slot = Launch.slot
		if Launch.config: cfg = Launch.config
		else: save = Save.read()
	elif load_save and not OS.get_cmdline_user_args().has("--new-game"):
		save = Save.read()
	if save: cfg = save.player.config
	var elder = World.init_world(cfg)
	if save: Save.apply(save)
	Travel.init_waystones()
	GameState.gameActive = true
	hud.show_game_ui(true)
	hud.to_title_requested.connect(_to_title)
	var p = GameState.player
	camera.cam_x = p.x - camera.w / 2
	camera.cam_y = p.y - camera.h / 2
	# 새 게임이면 떨어지던 밤부터 보여 주고, 그 끝에서 엘더와의 첫 대화로 잇는다
	if not save:
		GameState.story.chapter = "c1"   # 장 카드는 프롤로그 끝에서 직접 띄운다 (Story.update_chapter 가 또 띄우지 않게)
		GameState.story.chapterTitle = "1장"
	if not save and play_intro:
		GameState.quests.active.m0 = { step = 0, n = 0 }   # 첫날의 길잡이
		GameState.quests.tracked = "m0"
		Quests.changed()
		# 떨어지던 밤 → 까만 화면에 "제 1 장 · 웨스턴 마을" → 눈을 뜨고 촌장과 첫 대화
		Skills.later(500, func(): Prologue.start(func(): Hud.show_chapter_card("제1장", "웨스턴 마을", func(): Dialogue.start(elder, "TALK"))))


## 저장하고 처음 화면으로 (다른 기록을 불러오거나 새 용을 만들러)
func _to_title() -> void:
	if not GameState.prologue: Save.save_game()
	GameState.gameActive = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _exit_tree() -> void:
	Quests.reset_hooks()
	World.dispose()


func _notification(what: int) -> void:
	# 창을 닫을 때 한 번 더 저장한다 (2D판 beforeunload)
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not GameState.prologue: Save.save_game()


func _process(delta: float) -> void:
	var real := clampf(delta, 0, 0.1)
	var dt := Feedback.apply_hit_stop(real)   # 맞은 순간 세상이 아주 잠깐 멈춘다
	Feedback.update(real)
	if GameInput.pressed("zoom"): hud.toast("시점: " + camera.cycle_zoom(), "🔍")
	if GameInput.wheel: camera.step_zoom(GameInput.wheel)   # 휠은 조용히 (알림이 정신 사납다고 해서)
	if GameInput.pressed("hideUi") and not GameState.isDialogueOpen: hud.toggle_ui()
	if GameInput.pressed("help") and not GameState.isDialogueOpen: hud.help.toggle()
	if GameInput.pressed("screenFx") and not GameState.isDialogueOpen: hud.fx.toggle()
	if GameInput.pressed("kids") and not GameState.isDialogueOpen: hud.kids.toggle()
	if not GameState.isDialogueOpen:   # 일지의 탭으로 바로 간다
		for k in [["journal", ""], ["skillbook", "skills"], ["growthTab", "growth"], ["worldmap", "map"], ["inventory", "bag"]]:
			if GameInput.pressed(k[0]): hud.journal.toggle_tab(k[1])
	if GameInput.pressed("mute"):
		var muted: bool = not Prefs.get_value("sound", "muted", false)
		Prefs.set_value("sound", "muted", muted)
		hud.toast("소리 끔" if muted else "소리 켬", "🔊")
	# [Esc]: 하던 것부터 닫는다. 닫을 게 없으면 설정 창
	var card_skipped := false
	if GameInput.pressed("cancel") and not NameInput.is_open():
		if Credits.is_rolling():
			Credits.current.skip()
			card_skipped = true
		elif Hud.chapter_card_on():
			Hud.skip_chapter_card()
			card_skipped = true   # 건너뛴 그 Esc 가 바로 열린 대화까지 닫지 않게
		elif GameState.prologue: Prologue.skip()
		elif Den.is_placing(): Den.cancel_placing()
		elif GamePanel.close_top(): pass   # 창 하나 닫음
		elif not GameState.isDialogueOpen and not Cutscene.on: hud.settings.toggle()
	if GameState.isDialogueOpen:
		if GameState.nav: GameState.nav = null   # 대화·장면이 열리면 자동 이동은 거기서 끝난다
		if NameInput.is_open() or Credits.is_rolling() or Hud.fading(): pass   # 이름을 적는 중 · 크레딧 · 화면이 덮인 동안은 건드리지 않는다
		elif GameInput.pressed("cancel") and not card_skipped:
			# 장면이면 끝까지 건너뛴다 (대화창만 닫으면 장면의 끝이 영영 안 불려 사건 시계가 굳는다)
			if not Chronicle.skip_scene():
				Dialogue.close()
		elif Cutscene.busy() and not DialogueBox.is_open():
			# 연출 박자가 도는 동안: [Space]·클릭으로 지금 박자를 곧바로 끝낸다
			if GameInput.pressed("confirm") or GameInput.pressed("interact") or GameInput.mouse_clicked: Cutscene.rush()
		else: DialogueBox.current.handle_keys()   # 방향키 + Space 로 선택
		# 세상은 멈춰 있어도 그림은 흐른다: 폭포·불빛·비, 무대 위 용들의 숨쉬기와 걸음
		GameState.game_time += dt
		Cutscene.animate(dt)
	else:
		_update(dt)
	Cutscene.update(dt)   # 세계가 멈춰 있어도 띠와 어둠은 계속 움직여야 한다
	Prologue.update(dt)

	camera.follow(GameState.player)
	_show_stage()
	_mark_fade_targets()

	_save_timer += dt
	if _save_timer > AUTOSAVE_INTERVAL and not GameState.prologue:   # 프롤로그 도중의 한밤중을 저장하지 않는다
		Save.save_game()
		_save_timer = 0.0


func _update(dt: float) -> void:
	var E: Dictionary = GameState.entities
	GameState.game_time += dt
	GameState.play_time += dt
	var outside: bool = not GameState.dungeon
	if outside:   # 굴 속에서는 마을 습격도, 야생 적의 보충도 없다
		Raid.update(dt)
		Ambush.update(dt)
	var prev_day_time := GameState.dayTime
	NightEvents.update_clock(dt)
	NightEvents.update(dt, prev_day_time)
	Weather.update(dt)
	if GameState.rally > 0: GameState.rally -= dt

	Flow.update(dt)
	RelicOffer.update()
	GameState.player.update(dt)
	# 간발 직후에는 나만 빼고 세상이 느려진다. 내 숨결도 제 빠르기로 나간다
	var wdt := dt * Flow.world_time_scale()
	for group in ["nests", "babies", "items", "npcs", "enemies", "humans", "bosses", "hazards", "bullets", "effects", "particles"]:
		for e in E[group]: e.update(dt if group == "bullets" and e.faction == "ALLY" else wdt)

	Combat.resolve()
	World.prune()
	if outside:
		if Den.in_my_den(): Den.update_place()   # 굴 안: 살림살이 놓기
		else: Spawner.update(dt)
		Travel.update()
		World.update_portals()
		Routine.update(dt, World.get_npc)
		Tour.update(dt)
		Chronicle.update(dt)
		Story.update_bedtime()
		Story.update_chapter()
		Chatter.update(dt)
	Training.update()
	Tutorial.update()
	Achievements.update(dt)


## 컷씬에서는 무대에 오른 이들만 보인다. 적이 화면을 가로지르고 딴 용이 어슬렁대면 장면이 장면 같지 않다
func _show_stage() -> void:
	var E: Dictionary = GameState.entities
	var cut := Cutscene.on
	for group in ["babies", "npcs", "enemies", "humans", "bosses"]:
		for e in E[group]: e.visible = not cut or Cutscene.on_stage(e)
	var p = GameState.player
	p.visible = not cut or Cutscene.on_stage(p)


## 나무 뒤에 가려지면 안 되는 것들 (Prop 이 이 목록을 보고 나무를 투명하게 한다).
## 2D판은 그릴 때 화면 근처 것만 골라 이 목록을 만든다
func _mark_fade_targets() -> void:
	var E: Dictionary = GameState.entities
	var list := []
	var near := func(e) -> bool:
		return e.x + 420 > camera.cam_x and e.x - 420 < camera.cam_x + camera.w \
			and e.y + 420 > camera.cam_y and e.y - 420 < camera.cam_y + camera.h
	for e in E.npcs + E.enemies + E.humans + E.bosses + E.items + [GameState.player]:
		if not e.get("is_hidden") and near.call(e): list.append(e)
	for p in E.props:
		if (p.type == "CHEST" and not p.opened) or (p.type == "BERRY" and p.ripe):
			if near.call(p): list.append(p)
	GameState.fadeTargets = list
