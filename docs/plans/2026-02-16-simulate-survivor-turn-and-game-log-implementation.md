# Simulate Survivor Turn & Game Log Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a "Simulate Survivors" button that auto-resolves the player phase for testing, and fix the invisible attack log by repositioning it at the bottom-left of the screen.

**Architecture:** Fix the game log panel first (it is currently parented to the wrong node and invisible). Then add `simulate_all_survivors()` to `PlayerTurnController`. Then wire a new button in `TacticalUI` and connect it in `TacticalGameScreen`. No new autoloads — extend existing signal patterns throughout.

**Tech Stack:** Godot 4.5, GDScript. No automated test framework — verification is done by running the game (`F5` in Godot editor or via `godot` CLI). Scene files are text-format `.tscn` files.

---

## Task 1: Fix the Game Log Panel

The existing `_attack_log_label` is added as a child of `TacticalUI`, which is a small 260×180px panel in the top-right corner. It's invisible because it's clipped inside that container. Fix it by reparenting it as a direct child of the main game screen control, anchored to the bottom-left.

**Files:**
- Modify: `scripts/game/tactical_game_screen.gd` (lines 38–44, 219–221)

**Step 1: Read the current log label setup**

Read `scripts/game/tactical_game_screen.gd` lines 38–45 — the current setup is:
```gdscript
_attack_log_label = RichTextLabel.new()
_attack_log_label.name = "AttackLog"
_attack_log_label.custom_minimum_size = Vector2(300, 120)
_attack_log_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
_attack_log_label.add_theme_color_override("default_color", Color.WHITE)
_attack_log_label.scroll_active = false
tactical_ui.add_child(_attack_log_label)   # <-- wrong parent
monster_ai.attack_log_updated.connect(_on_attack_log_updated)
```

**Step 2: Replace the log label setup**

In `scripts/game/tactical_game_screen.gd`, replace lines 38–44 with:

```gdscript
_attack_log_label = RichTextLabel.new()
_attack_log_label.name = "AttackLog"
_attack_log_label.custom_minimum_size = Vector2(400, 150)
_attack_log_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
_attack_log_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
_attack_log_label.add_theme_color_override("default_color", Color.WHITE)
_attack_log_label.scroll_active = false
add_child(_attack_log_label)   # parent is TacticalGameScreen, not tactical_ui
```

Note: `GROW_DIRECTION_BEGIN` makes the control expand upward from its bottom-left anchor.

**Step 3: Add `append_log()` helper method**

After `_on_attack_log_updated`, add:
```gdscript
func append_log(line: String) -> void:
	if _attack_log_label:
		if _attack_log_label.text != "":
			_attack_log_label.text += "\n"
		_attack_log_label.text += line
```

Also update the existing `_on_attack_log_updated` to use `append_log` to avoid duplication:
```gdscript
func _on_attack_log_updated(lines: Array) -> void:
	if _attack_log_label:
		_attack_log_label.text = "\n".join(lines)
```
(Leave this as-is for now — `MonsterAIController` sends the full lines array as a batch, not one line at a time. The `append_log` method is for incremental appends from survivor simulation.)

**Step 4: Run the game and verify**

Launch the game. Trigger the monster turn (press "Monster Turn" button). The monster's attack log text should now appear in the bottom-left of the screen, not hidden. If the log shows up during monster attacks, this task is complete.

**Step 5: Commit**

```bash
git add scripts/game/tactical_game_screen.gd
git commit -m "fix: move game log panel to bottom-left of screen"
```

---

## Task 2: Add `simulate_all_survivors()` to `PlayerTurnController`

**Files:**
- Modify: `scripts/game/player_turn_controller.gd`

**Step 1: Add the signal declaration**

At the top of `player_turn_controller.gd`, after the existing `signal all_survivors_complete()` on line 5, add:
```gdscript
signal simulation_log_updated(lines: Array)
```

**Step 2: Add the `simulate_all_survivors()` method**

