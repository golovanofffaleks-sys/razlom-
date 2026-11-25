extends Node

enum HunterChoice { NONE, TOOK_REWARD, CONFESSED }

const NORTH_RIFT: String = "outskirts_north"
const SOUTH_RIFT: String = "outskirts_south"
const HUNTER_REWARD: int = 30

var redemption: int = 0
var coins: int = 0
var hunter_choice: HunterChoice = HunterChoice.NONE
var _sealed_rifts: Dictionary[String, bool] = {}


func _ready() -> void:
	EventBus.rift_closed.connect(_on_rift_closed)


func begin_outskirts() -> void:
	_sealed_rifts.clear()
	redemption = 0
	coins = 0
	hunter_choice = HunterChoice.NONE


func sealed_rift_count() -> int:
	return _sealed_rifts.size()


func take_hunter_reward() -> void:
	if not _can_resolve_hunter():
		return
	coins += HUNTER_REWARD
	hunter_choice = HunterChoice.TOOK_REWARD
	EventBus.world_state_changed.emit()


func confess_to_hunter() -> void:
	if not _can_resolve_hunter():
		return
	redemption += 1
	hunter_choice = HunterChoice.CONFESSED
	EventBus.world_state_changed.emit()


func _can_resolve_hunter() -> bool:
	return sealed_rift_count() == 2 and hunter_choice == HunterChoice.NONE


func _on_rift_closed(rift_id: String) -> void:
	if (rift_id == NORTH_RIFT or rift_id == SOUTH_RIFT) and not _sealed_rifts.has(rift_id):
		_sealed_rifts[rift_id] = true
		EventBus.world_state_changed.emit()
