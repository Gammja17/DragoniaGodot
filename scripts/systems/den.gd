class_name Den
## 2D판 systems/den.js · denEnter.js · denPlace.js. 굴과 굴 꾸미기.
##
##  GameState.furniture   가지고 있는 살림살이 { 가구id: 개수 }
##  GameState.denDecor    내 굴에 놓아 둔 것 [{ id, tx, ty }]  (방 안쪽 타일 좌표)
## 남의 굴은 data/dens 에 적힌 대로 고정이다. 내 굴만 손댈 수 있다.
## 놓을 자리 고르기: GameState.holding 에 가구 id 가 들어 있으면 커서를 따라 반투명하게 그려지고,
## 왼쪽 클릭으로 놓는다. 아무것도 들고 있지 않을 때 놓여 있는 것을 누르면 집어 들어 다시 옮길 수 있다.

const MY_DEN := "DEN_MINE"
# 놀러 온 용이 내 굴을 보고 하는 말. 아늑함 단계마다 달라진다
const VISIT_LINES := {
	0: ["(휑한 돌바닥을 둘러보더니, 여기서 어떻게 자냐는 얼굴이다.)", "(아직 아무것도 없는 굴 안을 천천히 둘러본다.)"],
	1: ["(새로 들인 것을 하나하나 눈여겨본다. 이제 좀 굴 같다는 얼굴이다.)", "(하나씩 채워 가는 굴을 보고 고개를 끄덕인다.)"],
	2: ["(앉을 데를 찾아 슬쩍 자리를 잡는다. 생각보다 아늑한 모양이다.)", "(제 굴보다 낫다는 듯 눈이 동그래진다.)"],
	3: ["(들어오자마자 눕고 싶은 얼굴이다.)", "(자랑할 만하다는 듯 여기저기 둘러본다.)"],
	4: ["(이제 누가 봐도 내 집이라는 듯 천천히 둘러본다.)", "(이만한 굴은 마을에 몇 없다는 얼굴이다.)"],
}
# 같이 사는 짝 (Routine). 제 굴에서 자던 칸에는 내 굴 잠자리 곁에서 잔다.
# 제 굴에서 자지 않는 짝은 잠자는 칸이 시작하는 시각을 hours 에 적는다 (티아맷은 밤에 망루를 지키고 아침에 잔다)
const PARTNER_HOME := {
	spot = [10, 6],
	doing = "굴 한쪽에 몸을 말고 잠들어 있다",
	hours = { "Tiamat": [7], "Ignar": [0, 22] },
	doings = { "Tiamat": "밤 망루를 마치고 들어와 곯아떨어져 있다" },
}
# 내 굴에서 짝에게 말을 걸면 인사 앞에 붙는 한 줄. 자고 있었으면 sleeping, 나와 같이 들어왔으면 아늑함 단계마다
const PARTNER_LINES := {
	sleeping = "(굴 한쪽에서 자고 있다가, 인기척에 눈을 뜬다.)",
	tiers = [
		"(휑한 돌바닥을 둘러보더니 한숨을 쉰다. 둘이 살려면 살림부터 들여야겠다는 얼굴이다.)",
		"(잠자리 한쪽을 벌써 제 자리로 정해 둔 모양이다. 아직 살림은 단출하다.)",
		"(굴에 들어서자 날개를 느슨하게 접는다. 이제 제법 둘이 사는 굴 같다.)",
		"(들어오자마자 제 자리에 가서 기대앉는다. 밖보다 여기가 편하다는 얼굴이다.)",
		"(들어서자 옆자리를 슬쩍 내어 준다. 누가 봐도 둘이 사는 집이다.)",
	],
}

static var _last_valid := false
static var _last_tile = null


static func dens() -> Dictionary: return Data.get_module("dens").DENS
static func furniture() -> Dictionary: return Data.get_module("furniture").FURNITURE
static func is_den(map_id: String) -> bool: return dens().has(map_id)
static func in_my_den() -> bool: return GameState.map_id == MY_DEN
static func owned(id: String) -> int: return int(GameState.furniture.get(id, 0))
static func owned_list() -> Array: return furniture().keys().filter(func(id): return owned(id) > 0)
static func sheet_of(f: Dictionary) -> String: return f.sheet if f.get("sheet") else "dungeon"


static func give_furniture(id: String, n := 1) -> void:
	if not furniture().has(id): return
	GameState.furniture[id] = owned(id) + n
	Hud.pop("살림살이: %s +%d" % [furniture()[id].name, n], "🪑")


