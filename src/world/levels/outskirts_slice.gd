extends LinaCombatControls

enum Mode { PLAY, DIALOGUE, PAUSE, REST, RISE, DYING, DEAD, END }

const MENU: String = "res://src/ui/main_menu.tscn"
const DIALOGUE: DialogueResource = preload("res://src/world/levels/outskirts_npc.dialogue")
const INTERACT: StringName = &"interact"
const SHARD_SCENE: PackedScene = preload("res://src/world/levels/aether_shards.tscn")
const SHARD_RADIUS: float = 1.95
const SANCTUARY_EDGE: float = -6.5
const INTERACTION_RADIUS: float = 2.8
const STORY_WHISPER_RADIUS: float = 3.4
const WARNING_COOLDOWN_MS: int = 1300
const RALLY_COOLDOWN_MS: int = 2900
const BEHIND_VOICE: AudioStream = preload("res://assets/audio/lina_whispers/behind.wav")
const TURN_VOICE: AudioStream = preload("res://assets/audio/lina_whispers/turn.wav")
const RALLY_VOICE: AudioStream = preload("res://assets/audio/lina_whispers/rally.wav")
const RIPOSTE_VOICE: AudioStream = preload("res://assets/audio/lina_whispers/riposte.wav")
const ALTAR_VOICE: AudioStream = preload("res://assets/audio/lina_whispers/altar.wav")
const RUINS_VOICE: AudioStream = preload("res://assets/audio/lina_whispers/ruins.wav")

var _mode: Mode = Mode.PLAY
var _met_hunter: bool = false
var _checkpoint: Vector3
var _shards: Node3D
var _lost_experience: Dictionary[String, float] = {}
var _spell_left: float = 0.0
var _warning_ready_at: int = 0
var _rally_ready_at: int = 0
var _use_turn_warning: bool = false
var _heard_altar: bool = false
var _heard_ruins: bool = false

@onready var _life_magic: LinaLifeMagic = $Lina/LifeMagic
@onready var _altar: Node3D = $Landscape/Altar
@onready var _temple_threshold: Marker3D = $TempleThreshold
@onready var _hunter: Node3D = $Landscape/Hunter
@onready var _north_rift: RiftSpawner = $NorthRift
@onready var _south_rift: RiftSpawner = $SouthRift
@onready var _north_healing: RiftHealing = $NorthRift/Healing
@onready var _south_healing: RiftHealing = $SouthRift/Healing
@onready var _world_environment: WorldEnvironment = $Landscape/Environment
@onready var _moon: DirectionalLight3D = $Landscape/Moon
@onready var _slice_hud: OutskirtsHud = $OutskirtsHud
@onready var _whisper: LinaWhisper = $LinaWhisper
@onready var _ambience: AudioStreamPlayer = $Ambience


func _ready() -> void:
	WorldState.begin_outskirts()
	_north_rift.rift_id = WorldState.NORTH_RIFT
	_south_rift.rift_id = WorldState.SOUTH_RIFT
	_world_environment.environment = _world_environment.environment.duplicate(true) as Environment
	_lina.in_sanctuary = true
	super._ready()
	_checkpoint = _spawn.global_position
	_refresh_objective(_north_rift)


func _bind_hud() -> void:
	super._bind_hud()
	_lina.health.rally_window = 3.5
	_slice_hud.bind(_lina.health, _combat.stamina, _life_magic)
	_combat.element_changed.connect(_slice_hud.set_element)
	_slice_hud.set_element(_combat.element)
	_slice_hud.dialogue.finished.connect(_finish_dialogue)
	_slice_hud.resume_requested.connect(_resume)
	_slice_hud.retry_requested.connect(_retry)
	_slice_hud.menu_requested.connect(_return_to_menu)
	_lina.health.health_changed.connect(_on_health_changed)
	_lina.health.rally_recovered.connect(_on_rally_recovered)
	_combat.riposte_landed.connect(_on_riposte_whisper)
	EventBus.lina_monologue_triggered.connect(_on_monologue)
	EventBus.minion_windup_started.connect(_on_minion_windup)
	EventBus.rift_closed.connect(_on_rift_closed)


func _input(event: InputEvent) -> void:
	if _mode != Mode.PLAY:
		return
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.26):
		_slice_hud.use_gamepad(true)
	elif event is InputEventKey or event is InputEventMouseButton:
		_slice_hud.use_gamepad(false)
	if event.is_action_pressed(&"pause"):
		_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"heal") and _controls_active():
		if not _life_magic.cast():
			var prompt: String = "Заряды исчерпаны. Вернись к Алтарю." if _life_magic.charges == 0 else "Здоровье уже полное."
			_slice_hud.show_notice(prompt)
		else:
			_spell_left = 0.50
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(INTERACT) and _controls_active():
		if _shards_in_reach():
			_recover_shards()
			get_viewport().set_input_as_handled()
		elif _in_sanctuary():
			_interact_in_camp()
			get_viewport().set_input_as_handled()
	else:
		super._input(event)


