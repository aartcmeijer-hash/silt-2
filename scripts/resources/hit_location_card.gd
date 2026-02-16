class_name HitLocationCard
extends Resource
## A hit location card drawn when a survivor lands a hit on a monster.
## Currently empty — effects will be added later.

@export var card_name: String = "Unknown"


func _init(p_name: String = "Unknown") -> void:
	card_name = p_name
