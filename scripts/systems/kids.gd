class_name Kids
## 2D판 systems/kids.js. 아이 명부. GameState.kids = [{ id, name, stage, affection, mode, personality, entity, … }]
## mode: FOLLOW(따라오기) | STAY(둥지 지키기). 가족 창(kidsPanel)은 5단계 UI 에서.


## 아직 아무도 쓰지 않은 이름 하나 (마을 용 이름과도 겹치지 않게)
static func _fresh_name() -> String:
	var npcs: Dictionary = Data.get_module("npcs")
	var taken := {}
	for k in GameState.kids: taken[k.name] = true
	for v in npcs.NPC_NAMES_KO.values(): taken[v] = true
	var pool: Array = npcs.KID_NAMES.filter(func(n): return not taken.has(n))
	if not pool.is_empty(): return pool.pick_random()
	return "%s %d세" % [npcs.KID_NAMES.pick_random(), GameState.kids.size() + 1]   # 이름이 다 떨어지면 대를 잇는 식으로


static func register(baby) -> Dictionary:
	# 부모를 적기 전의 옛 세이브에서 온 아이: 알 길이 없으니 불러올 때의 짝을 부모로 적어 둔다 (그 뒤로는 바뀌지 않는다)
	if not baby.genes.has("parent"): baby.genes.parent = GameState.partner.config.name if GameState.partner else ""
	var kid := { id = GameState.kids.size() + 1, name = _fresh_name(), stage = "BABY", affection = 0, mode = "FOLLOW",
		personality = Data.get_module("npcTalk").KID_PERSONALITIES.keys().pick_random(), entity = baby }
	GameState.kids.append(kid)
	return kid


static func find(baby):
	for k in GameState.kids:
		if k.get("entity") == baby: return k
	return null


static func set_stage(baby, stage: String) -> void:
	var kid = find(baby)
	if kid: kid.stage = stage


static func add_affection(baby, amount: float) -> void:
	var kid = find(baby)
	if kid: kid.affection = clampf(kid.affection + amount, 0, 100)


## 부모 둘의 종족·색을 섞어 아이의 유전 정보를 만든다. b 가 없으면(주워 온 알) a 를 닮는다.
## 다른 부모 b 의 이름도 적어 둔다 (parent, 부모 없이 품은 알이면 ""). 유전 정보는 둥지 · 아기 · 세이브를
## 그대로 따라다니므로, 짝이 바뀐 뒤에도 아이는 제 부모를 안다
static func mix_genes(a, b) -> Dictionary:
	if not b: return { species = a.species, colors = a.colors.duplicate(), look = a.look, parent = "" }
	var nm: String = b.config.get("name", "")
	# 한 장짜리 외형(LOOK)은 섞을 수 없으니 부모 한쪽을 그대로 닮는다
	if a.species == "LOOK" or b.species == "LOOK":
		var p = a if randf() < 0.5 else b
		return { species = p.species, colors = p.colors.duplicate(), look = p.look, parent = nm }
	var t := Util.rand_range(0.25, 0.75)
	return {
		species = a.species if randf() < 0.5 else b.species,
		colors = { body = "#" + Color(a.colors.body).lerp(Color(b.colors.body), t).to_html(false), wing = "#" + Color(a.colors.wing).lerp(Color(b.colors.wing), 1 - t).to_html(false) },
		parent = nm,
	}


## 이 아이의 다른 부모 (용 이름). 없으면 ""
static func parent_of(kid: Dictionary) -> String:
	var e = kid.get("entity")
	return str(e.genes.get("parent", "")) if e and e.genes else ""


static func rename(kid: Dictionary, nm: String) -> void:
	var s := nm.strip_edges().substr(0, 12)
	if s != "": kid.name = s


static func toggle_mode(kid: Dictionary) -> void:
	kid.mode = "STAY" if kid.mode == "FOLLOW" else "FOLLOW"
