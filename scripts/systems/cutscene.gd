class_name Cutscene
## 2D판 systems/cutscene.js 에서 출발한 컷씬 연출. 장면을 대사만 넘기는 게 아니라 '찍을' 수 있게 넓혔다.
##
## 사건이 터지면:
##   · 위아래로 검은 띠가 내려오고, HUD·알림이 물러난다
##   · 화면이 어두워지고, 무대에 오른 이들에게만 빛이 남는다
##   · 카메라가 천천히 다가가며 당겨진다 (장면이 열릴 때 멀리서부터 스르르)
##   · 말하는 쪽이 반걸음 나서고, 곁의 이들은 말하는 쪽을 돌아본다. 세상이 멈춰 있어도 숨 쉬고 걷는다
##   · 장면 제목이 화면 가운데에 한 번 떴다 사라진다
##
## 대사 한 줄(line)에 연출 박자(do)를 달 수 있다. 박자는 그 대사가 뜨기 전에 차례로 돈다 (그동안 대화창은 내려간다).
##   { wait = 0.8 }                                   잠깐의 정적
##   { move = "Poco", to = [dx, dy] | "near:Elder" | "look:PROP:FOUNTAIN" | "home", speed?, async? }
##                                                    [dx, dy] 는 장면이 열린 자리(내 발밑)에서 잰다
##   { exit = "Poco", side? = "left" | "right" }      화면 밖으로 걸어 나가며 사라진다
##   { face = "Poco", to = "left" | "right" | "up" | "down" | "나" | "Elder" }
##   { emote = "Poco", icon = "!" | "?" | "…" | "♥" | "!?" | "♪" | "💧" | "💢", async? }
##   { cam = "Elder" | "나" | "look:…" | [dx, dy] | "auto", zoom?, time? }   카메라가 time 초에 걸쳐 옮겨 간다
##   { zoom = 1.4 }                                   배율만 바꾼다 (장면 끝까지)
##   { shake = 12 } · { flash = "#ffffff", a? } · { sfx = "boom" } · { fx = "SHOCKWAVE", at = "Gron", size?, color? }
##   { bgm = "hollow" | "none" | "auto" }             장면에 깔 곡. "none" 은 음악을 걷어 정적을 만든다
##   { tone = "memory" | "grief" | "dread" | "warm" | "none" }   화면의 색 (회상은 바랜 색)
##   { fade = "out" | "in", time?, text? }            까맣게 덮었다가 걷는다. text 는 덮인 화면 가운데의 글 ("그날 밤")
##   { caption = "사흘 뒤", time? }                   화면 가운데 큰 글
##   { card = "옛 수호룡 모르가스", sub = "달빛 골짜기의 주인", time? }   이름패 (보스·새 땅)
##   { hide = "Gron" } · { show = "Gron" } · { down = "Gron" } · { up = "Gron" }
## 한 줄에는 그 밖에 zoom(그 줄만 당겨 본다) · auto(초. 다 찍히고 이만큼 뒤 저절로 넘어간다)를 달 수 있다.
## 대사(text) 없이 do 만 있는 줄은 연출만 하고 넘어간다.
## 세계 자체는 대화창이 떠 있는 동안 main 이 멈춰 둔다. 여기서는 "어떻게 보이는가"만 맡는다.
## 그리는 것은 CutsceneView (어둠·띠) 와 CinemaOverlay (검은 막·가운데 글).

const BAR := 0.11          # 레터박스 띠 높이 (화면의 몇 할)
const STAGE := 168         # 말하는 쪽이 내 곁으로 와서 서는 거리
const AIM := 0.42          # 인물을 화면 위에서 몇 할 지점에 놓을까 (대화창 위)
const DIM := 0.55          # 얼마나 어둡게
const BOOST := 1.18        # 카메라를 얼마나 당길까
const BAR_RATE := 7.0      # 띠와 어둠이 드는 빠르기 (1초에 남은 거리의 몇 배)
const PUSH_RATE := 1.5     # 장면이 열릴 때 카메라가 다가가는 빠르기. 느릴수록 천천히 밀고 들어간다
const PULL_RATE := 4.0     # 장면이 끝나 제 배율로 돌아가는 빠르기 (놀던 손이 기다리지 않게 빠르게)
const WALK := 260.0        # 무대 위의 걸음 (px/초)
const EMOTE_TIME := 1.6    # 머리 위 표시가 떠 있는 시간(초)

