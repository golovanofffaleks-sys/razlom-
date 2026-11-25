class_name OutskirtsDialogue
extends PanelContainer

signal finished

var _resource: DialogueResource
var _line: DialogueLine
var _loading: bool = false

@onready var _speaker: Label = %Speaker
@onready var _text: RichTextLabel = %Line
@onready var _responses: VBoxContainer = %Options
@onready var _advance: Button = %Advance


func _ready() -> void:
	_advance.pressed.connect(_advance_line)


func start(resource: DialogueResource, cue: String) -> void:
	_resource = resource
	show()
	_show_line(cue)


func _advance_line() -> void:
	if _line != null:
		_show_line(_line.next_id)


func _show_line(key: String) -> void:
	if _loading:
		return
	_loading = true
	_line = await DialogueManager.get_next_dialogue_line(_resource, key)
	_loading = false
	if _line == null:
		hide()
		finished.emit()
		return
	_speaker.text = _line.character
	_text.text = _line.text
	for option: Node in _responses.get_children():
		_responses.remove_child(option)
		option.queue_free()
	_advance.visible = _line.responses.is_empty()
	if _advance.visible:
		_advance.grab_focus()
	for response: DialogueResponse in _line.responses:
		if not response.is_allowed:
			continue
		var option: Button = Button.new()
		option.text = response.text
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		option.pressed.connect(_show_line.bind(response.next_id))
		_responses.add_child(option)
	var count: int = _responses.get_child_count()
	if count == 0:
		return
	for index: int in count:
		var option: Button = _responses.get_child(index) as Button
		var previous: NodePath = option.get_path_to(_responses.get_child(posmod(index - 1, count)))
		var next: NodePath = option.get_path_to(_responses.get_child((index + 1) % count))
		option.focus_neighbor_top = previous
		option.focus_neighbor_bottom = next
		option.focus_previous = previous
		option.focus_next = next
	(_responses.get_child(0) as Button).grab_focus()
