class_name Credits
extends Control
## 이야기의 끝에 올라가는 크레딧. 모양은 scenes/ui/credits.tscn (줄 모양은 Templates 아래의 Label 들을 복제해 쓴다).
## 무엇을 적을지는 Ending 이 건넨다. [Space] 를 누르고 있으면 빨리, [Esc] 로 건너뛴다. 끝나면 가운데에 "끝".

const SPEED := 48.0          # 초당 몇 px 올라가나
const FAST := 7.0            # [Space] 를 누르고 있으면 이만큼 빠르게

static var current: Credits

@onready var _roll: VBoxContainer = $Roll
@onready var _end: Label = $End
@onready var _hint: Label = $Hint

var _rolling := false
var _ending := false
var _done = null


func _ready() -> void:
	current = self


static func is_rolling() -> bool:
	return current != null and current.visible


## rows: [{ kind: "title" | "head" | "line" | "small" | "gap", text }] · end_text: 다 올라간 뒤 가운데에 뜨는 글
func roll(rows: Array, end_text: String, done: Callable) -> void:
	for c in _roll.get_children():
		_roll.remove_child(c); c.queue_free()
	for r in rows:
		var kind: String = str(r.get("kind", "line"))
		var tpl: Control = $Templates.get_node(kind.capitalize())
		var n: Control = tpl.duplicate()
		if n is Label: n.text = str(r.get("text", ""))
		_roll.add_child(n)
	_end.text = end_text
	_end.visible = false
	_end.modulate.a = 0
	if not _hint.has_meta("text"): _hint.set_meta("text", _hint.text)   # 패드·터치면 그 기기의 단추 이름으로
	_hint.text = GameInput.words(_hint.get_meta("text"))
	_hint.visible = true
	visible = true
	modulate.a = 0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.2)
	_roll.position.y = size.y + 40
	_roll.size.x = size.x
	_rolling = true
	_ending = false
	_done = done
	GameState.isDialogueOpen = true   # 크레딧이 도는 동안 세상은 멈춘다


func _process(dt: float) -> void:
	if not visible or not _rolling: return
	var fast := GameInput.down("confirm") or GameInput.down("attack") or GameInput.mouse_down
	_roll.position.y -= SPEED * (FAST if fast else 1.0) * dt
	if _roll.position.y + _roll.size.y < size.y * 0.35: _show_end()


## [Esc]: 곧장 "끝" 으로
func skip() -> void:
	if _rolling and not _ending: _show_end()


func _show_end() -> void:
	if _ending: return
	_ending = true
	_hint.visible = false
	var t := create_tween()
	t.tween_property(_roll, "modulate:a", 0.0, 0.8)
	t.tween_callback(func():
		_end.visible = true)
	t.tween_property(_end, "modulate:a", 1.0, 1.4)
	t.tween_interval(2.8)
	t.tween_property(self, "modulate:a", 0.0, 1.2)
	t.tween_callback(_finish)


func _finish() -> void:
	_rolling = false
	visible = false
	_roll.modulate.a = 1.0
	GameState.isDialogueOpen = false
	var d = _done
	_done = null
	if d: d.call()
