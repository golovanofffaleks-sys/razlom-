class_name CombatGymHud
extends LinaGymHud

const COMBAT_LABELS: Dictionary[StringName, String] = {
	&"arrow_speed": "Скорость стрелы · %.1f м/с",
	&"arrow_damage": "Урон стрелы · %.0f",
	&"archery_xp": "Опыт за попадание · %.0f",
	&"sword_damage": "Урон меча · %.0f",
	&"sword_reach": "Дальность меча · %.1f м",
	&"stamina_regen": "Восстановление выносливости · %.0f/с",
	&"dodge_cost": "Стоимость кувырка · %.0f",
	&"dodge_iframes": "Неуязвимость в кувырке · %.2f с",
}

@onready var _archery: Label = %Archery
@onready var _other_skills: Label = %OtherSkills
@onready var _health: ProgressBar = %HealthBar
@onready var _stamina: ProgressBar = %StaminaBar
@onready var _health_value: Label = _health.get_node("Value")
@onready var _stamina_value: Label = _stamina.get_node("Value")


func bind_combat(tuning: Resource, health: HealthComponent, stamina: StaminaComponent,
		labels: Dictionary[StringName, String] = COMBAT_LABELS, snapshot_prefix: String = "combat_gym") -> void:
	bind(tuning, labels, snapshot_prefix)
	EventBus.skill_xp_gained.connect(_refresh_skills.unbind(2), CONNECT_DEFERRED)
	health.health_changed.connect(_update_health)
	stamina.stamina_changed.connect(_update_stamina)
	_update_health(health.current_health, health.max_health, 0.0)
	_update_stamina(stamina.current, stamina.tuning.max_stamina)
	_refresh_skills()


func set_element(charge: CombatElements.Charge) -> void:
	var controls: Label = $Screen/Title/Content/Controls
	controls.text = "ПКМ + ЛКМ  Лук  ·  ЛКМ  Меч\n1 Огонь · 2 Лёд · 3 Молния    |    %s" % CombatElements.NAMES[charge]
	controls.add_theme_color_override(&"font_color", CombatElements.COLORS[charge].lerp(Color.WHITE, 0.4))


func _update_health(current: float, maximum: float, _damage: float) -> void:
	_health.max_value = maximum
	_health.value = current
	_health_value.text = "HP  %d / %d" % [ceili(current), roundi(maximum)]


func _update_stamina(current: float, maximum: float) -> void:
	_stamina.max_value = maximum
	_stamina.value = current
	_stamina_value.text = "Выносливость  %d / %d" % [ceili(current), roundi(maximum)]


func _refresh_skills() -> void:
	var level: int = StatsManager.get_skill_level("archery")
	var xp: float = StatsManager.get_skill_xp("archery")
	_archery.text = "Стрельба · ур. %d  ·  %d / %d ОП" % [level, int(xp), int(StatsManager.XP_PER_LEVEL * level)]
	_other_skills.text = "Ловкость %d · %d ОП   |   Стойкость %d   ·   Баланс %d" % [
		StatsManager.get_skill_level("agility"),
		int(StatsManager.get_skill_xp("agility")),
		StatsManager.get_skill_level("endurance"),
		StatsManager.get_skill_level("balance_magic"),
	]
