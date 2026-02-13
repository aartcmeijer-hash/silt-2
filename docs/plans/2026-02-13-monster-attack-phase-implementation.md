# Monster Attack Phase Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a KDM-inspired monster attack system where attacks roll dice to hit vs. survivor evasion, strike a body part location, apply wounds, and trigger knock-down or severe injury.

**Architecture:** Attack stats live on `MonsterActionCard` (dice_count, damage) with monster-level `accuracy` on a new `MonsterData` resource. Wound tracking and knock-down state live on `SurvivorData`. Resolution logic lives in `MonsterAIController`. Knock-down is enforced in `PlayerTurnController.reset_for_new_turn()`.

**Tech Stack:** Godot 4, GDScript. No test framework — verification is done by running the game and observing behavior.

---

### Task 1: Create MonsterData Resource

**Files:**
- Create: `scripts/resources/monster_data.gd`
- Modify: `scripts/game/entity_placeholder.gd`
- Modify: `scripts/game/tactical_game_screen.gd`

**Step 1: Create the resource**

Create `scripts/resources/monster_data.gd`:
```gdscript
class_name MonsterData
extends Resource
## Stores monster-level combat stats.

@export var accuracy: int = 0
```

**Step 2: Add monster_data to EntityPlaceholder**

In `scripts/game/entity_placeholder.gd`, after the existing `var survivor_data: SurvivorData = null` line, add:
```gdscript
var monster_data: MonsterData = null
```

**Step 3: Wire MonsterData when spawning monsters**

In `scripts/game/tactical_game_screen.gd`, in `_spawn_entity()`, after the `if type == EntityPlaceholder.EntityType.MONSTER:` block (around line 116), add monster_data initialization before `_initialize_monster_deck(id)`:
```gdscript
if type == EntityPlaceholder.EntityType.MONSTER:
    entity.monster_data = MonsterData.new()
    _initialize_monster_deck(id)
    monster_deck_ui.create_monster_row(id, label)
```

**Step 4: Verify**

Run the game. The game should launch and play exactly as before — this is a data-only change with no visible effect yet.

**Step 5: Commit**
```bash
git add scripts/resources/monster_data.gd scripts/game/entity_placeholder.gd scripts/game/tactical_game_screen.gd
git commit -m "feat: add MonsterData resource with accuracy stat"
```

---

### Task 2: Extend SurvivorData

**Files:**
- Modify: `scripts/resources/survivor_data.gd`

**Step 1: Add evasion, is_knocked_down, body_part_wounds**

Replace the entire contents of `scripts/resources/survivor_data.gd` with:
```gdscript
class_name SurvivorData
extends Resource
## Stores persistent survivor stats.

@export var movement_range: int = 5
@export var evasion: int = 5

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
```

**Step 2: Verify**

Run the game. Behavior is unchanged — new fields are unused so far.

**Step 3: Commit**
```bash
git add scripts/resources/survivor_data.gd
git commit -m "feat: add evasion, knock-down, and body part wound tracking to SurvivorData"
```

---

### Task 3: Extend MonsterActionCard with Attack Stats

**Files:**
- Modify: `scripts/game/cards/monster_action_card.gd`
- Create: `data/cards/attack_random_survivor.tres`
- Modify: `data/decks/basic_monster_deck.tres`

**Step 1: Add dice_count and damage fields to MonsterActionCard**

In `scripts/game/cards/monster_action_card.gd`, after the existing `@export var max_distance: int = 6` line, add:
```gdscript
@export var dice_count: int = 1
@export var damage: int = 1
```

Also update `get_action_description()` to handle ATTACK:
```gdscript
ActionType.ATTACK:
    return "Attack: %d dice, %d damage" % [dice_count, damage]
```

**Step 2: Create the attack card data file**

