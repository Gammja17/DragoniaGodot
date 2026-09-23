class_name DialogueBox
extends PanelContainer
## 2D판 ui/dialogueUI.js. 대화창 모양만 맡는다. 어떤 대사를 보여줄지는 Dialogue·NpcActions·Chronicle 이 정한다.
## 모양은 scenes/ui/dialogue_box.tscn · dialogue_option.tscn.

const OPTION := preload("res://scenes/ui/dialogue_option.tscn")
const TIERS := ["낯선 사이", "아는 사이", "친구", "절친"]
const SEL_STYLE_BG := Color(1, 216 / 255.0, 74 / 255.0, 0.16)

static var current: DialogueBox
## 대사 글자 크기 단계 (설정의 --dlg-step, 1~4. 12px 의 배수라야 픽셀 글꼴이 안 뭉개진다)
static var step := 2

@onready var _pad: MarginContainer = $Pad
@onready var _portrait: Control = $Pad/Body/Header/Portrait
@onready var _name: Label = $Pad/Body/Header/Who/Name
@onready var _job: Label = $Pad/Body/Header/Who/Meta/Job
@onready var _tier: Label = $Pad/Body/Header/Who/Meta/Tier
@onready var _rel: Control = $Pad/Body/Header/Who/Rel
@onready var _rel_fill: Control = $Pad/Body/Header/Who/Rel/Fill
@onready var _text: Label = $Pad/Body/Text
@onready var _options: VBoxContainer = $Pad/Body/Options

var _selected := 0
var _typed := 0.0
var _list := []
var _cinematic := false
var _style_normal: StyleBoxFlat
var _style_selected: StyleBoxFlat


func _ready() -> void:
	current = self
	step = clampi(int(Prefs.get_value("dialogue", "step", 2)), 1, 4)   # 설정의 대사 글자 크기
	_style_normal = OPTION.instantiate().get_theme_stylebox("normal").duplicate()
	_style_selected = _style_normal.duplicate()
	_style_selected.bg_color = SEL_STYLE_BG
	_style_selected.border_color = Color("#d8b25a")
	get_viewport().size_changed.connect(_layout)
	_layout()


static func is_open() -> bool:
	return current != null and current.visible


## 대사 속 {name} 을 주인공 이름으로 바꾼다. "{name}(이)" 의 '이'는 받침이 있을 때만 붙는다
static func fill_name(text: String) -> String:
	if text.find("{name}") < 0: return text
	var nm: String = GameState.player.config.get("name", "") if GameState.player else ""
	var batchim := false
	if nm != "":
		var code := nm.unicode_at(nm.length() - 1)
		batchim = code >= 0xAC00 and code <= 0xD7A3 and (code - 0xAC00) % 28 != 0
	return text.replace("{name}(이)", nm + ("이" if batchim else "")).replace("{name}", nm)


## opts: { name, text, options: [{ label, on_select }], on_close, sheet, npc }.
## options 가 비어 있으면 '닫기' 하나. npc 를 넘기면 머리에 맡은 일·사이·호감도 막대를 함께 보여 준다
func show_dialogue(opts: Dictionary) -> void:
	_portrait.sheet = opts.get("sheet")
	_portrait.queue_redraw()
	_name.text = opts.get("name", "")
	var npc = opts.get("npc")
	var job: String = str(npc.job) if npc and npc.job else ""
	var rel = npc.relation if npc and npc.config.get("fixed") else null
	_job.text = job
	_tier.text = "" if rel == null else ("· " if job != "" else "") + TIERS[_tier_of(rel)]
	_rel.visible = rel != null
	_portrait.visible = true
	if rel != null: _rel_fill.size.x = (_rel.size.x - 2) * minf(100, rel) / 100.0
	_text.text = fill_name(opts.get("text", ""))
	_text.visible_characters = 0
	_typed = 0.0
	for c in _options.get_children():
		_options.remove_child(c); c.queue_free()
	_list = opts.get("options", [])
	if _list.is_empty(): _list = [{ label = "닫기", on_select = opts.get("on_close", func(): pass) }]
	for i in _list.size():
		var b: Button = OPTION.instantiate()
		b.text = _list[i].label                 # 번호는 붙이지 않는다 (방향키로 고른다)
		b.add_theme_font_size_override("font_size", 12 * maxi(1, step - 1))
		b.pressed.connect(_choose.bind(i))
		# 마우스를 '움직여' 얹으면 그 줄이 골라진다 (창이 열리는 순간 커서 밑에 깔린 줄이 멋대로 골라지지 않게)
		b.gui_input.connect(func(ev): if ev is InputEventMouseMotion and _selected != i: _select(i))
		_options.add_child(b)
	_text.label_settings.font_size = 12 * step
	_select(0)
	visible = true


