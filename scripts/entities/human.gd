class_name Human
extends Node2D
## 2D판 entities/Human.js. 마을을 습격하는 사냥꾼. type: data/enemies 의 HUNTERS 키.
##
## 그리는 순서: [이 노드] 그림자·빛·돌진 예고선·내려치기 범위 → [Body] 몸(맞으면 하얗게) → [Top] 체력바

const COLOR_MATRIX := preload("res://shaders/color_matrix.gdshader")

var x: float:
	get: return position.x
	set(v): position.x = v
var y: float:
	get: return position.y
	set(v): position.y = v

var type: String
var def: Dictionary
var hp: float
var max_hp: float
var angle := 0.0
var hit_flash := 0.0
var cooldown := 1.0
var power := 1.0            # 습격 회차에 따른 공격력 배율 (systems/raid)
var swing := 0.0            # 내려치기 예고 (초)
var swing_at = null
var stagger := 0.0          # 돌진이 빗나가 비틀거리는 시간. 그동안 두 배로 맞는다
var charge = null           # { windup, t, dir, speed, hit } 베르단의 포위에서 쓴다 (systems/ambush)
var hold_back := false      # 뒤에서 지휘만 하는 대장
var fleeing := false
var hunts = null            # 이 습격에서 노리기로 한 용의 이름
var status := {}
var status_immune := false
var remove := false
var is_hidden := false

var _body: Node2D
var _top: Node2D


static func make(px: float, py: float, t := "KNIGHT") -> Human:
	var h := Human.new()
	h.x = px; h.y = py
	h.type = t
	h.def = Data.get_module("enemies").HUNTERS[t]
	h.hp = h.def.hp; h.max_hp = h.def.hp
	h.name = "Human_%s_%d" % [t, h.get_instance_id()]
	return h


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body = Node2D.new()
	var mat := ShaderMaterial.new()
	mat.shader = COLOR_MATRIX
	_body.material = mat
	_body.draw.connect(_draw_body)
	add_child(_body)
	_top = Node2D.new()
	_top.draw.connect(_draw_top)
	add_child(_top)


## 머리 위에 한마디. 대장의 외침은 화면 위에도 띄운다
func say(text: String) -> void:
	Vfx.spawn_text(x, y - 70, text.substr(0, 12) + "…" if text.length() > 12 else text, "#ffd8c0", 14)
	if type == "CAPTAIN": Hud.pop(text, "📣")


## 알이 있는 둥지가 가까우면 둥지, 아니면 가장 가까운 용(플레이어·마을 용·동료)
func _pick_target():
	var nests: Array = GameState.entities.nests
	if not nests.is_empty() and nests[0].has_egg and Util.dist(self, nests[0]) < 320: return nests[0]
	# 이 습격에서 특정한 용만 노리기로 한 사냥꾼 (RESCUE)
	if hunts:
		for n in GameState.entities.npcs:
			if n.config.get("name") == hunts and not (n.down_timer > 0): return n
	var best = GameState.player
	var best_d := Util.dist(self, best)
	for a in Combat.allies():
		var d := Util.dist(self, a)
		if d < best_d:
			best = a; best_d = d
	return best


