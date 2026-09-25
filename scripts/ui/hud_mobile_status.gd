class_name HudMobileStatus
extends PanelContainer
## 휴대폰용 상태 카드 (왼쪽 위). 데스크톱 상태판(HudStatus)의 절반쯤 되는 크기에
## 초상 · 이름 · 레벨, 체력(수) · 배부름 · 경험 막대, 고기 · 골드 · 성장 포인트만 담는다.
## 모바일 액션 게임처럼 세상을 덜 가리고, 엄지가 닿지 않는 위쪽 구석에 조용히 있는다.
## HudStatus 와 같은 이름의 신호 · refresh() 를 가져서 Hud 는 둘 가운데 하나를 똑같이 다룬다.
## 모양은 scenes/ui/hud_mobile_status.tscn.

signal collapse_pressed
signal family_pressed
signal growth_pressed

@onready var _portrait: Control = $Row/Portrait
@onready var _name: Label = $Row/Col/Id/Name
@onready var _level: Label = $Row/Col/Id/Level
@onready var _hp: HudBar = $Row/Col/Hp
@onready var _food: HudBar = $Row/Col/Food
@onready var _xp: HudBar = $Row/Col/Xp
@onready var _meat: Label = $Row/Col/Inv/Meat
@onready var _gold: Label = $Row/Col/Inv/Gold
@onready var _points: Button = $Row/Col/Inv/Points
@onready var _buffs: Label = $Row/Col/Buffs


func _ready() -> void:
	_points.pressed.connect(func(): growth_pressed.emit())


func refresh() -> void:
	var p = GameState.player
	if not p: return
	if _portrait.sheet != p.sheet:
		_portrait.sheet = p.sheet
		_portrait.queue_redraw()
	_name.text = p.config.get("name", "용") if p.config.get("name") else "용"
	_level.text = "Lv.%d %s" % [p.level, p.stage.name]
	_hp.set_value(p.hp / p.max_hp, "%d/%d" % [roundi(p.hp), roundi(p.max_hp)])
	_food.set_value(clampf(p.hunger, 0, 100) / 100.0, "")
	_xp.set_value(p.xp / p.max_xp, "")
	_meat.text = "🍖%d" % p.inventory.meat
	_gold.text = "🪙%d" % p.gold
	var pts: int = GameState.growth.get("points", 0)
	_points.visible = pts > 0
	if pts > 0: _points.text = "🌟%d" % pts
	# 걸린 효과는 이름만 한 줄로 (나쁜 것은 붉게)
	var good := []
	var bad := []
	if p.fury > 0: good.append("분노")
	if p.guard > 0: good.append("강철 비늘")
	if GameState.rally > 0: good.append("함성")
	if GameState.blessingDay == GameState.day: good.append("축복")
	if p.slow_timer > 0: bad.append("둔화")
	if p.hunger_level == 2: bad.append("굶주림")
	elif p.hunger_level == 1: bad.append("출출함")
	_buffs.text = " · ".join(good + bad)
	_buffs.visible = _buffs.text != ""
	_buffs.add_theme_color_override("font_color", Color("#ff8a7a") if not bad.is_empty() else Color("#ffe9a0"))
