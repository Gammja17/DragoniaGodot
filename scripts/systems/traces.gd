class_name Traces
## 하늘에서만 보이는 옛 흔적. 걸어서는 바닥돌의 금 · 흙에 묻힌 돌 · 풀숲의 구멍일 뿐인 것이, 날아올라 내려다보면 모양이 된다.
## 날고 있을 때만 바닥에 그려지고, 그 한가운데를 날아 지나가면 살펴본다 (속말 몇 줄 · 일지 [기록]의 "하늘에서 본 것").
## 새 수수께끼는 만들지 않는다. 이미 있는 이야기를 미리 깔거나 뒤에서 받친다 (설정집 "하늘에서만 보이는 옛 흔적").
##   GameState.story.traces = [id, ...] (찾은 차례)

const FLAT := 0.62        # 바닥에 누운 모양의 납작한 정도
const FIND_R := 120.0     # 흔적 한가운데서 이만큼 안으로 날아 지나가면 살펴본다
const XP := 60

## at: 한가운데 (px) · r: 크기 (px) · later: 그 이야기를 들은 뒤로 일지에 덧붙는 짐작
const LIST := [
	{ id = "fall", map = "VILLAGE", at = [1632, 1428], shape = "CRACK", r = 150.0, title = "광장의 금",
	  lines = ["(위에서 보니 광장 바닥돌에 금이 한 점에서 사방으로 뻗어 있다. 걸어 다닐 때는 그냥 낡은 돌인 줄 알았다.)",
		"(내가 떨어진 자리다. 꽤 세게 떨어졌구나.)"],
	  note = "광장 바닥돌의 금. 내가 떨어진 자리다." },
	{ id = "old_fall", map = "DOJO", at = [912, 624], shape = "OLD_CRACK", r = 330.0, title = "수련장 마당",
	  lines = ["(위에서 보니 수련장 마당이 둥글게 움푹하다. 흙 밑으로 금이 한 점에서 사방으로 뻗어 나간 자국이 있다.)",
		"(광장의 내 자리와 똑같은 모양이다. 다만 훨씬 오래돼서, 금마다 풀이 자라 있다.)"],
	  heard = { quest = "p1", yes = "(엘더가 오래전에 하늘에서 떨어진 아이가 하나 있었다고 했다. …여기였을까.)",
		no = "(아주 오래전에 여기에도 뭔가 떨어졌다.)" },
	  note = "마당이 둥글게 움푹하고, 흙 밑으로 광장의 내 자리와 같은 모양의 금이 있다. 아주 오래됐다.",
	  later = { quest = "m5c", note = "스승님은 하늘에서 떨어진 형을 부모님이 거둬 길렀다고 했다. 이 마당이 그 자리였을까." } },
	{ id = "dens", map = "HOLLOW", at = [788, 1200], shape = "DENS", r = 260.0, title = "옛 굴 마을",
	  lines = ["(굴 입구 여남은 개가 둥글게 한가운데 마당을 보고 있다. 걸어서는 풀숲 여기저기 난 구멍일 뿐이었다.)",
		"(여기도 예전엔 마을이었구나. 그중 하나는 옛 굴로 이어진다.)"],
	  note = "달빛 골짜기의 굴 입구들이 둥글게 한 마당을 보고 있다. 예전엔 마을이었다." },
	{ id = "circle", map = "FALLS", at = [912, 1008], shape = "STONES", r = 200.0, title = "폭포 아래 둥근 돌",
	  lines = ["(모닥불 자리를 둘러 납작한 돌이 둥글게 박혀 있다. 흙에 반쯤 묻혀서 걸어서는 몰랐다.)",
		"(폭포 쪽 절반은 흰 돌, 아랫마을 쪽 절반은 잿빛 돌이다. 두 마을이 마주 앉던 자리 같다.)"],
	  note = "모닥불을 두른 돌. 폭포 쪽은 흰 돌, 아랫마을 쪽은 잿빛 돌이다.",
	  later = { event = "ev_gathering", note = "달맞이 모임 자리였다. 스무 해 만에 두 마을이 다시 둘러앉았다." } },
	{ id = "shadow", map = "ASH_CITY", at = [1008, 560], shape = "SHADOW", r = 240.0, title = "그을리지 않은 자리",
	  lines = ["(도시 북쪽 어귀에, 거기만 그을리지 않은 땅이 있다. 날개를 활짝 편 커다란 용 모양이다.)",
		"(불길이 휩쓸 때 누군가 여기 엎드려 있었던 거다. 도시를 등지고.)",
		"(모르가스가 예순 해 전에 끝내 막지 못했다는 그날… 그게 여기였을까.)"],
	  note = "도시 북쪽 어귀, 날개를 편 용 모양으로 그을리지 않은 땅. 누군가 도시를 등지고 엎드려 있던 자리." },
]