func update(dt: float) -> void:
	if hit_flash > 0: hit_flash -= dt * 10
	cooldown -= dt
	var speed: float = def.speed * Status.update(self, dt)
	if remove or speed == 0: return
	var p = GameState.player
	# 달아난다: 플레이어에게서 멀어지다가 화면 밖으로 나가면 사라진다
	if fleeing:
		var a := atan2(y - p.y, x - p.x)
		angle = a + PI
		Collision.slide_move(self, x + cos(a) * speed * 1.4 * dt, y + sin(a) * speed * 1.4 * dt, 14)
		if Util.dist(self, p) > 1000: remove = true
		return
	if stagger > 0:
		stagger -= dt
		return
	if charge:
		_update_charge(dt)
		return
	var target = _pick_target()
	var d := Util.dist(self, target)
	angle = atan2(target.y - y, target.x - x)
	# 내려치기 예고. 0.45초 동안 칼을 치켜들고, 그때도 닿는 거리에 있어야 맞는다 (대시로 빠져나갈 수 있다)
	if swing > 0:
		swing -= dt
		if swing <= 0:
			if Util.dist(self, swing_at) < def.range + 34: _attack(swing_at)
			cooldown = def.cooldown
		return
	# 뒤에서 지휘만 하는 대장: 너무 가까워지면 물러선다
	if hold_back:
		if d < 330: Collision.slide_move(self, x - cos(angle) * speed * dt, y - sin(angle) * speed * dt, 14)
		return
	if d > def.range:
		Collision.slide_move(self, x + cos(angle) * speed * dt, y + sin(angle) * speed * dt, 14)
	elif cooldown <= 0:
		var nests: Array = GameState.entities.nests
		if def.attack == "MELEE" and (nests.is_empty() or target != nests[0]):
			swing = 0.45; swing_at = target
		else:
			_attack(target); cooldown = def.cooldown


func _attack(target) -> void:
	var aim := atan2(target.y - 30 - (y - 16), target.x - x)
	var nests: Array = GameState.entities.nests
	match def.attack:
		"ARROW":
			Projectile.add(Projectile.new(x, y - 16, aim, { faction = "ENEMY", kind = "ARROW", damage = def.damage * power, speed = 520 }))
		"NET":
			# 그물은 느리게 날아오니 보고 피할 수 있다. 맞으면 한동안 느려진다
			Projectile.add(Projectile.new(x, y - 16, aim, { faction = "ENEMY", kind = "ARROW", damage = def.damage * power, speed = 300, life = 1.6, slow = 2.6 }))
		"ORB":
			Projectile.add(Projectile.new(x, y - 16, aim, { faction = "ENEMY", element = "FIRE", damage = def.damage * power, speed = 300, life = 2.4, scale = 0.7 }))
		_:
			if not nests.is_empty() and target == nests[0]: target.attack_egg(30)
			else: target.take_damage(def.damage * power)


## 돌진: 예고 뒤에 한 방향으로 내달린다. 맞히지 못하면 비틀거린다 (간발로 피할 수 있다)
func _update_charge(dt: float) -> void:
	var c: Dictionary = charge
	var p = GameState.player
	if c.windup > 0:
		c.windup -= dt; angle = c.dir
		return
	c.t -= dt
	Collision.slide_move(self, x + cos(c.dir) * c.speed * dt, y + sin(c.dir) * c.speed * dt, 14)
	if randf() < 0.5: Particles.burst(x, y, "#c9a24a", 0.6, 2)
	if not c.hit and Util.dist(self, p) < 70:
		c.hit = true
		p.take_damage(def.damage * power * 1.6)
		p.x += cos(c.dir) * 90; p.y += sin(c.dir) * 90
		GameCamera.current.shake(10)
	if c.t <= 0:
		charge = null
		if not c.hit:
			stagger = 2.4
			Vfx.spawn_text(x, y - 80, "비틀!", "#9fe3ff", 16)
			Vfx.spawn_effect("PUFF", x, y - 10, { size = 1.4 })
		cooldown = 1.0


func take_damage(dmg: float, silent := false, _from = null) -> void:
	if stagger > 0: dmg *= 2   # 빈틈
	hp -= dmg
	if not silent: hit_flash = 1.0
	if hp <= 0 and not remove: die()


