extends SceneTree

const MENU: String = "res://src/ui/main_menu.tscn"
const SLICE: String = "res://src/world/levels/outskirts_slice.tscn"
const CAPTURES: String = "res://.studioigor/captures/dark_souls_proto/"
const DUMMY: String = "res://src/enemies/training_dummy.tscn"
const MINION: String = "res://src/enemies/rift_minion.tscn"

var _failures: int = 0
var _level: Node3D
var _lina: CharacterBody3D
var _combat: Node3D
var _north: Node3D
var _south: Node3D
var _hud: CanvasLayer
var _stats: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.always_on_top = true
	root.focus_exited.connect(_restore_focus)
	root.grab_focus()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURES))
	await _menu()
	if _level == null:
		_report()
		return
	_lina = _level.get_node("Lina")
	_combat = _level.get_node("Combat")
	_north = _level.get_node("NorthRift")
	_south = _level.get_node("SouthRift")
	_hud = _level.get_node("OutskirtsHud")
	_stats = root.get_node("StatsManager")
	_check_input_actions()
	_check_environment()
	_check_clips()
	_check_mixamo()
	await _photo("02-camp")
	await _sticks_and_roll()
	await _bow_and_combo()
	await _parry_and_block()
	await _core_and_rally()
	await _focus_window()
	await _rest_seal_and_dialogue()
	await _death_and_recovery()
	await _ending_choice()
	_report()


func _check(ok: bool, what: String) -> void:
	print("OK   " if ok else "FAIL ", what)
	if not ok:
		_failures += 1


func _report() -> void:
	print("Всего несоответствий: ", _failures)
	quit(1 if _failures > 0 else 0)


func _button(button: JoyButton, pressed: bool) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _axis(axis: JoyAxis, value: float) -> void:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap(button: JoyButton) -> void:
	_button(button, true)
	await process_frame
	_button(button, false)
	await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _focus_window() -> void:
	if not root.has_focus():
		root.grab_focus()
		await _wait(0.20)


func _restore_focus() -> void:
	root.grab_focus.call_deferred()


func _photo(label: String) -> void:
	await _focus_window()
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_check(image.save_png(ProjectSettings.globalize_path(CAPTURES + label + ".png")) == OK, "кадр " + label)


func _menu() -> void:
	change_scene_to_file(MENU)
	await scene_changed
	await _wait(0.50)
	_check(root.gui_get_focus_owner().name == &"Start", "фокус на запуске в главном меню")
	await _tap(JOY_BUTTON_DPAD_DOWN)
	_check(root.gui_get_focus_owner().name == &"Quit", "крестовина ведёт к выходу")
	_axis(JOY_AXIS_LEFT_Y, -0.8)
	await _wait(0.12)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check(root.gui_get_focus_owner().name == &"Start", "левый стик возвращает фокус на запуск")
	await _photo("01-menu")
	await _tap(JOY_BUTTON_A)
	await _wait(0.95)
	if current_scene.scene_file_path == SLICE:
		_level = current_scene as Node3D
	_check(_level != null, "A подтверждает запуск и открывает окраины")


func _check_input_actions() -> void:
	var actions: Array[StringName] = [&"move_left", &"move_right", &"move_back", &"move_forward",
		&"look_left", &"look_right", &"look_up", &"look_down", &"lock_on", &"dodge",
		&"interact", &"heal", &"attack", &"block", &"aim", &"bow_shot", &"element_fire",
		&"element_ice", &"element_lightning", &"pause", &"ui_accept", &"ui_cancel",
		&"ui_left", &"ui_right", &"ui_up", &"ui_down"]
	var valid: bool = true
	for action: StringName in actions:
		var bound: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			bound = bound or event is InputEventJoypadButton or event is InputEventJoypadMotion
		valid = valid and bound and is_equal_approx(InputMap.action_get_deadzone(action), 0.2)
	_check(valid, "все игровые действия и меню имеют привязки геймпада и deadzone 0.2")