Add this method after `reset_for_new_turn()` (after line 84):

```gdscript
func simulate_all_survivors() -> void:
	var log_lines: Array = []

	for entity_id in survivor_states:
		var state = survivor_states[entity_id]

		# Skip survivors whose turn is already complete (knocked down, already acted)
		if state.is_turn_complete:
			continue

		var entity: EntityPlaceholder = state.entity_node
		var survivor_grid_pos := grid.world_to_grid(entity.position)

		# Find nearest monster by Manhattan distance
		var nearest_monster_id := ""
		var nearest_dist := 999999
		for other_id in entities:
			var other: EntityPlaceholder = entities[other_id]
			if other.entity_type != EntityPlaceholder.EntityType.MONSTER:
				continue
			var monster_grid_pos := grid.world_to_grid(other.position)
			var dist := (abs(survivor_grid_pos.x - monster_grid_pos.x)
					+ abs(survivor_grid_pos.y - monster_grid_pos.y))
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_monster_id = other_id

		# Move toward nearest monster if one exists
		if nearest_monster_id != "":
			var monster: EntityPlaceholder = entities[nearest_monster_id]
			var monster_grid_pos := grid.world_to_grid(monster.position)

			var blocking_check := func(tile: Vector2i) -> bool:
				return _is_tile_blocked(tile, entity_id)

			var valid_tiles := MovementCalculator.calculate_valid_tiles(
				grid, survivor_grid_pos, state.data.movement_range, blocking_check
			)

			# Pick valid tile closest to monster
			var best_tile := survivor_grid_pos
			var best_tile_dist := nearest_dist
			for tile in valid_tiles:
				var d := abs(tile.x - monster_grid_pos.x) + abs(tile.y - monster_grid_pos.y)
				if d < best_tile_dist:
					best_tile_dist = d
					best_tile = tile

			# Move entity instantly (no tween for simulation)
			if best_tile != survivor_grid_pos:
				entity.position = grid.grid_to_world(best_tile.x, best_tile.y)

			log_lines.append("[%s] moves toward [%s], attacks (unresolved)" % [entity_id, nearest_monster_id])
		else:
			log_lines.append("[%s] has no target" % entity_id)

		# Mark as fully acted
		state.has_moved = true
		state.has_activated = true
		_complete_survivor_turn(entity_id)

	if log_lines.size() > 0:
		simulation_log_updated.emit(log_lines)
```

**Step 3: Run the game and verify in the Output panel**

At this point there's no button yet. To verify logic: temporarily add a `print` at the top of `simulate_all_survivors()` and call it manually by adding a `_input` handler or just trust the wiring in Task 4. The logic can be fully tested once the button is wired.

**Step 4: Commit**

```bash
git add scripts/game/player_turn_controller.gd
git commit -m "feat: add simulate_all_survivors to PlayerTurnController"
```

---

## Task 3: Add "Simulate Survivors" Button to TacticalUI

**Files:**
- Modify: `scripts/game/tactical_ui.gd`
- Modify: `scenes/game/tactical_ui.tscn`

**Step 1: Add button to the scene file**

In `scenes/game/tactical_ui.tscn`, add a new button node after the `EndTurnButton` node (after line 56):

```ini
[node name="SimulateSurvivorsButton" type="Button" parent="VBoxContainer"]
custom_minimum_size = Vector2(0, 50)
layout_mode = 2
theme_override_font_sizes/font_size = 18
text = "Simulate Survivors"
```

**Step 2: Update `tactical_ui.gd`**

Add the signal declaration after the existing signals (after line 5):
```gdscript
signal simulate_survivors_pressed
```

Add the `@onready` reference after the existing ones (after line 9):
```gdscript
@onready var simulate_survivors_btn: Button = $VBoxContainer/SimulateSurvivorsButton
```

In `_ready()`, connect the new button (after line 14):
```gdscript
simulate_survivors_btn.pressed.connect(_on_simulate_survivors_pressed)
```

