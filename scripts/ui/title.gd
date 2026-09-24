class_name Title
extends Control
## 처음 화면. 2D판 ui/customizer.js + 세이브 칸 셋.
##   [기록]      칸 셋. 이어 하기 · 새로 시작 · 지우기
##   [새 용]     이름 · 외형 30가지 · 장신구 · (옛 종족은) 몸과 날개 색 → 눈을 뜬다
##   [되묻기]    차 있는 칸을 덮어쓰거나 지울 때 한 번 더 묻는다
## 고른 것은 Launch 에 담아 게임 씬(main.tscn)으로 넘긴다.

const LOOK_CELL := preload("res://scenes/ui/look_cell.tscn")
const GAME := "res://scenes/main.tscn"
# 색을 바꿀 수 있는 옛 종족 4 (한 장짜리 새 외형 26 뒤에 붙는다)
const CLASSIC := [["WESTERN", "서양룡 (색 변경 가능)"], ["WYVERN", "와이번 (색 변경 가능)"], ["HYDRA", "쌍두룡 (색 변경 가능)"], ["BEHEMOTH", "베히모스 (색 변경 가능)"]]
const ACCESSORIES := [null, "PLUME", "FLOWER", "LEAF", "HELM", "HAT", "CROWN"]

@onready var _slots: PanelContainer = $Center/Column/Slots
@onready var _create: PanelContainer = $Center/Column/Create
@onready var _confirm: PanelContainer = $Center/Column/Confirm
@onready var _grid: GridContainer = $Center/Column/Create/Lines/Body/Right/Gallery/Grid
@onready var _look_name: Label = $Center/Column/Create/Lines/Body/Left/LookName
@onready var _preview: Control = $Center/Column/Create/Lines/Body/Left/Stage/Portrait
@onready var _gallery: ScrollContainer = $Center/Column/Create/Lines/Body/Right/Gallery
@onready var _grow: Control = $Center/Column/Create/Lines/Body/Right/Grow
@onready var _colors: Control = $Center/Column/Create/Lines/Body/Left/Colors
@onready var _body: ColorPickerButton = $Center/Column/Create/Lines/Body/Left/Colors/Body/Pick
@onready var _wing: ColorPickerButton = $Center/Column/Create/Lines/Body/Left/Colors/Wing/Pick
@onready var _mark: ColorPickerButton = $Center/Column/Create/Lines/Body/Left/Colors/Mark/Pick
@onready var _name: LineEdit = $Center/Column/Create/Lines/Body/Left/Name

var _slot := 1
var _choice := { species = "HERO", look = 0 }
var _cells := []
var _on_yes: Callable


func _ready() -> void:
	for i in Save.SLOTS:
		var row: SaveSlotRow = $Center/Column/Slots/Lines.get_node("Slot%d" % (i + 1))
		row.play_pressed.connect(_play)
		row.new_pressed.connect(_new)
		row.delete_pressed.connect(_delete)
	$Center/Column/Create/Lines/Buttons/Start.pressed.connect(_start)
	$Center/Column/Create/Lines/Buttons/Back.pressed.connect(func(): _show(_slots))
	$Center/Column/Confirm/Lines/Buttons/Yes.pressed.connect(func(): _on_yes.call())
	$Center/Column/Confirm/Lines/Buttons/No.pressed.connect(func(): _show(_slots))
	_body.color_changed.connect(func(_c): _recolor())
	_wing.color_changed.connect(func(_c): _recolor())
	_mark.color_changed.connect(func(_c): _recolor())
	_build_gallery()
	_show(_slots)


func _show(page: Control) -> void:
	for p in [_slots, _create, _confirm]: p.visible = p == page
	if page == _slots:
		for i in Save.SLOTS: $Center/Column/Slots/Lines.get_node("Slot%d" % (i + 1)).show_slot(i + 1)
	# 새 용 판은 키가 커서, 낮은 화면(휴대폰)에서는 제목을 접고 외형 목록을 줄인다
	var h := get_viewport_rect().size.y
	for n in ["Logo", "Subtitle", "Gap"]: $Center/Column.get_node(n).visible = page != _create or h >= 600
	var low := h < 520   # 휴대폰 가로: 무대를 줄이고 이름 칸 글씨도 작게 (색이 세 줄이라 왼쪽이 길다)
	var left := $Center/Column/Create/Lines/Body/Left
	left.get_node("Stage").custom_minimum_size.y = 96 if low else 170
	left.get_node("NameLabel").visible = not low
	_name.add_theme_font_size_override("font_size", 12 if low else 24)
	if page == _create:
		$Center/Column/Create/Lines/Head/Slot.text = "%d번 칸" % _slot
		_name.grab_focus()
		_name.select_all()