## 굴 하나의 살림살이 목록 (내 굴이면 놓아 둔 것, 남의 굴이면 정해진 것)
static func decor_of(map_id: String) -> Array:
	var spec = dens().get(map_id)
	if not spec: return []
	if spec.get("mine"): return GameState.denDecor.map(func(d): return { id = d.id, tx = d.tx, ty = d.ty })
	return spec.get("decor", []).map(func(d): return { id = d[0], tx = d[1], ty = d[2] })


## 아늑함 점수와 단계 { score, name, note, tier(단계 번호 0~) }
static func cozy_of(map_id: String) -> Dictionary:
	var n := 0
	for d in decor_of(map_id):
		if furniture().has(d.id): n += int(furniture()[d.id].cozy)
	var tiers: Array = Data.get_module("furniture").COZY_TIERS
	var tier := 0
	for i in tiers.size():
		if n >= tiers[i][0]: tier = i
	return { score = n, name = tiers[tier][1], note = tiers[tier][2], tier = tier }


## 방 안쪽 타일 좌표 → 월드 좌표 (칸 한가운데, 발끝 기준)
static func tile_to_world(tx: int, ty: int) -> Vector2:
	var T := GameMap.TILE
	return Vector2((RoomMap.PAD + tx) * T + T / 2.0, (RoomMap.PAD + ty) * T + T)


## 월드 좌표 → 방 안쪽 타일 좌표
static func world_to_tile(x: float, y: float) -> Vector2i:
	var T := GameMap.TILE
	return Vector2i(floori(x / T) - RoomMap.PAD, floori((y - 1) / T) - RoomMap.PAD)


## 그 칸에 놓을 수 있나
static func can_place(id: String, tx: int, ty: int, m, ignore_index := -1) -> bool:
	var f = furniture().get(id)
	if not f or not (m is RoomMap): return false
	var sw: int = f.span[0]
	var sh: int = f.span[1]
	var iw: int = m.tw - RoomMap.PAD * 2
	var ih: int = m.th - RoomMap.PAD * 2
	if tx < 0 or ty < 0 or tx + sw > iw or ty + sh > ih: return false
	if f.get("wall") and ty != 0: return false        # 벽에 거는 것은 맨 윗줄에만
	if not f.get("wall") and ty == 0: return false    # 바닥 물건은 벽줄을 비워 둔다
	# 이미 놓인 것과 겹치면 안 된다
	for i in GameState.denDecor.size():
		if i == ignore_index: continue
		var d: Dictionary = GameState.denDecor[i]
		var g = furniture().get(d.id)
		if not g: continue
		if tx < d.tx + g.span[0] and tx + sw > d.tx and ty < d.ty + g.span[1] and ty + sh > d.ty: return false
	return true


## 놓는다. 가진 것에서 하나 뺀다
static func place(id: String, tx: int, ty: int) -> bool:
	if owned(id) <= 0: return false
	GameState.furniture[id] -= 1
	if GameState.furniture[id] <= 0: GameState.furniture.erase(id)
	GameState.denDecor.append({ id = id, tx = tx, ty = ty })
	Sfx.play("ui")
	return true


## 치운다. 가진 것으로 돌아온다
static func pick_up(index: int):
	if index < 0 or index >= GameState.denDecor.size(): return null
	var d: Dictionary = GameState.denDecor[index]
	GameState.denDecor.remove_at(index)
	GameState.furniture[d.id] = owned(d.id) + 1
	Sfx.play("ui")
	return d


## 그 칸에 놓여 있는 것의 번호 (없으면 -1)
static func index_at(tx: int, ty: int) -> int:
	for i in GameState.denDecor.size():
		var d: Dictionary = GameState.denDecor[i]
		var f = furniture().get(d.id)
		if f and tx >= d.tx and tx < d.tx + f.span[0] and ty >= d.ty and ty < d.ty + f.span[1]: return i
	return -1


# ---------- 엮기 (굴 안에서 직접 만든다) ----------

static func cost_text(id: String) -> String:
	var c: Dictionary = furniture()[id].get("cost", {})
	var parts := []
	if c.get("gold"): parts.append("%dG" % c.gold)
	var mats: Dictionary = Data.get_module("materials").MATERIALS
	for m in c:
		if m == "gold": continue
		parts.append("%s %d/%d" % [mats[m].name if mats.has(m) else m, Forge.mat_count(m), c[m]])
	return " · ".join(parts) if not parts.is_empty() else "그냥 주워 오면 된다"


