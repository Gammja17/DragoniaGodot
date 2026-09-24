class_name JournalPanel
extends GamePanel
## 2D판 ui/journal.js. 모험 일지 [J].
##   [퀘스트] [지도] [소지품] [마을 용들] [스킬] [성장] [유물] [도감] [기록] [소리]
## 퀘스트 탭은 줄을 누르면 펼쳐지고, [추적] 을 누르면 오른쪽 추적창에 그 퀘스트가 걸린다.
## 성장·스킬 탭은 뿌리 하나에서 세 갈래가 뻗는 나무로 그리고, 마디를 누르면 아래 줄에서 자세히 보고 포인트를 쓴다.

const SECTION := preload("res://scenes/ui/journal_section.tscn")
const QUEST_ROW := preload("res://scenes/ui/quest_row.tscn")
const FOLK_CARD := preload("res://scenes/ui/folk_card.tscn")
const CODEX_CELL := preload("res://scenes/ui/codex_cell.tscn")
const RELIC_ROW := preload("res://scenes/ui/relic_row.tscn")
const COLOR_MATRIX := preload("res://shaders/color_matrix.gdshader")
const WIDE := ["growth", "skills", "map"]

@export var tab_style: StyleBox
@export var tab_on_style: StyleBox
@export var tab_hover_style: StyleBox
@export var detail_btn_style: StyleBox

@onready var _tabs: HFlowContainer = $Frame/Lines/Body/Tabs
@onready var _scroll: ScrollContainer = $Frame/Lines/Body/Scroll
@onready var _list: VBoxContainer = $Frame/Lines/Body/Scroll/Center/List
@onready var _tree_page: Control = $Frame/Lines/Body/TreePage
@onready var _tree: TreeView = $Frame/Lines/Body/TreePage/TreeScroll/Tree
@onready var _map_page: Control = $Frame/Lines/Body/MapPage
@onready var _detail: HBoxContainer = $Frame/Lines/Body/Detail

var tab := "quests"
var _open_row = null     # 펼쳐 놓은 퀘스트 id
var _picked = null       # 나무에서 고른 마디 { kind: 'node' | 'skill', id }


func _ready() -> void:
	super()
	for b in _tabs.get_children():
		b.pressed.connect(func():
			tab = b.name
			_picked = null
			Sfx.play("ui")
			render())
	_tree.node_picked.connect(func(item):
		_picked = { kind = "node", id = item.id } if tab == "growth" else { kind = "skill", id = item }
		Sfx.play("ui")
		render())


## 판이 좁으면(휴대폰) 글 목록도 좁힌다. 넓을 때는 2D판처럼 760 에서 멈추고 가운데 둔다
func _layout() -> void:
	super()
	var f: Control = $Frame
	_list.custom_minimum_size.x = minf(760, f.offset_right - f.offset_left - 60)


## 일지를 열거나 닫는다. tab_id 를 주면 그 탭으로 연다
func toggle_tab(tab_id := "") -> void:
	if visible and (tab_id == "" or tab_id == tab):
		close()
		return
	if tab_id != "" and tab_id != tab:
		tab = tab_id
		_picked = null
	Tutorial.mark("journal")
	render()
	open()


## 열려 있으면 내용만 새로 그린다 (퀘스트 진행도가 바뀔 때)
func refresh() -> void:
	if visible: render()


func render() -> void:
	for b in _tabs.get_children():
		var on: bool = b.name == tab
		for s in ["normal", "pressed"]: b.add_theme_stylebox_override(s, tab_on_style if on else tab_style)
		b.add_theme_stylebox_override("hover", tab_on_style if on else tab_hover_style)
		b.add_theme_color_override("font_color", Color("#1a1206") if on else Color("#cdc4af"))
		b.add_theme_color_override("font_hover_color", Color("#1a1206") if on else Color("#ece3cf"))
	var pts: int = GameState.growth.get("points", 0)
	$Frame/Lines/Head/Extra/Points.text = "성장 포인트 %d" % pts if pts > 0 else ""
	var tree := tab == "growth" or tab == "skills"
	_scroll.visible = not tree and tab != "map"
	_tree_page.visible = tree
	_map_page.visible = tab == "map"
	_detail.visible = tree
	$Frame/Lines/Body/DetailRule.visible = tree
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	match tab:
		"quests": _render_quests()
		"map": $Frame/Lines/Body/MapPage/Map.queue_redraw()
		"bag": _render_bag()
		"folk": _render_folk()
		"skills": _render_skills()
		"growth": _render_growth()
		"relics": _render_relics()
		"codex": _render_codex()
		"record": _render_record()
		"sound": _render_sound()
	if tree: _render_picked()


