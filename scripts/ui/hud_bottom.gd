class_name HudBottom
extends Control
## 2D판 HUD 아래쪽: 기술 칸(숨결 1~6 · Q F R · X), 그 위의 기세 띠, 왼쪽 아래의 끼고 있는 유물.
## 모양은 scenes/ui/hud_bottom.tscn.

const RELIC_CHIP := preload("res://scenes/ui/relic_chip.tscn")
const ELS := ["FIRE", "ICE", "THUNDER", "WATER", "EARTH", "GRASS"]
# 고른 숨결 칸의 테두리 · 글자 색 (2D판 .slot[data-el].active)
const EL_ACCENT := {
	"FIRE": ["#ff9a3c", "#ffb96e"], "ICE": ["#7fd4ff", "#7fd4ff"], "THUNDER": ["#ffe27a", "#ffd84a"],
}

@onready var _skills: HBoxContainer = $Skills
@onready var _flow: Panel = $Flow
@onready var _relics: VBoxContainer = $Relics

var _relic_key := "-"


## 터치: 기술 칸 줄은 치우고, 기세 띠는 위로 (2D판 body.touch)
func set_touch(on: bool) -> void:
	_skills.visible = not on
	if on:
		_flow.anchor_top = 0; _flow.anchor_bottom = 0
		_flow.offset_top = 40; _flow.offset_bottom = 49
		_flow.offset_left = -100; _flow.offset_right = 100
	_relics.modulate.a = 0.0 if on else 1.0


func refresh() -> void:
	var p = GameState.player
	if not p: return
	var els: Dictionary = Data.get_module("elements").ELEMENTS
	for i in ELS.size():
		var id: String = ELS[i]
		var slot: SkillSlot = _skills.get_node(id)
		var have: bool = p.elements.has(id)
		# 새 마을에서 받는 숨결은 받기 전까지 칸이 보이지 않는다
		slot.visible = have or i < 3
		var acc: Array = EL_ACCENT.get(id, ["#ffd84a", "#ffd84a"])
		slot.show_state(str(i + 1), els[id].name, not have, p.element == id, 0.0, Color(acc[0]), Color(acc[1]))
	var defs := Skills.defs()
	for key in ["Q", "F", "R"]:
		var slot: SkillSlot = _skills.get_node(key)
		var id = p.slots.get(key)
		var rank := Skills.rank(id) if id else 0
		var cd := 0.0
		if id: cd = p.cooldowns.get(id, 0.0) / p.cd_max.get(id, defs[id].cooldown)
		slot.show_state(key, defs[id].name if id else "비어 있음", id == null, false, cd, Color("#ffd84a"), Color("#ffd84a"), "★".repeat(rank - 1) if rank > 1 else "")
	var ult: SkillSlot = _skills.get_node("Ult")
	ult.visible = p.elements.size() >= 3
	if ult.visible: ult.show_ult(p.ult >= 100, p.ult / 100.0)
	_refresh_flow()
	_refresh_relics()


## 기세 게이지: 기술 칸 바로 위의 가는 띠. 차 있을 때만 보인다
func _refresh_flow() -> void:
	var m := Flow.momentum()
	var on := m > 1 and not Cutscene.on
	_flow.modulate.a = move_toward(_flow.modulate.a, 1.0 if on else 0.0, 0.34)
	var fill: ColorRect = _flow.get_node("Fill")
	fill.size.x = (_flow.size.x - 2) * m / 100.0
	fill.color = Flow.tier_color()
	_flow.get_node("Label").text = Flow.tier_name()


func _refresh_relics() -> void:
	var ids := Relics.equipped()
	var kins: Dictionary = Data.get_module("systems_relics").KINS
	var key := ",".join(ids) + "|" + ",".join(kins.keys().filter(func(k): return Relics.resonates(k)))
	_relics.visible = not Cutscene.on
	if key == _relic_key: return
	_relic_key = key
	for c in _relics.get_children(): c.queue_free()
	var defs := Skills.defs()
	for id in ids:
		var r = Relics.table().get(id)
		if not r: continue
		var small := ""
		if r.get("skill") and defs.has(r.skill): small = defs[r.skill].name
		elif r.get("kin") and Relics.resonates(r.kin): small = "%s 공명" % kins[r.kin].name
		var chip = RELIC_CHIP.instantiate()
		_relics.add_child(chip)
		chip.setup(r.name, small, r.get("kin"))
