class_name LinaAnimations
extends AnimationTree

const UAL_1: AnimationLibrary = preload("res://assets/models/lina/animations/pack/ual_1.glb")
const UAL_2: AnimationLibrary = preload("res://assets/models/lina/animations/pack/ual_2.glb")
const CLIP_SOURCE: GDScript = preload("res://src/player/lina_animation_source.gd")
const LOCOMOTION: StringName = &"Locomotion"

@export var prefer_mixamo_overrides: bool = false

var hitstop_active: bool = false
var roll_bow_visible: bool = false
var _library: AnimationLibrary = AnimationLibrary.new()
var _requested: StringName = LOCOMOTION
var _playback: AnimationNodeStateMachinePlayback
var _overrides: Dictionary[StringName, Animation] = {}

@onready var _player: AnimationPlayer = get_node(anim_player)
@onready var _skeleton: Skeleton3D = get_node(root_node).get_node("GeneralSkeleton")
@onready var weapons: LinaWeapons = $"../Visual/Weapons"
@onready var _right_hand: int = _skeleton.find_bone(&"RightHand")


func _ready() -> void:
	_overrides = CLIP_SOURCE.load_mixamo(_skeleton, prefer_mixamo_overrides)
	_player.add_animation_library(&"", _library)
	_add_loop(&"Idle", _clip(UAL_1, &"Idle", [&"idle"]))
	_add_loop(&"Walk", _clip(UAL_1, &"Walk", [&"walk", &"walking"]))
	_add_loop(&"Run", _clip(UAL_1, &"Jog_Fwd", [&"run", &"running"]))
	_add_loop(&"RestLoop", _clip(UAL_1, &"GroundSit_Idle", [&"ground_sit_idle"]))
	_library.add_animation(&"Rest", _fit(_clip(UAL_1, &"GroundSit_Enter", [&"rest", &"sit_down"]), 1.0))
	_library.add_animation(&"Rise", _fit(_clip(UAL_1, &"GroundSit_Exit", [&"rise", &"stand_up"]), 0.85))
	_library.add_animation(&"Cast", _fit(_clip(UAL_1, &"Spell_Simple_Shoot", [&"cast_spell", &"cast"]), 0.50))
	_library.add_animation(&"Hit", _fit(_clip(UAL_1, &"Hit_Chest", [&"hit_react", &"hit"]), 0.34))
	_library.add_animation(&"Death", _fit(_clip(UAL_1, &"Death01", [&"die", &"death"]), 1.18))
	_library.add_animation(&"Parry", _fit(_clip(UAL_2, &"Shield_OneShot", [&"parry"]), 0.38))
	var custom: AnimationLibrary = AnimationLibrary.new()
	for alias: StringName in _overrides:
		custom.add_animation(alias, _overrides[alias])
	if not custom.get_animation_list().is_empty():
		_player.add_animation_library(&"mixamo", custom)
	configure_actions(LinaCombatTuning.new())
	callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_playback = get("parameters/playback")
	active = true
	reset_pose()


func configure_actions(tuning: LinaCombatTuning) -> void:
	var notch: Animation = _clip(UAL_2, &"Bow_Notch")
	var bow_ready: Animation = _clip(UAL_2, &"Bow_Aim_Neutral", [&"bow_aim", &"aim"])
	var mixamo_bow: Animation = _overrides.get(&"shooting_arrow")
	var draw: Animation = _slice(notch, 1.10, notch.length, tuning.bow_draw_time)
	var shot: Animation = _fit(_clip(UAL_2, &"Bow_Shoot", [&"bow_shoot", &"bow_shot"]), tuning.bow_cooldown)
	if mixamo_bow != null and mixamo_bow.length > 4.72:
		draw = _slice(mixamo_bow, 1.90, 3.76, tuning.bow_draw_time)
		shot = _slice(mixamo_bow, 3.76, 4.72, tuning.bow_cooldown)
	elif _overrides.has(&"bow_aim") or _overrides.has(&"aim"):
		draw = _fit(bow_ready, tuning.bow_draw_time)
	else:
		draw = _join(draw, _slice(bow_ready, 0.0, 0.15, 0.08))
	_replace_animation(&"Aim", draw)
	_replace_animation(&"BowShot", shot)
	_replace_animation(&"Dodge", _fit(_clip(UAL_1, &"Roll", [&"roll", &"dodge", &"stand_to_roll"]), tuning.dodge_duration))
	_replace_animation(&"Sword", _sword(&"Sword_Regular_A", &"Sword_Regular_A_Rec",
		[&"sword_attack_1", &"sword_attack", &"sword"], tuning.sword_windup + tuning.sword_active, tuning.sword_recovery))
	_replace_animation(&"SwordFollow", _sword(&"Sword_Regular_B", &"Sword_Regular_B_Rec",
		[&"sword_attack_2", &"sword_follow"], tuning.sword_windup * tuning.follow_windup_factor + tuning.sword_active, tuning.sword_recovery))
	_replace_animation(&"Block", _fit(_clip(UAL_2, &"Sword_Block", [&"block", &"sword_block"]), 0.40))


