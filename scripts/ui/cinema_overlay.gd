class_name CinemaOverlay
extends Control
## 컷씬의 검은 막 · 가운데 큰 글 · 이름패 · 싸움 중 자막 (Cutscene 이 값을 정하고 여기서는 보여 주기만 한다).
## 모양은 scenes/ui/cinema_overlay.tscn. 컷씬 층(6)에 있어서 대화창(HUD, 10)보다 아래다 —
## 까만 화면 위에 해설 한 줄이 뜨는 장면이 된다.

@onready var _curtain: ColorRect = $Curtain
@onready var _caption: Control = $Caption
@onready var _caption_text: Label = $Caption/Text
@onready var _card: Control = $Card
@onready var _card_name: Label = $Card/Name
@onready var _card_sub: Label = $Card/Sub
@onready var _subtitle: Label = $Subtitle


func _process(_dt: float) -> void:
	_curtain.visible = Cutscene.black > 0.002
	_curtain.modulate.a = Cutscene.black
	_caption.visible = Cutscene.caption_a > 0.002
	if _caption.visible:
		if _caption_text.text != Cutscene.caption: _caption_text.text = Cutscene.caption
		_caption.modulate.a = Cutscene.caption_a
		_caption.position.y = (size.y / 2 - 60) + (1.0 - Cutscene.caption_a) * 10   # 떠오를 때 살짝 올라온다
	# 이름패: 보스·새 땅의 이름. 떠오르며 살짝 올라온다
	_card.visible = Cutscene.card_a > 0.002
	if _card.visible:
		_card_name.text = Cutscene.card.get("name", "")
		_card_sub.text = Cutscene.card.get("sub", "")
		_card.modulate.a = Cutscene.card_a
		_card.position.y = (size.y * 0.66 - 50) + (1.0 - Cutscene.card_a) * 14
	# 싸움 중 자막: 세상을 멈추지 않고 보스의 한마디를 띄운다
	var sub := Cutscene.subtitle_alpha()
	_subtitle.visible = sub > 0.002
	if _subtitle.visible:
		if _subtitle.text != Cutscene.subtitle: _subtitle.text = Cutscene.subtitle
		_subtitle.modulate.a = sub
