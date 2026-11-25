class_name LinaGymHud
extends CanvasLayer

const TUNING_DIR: String = "user://gym_tuning"
const LABELS: Dictionary[StringName, String] = {
	&"run_speed": "Скорость бега · %.1f м/с",
	&"dash_speed": "Сила рывка · %.1f м/с",
	&"aim_time_scale": "Время при прицеливании · ×%.2f",
}

var _tuning: Resource
var _labels: Dictionary[StringName, String]
var _snapshot_prefix: String

@onready var _panel: PanelContainer = %TuningPanel
@onready var _rows: VBoxContainer = %SliderRows
@onready var _metrics: Label = %Metrics
@onready var _reticle: Label = %Reticle
@onready var _aim_label: Label = %AimLabel
@onready var _notice: Label = %Notice


func bind(tuning: Resource, labels: Dictionary[StringName, String] = LABELS, snapshot_prefix: String = "lina_gym") -> void:
	_tuning = tuning
	_labels = labels
	_snapshot_prefix = snapshot_prefix
	for property: Dictionary in _tuning.get_property_list():
		var key: StringName = property["name"]
		if not _labels.has(key):
			continue
		var limits: PackedStringArray = String(property["hint_string"]).split(",")
		var label: Label = Label.new()
		label.text = _labels[key] % float(_tuning.get(key))
		_rows.add_child(label)
		var slider: HSlider = HSlider.new()
		slider.name = String(key).to_pascal_case()
		slider.min_value = float(limits[0])
		slider.max_value = float(limits[1])
		slider.step = float(limits[2])
		slider.value = float(_tuning.get(key))
		slider.custom_minimum_size.y = 25.0
		slider.value_changed.connect(_on_value_changed.bind(key, label))
		_rows.add_child(slider)


func is_panel_open() -> bool:
	return _panel.visible


func set_panel_open(open: bool) -> void:
	_panel.visible = open
	if not open:
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused != null and _panel.is_ancestor_of(focused):
			focused.release_focus()


func set_aiming(aiming: bool) -> void:
	_reticle.visible = aiming
	_aim_label.visible = aiming


func toggle_metrics() -> void:
	_metrics.visible = not _metrics.visible



func update_metrics(velocity: Vector3, time_scale: float) -> void:
	if _metrics.visible:
		var speed: float = Vector2(velocity.x, velocity.z).length()
		_metrics.text = "%.1f м/с   ·   ×%.2f   ·   %d FPS" % [speed, time_scale, Engine.get_frames_per_second()]
	if _aim_label.visible:
		_aim_label.text = "ВРЕМЯ ×%.2f" % time_scale


func save_tuning() -> void:
	if not OS.is_debug_build():
		return
	var folder: String = ProjectSettings.globalize_path(TUNING_DIR)
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		_notice.text = "Не удалось создать папку настроек"
		return
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var path: String = "%s/%s_%s_%d.json" % [folder, _snapshot_prefix, stamp, Time.get_ticks_msec()]
	var values: Dictionary[String, float] = {}
	for key: StringName in _labels:
		values[String(key)] = float(_tuning.get(key))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null or not file.store_string(JSON.stringify(values, "  ") + "\n"):
		_notice.text = "Не удалось сохранить настройки"
		return
	file.close()
	_note_saved(path)


func _note_saved(path: String) -> void:
	_notice.text = "Сохранено · %s" % path.get_file()
	print("Lina Gym settings saved to ", path)


func _on_value_changed(value: float, key: StringName, label: Label) -> void:
	_tuning.set(key, value)
	label.text = _labels[key] % value