## 불탄 도시의 그림자: 북쪽을 보고 엎드린 용 (반쪽만 적고 좌우로 뒤집어 잇는다. 머리 y = -1, 꼬리 끝 y = 1)
const _HALF := [[0.0, -1.0], [0.07, -0.88], [0.06, -0.7], [0.12, -0.5], [0.16, -0.44], [0.55, -0.74], [0.98, -0.56],
	[0.8, -0.34], [0.7, -0.42], [0.56, -0.2], [0.45, -0.3], [0.3, -0.06], [0.16, -0.04], [0.14, 0.16], [0.07, 0.46], [0.03, 0.8]]

static var _geo := {}      # id → 미리 그어 둔 금 (그릴 때마다 흔들리지 않게)
static var _show := 0.0    # 날아오르면 천천히 드러나고, 내려앉으면 스러진다


static func found(id: String) -> bool: return GameState.story.get("traces", []).has(id)


static func found_count() -> int:
	return LIST.filter(func(t): return found(t.id)).size()


## 아직 못 찾은 흔적이 이 지도에서 가까이 보이는가 (처음 하는 사람 안내)
static func near_unfound(dist: float) -> bool:
	var p = GameState.player
	for t in LIST:
		if t.map == GameState.map_id and not found(t.id) and Vector2(p.x - t.at[0], p.y - t.at[1]).length() < dist: return true
	return false


## 매 프레임 (main): 드러나고 스러지기 · 한가운데를 날아 지나가면 살펴본다
static func update(dt: float) -> void:
	var p = GameState.player
	if not p: return
	_show = move_toward(_show, 1.0 if p.flying else 0.0, dt * 2.5)
	if not p.flying or GameState.activity or GameState.isDialogueOpen or Cutscene.on or GameState.dungeon: return
	for t in LIST:
		if t.map != GameState.map_id or found(t.id): continue
		if Vector2(p.x - t.at[0], p.y - t.at[1]).length() < FIND_R:
			_find(t)
			return


static func _find(t: Dictionary) -> void:
	var list: Array = GameState.story.get("traces", [])
	list.append(t.id)
	GameState.story.traces = list
	GameState.player.gain_xp(XP)
	Sfx.play("relic")
	var lines: Array = t.lines.duplicate()
	if t.get("heard"): lines.append(t.heard.yes if GameState.quests.done.has(t.heard.quest) else t.heard.no)
	Chronicle.play_scene("", lines.map(func(s): return { who = "나", text = s }), func():
		Hud.pop("하늘에서 본 것 %d / %d: %s. 일지 [기록]에 적어 두었다." % [list.size(), LIST.size(), t.title], "🪶")
		Save.save_game(), false)


## 일지에 적는 말. 뒤에 이어지는 이야기를 들었으면 짐작을 덧붙인다
static func note_of(t: Dictionary) -> String:
	var l = t.get("later")
	if l and (GameState.quests.done.has(l.get("quest", "")) or GameState.story.get("events", []).has(l.get("event", ""))):
		return "%s %s" % [t.note, l.note]
	return t.note


## 일지 [기록]의 "하늘에서 본 것". 못 찾은 것은 가 본 곳이면 어디쯤인지만
static func journal_rows() -> Array:
	var rows := []
	for t in LIST:
		if found(t.id): rows.append([t.title, note_of(t)])
		elif GameState.visited.has(t.map): rows.append(["???", "%s 어딘가. 위에서 내려다봐야 보인다." % Names.map(t.map), true])
		else: rows.append(["???", "아직 가 보지 못한 곳", true])
	return rows


# ---------- 그리기 (바닥 층, 개체들 밑. 날 때만) ----------

static func draw(ci: CanvasItem) -> void:
	if _show <= 0.01 or Cutscene.on: return
	for t in LIST:
		if t.map != GameState.map_id: continue
		var c := Vector2(t.at[0], t.at[1])
		var a := _show
		match t.shape:
			"CRACK": _draw_crack(ci, t, c, a, false)
			"OLD_CRACK": _draw_crack(ci, t, c, a, true)
			"DENS": _draw_dens(ci, t, c, a)
			"STONES": _draw_stones(ci, t, c, a)
			"SHADOW": _draw_shadow(ci, t, c, a)
		if not found(t.id): _draw_glint(ci, c, a)


static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	ci.draw_set_transform(c, 0, Vector2(1, ry / rx))
	ci.draw_circle(Vector2.ZERO, rx, col)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## 한 점에서 사방으로 뻗은 금. old 면 풀이 자란 오래된 금과 움푹한 테두리
static func _draw_crack(ci: CanvasItem, t: Dictionary, c: Vector2, a: float, old: bool) -> void:
	var r: float = t.r
	if old:
		ci.draw_set_transform(c, 0, Vector2(1, FLAT))
		ci.draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(0, 0, 0, 0.14 * a), 12)
		ci.draw_arc(Vector2.ZERO, r - 9, 0, TAU, 64, Color(1, 1, 1, 0.08 * a), 4)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	else:
		_ellipse(ci, c, r * 0.3, r * 0.3 * FLAT, Color(0.1, 0.07, 0.05, 0.35 * a))
	var col := Color(0.14, 0.2, 0.08, 0.75 * a) if old else Color(0.13, 0.09, 0.06, 0.8 * a)
	for line in _cracks(t):
		var pts: Array = line
		for j in range(1, pts.size()):
			var w := lerpf(4.0, 1.2, float(j) / pts.size())
			var p0 := c + Vector2(pts[j - 1].x, pts[j - 1].y * FLAT)
			var p1 := c + Vector2(pts[j].x, pts[j].y * FLAT)
			ci.draw_line(p0, p1, col, w)
			if old: ci.draw_line(p0 + Vector2(1, -2), p1 + Vector2(1, -2), Color(0.42, 0.6, 0.24, 0.45 * a), 1.5)   # 금을 따라 자란 풀


