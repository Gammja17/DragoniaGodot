class_name Sfx
## 2D판 systems/audio.js. 효과음.
## 대부분은 파일 없이 코드로 만든 소리(파형 + 음 높이 미끄럼 + 사그라짐)이고, 합성으로는 흉내 내기 힘든 몇 가지만
## 녹음된 소리(assets/sfx, Kenney CC0)를 쓴다. 녹음이 있으면 그것을, 없으면 합성음을 튼다.
## 합성음은 게임을 켤 때 뒤에서 한 번 만들어 두고 다시 쓴다 (다 만들기 전에 울리면 그 자리에서 만든다). 실제로 트는 것은 Audio(autoload)의 목소리 묶음.

const DEFAULT_VOLUME := 0.8
const RATE := 32000

# [파형, 시작 Hz, 끝 Hz, 길이(초), 음량]. 여러 줄이면 순서대로 0.07초 간격으로 울린다
const SOUNDS := {
	"shoot": [["sawtooth", 520, 140, 0.12, 0.05]],
	"ice": [["triangle", 1200, 500, 0.14, 0.06]],
	"zap": [["square", 900, 200, 0.09, 0.04]],
	"hit": [["square", 220, 70, 0.08, 0.05]],
	"crit": [["square", 330, 90, 0.1, 0.07], ["triangle", 990, 660, 0.12, 0.05]],
	"hurt": [["sawtooth", 160, 60, 0.18, 0.07]],
	"coin": [["triangle", 1320, 1760, 0.07, 0.05]],
	"pickup": [["triangle", 660, 990, 0.09, 0.05]],
	"ui": [["triangle", 880, 880, 0.04, 0.03]],
	"level": [["triangle", 523, 523, 0.1, 0.06], ["triangle", 659, 659, 0.1, 0.06], ["triangle", 784, 784, 0.1, 0.06], ["triangle", 1047, 1047, 0.22, 0.07]],
	"relic": [["sine", 784, 784, 0.12, 0.06], ["sine", 1175, 1175, 0.12, 0.06], ["sine", 1568, 1568, 0.3, 0.06]],
	"roar": [["sawtooth", 110, 45, 0.5, 0.09]],
	"raid": [["square", 196, 196, 0.18, 0.06], ["square", 196, 196, 0.18, 0.06], ["square", 147, 147, 0.35, 0.07]],
	"splash": [["sine", 300, 120, 0.15, 0.05]],
	"dash": [["sine", 500, 900, 0.1, 0.04]],
	"flame": [["noise", 900, 300, 0.18, 0.06]],
	"boom": [["noise", 400, 60, 0.45, 0.12], ["sine", 90, 35, 0.4, 0.12]],
	"freeze": [["triangle", 2200, 900, 0.18, 0.05], ["triangle", 1500, 2400, 0.12, 0.04]],
	"thunder": [["noise", 3000, 200, 0.22, 0.09], ["square", 140, 50, 0.2, 0.05]],
	"slash": [["noise", 2500, 700, 0.1, 0.07]],
	"gust": [["noise", 500, 1600, 0.35, 0.06]],
	"heal": [["sine", 523, 784, 0.18, 0.05], ["sine", 784, 1047, 0.25, 0.05]],
	"guard": [["square", 300, 300, 0.06, 0.05], ["triangle", 1200, 900, 0.2, 0.05]],
	"die": [["square", 300, 60, 0.16, 0.05]],
	"dieBig": [["noise", 600, 80, 0.5, 0.1], ["sawtooth", 200, 40, 0.5, 0.08]],
	"chest": [["triangle", 392, 392, 0.08, 0.05], ["triangle", 523, 523, 0.08, 0.05], ["triangle", 784, 784, 0.2, 0.06]],
	"quest": [["triangle", 659, 659, 0.1, 0.05], ["triangle", 880, 880, 0.1, 0.05], ["triangle", 1319, 1319, 0.25, 0.06]],
	"talk": [["square", 420, 380, 0.035, 0.025]],
	"eat": [["square", 200, 140, 0.06, 0.05], ["square", 220, 150, 0.06, 0.05]],
	"evolve": [["sine", 262, 523, 0.5, 0.07], ["sine", 392, 784, 0.5, 0.07], ["triangle", 1047, 1568, 0.6, 0.07]],
	"sleep": [["sine", 660, 330, 0.5, 0.05], ["sine", 440, 220, 0.7, 0.05]],
	"warn": [["square", 880, 880, 0.08, 0.05], ["square", 880, 880, 0.08, 0.05]],
	"summon": [["sawtooth", 80, 240, 0.4, 0.06]],
	"beam": [["sawtooth", 300, 320, 0.5, 0.04]],
	"step": [["noise", 300, 150, 0.04, 0.02]],
	"thud": [["noise", 200, 60, 0.12, 0.08]],
	# 컷씬 연출 (Cutscene 의 sfx 박자)
	"pop": [["sine", 620, 1150, 0.07, 0.05]],                                            # 머리 위 표시가 톡
	"heartbeat": [["sine", 72, 48, 0.14, 0.16], ["sine", 64, 42, 0.16, 0.12]],          # 쿵… 쿵
	"bell": [["sine", 392, 392, 1.6, 0.08], ["sine", 784, 784, 1.2, 0.03], ["sine", 1175, 1175, 0.8, 0.015]],   # 멀리서 울리는 종
	"horn": [["sawtooth", 147, 140, 1.1, 0.07], ["square", 220, 212, 0.9, 0.025]],       # 길게 우는 나팔
	"stinger": [["sawtooth", 98, 46, 0.8, 0.1], ["noise", 900, 90, 0.6, 0.09]],          # 쿵 — 불길한 한 방
	"wind": [["noise", 280, 520, 1.6, 0.04]],
	"chime": [["sine", 1319, 1319, 0.35, 0.05], ["sine", 1760, 1760, 0.35, 0.05], ["sine", 2637, 2637, 0.6, 0.04]],
	"rumble": [["noise", 140, 40, 1.2, 0.11], ["sine", 46, 30, 1.2, 0.1]],               # 땅울림
}