func _check_environment() -> void:
	var landscape: Node3D = _level.get_node("Landscape")
	var env: Environment = (landscape.get_node("Environment") as WorldEnvironment).environment
	_check(env.tonemap_mode == Environment.TONE_MAPPER_ACES and env.sdfgi_enabled and
		env.ssao_enabled and env.ssil_enabled and env.volumetric_fog_enabled, "ACES, SDFGI, SSAO, SSIL и объёмный туман активны")
	_check(landscape.get_node("Mist").get_child_count() == 3 and landscape.get_node("ScannedProps").get_child_count() >= 10, "туман в трёх низинах и фотограмметрия расставлены")
	for path: String in ["roots", "mossy_stone_wall", "dark_rock_02", "burned_ground_01"]:
		var material: StandardMaterial3D = load("res://assets/textures/pbr/%s/surface.tres" % path)
		_check(material.uv1_triplanar and material.normal_enabled and material.ao_enabled and
			material.albedo_texture != null and material.roughness_texture != null and
			material.normal_texture != null and material.ao_texture != null, "PBR " + path)


func _check_clips() -> void:
	var anim: AnimationPlayer = _lina.get_node("AnimationPlayer")
	for name: StringName in [&"Idle", &"Walk", &"Run", &"Dodge", &"Sword", &"SwordFollow", &"Block", &"Parry", &"Hit", &"Death", &"Cast", &"Rest", &"Aim", &"BowShot"]:
		var clip: Animation = anim.get_animation(name)
		var working: bool = clip != null and clip.get_track_count() >= 40
		if working:
			for index: int in clip.get_track_count():
				var path: NodePath = clip.track_get_path(index)
				if not str(path).begins_with("GeneralSkeleton:"):
					working = false
		_check(working, "ретаргет скелетного клипа " + str(name))
	var machine: AnimationNodeStateMachine = _lina.animations.tree_root
	var crossfades: bool = true
	for index: int in machine.get_transition_count():
		if machine.get_transition_from(index) != &"Start":
			crossfades = crossfades and is_equal_approx(machine.get_transition(index).xfade_time, 0.15)
	_check(crossfades, "переходы состояний 0.15 с")


func _check_mixamo() -> void:
	var skeleton: Skeleton3D = _lina.get_node("Visual/Model/GeneralSkeleton")
	var adapter: GDScript = load("res://src/player/lina_animation_source.gd")
	var clips: Dictionary = adapter.load_mixamo(skeleton, true)
	_check(clips.has(&"idle") and clips.has(&"run") and clips.has(&"shooting_arrow") and
		clips.has(&"stand_to_roll"), "существующие FBX Mixamo по-прежнему загружаются")
	var document: FBXDocument = FBXDocument.new()
	var state: FBXState = FBXState.new()
	var path: String = "res://assets/models/lina/animations/Run.fbx"
	if document.append_from_file(path, state) != OK:
		_check(false, "открытие FBX Mixamo без параметров импорта")
		return
	var imported: Node = document.generate_scene(state)
	var avatars: Array[Node] = imported.find_children("*", "Skeleton3D", true, false)
	var players: Array[Node] = imported.find_children("*", "AnimationPlayer", true, false)
	if avatars.is_empty() or players.is_empty():
		_check(false, "сырой FBX содержит скелет и клип")
		imported.free()
		return
	var anim: AnimationPlayer = players[0] as AnimationPlayer
	var raw: Animation = anim.get_animation(&"mixamo_com")
	var retargeted: Animation = adapter.adapt(raw, skeleton, avatars[0] as Skeleton3D)
	_check(retargeted.get_track_count() >= 40 and str(retargeted.track_get_path(0)).begins_with("GeneralSkeleton:"),
		"новый FBX Mixamo ретаргетируется без ручного BoneMap")
	imported.free()


