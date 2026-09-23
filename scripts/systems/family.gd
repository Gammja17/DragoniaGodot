class_name Family
## 2D판 systems/family.js. 가족의 뒷이야기. 표는 data/family.json.
##
##   성년식    다 자란 아이는 다음 날 아침 촌장 앞에서 마을의 용으로 이름을 올리고, 성격대로 일을 맡는다
##   품삯      일을 맡은 아이는 아침마다 뭔가를 들고 온다 (골드 · 고기 · 쇳조각 · 경험치)
##   나들이    사흘에 한 번, 짝과 아이들을 데리고 호숫가에 다녀온다. 다들 정이 깊어진다
##   눈치      부모가 다투거나 헤어지거나 평생을 약속하면 아이들이 한마디씩 한다


static func _d() -> Dictionary: return Data.get_module("family")


## 받침을 보고 '이/가' 를 붙인다 (아이 이름은 플레이어가 지으므로 미리 알 수 없다)
static func iga(word: String) -> String:
	var c := word.unicode_at(word.length() - 1)
	var batchim := c >= 0xAC00 and c <= 0xD7A3 and (c - 0xAC00) % 28 != 0
	return word + ("이" if batchim else "가")


static func _kids_at(stage: String) -> Array:
	return GameState.kids.filter(func(k): return k.stage == stage)


## 아침에 (Story 의 play_morning_scene). 장면을 틀었으면 true
static func morning() -> bool:
	_bring_home()
	var kid = null
	for k in _kids_at("ADULT"):
		if not k.get("job"):
			kid = k
			break
	if not kid: return false
	var job: Dictionary = _d().KID_JOBS[kid.personality]
	# 일을 가르쳐 줄 용이 죽고 없으면 다른 용이 맡는다
	var mentor: String = job.fallback if Routine.is_dead(job.mentor) else job.mentor
	kid.job = kid.personality
	var say: Dictionary = _d().FAMILY_LINES[kid.personality]
	Chronicle.play_scene("%s의 성년식" % kid.name, [
		{ who = "Elder", text = "오늘부터 %s도 이 마을의 어엿한 용이란다. 알에서 나오던 날이 엊그제 같은데 벌써 이만큼 컸구나…" % kid.name },
		{ who = "나", text = "(%s: \"%s\")" % [kid.name, say.rite] },
		{ who = mentor, text = job.offer.get(mentor, job.offer.default) },
		{ who = "나", text = "(%s %s 밑에서 [%s] 일을 맡았다. 이제 아침마다 뭔가를 들고 돌아온다.)" % [iga(kid.name), Names.npc(mentor), job.name] },
	], Save.save_game, true, "VILLAGE")
	return true


## 일을 맡은 아이들이 아침마다 들고 오는 것
static func _bring_home() -> void:
	var p = GameState.player
	var got := []
	for kid in _kids_at("ADULT"):
		if not kid.get("job"): continue
		var bonus: float = 1 + kid.affection / 100.0   # 정이 깊을수록 넉넉히 챙겨 온다
		match _d().KID_JOBS[kid.job].pay:
			"gold":
				var g := roundi(18 * bonus)
				p.gold += g; got.append("%s %dG" % [kid.name, g])
			"meat":
				var n := 2 if bonus > 1.5 else 1
				p.inventory.meat += n; got.append("%s 고기 %d" % [kid.name, n])
			"ore":
				Forge.add_material("ORE", 1); got.append("%s 쇳조각 1" % kid.name)
			"xp":
				var xp := roundi(30 * bonus)
				p.gain_xp(xp); got.append("%s 경험치 %d" % [kid.name, xp])
	if not got.is_empty(): Hud.pop("아이들이 들고 왔다: %s" % " · ".join(got), "🎒")


# ---------- 가족 나들이 (NpcActions 의 '함께' 메뉴) ----------

static func can_outing() -> bool:
	return GameState.partner != null and GameState.partner.state != "WANDER" and not GameState.kids.is_empty() \
		and (GameState.story.get("lastOuting") == null or GameState.day - GameState.story.lastOuting >= 3)


static func outing_wait() -> int:
	if GameState.story.get("lastOuting") == null: return 0
	return maxi(0, 3 - (GameState.day - GameState.story.lastOuting))


static func go_outing(then = null) -> void:
	var partner = GameState.partner
	var nm: String = partner.config.name
	GameState.story.lastOuting = GameState.day
	var outing: Dictionary = _d().OUTING_PARTNER
	var lines := [{ who = nm, text = outing.get(nm, outing.default) }]
	for kid in GameState.kids.slice(0, 3):
		lines.append({ who = "나", text = "(%s: \"%s\")" % [kid.name, _d().FAMILY_LINES[kid.personality].outing.pick_random()] })
	lines.append({ who = "나", text = "(해가 기울 때까지 호숫가에 있었다. 돌아오는 길에는 아이들이 졸려서 등에 업혀 왔다.)" })
	Hud.fade_screen("가족 나들이", func(): GameState.dayTime = minf(0.78, GameState.dayTime + 0.14), func():
		Chronicle.play_scene("호숫가의 하루", lines, func():
			for kid in GameState.kids:
				kid.affection = minf(100, kid.affection + 10)
				if kid.get("entity"): kid.entity.grow(10)
			partner.relation = minf(100, partner.relation + 6)
			GameState.player.hp = GameState.player.max_hp
			Vfx.spawn_effect("HEART", GameState.player.x, GameState.player.y - 90, { color = "#ff7aa8", size = 1.4 })
			Hud.pop("가족 나들이를 다녀왔습니다. 아이들의 애정과 성장, 짝의 호감이 올랐습니다.", "🧺")
			Save.save_game()
			if then: then.call()))


# ---------- 아이들의 눈치 (KidActions 가 인사말 대신 쓴다) ----------

## 부모 사이에 일이 있으면 아이가 그 얘기부터 꺼낸다. 없으면 null
static func kid_mood_line(kid: Dictionary):
	var love = GameState.story.get("love")
	var say: Dictionary = _d().FAMILY_LINES[kid.personality]
	if not love or (kid.stage == "BABY" and randf() < 0.5): return null
	var p = GameState.partner
	if p and love.mood.has(p.config.name) and love.mood[p.config.name].kind == "SULK": return say.fight
	if not p and love.mood.values().any(func(m): return m.kind == "EX"): return say.split
	if p and love.get("vow") and love.vow.with == p.config.name and GameState.day - love.vow.day < 3: return say.vow
	return null
