class_name Hud
extends CanvasLayer
## 2D판 ui/hud.js · ui/toast.js · ui/questBanner.js 가운데 지금 쓰는 것:
## 지역 이름 배너, 알림, 퀘스트 배너, 레벨 업, 보스 체력바, 습격 경고, 화면 가리기, 장 카드, 장면 제목, 대화창.
## 모양은 scenes/ui/hud.tscn 과 그 안의 씬들에 있고, 여기서는 띄우고 움직이기만 한다.
##
## 자리: 화면 위쪽 가운데는 알림 줄 하나다 — 퀘스트 배너가 맨 위, 알림은 그 밑으로 비켜서 쌓인다.
## 지역 이름은 그보다 아래(용 머리 위쯤), 레벨 업은 용 머리 위에 뜬다. 지역 이름이 떠 있는 동안 퀘스트 배너·레벨 업은 기다리고 알림은 하나만

const TOAST_SCENE := preload("res://scenes/ui/toast.tscn")
const MAX_TOASTS := 3
const TOAST_W := 400.0   # 이보다 긴 알림은 줄을 나눈다 (좌우 판 사이에 들어가게)

@onready var _banner: Control = $RegionBanner
@onready var _region_name: Label = $RegionBanner/Name
@onready var _region_sub: Label = $RegionBanner/Sub
@onready var _toasts: Control = $ToastBox

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
var _region_until := 0   # 지역 이름이 떠 있는 동안 (그동안 퀘스트 배너 · 레벨 업은 기다리고, 알림은 하나까지만)
var _boss_ratio := 1.0
var _raid_until := 0
var _qb_queue := []
var _qb_until := 0
var _qb_now = null       # 지금 떠 있는 퀘스트 배너 (지역 이름에 밀리면 다시 줄 세운다)
var _qb_tween: Tween
var _qb_rest := 0.0      # 퀘스트 배너가 내려앉는 자리 (hud.tscn: 알림 줄 맨 위)
var _toast_wait := []    # 아직 못 띄운 알림
var _toast_gap := 0.0    # 다음 알림까지 남은 틈 (한꺼번에 쏟아지지 않게)
var _lv_pending = null   # 아직 못 보여 준 레벨 업 { level, points }
var _lv_at := 0
var _lv_tween: Tween
var _chapter_tween: Tween
var _chapter_done = null

static var current: Hud


## 어디서든 알림을 띄운다 (2D판 showToast)
static func pop(msg: String, icon := "✨") -> void:
	if current: current.toast(msg, icon)


func _ready() -> void:
	current = self
	_banner.modulate.a = 0
	_qb_rest = $QuestBanner.position.y
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
	# 장 카드는 누르면 넘어간다 (터치에는 Esc 가 없다)
	$ChapterCard.gui_input.connect(func(ev):
		if (ev is InputEventMouseButton or ev is InputEventScreenTouch) and ev.pressed: skip_chapter_card())


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


## 지도를 옮기면 지역 이름을 화면 가운데 조금 위에 잠깐 띄웠다 지운다 (2.8초).
## 글자 사이가 벌어졌다 모이고, 사라질 때 다시 조금 벌어진다
func show_region_banner(name_text: String, sub := "") -> void:
	_region_name.text = name_text
	_region_sub.text = sub
	GameState.bannerUntil = GameState.play_time + 3   # 이 동안은 사건 컷씬을 띄우지 않는다
	_region_until = Time.get_ticks_msec() + 2800
	# 떠 있던 퀘스트 배너는 거뒀다가 지역 이름이 지나간 뒤에 다시 띄운다
	if _qb_tween and _qb_tween.is_running():
		_qb_tween.kill()
		$QuestBanner.modulate.a = 0
		_qb_queue.push_front(_qb_now)
		_qb_until = 0
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
	# (chain() 뒤에 set_parallel(true) 를 다시 부르면 사라짐이 머무는 시간과 함께 돌아, 나타나자마자 1초 만에 사라진다)
	t.chain().tween_property(_banner, "modulate:a", 0.0, 0.62)
	t.tween_property(spacing, "spacing_glyph", 7, 0.62)


## 화면 맨 위가 아니라 용 머리 위쯤 (맨 위는 알림 줄 자리다)
func _banner_top() -> float:
	return get_viewport().get_visible_rect().size.y * 0.22


# ---------- 퀘스트 배너 ----------
# 토스트는 쌓이다 사라져서, 이야기가 시작되거나 끝난 걸 놓치기 쉬웠다. 알림 줄 맨 위에 큼직하게 한 번 띄운다.
# 대화·컷씬 중이거나 지역 이름이 떠 있으면 기다렸다가 조용해진 뒤에 띄운다

