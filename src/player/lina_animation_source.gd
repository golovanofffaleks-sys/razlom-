extends RefCounted

const DIRECTORY: String = "res://assets/models/lina/animations/"
const MIXAMO_MAP: BoneMap = preload("res://assets/models/lina/animations/mixamo_humanoid.tres")
const SHIPPED: Array[String] = ["Idle", "Run", "Stand To Roll", "Shooting Arrow"]


static func load_mixamo(skeleton: Skeleton3D, use_shipped: bool) -> Dictionary[StringName, Animation]:
	var clips: Dictionary[StringName, Animation] = {}
	for file: String in ResourceLoader.list_directory(DIRECTORY):
		if file.get_extension().to_lower() != "fbx":
			continue
		var base: String = file.get_basename()
		if not use_shipped and SHIPPED.has(base):
			continue
		var source: Resource = load(DIRECTORY + file)
		if source is AnimationLibrary:
			for clip_name: StringName in source.get_animation_list():
				var clip: Animation = adapt(source.get_animation(clip_name), skeleton)
				_register(clips, base, clip_name, clip)
		elif source is PackedScene:
			_read_mixamo_scene(source, skeleton, base, clips)
	return clips


static func adapt(original: Animation, skeleton: Skeleton3D, source: Skeleton3D = null) -> Animation:
	var clip: Animation = original.duplicate()
	var target_hips: Vector3 = skeleton.get_bone_rest(skeleton.find_bone(&"Hips")).origin / skeleton.motion_scale
	for track: int in range(clip.get_track_count() - 1, -1, -1):
		var path: NodePath = clip.track_get_path(track)
		var old: StringName = path.get_subname(0) if path.get_subname_count() == 1 else &""
		var bone: StringName = _resolve_bone(old, skeleton)
		var kind: Animation.TrackType = clip.track_get_type(track)
		if bone == &"" or (kind != Animation.TYPE_ROTATION_3D and (kind != Animation.TYPE_POSITION_3D or bone != &"Hips")):
			clip.remove_track(track)
			continue
		clip.track_set_path(track, NodePath("GeneralSkeleton:" + String(bone)))
		var source_id: int = source.find_bone(old) if source != null and old != bone else -1
		if kind == Animation.TYPE_POSITION_3D:
			for key: int in clip.track_get_key_count(track):
				var pos: Vector3 = clip.track_get_key_value(track, key)
				if source_id >= 0:
					var rest: Vector3 = source.get_bone_rest(source_id).origin
					pos.y = target_hips.y + (pos.y - rest.y) / maxf(absf(rest.y), 0.01)
				# Перемещение по плоскости принадлежит контроллеру.
				clip.track_set_key_value(track, key, Vector3(target_hips.x, pos.y, target_hips.z))
		elif source_id >= 0:
			_repose_rotation(clip, track, source, source_id, skeleton, skeleton.find_bone(bone))
	return clip


static func _resolve_bone(original: StringName, skeleton: Skeleton3D) -> StringName:
	if original == &"":
		return &""
	if skeleton.find_bone(original) >= 0:
		return original
	var text: String = String(original).to_lower().replace(":", "_").replace(" ", "_")
	var unprefixed: String = text.trim_prefix("mixamorig")
	while not unprefixed.is_empty() and unprefixed[0].is_valid_int():
		unprefixed = unprefixed.substr(1)
	var name: StringName = StringName(unprefixed.trim_prefix("_"))
	for index: int in MIXAMO_MAP.profile.get_bone_size():
		var canonical: StringName = MIXAMO_MAP.profile.get_bone_name(index)
		var alias: String = String(MIXAMO_MAP.get_skeleton_bone_name(canonical)).to_lower().trim_prefix("mixamorig_")
		if alias != "" and name == StringName(alias) and skeleton.find_bone(canonical) >= 0:
			return canonical
	return &""


static func _repose_rotation(clip: Animation, track: int, source: Skeleton3D, source_id: int,
		skeleton: Skeleton3D, destination_id: int) -> void:
	var source_local: Quaternion = source.get_bone_rest(source_id).basis.orthonormalized().get_rotation_quaternion()
	var destination_local: Quaternion = skeleton.get_bone_rest(destination_id).basis.orthonormalized().get_rotation_quaternion()
	var source_global: Quaternion = source.get_bone_global_rest(source_id).basis.orthonormalized().get_rotation_quaternion()
	var destination_global: Quaternion = skeleton.get_bone_global_rest(destination_id).basis.orthonormalized().get_rotation_quaternion()
	var offset: Quaternion = destination_global.inverse() * source_global
	for key: int in clip.track_get_key_count(track):
		var rotation: Quaternion = clip.track_get_key_value(track, key)
		var relative: Quaternion = source_local.inverse() * rotation
		clip.track_set_key_value(track, key, (destination_local * offset * relative * offset.inverse()).normalized())


static func _read_mixamo_scene(source: PackedScene, skeleton: Skeleton3D, base: String,
		clips: Dictionary[StringName, Animation]) -> void:
	var imported: Node = source.instantiate()
	var skeletons: Array[Node] = imported.find_children("*", "Skeleton3D", true, false)
	var players: Array[Node] = imported.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty() and not skeletons.is_empty():
		var player: AnimationPlayer = players[0] as AnimationPlayer
		for label: StringName in player.get_animation_list():
			if label != &"RESET":
				var clip: Animation = adapt(player.get_animation(label), skeleton, skeletons[0] as Skeleton3D)
				_register(clips, base, label, clip)
	imported.free()


static func _register(clips: Dictionary[StringName, Animation], base: String, label: StringName, clip: Animation) -> void:
	if clip.get_track_count() == 0:
		return
	var suffix: String = String(label).get_file().to_snake_case()
	var alias: StringName = StringName(base.to_snake_case())
	if not clips.has(alias):
		clips[alias] = clip
	if label != &"mixamo_com":
		clips[StringName(suffix)] = clip
