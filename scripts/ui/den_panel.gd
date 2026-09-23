class_name DenPanel
## 2D판 ui/denPanel.js 의 굴 꾸미기 판. [E] 로 열고, 고른 살림살이를 들고 놓는 자리로 간다.
##  · [가진 것]    놓을 수 있는 것들. 고르면 들고 나간다
##  · [엮는다]     골드와 소재로 새로 만든다
##  · [놓아 둔 것] 치워서 되돌린다
##
## 그림 목록이 달린 제 판은 5단계(UI)에서 장면으로 만든다. 그때까지는 대화창에 같은 메뉴를 띄운다.

static var _tab := "have"


static func _close() -> void:
	DialogueBox.current.set_meta("den_panel", false)
	GameState.isDialogueOpen = false
	DialogueBox.current.hide_dialogue()


static func is_open() -> bool:
	return GameState.isDialogueOpen and DialogueBox.current.get_meta("den_panel", false)


static func open() -> void:
	if GameState.map_id != Den.MY_DEN: return
	_render()


static func close() -> void:
	if is_open(): _close()


## 놓을 자리를 고르는 동안 화면 아래에 띄우는 안내 한 줄 (빈 글이면 지운다)
static func hint(text: String) -> void:
	Hud.current.set_hint(text)


## 하나를 들고 놓는 자리로 간다 (판은 닫힌다)
static func _hold(id: String) -> void:
	GameState.holding = id
	_close()
	Hud.pop("놓을 자리를 고르고 왼쪽 클릭. 오른쪽 클릭이면 그만둔다.", "🪑")


static func _render() -> void:
	var F := Den.furniture()
	var cozy := Den.cozy_of(Den.MY_DEN)
	var tabs := [
		{ label = "%s가진 것" % ("▸ " if _tab == "have" else ""), on_select = func(): _switch("have") },
		{ label = "%s엮는다" % ("▸ " if _tab == "craft" else ""), on_select = func(): _switch("craft") },
		{ label = "%s놓아 둔 것" % ("▸ " if _tab == "placed" else ""), on_select = func(): _switch("placed") },
	]
	var rows := []
	var empty := ""
	var desc := func(id: String) -> String:
		var f: Dictionary = F[id]
		return "아늑함 +%d%s%s" % [f.cozy, " · 벽에 건다" if f.get("wall") else "", " · 빛난다" if f.get("light") else ""]
	match _tab:
		"have":
			for id in Den.owned_list():
				rows.append({ label = "🪑 %s (%d개) — %s" % [F[id].name, Den.owned(id), desc.call(id)], on_select = func():
					Sfx.play("ui")
					_hold(id) })
			empty = "아직 가진 살림살이가 없다. [엮는다] 에서 만들어 보자."
		"craft":
			for id in F:
				rows.append({ label = "%s %s — %s" % ["🔨" if Den.can_afford(id) else "🔒", F[id].name, Den.cost_text(id)], on_select = func():
					if not Den.craft(id): Hud.pop("재료나 골드가 모자랍니다.", "🪵")
					_render() })
		"placed":
			var list := Den.decor_of(Den.MY_DEN)
			for i in list.size():
				var d: Dictionary = list[i]
				rows.append({ label = "🧹 %s — 치워서 되돌린다" % F[d.id].name, on_select = func():
					Den.pick_up(i)
					World.refresh_den()
					Hud.pop("%s을(를) 치웠다." % F[d.id].name, "🧹")
					_render() })
			empty = "굴 안이 아직 휑하다."
	var text := "아늑함 %d · %s\n%s" % [cozy.score, cozy.name, cozy.note]
	if rows.is_empty() and empty != "": text += "\n\n" + empty
	GameState.isDialogueOpen = true
	DialogueBox.current.set_meta("den_panel", true)
	DialogueBox.current.show_dialogue({ name = "굴 꾸미기", text = text, on_close = _on_close, options = tabs + rows + [{ label = "닫는다", on_select = _on_close }] })


static func _switch(tab: String) -> void:
	_tab = tab
	Sfx.play("ui")
	_render()


static func _on_close() -> void:
	_close()