# 녹음된 소리. [음량, 파일들] — 여러 개면 울릴 때마다 하나를 골라서 같은 소리가 반복돼 들리지 않게 한다
const SAMPLES := {
	"step": [0.30, ["step1", "step2", "step3", "step4", "step5"]],
	"hit": [0.45, ["hit1", "hit2", "hit3"]],
	"crit": [0.60, ["crit1", "crit2", "crit3"]],
	"slash": [0.50, ["slash1", "slash2"]],
	"guard": [0.45, ["guard1", "guard2", "guard3"]],
	"coin": [0.45, ["coin"]],
	"ui": [0.35, ["ui"]],
	"hurt": [0.55, ["hurt1", "hurt2", "hurt3"]],
	"boom": [0.65, ["boom1", "boom2", "boom3"]],
	"die": [0.45, ["die1", "die2", "die3"]],
	"dieBig": [0.8, ["bigdie1", "bigdie2"]],
	"pickup": [0.4, ["pickup"]],
	"chest": [0.5, ["chest"]],
	"quest": [0.5, ["quest1", "quest2", "quest3"]],
	"gust": [0.5, ["whoosh1", "whoosh2", "whoosh3"]],
	"dash": [0.35, ["whoosh1", "whoosh2", "whoosh3"]],
	"warn": [0.5, ["warn"]],
	"thud": [0.55, ["thud1", "thud2"]],
	"freeze": [0.5, ["glass1", "glass2", "glass3"]],
}

static var _synth := {}         # 이름 → 만들어 둔 합성음
static var _files := {}         # 파일 이름 → 불러 둔 녹음
static var _last_played := {}   # 이름 → 마지막으로 울린 때(초)
static var _noise := PackedFloat32Array()


