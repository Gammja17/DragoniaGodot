class_name Guide
## 2D판 systems/guide.js. 퀘스트 길잡이.
##
## 처음 하는 사람은 "티아맷에게 묻는다"는 글만 보고는 티아맷이 누군지, 어디 있는지 모른다.
## 지금 대목이 가리키는 곳을 찾아서:
##   · 그 용(또는 그 자리) 머리 위에 금빛 화살표를 띄운다
##   · 화면 밖이면 가장자리에 방향 화살표를 띄운다
##   · 추적창을 누르면 그곳까지 알아서 걸어간다 (아무 방향키나 누르면 멈춘다)
## 딴 지도에 있으면 그 지도로 가는 문(포탈)을 가리킨다. 문을 넘으면 다음 문을 가리킨다.
##
## 얼마나 알려 줄까: 'main' 본 이야기만 (기본) · 'all' 맡은 일 전부 · 'off' 끔

const LEVELS := { "main": "본 이야기만", "all": "맡은 일 전부", "off": "끔" }
const CELL := 32

static var _level := ""
static var _cache = null
static var _cache_at := -1.0
static var _cache_map := ""


static func level() -> String:
	if _level == "":
		var v: String = Prefs.get_value("guide", "level", "main")
		_level = v if LEVELS.has(v) else "main"
	return _level


static func set_level(v: String) -> void:
	_level = v
	Prefs.set_value("guide", "level", v)
	_cache_at = -1.0


static func cycle_level() -> String:
	var keys := LEVELS.keys()
	set_level(keys[(keys.find(level()) + 1) % keys.size()])
	return LEVELS[_level]


## 지도 사이의 길. 지금 지도에서 dest 로 가려면 먼저 어느 지도로 넘어가야 하는지
static func _next_hop(from: String, dest: String):
	if from == dest: return null
	var prev := { from: null }
	var queue := [from]
	var maps := World.maps()
	while not queue.is_empty():
		var id: String = queue.pop_front()
		for p in (maps[id].get("portals", []) if maps.has(id) else []):
			var to: String = p.to
			if prev.has(to): continue
			if to != dest and not Chapters.map_open(GameState, to): continue   # 아직 닫힌 길로는 돌아가지 않는다
			prev[to] = id
			if to == dest:
				var cur := dest
				while prev[cur] != from: cur = prev[cur]
				return cur
			queue.append(to)
	return null


## 그 용의 집 (일과가 없는 용은 지도 명세의 자리)
static func _home_of(nm: String):
	for id in World.maps():
		for f in World.maps()[id].get("fixtures", []):
			if f.t == "NPC" and f.name == nm:
				var p := World.at(f.at)
				return { map = id, x = p.x, y = p.y }
	return null


static func _boss_place(id: String):
	for mid in World.maps():
		for f in World.maps()[mid].get("fixtures", []):
			if f.t == "BOSS" and f.id == id:
				var p := World.at(f.at)
				# 모르가스의 무덤 · 쌍두룡의 둥지가 '결투장'일 리 없다. 가리키는 보스의 이름을 단다
				return { map = mid, x = p.x, y = p.y, label = Data.get_module("enemies").BOSSES.get(id, {}).get("name", Names.map(mid)) }
	return null


## 지금 대목이 가리키는 곳 { map, x, y, label, who }
static func _wanted():
	if level() == "off": return null
	var q = Quests.tracked_quest()
	var who = null
	var place = null
	if q:
		if level() == "main" and q.get("act") != "main": return null   # 곁가지는 스스로 찾는다
		if Quests.is_complete(q): who = Quests.turn_in_npc(q)
		else:
			var st: Dictionary = Quests.cur_step(q)
			var g: Dictionary = st.goal
			if st.get("discover"): return null                          # 이 대목은 일부러 안 가리킨다
			if st.get("where"):
				var p := World.at(st.where.spot)
				place = { map = st.where.map, x = p.x, y = p.y, label = st.where.get("label", "") }
			elif g.type == "talk" or g.type == "bring": who = g.target
			elif g.type == "visit": place = { map = g.target }
			elif g.type == "boss": place = _boss_place(g.id)
			elif g.type == "tour": who = "Poco"
			elif g.type == "stage": who = "Kairon"
			elif g.type == "delve":
				var cave = null
				for pr in GameState.entities.props:
					if pr.type == "CAVE": cave = pr
				place = { map = GameState.map_id, x = cave.x, y = cave.y, label = "굴 입구" } if cave else { map = "EAST_ROAD" }
			elif (g.type == "kill" or g.type == "killAny" or g.type == "elite") and (GameState.map_id == "VILLAGE" or GameState.map_id == "DOJO"):
				place = { map = "EAST_ROAD", label = "사냥터" }
	else:
		var s = Quests.suggestion()
		if s and s.get("who") and s.get("main"): who = s.who   # 곁가지 부탁은 누가 줄지 귀띔만 하고 가리키지는 않는다
		elif s and s.get("place") and s.get("main"): place = { map = s.place }   # 저절로 열리는 이야기는 그 지도로 가는 문을 가리킨다
	if who:
		for n in GameState.entities.npcs:
			if n.config.get("name") == who and not n.remove and not n.is_hidden:
				return { map = GameState.map_id, x = n.x, y = n.y, entity = n, label = Names.npc(who), who = who }
		var plan = Routine.plan_for(who)
		if not plan: plan = _home_of(who)
		if not plan: return null
		place = { map = plan.map, x = plan.x, y = plan.y, label = Names.npc(who), who = who }
		# 굴 안에 있으면 그 굴의 입구를 가리킨다
		if World.dens().has(place.map):
			var d: Dictionary = World.dens()[place.map]
			var p := World.at(d.at)
			place = { map = d.outer, x = p.x, y = p.y, label = "%s · %s" % [Names.npc(who), d.name], who = who }
	return place