func _physics_process(delta: float) -> void:
	_spell_left = maxf(0.0, _spell_left - delta / Engine.time_scale)
	_lina.in_sanctuary = _in_sanctuary()
	super._physics_process(delta)
	var active: bool = _controls_active() and not _lina.in_sanctuary
	var held: bool = active and Input.is_action_pressed(INTERACT)
	_north_rift.update_seal(held, active)
	_south_rift.update_seal(held, active)
	var rift: RiftSpawner = _nearest_open_rift()
	_refresh_objective(rift)
	_refresh_interaction(rift)
	_check_story_whispers()


func _controls_active() -> bool:
	return _mode == Mode.PLAY and _spell_left == 0.0 and _lina.health.current_health > 0.0 and get_window().has_focus()


func _action_animation() -> StringName:
	match _mode:
		Mode.REST:
			return &"Rest"
		Mode.RISE:
			return &"Rise"
		Mode.DYING, Mode.DEAD:
			return &"Death"
	if _spell_left > 0.0 or _north_rift.get_seal_progress() > 0.0 or _south_rift.get_seal_progress() > 0.0:
		return &"Cast"
	return super._action_animation()


func _in_sanctuary() -> bool:
	return _lina.global_position.z >= SANCTUARY_EDGE


func _on_aiming_changed(aiming: bool) -> void:
	super._on_aiming_changed(aiming)
	_slice_hud.set_aiming(aiming)


func _release_controls() -> void:
	super._release_controls()
	_north_rift.update_seal(false, false)
	_south_rift.update_seal(false, false)
	_slice_hud.set_interaction("", 0.0)


func _camp_interaction() -> Node3D:
	var limit: float = INTERACTION_RADIUS * INTERACTION_RADIUS
	var altar_distance: float = _lina.global_position.distance_squared_to(_altar.global_position)
	var hunter_distance: float = _lina.global_position.distance_squared_to(_hunter.global_position)
	if altar_distance <= limit and altar_distance < hunter_distance:
		return _altar
	return _hunter if hunter_distance <= limit else null


func _interact_in_camp() -> void:
	var interaction: Node3D = _camp_interaction()
	if interaction == _altar:
		_rest_at_altar()
	elif interaction == _hunter:
		var cue: String = "reminder" if _met_hunter else "meeting"
		if WorldState.sealed_rift_count() == 2:
			cue = "return" if _met_hunter else "first_return"
		_met_hunter = true
		_set_modal(Mode.DIALOGUE)
		_slice_hud.dialogue.start(DIALOGUE, cue)


func _rest_at_altar() -> void:
	_mode = Mode.REST
	_release_controls()
	_combat.interrupt_actions()
	_lina.stop_horizontal_motion()
	_set_lock(null)
	_lina.face_toward(_altar.global_position)
	await get_tree().create_timer(0.88, false).timeout
	if _mode != Mode.REST:
		return
	_checkpoint = $Checkpoint.global_position
	_life_magic.refill()
	_combat.reset()
	_reset_unsealed_rifts()
	_life_magic.pulse()
	_slice_hud.show_notice("Точка возрождения сохранена. Алтарь восстановил силы.")
	_mode = Mode.RISE
	await get_tree().create_timer(0.85, false).timeout
	if _mode == Mode.RISE:
		_mode = Mode.PLAY


func _reset_unsealed_rifts() -> void:
	_north_rift.reset_unsealed()
	_south_rift.reset_unsealed()


func _drop_shards(where: Vector3) -> void:
	_remove_shards()
	_lost_experience = StatsManager.take_unspent_experience()
	if _lost_experience.is_empty():
		return
	_shards = SHARD_SCENE.instantiate() as Node3D
	add_child(_shards)
	_shards.global_position = Vector3(where.x, maxf(0.0, where.y), where.z)


func _remove_shards() -> void:
	if is_instance_valid(_shards):
		_shards.queue_free()
		_shards = null
	_lost_experience.clear()


func _shards_in_reach() -> bool:
	return is_instance_valid(_shards) and _lina.global_position.distance_squared_to(_shards.global_position) <= SHARD_RADIUS * SHARD_RADIUS


func _recover_shards() -> void:
	StatsManager.restore_experience(_lost_experience)
	_remove_shards()
	_slice_hud.show_notice("Осколки Эфира возвращены.")


