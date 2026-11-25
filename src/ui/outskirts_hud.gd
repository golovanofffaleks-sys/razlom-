class_name OutskirtsHud
extends CanvasLayer

signal resume_requested
signal retry_requested
signal menu_requested

@onready var dialogue: OutskirtsDialogue = %Dialogue
@onready var _zone: Label = %Zone
@onready var _objective: Label = %Objective
@onready var _health: ProgressBar = %Health
@onready var _rally: TextureRect = %Rally
@onready var _stamina: ProgressBar = %Stamina
@onready var _charges: Label = %Charges
@onready var _prompt: Label = %Prompt
@onready var _seal: ProgressBar = %Seal
@onready var _notice: Label = %Notice
@onready var _crosshair: Label = %Crosshair
@onready var _controls: Label = $Interface/Controls
@onready var _veil: ColorRect = %Veil
@onready var _result_title: Label = %ResultTitle
@onready var _result_detail: Label = %ResultDetail
@onready var _resume: Button = %Resume
@onready var _retry: Button = %Retry
@onready var _menu: Button = %Menu
@onready var _click: AudioStreamPlayer = $Click

var _notice_tween: Tween
var _gamepad: bool = false
var _element: CombatElements.Charge = CombatElements.Charge.NONE


func _ready() -> void:
	_resume.pressed.connect(resume_requested.emit)
	_retry.pressed.connect(retry_requested.emit)
	_menu.pressed.connect(menu_requested.emit)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	dialogue.visibility_changed.connect(_update_controls_visibility)
	EventBus.unspent_xp_changed.connect(_set_shards)
	_set_shards(StatsManager.unspent_total())
	use_gamepad(not Input.get_connected_joypads().is_empty())


func bind(health: HealthComponent, stamina: StaminaComponent, life_magic: LinaLifeMagic) -> void:
	health.health_changed.connect(_set_health)
	health.rally_changed.connect(_set_rally)
	stamina.stamina_changed.connect(_set_stamina)
	life_magic.charges_changed.connect(_set_charges)
	_set_charges(life_magic.charges, life_magic.max_charges)


func _unhandled_input(event: InputEvent) -> void:
	if _veil.visible and _resume.visible and (event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel")):
		get_viewport().set_input_as_handled()
		resume_requested.emit()


func set_objective(zone_name: String, objective: String) -> void:
	_zone.text = zone_name
	_objective.text = objective


func set_interaction(prompt: String, progress: float) -> void:
	_prompt.text = prompt
	_seal.visible = progress > 0.0
	_seal.value = progress


func set_element(charge: CombatElements.Charge) -> void:
	_element = charge
	var keys: String = "◀ Огонь    ·    ▲ Лёд    ·    ▶ Молния" if _gamepad else "1 Огонь    ·    2 Лёд    ·    3 Молния"
	%Element.text = "%s    |    %s" % [keys, CombatElements.NAMES[charge]]
	%Element.add_theme_color_override(&"font_color", CombatElements.COLORS[charge].lerp(Color.WHITE, 0.4))


func use_gamepad(active: bool) -> void:
	if active == _gamepad:
		return
	_gamepad = active
	_controls.text = ("LT Лук / парирование · RT Стрела · RB Меч · LB Блок · B Кувырок · R3 Цель" if active else
		"WASD Движение · ПКМ Лук · ЛКМ Атака · F Блок / парирование · Shift Кувырок · Q Цель")
	set_element(_element)


func _set_shards(amount: float) -> void:
	%Shards.text = "Осколки Эфира   %d" % roundi(amount)


func set_aiming(aiming: bool) -> void:
	_crosshair.visible = aiming


func show_notice(message: String) -> void:
	if _notice_tween != null and _notice_tween.is_valid():
		_notice_tween.kill()
	_notice.modulate.a = 1.0
	_notice.text = message
	_notice_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, 0.5).set_delay(3.1)


func show_result(title: String, detail: String, is_pause: bool = false, retry_text: String = "Начать заново") -> void:
	_result_title.text = title
	_result_detail.text = detail
	_resume.visible = is_pause
	_retry.text = retry_text
	_retry.focus_neighbor_top = _retry.get_path_to(_resume if is_pause else _menu)
	_menu.focus_neighbor_bottom = _menu.get_path_to(_resume if is_pause else _retry)
	_veil.show()
	_update_controls_visibility()
	if is_pause:
		_resume.grab_focus()
	else:
		_retry.grab_focus()


func hide_result() -> void:
	_veil.hide()
	_update_controls_visibility()


func _update_controls_visibility() -> void:
	_controls.visible = not dialogue.visible and not _veil.visible
	%Element.visible = _controls.visible


func _set_health(current: float, maximum: float, _damage: float) -> void:
	_health.max_value = maximum
	_health.value = current


func _set_rally(available: float) -> void:
	_rally.visible = available > 0.0
	_rally.set_anchor(SIDE_LEFT, _health.ratio, true)
	_rally.set_anchor(SIDE_RIGHT, minf(1.0, _health.ratio + available / _health.max_value), true)


func _set_stamina(current: float, maximum: float) -> void:
	_stamina.max_value = maximum
	_stamina.value = current


func _set_charges(current: int, maximum: int) -> void:
	_charges.text = "Магия Жизни   %s%s   R / H / X" % ["◆".repeat(current), "◇".repeat(maximum - current)]


func _on_focus_changed(control: Control) -> void:
	if control is Button and is_ancestor_of(control) and not _click.playing:
		_click.play()
