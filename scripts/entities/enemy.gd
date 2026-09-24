class_name Enemy
extends Node2D
## 2D판 entities/Enemy.js. 들판의 적. 행동은 EnemyAI.
## 노드 원점이 발 위치(x, y)라 부모의 y 정렬이 앞뒤를 가른다.
##
## 그리는 순서: [이 노드] 그림자·빛·테두리 → [Body] 몸(변종 색 행렬) → [Top] 체력바. 이름표는 Overlay.

const COLOR_MATRIX := preload("res://shaders/color_matrix.gdshader")
# 적 종류별로 나오는 소재. 없으면 HIDE (data/materials.js 의 BY_ENEMY)
const MATERIAL_BY_ENEMY := {
	"SLIME": "HIDE", "FROST_SLIME": "HIDE", "MAGMA_SLIME": "HIDE",
	"CRAB": "HIDE", "SAND_CRAB": "HIDE", "PREY": "HIDE",
	"SPIDER": "FANG", "EMBER_SPIDER": "FANG", "BAT": "FANG", "SNOW_BAT": "FANG",
	"GOBLIN": "FANG", "RAT": "FANG", "BANDIT": "FANG", "GHOST": "FANG",
	"CULTIST": "ORE", "ICE_MAGE": "ORE",
}
const ELITE_ELEMENT_KO := { "FIRE": "불", "ICE": "얼음", "THUNDER": "번개" }

var x: float:
	get: return position.x
	set(v): position.x = v
var y: float:
	get: return position.y
	set(v): position.y = v

var type: String
var def: Dictionary
var elite := false
var affix = null              # 정예는 접사로 다르게 싸운다 (data/affixes)
var hp: float
var max_hp: float
var hit_flash := 0.0
var angle := 0.0
var phase := randf() * 6.28
var shot_timer := 1 + randf() * 2
var status := {}
var status_immune := false
var knock = null              # { x, y, t } 맞고 움찔하는 표시 (자리는 그대로, 그림만 어긋난다)
var squash := 0.0             # 눌렸다 튕겨 돌아오는 0.14초
var frenzied := false
var remove := false
var is_hidden := false        # 땅속에 있을 땐 못 맞힌다
var ai := {}
var home := Vector2.ZERO
var aggro := false
var guard_angle = null
var summoned_by = null
var split_child := false
var is_guardian := false
var target = null             # 노리는 용 (EnemyAI 가 고른다. null 이면 나)
var hit_by = null             # 마지막으로 나를 친 용
var hit_at := -99.0

var _body: Node2D
var _top: Node2D
var _cur_pose := {}           # 이번 프레임의 몸 자리 (테두리와 몸이 같은 떨림을 써야 한다)


## elite: 정예 — 크고 단단하고 아프지만 보상이 두둑하다
## 땅마다 적의 세기. 체력은 그대로 곱하고, 때리는 힘은 절반만큼 곱한다 (굴은 입구가 있는 지도를 따른다)
const MAP_POWER := { "SOUTH_ROAD": 1.35, "HOLLOW": 1.25, "HOLLOW_DEEP": 1.6, "MORGATH_LAIR": 1.6,
	"JUNGLE": 1.8, "JUNGLE_DEEP": 2.0, "ZALGORA_LAIR": 2.0, "SKY_RUINS": 1.9, "ROOTVALE": 1.8,
	"SNOW_ROAD": 2.0, "SNOW_RIDGE": 2.2, "GLACIA_LAIR": 2.2, "DESERT": 2.2, "DESERT_BONES": 2.4,
	"BASIL_LAIR": 2.4, "STONEBACK": 2.2, "ASH_CITY": 2.4, "AUTUMN": 2.4, "VOLCANO": 2.6, "VOLCANO_PATH": 2.7, "IGNAR_LAIR": 2.7 }
var power := 1.0

static func map_power() -> float: return MAP_POWER.get(GameState.map_id, 1.0)