## kind: '새 퀘스트' | '다음 할 일' | '퀘스트 완료' | '다음에 할 만한 일'
## (quests.gd 가 아직 '새 이야기' · '이야기 완료' 로 부르는 동안은 옛 이름도 받는다)
## q: 이 배너가 알리는 대목의 퀘스트. 줄 서 있는 동안 그 대목이 지나가면 띄우지 않는다 (_stale_banner)
static func quest_banner(kind: String, title: String, goal := "", q = null) -> void:
	if not current: return
	var b := { kind = kind, title = title, goal = goal }
	if q: b.merge({ id = q.id, step = Quests.step_index(q), complete = Quests.is_complete(q) })
	current._qb_queue.append(b)


## 줄 서 있는 동안 지나가 버린 배너. 대화 · 장면 · 지역 이름에 밀려 늦게 뜨면서, 이미 다 잡은 슬라임을 '새 이야기'로 알리거나
## 일을 맡았는데도 맡기 전에 줄 선 '다음에 할 만한 일'을 띄웠다
func _stale_banner(b: Dictionary) -> bool:
	if b.kind == "다음에 할 만한 일": return not Quests.active_quests().is_empty()
	if not b.has("id"): return false
	var q = Quests.by_id(b.id)
	return q == null or not GameState.quests.active.has(b.id) or Quests.step_index(q) != b.step or Quests.is_complete(q) != b.complete


## 쌓아 둔 퀘스트 배너를 버린다 (결말처럼 장면이 직접 이야기를 닫을 때)
func clear_quest_banners() -> void:
	_qb_queue.clear()


func _flush_quest_banner() -> void:
	if _qb_queue.is_empty() or GameState.isDialogueOpen or Cutscene.on or GameState.prologue: return
	var now := Time.get_ticks_msec()
	if now < _qb_until or now < _region_until: return   # 하나 끝나면 다음 것. 지역 이름이 지나간 뒤에
	var b: Dictionary = _qb_queue.pop_front()
	while _stale_banner(b):
		if _qb_queue.is_empty(): return
		b = _qb_queue.pop_front()
	_qb_now = b
	var qb: Control = $QuestBanner
	var kind: Label = qb.get_node("Bg/Lines/Kind")
	var title: Label = qb.get_node("Bg/Lines/Title")
	kind.text = b.kind
	title.text = b.title
	qb.get_node("Bg/Lines/Goal").text = b.goal
	var done: bool = b.kind in ["퀘스트 완료", "이야기 완료"]
	var line_col := Color("#7dd36a") if done else Color("#d8b25a")
	kind.label_settings.font_color = Color("#7dd36a") if done else Color("#ffd84a")
	qb.get_node("Bg/RuleTop").color = Color(line_col, 0.8)
	qb.get_node("Bg/RuleBottom").color = Color(line_col, 0.8)
	var vw := get_viewport().get_visible_rect().size.x
	var w := minf(maxf(minf(420, vw * 0.8), title.get_minimum_size().x + 52), vw * 0.9)
	qb.get_node("Bg").offset_left = -w / 2
	qb.get_node("Bg").offset_right = w / 2
	Sfx.play("level" if done else "quest")
	var hold := 2.59 if _qb_queue.is_empty() else 1.6   # 뒤에 줄 선 배너가 있으면 짧게 머문다
	_qb_until = now + int((0.36 + hold + 0.65) * 1000)
	# 나타나며 제자리로 내려앉고, 머물다 사라진다 (3.6초, 뒤에 줄 선 것이 있으면 2.6초). position 은 화면 기준이다 (0 이면 맨 위에 붙는다)
	qb.modulate.a = 0
	qb.position.y = _qb_rest - 10
	var t := qb.create_tween().set_parallel(true)
	_qb_tween = t
	t.tween_property(qb, "modulate:a", 1.0, 0.36)
	t.tween_property(qb, "position:y", _qb_rest, 0.36)
	t.chain().tween_interval(hold)
	t.chain().tween_property(qb, "modulate:a", 0.0, 0.65)


# ---------- 레벨 업 ----------
# 알림 두 줄로 흘려보내던 것을 용 머리 위의 큰 글자와 빛기둥으로. 대화·장면 중에 올랐으면 끝난 뒤에 보여 준다

## 레벨이 올랐다 (Dragon.gain_xp). points: 받은 성장 포인트
static func level_up(level: int, points: int) -> void:
	if not current: return
	if current._lv_pending: points += current._lv_pending.points   # 보여 주기 전에 또 올랐으면 한 번에
	current._lv_pending = { level = level, points = points }