func _section(title: String, rows: Array) -> JournalSection:
	var s: JournalSection = SECTION.instantiate()
	_list.add_child(s)
	return s.setup(title, rows)


func _note(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color("#a39a87"))
	_list.add_child(l)
	return l


# ---------- 퀘스트 ----------

func _render_quests() -> void:
	var groups := Quests.quest_log()
	if groups.is_empty(): _note("아직 맡은 일이 없다. 마을 용들에게 말을 걸어 보자.")
	for g in groups:
		_section(g.name, [])
		for r in g.rows:
			var row: QuestRow = QUEST_ROW.instantiate()
			_list.add_child(row)
			row.setup(r, _open_row == r.id)
			row.toggled_open.connect(func(id):
				_open_row = null if _open_row == id else id
				Sfx.play("ui")
				render())
			row.replay.connect(_replay)
			row.track.connect(func(id):
				Quests.set_tracked(id)
				Sfx.play("ui")
				render())
	# 게시판에서 떼어 온 잡일. 이야기와 섞이지 않게 맨 아래에 따로 둔다
	var chores := Chores.taken()
	if not chores.is_empty():
		_section("게시판 잡일", chores.map(func(c): return ["%s — %s" % [c.title, c.goal], "완료 · 게시판으로" if c.complete else c.text]))


## 일지를 닫고 그 장면을 다시 튼다 (컷씬 없이)
func _replay(title: String, scene: Array) -> void:
	close()
	Sfx.play("ui")
	Chronicle.play_scene(title, scene, null, false)


# ---------- 소지품 · 기록 · 소리 ----------

func _render_bag() -> void:
	var p = GameState.player
	var mats: Dictionary = Forge.mats()
	var rows := [["고기", "%d개" % p.inventory.meat], ["골드", "%dG" % p.gold]]
	if not GameState.den.get("built"): rows.append(["나뭇가지", "%d / 8 (둥지 재료)" % GameState.den.get("twigs", 0)])
	if p.carrying == "EGG": rows.append(["용의 알", "들고 있다 (내 굴 둥지 앞에서 [E]로 놓거나, 엘더에게 맡긴다)"])
	if GameState.eggSitting: rows.append(["맡긴 알", "엘더가 품는 중 (%d일 남음)" % maxi(0, 3 - (GameState.day - GameState.eggSitting.day))])
	_section("가진 것", rows)
	_section("대장간 재료", mats.keys().map(func(id): return [mats[id].name, "%d개" % Forge.mat_count(id), Forge.mat_count(id) == 0]))
	var F := Den.furniture()
	var furn := F.keys().filter(func(id): return Den.owned(id) > 0).map(func(id): return [F[id].name, "%d개" % Den.owned(id)])
	_section("굴 살림살이 (안 놓은 것)", furn if not furn.is_empty() else [["", "없다", true]])
	var worn := Relics.equipped().map(func(id): return [Relics.table()[id].name, "끼움"])
	_section("끼운 유물", worn if not worn.is_empty() else [["", "없다 (유물 탭에서 끼운다)", true]])