func die() -> void:
	remove = true
	Flow.on_kill(type == "CAPTAIN")
	if type == "CAPTAIN": GameState.raid.captainFell = true
	# 베르단의 포위에서 대장이 쓰러지면 남은 사냥꾼이 흔들리는 것은 포위를 옮길 때
	GameState.player.gain_xp(def.xp * NightEvents.xp_mult())
	GameState.stats.kills.HUNTER = GameState.stats.kills.get("HUNTER", 0) + 1
	Quests.notify("kill", "HUNTER")
	Quests.notify("killAny")
	Vfx.spawn_effect("SMOKE", x, y - 16, { size = 1.8 if def.get("scale") else 1.0 })
	World.add_entity("items", Item.make(x, y, "GOLD", def.gold))
	if randf() < 0.6: World.add_entity("items", Item.make(x + 20, y, "MEAT"))
	# 사냥꾼의 갑옷 조각 — 대장간 소재 중 가장 귀한 것
	var ore := 4 if type == "CAPTAIN" else (1 if randf() < 0.55 else 0)
	for i in ore: World.add_entity("items", Item.make(x - 18 - i * 26, y + 12, "MAT", "ORE"))
	if type == "CAPTAIN":
		Hud.pop("사냥꾼 대장을 쓰러뜨렸습니다!", "🏆")
		Vfx.spawn_text(x, y - 80, "대장 처치!", "#ffd84a", 22)


# ---------- 그리기 ----------

func _scale() -> float:
	return def.scale if def.get("scale") else 3.0


func _process(_dt: float) -> void:
	_body.material.set_shader_parameter("white", hit_flash > 0)
	queue_redraw(); _body.queue_redraw(); _top.queue_redraw()


func _draw() -> void:
	var sc := _scale()
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 20 * sc / 3, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO)
	var tint = Status.tint(self)
	if tint: Pixel.draw_glow(self, 0, -18, 34 * sc / 3, tint, 0.55)
	if charge and charge.windup > 0:   # 돌진 예고: 붉은 선
		var k: float = 1 - charge.windup / 0.75
		draw_dashed_line(Vector2.ZERO, Vector2(cos(charge.dir), sin(charge.dir)) * 520, Color(1, 90 / 255.0, 60 / 255.0, 0.3 + k * 0.5), 8 + k * 10, 18)
	if stagger > 0: Pixel.draw_glow(self, 0, -18, 40, Color("#9fe3ff"), 0.4 + sin(GameState.game_time * 14) * 0.2)
	if swing > 0:   # 치켜든 칼: 닿는 범위가 붉게 차오른다
		var k := 1 - swing / 0.45
		var r: float = (def.range + 20) * k
		if r > 0:
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.55))
			draw_circle(Vector2.ZERO, r, Color(1, 70 / 255.0, 50 / 255.0, 0.12 + k * 0.25))
			draw_set_transform(Vector2.ZERO)


func _draw_body() -> void:
	var sc := _scale()
	var bob := absf(sin(GameState.game_time * 9 + x)) * 3
	var sp: Array = def.sprite
	var w := 16 * sc
	var xf := Transform2D(0, Vector2(roundf(x) - x, roundf(y + 4 - bob) - y))
	if cos(angle) < 0: xf = xf.scaled_local(Vector2(-1, 1))
	_body.draw_set_transform_matrix(xf)
	_body.draw_texture_rect_region(TileImages.get_texture("dungeon"), Rect2(-w * 0.5, -w, w, w), Rect2(sp[0] * 16, sp[1] * 16, 16, 16))
	_body.draw_set_transform_matrix(Transform2D.IDENTITY)


## 머리 위 작은 체력바. 다친 사냥꾼만 보여준다
func _draw_top() -> void:
	var ratio := hp / max_hp
	if ratio >= 1 or ratio <= 0: return
	var sc := _scale()
	var width := 60.0 if sc > 3 else 34.0
	var bx := roundf(x - width / 2) - x
	var by := roundf(y - (16 * sc + 8)) - y
	_top.draw_rect(Rect2(bx - 1, by - 1, width + 2, 6), Color(0, 0, 0, 0.65))
	_top.draw_rect(Rect2(bx, by, width * ratio, 4), Color("#7ddc5a") if ratio > 0.5 else Color("#ffc93c") if ratio > 0.25 else Color("#ff5a4d"))