func _nearest_open_rift() -> RiftSpawner:
	if _north_rift.get_encounter_state() == RiftSpawner.State.CLOSED:
		return _south_rift if _south_rift.get_encounter_state() != RiftSpawner.State.CLOSED else null
	if _south_rift.get_encounter_state() == RiftSpawner.State.CLOSED:
		return _north_rift
	return _north_rift if _lina.global_position.distance_squared_to(_north_rift.global_position) < _lina.global_position.distance_squared_to(_south_rift.global_position) else _south_rift


func _refresh_objective(rift: RiftSpawner) -> void:
	var zone_name: String = "СТАБИЛЬНОСТЬ  /  ЛАГЕРЬ У РУИН" if _lina.in_sanctuary else "ХАОС  /  ПРОКЛЯТАЯ ЛОЩИНА"
	var objective: String
	if rift == null:
		objective = "Оба разлома запечатаны. Вернись к охотнику."
	elif _lina.in_sanctuary:
		objective = "Поговори с охотником или иди по тропе за арку." if not _met_hunter and WorldState.sealed_rift_count() == 0 else "Запечатай Малые Разломы в лощине.  %d / 2" % WorldState.sealed_rift_count()
	elif rift.get_encounter_state() == RiftSpawner.State.VULNERABLE:
		objective = "Подойди к разлому и удерживай E / A для Печати Баланса."
	elif rift.get_wave() == 0:
		objective = "Следуй к фиолетовому разлому.  %d / 2 запечатано" % WorldState.sealed_rift_count()
	elif rift.get_living_count() == 0:
		objective = "Следующая волна приближается."
	else:
		objective = "Волна %d / %d   ·   Приспешники: %d" % [rift.get_wave(), rift.wave_count, rift.get_living_count()]
	_slice_hud.set_objective(zone_name, objective)


func _refresh_interaction(rift: RiftSpawner) -> void:
	if not _controls_active():
		return
	var prompt: String = ""
	var progress: float = 0.0
	if _shards_in_reach():
		prompt = "[E / A]  Вернуть осколки Эфира"
	elif _lina.in_sanctuary:
		var interaction: Node3D = _camp_interaction()
		if interaction == _altar:
			prompt = "[E / A]  Отдохнуть у Алтаря"
		elif interaction == _hunter:
			prompt = "[E / A]  Поговорить с охотником"
	elif rift != null and rift.can_seal():
		prompt = "[Удерживай E / A]  Печать Баланса"
		progress = rift.get_seal_progress()
	_slice_hud.set_interaction(prompt, progress)


func _on_rift_closed(rift_id: String) -> void:
	if rift_id == _north_rift.rift_id:
		_north_healing.start()
	elif rift_id == _south_rift.rift_id:
		_south_healing.start()
	else:
		return
	var both_sealed: bool = WorldState.sealed_rift_count() == 2
	if both_sealed:
		_warm_landscape()
	var line: String = "Оба затихли. Пора узнать, держит ли охотник слово." if both_sealed else "Вот так. Ещё один шрам на мире затянули…"
	EventBus.lina_monologue(line)


func _warm_landscape() -> void:
	var environment: Environment = _world_environment.environment
	var sky: ProceduralSkyMaterial = environment.sky.sky_material as ProceduralSkyMaterial
	var warmth: Tween = create_tween().set_parallel(true).set_ignore_time_scale(true)
	warmth.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	warmth.tween_property(environment, "ambient_light_color", Color(0.91, 0.80, 0.57), RiftHealing.DURATION)
	warmth.tween_property(environment, "ambient_light_energy", 0.63, RiftHealing.DURATION)
	warmth.tween_property(environment, "fog_light_color", Color(0.31, 0.27, 0.28), RiftHealing.DURATION)
	warmth.tween_property(environment, "volumetric_fog_albedo", Color(0.75, 0.68, 0.63), RiftHealing.DURATION)
	warmth.tween_property(environment, "volumetric_fog_emission", Color(0.24, 0.20, 0.21), RiftHealing.DURATION)
	warmth.tween_property(sky, "sky_horizon_color", Color(0.40, 0.33, 0.32), RiftHealing.DURATION)
	warmth.tween_property(sky, "ground_horizon_color", Color(0.40, 0.33, 0.32), RiftHealing.DURATION)
	warmth.tween_property(_moon, "light_color", Color(1.0, 0.87, 0.71), RiftHealing.DURATION)


func _on_health_changed(current: float, maximum: float, damage: float) -> void:
	if current <= 0.0 and _mode in [Mode.PLAY, Mode.REST, Mode.RISE]:
		_mode = Mode.DYING
		_begin_death.call_deferred(_lina.global_position)
	elif current > 0.0 and current < maximum * 0.40 and current + damage >= maximum * 0.40:
		EventBus.lina_monologue("Ну давай, не подведи меня сейчас…")


func _on_monologue(line: String, voice: AudioStream, pan: float, warning: bool) -> void:
	if voice != null:
		_whisper.present(line, voice, pan, warning)
	else:
		_slice_hud.show_notice(line)