## 화면의 색 (PostFx 가 채도·가장자리 어둠·밝기·대비에 곱한다)
const TONES := {
	"none": { sat = 1.0, vig = 1.0, bri = 1.0, con = 1.0 },
	"memory": { sat = 0.25, vig = 2.2, bri = 0.97, con = 0.9 },   # 회상: 바랜 색
	"grief": { sat = 0.45, vig = 1.9, bri = 0.9, con = 1.0 },     # 슬픔: 색이 빠진다
	"dread": { sat = 0.7, vig = 2.2, bri = 0.86, con = 1.18 },    # 불길함: 짙고 어둡다
	"warm": { sat = 1.15, vig = 1.3, bri = 1.05, con = 1.0 },     # 따뜻한 끝
}

static var on := false
static var bars := 0.0     # 0 → 1 로 자라는 띠
static var dim := 0.0
static var boost := 1.0
static var focus = null    # 지금 말하는 쪽 (개체)
static var poi = null      # { target, label } 이번 대사가 가리키는 것
static var title := ""
static var title_t := 0.0
static var snap := true    # 장면이 막 시작했는데 카메라가 멀리 있으면 바로 옮긴다
static var exact := false  # 카메라 박자가 자리를 정한 동안은 따라가기 없이 그 자리를 그대로 본다
static var music := ""     # 이 장면에 깔 곡. "" 이면 평소대로, "none" 이면 정적 (Audio 가 읽는다)
static var tone := TONES.none.duplicate()   # 지금 화면 색
static var black := 0.0    # 화면을 덮는 검은 막 0~1
static var caption := ""   # 가운데 큰 글
static var caption_a := 0.0
static var card := {}      # 이름패 { name, sub } — 보스가 깨어날 때, 새 땅에 들어설 때
static var card_a := 0.0
static var subtitle := ""  # 싸움 중 자막 (세상을 멈추지 않는다)
static var _subtitle_at := 0
static var _subtitle_ms := 0

# 무대에 올린 개체들. guest: 이 지도에 없던 용을 잠깐 불러온 경우
static var _cast := []
static var _origin := Vector2.ZERO    # 장면이 열린 자리 (박자의 [dx, dy] 는 여기서 잰다)
static var _shot = null               # { from, to, t, time } 카메라 박자
static var _zoom_scene := BOOST
static var _zoom_line = null          # 이번 줄만 당겨 보는 배율
static var _tone_want: Dictionary = TONES.none
static var _black_want := 0.0
static var _black_rate := 1.2
static var _caption_want := 0.0
static var _card_want := 0.0
static var _beats := []               # 남은 박자
static var _beat = null               # 지금 박자
static var _beats_done = null         # 박자를 다 돌면 부를 것
static var _leaving := []             # 장면이 끝나 무대를 떠나는 손님들


## 판을 새로 시작할 때 (Launch.reset_run)
static func reset() -> void:
	on = false
	bars = 0.0; dim = 0.0; boost = 1.0
	focus = null; poi = null
	title = ""; title_t = 0.0
	snap = true; exact = false
	music = ""
	tone = TONES.none.duplicate(); _tone_want = TONES.none
	black = 0.0; _black_want = 0.0
	caption = ""; caption_a = 0.0; _caption_want = 0.0
	card = {}; card_a = 0.0; _card_want = 0.0
	subtitle = ""; _subtitle_ms = 0
	_cast = []; _leaving = []
	_shot = null; _zoom_scene = BOOST; _zoom_line = null
	cancel_beats()


## 이름('나' · NPC 이름 · 보스 id)으로 무대 위의 개체를 찾는다
static func actor(who):
	if who == null: return null
	if who is Object: return who
	return Chronicle._find(who)


