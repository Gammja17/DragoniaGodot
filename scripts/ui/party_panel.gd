class_name PartyPanel
extends Control
## 원정대 창: 따라나선 동료의 얼굴 · 이름 · 역할 · 체력 (scenes/ui/party_panel.tscn).
## 상태판 바로 밑에 붙고, 상태판이 접히면 같이 숨는다. 장면이 열리면 다른 판처럼 물러난다.
## 결투장에 합류한 용(이그나르전의 카이론)도 보인다

const ROW := preload("res://scenes/ui/party_row.tscn")
const REFRESH := 0.1

@onready var _list: VBoxContainer = $List
var _t := 0.0


func _process(dt: float) -> void:
	var hud = Hud.current
	if hud == null or GameState.player == null: return
	var dragons := _dragons()
	visible = GameState.gameActive and hud.status.visible and not GameState.prologue and not dragons.is_empty()
	if not visible: return
	modulate.a = 1.0 - Cutscene.bars
	var st: Control = hud.status
	scale = st.scale
	position = Vector2(st.position.x, st.position.y + st.size.y * st.scale.y + 8)
	_t -= dt
	if _t > 0: return
	_t = REFRESH
	while _list.get_child_count() < dragons.size(): _list.add_child(ROW.instantiate())
	while _list.get_child_count() > dragons.size():
		var c := _list.get_child(_list.get_child_count() - 1)
		_list.remove_child(c)
		c.queue_free()
	for i in dragons.size(): _list.get_child(i).show_dragon(dragons[i])


## 창에 올릴 용: 따라나선 동료 + 이 지도에서 함께 싸우는 용
func _dragons() -> Array:
	var out: Array = Party.followers()
	for n in GameState.entities.npcs:
		if n.state == "ALLY" and not out.has(n): out.append(n)
	return out