func _render_record() -> void:
	var kills: Dictionary = GameState.stats.get("kills", {})
	var total := 0
	for k in kills: total += int(kills[k])
	var chest_count := 0
	for id in World.maps(): chest_count += int(World.maps()[id].get("chests", 3)) if World.maps()[id].get("chests") != null else 3
	_section("기록", [
		["지낸 날", "%d일째" % GameState.day],
		["쓰러뜨린 적", str(total)],
		["막아낸 습격", "%d회" % (GameState.raid.count - (1 if GameState.raid.active else 0))],
		["연 보물상자", "%d / %d" % [GameState.openedChests.size(), chest_count]],
		["끝낸 퀘스트", str(GameState.quests.done.size())],
	])
	# 정체의 단서. 승급 의식과 사건에서 모인다
	var clues_def: Dictionary = Data.get_module("chronicle").CLUES
	var clues: Array = GameState.story.get("clues", []).filter(func(id): return clues_def.has(id))
	if not clues.is_empty():
		var rows := []
		for i in clues.size(): rows.append([str(i + 1), clues_def[clues[i]]])
		_section("비늘 아래의 무늬", rows)


func _render_sound() -> void:
	_section("음량", [
		["배경음", "%d" % roundi(Audio.music_volume() * 100)],
		["효과음", "%d" % roundi(Sfx.volume() * 100)],
		["소리 (O 키로 끄고 켠다)", "꺼짐" if Prefs.get_value("sound", "muted", false) else "켜짐"],
	])
	_note("음량은 [Esc] 설정 창에서 바꾼다.")
	_section("빌려 쓴 소리", [
		["배경음 15곡", "Music by Eric Matyas · www.soundimage.org"],
		["효과음 일부", "Kenney (CC0)"],
		["나머지 효과음", "코드로 그때그때 만든다"],
	])


# ---------- 마을 용들 ----------

func _render_folk() -> void:
	var t := GameState.dayTime * 24
	var hour := floori(t)
	var minute := floori(fmod(t, 1.0) * 60 / 10.0) * 10
	_section("%d일째 %02d:%02d · %s" % [GameState.day, hour, minute, NightEvents.day_phase_name()], [])
	# 달맞이 모임. 엘더가 첫 모임(m5g)을 알려 주기 전에는 모임이 있는 줄도 모르고,
	# 스무 해 끊겼던 모임은 그 첫 모임 때 다시 서므로 그 전에는 날짜를 세지 않는다 (여드레째 밤이 와도 아무도 가지 않는다)
	if Gathering.is_gather_day() or Gathering.invited_up():
		var moon := _note("")
		moon.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		if Gathering.is_gather_now():
			moon.text = "🌕 지금 구름 폭포에서 달맞이 모임이 열리고 있다. 두 마을 용들이 모두 내려와 있다."
			moon.add_theme_color_override("font_color", Color("#ffd84a"))
		elif not Gathering.invited_up(): moon.text = "🌕 오늘 밤, 스무 해 만에 달맞이 모임이 다시 선다. 해가 지면 구름 폭포 아래로."
		elif Gathering.is_gather_day(): moon.text = "🌕 오늘 밤이 달맞이 모임이다. 해가 지면 구름 폭포 아래로."
		else: moon.text = "🌘 다음 달맞이 모임까지 %d일. 달이 가장 밝은 밤이면 두 마을이 구름 폭포 아래에 모인다." % Gathering.days_to_gather()
	# 사이 단계는 대화창 머리 · 사이 장면 제목과 같은 문턱이다. 짝이 된 용만 '짝'
	var tiers := [[75, "절친"], [50, "친구"], [25, "아는 사이"], [0, "낯선 사이"]]
	for r in Routine.roster():
		if r.east and not Gathering.knows_cloudtop(): continue   # 아직 만나지 않은 마을의 용은 적지 않는다
		var card: PanelContainer = FOLK_CARD.instantiate()
		_list.add_child(card)
		var tier := "낯선 사이"
		for tt in tiers:
			if r.relation >= tt[0]:
				tier = tt[1]
				break
		if GameState.partner and GameState.partner.config.name == r.name: tier = "짝"
		card.get_node("Lines/Head/Name").text = r.label
		card.get_node("Lines/Head/Job").text = "%s · %s" % [r.job, tier]
		card.get_node("Lines/Where").text = ("📍 " if r.near else "") + r.where
		card.get_node("Lines/Doing").text = r.doing
		if r.near:
			var st: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
			st.border_color = Color("#ffd84a")
			st.bg_color = Color(1, 1, 1, 0.11)
			card.add_theme_stylebox_override("panel", st)
	_note("용마다 하루 일과가 있다. 시간과 날씨에 따라 있는 곳이 달라진다.")