func _on_minion_windup(target: Node3D, threat_position: Vector3) -> void:
	var now: int = Time.get_ticks_msec()
	if target != _lina or not _controls_active() or now < _warning_ready_at:
		return
	var offset: Vector3 = threat_position - _lina.global_position
	offset.y = 0.0
	var toward_threat: Vector3 = offset.normalized()
	var forward: Vector3 = -_combat.facing.global_basis.z.normalized()
	if forward.dot(toward_threat) >= -0.20:
		return
	if _camera.is_position_in_frustum(threat_position + Vector3.UP * 0.64) or _camera.is_position_in_frustum(threat_position + Vector3.UP * 1.54):
		return
	var side: float = _camera.global_basis.x.dot(toward_threat)
	if absf(side) < 0.08:
		side = _camera.global_basis.x.dot(threat_position - _camera.global_position)
	var pan: float = 0.93 if side >= 0.0 else -0.93
	_warning_ready_at = now + WARNING_COOLDOWN_MS
	if _use_turn_warning:
		EventBus.lina_monologue("Обернись, Лина!", TURN_VOICE, pan, true)
	else:
		EventBus.lina_monologue("Сзади!", BEHIND_VOICE, pan, true)
	_use_turn_warning = not _use_turn_warning


func _on_rally_recovered() -> void:
	var now: int = Time.get_ticks_msec()
	if _mode == Mode.PLAY and now >= _rally_ready_at:
		_rally_ready_at = now + RALLY_COOLDOWN_MS
		EventBus.lina_monologue("Да... ещё!", RALLY_VOICE, -0.55)


func _on_riposte_whisper() -> void:
	if _mode == Mode.PLAY:
		_rally_ready_at = Time.get_ticks_msec() + RALLY_COOLDOWN_MS
		EventBus.lina_monologue("Чувствуешь нашу силу?", RIPOSTE_VOICE, 0.64)


func _check_story_whispers() -> void:
	if not _controls_active() or _whisper.is_active():
		return
	var radius_squared: float = STORY_WHISPER_RADIUS * STORY_WHISPER_RADIUS
	var lina_position: Vector3 = _lina.global_position
	if not _heard_altar and lina_position.distance_squared_to(_altar.global_position) <= radius_squared:
		_heard_altar = true
		EventBus.lina_monologue("Ты винишь себя, Лина… А что сказала бы мама?", ALTAR_VOICE, -0.44)
	elif not _heard_ruins and lina_position.distance_squared_to(_temple_threshold.global_position) <= radius_squared:
		_heard_ruins = true
		EventBus.lina_monologue("Мама молилась здесь. Ты всё ещё просишь у неё прощения?", RUINS_VOICE, 0.48)


func _begin_death(at: Vector3) -> void:
	_whisper.clear()
	_release_controls()
	_combat.interrupt_actions()
	_lina.stop_horizontal_motion()
	_set_lock(null)
	_drop_shards(at)
	await get_tree().create_timer(1.18, false).timeout
	_set_modal(Mode.DEAD)
	var detail: String = "Сгусток ждёт на месте гибели." if is_instance_valid(_shards) else "Алтарь вернёт Лину в долину."
	_slice_hud.show_result("Лина пала", detail, false, "Возродиться")


func _finish_dialogue() -> void:
	match WorldState.hunter_choice:
		WorldState.HunterChoice.TOOK_REWARD:
			_end_attempt("Лощина затихла", "Оба разлома запечатаны. У Лины %d серебряных." % WorldState.coins)
		WorldState.HunterChoice.CONFESSED:
			_end_attempt("Лощина затихла", "Оба разлома запечатаны. Искупление +%d." % WorldState.redemption)
		_:
			_resume()


func _pause() -> void:
	_set_modal(Mode.PAUSE)
	_slice_hud.show_result("Пауза", "Проклятая лощина", true)


func _end_attempt(title: String, detail: String) -> void:
	_set_modal(Mode.END)
	_slice_hud.show_result(title, detail)


func _set_modal(mode: Mode) -> void:
	_mode = mode
	_whisper.clear()
	_release_controls()
	_set_lock(null)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func _resume() -> void:
	_slice_hud.hide_result()
	_mode = Mode.PLAY
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _retry() -> void:
	if _mode == Mode.DEAD:
		_respawn()
		return
	_ambience.stop()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _respawn() -> void:
	_spawn.global_position = _checkpoint
	_reset()
	_lina.in_sanctuary = true
	_life_magic.refill()
	_reset_unsealed_rifts()
	_resume()
	_slice_hud.show_notice("Забери осколки на месте гибели." if is_instance_valid(_shards) else "Лина вернулась к Алтарю.")


func _return_to_menu() -> void:
	_ambience.stop()
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU)
