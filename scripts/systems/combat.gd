class_name Combat
## 2D판 systems/combat.js. 탄 충돌과 치우기.

const HIT_RADIUS := 30


## 플레이어 편에서 싸우는 용들: 쓰러지지 않은 마을 고정 NPC, 짝, 동료
static func allies() -> Array:
	return GameState.entities.npcs.filter(func(n): return n.down_timer <= 0 and (n.config.get("fixed") or n.state != "WANDER"))


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