static func can_afford(id: String) -> bool:
	var c: Dictionary = furniture()[id].get("cost", {})
	if c.get("gold", 0) > GameState.player.gold: return false
	for m in c:
		if m != "gold" and Forge.mat_count(m) < c[m]: return false
	return true


static func craft(id: String) -> bool:
	if not can_afford(id): return false
	var c: Dictionary = furniture()[id].get("cost", {})
	GameState.player.gold -= int(c.get("gold", 0))
	for m in c:
		if m != "gold": Forge.add_material(m, -c[m])
	give_furniture(id, 1)
	Sfx.play("relic")
	return true


## 굴에서 자고 일어날 때의 덤. 아늑할수록 더 낫는다
static func cozy_rest() -> Dictionary:
	var c := cozy_of(MY_DEN)
	return { heal = minf(0.5, c.score * 0.012), tier = c }


## 내 굴에서 말을 걸면 인사 앞에 한 줄을 붙인다 (NpcActions). 같이 사는 짝과, 따라 들어온 용이 다르다
static func home_greeting(npc, greeting: String) -> String:
	var tier: int = cozy_of(MY_DEN).tier
	var line: String
	if npc == GameState.partner:
		var plan = Routine.plan_for(npc.config.name)
		var asleep: bool = npc.state == "WANDER" and plan != null and plan.map == MY_DEN
		line = PARTNER_LINES.sleeping if asleep else PARTNER_LINES.tiers[mini(tier, PARTNER_LINES.tiers.size() - 1)]
	else:
		line = VISIT_LINES.get(tier, VISIT_LINES[0]).pick_random()
	return "%s\n\n%s" % [line, greeting]


## 같이 사는 짝이 지금 잘 자리 (Routine 이 일과 칸 대신 쓴다). 그 용이 짝이 아니거나 잘 칸이 아니면 null.
## 따라다니는 짝은 늘 내 곁이라 일과를 타지 않는다. 토라진 짝은 굴을 나가 제 굴에서 잔다 (Romance)
static func partner_home(name: String, slot: Dictionary):
	var partner = GameState.partner
	if not partner or partner.config.get("name") != name or partner.state != "WANDER": return null
	if Romance.is_sulking(partner): return null
	if slot.map != den_of(name) and not PARTNER_HOME.hours.get(name, []).has(int(slot.get("h", -1))): return null
	return { map = MY_DEN, spot = PARTNER_HOME.spot, doing = PARTNER_HOME.doings.get(name, PARTNER_HOME.doing) }


## 이 굴에 들어갈 수 있나 (남의 굴은 사이가 어느 정도 되어야). 못 들어가면 그 까닭
static func locked_reason(map_id: String):
	var spec = dens().get(map_id)
	if not spec or spec.get("mine") or not spec.get("locked"): return null
	# 주인이 딴 지도에 가 있어도 사이는 그대로다 (지금 지도에 있는 용만 보면, 주인이 집을 비운 굴은 호감 100 이어도 잠겼다)
	var owner = World.any_npc(spec.owner)
	var rel: float = owner.relation if owner else 0.0
	if rel >= spec.locked: return null
	return "아직 %s 그리 가까운 사이는 아니다. 함부로 들어갈 수는 없다." % Util.josa(spec.name.replace("의 굴", ""), "과는", "와는")


static func den_of(nm: String):
	for id in dens():
		if dens()[id].get("owner") == nm: return id
	return null


# ---------- 굴 입구 앞에서 [E], 굴 안에서 [E] ----------

static func _ask(nm: String, text: String, options: Array) -> void:
	GameState.isDialogueOpen = true
	DialogueBox.current.show_dialogue({ name = nm, text = text, options = options, on_close = _close })


static func _close() -> void:
	GameState.isDialogueOpen = false
	DialogueBox.current.hide_dialogue()