# ---------- 유물 ----------

func _render_relics() -> void:
	var mx := Relics.slot_count()
	var table := Relics.table()
	var kins: Dictionary = Data.get_module("systems_relics").KINS
	var worn := Relics.equipped()
	_section("끼운 것 %d / %d칸" % [worn.size(), mx], [])
	var n1 := _note("가진 유물을 눌러 끼우고 뺀다. 몸이 자라면 끼울 수 있는 칸이 늘어난다 (어린 용 2칸 · 성체 3칸 · 고룡 4칸)." if mx < 4 else "가진 유물을 눌러 끼우고 뺀다. 끼운 것만 힘이 된다.")
	n1.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var n2 := _note("공명 — 같은 갈래를 둘 끼우면: " + " · ".join(kins.keys().map(func(k): return "%s %s (%s)" % ["◆" if Relics.resonates(k) else "◇", kins[k].name, kins[k].bonus])))
	n2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# 칸
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 5)
	_list.add_child(slots)
	var list := Relics.slots()
	for i in mx:
		var id = list[i]
		var cell := Button.new()
		cell.focus_mode = Control.FOCUS_NONE
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size.y = 38
		cell.text = table[id].name if id else "빈 칸"
		cell.add_theme_color_override("font_color", Color("#ffd84a") if id else Color("#a39a87"))
		cell.disabled = id == null
		if id: cell.pressed.connect(func():
			Relics.toggle(id)
			render())
		slots.add_child(cell)
	# 모은 것 (가진 것을 위로)
	var owned := table.keys().filter(func(id): return Relics.owns(id))
	_section("모은 유물 %d / %d" % [owned.size(), table.size()], [])
	var defs := Skills.defs()
	for id in owned:
		var r: Dictionary = table[id]
		var on := Relics.has(id)
		var row: Button = RELIC_ROW.instantiate()
		_list.add_child(row)
		var nm: String = ("[%s] " % defs[r.skill].name if r.get("skill") and defs.has(r.skill) else "") + ("%s · %s" % [r.name, kins[r.kin].name] if r.get("kin") else r.name)
		row.get_node("Row/Name").text = nm
		row.get_node("Row/Desc").text = r.desc
		row.tooltip_text = r.desc
		row.get_node("Row/State").text = "끼워 둠" if on else "끼우기"
		if on:
			row.get_node("Row/State").add_theme_color_override("font_color", Color("#ffd84a"))
			for s in ["normal", "hover", "pressed"]: row.add_theme_stylebox_override(s, row.get_meta("on_style"))
		row.pressed.connect(func():
			Relics.toggle(id)
			render())
	var missing := table.keys().filter(func(id): return not Relics.owns(id)).map(func(id): return ["???", "큰 용이 지니고 있다" if table[id].get("boss") else "상자·금빛 정예·옛 굴 깊은 곳에서", true])
	if not missing.is_empty(): _section("", missing)
	var mats := Forge.mats()
	_section("대장간 재료", mats.keys().map(func(k): return [mats[k].name, "%d개. %s" % [Forge.mat_count(k), mats[k].desc]]))


# ---------- 도감 ----------

