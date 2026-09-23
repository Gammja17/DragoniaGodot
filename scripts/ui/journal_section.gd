class_name JournalSection
extends VBoxContainer
## 일지의 목록 한 묶음 (2D판 section: .journal-title + .journal-row 들). 이름 ......... 값

const ROW := preload("res://scenes/ui/journal_row.tscn")


## title 이 빈 글이면 제목 줄을 감춘다. rows: [[왼쪽, 오른쪽, 흐리게?], ...]
func setup(title: String, rows: Array) -> JournalSection:
	$Title.text = title
	$Title.visible = title != ""
	$Rule.visible = title != ""
	for r in rows: add_row(r[0], r[1], r.size() > 2 and r[2])
	return self


func add_row(left: String, right: String, dim := false) -> void:
	var row: Control = ROW.instantiate()
	row.get_node("Left").text = left
	row.get_node("Right").text = right
	if dim: row.modulate.a = 0.42
	$Rows.add_child(row)