static func make(px: float, py: float, t: String, is_elite := false) -> Enemy:
	var e := Enemy.new()
	e.x = px; e.y = py
	e.type = t
	e.def = Data.get_module("enemies").ENEMIES[t]
	e.elite = is_elite
	if is_elite: e.affix = _roll_affix(e.def)
	e.max_hp = e.def.hp * (2.2 if is_elite else 1.0) * (0.8 if e.affix and e.affix.id == "SPLIT" else 1.0)
	var k := map_power() if t != "DUMMY" else 1.0
	e.max_hp *= k
	e.power = 1.0 + (k - 1.0) * 0.45
	e.hp = e.max_hp
	EnemyAI.init_ai(e)
	e.name = "Enemy_%s_%d" % [t, e.get_instance_id()]
	return e


## 정예에게 접사를 하나 준다. 거울은 그 적이 쓰지 않는 속성 중 하나를 막는다
static func _roll_affix(d: Dictionary) -> Dictionary:
	var ids: Array = Data.get_module("affixes").AFFIX_IDS
	var id: String = ids[floori(randf() * ids.size())]
	if id != "MIRROR": return { id = id }
	var pool := ["FIRE", "ICE", "THUNDER"].filter(func(el): return el != d.get("element"))
	return { id = id, element = pool[floori(randf() * pool.size())] }


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body = Node2D.new()
	var mat := ShaderMaterial.new()
	mat.shader = COLOR_MATRIX
	mat.set_shader_parameter("m", filter_matrix(def.get("filter", "")) if def.get("filter") else Basis.IDENTITY)
	_body.material = mat
	_body.draw.connect(_draw_body)
	add_child(_body)
	_top = Node2D.new()
	_top.draw.connect(_draw_top)
	add_child(_top)


func light():
	if elite: return { r = 150, color = "#ffd84a", intensity = 0.7 }
	return { r = 120, color = def.glow, intensity = 0.6 } if def.get("glow") else null


func update(dt: float) -> void:
	if hit_flash > 0: hit_flash -= dt * 10
	if knock and knock.t > 0: knock.t -= dt * 6
	if squash > 0: squash -= dt * 7
	var speed: float = def.speed * Status.update(self, dt)
	if remove: return
	if def.move == "none": return   # 수련용 허수아비
	# 광폭: 궁지에 몰리면 폭주한다
	frenzied = affix != null and affix.id == "FRENZY" and hp < max_hp * 0.3
	if frenzied: speed *= 1.6
	EnemyAI.update(self, dt, speed)   # 예고 → 발동 → 숨 고르기


## silent: 지속 피해(화상)처럼 번쩍임 없이 깎을 때
func take_damage(dmg: float, silent := false, from = null) -> void:
	if is_hidden: return                 # 땅속에 있을 땐 못 맞힌다
	if affix and from and not silent:
		var ax: String = affix.id
		if ax == "MIRROR" and from is Projectile and from.element == affix.element:
			Vfx.spawn_text(x, y - 52, "튕김", "#ffe27a", 13)
			Vfx.spawn_effect("SPARK", x, y - 20, { size = 0.8, color = "#ffe27a" })
			return
		if ax == "ARMORED":
			var da := atan2(from.y - y, from.x - x) - angle
			da = atan2(sin(da), cos(da))
			if absf(da) < PI * 0.39:
				dmg *= 0.4; Vfx.spawn_text(x, y - 52, "단단함", "#b8c8d8", 12)
		if ax == "PLAGUE" and not status.is_empty():
			for o in GameState.entities.enemies:
				if o == self or o.remove or Util.dist(o, self) > 150: continue
				for k in ["BURN", "SLOW"]:
					if status.get(k, 0) > 0: Status.apply(o, k, status[k] * 0.8)
	hp -= dmg
	var who = Combat.attacker_of(from)
	if who != null and not silent:
		hit_by = who; hit_at = GameState.game_time
	if not silent: EnemyAI.alert(self)              # 먼저 때리면 그 무리가 돌아본다
	if not silent:
		hit_flash = 1.0
		squash = 1.0                     # 옆으로 퍼지고 위아래로 눌린다
		# 맞은 쪽으로 밀린다. 맞은 티가 나야 때린 맛이 난다
		if from:
			var a := atan2(y - from.y, x - from.x)
			var push := minf(14, 5 + dmg * 0.4) * (0.55 if elite else 1.0)
			knock = { x = cos(a) * push, y = sin(a) * push, t = 1.0 }
	if hp <= 0 and not remove:
		# 마지막 타는 한 박자 멈추고 화면이 살짝 흔들린다. 정예는 더 길게
		Feedback.hit_stop(0.11 if elite else 0.07)
		GameCamera.current.shake(5 if elite else 2)
		die()


