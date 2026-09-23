class_name Forge
## 2D판 systems/smithing.js. 그론의 모루. 잡은 것에서 나온 소재를 두드려 몸을 손본다.
## GameState.materials = { HIDE: n, FANG: n, ORE: n } · GameState.upgrades = { hp, dmg, spd … } (두드린 횟수)


static func mats() -> Dictionary: return Data.get_module("materials").MATERIALS
static func recipes() -> Array: return Data.get_module("materials").RECIPES
static func goods() -> Array: return Data.get_module("materials").GOODS
static func mat_count(id: String) -> int: return int(GameState.materials.get(id, 0))


static func add_material(id: String, n := 1) -> void:
	GameState.materials[id] = mat_count(id) + n


## 이 조리법을 다음번에 두드릴 때 드는 재료
static func cost_of(recipe: Dictionary) -> Dictionary:
	var times := int(GameState.upgrades.get(recipe.id, 0))
	var out := {}
	for k in recipe.base: out[k] = int(recipe.base[k]) + int(recipe.step.get(k, 0)) * times
	for k in recipe.step:
		if not out.has(k): out[k] = int(recipe.step[k]) * times
	return out


static func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if mat_count(k) < cost[k]: return false
	return true


## 재료를 사람이 읽는 줄로 ("질긴 가죽 4/2 · 쇳조각 1/0")
static func cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in cost: parts.append("%s %d/%d" % [mats()[k].name, mat_count(k), cost[k]])
	return " · ".join(parts)


## 두드린다. 성공하면 true
static func forge(recipe: Dictionary) -> bool:
	var cost := cost_of(recipe)
	if not can_afford(cost):
		Hud.pop("재료가 모자랍니다. %s" % cost_text(cost), "🔨")
		return false
	for k in cost: GameState.materials[k] = mat_count(k) - cost[k]
	GameState.upgrades[recipe.id] = int(GameState.upgrades.get(recipe.id, 0)) + 1
	var p = GameState.player
	if recipe.id == "hp":
		p.max_hp += 25; p.hp += 25
	Vfx.spawn_effect("SPARK", p.x, p.y - 40, { size = 1.4, color = "#ffd07a" })
	GameCamera.current.shake(5)
	Sfx.play("relic")
	Hud.pop("%s 완료! %s (%d단)" % [recipe.name, recipe.effect, GameState.upgrades[recipe.id]], "🔨")
	Quests.notify("upgrade")
	return true


## 골드로 사는 것들
static func buy(item: Dictionary) -> bool:
	var p = GameState.player
	if p.gold < item.cost:
		Hud.pop("골드가 모자랍니다.", "💰")
		return false
	p.gold -= int(item.cost)
	if item.get("material"): add_material(item.id, 1)
	elif item.id == "meat": p.inventory.meat += 1
	Sfx.play("coin")
	Hud.pop("%s 구입!" % item.name, "🛒")
	return true
