class_name Save
## 2D판 systems/save.js. 세이브 칸 세 개 (user://dragonia-slot-1..3.json). 월드(지형·소품)는 시드 고정이라 저장하지 않는다.
## 떠돌이 NPC·적·아이템도 저장 안 함. 모양은 2D판 localStorage 세이브와 같다 (v: 1).
## 지금 쓰는 칸은 slot. 처음 화면(Title)에서 고른다.

const SLOTS := 3
const LEGACY := "user://dragonia-save-v1.json"   # 칸이 하나뿐이던 때의 세이브. 1번 칸으로 옮긴다

static var slot := 1


static func path(n: int) -> String: return "user://dragonia-slot-%d.json" % n


static func has_save(n := -1) -> bool: return read(n) != null


## n 번 칸을 읽는다 (없거나 깨졌으면 null). n 을 안 주면 지금 칸
static func read(n := -1):
	if n < 0: n = slot
	_migrate_legacy()
	var p := path(n)
	if not FileAccess.file_exists(p): return null
	var data = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not data is Dictionary or data.get("v") != 1.0: return null
	return _intify(data)


static func delete(n := -1) -> void:
	if n < 0: n = slot
	var p := path(n)
	if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## 처음 화면에 띄울 한 줄 요약. 빈 칸이면 null
static func summary(n: int):
	var d = read(n)
	if not d: return null
	var stages: Array = Data.get_module("elements").STAGES
	var st: int = clampi(d.player.get("stageIndex", 0), 0, stages.size() - 1)
	return {
		name = d.player.config.get("name", "용"), level = d.player.level, stage = stages[st].name,
		map = Names.map(d.get("mapId", "VILLAGE")), day = d.get("day", 1),
		chapter = d.get("story", {}).get("chapterTitle", ""),
		saved = Time.get_datetime_string_from_unix_time(int(d.get("savedAt", 0) / 1000.0) + _tz_offset(), true),
	}


static func _tz_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


## 칸이 하나뿐이던 때의 세이브를 1번 칸으로 옮긴다 (한 번만)
static func _migrate_legacy() -> void:
	if not FileAccess.file_exists(LEGACY) or FileAccess.file_exists(path(1)): return
	DirAccess.rename_absolute(ProjectSettings.globalize_path(LEGACY), ProjectSettings.globalize_path(path(1)))


## JSON 은 숫자를 모두 실수로 돌려준다. 딱 떨어지는 수는 정수로 되돌린다
## (날짜 비교나 배열 속 단계 번호가 정수로 저장된 값과 맞아야 한다)
static func _intify(v):
	if v is float and v == floorf(v) and absf(v) < 9.0e15: return int(v)
	if v is Array: return v.map(_intify)
	if v is Dictionary:
		var out := {}
		for k in v: out[k] = _intify(v[k])
		return out
	return v


