extends Node

const XP_PER_LEVEL: float = 100.0


class SkillProgress:
	var level: int = 1
	var xp: float = 0.0


var _skills: Dictionary[String, SkillProgress] = {
	"archery": SkillProgress.new(),
	"agility": SkillProgress.new(),
	"endurance": SkillProgress.new(),
	"balance_magic": SkillProgress.new(),
}


func add_xp(skill_name: String, amount: float) -> void:
	var progress: SkillProgress = _skills.get(skill_name)
	if progress == null or not is_finite(amount) or amount <= 0.0:
		return

	progress.xp += amount
	EventBus.skill_xp_gained.emit(skill_name, amount)

	var xp_required: float = XP_PER_LEVEL * float(progress.level)
	while progress.xp >= xp_required:
		progress.xp -= xp_required
		progress.level += 1
		EventBus.skill_leveled_up.emit(skill_name, progress.level)
		xp_required = XP_PER_LEVEL * float(progress.level)
	EventBus.unspent_xp_changed.emit(unspent_total())


func unspent_total() -> float:
	var total: float = 0.0
	for progress: SkillProgress in _skills.values():
		total += progress.xp
	return total


func take_unspent_experience() -> Dictionary[String, float]:
	var removed: Dictionary[String, float] = {}
	for skill: String in _skills:
		var progress: SkillProgress = _skills[skill]
		if progress.xp > 0.0:
			removed[skill] = progress.xp
			progress.xp = 0.0
	EventBus.unspent_xp_changed.emit(0.0)
	return removed


func restore_experience(shards: Dictionary[String, float]) -> void:
	for skill: String in shards:
		add_xp(skill, shards[skill])


func get_skill_level(skill_name: String) -> int:
	var progress: SkillProgress = _skills.get(skill_name)
	return progress.level if progress != null else 0


func get_skill_xp(skill_name: String) -> float:
	var progress: SkillProgress = _skills.get(skill_name)
	return progress.xp if progress != null else 0.0
