extends Node
## 창 없이 UI 배치를 잰다. 화면 크기마다, 화면(처음 화면 · HUD · 대화 · 판들)마다
##   · 화면 밖으로 나간 것 · 글이 칸보다 길어 넘치는 것 · 칸이 최소 크기보다 좁게 눌린 것 · HUD 덩어리끼리 겹치는 것
## 을 찾아 적는다. 그림은 못 보지만, 이상하게 보이는 것의 대부분은 이 넷 중 하나다.
##   godot --headless --path . res://tools/audit_ui.tscn

const SIZES := [Vector2i(960, 540), Vector2i(1200, 675), Vector2i(780, 420)]   # 보통 · 작게 · 휴대폰 (논리 크기)

var _issues := {}


func _ready() -> void:
	Save.slot = 9
	for sz in SIZES:
		get_tree().root.size = sz
		# 처음 화면
		var title: Node = load("res://scenes/title.tscn").instantiate()
		add_child(title)
		await _frames(4)
		_audit("처음 화면", title, sz)
		title._show(title._create)
		await _frames(3)
		_audit("새 용", title, sz)
		title.queue_free()
		await _frames(2)
		# 게임
		var main: Node = load("res://scenes/main.tscn").instantiate()
		main.play_intro = false
		main.load_save = false
		add_child(main)
		await _frames(12)
		var hud: Hud = Hud.current
		if GameState.isDialogueOpen: _audit("대화창(첫날)", hud, sz)
		Dialogue.close()
		GameState.isDialogueOpen = false
		await _frames(3)
		_audit("HUD", hud, sz)
		var npc = GameState.entities.npcs[0] if GameState.entities.npcs.size() else null
		if npc:
			Dialogue.start(npc, "TALK")
			await _frames(4)
			_audit("대화창", hud, sz)
			Dialogue.close()
			await _frames(2)
		for p in ["settings", "help", "fx", "kids"]:
			hud.get(p).open()
			await _frames(3)
			_audit("판 " + p, hud, sz)
			hud.get(p).close()
		for tab in ["", "skills", "growth", "map", "bag"]:
			hud.journal.toggle_tab(tab)
			await _frames(3)
			_audit("일지 " + (tab if tab else "퀘스트"), hud, sz)
			hud.journal.close()
		main.queue_free()
		await _frames(3)
	_report()
	Save.delete(9)
	get_tree().quit()


func _audit(where: String, root: Node, sz: Vector2i) -> void:
	var view := Rect2(Vector2.ZERO, Vector2(sz))
	for c in _controls(root):
		if not c.is_visible_in_tree() or c.size.x < 1: continue
		var r: Rect2 = c.get_global_rect()
		var clipped := _in_scroll(c)
		var path := str(root.get_path_to(c))
		if not clipped and (r.position.x < -2 or r.position.y < -2 or r.end.x > view.end.x + 2 or r.end.y > view.end.y + 2):
			_add(where, sz, "화면 밖", path, "%s" % [r])
		var ms: Vector2 = c.get_combined_minimum_size()
		if c.get_parent() is Container and (ms.x > c.size.x + 1 or ms.y > c.size.y + 1):
			_add(where, sz, "눌림", path, "최소 %s > %s" % [ms, c.size])
		if c is Label and c.autowrap_mode == TextServer.AUTOWRAP_OFF and not c.clip_text and c.text != "":
			var f: Font = c.get_theme_font("font")
			var fs: int = c.get_theme_font_size("font_size")
			var w := 0.0
			for line in c.text.split("\n"): w = maxf(w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
			if w > c.size.x + 2: _add(where, sz, "글 넘침", path, "%d > %d \"%s\"" % [w, c.size.x, c.text.left(24)])
		if c is Label or c is Button:
			var fs2: int = c.get_theme_font_size("font_size")
			if fs2 < 12: _add(where, sz, "작은 글씨", path, str(fs2))
	# HUD 덩어리끼리 겹침
	if root is Hud:
		var parts := []
		for n in ["Status", "Right", "Bottom", "HelpChip", "ToastBox", "RegionBanner", "BossBar"]:
			var c = root.get_node_or_null(n)
			if c and c.is_visible_in_tree(): parts.append(c)
		for i in parts.size():
			for j in range(i + 1, parts.size()):
				var a := _content_rect(parts[i])
				var b := _content_rect(parts[j])
				if a.size.x > 0 and b.size.x > 0 and a.intersects(b):
					_add(where, sz, "겹침", "%s × %s" % [parts[i].name, parts[j].name], "%s ∩ %s" % [a, b])


## 속이 빈 틀(전체 화면 앵커)은 겹침 판정에서 실제로 보이는 자식들의 영역으로
func _content_rect(c: Control) -> Rect2:
	var out := Rect2()
	for k in _controls(c):
		if k == c or not k.is_visible_in_tree(): continue
		if k is Label or k is Button or k is Panel or k is TextureRect or k is ColorRect or k is PanelContainer:
			var r: Rect2 = k.get_global_rect()
			out = r if out.size.x == 0 else out.merge(r)
	return out


func _controls(n: Node) -> Array:
	var out := []
	if n is Control: out.append(n)
	for k in n.get_children(): out.append_array(_controls(k))
	return out


func _in_scroll(c: Node) -> bool:
	var p := c.get_parent()
	while p:
		if p is ScrollContainer: return true
		p = p.get_parent()
	return false


func _add(where: String, sz: Vector2i, kind: String, path: String, detail: String) -> void:
	var key := "%s | %s | %s" % [kind, where, path]
	if not _issues.has(key): _issues[key] = []
	_issues[key].append("%dx%d %s" % [sz.x, sz.y, detail])


func _report() -> void:
	var keys := _issues.keys()
	keys.sort()
	print("== 문제 %d곳 ==" % keys.size())
	for k in keys:
		print(k, "  →  ", " / ".join(_issues[k]))


func _frames(n: int) -> void:
	for i in n: await get_tree().process_frame
