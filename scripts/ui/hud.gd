class_name Hud
extends CanvasLayer
## 2D판 ui/hud.js · ui/toast.js · ui/questBanner.js 가운데 지금 쓰는 것:
## 지역 이름 배너, 알림, 퀘스트 배너, 보스 체력바, 습격 경고, 화면 가리기, 장 카드, 장면 제목, 대화창.
## 모양은 scenes/ui/hud.tscn 과 그 안의 씬들에 있고, 여기서는 띄우고 움직이기만 한다.

const TOAST_SCENE := preload("res://scenes/ui/toast.tscn")
const MAX_TOASTS := 4

@onready var _banner: Control = $RegionBanner
@onready var _region_name: Label = $RegionBanner/Name
@onready var _region_sub: Label = $RegionBanner/Sub
@onready var _toasts: VBoxContainer = $ToastBox

@onready var _boss_bar: Control = $BossBar
@onready var _boss_name: Label = $BossBar/Name
@onready var _boss_track: Control = $BossBar/Track
@onready var _boss_fill: Control = $BossBar/Track/Fill

@onready var _raid: Label = $RaidWarning

# 상태판 · 오른쪽 기둥 · 기술 칸 (5단계)
@onready var status: HudStatus = $Status
@onready var right: HudRight = $Right
@onready var bottom: HudBottom = $Bottom
@onready var settings: SettingsPanel = $Settings
@onready var help: GamePanel = $Help
@onready var fx: FxPanel = $Fx
@onready var journal: JournalPanel = $Journal
@onready var kids: KidsPanel = $Kids
@onready var touch: TouchLayer = $Touch

## 설정의 [저장하고 처음 화면으로] (main 이 받는다)
signal to_title_requested
var _refresh_t := 0.0

var _banner_tween: Tween
var _boss_ratio := 1.0
var _raid_until := 0
var _qb_queue := []
var _qb_until := 0
var _chapter_tween: Tween
var _chapter_done = null

static var current: Hud


## 어디서든 알림을 띄운다 (2D판 showToast)
static func pop(msg: String, icon := "✨") -> void:
	if current: current.toast(msg, icon)


func _ready() -> void:
	current = self
	_banner.modulate.a = 0
	status.collapse_pressed.connect(func(): collapse_status(true))
	$ShowStatus.pressed.connect(func(): collapse_status(false))
	right.collapse_pressed.connect(func(): collapse_right(true))
	$ShowRight.pressed.connect(func(): collapse_right(false))
	settings.help_pressed.connect(help.open)
	settings.fx_pressed.connect(fx.open)
	status.growth_pressed.connect(func(): journal.toggle_tab("growth"))
	status.family_pressed.connect(kids.toggle)
	touch.settings_pressed.connect(settings.toggle)
	get_viewport().size_changed.connect(_fit_screen)
	_fit_screen()
	settings.to_title_pressed.connect(func(): to_title_requested.emit())
	$HelpChip.visible = false


## 게임이 시작되면 보인다 (시작 화면에서는 감춘다)
func show_game_ui(on: bool) -> void:
	for n in [status, right, bottom, $HelpChip]: n.visible = on
	if on: refresh_tracker()


## 작은 화면(폰 가로)에서는 좌우 판을 줄인다 (2D판 @media max-width 900 · max-height 540).
## UI 는 UiScale 이 이미 화면에 맞춰 늘려 두었으니, 논리 크기가 휴대폰 기준(780×420)쯤일 때만
func _fit_screen() -> void:
	var s := get_viewport().get_visible_rect().size
	var small := s.x <= 820 or s.y <= 440
	status.scale = Vector2.ONE * (0.72 if small else 1.0)
	status.position = Vector2(6, 6) if small else Vector2(18, 18)
	right.scale = Vector2.ONE * (0.7 if small else 1.0)
	right.pivot_offset = Vector2(right.size.x, 0)


## 왼쪽 판(상태)을 접거나 편다
func collapse_status(on: bool) -> void:
	status.visible = not on
	$ShowStatus.visible = on