static func save_game() -> void:
	var p = GameState.player
	if not p or not GameState.gameActive: return
	if GameState.dungeon: return   # 굴은 한 판짜리다. 나온 뒤에 저장한다
	# 둥지는 내 굴에만 있다. 딴 데 있을 땐 마지막으로 본 값을 그대로 저장한다
	var nest := { hasEgg = false, progress = 0, genes = null }
	if not GameState.entities.nests.is_empty():
		var n = GameState.entities.nests[0]
		nest = { hasEgg = n.has_egg, progress = n.progress, genes = n.genes }
	elif GameState.denNest: nest = GameState.denNest
	var npcs := {}
	for n in World.fixed_npcs():
		npcs[n.config.name] = { relation = n.relation, lastGiftDay = n.last_gift_day, lastTalkDay = n.last_talk_day, lastPresentDay = n.last_present_day,
			lastPlayDay = n.last_play_day, dates = n.dates, lastDateDay = n.last_date_day, lastEggDay = n.last_egg_day, lastMeditateDay = n.last_meditate_day }
	var data := {
		v = 1,
		savedAt = Time.get_unix_time_from_system() * 1000,
		player = {
			config = { name = p.config.get("name"), species = p.species, colors = p.colors, accessory = p.config.get("accessory"), look = p.look },
			level = p.level, xp = p.xp, maxXp = p.max_xp, hp = p.hp, maxHp = p.max_hp, hunger = p.hunger,
			meat = p.inventory.meat, gold = p.gold, x = p.x, y = p.y, carrying = p.carrying,
			stageIndex = p.stage_index, elements = p.elements, element = p.element, skills = p.skills, slots = p.slots,
		},
		gameTime = GameState.game_time, dayTime = GameState.dayTime, day = GameState.day, raidTimer = GameState.raidTimer,
		mapId = GameState.map_id, visited = GameState.visited,
		elderTutorialDone = GameState.elderTutorialDone, tutorial = GameState.tutorial,
		weather = GameState.weather.type,
		quests = GameState.quests, chores = GameState.chores,
		bossesDefeated = GameState.bossesDefeated,
		raidCount = GameState.raid.count, upgrades = GameState.upgrades, openedChests = GameState.openedChests, blessingDay = GameState.blessingDay,
		companion = GameState.companion.config.name if GameState.companion else null,
		den = GameState.den, ult = p.ult, eggSitting = GameState.eggSitting,
		relics = GameState.relics, relicSlots = GameState.relicSlots, materials = GameState.materials, waystones = GameState.waystones,
		furniture = GameState.furniture, denDecor = GameState.denDecor, densSeen = GameState.densSeen, stats = GameState.stats, event = GameState.event, story = GameState.story,
		growth = GameState.growth, revivedDay = GameState.revivedDay,
		npcs = npcs,
		partner = GameState.partner.config.name if GameState.partner else null,
		partnerFollowing = GameState.partner.state != "WANDER" if GameState.partner else false,
		nest = nest,
		kids = GameState.kids.map(func(k): return {
			name = k.name, stage = k.stage, affection = k.affection, mode = k.mode, personality = k.personality,
			lastPlayDay = k.get("lastPlayDay"), lastTrainDay = k.get("lastTrainDay"), job = k.get("job"), fedDay = k.get("fedDay"), fedCount = k.get("fedCount", 0),
			element = k.entity.element, growth = k.entity.growth, genes = k.entity.genes, x = k.entity.x, y = k.entity.y,
		}),
	}
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f == null: return   # 저장할 수 없으면 조용히 포기
	f.store_string(JSON.stringify(data))


