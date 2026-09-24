class_name Delve
## 2D판 systems/delve.js. 굴 탐험. 바깥 세상은 늘 같아서 이야기를 심을 수 있고, 굴은 들어갈 때마다 새로 그려진다.
##
##  들어간다 → 층을 하나 만든다 → 방마다 적과 상자 → 가장 먼 방에 내려가는 구멍
##  내려갈수록 적이 늘고 세지며, 나올 때 깊이만큼 보상을 받는다.
##  아무 때나 들어온 자리로 되돌아 나올 수 있다 (욕심과 안전 사이에서 고르게).
##
## GameState.dungeon = { id, depth, seed, entryPos, best } · 굴 밖이면 null

const EXIT_RANGE := 90.0

# 굴마다 처음 그 깊이에 닿았을 때 한 번만 받는 것. 나올 때 받는다
#   GameState.story.delve = { 굴 id: { best: 가장 깊이 내려간 층, claimed: [받은 깊이] } }
const MILESTONES := [
	{ depth = 3, relic = true, text = "유물 하나" },
	{ depth = 5, points = 2, text = "성장 포인트 2" },
	{ depth = 8, points = 3, relic = true, text = "성장 포인트 3과 유물 하나" },
]

static var _saved = null   # 굴에 들어가 있는 동안 비워 둔 바깥 세상의 자리 { mapId, x, y }


static func _defs() -> Dictionary: return Data.get_module("dungeons").DUNGEONS


static func _record(id: String) -> Dictionary:
	if not GameState.story.get("delve"): GameState.story.delve = {}
	if not GameState.story.delve.has(id): GameState.story.delve[id] = { best = 0, claimed = [] }
	return GameState.story.delve[id]


static func _next_milestone(id: String):
	for m in MILESTONES:
		if not _record(id).claimed.has(m.depth): return m
	return null


static func active() -> bool: return GameState.dungeon != null


static func dungeon_name():
	var d = GameState.dungeon
	return "%s 지하 %d층" % [_defs()[d.id].name, d.depth] if d else null


# ---------- 들어가기 ----------

static func enter(id: String) -> void:
	var def: Dictionary = _defs()[id]
	var p = GameState.player
	GameState.isDialogueOpen = false
	DialogueBox.current.hide_dialogue()
	_saved = { mapId = GameState.map_id, x = p.x, y = p.y }
	GameState.dungeon = { id = id, depth = 1, seed = randi() % 1000000000, entryPos = Vector2(p.x, p.y), best = 0 }
	Sfx.play("evolve")
	Hud.fade_screen("%s 지하 1층" % def.name, func(): _build_floor(1), func():
		Hud.pop("%s에 들어섰다. 더 깊이 내려갈수록 보상이 커진다. 구멍 앞에서 [E]로 오르내린다." % def.name, "🕯️"))


