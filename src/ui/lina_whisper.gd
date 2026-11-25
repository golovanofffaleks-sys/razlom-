class_name LinaWhisper
extends CanvasLayer

const EDGE_SHADER: Shader = preload("res://src/ui/lina_whisper_edge.gdshader")
const THEME: Theme = preload("res://src/ui/outskirts_theme.tres")

@export var voice_player: AudioStreamPlayer3D

var _edge: ColorRect
var _subtitle: Label
var _animation: Tween


func _ready() -> void:
	var overlay: Control = Control.new()
	overlay.name = &"Overlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_edge = ColorRect.new()
	_edge.name = &"ThreatEdge"
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge_material: ShaderMaterial = ShaderMaterial.new()
	edge_material.shader = EDGE_SHADER
	_edge.material = edge_material
	overlay.add_child(_edge)
	_edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edge.hide()

	_subtitle = Label.new()
	_subtitle.name = &"WhisperText"
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.theme = THEME
	_subtitle.theme_type_variation = &"Display"
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.anchor_top = 0.49
	_subtitle.anchor_bottom = 0.49
	_subtitle.add_theme_color_override(&"font_outline_color", Color(0.10, 0.056, 0.13, 0.96))
	_subtitle.add_theme_constant_override(&"outline_size", 6)
	overlay.add_child(_subtitle)
	_subtitle.hide()


func clear() -> void:
	if _animation != null and _animation.is_valid():
		_animation.kill()
	voice_player.stop()
	_edge.hide()
	_subtitle.hide()


func is_active() -> bool:
	return _animation != null and _animation.is_running()


func present(line: String, voice: AudioStream, pan: float, warning: bool) -> void:
	if not warning and _edge.visible:
		return
	clear()
	var right: bool = pan >= 0.0
	var edge_material: ShaderMaterial = _edge.material as ShaderMaterial
	edge_material.set_shader_parameter(&"right_side", float(right))
	_edge.modulate.a = 0.0
	_edge.visible = warning
	_subtitle.anchor_left = 0.58 if right else 0.0
	_subtitle.anchor_right = 1.0 if right else 0.42
	_subtitle.offset_left = 22.0
	_subtitle.offset_right = -22.0
	_subtitle.offset_top = 7.0
	_subtitle.offset_bottom = 7.0
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	_subtitle.add_theme_font_size_override(&"font_size", 29 if warning else 24)
	_subtitle.modulate = Color(1.0, 0.74, 0.64, 0.0) if warning else Color(0.88, 0.87, 1.0, 0.0)
	_subtitle.text = line
	_subtitle.show()
	voice_player.position = Vector3(pan * 1.25, 0.0, -0.92)
	voice_player.volume_db = -12.0 if warning else -16.0
	voice_player.stream = voice
	voice_player.play()

	var fade_in: float = 0.08 if warning else 0.32
	var fade_out: float = 0.52 if warning else 0.72
	var hold: float = maxf(1.08, voice.get_length() - fade_in)
	_animation = create_tween().set_parallel(true).set_ignore_time_scale(true)
	_animation.tween_property(_subtitle, "modulate:a", 0.94 if warning else 0.76, fade_in)
	_animation.tween_property(_subtitle, "offset_top", -8.0, fade_in + hold + fade_out).set_trans(Tween.TRANS_SINE)
	if warning:
		_animation.tween_property(_edge, "modulate:a", 0.76, fade_in)
		_animation.tween_property(_edge, "modulate:a", 0.0, 0.62).set_delay(0.17)
	_animation.tween_property(_subtitle, "modulate:a", 0.0, fade_out).set_delay(fade_in + hold)
	_animation.chain().tween_callback(_subtitle.hide)
	_animation.tween_callback(_edge.hide)
