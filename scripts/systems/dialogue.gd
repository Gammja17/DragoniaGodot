class_name Dialogue
## 2D판 systems/dialogue.js. 말 걸기의 입구.
## 마을 고정 NPC는 NpcActions 의 고유 대화 화면으로, 떠돌이 용과 첫날 촌장은 data/dialogues.json 의 대본으로.

# 이 모듈이 컷씬을 걸었는지. 걸었을 때만 우리가 내린다 (사건 장면은 Chronicle 이 따로 관리한다)
static var _our_cutscene := false


static func _scripts() -> Dictionary: return Data.get_module("dialogues").NPC_SCRIPTS


## type: 'TALK' | 'FLIRT'
static func start(npc, type := "TALK") -> void:
	GameState.currentNpc = npc
	GameState.isDialogueOpen = true
	# 엘더는 튜토리얼이 끝난 뒤에야 평소 대화·퀘스트가 열린다
	var tutorial_pending: bool = npc.config.get("role") == "ELDER" and not GameState.elderTutorialDone
	# 마을 고정 NPC는 고유 대화 화면으로
	if type == "TALK" and not tutorial_pending and NpcActions.open_hub(npc): return

	var group: Dictionary
	var key := "intro"
	if npc.config.get("role") == "ELDER":
		group = _scripts().TUTORIAL if (not GameState.elderTutorialDone and type == "TALK") else _scripts().WISE
		# 눈을 뜨고 처음 촌장과 나누는 말은 이야기의 첫 장면이다. 컷씬으로 연출한다
		if group == _scripts().TUTORIAL:
			_our_cutscene = true
			Cutscene.begin("처음 눈을 뜬 날")
			Cutscene.focus_on(npc)
	elif type == "FLIRT" and npc.config.get("canPartner"):
		group = _scripts().FLIRT
		key = _flirt_key(npc)
	else:
		group = _scripts().get(npc.config.get("personality", ""), _scripts().WISE)
	_render(group, key, npc)


static func _flirt_key(npc) -> String:
	return "low" if npc.relation < 30 else "mid" if npc.relation < 60 else "high"


static func close() -> void:
	GameState.isDialogueOpen = false
	GameState.currentNpc = null
	DialogueBox.current.hide_dialogue()
	if _our_cutscene:
		_our_cutscene = false
		Cutscene.finish()


static func _render(group: Dictionary, key: String, npc) -> void:
	var node = group.get(key)
	if not node:
		close()
		return
	var options: Array = node.options.map(func(opt): return { label = opt.t, on_select = func(): _choose(group, opt, npc) })
	if key == "intro" and _can_gift(npc):
		options.append({ label = "고기를 선물한다 (고기 -1)", on_select = func(): _gift(npc) })
	if key == "intro" and group != _scripts().TUTORIAL and npc.config.get("canPartner") and not npc.config.get("fixed"):
		options.append({ label = "💗 마음을 떠본다", on_select = func(): _render(_scripts().FLIRT, _flirt_key(npc), npc) })
	DialogueBox.current.show_dialogue({ name = Names.npc(npc.config.name), text = node.text, options = options, on_close = close, sheet = npc.sheet, npc = npc })


static func _choose(group: Dictionary, opt: Dictionary, npc) -> void:
	if opt.get("eff"):
		NpcActions.add_relation(npc, opt.eff)   # 하루에 쌓을 수 있는 호감(NpcActions.DAILY_GAIN)을 함께 센다
		npc.emote("♥" if opt.eff > 0 else "💢")   # 대화창을 보는 눈에 닿게, 위쪽 알림 대신 그 용의 머리 위에
	match opt.next:
		"end":
			if group == _scripts().TUTORIAL:
				GameState.elderTutorialDone = true
				_give_meat(3, "그론이 구워 둔 고기 3개. [C]로 먹는다")
				close()
				Quests.notify("talk", "Elder")
				Tour.start()          # 포코가 마을을 데리고 돈다
				return
			close()
		"meat":
			_give_meat(3, "고기 3개를 받았습니다!")
			_render(group, "meat", npc)
		"partner":
			# 짝이 되려면 데이트 세 번 뒤 대화(T)에서 고백해야 한다 (NpcActions)
			Hud.pop("마음이 통한 것 같다. 데이트를 세 번 하고 나면, 대화에서 [마음을 고백한다]를 고를 수 있습니다.", "💗")
			close()
		_:
			_render(group, opt.next, npc)


static func _give_meat(n: int, msg: String) -> void:
	if not GameState.player: return
	GameState.player.inventory.meat += n
	Hud.pop(msg, "🍖")


## 선물: NPC마다 하루에 한 번, 호감도 +8
static func _can_gift(npc) -> bool:
	return npc.config.get("role") != "ELDER" and GameState.player.inventory.meat > 0 and npc.last_gift_day != GameState.day


static func _gift(npc) -> void:
	GameState.player.inventory.meat -= 1
	npc.last_gift_day = GameState.day
	var got := NpcActions.add_relation(npc, 8)
	Particles.burst(npc.x, npc.y - 60, "#ff7aa8", 1, 10)
	npc.say("고마워! 잘 먹을게.")
	Hud.pop("%s에게 고기를 선물했습니다. (%s)" % [Names.npc(npc.config.name), "호감 ↑" if got > 0 else "오늘은 이미 많이 가까워졌습니다"], "🎁")
	close()