## 무대에 세운다. 말하는 용이 멀리 있거나 딴 지도에 있으면 연극처럼 불러와 내 곁에 세우되,
## 툭 나타나면 어색하니 옆에서 걸어 들어오게 한다. 무대 위 자리(칸)를 돌려준다
static func _stage(e):
	if e == null or e == GameState.player or not (e is Dragon): return null
	var p = GameState.player
	for c in _cast:
		if c.e == e: return c
	var here: bool = GameState.entities.npcs.has(e)
	var m := { e = e, x = e.x, y = e.y, facing = e.facing, guest = not here, slot = _npc_slots(), hidden = e.is_hidden, down = e.down_timer }
	_cast.append(m)
	if not here: World.add_entity("npcs", e)     # 이 지도에 없던 용을 잠깐 불러온다
	e.is_hidden = false
	# 자리: 나를 가운데 두고 좌우로 번갈아 선다
	var side := 1 if m.slot % 2 == 0 else -1
	var rank := floori(m.slot / 2.0)
	m.to = _clear_spot(p.x + side * (STAGE + rank * 92), p.y - 14 - rank * 26)
	m.face = "left" if side > 0 else "right"
	# 멀리 있거나 딴 지도에 있던 용은 화면 밖에서 스르르 걸어 들어온다
	var cam := GameCamera.current
	var far: bool = m.guest or cam == null or Vector2(e.x - m.to.x, e.y - m.to.y).length() > cam.w * 0.55
	if far:
		var w: float = cam.w if cam else 1280.0
		e.x = m.to.x + side * (w * 0.5 + 120)
		e.y = m.to.y + 30
		e.stage_alpha = 0.0      # 걸어오며 또렷해진다
	return m


static func _npc_slots() -> int:
	var n := 0
	for c in _cast:
		if not c.get("player"): n += 1
	return n


## 무대 위 자리. 나도 박자로 움직이면 무대에 오른다
static func _cast_of(e):
	if e == null: return null
	for c in _cast:
		if c.e == e: return c
	if e == GameState.player:
		var m := { e = e, player = true, x = e.x, y = e.y, to = Vector2(e.x, e.y), hidden = e.is_hidden, down = e.down_timer }
		_cast.append(m)
		return m
	return _stage(e)


## 이 개체가 지금 무대에 올라 있는가 (컷씬에서 무대 밖의 것은 그리지 않는다).
## 보스는 늘 무대 위다 — 말을 멈췄다고 결투장 한가운데의 거대한 용이 사라지면 장면이 깨진다
static func on_stage(e) -> bool:
	if not on: return true
	if e == GameState.player or e is Boss: return true
	if poi and poi.target == e: return true
	if focus == e: return true
	return _in_cast(e)


static func _in_cast(e) -> bool:
	for c in _cast:
		if c.e == e: return true
	return false


## 빛을 받을 이들과 빛의 크기 [[개체, 배율], …]. 나·말하는 쪽·가리키는 것이 먼저, 그다음 곁에 선 이들
static func lit() -> Array:
	var out := []
	var seen := []
	var add := func(e, k: float):
		if e == null or not is_instance_valid(e) or seen.has(e) or e.get("is_hidden"): return
		seen.append(e)
		out.append([e, k])
	add.call(GameState.player, 1.0)
	add.call(focus, 1.0)
	if poi: add.call(poi.target, 1.0)
	for m in _cast:
		if not m.get("exit"): add.call(m.e, 0.78)
	for b in GameState.entities.bosses: add.call(b, 1.3)
	return out


static func _clear_spot(x: float, y: float) -> Vector2:
	for r in range(0, 181, 30):
		for i in 8:
			var a := (i / 8.0) * TAU
			var px := x + cos(a) * r
			var py := y + sin(a) * r
			if not Collision.solid_at(px, py, 18): return Vector2(px, py)
	return Vector2(x, y)


## 컷씬 시작. speakers: 이 장면에서 말할 이들. 처음부터 다 무대에 올려 두면 제 차례에 불쑥 나타나지 않는다
static func begin(t := "", speakers := []) -> void:
	if not on:
		var p = GameState.player
		_origin = Vector2(p.x, p.y)
		_zoom_scene = BOOST
		_zoom_line = null
		_shot = null
		exact = false
		music = ""
		_tone_want = TONES.none
		# 카메라가 가까이 있으면 튀기지 않고 미끄러뜨린다. 딴 지도로 옮겨 와 멀리 떨어졌으면 바로 옮긴다
		var cam := GameCamera.current
		snap = cam == null or Vector2(cam.cam_x + cam.w / 2 - p.x, cam.cam_y + cam.h / 2 - p.y).length() > cam.w * 0.8
	on = true
	for e in speakers: _stage(e)
	title = t
	title_t = 2.6 if t != "" else 0.0
	Hud.scene_title(t)
	DialogueBox.current.set_cinematic(true)


## 이번 대사를 말하는 쪽을 카메라가 본다
static func focus_on(entity) -> void:
	_stage(entity)
	focus = entity