func _sticks_and_roll() -> void:
	await _focus_window()
	var origin: Vector3 = _lina.global_position
	_axis(JOY_AXIS_LEFT_Y, -0.1)
	await _wait(0.20)
	_check(absf(_lina.global_position.z - origin.z) < 0.04, "ось до мёртвой зоны 0.20 не двигает Лину")
	_axis(JOY_AXIS_LEFT_Y, -0.49)
	await _wait(0.36)
	var pace: float = Vector2(_lina.velocity.x, _lina.velocity.z).length()
	_axis(JOY_AXIS_LEFT_Y, -1.0)
	await _wait(0.38)
	var run: float = Vector2(_lina.velocity.x, _lina.velocity.z).length()
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check(pace > 0.6 and run > pace * 1.65, "стик даёт ходьбу %.2f и бег %.2f м/с" % [pace, run])
	await _wait(0.20)
	await _focus_window()
	var look_before: Vector3 = _level._look
	_axis(JOY_AXIS_RIGHT_X, 0.7)
	_axis(JOY_AXIS_RIGHT_Y, -0.5)
	await _wait(0.30)
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	_axis(JOY_AXIS_RIGHT_Y, 0.0)
	var look_after: Vector3 = _level._look
	_check(absf(look_before.x - look_after.x) > 3.0 and absf(look_before.y - look_after.y) > 6.0, "правый стик вращает камеру по двум осям")
	await _focus_window()
	await _tap(JOY_BUTTON_B)
	await _wait(0.09)
	_check(_lina.is_dashing() and _lina.hurtbox.invulnerable and _lina.animations._requested == &"Dodge", "B запускает кувырок, скелетный клип и I-frames")
	await _wait(0.58)
	_check(not _lina.is_dashing() and not _lina.hurtbox.invulnerable, "I-frames завершаются")
	await _wait(0.70)
	await _tap(JOY_BUTTON_B)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.90)
	await _wait(0.12)
	_check(_lina.is_dashing() and is_equal_approx(Engine.time_scale, 0.25) and
		_lina.animations.weapons.bow.visible, "LT сразу открывает лук в кувырке и замедляет мир до ×0.25")
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.90)
	await _wait(0.25)
	_check(_lina.is_dashing() and not _combat.find_children("*", "CharacterBody3D", false, false).is_empty(),
		"RT выпускает стрелу до конца кувырка")
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await _wait(0.50)
	_check(is_equal_approx(Engine.time_scale, 0.25), "акробатическое замедление продолжается после выстрела")
	await _wait(0.45)
	_check(is_equal_approx(Engine.time_scale, 1.0), "через 1.2 с возвращается обычный масштаб времени")
	await _tap(JOY_BUTTON_START)
	_check(paused and _hud._veil.visible, "Start показывает паузу")
	await _tap(JOY_BUTTON_START)
	_check(not paused and not _hud._veil.visible, "Start закрывает паузу")
	_level._reset()
	await _wait(0.30)


func _training_target(where: Vector3) -> StaticBody3D:
	var dummy: StaticBody3D = (load(DUMMY) as PackedScene).instantiate() as StaticBody3D
	_level.add_child(dummy)
	dummy.global_position = where
	dummy.health.max_health = 200.0
	dummy.health.reset()
	return dummy


func _bow_and_combo() -> void:
	var base: Vector3 = _lina.global_position
	var near: StaticBody3D = _training_target(Vector3(base.x, 0, base.z - 4.2))
	var right: StaticBody3D = _training_target(Vector3(base.x + 3.1, 0, base.z - 4.7))
	await _tap(JOY_BUTTON_RIGHT_STICK)
	await _wait(0.50)
	_check(_level._target == near, "R3 захватывает ближайшую цель")
	_axis(JOY_AXIS_RIGHT_X, 0.95)
	await _wait(0.17)
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	_check(_level._target == right, "правый стик переключает захват вправо")
	await _tap(JOY_BUTTON_RIGHT_STICK)
	_check(not _level._lock_marker.visible, "повтор R3 снимает захват")
	await _tap(JOY_BUTTON_DPAD_LEFT)
	_check(_combat.element == 1, "D-pad влево выбирает огонь")
	await _tap(JOY_BUTTON_DPAD_UP)
	_check(_combat.element == 2, "D-pad вверх выбирает лёд")
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	_check(_combat.element == 3, "D-pad вправо выбирает молнию")
	await _tap(JOY_BUTTON_RIGHT_STICK)
	await _wait(0.28)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.88)
	await _wait(0.72)
	_check(Engine.time_scale < 0.7 and _lina.animations._requested == &"Aim" and _lina.animations.weapons.bow.visible,
		"LT поднимает лук и замедляет время")
	await _photo("03-bow")
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.9)
	await _wait(0.11)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	var arrows: Array[Node] = _combat.find_children("*", "CharacterBody3D", false, false)
	_check(not arrows.is_empty(), "RT во время LT выпускает стрелу")
	await _wait(0.48)
	await _tap(JOY_BUTTON_RIGHT_STICK)
	near.queue_free()
	right.queue_free()
	_level._reset()
	_combat.select_element(0)
	await _wait(0.28)
	base = _lina.global_position
	var target: StaticBody3D = _training_target(Vector3(base.x, 0, base.z - 1.48))
	await _wait(0.18)
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	await _wait(0.28)
	_check(_combat._sword_stage == 1 and _lina.animations.weapons.sword.visible, "RB запускает первый удар")
	_check(_lina.animations._requested == &"Sword", "первый удар использует отдельный клип")
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	await _wait(0.28)
	_check(_combat._sword_stage == 2 and _lina.animations._requested == &"SwordFollow", "повторный RB в окне запускает рубящий удар")
	await _photo("04-sword-follow")
	await _wait(0.25)
	var expected: float = 200.0 - _combat.tuning.sword_damage * (1.0 + _combat.tuning.follow_damage_factor)
	_check(is_equal_approx(target.health.current_health, expected), "оба удара нанесли урон %.2f / %.2f" % [target.health.current_health, expected])
	_check(is_equal_approx(_combat.stamina.current, 100.0 - _combat.tuning.sword_stamina_cost - _combat.tuning.follow_stamina_cost),
		"второй удар потратил отдельную повышенную стоимость")
	target.queue_free()
	await _wait(0.45)