## 화살표를 띄울 곳 (지금 지도 위의 좌표). 없으면 null
##   { x, y, label, entity?, far: 딴 지도로 가는 문인가, dest: 최종 목적지 지도 }
static func target():
	if not GameState.player or GameState.prologue or GameState.dungeon: return null
	if GameState.game_time - _cache_at < 0.4 and _cache_at >= 0 and _cache_map == GameState.map_id: return _cache
	_cache_at = GameState.game_time
	_cache_map = GameState.map_id
	_cache = _compute()
	return _cache


static func _compute():
	var w = _wanted()
	if not w: return null
	if w.map == GameState.map_id:
		if w.get("x") == null: return null
		return { x = w.x, y = w.y, label = w.get("label", ""), entity = w.get("entity"), far = false, dest = w.map }
	var hop = _next_hop(GameState.map_id, w.map)
	if not hop: return null
	var gate = null
	for p in GameState.entities.props:
		if p.portal and p.portal.to == hop: gate = p
	if not gate: return null
	var dest: String = "%s · %s" % [Names.npc(w.who), Names.map(w.map)] if w.get("who") else Names.map(w.map)
	return { x = gate.x, y = gate.y, label = "%s 쪽" % dest, entity = gate, far = true, dest = w.map }


# ---------- 그리기 ----------

## 목표 위의 화살표 (월드 좌표 층 안에서, 크기는 줌과 무관하게)
static func draw_marker(ci: CanvasItem, zoom: float) -> void:
	var t = target()
	if not t or GameState.isDialogueOpen: return
	var p = GameState.player
	if Vector2(p.x - t.x, p.y - t.y).length() < 90 and not t.far: return   # 다 왔으면 치운다
	var ent = t.entity
	var is_npc: bool = ent != null and ent is Dragon
	var lift := 150.0 if is_npc else 170.0 if ent != null and ent.get("portal") else 96.0
	var bob := sin(GameState.game_time * 5) * 6
	ci.draw_set_transform(Vector2(roundf(t.x), roundf(t.y - lift + bob)), 0, Vector2.ONE / zoom)
	var arrow := PackedVector2Array([Vector2(0, 14), Vector2(-13, -4), Vector2(-5, -4), Vector2(-5, -18), Vector2(5, -18), Vector2(5, -4), Vector2(13, -4)])
	# 테두리를 먼저 긋고 안을 채운다 (2D판 stroke → fill)
	var ring := arrow.duplicate()
	ring.append(arrow[0])
	ci.draw_polyline(ring, Color(30 / 255.0, 20 / 255.0, 0, 0.85), 3)
	ci.draw_colored_polygon(arrow, Color("#ffd84a"))
	if t.label and not is_npc:   # 용은 이름표가 있으니 이름을 또 쓰지 않는다
		var font := Fonts.bold()
		var tw := ceilf(Fonts.text_width(font, t.label, 12)) + 14
		ci.draw_rect(Rect2(-tw / 2, -40, tw, 19), Color(10 / 255.0, 9 / 255.0, 16 / 255.0, 0.85))
		Fonts.draw_centered(ci, font, t.label, 0, -26, 12, Color("#ffd84a"))
	ci.draw_set_transform(Vector2.ZERO)