## 이번 대사가 가리키는 것 (시설이든 용이든). 카메라가 나와 그것 사이를 보고, 빛이 떨어지고, 이름표가 뜬다
static func point_at(target, label := "") -> void:
	poi = { target = target, label = label } if target else null


## 이번 줄만 당겨 볼 배율 (null 이면 장면의 배율)
static func line_zoom(z) -> void:
	_zoom_line = float(z) if z != null else null


static func finish() -> void:
	cancel_beats()
	poi = null
	for m in _cast:
		var e = m.e
		if not is_instance_valid(e): continue
		e.moving = false
		e.is_hidden = m.hidden
		e.down_timer = m.down
		# 무대에서 옮긴 자리가 벽·물 속이면 원래 자리로
		var stuck: bool = Collision.solid_at(e.x, e.y, 18)
		if m.get("player"):
			if stuck: e.x = m.x; e.y = m.y
			continue
		if m.guest:
			# 불러왔던 용은 화면 밖으로 걸어 나가며 흐려진 뒤 제 일과로 돌아간다
			_leaving.append({ e = e, side = 1.0 if e.x >= GameState.player.x else -1.0 })
		else:
			e.stage_alpha = 1.0
			if stuck: e.x = m.x; e.y = m.y
	_cast.clear()
	on = false
	focus = null
	_shot = null
	exact = false
	music = ""
	_tone_want = TONES.none
	_black_want = 0.0
	_caption_want = 0.0
	_card_want = 0.0
	_zoom_line = null
	title_t = 0.0
	Hud.scene_title("")
	DialogueBox.current.set_cinematic(false)


## 카메라가 볼 자리. 컷씬이면 나와 상대의 가운데. 대화창이 아래를 덮으므로 인물을 화면 위쪽(AIM)에 놓는다
static func camera_target(cam_h: float):
	if not on: return null
	var c: Vector2
	if _shot:
		var to := _point(_shot.to)
		var k: float = 1.0 if _shot.time <= 0 else clampf(_shot.t / _shot.time, 0, 1)
		k = k * k * (3 - 2 * k)
		c = _shot.from.lerp(to, k)
	else:
		var p = GameState.player
		var f = null
		if poi and is_instance_valid(poi.target): f = poi.target
		elif focus and focus != p and is_instance_valid(focus): f = focus
		c = Vector2((p.x + f.x) / 2, (p.y + f.y) / 2) if f else Vector2(p.x, p.y)
	return Vector2(c.x, c.y + cam_h * (0.5 - AIM))


## 카메라 박자의 대상이 지금 어디 있나
static func _point(to) -> Vector2:
	if to is Vector2: return to
	if to is Object and is_instance_valid(to): return Vector2(to.x, to.y - 20)
	return _origin


## 지금 카메라가 보고 있는 인물 자리 (camera_target 의 거꾸로)
static func _camera_subject() -> Vector2:
	var cam := GameCamera.current
	if cam == null: return _origin
	return Vector2(cam.cam_x + cam.w / 2, cam.cam_y + cam.h / 2 - cam.h * (0.5 - AIM))


## 매 프레임: 띠와 어둠이 스르르 들어오고 나간다 (대화창이 떠 있어도 돌아야 한다)
static func update(dt: float) -> void:
	if on: _walk_cast(dt)
	_walk_leaving(dt)
	if _beat != null or not _beats.is_empty(): _tick_beats(dt)
	if _shot: _shot.t += dt
	var want := 1.0 if on else 0.0
	var k := 1.0 - exp(-BAR_RATE * dt)
	bars += (want - bars) * k
	dim += (want - dim) * k
	var z: float = (_zoom_line if _zoom_line != null else _zoom_scene) if on else 1.0
	boost += (z - boost) * (1.0 - exp(-(PUSH_RATE if on else PULL_RATE) * dt))
	if bars < 0.002 and not on: bars = 0.0
	var tk := 1.0 - exp(-2.2 * dt)
	for key in tone: tone[key] += (_tone_want[key] - tone[key]) * tk
	black = move_toward(black, _black_want, dt * _black_rate)
	caption_a = move_toward(caption_a, _caption_want, dt * 2.2)
	card_a = move_toward(card_a, _card_want, dt * 2.6)
	if title_t > 0:
		title_t -= dt
		if title_t <= 0: Hud.scene_title("")