## 오른쪽 기둥(지도·길잡이·퀘스트)을 접거나 편다
func collapse_right(on: bool) -> void:
	right.visible = not on
	$ShowRight.visible = on


## [U]: 둘 다 켜져 있으면 둘 다 접고, 하나라도 접혀 있으면 둘 다 편다
func toggle_ui() -> void:
	var any_hidden := not status.visible or not right.visible
	collapse_status(not any_hidden)
	collapse_right(not any_hidden)


## 퀘스트가 바뀌면 추적창을 다시 채운다 (Quests.on_change)
func refresh_tracker() -> void:
	right.quest.refresh()
	journal.refresh()


## 지도를 옮기면 지역 이름을 위쪽에 잠깐 띄웠다 지운다 (2.8초).
## 글자 사이가 벌어졌다 모이고, 사라질 때 다시 조금 벌어진다
func show_region_banner(name_text: String, sub := "") -> void:
	_region_name.text = name_text
	_region_sub.text = sub
	GameState.bannerUntil = GameState.game_time + 3   # 이 동안은 사건 컷씬을 띄우지 않는다
	var spacing: FontVariation = _region_name.label_settings.font
	if _banner_tween: _banner_tween.kill()
	_banner.modulate.a = 0
	_banner.position.y = _banner_top() - 14
	spacing.spacing_glyph = 10
	var t := create_tween()
	_banner_tween = t
	# 0% → 14%: 떨어지며 나타나고 글자 사이가 10 → 4
	t.set_parallel(true).set_ease(Tween.EASE_OUT)
	t.tween_property(_banner, "modulate:a", 1.0, 0.39)
	t.tween_property(_banner, "position:y", _banner_top(), 0.39)
	t.tween_property(spacing, "spacing_glyph", 4, 0.39)
	# 78% → 100%: 사라지며 4 → 7
	t.chain().tween_interval(1.79)
	t.chain().set_parallel(true).tween_property(_banner, "modulate:a", 0.0, 0.62)
	t.tween_property(spacing, "spacing_glyph", 7, 0.62)


func _banner_top() -> float:
	return get_viewport().get_visible_rect().size.y * 0.12


# ---------- 퀘스트 배너 ----------
# 토스트는 쌓이다 사라져서, 이야기가 시작되거나 끝난 걸 놓치기 쉬웠다. 화면 가운데 위에 큼직하게 한 번 띄운다.
# 대화·컷씬 중이면 기다렸다가 조용해진 뒤에 띄운다

## kind: '새 이야기' | '다음 할 일' | '이야기 완료' | '다음에 할 만한 일'
static func quest_banner(kind: String, title: String, goal := "") -> void:
	if current: current._qb_queue.append({ kind = kind, title = title, goal = goal })


func _flush_quest_banner() -> void:
	if _qb_queue.is_empty() or GameState.isDialogueOpen or Cutscene.on or GameState.prologue: return
	if Time.get_ticks_msec() < _qb_until: return   # 하나 끝나면 다음 것
	var b: Dictionary = _qb_queue.pop_front()
	var qb: Control = $QuestBanner
	var kind: Label = qb.get_node("Bg/Lines/Kind")
	var title: Label = qb.get_node("Bg/Lines/Title")
	kind.text = b.kind
	title.text = b.title
	qb.get_node("Bg/Lines/Goal").text = b.goal
	var done: bool = b.kind == "이야기 완료"
	var line_col := Color("#7dd36a") if done else Color("#d8b25a")
	kind.label_settings.font_color = Color("#7dd36a") if done else Color("#ffd84a")
	qb.get_node("Bg/RuleTop").color = Color(line_col, 0.8)
	qb.get_node("Bg/RuleBottom").color = Color(line_col, 0.8)
	var vw := get_viewport().get_visible_rect().size.x
	var w := minf(maxf(minf(420, vw * 0.8), title.get_minimum_size().x + 52), vw * 0.9)
	qb.get_node("Bg").offset_left = -w / 2
	qb.get_node("Bg").offset_right = w / 2
	Sfx.play("level" if done else "quest")
	_qb_until = Time.get_ticks_msec() + 3600
	# 0% → 10% 나타나며 내려앉고, 82% 까지 머물다 사라진다 (3.6초)
	qb.modulate.a = 0
	qb.position.y = -10
	var t := qb.create_tween().set_parallel(true)
	t.tween_property(qb, "modulate:a", 1.0, 0.36)
	t.tween_property(qb, "position:y", 0.0, 0.36)
	t.chain().tween_interval(2.59)
	t.chain().tween_property(qb, "modulate:a", 0.0, 0.65)


