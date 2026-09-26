class_name SaveCodePanel
extends GamePanel
## 저장 코드: 이 기기의 기록을 글자로 옮겨 다른 기기(PC → 폰)에서 이어 한다. 서버를 거치지 않는다.
##   내보내기: 그 칸의 기록을 압축한 글자를 보여 주고 곧바로 복사한다. 카톡 '나에게 보내기'처럼 글을 보낼 수 있는 곳이면 옮길 수 있다.
##   불러오기: 붙여 넣은 코드를 그 칸에 쓴다 (그 칸의 기록은 지워진다). 처음 화면에서만 연다.
## 웹판에서 붙여 넣기는 브라우저 입력 창으로 받는다 (휴대폰에서는 판 안의 글 칸에 붙여 넣기가 잘 안 된다).

signal imported(n: int)

var slot := 1

@onready var _note: Label = $Frame/Lines/Body/Note
@onready var _code: TextEdit = $Frame/Lines/Body/Code
@onready var _status: Label = $Frame/Lines/Body/Status
@onready var _copy: Button = $Frame/Lines/Body/Buttons/Copy
@onready var _switch: Button = $Frame/Lines/Body/Buttons/Switch
@onready var _paste: Button = $Frame/Lines/Body/Buttons/Paste
@onready var _load: Button = $Frame/Lines/Body/Buttons/Load


func _ready() -> void:
	super()
	_copy.pressed.connect(_copy_code)
	_switch.pressed.connect(func(): open_import(slot))
	_paste.pressed.connect(_paste_code)
	_load.pressed.connect(_import)


## 그 칸의 기록을 코드로 보여 주고 곧바로 복사한다. allow_import: 처음 화면이면 [다른 코드로 바꾸기]도
func open_export(n: int, allow_import := false) -> void:
	slot = n
	title = "%d번 칸 저장 코드" % n
	_code.text = Save.export_code(n)
	_code.editable = false
	_note.text = "다른 기기에서 처음 화면의 [저장 코드] → [붙여 넣기]로 이 코드를 넣으면 여기서 하던 판을 이어 한다.\n카톡 '나에게 보내기'처럼 글을 보낼 수 있는 곳이면 된다."
	_status.text = ""
	_copy.visible = true
	_switch.visible = allow_import
	_paste.visible = false
	_load.visible = false
	open()
	_copy_code()


## 붙여 넣은 코드를 이 칸에 들인다
func open_import(n: int) -> void:
	slot = n
	title = "저장 코드로 불러오기 · %d번 칸" % n
	_code.text = ""
	_code.editable = true
	_note.text = "다른 기기에서 복사한 저장 코드를 붙여 넣는다." + ("\n이 칸의 기록은 지워지고 코드에 담긴 기록으로 바뀐다." if Save.has_save(n) else "")
	_status.text = ""
	_copy.visible = false
	_switch.visible = false
	_paste.visible = true
	_load.visible = true
	open()


func _copy_code() -> void:
	if _code.text == "":
		_status.text = "이 칸에는 기록이 없다."
		return
	DisplayServer.clipboard_set(_code.text)
	_status.text = "복사했다 (%d 글자). 복사가 안 됐으면 위의 글을 모두 골라 복사한다." % _code.text.length()


func _paste_code() -> void:
	var text := ""
	if OS.has_feature("web"):
		var got = JavaScriptBridge.eval("window.prompt('저장 코드를 붙여 넣으세요', '') || ''")
		text = str(got) if got != null else ""
	else:
		text = DisplayServer.clipboard_get()
	if text.strip_edges() == "":
		_status.text = "붙여 넣을 코드가 없다. 다른 기기에서 먼저 [저장 코드]를 복사하자."
		return
	_code.text = text
	_status.text = ""


func _import() -> void:
	if not Save.import_code(_code.text, slot):
		_status.text = "코드가 잘못됐다. 처음부터 끝까지 빠짐없이 복사했는지 보자."
		return
	close()
	imported.emit(slot)