func _parry_and_block() -> void:
	_level._reset()
	_lina.reset_at(Vector3(-11.0, 0.13, -9.2))
	var enemy: CharacterBody3D = (load(MINION) as PackedScene).instantiate() as CharacterBody3D
	enemy.target = _lina
	enemy.tuning = _north.tuning
	enemy.position = Vector3(7.1, 0.13, -13.2)
	_level.add_child(enemy)
	enemy.health.max_health = 140.0
	enemy.health.reset()
	var patrol_origin: Vector3 = enemy.global_position
	await _wait(1.20)
	_check(enemy._state == enemy.get_script().State.IDLE and enemy.global_position.distance_to(patrol_origin) > 0.30,
		"приспешник патрулирует вне радиуса агро")
	_lina.reset_at(enemy.global_position + Vector3(0, 0.06, 1.45))
	var deadline: int = Time.get_ticks_msec() + 3500
	while Time.get_ticks_msec() < deadline:
		await physics_frame
		if enemy._state == enemy.get_script().State.WINDUP and enemy._state_time < 0.15:
			break
	_check(enemy._state == enemy.get_script().State.WINDUP, "приспешник телеграфирует настоящий удар")
	_key(KEY_F, true)
	await _wait(0.24)
	_key(KEY_F, false)
	var hurtbox: HurtboxComponent = enemy.get_node("Hurtbox")
	_check(not hurtbox.riposte_ready and is_equal_approx(enemy.posture, 0.5) and
		enemy._state == enemy.get_script().State.STAGGERED and
		enemy._state_time > 1.30 and is_equal_approx(_lina.health.current_health, 100.0),
		"идеальное парирование на F даёт 50% концентрации и короткое оглушение")
	await _photo("05-parry")
	deadline = Time.get_ticks_msec() + 3200
	while Time.get_ticks_msec() < deadline:
		await physics_frame
		if enemy._state == enemy.get_script().State.WINDUP and enemy._state_time < 0.055:
			break
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.91)
	await _wait(0.17)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_check(hurtbox.riposte_ready and is_equal_approx(enemy.posture, 1.0) and enemy._state_time > 2.0
		and (enemy.get_node("PostureBreak") as AudioStreamPlayer3D).playing,
		"второе идеальное парирование на LT открывает глубокое оглушение со звоном")
	deadline = Time.get_ticks_msec() + 850
	while _lina.defense.parry_pose_left > 0.0 and Time.get_ticks_msec() < deadline:
		await physics_frame
	await process_frame
	var before: float = enemy.health.current_health
	_lina.health.take_damage(30.0)
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	deadline = Time.get_ticks_msec() + 950
	while Engine.time_scale >= 0.1 and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(Engine.time_scale < 0.1 and _level._shake_left > 0.0, "добивание запускает хитстоп и тряску")
	await _wait(0.18)
	_check(is_equal_approx(before - enemy.health.current_health, _combat.tuning.sword_damage * 3.0) and
		not hurtbox.riposte_ready and enemy.posture == 0.0, "добивание наносит тройной урон и закрывает окно")
	_check(_lina.health.current_health == 100.0 and _lina.health.recoverable_health == 0.0 and not _hud._rally.visible,
		"попадание мечом возвращает доступные HP и убирает подсветку")
	enemy.queue_free()
	await _wait(0.35)
	_level._reset()
	_button(JOY_BUTTON_LEFT_SHOULDER, true)
	await _wait(0.29)
	_check(_lina.blocking and _lina.animations._requested == &"Block", "удержание LB оставляет обычный блок")
	var source: Vector3 = _lina.global_position + Vector3.FORWARD
	var blocked: int = _lina.defense.receive_strike(18.0, source)
	_check(blocked == _lina.defense.get_script().Strike.BLOCKED and is_equal_approx(_lina.health.current_health, 95.5)
		and is_equal_approx(_combat.stamina.current, 86.5), "блок снижает урон и тратит выносливость")
	_button(JOY_BUTTON_LEFT_SHOULDER, false)
	await _tap(JOY_BUTTON_X)
	_check(_level._life_magic.charges == 2 and is_equal_approx(_lina.health.current_health, 100.0), "X лечит и расходует один заряд")
	await _wait(0.65)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.91)
	await _wait(0.09)
	var fast_guard: int = _lina.defense.receive_strike(18.0, _lina.global_position + Vector3.FORWARD)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_check(fast_guard == _lina.defense.get_script().Strike.PARRIED, "первые 0.22 с LT также открывают парирование")
	await _wait(0.48)