## 화면 밖이면 가장자리에 방향 화살표 (화면 좌표 층에서)
static func draw_edge(ci: CanvasItem, w: float, h: float) -> void:
	var t = target()
	if not t or GameState.isDialogueOpen or Cutscene.on: return
	var cam := GameCamera.current
	var z: float = cam.zoom.x
	var s := Vector2((t.x - cam.cam_x) * z, (t.y - 40 - cam.cam_y) * z)
	var pad := 74.0
	if s.x > pad and s.x < w - pad and s.y > pad and s.y < h - pad: return
	var cx := w / 2
	var cy := h / 2
	var ang := atan2(s.y - cy, s.x - cx)
	# 화면 안쪽 사각형 테두리에 붙인다
	var hw := cx - pad
	var hh := cy - pad
	var k := minf(hw / maxf(absf(cos(ang)), 1e-6), hh / maxf(absf(sin(ang)), 1e-6))
	var x := cx + cos(ang) * k
	var y := cy + sin(ang) * k
	var beat := 0.75 + sin(GameState.game_time * 6) * 0.25
	ci.draw_set_transform(Vector2(x, y), ang)
	var tri := PackedVector2Array([Vector2(18, 0), Vector2(-10, -13), Vector2(-4, 0), Vector2(-10, 13)])
	var ring := tri.duplicate()
	ring.append(tri[0])
	ci.draw_polyline(ring, Color(30 / 255.0, 20 / 255.0, 0, 0.85 * beat), 3)
	ci.draw_colored_polygon(tri, Color(1, 216 / 255.0, 74 / 255.0, beat))
	ci.draw_set_transform(Vector2.ZERO)
	if t.label:
		var font := Fonts.bold()
		var tw := ceilf(Fonts.text_width(font, t.label, 12)) + 14
		var lx := maxf(tw / 2 + 4, minf(w - tw / 2 - 4, x - cos(ang) * 40))
		var ly := maxf(24, minf(h - 8, y - sin(ang) * 40 + 5))
		ci.draw_rect(Rect2(lx - tw / 2, ly - 14, tw, 19), Color(10 / 255.0, 9 / 255.0, 16 / 255.0, 0.85))
		Fonts.draw_centered(ci, font, t.label, lx, ly, 12, Color("#ffd84a"))


# ---------- 자동 이동 ----------
# GameState.nav = { map, path: [Vector2], i, stuck, lx, ly, far }

## 격자 위에서 길을 찾는다 (너비 우선). 못 찾으면 곧장 가는 한 점짜리 길
static func _find_path(from: Vector2, to: Vector2) -> Array:
	var b := Terrain.current_map_bounds()
	var cols := ceili(b.x / CELL)
	var rows := ceili(b.y / CELL)
	var cx := func(x: float) -> int: return clampi(floori(x / CELL), 0, cols - 1)
	var cy := func(y: float) -> int: return clampi(floori(y / CELL), 0, rows - 1)
	var sx: int = cx.call(from.x)
	var sy: int = cy.call(from.y)
	var tx: int = cx.call(to.x)
	var ty: int = cy.call(to.y)
	var free := PackedByteArray()
	free.resize(cols * rows)
	for yy in rows:
		for xx in cols:
			free[yy * cols + xx] = 0 if Collision.solid_at(xx * CELL + CELL / 2.0, yy * CELL + CELL / 2.0, 14) else 1
	free[sy * cols + sx] = 1
	# 목표 칸이 막혀 있으면(용이 소품 위에 서 있거나) 그 둘레의 빈 칸으로 간다
	var goal := ty * cols + tx
	if not free[goal]:
		var found_goal := false
		for r in range(1, 5):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var gx := tx + dx
					var gy := ty + dy
					if gx < 0 or gy < 0 or gx >= cols or gy >= rows or not free[gy * cols + gx]: continue
					goal = gy * cols + gx
					found_goal = true
					break
				if found_goal: break
			if found_goal: break
	var prev := PackedInt32Array()
	prev.resize(cols * rows)
	prev.fill(-1)
	var start := sy * cols + sx
	prev[start] = start
	var queue := [start]
	var head := 0
	var found := start == goal
	var dirs := [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]
	while head < queue.size() and not found:
		var cur: int = queue[head]
		head += 1
		var x := cur % cols
		var y := (cur - x) / cols
		for d in dirs:
			var nx: int = x + d[0]
			var ny: int = y + d[1]
			if nx < 0 or ny < 0 or nx >= cols or ny >= rows: continue
			var n := ny * cols + nx
			if not free[n] or prev[n] >= 0: continue
			if d[0] and d[1] and not (free[y * cols + nx] and free[ny * cols + x]): continue   # 모서리를 비스듬히 뚫지 않는다
			prev[n] = cur
			if n == goal:
				found = true
				break
			queue.append(n)
	if not found: return [to]
	var cells := []
	var c := goal
	while c != start:
		cells.append(c)
		c = prev[c]
	cells.reverse()
	var pts := cells.map(func(cc): return Vector2((cc % cols) * CELL + CELL / 2.0, floori(cc / float(cols)) * CELL + CELL / 2.0))
	# 곧장 보이는 점까지는 건너뛴다 (격자 계단을 따라 지그재그로 걷지 않게)
	var out := []
	var i := 0
	while i < pts.size():
		var j := pts.size() - 1
		while j > i + 1 and not _clear(from if i == 0 else pts[i], pts[j]): j -= 1
		out.append(pts[j])
		i = j
		if j == pts.size() - 1: break
	if out.is_empty(): out.append(to)
	out[-1] = to
	return out


