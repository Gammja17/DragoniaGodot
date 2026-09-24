class_name Growth
## 2D판 systems/growth.js 가운데 수치 보정. 성장 트리 표는 data/growth.json.
## 성장 포인트 한 주머니로 성장 트리와 스킬 강화를 모두 쓴다.
## GameState.growth = { points: 남은 포인트, nodes: { 노드id: 찍은 단수 }, ranks: { 스킬id: 강화 단수 } }
## (트리를 찍는 화면은 5단계 UI 에서)

const POINTS_PER_LEVEL := 2
const POINTS_PER_STAGE := 3


static func node_rank(id: String) -> int:
	return int(GameState.growth.nodes.get(id, 0))


## 수치 보정의 합. 'hp' 는 찍는 순간 maxHp 에 바로 더하므로 여기서 세지 않는다
static func stat(name: String) -> float:
	var sum := 0.0
	for n in Data.get_module("growth").GROWTH_NODES:
		if n.get("stat") == name: sum += node_rank(n.id) * n.per
	return sum


## 꼭대기 노드의 특별 효과를 찍었는지 ('SCORN' | 'UNDYING' | 'GALE')
static func has_perk(flag: String) -> bool:
	for n in Data.get_module("growth").GROWTH_NODES:
		if n.get("flag") == flag: return node_rank(n.id) > 0
	return false


static func grant_points(n: int, why := "") -> void:
	GameState.growth.points += n
	if why != "": Hud.pop("%s. 성장 포인트 +%d ([G] 성장 나무에서 쓴다)" % [why, n], "🌟")


## 이미 쓴 포인트의 합. 옛 세이브를 불러올 때 남은 포인트를 되짚는 데 쓴다
static func _spent_points() -> int:
	var g: Dictionary = GameState.growth
	var sum := 0
	for n in Data.get_module("growth").GROWTH_NODES: sum += int(g.nodes.get(n.id, 0)) * int(n.cost)
	var ranks: Array = Data.get_module("skills").SKILL_RANKS
	for id in g.ranks:
		for r in range(1, int(g.ranks[id])): sum += int(ranks[r].cost)
	return sum


## 세이브를 불러왔을 때 지금까지 쌓였어야 할 포인트를 채워 준다 (레벨·단계를 복원한 뒤에 부른다)
static func reconcile_points() -> void:
	var p = GameState.player
	var earned: int = (p.level - 1) * POINTS_PER_LEVEL + p.stage_index * POINTS_PER_STAGE + _delve_points()
	GameState.growth.points = maxi(0, earned - _spent_points())


## 옛 굴에서 처음 닿은 깊이로 받은 포인트 (Delve.MILESTONES). 레벨·단계만 세면 불러올 때마다 이것이 사라졌다
static func _delve_points() -> int:
	var recs = GameState.story.get("delve")
	if not recs: return 0
	var sum := 0
	for id in recs:
		var claimed: Array = recs[id].get("claimed", [])
		for m in Delve.MILESTONES:
			if m.get("points") and claimed.has(m.depth): sum += int(m.points)
	return sum


const STAGE_LABEL := ["아기 용", "어린 용", "성체", "고룡"]


static func _nodes_by_id() -> Dictionary: return Data.get_module("growth").NODES_BY_ID


## 이 노드를 지금 찍을 수 있는지. 못 찍으면 이유를 돌려준다 { rank, can, reason }
static func node_status(node: Dictionary) -> Dictionary:
	var rank := node_rank(node.id)
	var stage_index: int = GameState.player.stage_index if GameState.player else 0
	if rank >= node.max: return { rank = rank, can = false, reason = "최대" }
	if stage_index < node.tier: return { rank = rank, can = false, reason = "%s 필요" % STAGE_LABEL[node.tier] }
	if node.get("need") and node_rank(node.need[0]) < node.need[1]:
		return { rank = rank, can = false, reason = "%s %d단 필요" % [_nodes_by_id()[node.need[0]].name, node.need[1]] }
	if GameState.growth.points < node.cost: return { rank = rank, can = false, reason = "포인트 %d 필요" % node.cost }
	return { rank = rank, can = true, reason = null }


static func invest_node(id: String) -> bool:
	var node: Dictionary = _nodes_by_id()[id]
	var st := node_status(node)
	if not st.can:
		Hud.pop("이미 끝까지 키웠습니다." if st.reason == "최대" else st.reason, "🌱")
		return false
	var g: Dictionary = GameState.growth
	g.points -= node.cost
	g.nodes[id] = st.rank + 1
	if node.get("stat") == "hp":   # 최대 체력만은 찍는 즉시 몸에 반영한다
		GameState.player.max_hp += node.per
		GameState.player.hp += node.per
	Hud.pop("[%s] %d단. %s" % [node.name, g.nodes[id], node.desc.call(g.nodes[id])], "🌱")
	Sfx.play("level")
	return true


## 스킬을 한 단 더 올리는 값. 끝까지 익혔으면 null
static func skill_upgrade_cost(id: String):
	var r := Skills.rank(id)
	var ranks: Array = Data.get_module("skills").SKILL_RANKS
	return null if r >= ranks.size() else int(ranks[r].cost)


static func upgrade_skill(id: String) -> bool:
	var cost = skill_upgrade_cost(id)
	if cost == null:
		Hud.pop("이미 끝까지 익힌 스킬입니다.", "📖")
		return false
	var g: Dictionary = GameState.growth
	if g.points < cost:
		Hud.pop("성장 포인트가 %d 필요합니다." % cost, "📖")
		return false
	g.points -= cost
	g.ranks[id] = Skills.rank(id) + 1
	Hud.pop("[%s] %d단. 위력 ↑ 재사용 대기 ↓" % [Skills.defs()[id].name, g.ranks[id]], "📖")
	Sfx.play("level")
	return true