func die() -> void:
	remove = true
	if not def.get("noLoot"): Flow.on_kill(elite)
	if def.get("noLoot"):   # 허수아비도 첫 퀘스트가 센다
		Vfx.spawn_effect("PUFF", x, y - 16); Sfx.play("die"); Quests.notify("kill", type)
		return
	if affix and affix.id == "SPLIT" and not split_child:   # 둘로 갈라진다 (한 번만)
		for side in [-1, 1]:
			var c := Enemy.make(x + side * 34, y + 8, type, false)
			c.split_child = true; c.aggro = true
			c.max_hp = roundf(def.hp * 0.35 * map_power()); c.hp = c.max_hp; c.power = power
			World.add_entity("enemies", c)
			Particles.burst(c.x, c.y, def.color, 0.6, 6)
	# 몸이 가로 띠로 쪼개져 흩날린다
	var sp: Array = def.sprite
	Vfx.spawn_shatter(x, y - (22 if def.get("flying") else 4), TileImages.get_image("dungeon"), Rect2(sp[0] * 16, sp[1] * 16, 16, 16),
		{ scale = 4.5 if elite else 3.0, flip = cos(angle) < 0, color = def.color })
	var bonus := 3 if elite else 1
	GameState.player.gain_xp(def.xp * bonus * NightEvents.xp_mult())
	GameState.stats.kills[type] = GameState.stats.kills.get(type, 0) + 1
	if elite and not GameState.stats.get("eliteOffer"):
		GameState.stats.eliteOffer = true   # 처음 쓰러뜨린 우두머리: 유물을 셋 중 하나 고른다 (첫 시간에 고를 거리가 없던 것)
		RelicOffer.offer("처음 쓰러뜨린 금빛 정예에게서")
	elif elite and randf() < 0.3:
		var id = Relics.random_relic()
		if id: Relics.grant(id, x, y)
	Particles.burst(x, y, def.color, 0.8 if elite else 0.6, 18 if elite else 12, 380.0 if elite else 300.0)
	Vfx.spawn_effect("PUFF" if def.get("flying") else "SMOKE", x, y - 16, { size = 1.8 if elite else 1.0 })
	Vfx.spawn_effect("SHOCKWAVE", x, y, { size = 1.2 if elite else 0.6, color = def.color })
	Sfx.play("dieBig" if elite else "die")
	var meat: int = int(def.meat) if def.get("meat") != null else (1 if randf() < 0.45 else 0)
	for i in meat: World.add_entity("items", Item.make(x + i * 22, y, "MEAT"))
	if randf() < 0.7: World.add_entity("items", Item.make(x - 16, y, "GOLD", maxi(2, roundi(def.xp / 7.0)) * bonus))
	# 대장간 소재. 정예는 확실히, 보통은 절반쯤 떨어뜨린다
	var mats := 2 if elite else (1 if randf() < 0.5 else 0)
	for i in mats: World.add_entity("items", Item.make(x + 20 - i * 30, y + 14, "MAT", MATERIAL_BY_ENEMY.get(type, "HIDE")))
	Quests.notify("kill", type)
	if def.move != "flee": Quests.notify("killAny")
	if elite: Quests.notify("elite")
	if is_guardian: Delve.on_guardian_down(self)


# ---------- 그리기 ----------

func _lift() -> float:
	return 22 + sin(GameState.game_time * 5 + phase) * 5 if def.get("flying") else 0.0


func _process(_dt: float) -> void:
	_body.material.set_shader_parameter("white", hit_flash > 0)
	_cur_pose = _pose()
	queue_redraw(); _body.queue_redraw(); _top.queue_redraw()