func hide_dialogue() -> void:
	visible = false
	for c in _options.get_children():   # 숨겨진 버튼이 남아 다시 눌리는 일 방지
		_options.remove_child(c); c.queue_free()
	_list = []


## 컷씬이면 가운데로 모으고 띠 안쪽에 앉힌다
func set_cinematic(on: bool) -> void:
	_cinematic = on
	_layout()


func _layout() -> void:
	var vw := get_viewport_rect().size
	if _cinematic:
		var w := minf(940, vw.x * 0.84)
		anchor_left = 0.5; anchor_right = 0.5
		offset_left = -w / 2; offset_right = w / 2
		offset_bottom = -vw.y * 0.12
		_pad.add_theme_constant_override("margin_left", 0)
		_pad.add_theme_constant_override("margin_right", 0)
	else:
		anchor_left = 0.0; anchor_right = 1.0
		offset_left = 0; offset_right = 0; offset_bottom = 0
		var side := int(vw.x * 0.08)
		_pad.add_theme_constant_override("margin_left", side)
		_pad.add_theme_constant_override("margin_right", side)
	# 판이 커진 뒤로는 거의 불투명해야 글이 읽힌다. 컷씬 때 조금 더 어둡게
	self_modulate = Color(0.95, 0.95, 1.0, 1.0) if _cinematic else Color.WHITE


func _process(dt: float) -> void:
	if not visible: return
	# 대사를 한 글자씩 찍는다 (16ms 에 두 글자)
	var total := _text.get_total_character_count()
	if _text.visible_characters >= 0 and _text.visible_characters < total:
		var before := int(_typed)
		_typed += dt * 125
		_text.visible_characters = mini(int(_typed), total)
		if int(_typed) / 6 != before / 6: Sfx.play("talk")
		if _text.visible_characters >= total: _text.visible_characters = -1


func _tier_of(r: float) -> int:
	return 3 if r >= 75 else 2 if r >= 50 else 1 if r >= 25 else 0


func _select(i: int) -> void:
	_selected = i
	var buttons := _options.get_children()
	for k in buttons.size():
		var sel := k == i
		for s in ["normal", "hover", "pressed"]:
			buttons[k].add_theme_stylebox_override(s, _style_selected if sel else _style_normal)
		buttons[k].add_theme_color_override("font_color", Color.WHITE if sel else Color("#ece3cf"))
		buttons[k].add_theme_color_override("font_hover_color", Color.WHITE if sel else Color("#ece3cf"))
		buttons[k].get_node("Arrow").visible = sel


func _choose(i: int) -> void:
	if i >= _list.size(): return
	Sfx.play("ui")
	_list[i].on_select.call()


## 키보드로 고르기: 방향키(또는 W·S)로 옮기고 [Space]·Enter 로 고른다. main 이 대화 중에 부른다
func handle_keys() -> void:
	var n := _options.get_child_count()
	if n == 0: return
	if GameInput.pressed("down") or GameInput.pressed("right"):
		_select((_selected + 1) % n); Sfx.play("ui")
	if GameInput.pressed("up") or GameInput.pressed("left"):
		_select((_selected + n - 1) % n); Sfx.play("ui")
	if GameInput.pressed("confirm") or GameInput.pressed("interact") or GameInput.pressed("talk"):
		_choose(_selected)