func _flush_level_up() -> void:
	var p = GameState.player
	if _lv_pending == null or not p or GameState.isDialogueOpen or Cutscene.on or GameState.prologue: return
	if Time.get_ticks_msec() < _region_until: return
	var lv: Control = $LevelUp
	lv.get_node("Sub").text = GameInput.words("Lv.%d · 성장 포인트 +%d ([G] 성장)" % [_lv_pending.level, _lv_pending.points])
	_lv_pending = null
	_lv_at = Time.get_ticks_msec()
	lv.visible = true
	lv.reset_size()
	lv.pivot_offset = Vector2(lv.size.x / 2, lv.size.y)
	lv.modulate.a = 0
	lv.scale = Vector2.ONE * 0.6
	# 톡 튀어나와(0.15초) 머물다가, 떠오르며 사라진다 (2.45초)
	if _lv_tween: _lv_tween.kill()
	var t := lv.create_tween().set_parallel(true)
	_lv_tween = t
	t.tween_property(lv, "modulate:a", 1.0, 0.15)
	t.tween_property(lv, "scale", Vector2.ONE * 1.12, 0.15).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(lv, "scale", Vector2.ONE, 0.1)
	t.chain().tween_interval(1.7)
	t.chain().tween_property(lv, "modulate:a", 0.0, 0.5)
	t.chain().tween_callback(func(): lv.visible = false)
	p.level_up_fx()
	Sfx.play("level")


## 레벨 업 글자는 용 머리 위를 따라다니며 천천히 떠오른다. 장면이 시작되면 거둔다
func _place_level_up() -> void:
	var lv: Control = $LevelUp
	if not lv.visible: return
	var p = GameState.player
	if Cutscene.on or not p:
		lv.visible = false
		return
	var cam := GameCamera.current
	var z: float = cam.zoom.x
	var a: Vector2 = p.crisp_anchor()
	var rise := (Time.get_ticks_msec() - _lv_at) / 1000.0 * 12
	lv.position = (Vector2((a.x - cam.cam_x) * z, (a.y - cam.cam_y) * z - rise) - Vector2(lv.size.x / 2, lv.size.y)).round()


# ---------- 화면 가리기 ----------
## 화면이 까맣게 덮여 있는가 (그 사이의 Esc 가 멈춰 둔 세상을 풀지 않게)
static func fading() -> bool:
	return current != null and current.get_node("FadeScreen").visible

## 화면을 어둡게 했다가(가운데 글자) 다시 밝힌다. mid: 완전히 어두워졌을 때, done: 다시 밝아진 뒤
## keep_paused: 걷힐 때 세상을 풀지 않는다 — 덮인 동안(mid) 다음 장면을 걸어 두면, 막이 걷히며 그 장면이 드러난다
static func fade_screen(text: String, mid: Callable, done: Callable, keep_paused := false) -> void:
	var f: ColorRect = current.get_node("FadeScreen")
	f.get_node("Text").text = text
	f.visible = true
	GameState.isDialogueOpen = true   # 자는 동안 게임을 멈춘다
	var t := f.create_tween()
	t.tween_property(f, "modulate:a", 1.0, 0.9)
	t.tween_interval(0.1)
	t.tween_callback(mid)
	t.tween_interval(1.3)
	if not keep_paused: t.tween_callback(func(): GameState.isDialogueOpen = false)
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
	GameState.bannerUntil = GameState.play_time + 6   # 장 이름이 떠 있는 동안은 사건 컷씬을 띄우지 않는다
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
	text = GameInput.words(text)
	_tip_target = target
	var tip: Label = $InteractTip
	# 레벨 업 글자 · 지역 이름이 떠 있는 동안은 감춘다 (도착한 자리 바로 위에 석비가 있으면 지역 이름을 가렸다)
	tip.visible = target != null and not DialogueBox.is_open() and not Cutscene.on and not $LevelUp.visible and Time.get_ticks_msec() >= _region_until
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


