class_name AttackResolver
## Pure dice logic for survivor attack resolution. No side effects.


## Resolves hit rolls for one attack.
## Returns: { hits: int, roll_details: Array[Dictionary] }
## Each roll_detail: { roll: int, is_hit: bool }
static func resolve_hit_roll(weapon: WeaponProfile, survivor: SurvivorData) -> Dictionary:
	var dice_count: int = max(1, weapon.dice_count + survivor.speed)
	var adjusted_threshold: int = weapon.hit_threshold - survivor.accuracy
	var hits: int = 0
	var roll_details: Array[Dictionary] = []

	for i in range(dice_count):
		var roll: int = randi_range(1, 10)
		var is_hit: bool = false

		if roll == 1:
			is_hit = false
		elif roll == 10:
			is_hit = true
		elif roll >= adjusted_threshold:
			is_hit = true

		if is_hit:
			hits += 1
		roll_details.append({"roll": roll, "is_hit": is_hit})

	return {"hits": hits, "roll_details": roll_details}


## Resolves a single wound roll for one hit.
## Returns: { roll: int, total: int, is_wound: bool, is_crit: bool }
static func resolve_wound_roll(weapon: WeaponProfile, survivor: SurvivorData, monster: MonsterData) -> Dictionary:
	var roll: int = randi_range(1, 10)
	var total: int = roll + weapon.strength_modifier + survivor.strength
	var crit_threshold: int = max(2, 10 - max(0, survivor.luck))

	var is_wound: bool = false
	var is_crit: bool = false

	if roll == 1:
		is_wound = false
	elif roll >= crit_threshold:
		is_wound = true
		is_crit = true
	elif total >= monster.toughness:
		is_wound = true

	return {"roll": roll, "total": total, "is_wound": is_wound, "is_crit": is_crit}