## 세상이 멈춰 있는 동안(대화창) 무대 위의 이들이 숨을 쉬고 걷게 한다. 효과와 빛 알갱이도 흐른다 (main 이 부른다)
static func animate(dt: float) -> void:
	var seen := []
	var list := [GameState.player, GameState.currentNpc, focus]
	for m in _cast: list.append(m.e)
	for e in list:
		if e == null or not is_instance_valid(e) or seen.has(e) or not (e is Dragon): continue
		seen.append(e)
		e.animate_only(dt)
	if not on: return
	var E: Dictionary = GameState.entities
	for group in ["effects", "particles"]:
		for fx in E[group]: fx.update(dt)
		E[group] = E[group].filter(func(fx): return not fx.remove)


## 무대에 오른 이들을 제자리로 걸린다. 말하는 쪽은 반걸음 앞으로, 듣는 쪽은 말하는 쪽을 본다
static func _walk_cast(dt: float) -> void:
	var p = GameState.player
	var player_walking := false
	for m in _cast:
		var e = m.e
		if not is_instance_valid(e): continue
		var speaking: bool = focus == e and not m.get("player") and not m.get("exit")
		var tx: float = m.to.x
		var ty: float = m.to.y + (14 if speaking else 0)   # 말할 차례엔 앞으로 나선다
		var dx: float = tx - e.x
		var dy: float = ty - e.y
		var d := Vector2(dx, dy).length()
		if d > 2:
			var k := minf(1, (dt * float(m.get("speed", WALK))) / d)
			e.x += dx * k; e.y += dy * k
			e.moving = d > 6
			if e.moving: e.facing = Dragon.facing_from_vector(dx, dy, e.facing)
		else:
			e.moving = false
		if m.get("player") and e.moving: player_walking = true
		if m.get("exit"):
			e.stage_alpha = maxf(0, e.stage_alpha - dt * 1.6)
			if e.stage_alpha <= 0: e.is_hidden = true
			continue
		if e.stage_alpha < 1: e.stage_alpha = minf(1, e.stage_alpha + dt * 1.4)
		if e.moving: continue
		# 서 있으면: 정해 준 쪽이 있으면 그쪽, 아니면 말하는 이를 본다. 말하는 이는 나를 본다
		if m.get("face_lock"): e.facing = m.face_lock
		elif focus and focus != e and is_instance_valid(focus): e.facing = _toward(e, focus)
		elif not m.get("player"): e.facing = _toward(e, p)
	# 나는 말하는 이를 본다 (걷고 있지 않을 때)
	if not player_walking and focus and focus != p and is_instance_valid(focus):
		var mine = null
		for m in _cast:
			if m.e == p: mine = m
		if mine == null or not mine.get("face_lock"): p.facing = _toward(p, focus)


## a 가 b 쪽을 보는 방향. 마주 서서 말할 때는 옆얼굴이 자연스럽다
static func _toward(a, b) -> String:
	var dx: float = b.x - a.x
	var dy: float = b.y - a.y
	if absf(dy) > absf(dx) * 2.2: return "down" if dy > 0 else "up"
	return "right" if dx >= 0 else "left"


## 장면이 끝나 무대를 떠나는 손님: 화면 밖으로 걸어 나가며 흐려지고, 다 흐려지면 제 지도로 돌아간다
static func _walk_leaving(dt: float) -> void:
	if _leaving.is_empty(): return
	var keep := []
	for l in _leaving:
		var e = l.e
		if not is_instance_valid(e): continue
		# 지도를 옮겨 이미 떠났거나, 새 장면이 다시 불러 세웠으면 그만 걷는다
		if not GameState.entities.npcs.has(e) or _in_cast(e):
			e.stage_alpha = 1.0
			continue
		e.x += l.side * 220 * dt
		e.moving = true
		e.facing = "right" if l.side > 0 else "left"
		e.stage_alpha = maxf(0, e.stage_alpha - dt * 1.8)
		if e.stage_alpha > 0:
			keep.append(l)
			continue
		GameState.entities.npcs.erase(e)
		if e.is_inside_tree(): e.get_parent().remove_child(e)
		e.stage_alpha = 1.0
		e.moving = false
	_leaving = keep


# ---------- 박자 ----------

## 박자들을 차례로 돌리고, 다 돌면 done 을 부른다. 바로 끝나는 박자는 이 자리에서 다 돈다
static func run(list: Array, done: Callable) -> void:
	_beats = list.duplicate()
	_beat = null
	_beats_done = done
	_tick_beats(0.0)


