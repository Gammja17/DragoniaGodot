class_name QuestRow
extends PanelContainer
## 일지의 퀘스트 한 줄 (2D판 .q-item). 누르면 펼쳐져 배경·지나온 대목·할 일·보상을 읽는다.
## 지나온 대목에 장면이 있었으면 [다시 보기], 끝낸 퀘스트는 [마무리 장면 다시 보기].

signal toggled_open(id: String)
signal replay(title: String, scene: Array)
signal track(id: String)

const STEP := preload("res://scenes/ui/quest_step.tscn")
const GOLD_LIT := Color("#ffd84a")
const GOOD := Color("#7dd36a")


func setup(r: Dictionary, open: bool) -> void:
	var L := $Lines/Body/Lines
	var st: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	st.border_color = Color("#3b414c") if r.get("upcoming") else Color("#4e5560") if r.get("done") else GOOD if r.get("complete") else GOLD_LIT
	add_theme_stylebox_override("panel", st)
	modulate.a = 0.5 if r.get("done") or r.get("upcoming") else 1.0
	$Lines/Head/Row/Mark.text = "·" if r.get("upcoming") else "✔" if r.get("done") else "!" if r.get("complete") else "▸"
	$Lines/Head/Row/Mark.add_theme_color_override("font_color", GOOD if r.get("complete") else GOLD_LIT)
	$Lines/Head/Row/Title.text = r.title
	$Lines/Head/Row/Prog.text = "" if r.get("upcoming") else r.get("progress", "")
	if r.get("upcoming"):
		# 다음에 열릴 퀘스트는 귀띔 한 줄만
		$Lines/Head.mouse_default_cursor_shape = Control.CURSOR_ARROW
		$Lines/Body.visible = true
		for c in L.get_children(): c.visible = false
		L.get_node("Hint").visible = true
		L.get_node("Hint/Key").visible = false
		L.get_node("Hint/Text").text = r.hint
		return
	$Lines/Head.pressed.connect(func(): toggled_open.emit(r.id))
	$Lines/Body.visible = open
	if not open: return
	L.get_node("Giver/Text").text = r.giver
	L.get_node("Summary").text = r.summary
	L.get_node("Summary").visible = r.summary != ""
	L.get_node("Chapter/Text").text = r.chapter
	L.get_node("Chapter").visible = r.chapter != ""
	for s in r.steps:
		var row: Control = STEP.instantiate()
		L.get_node("Steps").add_child(row)
		row.get_node("Mark").text = "▸" if s.now else "✔"
		row.get_node("Mark").add_theme_color_override("font_color", GOLD_LIT if s.now else GOOD)
		row.get_node("Text").text = s.hint
		row.get_node("Text").add_theme_color_override("font_color", Color("#ece3cf") if s.now else Color("#b6ae9a"))
		if s.done and s.scene:
			row.get_node("Replay").visible = true
			row.get_node("Replay").pressed.connect(func(): replay.emit(r.title, s.scene))
	L.get_node("Steps").visible = not r.steps.is_empty()
	L.get_node("Hint/Text").text = r.hint
	L.get_node("Hint").visible = not r.done and r.hint != ""
	L.get_node("DoneText").text = r.doneText
	L.get_node("DoneText").visible = r.doneText != ""
	L.get_node("EndScene").visible = r.endScene != null
	if r.endScene: L.get_node("EndScene").pressed.connect(func(): replay.emit(r.title, r.endScene))
	L.get_node("Reward/Text").text = r.reward
	L.get_node("Reward").visible = r.reward != ""
	var tr: Button = L.get_node("Track")
	tr.visible = not r.done
	tr.text = "★ 추적 중 (누르면 해제)" if r.tracked else "☆ 이 퀘스트를 추적"
	if r.tracked: tr.add_theme_color_override("font_color", GOLD_LIT)
	tr.pressed.connect(func(): track.emit(r.id))