func _render_codex() -> void:
	var kills: Dictionary = GameState.stats.get("kills", {})
	var enemies: Dictionary = Data.get_module("enemies").ENEMIES
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_list.add_child(grid)
	var sheet := TileImages.get_texture("dungeon")
	var cell := func(def, nm: String, sub: String, dim: bool) -> void:
		var c: PanelContainer = CODEX_CELL.instantiate()
		grid.add_child(c)
		c.custom_minimum_size.x = 102
		var face: TextureRect = c.get_node("Lines/Face")
		if def and def.get("sprite"):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(def.sprite[0] * 16, def.sprite[1] * 16, 16, 16)
			face.texture = at
			if def.get("filter"):
				var mat := ShaderMaterial.new()
				mat.shader = COLOR_MATRIX
				mat.set_shader_parameter("m", Enemy.filter_matrix(def.filter))
				face.material = mat
			if dim: face.modulate = Color(0, 0, 0, 0.35)   # 못 만난 놈은 실루엣만
		else: face.visible = false
		c.get_node("Lines/Name").text = nm
		c.get_node("Lines/Sub").text = sub
	for id in enemies:
		var def: Dictionary = enemies[id]
		if def.get("noLoot"): continue
		var met := kills.has(id)
		cell.call(def, def.name if met else "???", "%d마리" % kills[id] if met else "아직 만나지 못함", not met)
	var hunters: int = kills.get("HUNTER", 0)
	cell.call(null, "사냥꾼" if hunters else "???", "%d명" % hunters if hunters else "아직 만나지 못함", hunters == 0)
	var bosses: Dictionary = Data.get_module("enemies").BOSSES
	_section("큰 용들", bosses.keys().map(func(id): return [bosses[id].name, "처치"] if GameState.bossesDefeated.get(id) else ["???", bosses[id].get("title", ""), true]))


# ---------- 성장 · 스킬 나무 ----------

func _tree_note(title: String, text: String) -> void:
	$Frame/Lines/Body/TreePage/Note/Lines/Title.text = title
	$Frame/Lines/Body/TreePage/Note/Lines/Text.text = text


func _render_growth() -> void:
	var p = GameState.player
	var g: Dictionary = Data.get_module("growth")
	_tree_note("레벨 %d · %s" % [p.level, p.stage.name], "레벨이 오를 때마다 성장 포인트 2, 승급 시험을 넘을 때마다 3을 받는다. 위 칸일수록 더 자란 몸(어린 용·성체·고룡)이라야 찍을 수 있다. 마디를 눌러 조건과 효과를 본다.")
	var branches := []
	for key in g.BRANCHES:
		var b: Dictionary = g.BRANCHES[key]
		var tiers := []
		for t in 4: tiers.append(g.GROWTH_NODES.filter(func(n): return n.branch == key and n.tier == t))
		branches.append({ key = key, title = b.name, sub = b.get("sub", ""), color = b.color, tiers = tiers })
	_tree.build(branches, "%s · 레벨 %d" % [p.stage.name, p.level], func(node, _c):
		var st := Growth.node_status(node)
		var rank: int = st.rank
		return {
			rank = "%d/%d" % [rank, node.max], name = node.name,
			on = rank > 0, full = rank >= node.max, can = st.can, locked = rank == 0 and not st.can,
			sel = _picked != null and _picked.kind == "node" and _picked.id == node.id,
		})


func _render_skills() -> void:
	var p = GameState.player
	var sk: Dictionary = Data.get_module("skills")
	var defs: Dictionary = sk.SKILLS
	var slot_names: Array = sk.SKILL_SLOTS
	_tree_note("배운 스킬 %d / %d" % [p.skills.size(), defs.size()],
		"장착 %s. 마디를 눌러 장착하고 강화한다." % "  ".join(slot_names.map(func(s): return "[%s] %s" % [s, defs[p.slots[s]].name if p.slots.get(s) else "─"])))
	var branches := []
	for key in sk.SKILL_BRANCHES:
		var b: Dictionary = sk.SKILL_BRANCHES[key]
		var tiers := []
		for t in 4:
			var row: Array = defs.keys().filter(func(id): return defs[id].branch == key and defs[id].tier == t)
			if not row.is_empty(): tiers.append(row)
		branches.append({ key = key, title = b.name, sub = "", color = b.color, tiers = tiers })
	_tree.build(branches, "%d / %d 습득" % [p.skills.size(), defs.size()], func(id, _c):
		var rank := Skills.rank(id)
		var known := rank > 0
		var slot := ""
		for s in slot_names:
			if p.slots.get(s) == id: slot = s
		return {
			rank = "★".repeat(rank) if known else "?", name = defs[id].name if known else "???",
			on = known, full = known and Growth.skill_upgrade_cost(id) == null, locked = not known, slot = slot,
			sel = _picked != null and _picked.kind == "skill" and _picked.id == id,
		})


