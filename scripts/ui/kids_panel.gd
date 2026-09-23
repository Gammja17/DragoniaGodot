class_name KidsPanel
extends GamePanel
## 2D판 ui/kidsPanel.js. 가족 창 [P]. 아이마다 단계 · 애정(♥) · [이름] · [따라오는 중 / 둥지 지키는 중]

const ROW := preload("res://scenes/ui/kid_row.tscn")
const STAGE_NAMES := { "BABY": "아기", "TEEN": "청소년 (전투 가능)", "ADULT": "성체 (둥지 수호)" }


func _ready() -> void:
	super()
	opened.connect(refresh)


func refresh() -> void:
	var list: VBoxContainer = $Frame/Lines/Body/Scroll/List
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	$Frame/Lines/Body/Meta.text = "최대 %d명 · 지금 %d명" % [Data.get_module("core_config").MAX_KIDS, GameState.kids.size()]
	var empty: Label = $Frame/Lines/Body/Empty
	empty.visible = GameState.kids.is_empty()
	empty.text = "아직 아이가 없다. 짝에게 말을 걸어 [마음] → 아이 이야기를 꺼내 보자." if GameState.partner \
		else "아직 아이가 없다. 마음이 통하는 용과 짝이 되면 둥지에 알을 품을 수 있다."
	for k in GameState.kids:
		var row: Control = ROW.instantiate()
		list.add_child(row)
		row.get_node("Row/Info/Name").text = k.name
		row.get_node("Row/Info/Stage").text = STAGE_NAMES.get(k.stage, k.stage)
		row.get_node("Row/Hearts").text = "♥".repeat(mini(5, roundi(k.affection / 20.0)))
		row.get_node("Row/Rename").pressed.connect(func():
			NameInput.ask("아이의 새 이름 (12자까지)", k.name, func(n: String):
				Kids.rename(k, n)
				refresh(), 12))
		var mode: Button = row.get_node("Row/Mode")
		mode.visible = k.stage != "ADULT"
		mode.text = "따라오는 중" if k.mode == "FOLLOW" else "둥지 지키는 중"
		mode.pressed.connect(func():
			Kids.toggle_mode(k)
			refresh())
