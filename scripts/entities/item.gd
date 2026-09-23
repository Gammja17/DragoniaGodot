class_name Item
extends Node2D
## 2D판 entities/Item.js. 바닥에 떨어진 것: 'MEAT' | 'EGG' | 'GOLD' | 'MAT'.
## 골드와 소재는 가까이 가면 빨려 들어온다 (E 안 눌러도 됨). 고기·알은 줍기를 옮길 때 [E] 로.

var x: float:
	get: return position.x
	set(v): position.x = v
var y: float:
	get: return position.y
	set(v): position.y = v

var type: String
var value = 0                 # GOLD 면 액수, MAT 이면 소재 id
var t := 0.0
var remove := false


static func make(px: float, py: float, kind: String, v = 0) -> Item:
	var it := Item.new()
	it.x = px; it.y = py
	it.type = kind; it.value = v
	it.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return it


func update(dt: float) -> void:
	t += dt * 3
	queue_redraw()
	if type != "GOLD" and type != "MAT": return
	var p = GameState.player
	var d := Util.dist(self, p)
	if d < 40:
		if type == "MAT":
			GameState.materials[value] = GameState.materials.get(value, 0) + 1
			Vfx.spawn_text(p.x, p.y - 90, "%s +1" % Data.get_module("materials").MATERIALS[value].name, "#d8c39a", 14)
			Sfx.play("pickup")
		else:
			var gain := roundi(value * (1.3 if Relics.has("LUCKY_COIN") else 1.0))
			p.gold += gain
			Vfx.spawn_text(p.x, p.y - 90, "+%dG" % gain, "#ffd84a", 15)
			Sfx.play("coin")
		remove = true
	elif d < 170:
		x += ((p.x - x) / d) * 420 * dt
		y += ((p.y - y) / d) * 420 * dt


func _draw() -> void:
	var bob := sin(t) * 5
	draw_set_transform(Vector2(0, 20), 0, Vector2(1, 5 / (14 - bob * 0.4)))
	draw_circle(Vector2.ZERO, 14 - bob * 0.4, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	Pixel.draw_glow(self, 0, bob, 30, Color("#fff4c2"), 0.35 + sin(t * 1.3) * 0.15)   # 주울 수 있다는 표시
	var icon: String = "COIN" if type == "GOLD" else Data.get_module("materials").MATERIALS[value].icon if type == "MAT" else type
	Pixel.draw_icon(self, icon, 0, bob)