## 박자가 도는 중인가 (대화창이 내려가 있는 동안)
static func busy() -> bool:
	return _beat != null or not _beats.is_empty() or _beats_done != null


static func cancel_beats() -> void:
	_beats = []
	_beat = null
	_beats_done = null


## [Space]: 지금 박자를 곧바로 끝낸다 (걷던 이는 제자리로 옮겨 놓는다)
static func rush() -> void:
	if _beat == null: return
	if _beat.get("rush"): _beat.rush.call()
	_beat.t = 999.0
	_beat.until = null
	_tick_beats(0.0)


static func _tick_beats(dt: float) -> void:
	for guard in 64:
		if _beat == null:
			if _beats.is_empty():
				var d = _beats_done
				_beats_done = null
				if d: d.call()
				return
			_beat = _start(_beats.pop_front())
		else:
			_beat.t += dt
			dt = 0.0
		var b: Dictionary = _beat
		var over: bool = b.t >= b.wait and (b.until == null or b.until.call() or b.t >= b.cap)
		if not over: return
		_beat = null
		if b.end: b.end.call()


## 박자 하나를 건다. { t, wait(이만큼은 기다린다), until(이게 참이 될 때까지), cap(아무리 길어도),
## rush(건너뛸 때), end(끝날 때) }
static func _start(spec: Dictionary) -> Dictionary:
	var b := { t = 0.0, wait = 0.0, until = null, cap = 6.0, rush = null, end = null }
	var async: bool = spec.get("async", false)
	if spec.has("wait"):
		b.wait = float(spec.wait)
	elif spec.has("move"):
		var e = actor(spec.move)
		var m = _cast_of(e)
		if m:
			m.to = _spot(spec.get("to"), m)
			if spec.has("speed"): m.speed = float(spec.speed)
			m.erase("face_lock")
			if not async:
				b.until = func(): return not is_instance_valid(e) or Vector2(e.x - m.to.x, e.y - m.to.y).length() <= 3
				b.rush = func():
					if is_instance_valid(e): e.x = m.to.x; e.y = m.to.y
	elif spec.has("exit"):
		var e = actor(spec.exit)
		var m = _cast_of(e)
		if m and not m.get("player"):
			var cam := GameCamera.current
			var side: float = (1.0 if spec.side == "right" else -1.0) if spec.get("side") else (1.0 if e.x >= GameState.player.x else -1.0)
			m.to = Vector2(e.x + side * (cam.w * 0.6 if cam else 700.0), e.y)
			m.exit = true
			b.wait = 0.0 if async else 0.9
	elif spec.has("face"):
		var m = _cast_of(actor(spec.face))
		if m:
			var to = spec.get("to", "down")
			var other = actor(to) if not ["left", "right", "up", "down"].has(to) else null
			m.face_lock = _toward(m.e, other) if other else to
			m.e.facing = m.face_lock
	elif spec.has("emote"):
		var e = actor(spec.emote)
		if e is Dragon:
			e.emote(str(spec.get("icon", "!")))
			if spec.get("sfx", true): Sfx.play("pop")
		b.wait = 0.0 if async else 0.75
	elif spec.has("cam"):
		var to = spec.cam
		if to == null or (to is String and to == "auto"):
			_shot = null
			exact = false
		else:
			var target = null
			if to is Array: target = _origin + Vector2(float(to[0]), float(to[1]))
			elif to is String and to.begins_with("look:"): target = Chronicle._look_target(to.substr(5))
			else: target = actor(to)
			if target != null:
				_shot = { from = _camera_subject(), to = target, t = 0.0, time = float(spec.get("time", 1.2)) }
				exact = true
		if spec.has("zoom"): _zoom_scene = float(spec.zoom)
		b.wait = 0.0 if async or _shot == null else float(spec.get("time", 1.2))
	elif spec.has("zoom"):
		_zoom_scene = float(spec.zoom)
		b.wait = 0.0 if async else float(spec.get("time", 0.0))
	elif spec.has("shake"):
		if GameCamera.current: GameCamera.current.shake(float(spec.shake))
	elif spec.has("flash"):
		Feedback.flash(float(spec.get("a", 0.7)), Color(spec.flash))
	elif spec.has("sfx"):
		Sfx.play(str(spec.sfx))
	elif spec.has("bgm"):
		music = "" if spec.bgm == null or str(spec.bgm) == "auto" else str(spec.bgm)
	elif spec.has("tone"):
		_tone_want = TONES.get(str(spec.tone), TONES.none)
	elif spec.has("fx"):
		var at = actor(spec.get("at", "나"))
		var pos := Vector2(at.x, at.y) if at else _origin
		if spec.has("dx"): pos.x += float(spec.dx)
		if spec.has("dy"): pos.y += float(spec.dy)
		Vfx.spawn_effect(str(spec.fx), pos.x, pos.y, { size = float(spec.get("size", 1.0)), color = spec.get("color") })
	elif spec.has("fade"):
		var time := float(spec.get("time", 0.8))
		_black_rate = 1.0 / maxf(0.05, time)
		_black_want = 1.0 if spec.fade == "out" else 0.0
		if spec.has("text"):
			caption = str(spec.text)
			_caption_want = 1.0
		elif spec.fade == "in":
			_caption_want = 0.0
		b.wait = 0.0 if async else time
		b.rush = func():
			black = _black_want
			caption_a = _caption_want
	elif spec.has("caption"):
		caption = str(spec.caption)
		_caption_want = 1.0
		b.wait = float(spec.get("time", 2.2))
		b.end = func(): _caption_want = 0.0   # 다 보여 주면 스르르 걷는다
	elif spec.has("card"):
		show_card(str(spec.card), str(spec.get("sub", "")))
		b.wait = 0.0 if async else float(spec.get("time", 2.2))
		b.end = func(): _card_want = 0.0
	elif spec.has("hide"):
		var e = actor(spec.hide)
		var m = _cast_of(e)
		if m: m.e.is_hidden = true
	elif spec.has("show"):
		var e = actor(spec.show)
		var m = _cast_of(e)
		if m:
			m.e.is_hidden = false
			m.e.stage_alpha = 1.0
	elif spec.has("down"):
		var m = _cast_of(actor(spec.down))
		if m: m.e.down_timer = 999.0
	elif spec.has("up"):
		var m = _cast_of(actor(spec.up))
		if m: m.e.down_timer = 0.0
	return b