Create `data/cards/attack_random_survivor.tres`:
```
[gd_resource type="Resource" script_class="MonsterActionCard" load_steps=2 format=3 uid="uid://attack_random_1"]

[ext_resource type="Script" path="res://scripts/game/cards/monster_action_card.gd" id="1"]

[resource]
script = ExtResource("1")
card_title = "Feral Strike"
targeting_type = 0
action_type = 1
max_distance = 0
display_text = "TARGET: Random Survivor
ACTION: Attack with 2 dice, 1 damage"
dice_count = 2
damage = 1
```

> **Note:** Godot requires a real UID. Open Godot editor after creating this file — it will auto-assign a valid UID when it imports the resource. Alternatively, generate one by running the game once; Godot will fix the UID automatically.

**Step 3: Add attack card to the deck**

Edit `data/decks/basic_monster_deck.tres` to include the attack card. The file should become:
```
[gd_resource type="Resource" script_class="MonsterDeckConfig" load_steps=4 format=3 uid="uid://bpv3k2m8ht5dx"]

[ext_resource type="Script" path="res://scripts/game/cards/monster_deck_config.gd" id="1"]
[ext_resource type="Resource" path="res://data/cards/move_random_survivor.tres" id="2"]
[ext_resource type="Resource" path="res://data/cards/attack_random_survivor.tres" id="3"]

[resource]
script = ExtResource("1")
deck_name = "Basic Monster"
cards = Array[Resource]([ExtResource("2"), ExtResource("3")])
card_counts = Array[int]([7, 3])
```

**Step 4: Verify**