## 처리했으면 true
static func try_interact() -> bool:
	# 1) 굴 안 — 둥지 곁이면 잠자기가 먼저다. 그 밖에서는 꾸미기
	if in_my_den():
		var nests: Array = GameState.entities.nests
		if not nests.is_empty() and Util.dist(nests[0], GameState.player) < 110:
			Story.open_nest_menu()
			return true
		DenPanel.show_panel()
		return true
	# 2) 굴 입구
	var mouth = World.nearby_den_mouth()
	if not mouth: return false
	var spec = dens().get(mouth.den_id)
	if not spec: return false
	var why = locked_reason(mouth.den_id)
	if why:
		_ask(spec.name, why, [{ label = "돌아선다", on_select = _close }])
		return true
	var owner = null
	if spec.get("owner"):
		for n in GameState.entities.npcs:
			if n.config.get("name") == spec.owner: owner = n
	var home: bool = owner != null and Util.dist(owner, mouth) < 400
	var cz := cozy_of(mouth.den_id)
	var line: String = "내 굴이다. %s. %s" % [cz.name, cz.note] if spec.get("mine") \
		else "%s의 굴이다. 주인이 근처에 있다." % Names.npc(spec.owner) if home \
		else "%s의 굴이다. 지금은 비어 있는 것 같다." % Names.npc(spec.owner)
	_ask(spec.name, line, [
		{ label = "🕯️ 들어간다", on_select = func():
			_close()
			World.travel_to(mouth.den_id) },
		{ label = "다음에", on_select = _close },
	])
	return true


## 굴에 들어서면 한 번, 그 굴다운 첫인상을 남긴다
static func intro(map_id: String) -> void:
	var spec = dens().get(map_id)
	if not spec or not spec.get("intro"): return
	if GameState.densSeen.has(map_id): return
	GameState.densSeen.append(map_id)
	Hud.pop(spec.intro, "🕯️")


# ---------- 놓을 자리 고르기 ----------

static func is_placing() -> bool: return GameState.holding != null


static func cancel_placing() -> void:
	GameState.holding = null
	DenPanel.hint("")


## 커서가 가리키는 칸
static func _cursor_tile():
	if not GameInput.mouse_inside: return null
	var w: Vector2 = GameCamera.current.screen_to_world(GameInput.mouse_pos)
	return world_to_tile(w.x, w.y)


## 매 프레임 (굴 안에서만)
static func update_place() -> void:
	if not in_my_den():
		cancel_placing()
		return
	var m := Terrain.active
	if GameState.holding:
		var t = _cursor_tile()
		_last_tile = t
		_last_valid = t != null and can_place(GameState.holding, t.x, t.y, m)
		var f: Dictionary = furniture()[GameState.holding]
		DenPanel.hint("%s: 왼쪽 클릭으로 놓는다 (오른쪽 클릭: 그만)" % f.name if _last_valid \
			else "%s: %s" % [f.name, "벽에 거는 것은 맨 윗줄에만 걸 수 있다" if f.get("wall") else "여기에는 놓을 수 없다"])
		if GameInput.mouse_right:
			cancel_placing(); Sfx.play("ui"); DenPanel.show_panel()
			return
		if GameInput.mouse_clicked and _last_valid:
			place(GameState.holding, t.x, t.y)
			Hud.pop("%s 놓았다." % Util.josa(f.name, "을", "를"), "🪑")
			GameState.holding = null
			DenPanel.hint("")
			World.refresh_den()
		return
	# 아무것도 안 들고 있을 때: 놓여 있는 것을 누르면 집어 든다
	DenPanel.hint("")
	if not GameInput.mouse_clicked: return
	var t = _cursor_tile()
	if t == null: return
	var i := index_at(t.x, t.y)
	if i < 0: return
	var d = pick_up(i)
	if not d: return
	GameState.holding = d.id
	Hud.pop("%s 집어 들었다." % Util.josa(furniture()[d.id].name, "을", "를"), "✋")
	World.refresh_den()


## 들고 있는 것을 커서 자리에 반투명하게 그린다 (월드 좌표 층에서)
static func draw_ghost(ci: CanvasItem) -> void:
	if not GameState.holding or _last_tile == null: return
	var f: Dictionary = furniture()[GameState.holding]
	var sheet := TileImages.get_texture(sheet_of(f))
	var T := GameMap.TILE
	var S := GameMap.TILE_SRC
	var sw: int = f.span[0]
	var sh: int = f.span[1]
	var w0 := tile_to_world(_last_tile.x, _last_tile.y)
	var x := w0.x + (sw - 1) * T / 2.0
	var y := w0.y
	var r := Rect2(roundf(x - sw * T / 2.0), roundf(y - sh * T), sw * T, sh * T)
	# 놓을 칸을 네모로 표시
	ci.draw_rect(r, Color("#8ef08e" if _last_valid else "#f08e8e", 0.85), false, 2)
	ci.draw_texture_rect_region(sheet, r, Rect2(f.tile[0] * S, f.tile[1] * S, sw * S, sh * S), Color(1, 1, 1, 0.75 if _last_valid else 0.35))