func _launch_test_arrow(from: Vector3, to: Vector3) -> void:
	var arrow: CharacterBody3D = (load("res://src/player/lina_arrow.tscn") as PackedScene).instantiate()
	_combat.add_child(arrow)
	arrow.launch(from, (to - from).normalized(), _combat.tuning, CombatElements.Charge.NONE, _lina)


func _core_and_rally() -> void:
	_level._reset()
	await _wait(0.23)
	var enemy: CharacterBody3D = (load(MINION) as PackedScene).instantiate()
	enemy.position = _lina.global_position + Vector3.FORWARD * 2.65
	enemy.rotation.y = PI
	_level.add_child(enemy)
	enemy.set_physics_process(false)
	var core: Node3D = enemy.get_node("Visual/AetherCore")
	var xp_gained: Array[float] = [0.0]
	var track_xp: Callable = func(skill: String, amount: float) -> void:
		if skill == "archery":
			xp_gained[0] += amount
	var bus: Node = root.get_node("EventBus")
	bus.skill_xp_gained.connect(track_xp)
	_lina.health.take_damage(30.0)
	await _wait(0.03)
	_check(_hud._rally.visible and is_equal_approx(_hud._rally.anchor_left, 0.7) and
		is_equal_approx(_hud._rally.anchor_right, 1.0), "HUD выделяет недостающие 30 HP для ралли")
	await _photo("11-rally-core")
	enemy._state = enemy.get_script().State.WINDUP
	enemy.get_node("Telegraph").show()
	var point: Vector3 = core.global_position
	var camera: Camera3D = _level.get_node("Camera")
	await physics_frame
	camera.look_at(point)
	_combat._fire_arrow()
	await _wait(0.25)
	_check(is_equal_approx(enemy.health.max_health - enemy.health.current_health, _combat.tuning.arrow_damage * 2.5)
		and is_equal_approx(enemy.posture, 0.5) and enemy._state == enemy.get_script().State.STAGGERED and
		not enemy.get_node("Telegraph").visible, "ядро получает ×2.5 урона, добавляет 50% концентрации и сбивает замах")
	_check(is_equal_approx(xp_gained[0], _combat.tuning.archery_xp * 2.0), "ядро даёт двойной опыт archery")
	_check(is_equal_approx(_lina.health.current_health, 97.5) and
		is_equal_approx(_lina.health.recoverable_health, 2.5) and _level._life_magic._particles.emitting,
		"выстрел в упор мгновенно возвращает часть HP и вызывает искры")
	bus.skill_xp_gained.disconnect(track_xp)
	enemy.position += Vector3.FORWARD * 1.7
	enemy.health.reset()
	enemy._state = enemy.get_script().State.WINDUP
	await physics_frame
	point = enemy.global_position + Vector3.UP * 0.75
	_launch_test_arrow(point + Vector3.BACK * 2.1, point)
	await _wait(0.25)
	_check(is_equal_approx(enemy.health.max_health - enemy.health.current_health, _combat.tuning.arrow_damage)
		and is_equal_approx(enemy.posture, 0.85) and enemy._state == enemy.get_script().State.WINDUP,
		"стрела в корпус на замахе наносит обычный урон и добавляет 35% концентрации")
	_check(is_equal_approx(_lina.health.current_health, 97.5), "дальний выстрел не возвращает HP")
	var wall: StaticBody3D = StaticBody3D.new()
	var collider: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.2, 1.2, 0.22)
	collider.shape = box
	wall.add_child(collider)
	_level.add_child(wall)
	point = core.global_position
	wall.global_position = point + Vector3.BACK * 0.75
	await physics_frame
	var hp_before: float = enemy.health.current_health
	_launch_test_arrow(point + Vector3.BACK * 2.1, point)
	await _wait(0.25)
	_check(enemy.health.current_health == hp_before, "стена перекрывает попадание в ядро")
	wall.queue_free()
	enemy.set_physics_process(true)
	_lina.health.reset()
	_lina.health.take_damage(10.0)
	await _wait(0.45)
	_lina.health.take_damage(20.0)
	await _wait(1.80)
	_check(is_equal_approx(enemy.posture, 0.85), "концентрация держится три секунды без попаданий")
	await _wait(1.37)
	_check(enemy.posture > 0.0 and enemy.posture < 0.85, "после трёх секунд концентрация плавно спадает")
	enemy.queue_free()
	_check(is_equal_approx(_lina.health.recoverable_health, 20.0), "каждая порция ралли истекает через свои 3.5 с")
	await _wait(0.45)
	_check(not _hud._rally.visible and _lina.health.recoverable_health == 0.0, "подсветка ралли исчезает по истечении окна")
	_level._reset()