static func _build_floor(depth: int) -> void:
	var d: Dictionary = GameState.dungeon
	var def: Dictionary = _defs()[d.id]
	d.depth = depth
	d.best = maxi(d.best, depth)
	var floor := DungeonMap.generate(d.seed + depth * 7919, depth, def.biome)
	GameState.indoors = true
	Terrain.set_active_map(floor)

	# 개체 풀을 굴 전용으로 갈아 끼운다. 짝·동료·아이들은 따라 들어온다
	var before: Dictionary = GameState.entities
	var pools := GameState.empty_pools()
	pools.npcs = before.npcs.filter(func(n): return n and n.state != "WANDER" and (n == GameState.partner or n == GameState.companion))
	pools.babies = before.babies.filter(func(b): return GameState.kids.any(func(k): return k.get("entity") == b))

	var rng := Util.Mulberry32.new(floor.seed + 1)
	var start := DungeonMap.tile_center(floor.entry.cx, floor.entry.cy)
	GameState.player.x = start.x; GameState.player.y = start.y
	for n in pools.npcs:
		n.x = start.x + 70; n.y = start.y + 30
	for b in pools.babies:
		b.x = start.x - 60; b.y = start.y + 30

	# 올라가는 구멍 / 내려가는 구멍
	pools.props.append(Prop.new().setup(start.x, start.y - 30, "STAIRS_UP"))
	var down_pos := DungeonMap.tile_center(floor.exit.cx, floor.exit.cy)
	pools.props.append(Prop.new().setup(down_pos.x, down_pos.y, "STAIRS_DOWN"))

	# 방마다 적. 들어온 방은 비워 둔다
	var table: Dictionary = Data.get_module("enemies").BIOME_ENEMIES
	var types: Array = table.get(def.biome, table.FOREST).filter(func(t): return t != "PREY")
	var pick_type := func() -> String: return types[floori(randf() * types.size())] if not types.is_empty() else "SLIME"
	var per_room := 2 + mini(5, floori(depth / 2.0))
	for room in floor.rooms:
		if room == floor.entry: continue
		var n := 1 + floori(rng.next() * per_room)
		for i in n:
			var s := DungeonMap.spot_in_room(room, rng)
			var elite := rng.next() < 0.05 + depth * 0.02
			var e := Enemy.make(s.x, s.y, pick_type.call(), elite)
			e.max_hp = e.max_hp * (1 + depth * 0.18)
			e.hp = e.max_hp
			pools.enemies.append(e)
		# 상자: 방 네 개 중 하나꼴. 굴의 상자는 한 판에만 있는 것이라 기록하지 않는다
		if rng.next() < 0.3:
			var s := DungeonMap.spot_in_room(room, rng)
			pools.props.append(Prop.new().setup(s.x, s.y, "CHEST"))
	# 세 층마다 파수꾼이 지키는 방에 상자가 꼭 하나 있다
	if depth % 3 == 0:
		var s := DungeonMap.spot_in_room(floor.exit, rng)
		pools.props.append(Prop.new().setup(s.x, s.y, "CHEST"))
	# 마지막 방의 파수꾼
	var gs := DungeonMap.spot_in_room(floor.exit, rng)
	var guard := Enemy.make(gs.x, gs.y, pick_type.call(), true)
	guard.max_hp = guard.max_hp * (1.4 + depth * 0.3)
	guard.hp = guard.max_hp
	guard.is_guardian = true
	pools.enemies.append(guard)

	Collision.build_prop_grid(pools.props)
	World.swap_pools(pools)
	Quests.notify("delve", depth)   # '몇 층까지 내려갔나'를 보는 퀘스트용


# ---------- 오르내리기 ----------

static func descend() -> void:
	var d: Dictionary = GameState.dungeon
	var next: int = d.depth + 1
	Sfx.play("warn")
	Hud.fade_screen("%s 지하 %d층" % [_defs()[d.id].name, next], func(): _build_floor(next), func():
		Hud.pop("지하 %d층. 공기가 더 무거워졌다." % next, "🕯️"))


static func leave() -> void:
	var d: Dictionary = GameState.dungeon
	var def: Dictionary = _defs()[d.id]
	var depth: int = d.best
	Sfx.play("sleep")
	Hud.fade_screen("바깥 공기", func():
		var back: Dictionary = _saved
		GameState.dungeon = null
		_saved = null
		World.enter_map(back.mapId, null, Vector2(back.x, back.y + 80)), func():
		# 깊이 내려갔던 만큼 보상
		var p = GameState.player
		var gold := depth * 45
		var xp := depth * 90
		p.gold += gold
		p.gain_xp(xp)
		Hud.pop("%s에서 지하 %d층까지 내려갔다. (%dG, 경험치 %d)" % [def.name, depth, gold, xp], "🕯️")
		if depth >= 3 and randf() < 0.45:
			var id = Relics.random_relic()
			if id: Relics.grant(id, p.x, p.y)
		# 이 굴에서 처음 닿은 깊이의 보상
		var rec := _record(d.id)
		rec.best = maxi(rec.best, depth)
		for m in MILESTONES:
			if depth < m.depth or rec.claimed.has(m.depth): continue
			rec.claimed.append(m.depth)
			if m.get("points"): Growth.grant_points(m.points, "%s 지하 %d층" % [def.name, m.depth])
			if m.get("relic"): RelicOffer.offer("%s 지하 %d층에서" % [def.name, m.depth])
			Hud.pop("%s 지하 %d층에 처음 닿았다: %s" % [def.name, m.depth, m.text], "🏅")
		Vfx.spawn_effect("RING", p.x, p.y - 30, { size = 1.6, color = "#ffd84a" })
		Save.save_game())


