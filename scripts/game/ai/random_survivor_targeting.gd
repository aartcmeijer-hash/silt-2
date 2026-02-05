class_name RandomSurvivorTargeting
extends TargetingStrategy
## Targeting strategy that picks a random survivor from available targets.

func pick_target(monster_id: String, monsters: Dictionary, survivors: Dictionary) -> String:
	if survivors.is_empty():
		return ""

	var survivor_ids := survivors.keys()
	return survivor_ids[randi() % survivor_ids.size()]