In `update_for_turn()`, add the button state to the match cases:
```gdscript
func update_for_turn(turn: TurnState.Turn) -> void:
	match turn:
		TurnState.Turn.PLAYER:
			turn_label.text = "Player Turn"
			monster_turn_btn.disabled = false
			end_turn_btn.disabled = true
			simulate_survivors_btn.disabled = false   # enabled during player turn
		TurnState.Turn.MONSTER:
			turn_label.text = "Monster Turn"
			monster_turn_btn.disabled = true
			end_turn_btn.disabled = false
			simulate_survivors_btn.disabled = true    # disabled during monster turn
```

In `set_disabled()`, add the new button:
```gdscript
func set_disabled(disabled: bool) -> void:
	monster_turn_btn.disabled = disabled
	end_turn_btn.disabled = disabled
	simulate_survivors_btn.disabled = disabled
```

Add the handler at the bottom:
```gdscript
func _on_simulate_survivors_pressed() -> void:
	simulate_survivors_pressed.emit()
```

**Step 3: Run the game and verify**

Launch the game. The "Simulate Survivors" button should appear in the tactical UI panel. It should be enabled during player turn and disabled during monster turn. Clicking it should do nothing yet (no wiring in game screen).

**Step 4: Commit**

```bash
git add scripts/game/tactical_ui.gd scenes/game/tactical_ui.tscn
git commit -m "feat: add Simulate Survivors button to TacticalUI"
```

---

## Task 4: Wire Everything in TacticalGameScreen

**Files:**
- Modify: `scripts/game/tactical_game_screen.gd`

**Step 1: Connect `simulate_survivors_pressed` signal**

In `_ready()`, after `tactical_ui.end_turn_pressed.connect(_on_end_turn_pressed)` (line 49), add:
```gdscript
tactical_ui.simulate_survivors_pressed.connect(_on_simulate_survivors_pressed)
```

**Step 2: Connect `simulation_log_updated` signal**

After `monster_ai.attack_log_updated.connect(_on_attack_log_updated)` (line 45), add:
```gdscript
player_turn_controller.simulation_log_updated.connect(_on_simulation_log_updated)
```

Wait — `player_turn_controller` is initialized *after* `tactical_ui` connections in `_ready()`. Move the simulation_log_updated connection to after `player_turn_controller` is set up (after line 60):
```gdscript
player_turn_controller.simulation_log_updated.connect(_on_simulation_log_updated)
```

**Step 3: Add the handler methods**

Add after `_on_end_turn_pressed()`:
```gdscript
func _on_simulate_survivors_pressed() -> void:
	player_turn_controller.simulate_all_survivors()


func _on_simulation_log_updated(lines: Array) -> void:
	for line in lines:
		append_log(line)
```

**Step 4: Run the game and do a full verification**

1. Launch the game
2. Press "Simulate Survivors" — all 4 survivors should instantly move toward the monster
3. All survivors should go grey (turn complete)
4. The bottom-left log should show entries like `"[survivor_1] moves toward [monster_1], attacks (unresolved)"`
5. The monster turn should begin automatically after simulation
6. During monster turn, attack results should appear in the same bottom-left log
7. At the start of the next player turn, the log should clear

**Step 5: Commit**

```bash
git add scripts/game/tactical_game_screen.gd
git commit -m "feat: wire simulate survivors button and game log panel"
```

---

## Summary of Changes

| File | What Changed |
|------|-------------|
| `scripts/game/tactical_game_screen.gd` | Reparent log to self, add `append_log()`, wire new signals |
| `scripts/game/player_turn_controller.gd` | Add `simulation_log_updated` signal, add `simulate_all_survivors()` |
| `scripts/game/tactical_ui.gd` | Add `simulate_survivors_pressed` signal, new button refs and handler |
| `scenes/game/tactical_ui.tscn` | Add `SimulateSurvivorsButton` node |
