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
@onready var _card_rule: Control = $Card/Rule
@onready var _card_sub: Label = $Card/Sub
@onready var _slam: Label = $Slam                                  # 막 박힌 보스 이름 글자 하나 (크게 떴다가 떨어진다)
@onready var _name_plain: LabelSettings = _card_name.label_settings   # 새 땅 · 쓰러짐 이름패의 글씨
@onready var _subtitle: Label = $Subtitle

const SLAM_SEC := 0.12   # 막 박힌 글자가 제자리에 떨어지기까지 (Cutscene.STAMP_SEC 보다 짧아야 다음 글자 전에 내려앉는다)


func _process(_dt: float) -> void:
	_curtain.visible = Cutscene.black > 0.002
	_curtain.modulate.a = Cutscene.black
	_caption.visible = Cutscene.caption_a > 0.002
	if _caption.visible:
		if _caption_text.text != Cutscene.caption: _caption_text.text = Cutscene.caption
		_caption.modulate.a = Cutscene.caption_a
		_caption.position.y = (size.y / 2 - 60) + (1.0 - Cutscene.caption_a) * 10   # 떠오를 때 살짝 올라온다
	# 이름패: 보스·새 땅의 이름. 떠오르며 살짝 올라온다.
	# 보스의 이름패(stamp)는 화면 한가운데 보스 위에 큰 글씨로 한 글자씩 박고, 다 박은 뒤에 줄과 칭호가 떠오른다
	_card.visible = Cutscene.card_a > 0.002
	_slam.visible = false
	if _card.visible:
		var stamp: bool = Cutscene.card.get("stamp", false)
		var name_text: String = Cutscene.card.get("name", "")
		_card_name.label_settings = _slam.label_settings if stamp else _name_plain
		_card_name.text = name_text
		_card_sub.text = Cutscene.card.get("sub", "")
		_card.modulate.a = Cutscene.card_a
		var landing := stamp and Cutscene.card_hit < SLAM_SEC   # 막 박힌 글자는 아직 떨어지는 중이라 제자리에는 없다
		_card_name.visible_characters = Cutscene.card_n - (1 if landing else 0) if stamp else -1
		var after := 1.0
		if stamp: after = clampf(Cutscene.card_hit / 0.35, 0.0, 1.0) if Cutscene.card_n >= name_text.length() else 0.0
		_card_rule.modulate.a = after
		_card_sub.modulate.a = after
		if stamp:
			_card.position.y = size.y * 0.5 - _card_name.size.y * 0.5
			if landing: _slam_letter(name_text)
		else:
			_card.position.y = (size.y * 0.66 - 50) + (1.0 - Cutscene.card_a) * 14
	# 싸움 중 자막: 세상을 멈추지 않고 보스의 한마디를 띄운다
	var sub := Cutscene.subtitle_alpha()
	_subtitle.visible = sub > 0.002
	if _subtitle.visible:
		if _subtitle.text != Cutscene.subtitle: _subtitle.text = Cutscene.subtitle
		_subtitle.modulate.a = sub


## 막 박힌 글자를 제자리 위에서 크게 띄웠다가 쿵 떨어뜨린다 (두두둥)
func _slam_letter(name_text: String) -> void:
	var n := Cutscene.card_n
	if n <= 0: return
	var font: Font = _slam.label_settings.font
	var fs: int = _slam.label_settings.font_size
	var full := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var before := font.get_string_size(name_text.left(n - 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ch := name_text[n - 1]
	var k := clampf(Cutscene.card_hit / SLAM_SEC, 0.0, 1.0)
	var s := lerpf(2.4, 1.0, k * k)
	_slam.text = ch
	_slam.size = Vector2(font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, _card_name.size.y)
	_slam.pivot_offset = _slam.size / 2
	_slam.scale = Vector2(s, s)
	_slam.modulate.a = Cutscene.card_a * minf(1.0, 0.35 + k)
	_slam.position = _card.position + _card_name.position + Vector2((_card_name.size.x - full) / 2 + before, 0)
	_slam.visible = true