## 이름패를 띄운다 (보스의 이름 · 새 땅의 이름). hide_after 초 뒤 걷는다 (0 이면 박자가 걷는다)
static func show_card(name_text: String, sub := "", hide_after := 0.0) -> void:
	card = { name = name_text, sub = sub }
	_card_want = 1.0
	if hide_after > 0:
		var shown := card
		(Engine.get_main_loop() as SceneTree).create_timer(hide_after, true, false, true).timeout.connect(func():
			if card == shown: _card_want = 0.0)


## 싸움 중 자막. 세상을 멈추지 않고 화면 아래쪽에 한마디를 띄운다 (보스가 판을 바꿀 때)
static func say_over(who: String, text: String, sec := 3.2) -> void:
	subtitle = "%s — %s" % [who, text] if who != "" else text
	_subtitle_at = Time.get_ticks_msec()
	_subtitle_ms = int(sec * 1000)


static func subtitle_alpha() -> float:
	if _subtitle_ms <= 0: return 0.0
	var t := Time.get_ticks_msec() - _subtitle_at
	if t > _subtitle_ms: return 0.0
	return minf(1.0, minf(t / 250.0, (_subtitle_ms - t) / 400.0))


## 박자의 to 를 실제 자리로. [dx, dy] 는 장면이 열린 자리에서, "near:이름" 은 그 이의 곁, "look:…" 은 그 시설 앞
static func _spot(spec, m: Dictionary) -> Vector2:
	var e = m.e
	if spec is Array: return _clear_spot(_origin.x + float(spec[0]), _origin.y + float(spec[1]))
	if spec is Dictionary: return Vector2(float(spec.x), float(spec.y))
	if spec is String:
		if spec == "home": return Vector2(m.x, m.y)
		if spec.begins_with("look:"):
			var t = Chronicle._look_target(spec.substr(5))
			if t: return _clear_spot(t.x + 70, t.y + 50)
		var who = actor(spec.substr(5) if spec.begins_with("near:") else spec)
		if who and who != e:
			var side := 1.0 if e.x >= who.x else -1.0
			return _clear_spot(who.x + side * 96, who.y)
	return Vector2(e.x, e.y)
