class_name SettingsPanel
extends GamePanel
## 2D판 ui/settings.js. 설정 창. [Esc] 로 연다 (열려 있는 다른 창이 있으면 Esc 는 그것부터 닫는다).
##   소리: 배경음·효과음 손잡이, 전체 끄기 (systems/audio · sfx 가 매 프레임 따른다)
##   화면: 시점 단계, 좌우 판 접기, UI 크기, 대사 글자 크기, 화면 효과 판 · 길잡이 · 테스트 · 조작법 · 처음 화면으로

signal help_pressed
signal fx_pressed
signal to_title_pressed
signal save_code_pressed

const DLG_NAMES := { 1: "작게", 2: "보통", 3: "크게", 4: "아주 크게" }

@export var slider_track: StyleBox
@export var slider_fill: StyleBox
@export var slider_knob: Texture2D

@onready var _rows: VBoxContainer = $Frame/Lines/Body/Scroll/Rows


func _ready() -> void:
	super()
	for key in ["Music", "Sfx"]:
		var s: HSlider = _rows.get_node("%s/Slider" % key)
		s.add_theme_stylebox_override("slider", slider_track)
		s.add_theme_stylebox_override("grabber_area", slider_fill)
		s.add_theme_stylebox_override("grabber_area_highlight", slider_fill)
		s.add_theme_icon_override("grabber", slider_knob)
		s.add_theme_icon_override("grabber_highlight", slider_knob)
		s.max_value = 100
		var pref := "music" if key == "Music" else "sfx"
		s.value = roundi((Audio.music_volume() if key == "Music" else Sfx.volume()) * 100)
		s.value_changed.connect(func(v):
			Prefs.set_value("sound", pref, v / 100.0)
			_rows.get_node("%s/Num" % key).text = str(roundi(v)))
	_btn("Mute").pressed.connect(func():
		Prefs.set_value("sound", "muted", not Prefs.get_value("sound", "muted", false))
		_refresh())
	_btn("Zoom").pressed.connect(func():
		GameCamera.current.cycle_zoom()
		_refresh())
	_btn("Ui").pressed.connect(func(): Hud.current.toggle_ui())
	_btn("UiSize").pressed.connect(func():
		Hud.pop("UI 크기: %s" % UiScale.cycle(), "🔎")
		_refresh())
	_btn("Dlg").pressed.connect(func():
		DialogueBox.step = DialogueBox.step % 4 + 1
		Prefs.set_value("dialogue", "step", DialogueBox.step)
		Hud.pop("대사 글자: %s" % DLG_NAMES[DialogueBox.step], "🔤")
		_refresh())
	_btn("Fx").pressed.connect(func():
		close()
		fx_pressed.emit())
	_btn("Guide").pressed.connect(func():
		Guide.cycle_level()
		_refresh())
	_btn("Level").pressed.connect(_test_level)
	_btn("Elements").pressed.connect(_test_elements)
	_btn("Lessons").pressed.connect(_test_lessons)
	_btn("Help").pressed.connect(func():
		close()
		help_pressed.emit())
	_btn("ToTitle").pressed.connect(func(): to_title_pressed.emit())
	_btn("SaveCode").pressed.connect(func(): save_code_pressed.emit())
	opened.connect(_refresh)


func _btn(row: String) -> Button: return _rows.get_node("%s/Button" % row)


func _refresh() -> void:
	for key in ["Music", "Sfx"]:
		_rows.get_node("%s/Num" % key).text = str(roundi(_rows.get_node("%s/Slider" % key).value))
	_btn("Mute").text = "꺼짐 · 켜기" if Prefs.get_value("sound", "muted", false) else "켜짐 · 끄기"
	_btn("Zoom").text = GameCamera.current.zoom_name()
	_btn("UiSize").text = UiScale.setting_name()
	_btn("Dlg").text = DLG_NAMES[DialogueBox.step]
	_btn("Guide").text = Guide.LEVELS[Guide.level()]
	var p = GameState.player
	if not p: return
	_rows.get_node("Level/Label").text = "레벨 %d → 16" % p.level
	_rows.get_node("Elements/Label").text = "속성 %d / 3" % p.elements.size()
	_rows.get_node("Lessons/Label").text = "수련 %d / %d · 보스 %d" % [GameState.story.lessons.size(), Data.get_module("story").LESSONS.size(), GameState.bossesDefeated.size()]


# ---------- 테스트 (뒷이야기를 확인하려고 둔 것이라 진행이 그대로 건너뛰어진다) ----------

func _test_level() -> void:
	_mark_tested()
	var p = GameState.player
	while p.level < 16: p.gain_xp(p.max_xp - p.xp)
	Save.save_game()
	_refresh()


func _test_elements() -> void:
	_mark_tested()
	var p = GameState.player
	for id in Data.get_module("elements").ELEMENTS:
		if not p.elements.has(id): p.elements.append(id)
	Hud.pop("세 속성을 모두 얻었다. (테스트)", "✨")
	Save.save_game()
	_refresh()


func _test_lessons() -> void:
	_mark_tested()
	GameState.story.lessons = Data.get_module("story").LESSONS.map(func(l): return l.id)
	GameState.story.lessonDay = 0
	for id in Data.get_module("enemies").BOSSES: GameState.bossesDefeated[id] = true
	Hud.pop("수련과 보스 기록을 채웠다. (테스트)", "📜")
	Save.save_game()
	_refresh()


## 테스트 단추로 건너뛴 판에는 표시를 남긴다. 이 판에서는 SKEAM 도전 과제를 더 알리지 않는다 (Achievements)
func _mark_tested() -> void:
	if not GameState.story.has("flags"): GameState.story.flags = {}
	GameState.story.flags.tested = true
