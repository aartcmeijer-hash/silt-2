class_name MonsterActionCard
extends Resource
## Defines a monster action card combining targeting and action behavior.

enum TargetingType {
	RANDOM_SURVIVOR,
	NEAREST_SURVIVOR,
	WOUNDED_SURVIVOR,
	HIGHEST_HEALTH
}

enum ActionType {
	MOVE_TOWARDS,
	ATTACK,
	SPECIAL_ABILITY
}

@export var card_title: String = "Unnamed Card"
@export var targeting_type: TargetingType = TargetingType.RANDOM_SURVIVOR
@export var action_type: ActionType = ActionType.MOVE_TOWARDS
@export var max_distance: int = 6
@export var dice_count: int = 1
@export var damage: int = 1
@export_multiline var display_text: String = ""


func get_targeting_description() -> String:
	match targeting_type:
		TargetingType.RANDOM_SURVIVOR:
			return "Random Survivor"
		TargetingType.NEAREST_SURVIVOR:
			return "Nearest Survivor"
		TargetingType.WOUNDED_SURVIVOR:
			return "Wounded Survivor"
		TargetingType.HIGHEST_HEALTH:
			return "Highest Health Survivor"
	return "Unknown"


func get_action_description() -> String:
	match action_type:
		ActionType.MOVE_TOWARDS:
			return "Move up to %d spaces toward target" % max_distance
		ActionType.ATTACK:
			return "Attack: %d dice, %d damage" % [dice_count, damage]
		ActionType.SPECIAL_ABILITY:
			return "Use special ability"
	return "Unknown"
