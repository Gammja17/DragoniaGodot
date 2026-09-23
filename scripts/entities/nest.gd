class_name Nest
extends Node2D
## 2D판 entities/Nest.js. 알을 품는 둥지 (내 굴 안에만 있다).

var x: float:
	get: return position.x
	set(v): position.x = v
var y: float:
	get: return position.y
	set(v): position.y = v

var has_egg := false
var progress := 0.0      # 0~100, 플레이어가 근처에 있으면 빨리 찬다
var genes = null         # 알 속 아이의 { species, colors, look }
var remove := false
var is_hidden := false


static func make(px: float, py: float) -> Nest:
	var n := Nest.new()
	n.x = px; n.y = py
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return n


## a, b: 부모 드래곤. b 가 없으면 주워 온 알
func lay_egg(a, b) -> void:
	has_egg = true
	progress = 0.0
	genes = Kids.mix_genes(a, b)


## 사냥꾼이 알을 노린다. 부화 진행도가 깎이고, 바닥나면 알을 빼앗긴다
func attack_egg(amount: float) -> void:
	if not has_egg: return
	progress -= amount
	Particles.burst(x, y, "#ff5a4d", 0.6, 6)
	if progress < 0:
		has_egg = false
		progress = 0.0
		Hud.pop("사냥꾼에게 알을 빼앗겼습니다…!", "💔")


func update(dt: float) -> void:
	queue_redraw()
	if not has_egg: return
	var near := Util.dist(self, GameState.player) < 120
	# 곁에서 품으면 하루 반, 밤에 곁에서 자면 하룻밤에 +25 (Story 의 sleep)
	progress += (dt * 0.25 if near else dt * 0.05) * (1.5 if Relics.has("NEST_CHARM") else 1.0)
	if progress > 100: hatch()


func hatch() -> void:
	has_egg = false
	progress = 0.0
	var baby := BabyDragon.make(x + Util.rand_range(-20, 20), y + Util.rand_range(-20, 20), genes)
	World.add_entity("babies", baby)
	Kids.register(baby)
	Quests.notify("hatch")
	Hud.pop("아기 용이 태어났습니다!", "🐣")
	# 색 12가지 (hsl(k·30, 100%, 60%))
	Particles.burst(x, y, func():
		var rgb := Util.hsl_to_rgb(floori(randf() * 12) * 30, 1.0, 0.6)
		return Color8(roundi(rgb[0]), roundi(rgb[1]), roundi(rgb[2])), 1, 25)
	Vfx.spawn_effect("RING", x, y)


func _draw() -> void:
	# 돌무더기 터는 지형에 구워져 있다. 둥지를 지으면 그 안에 짚을 깐다
	if GameState.den.built:
		_ellipse(0, 2, 30, 17, Color("#6b4a22"))
		_ellipse(0, 0, 25, 13, Color("#d8b25a"))
		for i in 7:
			var a := i * 0.9
			draw_line(Vector2(cos(a) * 8, sin(a) * 4), Vector2(cos(a) * 26, sin(a) * 13), Color("#a07a30"), 2)
		# 깜깜한 굴에서도 눈에 띄도록. 알이 없으면 "여기서 잘 수 있다"는 표시를 띄운다
		Pixel.draw_glow(self, 0, -4, 44, Color("#ffd89a"), 0.24)
		if not has_egg:
			var bob := sin(GameState.game_time * 2.2) * 3
			Fonts.draw_centered(self, Fonts.bold(), "💤", 0, -30 + bob, 24, Color(1, 226 / 255.0, 170 / 255.0, 0.9))
	if not has_egg: return
	var wobble := sin(GameState.game_time * 25) * 2 if progress > 80 else 0.0
	Pixel.draw_glow(self, 0, -4, 40, Color("#fff2c8"), 0.35 + progress / 250)
	Pixel.draw_icon(self, "EGG", wobble, -6)
	draw_arc(Vector2.ZERO, 50, 0, TAU, 48, Color(0, 0, 0, 0.45), 6)
	draw_arc(Vector2.ZERO, 50, -PI / 2, -PI / 2 + TAU * progress / 100, 48, Color("#ffd866"), 3)


func _ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	draw_set_transform(Vector2(cx, cy), 0, Vector2(1, ry / rx))
	draw_circle(Vector2.ZERO, rx, c)
	draw_set_transform(Vector2.ZERO)