## 지금 몸을 그릴 자리와 모양
func _pose() -> Dictionary:
	var lift := _lift()
	var hop := absf(sin(GameState.game_time * 5 + phase)) * 10 if def.get("hop") else absf(sin(GameState.game_time * 10 + phase)) * 4
	var kx: float = knock.x * knock.t if knock and knock.t > 0 else 0.0
	var ky: float = knock.y * knock.t if knock and knock.t > 0 else 0.0
	var telling: bool = ai.s == "tell" or ai.s == "tell2"
	var sc := (4.5 if elite else 3.0) * (0.86 if telling else 1.0)
	# 눌림: 맞는 순간 가로 1.28 · 세로 0.74 로 찌그러졌다가 되돌아온다
	var q := sin(squash * PI) if squash > 0 else 0.0
	# 예고 중엔 몸이 부르르 떤다. 싸울 땐 시선이 적의 몸에 가 있지 바닥에 가 있지 않다
	var shiver := (randf() - 0.5) * 3.5 if telling else 0.0
	return { px = kx + shiver, py = 4 - (0.0 if telling else hop) - lift + ky, sc = sc, sx = 1 + 0.28 * q, sy = 1 - 0.26 * q,
		flip = cos(angle) < 0, telling = telling, lift = lift }


func _sprite(ci: CanvasItem, tex: Texture2D, pose: Dictionary, ox := 0.0, oy := 0.0) -> void:
	var sp: Array = def.sprite
	var src := Rect2(sp[0] * 16, sp[1] * 16, 16, 16)
	var w: float = 16 * pose.sc
	var h: float = 16 * pose.sc
	# 기준점(발)을 월드의 정수 좌표에 둔다. 원점이 (x, y) 라 월드로 옮겨 반올림한 뒤 되돌린다
	var xf := Transform2D(0, Vector2(roundf(x + pose.px + ox) - x, roundf(y + pose.py + oy) - y))
	if pose.flip: xf = xf.scaled_local(Vector2(-1, 1))
	xf = xf.scaled_local(Vector2(pose.sx, pose.sy))
	ci.draw_set_transform_matrix(xf)
	ci.draw_texture_rect_region(tex, Rect2(-w * 0.5, -h, w, h), src)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw() -> void:
	if is_hidden or _cur_pose.is_empty(): return   # 땅속 — 흙더미만 보인다 (바닥 예고)
	var pose := _cur_pose
	var lift: float = pose.lift
	# 그림자
	var r := 14.0 if def.get("flying") else 20.0
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO)
	var tint = Status.tint(self)
	if tint: Pixel.draw_glow(self, 0, -18 - lift, 34, tint, 0.55)
	if elite:
		var col := Color(Data.get_module("affixes").AFFIXES[affix.id].color) if affix else Color("#ffd84a")
		Pixel.draw_glow(self, 0, -26 - lift, 74 if frenzied else 58, Color("#ff3b1f") if frenzied else col, 0.4 + sin(GameState.game_time * (12 if frenzied else 5)) * 0.12)
	# 덤비기 직전엔 몸이 경고색으로 달아오른다
	if pose.telling: Pixel.draw_glow(self, pose.px, pose.py - 14, 46, Color("#ff6b3c"), 0.45 + sin(GameState.game_time * 24) * 0.35)
	# 16px 그림이라 풀숲에 묻힌다. 제 색으로 테를 둘러 배경에서 떼어 놓는다
	var sil := SpriteSheet.silhouette(TileImages.get_image("dungeon"), Color(def.color))
	for o in [[-3, 0], [3, 0], [0, -3], [0, 3]]: _sprite(self, sil, pose, o[0], o[1])


## 몸. 변종은 이 노드의 색 행렬을 탄다. 맞은 순간엔 하얗게 (셰이더의 white)
func _draw_body() -> void:
	if is_hidden or _cur_pose.is_empty(): return
	_sprite(_body, TileImages.get_texture("dungeon"), _cur_pose)


