class_name MonsterData
extends Resource
## Stores monster-level combat stats.

@export var accuracy: int = 0
@export var toughness: int = 5

var hit_location_deck: HitLocationDeck = null


func _init(p_accuracy: int = 0, p_toughness: int = 5) -> void:
	accuracy = p_accuracy
	toughness = p_toughness