## 합성음을 모두 미리 만든다 (Audio 가 시작할 때 일꾼 스레드에서 부른다. 다 합쳐 2초 가까이 걸려서,
## 처음 울릴 때 만들면 첫 숨결에 화면이 멈칫한다). 다 만든 묶음은 본 스레드로 넘겨 끼운다
static func prebuild() -> void:
	_noise_table()
	var made := {}
	for n in SOUNDS: made[n] = make(SOUNDS[n])
	(func(): for n in made: _synth[n] = made[n]).call_deferred()


static func volume() -> float: return float(Prefs.get_value("sound", "sfx", DEFAULT_VOLUME))
static func muted() -> bool: return Prefs.get_value("sound", "muted", false)


static func play(name: String) -> void:
	if muted(): return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_played.get(name, -1.0) < 0.04: return   # 같은 소리가 한 프레임에 겹쳐 울리지 않게
	var sample = SAMPLES.get(name)
	if sample:
		var file: String = sample[1].pick_random()
		if not _files.has(file): _files[file] = load("res://assets/sfx/%s.ogg" % file)
		if _files[file]:
			_last_played[name] = now
			# 조금씩 음을 흔들어 기계처럼 들리지 않게
			Audio.play_voice(_files[file], sample[0] * volume(), randf_range(0.92, 1.08))
			return
	if not SOUNDS.has(name): return
	_last_played[name] = now
	if not _synth.has(name): _synth[name] = make(SOUNDS[name])
	Audio.play_voice(_synth[name], volume(), 1.0)


static func _noise_table() -> void:
	if not _noise.is_empty(): return
	var t := PackedFloat32Array()
	t.resize(RATE)
	for i in RATE: t[i] = randf() * 2 - 1
	_noise = t


## 합성음 하나를 만든다 (2D판 WebAudio 의 오실레이터 · 잡음 + 띠 거르개와 같은 모양)
static func make(parts: Array) -> AudioStreamWAV:
	var total := 0.0
	for i in parts.size(): total = maxf(total, i * 0.07 + parts[i][3] + 0.02)
	var buf := PackedFloat32Array()
	buf.resize(ceili(total * RATE))
	for i in parts.size():
		var p: Array = parts[i]
		_render_part(buf, roundi(i * 0.07 * RATE), p[0], p[1], p[2], p[3], p[4])
	var pcm := PackedByteArray()
	pcm.resize(buf.size() * 2)
	for i in buf.size(): pcm.encode_s16(i * 2, int(clampf(buf[i], -1, 1) * 32767))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = pcm
	return s


## 음 높이는 f0 → f1 로 지수로 미끄러지고, 음량은 vol → 0.0001 로 지수로 사그라진다 (exponentialRampToValueAtTime)
static func _render_part(buf: PackedFloat32Array, start: int, type: String, f0: float, f1: float, dur: float, vol: float) -> void:
	f1 = maxf(20, f1)
	var n := mini(ceili((dur + 0.02) * RATE), buf.size() - start)
	var phase := 0.0
	# 띠 거르개 (WebAudio BiquadFilter 'bandpass', Q = 1) 의 상태
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	if type == "noise": _noise_table()
	for i in n:
		var k := minf(1, float(i) / RATE / dur)
		var f := f0 * pow(f1 / f0, k)
		var g := vol * pow(0.0001 / vol, k)
		var v := 0.0
		if type == "noise":
			var w0 := TAU * minf(f, RATE * 0.49) / RATE
			var alpha := sin(w0) / 2.0
			var x0: float = _noise[i % RATE]
			var y0 := (alpha * x0 - alpha * x2 + 2 * cos(w0) * y1 - (1 - alpha) * y2) / (1 + alpha)
			x2 = x1; x1 = x0; y2 = y1; y1 = y0
			v = y0
		else:
			phase = fmod(phase + f / RATE, 1.0)
			match type:
				"sine": v = sin(phase * TAU)
				"square": v = 1.0 if phase < 0.5 else -1.0
				"sawtooth": v = phase * 2 - 1
				"triangle": v = 1 - 4 * absf(phase - 0.5)
		buf[start + i] += v * g
