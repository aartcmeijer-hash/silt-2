class_name RandomSurvivorTargeting
extends TargetingStrategy
## Targeting strategy that picks a random survivor from available targets.

func pick_target(monster_id: String, monsters: Dictionary, survivors: Dictionary) -> String:
	if survivors.is_empty():
		return ""

	var survivor_ids: Array = survivors.keys()
	return survivor_ids[randi_range(0, survivor_ids.size() - 1)]