## 아직 못 배운 스킬을 어디서 얻는지
func _source_text(id: String) -> String:
	var defs := Skills.defs()
	var s: Dictionary = defs[id].source
	if s.type == "MASTER":
		for l in Data.get_module("story").LESSONS:
			if l.skill == id: return "스승 카이론: %s (레벨 %d)" % [l.title, l.level]
		return "스승 카이론의 수련"
	if s.type == "BOSS": return "%s 쓰러뜨리면" % Util.josa(Data.get_module("enemies").BOSSES.get(s.id, {}).get("name", s.id), "을", "를")
	if s.type == "AWAKEN": return "%s: %s" % [s.hint, " + ".join(s.need.map(func(n): return "%s %d단" % [defs[n[0]].name, n[1]]))]
	return s.get("hint", "")


## 나무 아래 자세히 보기 줄: 고른 마디의 설명과 단추
func _render_picked() -> void:
	var info_name: Label = $Frame/Lines/Body/Detail/Info/Name
	var info_text: Label = $Frame/Lines/Body/Detail/Info/Text
	var actions: HBoxContainer = $Frame/Lines/Body/Detail/Actions
	for c in actions.get_children():
		actions.remove_child(c)
		c.queue_free()
	if _picked == null or (_picked.kind == "node") != (tab == "growth"):
		info_name.text = ""
		info_text.text = "마디를 눌러 자세히 보고 성장 포인트를 쓴다."
		return
	if _picked.kind == "node":
		var node: Dictionary = Data.get_module("growth").NODES_BY_ID[_picked.id]
		var st := Growth.node_status(node)
		var rank := Growth.node_rank(node.id)
		info_name.text = "%s  %d / %d단" % [node.name, rank, node.max]
		info_text.text = node.desc.call(rank) if rank >= node.max else "지금 %s → 다음 단계 %s" % [node.desc.call(rank) if rank else "아직 찍지 않았다", node.desc.call(rank + 1)]
		if rank < node.max:
			_action("한 단 올리기 (포인트 %d)" % node.cost if st.can else st.reason, st.can, func():
				if Growth.invest_node(node.id): render())
	else:
		var id: String = _picked.id
		var def: Dictionary = Skills.defs()[id]
		var rank := Skills.rank(id)
		var cost = Growth.skill_upgrade_cost(id)
		info_name.text = "%s  %d / %d단" % [def.name, rank, Data.get_module("skills").MAX_SKILL_RANK] if rank else "%s (아직 못 배움)" % def.name
		info_text.text = "%s · 재사용 대기 %.1f초" % [def.desc, Skills.cooldown(id)] if rank else _source_text(id)
		if rank:
			for s in Data.get_module("skills").SKILL_SLOTS:
				var on: bool = GameState.player.slots.get(s) == id
				var b := _action("[%s] 해제" % s if on else "[%s]에 끼우기" % s, true, func():
					_equip(id, s, on)
					render())
				if on: b.add_theme_color_override("font_color", Color("#7dd36a"))
			if cost != null: _action("강화 %d단 (포인트 %d)" % [rank + 1, cost], true, func():
				if Growth.upgrade_skill(id): render())
			else:
				var l := Label.new()
				l.text = "끝까지 익힌 스킬이다"
				l.add_theme_color_override("font_color", Color("#a39a87"))
				actions.add_child(l)


func _action(label: String, enabled: bool, fn: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	if enabled:
		for s in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(s, detail_btn_style)
		b.pressed.connect(fn)
	else: b.disabled = true
	$Frame/Lines/Body/Detail/Actions.add_child(b)
	return b


func _equip(id: String, slot: String, unequip: bool) -> void:
	var p = GameState.player
	if unequip:
		p.slots[slot] = null
		return
	for s in Data.get_module("skills").SKILL_SLOTS:   # 이미 장착된 스킬이면 자리를 맞바꾼다
		if p.slots.get(s) == id: p.slots[s] = p.slots.get(slot)
	p.slots[slot] = id
	Sfx.play("ui")
