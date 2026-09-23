extends Node
## 소리를 실제로 내는 곳 (autoload "Audio").
##  · 효과음 목소리 묶음: Sfx.play 가 고른 소리를 빈 목소리에 실어 튼다 (여러 소리가 겹쳐 울릴 수 있게 16개)
##  · 배경음 (2D판 systems/music.js): 지금 서 있는 곳과 처지에 어울리는 곡 하나를 골라 계속 틀고,
##    장면이 바뀌면 두 곡을 잠깐 겹쳐 틀어 부드럽게 갈아 끼운다. 처음 화면에서는 처음 화면 곡.
## 음량 · 음소거는 설정 창(Prefs sound/*)을 매 프레임 따른다.

const VOICES := 16
const MUSIC_DEFAULT_VOLUME := 0.55
const FADE := 1.6    # 곡을 갈아 끼우는 데 걸리는 시간(초)

# 지도의 biome (data/maps) → 곡
const BIOME_TRACK := {
	"VILLAGE": "village", "LAKE": "lake", "FOREST": "forest", "JUNGLE": "jungle", "HOLLOW": "hollow",
	"SNOW": "snow", "VOLCANO": "volcano", "AUTUMN": "autumn", "DESERT": "desert",
	# 폭포 위 마을은 물소리 쪽, 마을 자체는 마을 곡을 같이 쓴다
	"FALLS": "lake", "CLOUDTOP": "village", "SKY": "snow",
}

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0

var scene := ""                 # 지금 틀기로 한 장면 id
var _playing = null             # { id, player, gain } — 올라오는 중이거나 다 올라온 곡
var _fading := []               # 물러나는 중인 곡들
var _pool := {}                 # id → AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	WorkerThreadPool.add_task(Sfx.prebuild, false, "합성음 만들기")


# ---------- 효과음 ----------

func play_voice(stream: AudioStream, gain: float, pitch: float) -> void:
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	p.stream = stream
	p.volume_db = linear_to_db(maxf(gain, 0.0001))
	p.pitch_scale = pitch
	p.play()


# ---------- 배경음 ----------

static func music_volume() -> float: return float(Prefs.get_value("sound", "music", MUSIC_DEFAULT_VOLUME))


## 지금 틀어야 할 곡. 위에 있는 줄이 먼저다
func scene_now() -> String:
	if not GameState.gameActive: return "title"
	if Cutscene.music != "": return Cutscene.music   # 장면이 고른 곡 ("none" 이면 정적)
	if World.map_has_boss(): return "boss"
	if GameState.raid.get("active"): return "raid"
	if GameState.dungeon: return "dungeon"
	if Den.is_den(GameState.map_id): return "den"
	if GameState.event == "BLOOD_MOON": return "bloodmoon"
	return BIOME_TRACK.get(Terrain.active_biome(), "forest")


func _process(dt: float) -> void:
	_set_scene(scene_now())
	var step := minf(dt, 0.1) / FADE
	if _playing:
		_playing.gain = minf(1, _playing.gain + step)
		_apply(_playing)
	for t in _fading:
		t.gain = maxf(0, t.gain - step)
		_apply(t)
		if t.gain == 0: t.player.stop()
	_fading = _fading.filter(func(t): return t.gain > 0)


## 이 장면의 곡으로 갈아 끼운다. 이미 그 곡이면 아무것도 하지 않는다. "none" 은 곡을 걷기만 한다
func _set_scene(id: String) -> void:
	if id == scene: return
	scene = id
	if _playing:
		_fading.append(_playing)
		_playing = null
	if id == "none": return
	var back := -1
	for i in _fading.size():
		if _fading[i].id == id: back = i
	# 잠깐 다녀와서 되돌아온 것이면, 물러나던 곡을 그대로 다시 올린다
	if back >= 0:
		_playing = _fading[back]
		_fading.remove_at(back)
	else:
		_playing = { id = id, player = _player(id), gain = 0.0 }
		_apply(_playing)
		_playing.player.play()


func _player(id: String) -> AudioStreamPlayer:
	if not _pool.has(id):
		var p := AudioStreamPlayer.new()
		var s: AudioStreamOggVorbis = load("res://assets/music/%s.ogg" % id)
		s.loop = true
		p.stream = s
		add_child(p)
		_pool[id] = p
	return _pool[id]


func _apply(t: Dictionary) -> void:
	var v: float = 0.0 if Sfx.muted() else t.gain * music_volume()
	t.player.volume_db = linear_to_db(maxf(v, 0.00001))


## 지금 틀고 있는 곡 id (없으면 빈 글). 시험이 읽는다
func playing_id() -> String: return _playing.id if _playing else ""
