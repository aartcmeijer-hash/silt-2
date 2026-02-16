class_name WeaponProfile
extends Resource
## Defines the attack stats for a weapon.

@export var dice_count: int = 2
@export var hit_threshold: int = 8
@export var strength_modifier: int = 0
@export var range: int = 1


func _init(
	p_dice_count: int = 2,
	p_hit_threshold: int = 8,
	p_strength_modifier: int = 0,
	p_range: int = 1
) -> void:
	dice_count = p_dice_count
	hit_threshold = p_hit_threshold
	strength_modifier = p_strength_modifier
	range = p_range