## 금은 한 번만 긋는다 (흔적마다 늘 같은 모양)
static func _cracks(t: Dictionary) -> Array:
	if _geo.has(t.id): return _geo[t.id]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(t.id)
	var out := []
	var n := 13
	for i in n:
		var dir := TAU * i / n + rng.randf_range(-0.18, 0.18)
		var reach: float = t.r * rng.randf_range(0.55, 1.0)
		var cur := Vector2.ZERO
		var pts := [cur]
		for s in 5:
			dir += rng.randf_range(-0.35, 0.35)
			cur += Vector2(cos(dir), sin(dir)) * reach / 5.0
			pts.append(cur)
			if s == 2 and rng.randf() < 0.6:   # 곁가지
				var b := dir + rng.randf_range(0.5, 0.9) * (1.0 if rng.randf() < 0.5 else -1.0)
				out.append([cur, cur + Vector2(cos(b), sin(b)) * reach * 0.25])
		out.append(pts)
	_geo[t.id] = out
	return out


## 둥글게 한 마당을 보는 굴 입구들. 서쪽 하나는 옛 굴(달빛 골짜기의 굴 입구)이라 그리지 않는다
static func _draw_dens(ci: CanvasItem, t: Dictionary, c: Vector2, a: float) -> void:
	var r: float = t.r
	_ellipse(ci, c, r * 0.5, r * 0.5 * FLAT, Color(0.95, 0.9, 0.75, 0.08 * a))   # 다져진 마당
	var n := 10
	for i in n:
		var ang := TAU * i / n
		if i * 2 == n: continue
		var m := c + Vector2(cos(ang) * r, sin(ang) * r * FLAT)
		for k in range(1, 4):   # 마당으로 나 있던 발길
			_ellipse(ci, m.lerp(c, k * 0.2), 6, 4, Color(0, 0, 0, 0.1 * a))
		_ellipse(ci, m, 38, 22, Color(0.38, 0.32, 0.25, 0.35 * a))   # 입구 둘레의 흙
		_ellipse(ci, m + Vector2(0, 2), 29, 15, Color(0.04, 0.03, 0.05, 0.8 * a))


## 모닥불을 두른 납작한 돌. 폭포 쪽(위) 절반은 흰 돌, 아랫마을 쪽(아래) 절반은 잿빛 돌
static func _draw_stones(ci: CanvasItem, t: Dictionary, c: Vector2, a: float) -> void:
	var r: float = t.r
	var n := 16
	for i in n:
		var ang := TAU * (i + 0.5) / n
		var s := c + Vector2(cos(ang) * r, sin(ang) * r * FLAT)
		var col := Color("#e9f0f4") if sin(ang) < 0 else Color("#8d9097")
		_ellipse(ci, s + Vector2(3, 4), 16, 9, Color(0, 0, 0, 0.25 * a))
		_ellipse(ci, s, 15, 8.5, Color(col, 0.9 * a))
		_ellipse(ci, s + Vector2(-4, -2), 6, 3, Color(1, 1, 1, 0.25 * a))


## 그을린 땅 한가운데, 날개를 편 용 모양으로 그을리지 않은 자리 (북쪽을 보고 엎드렸다)
static func _draw_shadow(ci: CanvasItem, t: Dictionary, c: Vector2, a: float) -> void:
	var r: float = t.r
	_ellipse(ci, c, r * 1.25, r * 1.25 * FLAT, Color(0, 0, 0, 0.22 * a))   # 둘레의 그을음
	var pts := PackedVector2Array()
	for q in _HALF: pts.append(c + Vector2(q[0] * r, q[1] * r * FLAT))
	pts.append(c + Vector2(0, r * FLAT))   # 꼬리 끝
	for i in range(_HALF.size() - 1, 0, -1): pts.append(c + Vector2(-_HALF[i][0] * r, _HALF[i][1] * r * FLAT))
	ci.draw_colored_polygon(pts, Color(0.78, 0.71, 0.6, 0.42 * a))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(0.55, 0.48, 0.4, 0.5 * a), 2)


## 아직 살펴보지 않은 흔적 한가운데서 반짝임 (날아가 볼 곳)
static func _draw_glint(ci: CanvasItem, c: Vector2, a: float) -> void:
	var k := 0.55 + sin(GameState.game_time * 3.0) * 0.45
	var col := Color(1, 0.95, 0.75, 0.8 * k * a)
	var s := 10.0 + 6.0 * k
	ci.draw_line(c + Vector2(-s, 0), c + Vector2(s, 0), col, 2)
	ci.draw_line(c + Vector2(0, -s), c + Vector2(0, s), col, 2)