func play_action(state: StringName) -> void:
	if state != _requested:
		_requested = state
		_playback.travel(state)


func reset_pose() -> void:
	roll_bow_visible = false
	_requested = LOCOMOTION
	set("parameters/Locomotion/blend_position", 0.0)
	_playback.start(LOCOMOTION)
	advance(0.0)
	weapons.show_action(_requested)


func update_locomotion(speed_ratio: float) -> void:
	set("parameters/Locomotion/blend_position", clampf(speed_ratio, 0.0, 1.0))


func sword_grip() -> Vector3:
	return _skeleton.to_global(_skeleton.get_bone_global_pose(_right_hand).origin)


func _process(delta: float) -> void:
	advance(delta if hitstop_active else delta / Engine.time_scale)
	weapons.show_action(_requested, roll_bow_visible)


func _clip(source: AnimationLibrary, clip_id: StringName, aliases: Array[StringName] = []) -> Animation:
	for alias: StringName in aliases:
		if _overrides.has(alias):
			return _overrides[alias]
	return CLIP_SOURCE.adapt(source.get_animation(clip_id), _skeleton)


func _sword(clip_id: StringName, recover: StringName, aliases: Array[StringName], swing: float, recovery: float) -> Animation:
	for alias: StringName in aliases:
		if _overrides.has(alias):
			return _fit(_overrides[alias], swing + recovery)
	return _join(_fit(_clip(UAL_2, clip_id), swing), _fit(_clip(UAL_2, recover), recovery))


func _add_loop(clip_id: StringName, source: Animation) -> void:
	var clip: Animation = source.duplicate()
	clip.loop_mode = Animation.LOOP_LINEAR
	_library.add_animation(clip_id, clip)


func _fit(source: Animation, duration: float) -> Animation:
	return _slice(source, 0.0, source.length, duration)


func _slice(source: Animation, start: float, finish: float, duration: float) -> Animation:
	var clip: Animation = Animation.new()
	clip.length = duration
	for i: int in source.get_track_count():
		var kind: Animation.TrackType = source.track_get_type(i)
		var track: int = clip.add_track(kind)
		clip.track_set_path(track, source.track_get_path(i))
		clip.track_insert_key(track, 0.0, _sample(source, i, start))
		for key: int in source.track_get_key_count(i):
			var time: float = source.track_get_key_time(i, key)
			if time > start and time < finish:
				clip.track_insert_key(track, remap(time, start, finish, 0.0, duration), source.track_get_key_value(i, key))
		clip.track_insert_key(track, duration, _sample(source, i, finish))
	return clip


func _join(first: Animation, second: Animation) -> Animation:
	var clip: Animation = first.duplicate()
	clip.length = first.length + second.length
	for source_track: int in second.get_track_count():
		var path: NodePath = second.track_get_path(source_track)
		var kind: Animation.TrackType = second.track_get_type(source_track)
		var track: int = clip.find_track(path, kind)
		if track == -1:
			track = clip.add_track(kind)
			clip.track_set_path(track, path)
		for key: int in second.track_get_key_count(source_track):
			var time: float = first.length + second.track_get_key_time(source_track, key)
			clip.track_insert_key(track, time, second.track_get_key_value(source_track, key))
	return clip


func _sample(clip: Animation, track: int, time: float) -> Variant:
	if clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
		return clip.position_track_interpolate(track, time)
	return clip.rotation_track_interpolate(track, time)


func _replace_animation(id: StringName, clip: Animation) -> void:
	if _library.has_animation(id):
		_library.remove_animation(id)
	_library.add_animation(id, clip)