func _ask(text: String, yes_label: String, on_yes: Callable) -> void:
	$Center/Column/Confirm/Lines/Text.text = text
	$Center/Column/Confirm/Lines/Buttons/Yes.text = yes_label
	_on_yes = on_yes
	_show(_confirm)


# ---------- 칸 ----------

func _play(n: int) -> void:
	Sfx.play("ui")
	Launch.continue_game(n)
	get_tree().change_scene_to_file(GAME)


func _new(n: int) -> void:
	Sfx.play("ui")
	_slot = n
	if Save.has_save(n):
		var s = Save.summary(n)
		_ask("%d번 칸에는 %s(Lv.%d)의 기록이 있다.\n새로 시작하면 그 기록은 사라진다." % [n, s.name, s.level], "새로 시작한다", func(): _show(_create))
	else: _show(_create)


func _delete(n: int) -> void:
	var s = Save.summary(n)
	_ask("%d번 칸의 %s(Lv.%d) 기록을 지울까?\n지운 기록은 되돌릴 수 없다." % [n, s.name, s.level], "지운다", func():
		Save.delete(n)
		_show(_slots))


# ---------- 새 용 ----------

func _build_gallery() -> void:
	# 주인공 프리셋 다섯 (data/sprites.json HERO). 옛 종족·26종 외형은 마을 용과 아이들만 쓴다
	var presets: Array = Data.get_module("sprites").HERO_PRESETS
	for i in presets.size(): _add_cell({ species = "HERO", look = i }, presets[i].name)
	_select(_cells[0])


func _add_cell(v: Dictionary, nm: String) -> void:
	var cell: LookCell = LOOK_CELL.instantiate()
	_grid.add_child(cell)
	cell.setup(v, nm, _colors_now())
	cell.pressed.connect(func(): _select(cell))
	_cells.append(cell)


func _select(cell: LookCell) -> void:
	_choice = cell.value
	for c in _cells: c.set_selected(c == cell)
	_look_name.text = cell.look_name
	_show_growth()
	_colors.visible = _choice.species != "LOOK"   # 한 장짜리 외형은 색을 바꿀 수 없다


func _colors_now() -> Dictionary:
	return { body = "#" + _body.color.to_html(false), wing = "#" + _wing.color.to_html(false), mark = "#" + _mark.color.to_html(false) }


## HERO 는 성체 칸으로 미리 보여 준다 (칸 번호 = 프리셋 × 3 + 2)
func _preview_look(v: Dictionary) -> int:
	return int(v.look) * 3 + 2 if v.species == "HERO" else int(v.look)


## 색을 바꾸면 옛 종족 칸들의 그림을 다시 칠한다
func _recolor() -> void:
	for c in _cells:
		if c.value.species != "LOOK": c.setup(c.value, c.look_name, _colors_now())
	if _choice.species != "LOOK": _show_growth()


## 큰 미리보기(성체)와 자라는 모습 세 칸 (HERO 는 프리셋 × 3 + 단계)
func _show_growth() -> void:
	_preview.sheet = DragonSprites.get_sheet(_choice.species, _colors_now(), _preview_look(_choice))
	_preview.queue_redraw()
	var hero: bool = _choice.species == "HERO"
	_grow.visible = hero
	$Center/Column/Create/Lines/Body/Right/GrowLabel.visible = hero
	if not hero: return
	for i in 3:
		var p: Control = _grow.get_child(i).get_node("Portrait")
		p.sheet = DragonSprites.get_sheet("HERO", _colors_now(), int(_choice.look) * 3 + i)
		p.queue_redraw()


func _start() -> void:
	Sfx.play("ui")
	var nm := _name.text.strip_edges()
	Launch.new_game(_slot, {
		name = nm if nm != "" else "Player",
		species = _choice.species,
		look = _choice.look,
		accessory = ACCESSORIES[$Center/Column/Create/Lines/Body/Left/Accessory/Pick.selected],
		colors = _colors_now(),
	})
	Save.slot = _slot
	Save.delete(_slot)   # 새로 시작하면 그 칸의 옛 기록은 버린다
	get_tree().change_scene_to_file(GAME)
