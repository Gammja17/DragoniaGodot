class_name TreeView
extends Control
## 갈래 셋이 뿌리 하나에서 뻗어 올라가는 나무 (2D판 buildTree · drawLinks). 성장 나무와 스킬 나무가 함께 쓴다.
## 마디는 아래줄(기초)부터 위로 쌓고, 줄기는 자리를 잡은 뒤 마디들의 실제 위치를 재서 긋는다.
## 딴 마디로 이어지는 줄기는 갈래 색으로 빛난다.

signal node_picked(item)

const BRANCH := preload("res://scenes/ui/tree_branch.tscn")
const NODE := preload("res://scenes/ui/tree_node.tscn")
const GLYPHS := { "FANG": "▲", "SCALE": "⬢", "WING": "✦", "BODY": "▲", "BREATH": "⬢", "SOUL": "✦" }
const LINK_DIM := Color(216 / 255.0, 178 / 255.0, 90 / 255.0, 0.38)

var _branches := []   # [{ color, rows: [[TreeNode, ...] 아래줄부터] }]


func _ready() -> void:
	$Links.draw.connect(_draw_links)


func _process(_dt: float) -> void:
	# 안쪽 칸들이 자리를 잡는 것은 한두 프레임 늦다. 보이는 동안은 줄기를 늘 다시 긋는다
	if is_visible_in_tree():
		# 굴림판 안에 들어 있으므로, 나무가 차지하는 크기를 제 크기로 알린다
		custom_minimum_size = $Layout.get_combined_minimum_size()
		$Links.queue_redraw()


## branches: [{ key, title, sub, color, tiers: [[항목, ...] 아래줄부터] }]
## make(항목, 색) → TreeNode.setup 에 넘길 { rank, name, color, on, full, can, locked, sel, slot }
func build(branches: Array, root_label: String, make: Callable) -> void:
	var canopy: HBoxContainer = $Layout/Canopy
	for c in canopy.get_children(): c.queue_free()
	_branches.clear()
	$Layout/Root/Row/Label.text = root_label
	for b in branches:
		var col: Control = BRANCH.instantiate()
		canopy.add_child(col)
		var color := Color(b.color)
		col.get_node("Head/Row/Glyph").text = GLYPHS.get(b.key, "◆")
		col.get_node("Head/Row/Glyph").add_theme_color_override("font_color", color)
		col.get_node("Head/Row/Name").text = b.title
		col.get_node("Head/Row/Sub").text = b.get("sub", "")
		col.get_node("Head/Row/Sub").add_theme_color_override("font_color", color)
		col.get_node("Head/Underline").color = color
		var rows_box: VBoxContainer = col.get_node("Rows")
		var rows := []
		# 위가 높은 단계라서 아래줄부터 만들어 위로 쌓는다
		for tier in b.tiers:
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 8)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rows_box.add_child(row)
			rows_box.move_child(row, 0)
			var nodes := []
			for item in tier:
				var n: TreeNode = NODE.instantiate()
				row.add_child(n)
				var d: Dictionary = make.call(item, color)
				d.color = color
				n.setup(d)
				n.picked.connect(func(): node_picked.emit(item))
				nodes.append(n)
			rows.append(nodes)
		_branches.append({ color = color, rows = rows })
	$Links.queue_redraw()


func _draw_links() -> void:
	var links: Control = $Links
	var origin := links.global_position
	var root: Control = $Layout/Root
	var root_top := root.global_position + Vector2(root.size.x / 2, 0) - origin
	for b in _branches:
		var rows: Array = b.rows
		for i in rows.size():
			for n in rows[i]:
				if not is_instance_valid(n): continue
				var a: Vector2 = n.bottom_point() - origin
				var lit: bool = n.on
				var to: Vector2
				if i == 0:
					to = root_top
				else:
					# 아래줄에서 이미 딴 마디가 있으면 거기서, 없으면 첫 칸에서 뻗어 올린다
					var below: Array = rows[i - 1]
					var from = below[0]
					for x in below:
						if x.on:
							from = x
							break
					to = from.top_point() - origin
					lit = lit and from.on
				var mid := (a.y + to.y) / 2
				var pts := PackedVector2Array([a, Vector2(a.x, mid), Vector2(to.x, mid), to])
				if lit: links.draw_polyline(pts, Color(b.color, 0.35), 9)   # 2D판 drop-shadow 빛
				links.draw_polyline(pts, b.color if lit else LINK_DIM, 5.0 if lit else 4.0)
