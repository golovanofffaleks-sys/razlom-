extends Node

@warning_ignore("unused_signal")
signal skill_xp_gained(skill_name: String, amount: float)
@warning_ignore("unused_signal")
signal skill_leveled_up(skill_name: String, new_level: int)
@warning_ignore("unused_signal")
signal rift_closed(rift_id: String)
@warning_ignore("unused_signal")
signal lina_monologue_triggered(text: String, voice: AudioStream, pan: float, warning: bool)
@warning_ignore("unused_signal")
signal minion_windup_started(target: Node3D, position: Vector3)
@warning_ignore("unused_signal")
signal world_state_changed
@warning_ignore("unused_signal")
signal unspent_xp_changed(total: float)


func lina_monologue(text: String, voice: AudioStream = null, pan: float = 0.0, warning: bool = false) -> void:
	lina_monologue_triggered.emit(text, voice, pan, warning)
