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
	if why != "": Hud.pop("%s. 성장 포인트 +%d ([G] 성장)" % [why, n], "🌟")


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
	var earned: int = (p.level - 1) * POINTS_PER_LEVEL + p.stage_index * POINTS_PER_STAGE
	GameState.growth.points = maxi(0, earned - _spent_points())