func _finish_wave(rift: Node3D) -> void:
	for member: Node in rift.get_node("Minions").get_children():
		var minion: CharacterBody3D = member as CharacterBody3D
		minion.health.take_damage(minion.health.current_health)


func _rest_seal_and_dialogue() -> void:
	_south._spawn_wave()
	_finish_wave(_south)
	await _wait(0.35)
	_south._spawn_wave()
	_finish_wave(_south)
	_lina.reset_at(_south.global_position + Vector3(0, 0.10, 1.4))
	await _wait(0.35)
	_check(_south.can_seal(), "две волны открывают возможность печати")
	_button(JOY_BUTTON_A, true)
	await _wait(1.78)
	_button(JOY_BUTTON_A, false)
	_check(_south.get_encounter_state() == _south.get_script().State.CLOSED, "удержание A запечатывает разлом")
	await _photo("06-closed-rift")
	_north._spawn_wave()
	var minions: Node = _north.get_node("Minions")
	var victim: CharacterBody3D = minions.get_child(0) as CharacterBody3D
	victim.health.take_damage(victim.health.current_health)
	_lina.health.take_damage(25)
	_combat.stamina.spend(26)
	var altar: Node3D = _level.get_node("Landscape/Altar")
	_lina.reset_at(altar.global_position + Vector3(0.95, 0.1, 1.13))
	await _wait(0.35)
	await _tap(JOY_BUTTON_A)
	await _wait(0.69)
	_check(_lina.animations._requested == &"Rest", "A у Алтаря запускает сцену отдыха")
	await _photo("07-altar-rest")
	await _wait(1.10)
	var checkpoint: Marker3D = _level.get_node("Checkpoint")
	_check(is_equal_approx(_lina.health.current_health, 100.0) and is_equal_approx(_combat.stamina.current, 100.0)
		and _level._life_magic.charges == 3 and _level._checkpoint.is_equal_approx(checkpoint.global_position),
		"Алтарь восстанавливает HP, выносливость и три заряда, записывает точку возрождения")
	_check(_north.get_wave() == 0 and _south.get_encounter_state() == _south.get_script().State.CLOSED,
		"отдых сбрасывает активные волны и сохраняет запечатанный разлом")
	_lina.reset_at(_north.global_position + Vector3(0, 0.10, 7.0))
	await _wait(1.76)
	_check(_north.get_living_count() == 2, "рядовые приспешники появились вновь")
	var hunter: Node3D = _level.get_node("Landscape/Hunter")
	_lina.reset_at(hunter.global_position + Vector3(-0.9, 0.10, 1.1))
	await _wait(0.25)
	await _tap(JOY_BUTTON_A)
	await _wait(0.35)
	_check(_hud.dialogue.visible and root.gui_get_focus_owner() != null, "A открывает диалог с фокусом")
	for _i: int in range(7):
		if not _hud.dialogue.visible:
			break
		await _tap(JOY_BUTTON_A)
		await _wait(0.08)
	_check(not _hud.dialogue.visible and not paused, "реплики проходятся кнопкой A")


