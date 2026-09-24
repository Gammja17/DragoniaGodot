class_name PartyRow
extends PanelContainer
## 원정대 창의 한 줄: 얼굴 · 이름 · 역할 · 체력 (scenes/ui/party_row.tscn)

@onready var _portrait: Control = $Row/Portrait
@onready var _name: Label = $Row/Info/Top/Name
@onready var _role: Label = $Row/Info/Top/Role
@onready var _hp: HudBar = $Row/Info/Hp

var _for = null


func show_dragon(n) -> void:
	if _for != n:
		_for = n
		_portrait.sheet = n.sheet
		_portrait.queue_redraw()
		_name.text = Names.npc(n.config.name)
		_role.text = Party.role(n).get("name", "")
	var here: bool = GameState.entities.npcs.has(n)
	modulate.a = 1.0 if here else 0.5   # 나 혼자 가는 곳: 밖에서 기다린다
	if not here: _hp.set_value(n.hp / n.max_hp, "밖에서 기다린다")
	elif n.down_timer > 0: _hp.set_value(0.0, "쓰러짐")
	else: _hp.set_value(n.hp / n.max_hp, "")
