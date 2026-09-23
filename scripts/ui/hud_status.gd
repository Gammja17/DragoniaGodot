class_name HudStatus
extends PanelContainer
## 2D판 HUD 왼쪽 위: 나. 초상 · 이름 · 단계, 그 밑에 막대 셋(글자는 막대 안에), 걸린 효과, 주머니 한 줄.
## 모양은 scenes/ui/hud_status.tscn. 여기서는 값만 채운다 (Hud 가 0.1초마다 부른다).

signal collapse_pressed
signal family_pressed
signal growth_pressed

const BUFF := preload("res://scenes/ui/hud_buff.tscn")

@onready var _portrait: Control = $Lines/Head/Portrait
@onready var _name: Label = $Lines/Head/Id/Name
@onready var _level: Label = $Lines/Head/Id/Lvl/Level
@onready var _stage: Label = $Lines/Head/Id/Lvl/Stage
@onready var _hp: HudBar = $Lines/Hp
@onready var _food: HudBar = $Lines/Food
@onready var _xp: HudBar = $Lines/Xp
@onready var _buffs: HFlowContainer = $Lines/Buffs
@onready var _points: Button = $Lines/Points
@onready var _meat: Label = $Lines/Inv/Meat
@onready var _gold: Label = $Lines/Inv/Gold
@onready var _twigs: Label = $Lines/Inv/Twigs
@onready var _partner: Button = $Lines/Inv/Partner

var _buff_key := "-"


func _ready() -> void:
	$Lines/Head/Collapse.pressed.connect(func(): collapse_pressed.emit())
	_partner.pressed.connect(func(): family_pressed.emit())
	_points.pressed.connect(func(): growth_pressed.emit())


func refresh() -> void:
	var p = GameState.player
	if not p: return
	if _portrait.sheet != p.sheet:
		_portrait.sheet = p.sheet
		_portrait.queue_redraw()
	_name.text = p.config.get("name", "용") if p.config.get("name") else "용"
	_level.text = "Lv.%d" % p.level
	_stage.text = p.stage.name
	_hp.set_value(p.hp / p.max_hp, "%d" % roundi(p.hp))
	var hunger := clampf(p.hunger, 0, 100)
	_food.set_value(hunger / 100.0, "%d%%" % roundi(hunger))
	var xp_pct: float = p.xp / p.max_xp * 100
	_xp.set_value(xp_pct / 100.0, "%d%%" % floori(xp_pct))
	_meat.text = "🍖 %d" % p.inventory.meat
	_gold.text = "🪙 %d" % p.gold
	_twigs.visible = not GameState.den.get("built", false)
	_twigs.text = "🪵 %d/8" % GameState.den.get("twigs", 0)
	_partner.text = "💞 %s" % (Names.npc(GameState.partner.config.name) if GameState.partner else "없음")
	var pts: int = GameState.growth.get("points", 0)
	_points.visible = pts > 0
	if pts > 0: _points.text = "🌟 성장 포인트 %d · 누르면 성장 나무" % pts
	_refresh_buffs(p)


## 걸려 있는 효과들. 바뀔 때만 다시 만든다
func _refresh_buffs(p) -> void:
	var buffs := []
	if p.fury > 0: buffs.append(["분노", false])
	if p.guard > 0: buffs.append(["강철 비늘", false])
	if GameState.rally > 0: buffs.append(["용의 함성", false])
	if GameState.blessingDay == GameState.day: buffs.append(["엘더의 축복", false])
	if p.slow_timer > 0: buffs.append(["둔화", true])
	if p.hunger_level == 2: buffs.append(["굶주림 (이속·공속 저하)", true])
	elif p.hunger_level == 1: buffs.append(["출출함 (조금 느려짐)", true])
	var key := ",".join(buffs.map(func(b): return b[0]))
	if key == _buff_key: return
	_buff_key = key
	for c in _buffs.get_children(): c.queue_free()
	_buffs.visible = not buffs.is_empty()
	for b in buffs:
		var chip = BUFF.instantiate()
		_buffs.add_child(chip)
		chip.setup(b[0], b[1])
