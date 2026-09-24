class_name QuestLine
extends PanelContainer
## 2D판 추적창의 한 줄. 추적 중인 퀘스트 하나만 보여 주고, 맡은 일이 없으면 "다음에 할 만한 일"을 띄운다.
## 누르면 그곳까지 알아서 걸어간다 (Guide). 할 일이 바뀌면 한 번 번쩍인다.
## 읽기 쉽게: 제목은 밝은 양피지색 굵은 글씨, 할 일은 한 톤 낮게, 상태는 윗줄 글씨와 테두리 색으로만 알린다.

const BG := Color(14 / 255.0, 13 / 255.0, 22 / 255.0, 0.9)
const BG_HOVER := Color(30 / 255.0, 27 / 255.0, 40 / 255.0, 0.95)
const GOLD_LIT := Color("#ffd84a")
const GOLD := Color("#d8b25a")
const GOOD := Color("#7dd36a")
const COLD := Color("#7fd4ff")
const PARCH := Color("#f3ead6")
const GOLD_DIM := Color("#6a5a38")
const PARCH_MID := Color("#cdc4af")
const PARCH_DIM := Color("#a39a87")

@onready var _kind: Label = $Lines/Kind
@onready var _title: Label = $Lines/Title
@onready var _goal: Label = $Lines/Goal
@onready var _where: Label = $Lines/Where
@onready var _prog: Label = $Lines/Prog
@onready var _go: Label = $Lines/Go

var _style: StyleBoxFlat
var _last_key := ""
var _flash := 0.0
var _hover := false
var _left := GOLD_DIM


func _ready() -> void:
	_style = get_theme_stylebox("panel").duplicate()
	add_theme_stylebox_override("panel", _style)
	mouse_entered.connect(func(): _hover = true)
	mouse_exited.connect(func(): _hover = false)
	gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			Sfx.play("ui")
			Guide.toggle_auto_nav())


## 추적창을 다시 채운다. 보여 줄 것이 없으면 감춘다
func refresh() -> void:
	var line = Quests.tracked_line()
	var suggest := false
	if not line:
		var s = Quests.suggestion()
		if not s:
			visible = false
			_last_key = ""
			return
		line = { title = s.title, goal = s.get("goal", ""), complete = false, more = 0 }
		suggest = true
	visible = true
	_kind.text = "다음에 할 만한 일" if suggest else "보고하러 간다" if line.complete else "오늘의 수련" if line.get("training") else "지금 할 일"
	# 좁은 칸이라 줄이 자주 바뀐다. 낱말 가운데서 끊기지 않게 (Util.keep_words)
	_title.text = Util.keep_words(line.title)
	_goal.text = Util.keep_words(line.goal)
	_where.text = Util.keep_words("📍 %s" % line.where) if line.get("where") else ""
	_where.visible = _where.text != ""
	_prog.text = line.get("text", "") if line.get("text") else ""
	_prog.visible = _prog.text != ""
	_left = Color("#4a4538") if suggest else GOOD if line.complete else GOLD_DIM
	_kind.add_theme_color_override("font_color", PARCH_DIM if suggest else GOOD if line.complete else GOLD)
	_title.add_theme_color_override("font_color", PARCH)
	# 할 일이 바뀌면 한 번 번쩍여서 눈길을 끈다
	var key: String = line.title + "|" + line.goal
	if _last_key != "" and key != _last_key: _flash = 1.6
	_last_key = key
	get_parent().get_node("More").text = "+ 맡은 일 %d개 · [J] 일지" % line.more if line.more > 0 else "" if suggest else "[J] 일지"


func _process(dt: float) -> void:
	if not visible: return
	# 추적창 맨 아래 줄: 누르면 가는지, 가는 중인지
	var t = Guide.target()
	var nav: bool = GameState.nav != null
	_go.text = "🧭 걸어가는 중… (누르거나 직접 움직이면 멈춤)" if nav else "🧭 누르면 %s까지 알아서 간다" % (t.label if t.label else "그곳") if t else ""
	_go.visible = _go.text != ""
	_go.add_theme_color_override("font_color", COLD if nav else PARCH_DIM)
	_style.border_color = COLD if nav else _left
	_flash = maxf(0, _flash - dt)
	var base := BG_HOVER if _hover else BG
	_style.bg_color = base.lerp(Color(216 / 255.0, 178 / 255.0, 90 / 255.0, 0.3), _flash / 1.6)