var _visited_map := ""
func _process(dt: float) -> void:
	_cinema_fade()
	# '가 보기' 대목: 오른쪽 기둥을 접어 둬도 센다
	if GameState.player and not GameState.dungeon and GameState.map_id != _visited_map:
		_visited_map = GameState.map_id
		Quests.notify("visit", GameState.map_id)
	# 판의 숫자는 0.1초마다 (2D판 hudAccumulator)
	_refresh_t -= dt
	if _refresh_t <= 0 and GameState.player and status.get_parent():
		_refresh_t = 0.1
		if status.visible: status.refresh()
		if right.visible: right.refresh()
		if bottom.visible: bottom.refresh()
	_flush_quest_banner()
	_update_toasts(dt)
	_flush_level_up()
	_place_tip()
	_place_level_up()
	# 터치에서는 Q·F·R·X 가 단추로 있으니 기술 칸 줄과 도움말 칩은 치운다
	if bottom.visible:
		$HelpChip.visible = not help.visible and not GameInput.touch   # 도움말이 떠 있는 동안엔 안내 칩을 감춘다
		bottom.set_touch(GameInput.touch)
	$QuestBanner.visible = not Cutscene.on
	_banner.visible = not Cutscene.on   # 장면이 시작되면 지역 이름은 장면 제목에 자리를 내준다
	if _raid.visible:
		if Time.get_ticks_msec() > _raid_until: _raid.visible = false
		# 좌우로 흔들린다 (2D판 shake 0.5초 반복: 화면 폭의 ±1.5%)
		else: _raid.position.x = sin(Time.get_ticks_msec() / 500.0 * TAU) * get_viewport().get_visible_rect().size.x * 0.015
	if not _boss_bar.visible: return
	var inner := _boss_track.size.x - 4
	_boss_fill.size.x = move_toward(_boss_fill.size.x, inner * _boss_ratio, inner * dt / 0.15)


## 컷씬이면 상태판·오른쪽 기둥·기술 칸이 띠를 따라 물러났다가 끝나면 돌아온다 (띠 위로 판이 떠 있으면 장면이 깨진다).
## 그동안 쌓인 알림은 장면이 끝난 뒤에 띄운다 (_update_toasts)
func _cinema_fade() -> void:
	var a := 1.0 - Cutscene.bars
	for n in [status, right, bottom, $HelpChip, $ShowStatus, $ShowRight, _toasts]:
		n.modulate.a = a


## 알림은 화면 위쪽 가운데에 한 줄씩 쌓인다 (퀘스트 배너가 떠 있으면 그 밑으로).
## 한 번에 셋까지만 보이고, 넘치는 것은 줄을 서서 앞의 것이 사라지면 0.3초 간격으로 나온다.
## 같은 알림은 겹쳐 쌓지 않고, 긴 알림일수록 오래 머문다
func toast(msg: String, icon := "✨") -> void:
	var text := "%s %s" % [icon, GameInput.words(msg)]   # 패드·터치면 그 기기의 단추 이름으로
	for t in _toasts.get_children():
		if t.get_node("Label").text == text:   # 이미 떠 있으면 새로 쌓지 않고 그것을 다시 머물게 한다
			t.set_meta("age", minf(t.get_meta("age"), 0.25))
			return
	if not _toast_wait.has(text): _toast_wait.append(text)


func _update_toasts(dt: float) -> void:
	var now := Time.get_ticks_msec()
	var qb_on := now < _qb_until
	# 장면 중에는 띠가 다 걷힌 뒤에 (걷히는 동안엔 판이 투명하다)
	var hold: bool = (Cutscene.on or Cutscene.bars >= 0.05) and not GameState.prologue
	# 셋까지. 퀘스트 배너가 떠 있으면 둘, 지역 이름이 떠 있으면 하나 (알림 줄이 지역 이름까지 내려오지 않게)
	var cap := 1 if now < _region_until else MAX_TOASTS - (1 if qb_on else 0)
	_toast_gap -= dt
	if not hold and _toast_gap <= 0 and not _toast_wait.is_empty() and _toasts.get_child_count() < cap:
		_add_toast(_toast_wait.pop_front())
		_toast_gap = 0.3
	var y: float = $QuestBanner/Bg.size.y + 6 if qb_on else 0.0
	for t in _toasts.get_children():
		var age: float = t.get_meta("age")
		var life: float = t.get_meta("life")
		if age >= life:
			_toasts.remove_child(t)
			t.queue_free()
			continue
		t.reset_size()
		if age == 0.0: t.position.y = y - 8   # 새 알림은 제자리 조금 위에서 내려앉는다
		t.position.x = roundf((_toasts.size.x - t.size.x) / 2)
		t.position.y = lerpf(t.position.y, y, minf(1, dt * 12))   # 줄이 바뀌면 뚝 뛰지 않고 미끄러져 간다
		t.modulate.a = minf(1, age / 0.25) * minf(1, (life - age) / 0.5)
		t.set_meta("age", age + dt)
		y += t.size.y + 5


func _add_toast(text: String) -> void:
	var t: Control = TOAST_SCENE.instantiate()
	var label: Label = t.get_node("Label")
	label.text = text
	var ls := label.label_settings
	var max_w := minf(TOAST_W, get_viewport().get_visible_rect().size.x * 0.5)
	if ls.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ls.font_size).x > max_w:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = max_w
	t.set_meta("age", 0.0)
	t.set_meta("life", clampf(1.6 + text.length() * 0.07, 3.0, 5.5))   # 읽을 시간: 긴 알림일수록 오래
	t.modulate.a = 0
	_toasts.add_child(t)