Run the game. Monster turn should play as before (ATTACK cards will print "Action type not yet implemented" warning — that's expected and will be fixed in Task 4).

**Step 5: Commit**
```bash
git add scripts/game/cards/monster_action_card.gd data/cards/attack_random_survivor.tres data/decks/basic_monster_deck.tres
git commit -m "feat: add dice_count and damage to MonsterActionCard, add attack card to deck"
```

---

### Task 4: Implement Attack Resolution in MonsterAIController

**Files:**
- Modify: `scripts/game/monster_ai_controller.gd`

This is the core logic task. Add `_execute_attack_action()` and wire it into the existing `_execute_card_action()`.

**Step 1: Add the attack resolution method**

In `scripts/game/monster_ai_controller.gd`, add these methods before the final closing of the file:

```gdscript
func _execute_attack_action(monster: EntityPlaceholder, card: MonsterActionCard, target_id: String) -> void:
	if not entities.has(target_id):
		return

	var target: EntityPlaceholder = entities[target_id]
	var survivor_data: SurvivorData = target.survivor_data
	if not survivor_data:
		push_warning("MonsterAIController: target %s has no SurvivorData" % target_id)
		return

	var monster_data: MonsterData = monster.monster_data
	var accuracy: int = monster_data.accuracy if monster_data else 0

	# Step 1: Hit rolls
	var hits: int = 0
	var roll_results: Array[int] = []
	for i in range(card.dice_count):
		var roll: int = randi_range(1, 10)
		roll_results.append(roll)
		if roll + accuracy > survivor_data.evasion:
			hits += 1

	var rolls_str: String = ", ".join(roll_results.map(func(r): return str(r)))
	print("  Rolls: %s → %d hit(s) (evasion %d)" % [rolls_str, hits, survivor_data.evasion])

	if hits == 0:
		print("  Miss!")
		return

	# Step 2 & 3: Per-hit location and damage
	for i in range(hits):
		var location: String = _roll_hit_location()
		var prev_wounds: int = survivor_data.body_part_wounds[location]
		survivor_data.body_part_wounds[location] += card.damage
		var new_wounds: int = survivor_data.body_part_wounds[location]

		var wound_str: String = "%s — wound %d" % [location.to_upper(), new_wounds]

		if prev_wounds < 2 and new_wounds >= 2:
			survivor_data.is_knocked_down = true
			wound_str += " → KNOCKED DOWN"
		elif prev_wounds >= 2:
			_trigger_severe_injury(target_id, location)
			wound_str += " → SEVERE INJURY"

		print("  Hit %d: %s" % [i + 1, wound_str])


func _roll_hit_location() -> String:
	var roll: int = randi_range(1, 10)
	match roll:
		1, 2: return "head"
		3, 4: return "arms"
		5, 6: return "body"
		7, 8: return "waist"
		_: return "legs"


func _trigger_severe_injury(target_id: String, body_part: String) -> void:
	# Stub: severe injury table not yet implemented
	push_warning("SEVERE INJURY triggered on %s (%s) — not yet implemented" % [target_id, body_part])
```

**Step 2: Wire into _execute_card_action()**

In `_execute_card_action()`, replace the ATTACK case:
```gdscript
MonsterActionCard.ActionType.ATTACK:
    await _execute_attack_action(monster, card, target_id)
```

**Step 3: Add print for monster attack announcement**

In `_execute_card_action()`, add a print at the top so the log shows which monster is acting:
```gdscript
func _execute_card_action(monster: EntityPlaceholder, card: MonsterActionCard, target_id: String) -> void:
	if card.action_type == MonsterActionCard.ActionType.ATTACK:
		print("%s attacks %s!" % [monster.entity_label, target_id])
	match card.action_type:
		...
```

**Step 4: Verify**

Run the game. Trigger a monster turn. In the Godot output console, when an ATTACK card is drawn you should see:
```
M attacks survivor_1!
  Rolls: 7, 3, 9 → 2 hits (evasion 5)
  Hit 1: ARMS — wound 1
  Hit 2: BODY — wound 2 → KNOCKED DOWN
```

**Step 5: Commit**
```bash
git add scripts/game/monster_ai_controller.gd
git commit -m "feat: implement monster attack resolution with hit rolls, location, and wound tracking"
```

---

### Task 5: Enforce Knock-Down in PlayerTurnController

**Files:**
- Modify: `scripts/game/player_turn_controller.gd`

**Step 1: Auto-complete knocked-down survivors at turn start**

In `reset_for_new_turn()`, after the existing reset loop, add a knocked-down check. The existing loop already resets state — extend it:

```gdscript
func reset_for_new_turn() -> void:
	for entity_id in survivor_states:
		var state = survivor_states[entity_id]
		state.has_moved = false
		state.has_activated = false
		state.is_turn_complete = false

		var entity: EntityPlaceholder = state.entity_node
		entity.restore_color()

		# Knock-down: survivor skips this entire turn
		var data: SurvivorData = state.data
		if data and data.is_knocked_down:
			data.is_knocked_down = false
			state.is_turn_complete = true
			entity.set_greyed_out(true)
			print("%s is knocked down — skipping turn" % entity_id)

	if active_survivor_id != "":
		deselect_survivor()
```

**Step 2: Verify**

Run the game. Let a survivor get knocked down (watch the console output from Task 4). End the monster turn, start the player turn — the knocked-down survivor should appear greyed-out immediately and be unselectable.

**Step 3: Commit**
```bash
git add scripts/game/player_turn_controller.gd
git commit -m "feat: knocked-down survivors skip their next player turn"
```

---

### Task 6: UI — Attack Log

**Files:**
- Modify: `scripts/game/monster_ai_controller.gd`
- Modify: `scripts/game/tactical_game_screen.gd`

**Step 1: Add a signal to MonsterAIController**

At the top of `scripts/game/monster_ai_controller.gd`, add:
```gdscript
signal attack_log_updated(lines: Array)
```

Add a `_attack_log: Array` member variable:
```gdscript
var _attack_log: Array = []
```

**Step 2: Replace print calls with log accumulation**

In `_execute_attack_action()`, replace each `print(...)` with a helper that both prints and accumulates:
```gdscript
func _log(line: String) -> void:
	print(line)
	_attack_log.append(line)
```

At the start of `_execute_attack_action()`, before the hit rolls, clear and start the log entry:
```gdscript
_log("%s attacks %s!" % [monster.entity_label, target_id])
```

At the end of the method (after all hits resolved), emit:
```gdscript
attack_log_updated.emit(_attack_log.duplicate())
```

Also clear the log at the start of each `_execute_attack_action()` call:
```gdscript
_attack_log.clear()
```

Remove the duplicate print from `_execute_card_action()` added in Task 4.

**Step 3: Add attack log label in tactical_game_screen.gd**

In `tactical_game_screen.gd`, declare a member variable:
```gdscript
var _attack_log_label: RichTextLabel = null
```

In `_ready()`, after `monster_ai` is created and connected, add:
```gdscript
_attack_log_label = RichTextLabel.new()
_attack_log_label.name = "AttackLog"
_attack_log_label.custom_minimum_size = Vector2(300, 120)
_attack_log_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
_attack_log_label.add_theme_color_override("default_color", Color.WHITE)
_attack_log_label.scroll_active = false
tactical_ui.add_child(_attack_log_label)
monster_ai.attack_log_updated.connect(_on_attack_log_updated)
```

Add the handler:
```gdscript
func _on_attack_log_updated(lines: Array) -> void:
	_attack_log_label.text = "\n".join(lines)
```

Clear the log when a new player turn starts. In `_on_turn_changed()` (or wherever player turn begins), add:
```gdscript
if _attack_log_label:
	_attack_log_label.text = ""
```

**Step 4: Verify**

Run the game. Trigger a monster turn with ATTACK cards — the attack log text should appear on screen in the bottom-left area of the tactical UI panel.

**Step 5: Commit**
```bash
git add scripts/game/monster_ai_controller.gd scripts/game/tactical_game_screen.gd
git commit -m "feat: add on-screen attack log for monster attacks"
```

---

### Task 7: UI — Wound Panel in SurvivorActionMenu

**Files:**
- Modify: `scripts/game/player_turn_controller.gd`
- Modify: `scripts/game/ui/survivor_action_menu.gd`

**Step 1: Add wound display method to SurvivorActionMenu**

In `scripts/game/ui/survivor_action_menu.gd`, add a method to show/update the wound state. First add a member variable:
```gdscript
var _wound_label: Label = null
```

Add a method:
```gdscript
func show_wounds(survivor_data: SurvivorData) -> void:
	if not _wound_label:
		_wound_label = Label.new()
		_wound_label.name = "WoundPanel"
		$VBoxContainer.add_child(_wound_label)

	var lines: Array[String] = []

	if survivor_data.is_knocked_down:
		lines.append("[KNOCKED DOWN]")

	for part in ["head", "arms", "body", "waist", "legs"]:
		var wounds: int = survivor_data.body_part_wounds[part]
		var slot1: String = "●" if wounds >= 1 else "○"
		var slot2: String = "●" if wounds >= 2 else "○"
		var severe: String = "!" if wounds > 2 else ""
		lines.append("%s %s %s%s" % [part.to_upper().lpad(5), slot1, slot2, severe])

	_wound_label.text = "\n".join(lines)
```

**Step 2: Call show_wounds from PlayerTurnController.select_survivor()**

In `scripts/game/player_turn_controller.gd`, in `select_survivor()`, after `action_menu.update_button_states(...)`, add:
```gdscript
var data: SurvivorData = state.data
if data:
	action_menu.show_wounds(data)
```

**Step 3: Verify**

Run the game. Select a survivor — the action menu should now show wound state for all five body parts below the action buttons. Let a survivor take wounds (check console log) then select them again to see the wound state update.

**Step 4: Commit**
```bash
git add scripts/game/ui/survivor_action_menu.gd scripts/game/player_turn_controller.gd
git commit -m "feat: show survivor body part wound state in action menu"
```

---

## Done

At this point:
- Monsters with ATTACK cards roll dice vs. survivor evasion, strike a body part, and apply wounds
- Wound thresholds trigger knock-down (survivor skips next turn) or a severe injury stub
- Attack resolution is logged on screen during the monster turn
- Selecting a survivor shows their body part wound state

**Next steps (out of scope for this plan):**
- Armor system (reduces damage before wound application)
- Severe injury table
- Custom body part dice
- Per-location wound effects