## World.init_world() 직후에 불러 저장된 진행 상황을 덮어쓴다
static func apply(data: Dictionary) -> void:
	var p = GameState.player
	var s: Dictionary = data.player
	p.level = s.level; p.xp = s.xp; p.max_xp = s.maxXp; p.hp = s.hp; p.max_hp = s.maxHp; p.hunger = s.hunger
	p.stage_index = s.stageIndex; p.elements = s.elements; p.element = s.element
	p.inventory.meat = s.meat
	p.skills = s.get("skills", []) if s.get("skills") else []
	p.slots = s.slots if s.get("slots") else { Q = null, F = null, R = null }
	p.gold = s.get("gold", 0) if s.get("gold") else 0
	p.carrying = s.get("carrying")   # 들고 있던 알

	var G := GameState
	G.game_time = data.gameTime; G.dayTime = data.dayTime; G.day = data.day; G.raidTimer = data.raidTimer
	G.elderTutorialDone = data.elderTutorialDone; G.bossesDefeated = data.bossesDefeated
	G.quests = Quests.migrate(data.get("quests", {}) if data.get("quests") else {})
	G.chores = data.chores if data.get("chores") else { day = 0, offers = [], taken = {}, done = [] }
	G.questScenes = []
	G.weather.type = data.weather
	G.raid.count = data.get("raidCount", 0)
	G.upgrades = data.get("upgrades", {})
	G.openedChests = data.get("openedChests", {})
	G.blessingDay = data.get("blessingDay", 0)
	G.tutorial = data.tutorial if data.get("tutorial") else { moved = true, journal = true, ate = true, toured = true, finished = true }   # 예전 세이브는 안내를 건너뛴다
	if not G.tutorial.has("toured"): G.tutorial.toured = true
	# '낯선 아침'(m0)이 생기기 전 세이브: 마을을 다 돌았으면 끝낸 것으로 친다. 돌던 중이면 그 대목부터 잇는다
	if not G.quests.done.has("m0") and not G.quests.active.has("m0"):
		if G.tutorial.toured: G.quests.done.push_front("m0")
		else: G.quests.active.m0 = { step = 1 if G.elderTutorialDone else 0, n = 0 }
	G.tour = null
	G.relics = data.get("relics", [])
	# 예전 세이브에는 장착 칸이 없다. 가진 유물 앞쪽 몇 개를 자동으로 끼워 준다
	G.relicSlots = data.relicSlots if data.get("relicSlots") != null else G.relics.slice(0, 3)
	G.materials = data.get("materials", {})
	G.waystones = data.get("waystones", [])
	G.furniture = data.get("furniture", {})
	G.denDecor = data.get("denDecor", [])
	# 옛 세이브: 굴 가운데 잠자리가 없으면 하나 놓아 준다
	if not G.denDecor.any(func(d): return d.id == "BED") and not G.denDecor.any(func(d): return d.tx >= 8 and d.tx <= 10 and d.ty >= 4 and d.ty <= 8):
		G.denDecor.append({ id = "BED", tx = 9, ty = 5 })
	G.densSeen = data.get("densSeen", [])
	G.visited = data.get("visited", [])
	var nest0 = data.get("nest")
	G.den = data.den if data.get("den") else { built = nest0 != null and nest0.hasEgg, twigs = 0 }
	G.denNest = nest0 if nest0 else { hasEgg = false, progress = 0, genes = null }
	G.eggSitting = data.get("eggSitting")
	p.ult = data.get("ult", 0)
	G.story = data.story if data.get("story") else { scenes = [], lessons = [], lessonDay = 0 }
	Data.get_module("npcs").NAME_OVERRIDES.merge(G.story.get("npcNames", {}), true)   # 이야기 속에서 지어 준 이름
	for key in ["rites", "clues"]:
		if not G.story.get(key): G.story[key] = []
	for key in ["today", "yesterday"]:
		if not G.story.get(key): G.story[key] = {}
	G.stats = data.stats if data.get("stats") else { kills = {} }
	if not G.stats.has("brinks"): G.stats.brinks = 0
	G.event = data.get("event")
	# 성장 트리: 찍어 둔 것을 되살리고, 남은 포인트는 레벨·단계에서 다시 계산한다
	G.growth = data.growth if data.get("growth") else { points = 0, nodes = {}, ranks = {} }
	G.revivedDay = data.get("revivedDay", 0)
	Growth.reconcile_points()
	# 유물이 생기기 전에 잡은 보스의 전리품도 챙겨 준다
	for id in G.bossesDefeated:
		var r = Relics.boss_relic(id)
		if r and not G.relics.has(r): G.relics.append(r)

	# NPC 상태는 이름으로 되살린다 (지도마다 따로 깔리므로 개체 목록으로는 찾을 수 없다)
	var keys := { relation = "relation", lastGiftDay = "last_gift_day", lastTalkDay = "last_talk_day", lastPresentDay = "last_present_day",
		lastPlayDay = "last_play_day", dates = "dates", lastDateDay = "last_date_day", lastEggDay = "last_egg_day", lastMeditateDay = "last_meditate_day" }
	for npc in World.fixed_npcs():
		var saved = data.get("npcs", {}).get(npc.config.name)
		if not saved: continue
		for k in keys:
			if saved.has(k) and saved[k] != null: npc.set(keys[k], saved[k])
		if data.get("companion") == npc.config.name:
			npc.state = "COMPANION_FOLLOW"
			G.companion = npc
		if data.get("partner") == npc.config.name:
			G.partner = npc
			# 기다리라고 해 둔 짝은 그대로 둔다. 이 값이 없는 예전 세이브는 따라오던 것으로 본다
			npc.state = "WANDER" if data.get("partnerFollowing") == false else "PARTNER_FOLLOW"

	# 아이들. 지도를 옮길 때 따라오므로 개체만 만들어 두면 된다
	for k in data.get("kids", []):
		var baby := BabyDragon.make(k.x, k.y, k.genes)
		baby.growth = k.growth
		baby.stage = k.stage
		var kid := Kids.register(baby)
		baby.element = k.element if k.get("element") else "FIRE"
		kid.name = k.name; kid.affection = k.affection; kid.mode = k.mode
		if k.get("personality"): kid.personality = k.personality
		kid.lastPlayDay = k.get("lastPlayDay"); kid.lastTrainDay = k.get("lastTrainDay"); kid.job = k.get("job")
		kid.fedDay = k.get("fedDay"); kid.fedCount = k.get("fedCount", 0)
		Kids.set_stage(baby, k.stage)

	# 마지막으로 있던 지도로 (여기서 소품·NPC·보스·가족이 전부 새로 깔린다)
	var start: String = Data.get_module("maps").START_MAP
	World.enter_map(data.mapId if World.maps().has(data.mapId) else start, null, Vector2(s.x, s.y))