# ---------- 화면 가리기 ----------
## 화면을 어둡게 했다가(가운데 글자) 다시 밝힌다. mid: 완전히 어두워졌을 때, done: 다시 밝아진 뒤
static func fade_screen(text: String, mid: Callable, done: Callable) -> void:
	var f: ColorRect = current.get_node("FadeScreen")
	f.get_node("Text").text = text
	f.visible = true
	GameState.isDialogueOpen = true   # 자는 동안 게임을 멈춘다
	var t := f.create_tween()
	t.tween_property(f, "modulate:a", 1.0, 0.9)
	t.tween_interval(0.1)
	t.tween_callback(mid)
	t.tween_interval(1.3)
	t.tween_callback(func(): GameState.isDialogueOpen = false)
	t.tween_property(f, "modulate:a", 0.0, 0.9)
	t.tween_callback(func():
		f.visible = false
		done.call())


# ---------- 장 카드 ----------
## 장이 넘어갈 때 까만 화면에 "제 1 장 · 웨스턴 마을" 을 띄운다. 그동안 세상은 멈춘다. done: 다시 밝아진 뒤
static func show_chapter_card(no: String, name_text: String, done = null) -> void:
	var c: ColorRect = current.get_node("ChapterCard")
	c.get_node("Lines/No").text = no
	c.get_node("Lines/Name").text = name_text
	c.visible = true
	GameState.isDialogueOpen = true
	GameState.bannerUntil = GameState.game_time + 6   # 장 이름이 떠 있는 동안은 사건 컷씬을 띄우지 않는다
	current._chapter_done = done
	Sfx.play("quest")
	var lines := [c.get_node("Lines/No"), c.get_node("Lines/Rule"), c.get_node("Lines/Name")]
	for l in lines: l.modulate.a = 0
	var t := c.create_tween()
	current._chapter_tween = t
	t.tween_property(c, "modulate:a", 1.0, 0.9)
	t.tween_interval(2.5)
	t.tween_property(c, "modulate:a", 0.0, 0.9)
	t.tween_callback(current._end_chapter_card)
	# 글자들은 1.4초에 걸쳐 떠오른다 (이름만 0.35초 늦게)
	var tl := c.create_tween().set_parallel(true)
	tl.tween_property(lines[0], "modulate:a", 1.0, 1.4)
	tl.tween_property(lines[1], "modulate:a", 1.0, 1.4)
	tl.tween_property(lines[2], "modulate:a", 1.0, 1.4).set_delay(0.35)


static func chapter_card_on() -> bool:
	return current != null and current.get_node("ChapterCard").visible


## [Esc]·클릭으로 건너뛴다
static func skip_chapter_card() -> void:
	if not chapter_card_on(): return
	current._chapter_tween.kill()
	current._end_chapter_card()


func _end_chapter_card() -> void:
	var c: ColorRect = $ChapterCard
	c.visible = false
	c.modulate.a = 0
	GameState.isDialogueOpen = false
	var d = _chapter_done
	_chapter_done = null
	if d: d.call()


# ---------- 장면 제목 (컷씬이 시작될 때 가운데에 한 번) ----------
static func scene_title(text: String) -> void:
	var l: Label = current.get_node("SceneTitle")
	if text != "": l.text = text
	l.create_tween().tween_property(l, "modulate:a", 1.0 if text != "" else 0.0, 0.5)


