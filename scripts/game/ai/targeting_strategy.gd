class_name TargetingStrategy
extends Resource
## Abstract base class for monster targeting strategies.
## Subclasses implement pick_target() to define targeting behavior.

## Virtual method - override in subclasses to implement targeting logic.
## Returns the entity_id of the chosen target, or empty string if no valid target.
func pick_target(monster_id: String, monsters: Dictionary, survivors: Dictionary) -> String:
	push_error("TargetingStrategy.pick_target() must be implemented in subclass")
	return ""