static func _clear(a: Vector2, b: Vector2) -> bool:
	var n := ceili(a.distance_to(b) / 14)
	for i in range(1, n):
		var t := i / float(n)
		if Collision.solid_at(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, 16): return false
	return true


static func _plan() -> bool:
	var t = target()
	if not t:
		GameState.nav = null
		return false
	var p = GameState.player
	GameState.nav = { map = GameState.map_id, path = _find_path(Vector2(p.x, p.y), Vector2(t.x, t.y)), i = 0, stuck = 0.0, lx = p.x, ly = p.y, far = t.far }
	return true


## 추적창을 눌렀을 때. 이미 가는 중이면 멈춘다
static func toggle_auto_nav() -> void:
	if GameState.nav:
		cancel_nav()
		Hud.pop("자동 이동을 멈췄다.", "🧭")
		return
	var t = target()
	if not t:
		Hud.pop("지금은 가리킬 곳이 없다.", "🧭")
		return
	if GameState.player.flying:
		Hud.pop("날고 있을 땐 알아서 걸어갈 수 없다.", "🧭")
		return
	if _plan(): Hud.pop("%s 쪽으로 걸어간다. 직접 움직이면 멈춘다." % (t.label if t.label else "목표"), "🧭")


static func cancel_nav() -> void: GameState.nav = null


## 이번 프레임의 이동 방향 (Dragon 이 방향키 대신 쓴다). 안 가는 중이면 Vector2.ZERO.
## 지도를 넘어가면 다음 문을 향해 길을 다시 찾는다.
static func nav_axis(p, dt: float, depth := 0) -> Vector2:
	var nav = GameState.nav
	if not nav or depth > 4: return Vector2.ZERO
	if GameState.isDialogueOpen or GameState.activity or p.flying or p.fishing:
		cancel_nav()
		return Vector2.ZERO
	if nav.map != GameState.map_id:   # 문을 넘었다. 다음 문(또는 목적지)으로
		if not _plan(): return Vector2.ZERO
		return nav_axis(p, dt, depth + 1)
	var t = target()
	# 목표가 움직이는 용이면 도착점을 따라 다시 잡는다
	if t and t.entity is Dragon and not nav.path.is_empty():
		var last: Vector2 = nav.path[-1]
		if last.distance_to(Vector2(t.x, t.y)) > 120:
			_plan()
			return nav_axis(p, dt, depth + 1)
	if nav.i >= nav.path.size():
		cancel_nav()
		return Vector2.ZERO
	var wp: Vector2 = nav.path[nav.i]
	var dv := wp - Vector2(p.x, p.y)
	var d := dv.length()
	var last_leg: bool = nav.i == nav.path.size() - 1
	if d < ((20.0 if nav.far else 70.0) if last_leg else 26.0):
		nav.i += 1
		if nav.i >= nav.path.size():
			cancel_nav()
			if not nav.far: Hud.pop("다 왔다.", "🧭")
			return Vector2.ZERO
		return nav_axis(p, dt, depth + 1)
	# 제자리걸음이면 길을 다시 찾고, 그래도 안 되면 포기한다
	var moved := Vector2(p.x - nav.lx, p.y - nav.ly).length()
	nav.lx = p.x
	nav.ly = p.y
	nav.stuck = nav.stuck + dt if moved < 0.5 else 0.0
	if nav.stuck > 1.2:
		if nav.get("replanned"):
			cancel_nav()
			Hud.pop("길이 막혀 있다. 직접 가 보자.", "🧭")
			return Vector2.ZERO
		var ok := _plan()
		if GameState.nav: GameState.nav.replanned = true
		return nav_axis(p, dt, depth + 1) if ok else Vector2.ZERO
	return dv / d