## 보스 체력바. name 이 null 이면 감춘다. 너비는 0.15초에 걸쳐 따라간다 (2D판 transition)
func set_boss_bar(name_text, ratio := 0.0) -> void:
	if name_text == null:
		_boss_bar.visible = false
		return
	_boss_bar.visible = true
	_boss_name.text = name_text
	_boss_ratio = maxf(0, ratio)


## 눈앞에서 할 수 있는 일 (말 걸기 · 줍기 · 석비 …). 그 대상 머리 위에 붙는다. target 이 null 이면 감춘다
static var _tip_target = null
func set_interact(target, text := "") -> void:
	_tip_target = target
	var tip: Label = $InteractTip
	tip.visible = target != null and not DialogueBox.is_open() and not Cutscene.on
	if tip.visible and tip.text != text:
		tip.text = text
		tip.reset_size()


func _place_tip() -> void:
	var tip: Label = $InteractTip
	# 대화창·장면이 뜨면 플레이어 갱신이 멈춰 안내가 그대로 남는다. 여기서 걷는다
	if tip.visible and (GameState.isDialogueOpen or Cutscene.on or _tip_target == null or not is_instance_valid(_tip_target)):
		tip.visible = false
		_tip_target = null
	if not tip.visible: return
	var cam := GameCamera.current
	var z: float = cam.zoom.x
	var s := Vector2((_tip_target.x - cam.cam_x) * z, (_tip_target.y - cam.cam_y) * z - 60)
	tip.position = (s - Vector2(tip.size.x / 2, tip.size.y)).round()   # 2D판 translate(-50%, -100%)


## 화면 아래 가운데의 안내 한 줄 (굴 꾸미기에서 놓을 자리를 고르는 동안). 빈 글이면 감춘다
func set_hint(text: String) -> void:
	$Hint.text = text
	$Hint.visible = text != ""


## 습격 경고. 3.5초 동안 크게 떨며 떠 있다
func show_raid_warning(text: String) -> void:
	_raid.text = text
	_raid.visible = true
	_raid_until = Time.get_ticks_msec() + 3500


func _process(dt: float) -> void:
	# 판의 숫자는 0.1초마다 (2D판 hudAccumulator)
	_refresh_t -= dt
	if _refresh_t <= 0 and GameState.player and status.get_parent():
		_refresh_t = 0.1
		if status.visible: status.refresh()
		if right.visible: right.refresh()
		if bottom.visible: bottom.refresh()
	_flush_quest_banner()
	_place_tip()
	# 터치에서는 Q·F·R·X 가 단추로 있으니 기술 칸 줄과 도움말 칩은 치운다
	if bottom.visible:
		$HelpChip.visible = not help.visible and not GameInput.touch   # 도움말이 떠 있는 동안엔 안내 칩을 감춘다
		bottom.set_touch(GameInput.touch)
	$QuestBanner.visible = not Cutscene.on
	if _raid.visible:
		if Time.get_ticks_msec() > _raid_until: _raid.visible = false
		# 좌우로 흔들린다 (2D판 shake 0.5초 반복: 화면 폭의 ±1.5%)
		else: _raid.position.x = sin(Time.get_ticks_msec() / 500.0 * TAU) * get_viewport().get_visible_rect().size.x * 0.015
	if not _boss_bar.visible: return
	var inner := _boss_track.size.x - 4
	_boss_fill.size.x = move_toward(_boss_fill.size.x, inner * _boss_ratio, inner * dt / 0.15)


## 알림은 화면 위쪽 가운데에 차곡차곡 쌓인다. 한 번에 최대 4개, 3.4초
func toast(msg: String, icon := "✨") -> void:
	var t: Control = TOAST_SCENE.instantiate()
	t.get_node("Label").text = "%s %s" % [icon, msg]
	_toasts.add_child(t)
	while _toasts.get_child_count() > MAX_TOASTS:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	t.modulate.a = 0
	var tw := t.create_tween()
	tw.tween_property(t, "modulate:a", 1.0, 0.27)
	tw.tween_interval(2.62)
	tw.tween_property(t, "modulate:a", 0.0, 0.51)
	tw.tween_callback(t.queue_free)
