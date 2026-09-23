extends Node
## 2D판 core/state.js. 한 판의 모든 런타임 상태. 이름은 2D판 그대로 둔다
## (데이터 속 조건 함수와 세이브가 이 이름으로 묻는다). 하위 묶음은 2D판처럼 Dictionary.

var gameActive := false
var isDialogueOpen := false
var game_time := 0.0          # 2D판 gameTime. 대화·장면 중에도 흐른다 (폭포·불빛·숨쉬기 같은 그림이 멈추지 않게)
var play_time := 0.0          # 세상이 실제로 굴러간 시간. 대화·장면 중에는 멈춘다 (배너 기다리기 · 습격 뒤 숨 돌리기)
var dayTime := 0.27           # 0~1, 하루 중 시각 (조명용). 새벽에서 시작
var day := 1
var weather := {}
var quests := {}
var chores := {}
var questScenes := []         # 대목을 끝내며 밀린 장면
var bossesDefeated := {}
var raid := {}
var upgrades := {}            # 그론 상점 강화 횟수 { hp, dmg, spd }
var openedChests := {}
var blessingDay := 0
var activity = null           # 진행 중인 대련/술래잡기
var companion = null
var den := {}                 # 아지트 둥지: 나뭇가지를 모아 지어야 알을 품을 수 있다
var rally := 0.0              # 용의 함성: 남은 시간 동안 아군 공격력 +50%
var story := {}
var talkTarget = null         # 지금 T·클릭으로 말을 걸 수 있는 상대
var nav = null                # 추적창을 눌러 알아서 걸어가는 중
var fadeTargets := []         # 이번 프레임에 나무 뒤로 숨으면 안 되는 것들
var relics := []
var relicSlots := []
var materials := {}
var waystones := []           # 깨운 이동 석비 id
var dungeon = null            # 굴에 들어가 있으면 { id, depth, ... }
var map_id := "VILLAGE"       # 2D판 mapId
var visited := []             # 발을 들여 본 지도들
var dojoSpot = null           # 수련장 허수아비가 설 자리
var denNest = null
var eggSitting = null
var indoors := false          # 굴 안(보금자리·미궁)인가
var event = null              # 밤 이벤트 'BLOOD_MOON' | 'METEOR'
var stats := {}
var growth := {}
var revivedDay := 0
var raidTimer := 0.0
var elderTutorialDone := false
var tutorial := {}
var furniture := {}
var denDecor := []
var densSeen := []
var holding = null
var tour = null
var prologue = null           # 떨어지던 밤. 새 게임에서만
var player = null
var partner = null
var currentNpc = null
var pendingBond = null
var kids := []
var entities := {}            # 지금 지도의 개체들 (systems/world 가 채운다)
var bannerUntil := 0.0
var flow := {}                # 싸움의 흐름 (systems/flow)
var packTurn := 0.0           # 포위하는 무리가 덤빌 차례
var emberDay := 0
var ambush = null             # 베르단의 포위 { phase, captain, t, waveT, first } (systems/ambush)


func _ready() -> void:
	reset()


static func empty_pools() -> Dictionary:
	return { bullets = [], effects = [], items = [], particles = [], nests = [], babies = [], props = [], npcs = [], enemies = [], humans = [], bosses = [], hazards = [] }


func reset() -> void:
	gameActive = false
	isDialogueOpen = false
	game_time = 0.0
	play_time = 0.0
	dayTime = 0.27
	day = 1
	weather = { type = "CLEAR", timer = 70, intensity = 0, flash = 0 }
	quests = { active = {}, done = [], tracked = null, choices = {} }
	chores = { day = 0, offers = [], taken = {}, done = [] }
	questScenes = []
	bossesDefeated = {}
	raid = { count = 0, active = false }
	upgrades = {}
	openedChests = {}
	blessingDay = 0
	activity = null
	companion = null
	den = { built = false, twigs = 0 }
	rally = 0.0
	story = { scenes = [], lessons = [], lessonDay = 0, events = [], bonds = [], rites = [], clues = [], today = {}, yesterday = {} }
	relics = []
	relicSlots = []
	materials = {}
	waystones = []
	dungeon = null
	map_id = "VILLAGE"
	visited = []
	dojoSpot = null
	denNest = null
	eggSitting = null
	indoors = false
	furniture = {}
	denDecor = []
	densSeen = []
	holding = null
	event = null
	stats = { kills = {}, brinks = 0 }
	growth = { points = 0, nodes = {}, ranks = {} }
	revivedDay = 0
	raidTimer = Data.get_module("core_config").RAID_FIRST_DELAY
	elderTutorialDone = false
	tutorial = { moved = false, journal = false, ate = false, toured = false, finished = false }
	tour = null
	nav = null
	fadeTargets = []
	talkTarget = null
	prologue = null
	player = null
	partner = null
	currentNpc = null
	pendingBond = null
	kids = []
	entities = empty_pools()
	flow = {}
	packTurn = 0.0
	emberDay = 0
	ambush = null
