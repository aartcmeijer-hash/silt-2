class_name SurvivorData
extends Resource
## Stores persistent survivor stats.

@export var movement_range: int = 5
@export var evasion: int = 5
@export var accuracy: int = 0
@export var speed: int = 0
@export var strength: int = 0
@export var luck: int = 0

var is_knocked_down: bool = false
var body_part_wounds: Dictionary = {
	"head": 0,
	"arms": 0,
	"body": 0,
	"waist": 0,
	"legs": 0,
}


func _init(p_movement_range: int = 5) -> void:
	movement_range = p_movement_range
