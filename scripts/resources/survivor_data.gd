class_name SurvivorData
extends Resource
## Stores persistent survivor stats.

@export var movement_range: int = 5

func _init(p_movement_range: int = 5) -> void:
	movement_range = p_movement_range
