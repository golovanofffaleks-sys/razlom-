class_name RiftGymHud
extends CombatGymHud

const RIFT_LABELS: Dictionary[StringName, String] = {
	&"enemy_speed": "Скорость врагов · %.1f м/с",
	&"wave_interval": "Интервал волн · %.1f с",
	&"seal_duration": "Время запечатывания · %.1f с",
}

var _monologue_tween: Tween
var _status_text: String

@onready var _rift_status: Label = %RiftStatus
@onready var _cast_panel: PanelContainer = %CastPanel
@onready var _cast_bar: ProgressBar = %SealProgress
@onready var _subtitle: PanelContainer = %Subtitle
@onready var _subtitle_text: Label = %SubtitleText


func bind_rift(rift: RiftSpawner, health: HealthComponent, stamina: StaminaComponent) -> void:
	bind_combat(rift.tuning, health, stamina, RIFT_LABELS, "rift_gym")
	rift.encounter_changed.connect(_on_encounter_changed)
	rift.seal_progress_changed.connect(_on_seal_progress)
	EventBus.lina_monologue_triggered.connect(_show_monologue)


func clear_monologue() -> void:
	if _monologue_tween != null and _monologue_tween.is_valid():
		_monologue_tween.kill()
	_subtitle.hide()


func _on_encounter_changed(state: RiftSpawner.State, wave: int, total: int, living: int) -> void:
	match state:
		RiftSpawner.State.ACTIVE:
			if wave == 0:
				_status_text = "Разлом открыт · скоро первая волна"
			elif living > 0:
				_status_text = "Волна %d / %d  ·  Враги: %d" % [wave, total, living]
			else:
				_status_text = "Волна %d / %d отбита · приближается следующая" % [wave, total]
			_rift_status.modulate = Color(0.91, 0.75, 1.0)
		RiftSpawner.State.VULNERABLE:
			_status_text = "Разлом уязвим · подойдите к печати"
			_rift_status.modulate = Color(0.63, 1.0, 0.85)
		RiftSpawner.State.CLOSED:
			_status_text = "Разлом запечатан"
			_rift_status.modulate = Color(0.63, 1.0, 0.85)
	_rift_status.text = _status_text


func _on_seal_progress(available: bool, progress: float) -> void:
	_cast_panel.visible = progress > 0.0
	_cast_bar.value = progress
	_rift_status.text = "Разлом уязвим" if available else _status_text


func _update_health(current: float, maximum: float, damage: float) -> void:
	super._update_health(current, maximum, damage)
	if current <= 0.0:
		_rift_status.text = "Лина пала · R начать заново"
		_rift_status.modulate = Color(1.0, 0.56, 0.51)


func _refresh_skills() -> void:
	super._refresh_skills()
	_other_skills.text = "Ловкость %d · %d ОП\nСтойкость %d · %d ОП   |   Баланс %d · %d ОП" % [
		StatsManager.get_skill_level("agility"), int(StatsManager.get_skill_xp("agility")),
		StatsManager.get_skill_level("endurance"), int(StatsManager.get_skill_xp("endurance")),
		StatsManager.get_skill_level("balance_magic"), int(StatsManager.get_skill_xp("balance_magic")),
	]


func _show_monologue(line: String, _voice: AudioStream, _pan: float, _warning: bool) -> void:
	clear_monologue()
	_subtitle_text.text = line
	_subtitle.modulate.a = 1.0
	_subtitle.show()
	_monologue_tween = create_tween().set_ignore_time_scale(true)
	_monologue_tween.tween_interval(5.0)
	_monologue_tween.tween_property(_subtitle, "modulate:a", 0.0, 0.38)
	_monologue_tween.tween_callback(_subtitle.hide)
