class_name BossVoice
## 보스마다의 울음. 녹음(assets/sfx/boss, CC0 — CREDITS.md)을 보스마다 빠르기·크기를 달리해 쓴다.
##   cry(id, kind)   kind: "roar" 깨어날 때 · "phase" 판이 바뀔 때 · "revive" 되살아날 때 · "fall" 쓰러질 때 · "far" 멀리서 들리는 울음
## 없는 kind 는 울지 않는다 ("roar" 가 없으면 Sfx 의 흔한 포효로 대신한다).
##
## 울음 하나는 겹 몇 개: { f: 파일, p: 빠르기 (1보다 작으면 낮고 길게), g: 크기, at: 늦게 울릴 초 }
## 메아리는 같은 소리를 조금 늦게, 작게 한 번 더 얹어 낸다 (골짜기 · 봉우리).

const DIR := "res://assets/sfx/boss/"
const GAIN := 0.8   # 다른 녹음 효과음(Sfx.SAMPLES)과 맞춘 크기

const VOICES := {
	"MORGATH": {   # 예순 해를 운 옛 수호룡: 낮게 늘어지는 울부짖음, 골짜기의 메아리
		"roar": [{ f = "howl.ogg", p = 0.72 }, { f = "howl.ogg", p = 0.72, g = 0.3, at = 0.25 }],
		"phase": [{ f = "howl.ogg", p = 0.85, g = 0.8 }],
		"revive": [{ f = "monster_04.ogg", p = 0.72 }],
		"fall": [{ f = "die_03.ogg", p = 0.72, g = 0.8 }],
		"far": [{ f = "howl.ogg", p = 0.6, g = 0.45 }, { f = "howl.ogg", p = 0.6, g = 0.2, at = 0.35 }],   # 이야기 장면에서 { cry = "MORGATH", kind = "far" }
	},
	"ZALGORA": {   # 한 몸이 된 형제: 두 머리가 번갈아 운다
		"roar": [{ f = "roar_04.ogg", p = 0.95 }, { f = "roar_06.ogg", p = 0.85, at = 0.55 }],
		"phase": [{ f = "roar_06.ogg", p = 1.0 }, { f = "roar_04.ogg", p = 1.05, at = 0.35 }],
		"fall": [{ f = "die_03.ogg", p = 0.95, g = 0.8 }, { f = "die_03.ogg", p = 0.85, g = 0.8, at = 0.45 }],
	},
	"GLACIA": {    # 알을 품은 얼음 용: 높은 울음, 봉우리의 메아리
		"roar": [{ f = "scream_01.ogg", p = 1.0 }, { f = "scream_01.ogg", p = 1.0, g = 0.3, at = 0.3 }],
		"phase": [{ f = "scream_02.ogg", p = 1.0 }],
		"fall": [{ f = "scream_01.ogg", p = 0.72, g = 0.7 }],
	},
	"BASIL": {     # 사연 없는 짐승: 목 깊은 데서 끓는 포효
		"roar": [{ f = "monster_roar.wav", p = 1.0 }],
		"phase": [{ f = "monster_04.ogg", p = 0.72 }],
		"fall": [{ f = "die_03.ogg", p = 0.6 }],
	},
	"IGNAR": {     # 먼저 떨어진 하늘 용: 크고 당당한 포효. 무릎을 꿇을 때는 긴 숨
		"roar": [{ f = "roar_05.ogg", p = 0.72 }, { f = "roar_05.ogg", p = 0.72, g = 0.3, at = 0.25 }],
		"phase": [{ f = "roar_02.ogg", p = 0.8 }],
		"fall": [{ f = "breath.ogg", p = 0.72 }],
	},
}

static var _streams := {}   # 파일 → 불러 둔 소리


## 이 보스의 울음을 미리 불러 둔다 (Boss 가 생길 때. 울 때 불러오면 그 순간 멈칫할 수 있다)
static func prepare(id: String) -> void:
	for kind in VOICES.get(id, {}):
		for l in VOICES[id][kind]: _stream(l.f)


## 운다
static func cry(id: String, kind := "roar") -> void:
	if Sfx.muted(): return
	var layers: Array = VOICES.get(id, {}).get(kind, [])
	if layers.is_empty():
		if kind == "roar": Sfx.play("roar")
		return
	for l in layers:
		var at := float(l.get("at", 0.0))
		if at <= 0: _play(l)
		else: (Engine.get_main_loop() as SceneTree).create_timer(at, true, false, true).timeout.connect(func(): _play(l))


static func _play(l: Dictionary) -> void:
	var s = _stream(l.f)
	if s: Audio.play_voice(s, Sfx.volume() * GAIN * float(l.get("g", 1.0)), float(l.get("p", 1.0)) * randf_range(0.98, 1.02))


static func _stream(file: String):
	if not _streams.has(file): _streams[file] = load(DIR + file)
	return _streams[file]