func _death_and_recovery() -> void:
	_stats.take_unspent_experience()
	_stats.add_xp("archery", 27.0)
	_stats.add_xp("balance_magic", 11.0)
	var expected: float = _stats.unspent_total()
	var fallen: Vector3 = Vector3(-1.4, 0.11, -15.6)
	_lina.reset_at(fallen)
	await _wait(0.25)
	_lina.health.take_damage(1000.0)
	await _wait(0.65)
	_check(_lina.animations._requested == &"Death", "смерть запускает скелетную анимацию")
	await _wait(0.75)
	_check(paused and is_instance_valid(_level._shards) and is_zero_approx(_stats.unspent_total()) and
		_level._shards.global_position.distance_to(fallen) < 0.3, "опыт выпал в месте гибели")
	await _photo("08-death")
	await _tap(JOY_BUTTON_A)
	await _wait(0.40)
	_check(not paused and is_equal_approx(_lina.health.current_health, 100.0) and
		_lina.global_position.distance_to(_level._checkpoint) < 0.22, "A возрождает у Алтаря в той же сцене")
	_check(_south.get_encounter_state() == _south.get_script().State.CLOSED, "печать сохраняется после смерти")
	_lina.reset_at(fallen + Vector3(0.8, 0, 0.1))
	await _wait(0.42)
	await _photo("09-recoverable-shards")
	await _tap(JOY_BUTTON_A)
	print("Подбор: XP=", _stats.unspent_total(), " ожидается=", expected, " сгусток=", is_instance_valid(_level._shards),
		" управление=", _level._controls_active(), " фокус=", root.has_focus())
	_check(not is_instance_valid(_level._shards) and is_equal_approx(_stats.unspent_total(), expected), "A возвращает весь потерянный нераспределённый опыт")
	_stats.take_unspent_experience()
	_stats.add_xp("endurance", 17.0)
	_lina.health.take_damage(1000.0)
	await _wait(1.42)
	var abandoned: Node3D = _level._shards
	await _tap(JOY_BUTTON_A)
	await _wait(0.30)
	_lina.reset_at(fallen + Vector3(2.7, 0, -1.0))
	await _wait(0.12)
	_lina.health.take_damage(1000.0)
	await _wait(1.40)
	_check(not is_instance_valid(abandoned) and not is_instance_valid(_level._shards) and
		is_zero_approx(_stats.unspent_total()), "вторая смерть до подбора уничтожает предыдущий сгусток")



func _ending_choice() -> void:
	await _tap(JOY_BUTTON_A)
	await _wait(0.35)
	_north.reset_unsealed()
	_north._spawn_wave()
	_finish_wave(_north)
	await _wait(0.40)
	_north._spawn_wave()
	_finish_wave(_north)
	_lina.reset_at(_north.global_position + Vector3(0, 0.10, 1.4))
	await _wait(0.27)
	_button(JOY_BUTTON_A, true)
	await _wait(1.76)
	_button(JOY_BUTTON_A, false)
	var world: Node = root.get_node("WorldState")
	_check(world.sealed_rift_count() == 2, "обе печати сохраняются в одной попытке")
	var hunter: Node3D = _level.get_node("Landscape/Hunter")
	_lina.reset_at(hunter.global_position + Vector3(-0.9, 0.10, 1.1))
	await _wait(0.26)
	await _tap(JOY_BUTTON_A)
	await _wait(0.24)
	var options: Container = _hud.dialogue.get_node("Content/Options")
	for _i: int in range(7):
		if options.get_child_count() >= 2 or not _hud.dialogue.visible:
			break
		await _tap(JOY_BUTTON_A)
		await _wait(0.10)
	if options.get_child_count() < 2:
		_check(false, "открыты два ответа финального диалога")
		return
	var first: Button = options.get_child(0)
	var second: Button = options.get_child(1)
	_check(root.gui_get_focus_owner() == first, "фокус открыт на первом варианте ответа")
	await _tap(JOY_BUTTON_DPAD_DOWN)
	_check(root.gui_get_focus_owner() == second, "крестовина переключает вариант ответа Dialogue Manager")
	await _photo("10-dialogue-choice")
	await _tap(JOY_BUTTON_A)
	for _i: int in range(8):
		await _wait(0.10)
		if not _hud.dialogue.visible:
			break
		await _tap(JOY_BUTTON_A)
	_check(world.hunter_choice != 0 and _hud._veil.visible and _hud._result_title.text == "Лощина затихла",
		"A подтверждает ответ и завершает игровую петлю")
