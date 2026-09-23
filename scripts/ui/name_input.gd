class_name NameInput
extends PanelContainer
## 이름 짓기 칸. 2D판은 브라우저의 prompt() 창을 띄웠다 (아이 이름 · 도란과 미루의 아이).
## 비워 두거나 Esc 로 닫으면 처음 채워 둔 이름을 그대로 쓴다.

static var current: NameInput

@onready var _prompt: Label = %Prompt
@onready var _edit: LineEdit = %Edit
@onready var _ok: Button = %Ok

var _default := ""
var _max_len := 12
var _done: Callable


func _ready() -> void:
	current = self
	visible = false
	_ok.pressed.connect(_submit)
	_edit.text_submitted.connect(func(_t): _submit())


## prompt: 물어볼 말 · default_name: 처음 채워 둘 이름 · done(name): 정한 이름을 받는다
static func ask(prompt: String, default_name: String, done: Callable, max_len := 6) -> void:
	var n := current
	n._default = default_name
	n._max_len = max_len
	n._done = done
	n._prompt.text = prompt
	n._edit.max_length = max_len
	n._edit.text = default_name
	GameState.isDialogueOpen = true
	n.visible = true
	n._edit.grab_focus()
	n._edit.select_all()


static func is_open() -> bool: return current != null and current.visible


func _submit() -> void:
	var nm := _edit.text.strip_edges().left(_max_len)
	_finish(nm if nm != "" else _default)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish(_default)


func _finish(nm: String) -> void:
	visible = false
	_edit.release_focus()
	GameState.isDialogueOpen = false
	var done := _done
	_done = Callable()
	if done.is_valid(): done.call(nm)
