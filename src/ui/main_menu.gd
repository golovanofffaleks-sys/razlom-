extends Control

const SLICE: String = "res://src/world/levels/outskirts_slice.tscn"

@onready var _start: Button = %Start
@onready var _quit: Button = %Quit
@onready var _ambience: AudioStreamPlayer = $Ambience


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_start.pressed.connect(_start_path)
	_quit.pressed.connect(_quit_game)
	_start.grab_focus()


func _start_path() -> void:
	_ambience.stop()
	get_tree().change_scene_to_file(SLICE)


func _quit_game() -> void:
	_start.disabled = true
	_quit.disabled = true
	_ambience.stop()
	await get_tree().create_timer(0.12).timeout
	get_tree().quit()
