class_name Combat
## 2D판 systems/combat.js. 탄 충돌과 치우기.

const HIT_RADIUS := 30


## 싸우는 중인가: 나를 알아챈 적이 r 안에 있다 (도망치는 사냥감 · 허수아비는 빼고)
static func in_fight(r := 600.0) -> bool:
	var p = GameState.player
	if p == null: return false
	for e in GameState.entities.enemies:
		if e.remove or e.def.get("move") == "flee" or e.type == "DUMMY": continue
		if e.get("aggro") and Util.dist(e, p) < r: return true
	for h in GameState.entities.humans:
		if not h.remove and Util.dist(h, p) < r: return true
	return false


## 플레이어 편에서 싸우는 용들: 쓰러지지 않은 마을 고정 NPC, 짝, 동료
static func allies() -> Array:
	return GameState.entities.npcs.filter(func(n): return n.down_timer <= 0 and (n.config.get("fixed") or n.state != "WANDER"))


## 곁에서 싸우는 용(동료 · 마을 용)이 아직 설 수 있나: 쓰러지지 않았고 이 지도에 있다
static func alive_ally(n) -> bool:
	return is_instance_valid(n) and n is Dragon and not n.is_player and not n.remove and n.down_timer <= 0 and GameState.entities.npcs.has(n)


## 맞힌 것(탄 · 용)을 쏜 용. 모르면 null
static func attacker_of(from):
	if from is Projectile: return from.by if from.by != null else (GameState.player if from.from_player else null)
	if from is Dragon: return from
	return null


## 브레스를 맞힐 수 있는 상대인가: 허수아비, 땅속에 숨은 적,
## 잠들었거나 쓰러지는 · 무릎 꿇은 · 장면을 기다리는 보스는 아니다
static func hittable(e) -> bool:
	if e.remove or e.get("is_hidden") or e.type == "DUMMY": return false
	if e is Boss: return e.awake and e.dying <= 0 and not e.lingering and e.vanishing <= 0 and not e.yielding and not e.rising and e.risen >= 1.0
	return true


## 총알 충돌. ALLY 총알은 적/인간에게, ENEMY 총알은 플레이어(와 마을 용)에게만 맞는다
static func resolve() -> void:
	var E: Dictionary = GameState.entities
	var player = GameState.player
	for b in E.bullets:
		if b.remove: continue
		if b.faction == "ALLY":
			var targets: Array = E.enemies + E.humans + E.bosses
			# 큰 상대(보스·대장)는 몸통이 넓다. 관통탄은 이미 맞힌 적을 건너뛴다
			for e in targets:
				if e.remove or b.hit_set.has(e): continue
				var big: bool = e.def.get("scale") != null
				if Util.dist(b, Vector2(e.x, e.y - (50 if big else 20))) < (60 if big else 0) + b.radius:
					b.hit(e, targets)
					break
		elif Util.dist(b, Vector2(player.x, player.y - 30)) < HIT_RADIUS:
			b.hit(player)
		elif not GameState.activity:   # 적의 화살·마법은 마을 용들도 맞는다
			for n in allies():
				if Util.dist(b, Vector2(n.x, n.y - 30)) < HIT_RADIUS:
					b.hit(n)
					break