## 머리 위 작은 체력바. 다친 적만 보여준다
func _draw_top() -> void:
	if is_hidden: return
	var ratio := hp / max_hp
	if ratio >= 1 or ratio <= 0: return
	var up := (82.0 if elite else 58.0) + _lift()
	var width := 50.0 if elite else 34.0
	var bx := roundf(x - width / 2) - x
	var by := roundf(y - up) - y
	_top.draw_rect(Rect2(bx - 1, by - 1, width + 2, 6), Color(0, 0, 0, 0.65))
	_top.draw_rect(Rect2(bx, by, width * ratio, 4), Color("#7ddc5a") if ratio > 0.5 else Color("#ffc93c") if ratio > 0.25 else Color("#ff5a4d"))


## 머리 위 이름표 (Overlay 가 화면 픽셀로). 정예는 접사를 작게 한 줄 덧붙인다. 무엇과 싸우는지 알아야 싸움이 된다
func crisp_anchor() -> Vector2:
	return Vector2(roundf(x), roundf(y - ((96 if elite else 66) + _lift())))


func draw_crisp(ci: CanvasItem, _zoom: float) -> void:
	if is_hidden: return
	var bold := Fonts.bold()
	var nm: String = ("★ " if elite else "") + def.name
	var w := ceilf(Fonts.text_width(bold, nm, 12)) + 12
	ci.draw_rect(Rect2(-w / 2, -14, w, 18), Color(8 / 255.0, 7 / 255.0, 14 / 255.0, 0.72))
	Fonts.draw_centered(ci, bold, nm, 0, 0, 12, Color("#ffd84a") if elite else Color("#e8dcc4"))
	if affix:
		var ax: Dictionary = Data.get_module("affixes").AFFIXES[affix.id]
		var tag: String = ax.name + ("·" + ELITE_ELEMENT_KO[affix.element] if affix.get("element") else "")
		var font := Fonts.regular()
		var tw := ceilf(Fonts.text_width(font, tag, 12)) + 10
		ci.draw_rect(Rect2(-tw / 2, -30, tw, 14), Color(8 / 255.0, 7 / 255.0, 14 / 255.0, 0.72))
		Fonts.draw_centered(ci, font, tag, 0, -19, 12, Color(ax.color))


## CSS filter 문자열("hue-rotate(40deg) brightness(1.35)" 등)을 색 행렬 하나로 (Filter Effects 명세의 행렬)
static func filter_matrix(filter: String) -> Basis:
	var m := Basis.IDENTITY
	var re := RegEx.create_from_string("([a-z-]+)\\(([-0-9.]+)(deg)?\\)")
	for r in re.search_all(filter):
		var v := float(r.get_string(2))
		var f := Basis.IDENTITY
		match r.get_string(1):
			"hue-rotate":
				var a := deg_to_rad(v)
				var c := cos(a)
				var s := sin(a)
				f = _rows(0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928,
					0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283,
					0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072)
			"saturate":
				f = _rows(0.213 + 0.787 * v, 0.715 - 0.715 * v, 0.072 - 0.072 * v,
					0.213 - 0.213 * v, 0.715 + 0.285 * v, 0.072 - 0.072 * v,
					0.213 - 0.213 * v, 0.715 - 0.715 * v, 0.072 + 0.928 * v)
			"grayscale":
				var g := 1 - minf(1, v)
				f = _rows(0.2126 + 0.7874 * g, 0.7152 - 0.7152 * g, 0.0722 - 0.0722 * g,
					0.2126 - 0.2126 * g, 0.7152 + 0.2848 * g, 0.0722 - 0.0722 * g,
					0.2126 - 0.2126 * g, 0.7152 - 0.7152 * g, 0.0722 + 0.9278 * g)
			"brightness":
				f = Basis.from_scale(Vector3(v, v, v))
		m = f * m   # 앞의 필터를 먼저 적용한다
	return m


## 행 단위로 적은 3x3 행렬 (Basis 는 열 단위로 받는다)
static func _rows(a: float, b: float, c: float, d: float, e: float, f: float, g: float, h: float, i: float) -> Basis:
	return Basis(Vector3(a, d, g), Vector3(b, e, h), Vector3(c, f, i))
