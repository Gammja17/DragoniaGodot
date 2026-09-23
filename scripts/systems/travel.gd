class_name Travel
## 2D판 systems/travel.js. 이동 석비. 옛 용들이 길목마다 세워 둔 돌기둥으로, 한 번 손을 대면 그 뒤로는
## 석비끼리 건너뛸 수 있다. "걸어서 한 번 뚫은 길을 다시 걷지 않게" 해 주는 장치다. 석비가 선 지도의 id 를 그대로 쓴다.

const USE_RANGE := 150.0
const DISCOVER_RANGE := 170.0

static var _stone_maps := []


## 석비가 서 있는 지도들 (maps 의 fixtures 에서 모은다)
static func stone_maps() -> Array:
	if _stone_maps.is_empty():
		var maps: Dictionary = Data.get_module("maps")
		_stone_maps = maps.MAP_ORDER.filter(func(id): return maps.MAPS[id].get("fixtures", []).any(func(f): return f.t == "WAYSTONE"))
	return _stone_maps


static func is_awake(id: String) -> bool: return GameState.waystones.has(id)


## 처음부터 켜 두는 석비 (마을)
static func init_waystones() -> void:
	for id in ["VILLAGE"]:
		if stone_maps().has(id) and not is_awake(id): GameState.waystones.append(id)


## 매 프레임: 석비 가까이 가면 깨어난다
static func update() -> void:
	var p = GameState.player
	if not p or GameState.dungeon: return
	for stone in GameState.entities.props:
		if stone.type != "WAYSTONE" or is_awake(stone.stone_id) or Util.dist(p, stone) > DISCOVER_RANGE: continue
		GameState.waystones.append(stone.stone_id)
		Vfx.spawn_effect("RING", stone.x, stone.y - 30, { size = 1.5, color = "#7fd4ff" })
		Sfx.play("relic")
		Hud.pop("[%s]의 석비가 깨어났습니다. 이제 이곳으로 건너뛸 수 있습니다." % Names.map(stone.stone_id), "🗿")


## 지금 자리에서 쓸 수 있는 석비
static func nearby_waystone():
	var p = GameState.player
	var best = null
	var best_d := USE_RANGE
	for stone in GameState.entities.props:
		if stone.type != "WAYSTONE": continue
		var d := Util.dist(p, stone)
		if d < best_d:
			best = stone
			best_d = d
	return best


static func _close() -> void:
	GameState.isDialogueOpen = false
	DialogueBox.current.hide_dialogue()


## 왜 지금은 못 쓰는가 (쓸 수 있으면 null)
static func _blocked_reason():
	if GameState.raid.active: return "사냥꾼이 마을을 치고 있다. 지금 떠날 수는 없다."
	if GameState.activity: return "지금은 다른 일에 매여 있다."
	if GameState.entities.bosses.any(func(b): return b.awake): return "눈앞의 용에게서 등을 돌릴 수는 없다."
	return null


static func open_menu(stone) -> void:
	var here: String = stone.stone_id
	GameState.isDialogueOpen = true
	var why = _blocked_reason()
	if why:
		DialogueBox.current.show_dialogue({ name = Names.map(here), text = why, on_close = _close, options = [{ label = "알겠다", on_select = _close }] })
		return
	var others := stone_maps().filter(func(id): return id != here and is_awake(id))
	var options: Array = others.map(func(id): return { label = Names.map(id), on_select = func():
		_close()
		World.travel_to(id) })
	options.append({ label = "그냥 걸어간다", on_select = _close })
	var sleeping := stone_maps().size() - others.size() - 1
	var text := "돌에 손을 얹자 먼 곳의 돌들이 웅웅 울린다. 어디로 갈까?" + ("\n(아직 깨우지 못한 석비가 %d개 남아 있다.)" % sleeping if sleeping > 0 else "") \
		if not others.is_empty() else "아직 깨운 석비가 여기뿐이다. 발로 뛰어 다른 석비를 찾아보자."
	DialogueBox.current.show_dialogue({ name = "%s의 석비" % Names.map(here), text = text, on_close = _close, options = options })