# ---------- 안내 ----------

static func _close() -> void:
	GameState.isDialogueOpen = false
	DialogueBox.current.hide_dialogue()


static func _ask(title: String, text: String, options: Array) -> void:
	GameState.isDialogueOpen = true
	DialogueBox.current.show_dialogue({ name = title, text = text, on_close = _close, options = options })


static func _prop_near(type: String, r: float):
	for x in GameState.entities.props:
		if x.type == type and Util.dist(GameState.player, x) < r: return x
	return null


## 굴 입구·계단 앞에서 [E] 를 눌렀을 때. 처리했으면 true
static func try_interact() -> bool:
	if not active():
		var mouth = _prop_near("CAVE", 120)
		if not mouth: return false
		var def: Dictionary = _defs()[mouth.cave_id]
		var rec := _record(mouth.cave_id)
		var goal = _next_milestone(mouth.cave_id)
		var note: String = ("\n\n(지금까지 지하 %d층까지 내려가 봤다." % rec.best if rec.best else "\n\n(아직 들어가 본 적이 없다.") \
			+ (" 지하 %d층에 처음 닿으면 받는 것: %s.)" % [goal.depth, goal.text] if goal else " 이 굴에서 처음으로 얻을 것은 다 얻었다.)") \
			+ "\n(층마다 파수꾼이 [옛 비늘돌]을 품고 있다. 대장간에서 쓴다.)"
		_ask(def.name, def.intro + note, [
			{ label = "🕯️ 들어간다", on_select = func(): enter(mouth.cave_id) },
			{ label = "다음에", on_select = _close },
		])
		return true

	var d: Dictionary = GameState.dungeon
	if _prop_near("STAIRS_UP", EXIT_RANGE):
		_ask("올라가는 구멍", "여기서 바깥으로 나갈 수 있다. 지금까지 지하 %d층까지 내려갔다." % d.best, [
			{ label = "↑ 바깥으로 나간다", on_select = func():
				_close()
				leave() },
			{ label = "더 둘러본다", on_select = _close },
		])
		return true
	if _prop_near("STAIRS_DOWN", EXIT_RANGE):
		if GameState.entities.enemies.any(func(e): return e.is_guardian and not e.remove):
			_ask("내려가는 구멍", "구멍이 검은 기운으로 막혀 있다. 이 층의 파수꾼을 쓰러뜨려야 열린다.", [{ label = "파수꾼을 찾는다", on_select = _close }])
			return true
		_ask("내려가는 구멍", "지하 %d층으로 내려간다. 더 깊을수록 적이 세지고, 나올 때 받는 것도 커진다." % (d.depth + 1), [
			{ label = "↓ 더 깊이 내려간다", on_select = func():
				_close()
				descend() },
			{ label = "여기서 멈춘다", on_select = _close },
		])
		return true
	return false


## 파수꾼을 잡으면 알려 준다 (Enemy.die). 파수꾼은 굴에서만 나오는 옛 비늘돌을 떨군다 — 깊을수록 많이
static func on_guardian_down(e) -> void:
	if not GameState.dungeon: return
	var n := 1 + floori(GameState.dungeon.depth / 3.0)
	for i in n: World.add_entity("items", Item.make(e.x - 24 + i * 26, e.y + 30, "MAT", "CORE"))
	Hud.pop("파수꾼이 쓰러졌다. 내려가는 구멍이 열렸다.", "🕳️")
	Sfx.play("quest")
