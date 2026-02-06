# Monster Action Card System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement card-based monster behavior system with visual deck UI and animations

**Architecture:** Replace hardcoded monster AI with deck of action cards. Each card combines targeting strategy + action. UI shows deck/discard piles with animated card draw/flip/discard.

**Tech Stack:** Godot 4.x, GDScript, Tween animations, Resource system (.tres files)

---

## Phase 1: Data Foundation

### Task 1: Create MonsterActionCard Resource

**Files:**
- Create: `scripts/game/cards/monster_action_card.gd`

**Step 1: Create directory structure**

```bash
mkdir -p scripts/game/cards
mkdir -p data/cards
mkdir -p data/decks
```

**Step 2: Write MonsterActionCard resource class**

Create `scripts/game/cards/monster_action_card.gd`:

```gdscript
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
			return "Attack target"
		ActionType.SPECIAL_ABILITY:
			return "Use special ability"
	return "Unknown"
```

**Step 3: Commit**

```bash
git add scripts/game/cards/monster_action_card.gd
git commit -m "feat: add MonsterActionCard resource class

- Define targeting and action type enums
- Store card metadata (title, targeting, action, parameters)
- Provide description methods for UI display

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 2: Create MonsterDeck Class

**Files:**
- Create: `scripts/game/cards/monster_deck.gd`

**Step 1: Write MonsterDeck class**

Create `scripts/game/cards/monster_deck.gd`:

```gdscript
class_name MonsterDeck
extends RefCounted
## Manages a monster's card deck, draw pile, and discard pile.

signal deck_shuffled
signal card_drawn(card: MonsterActionCard)
signal card_discarded(card: MonsterActionCard)

var draw_pile: Array[MonsterActionCard] = []
var discard_pile: Array[MonsterActionCard] = []


func draw_card() -> MonsterActionCard:
	if draw_pile.is_empty():
		push_error("MonsterDeck.draw_card() called with empty draw pile")
		return null

	var card: MonsterActionCard = draw_pile.pop_front()
	card_drawn.emit(card)
	return card


func discard_card(card: MonsterActionCard) -> void:
	if card:
		discard_pile.append(card)
		card_discarded.emit(card)


func needs_shuffle() -> bool:
	return draw_pile.is_empty() and not discard_pile.is_empty()


func shuffle_discard_into_deck() -> void:
	if discard_pile.is_empty():
		push_warning("MonsterDeck.shuffle_discard_into_deck() called with empty discard pile")
		return

	# Transfer discard to draw pile
	draw_pile.append_array(discard_pile)
	discard_pile.clear()

	# Shuffle
	draw_pile.shuffle()

	deck_shuffled.emit()


func get_draw_pile_count() -> int:
	return draw_pile.size()


func get_discard_pile_count() -> int:
	return discard_pile.size()


func get_top_discard() -> MonsterActionCard:
	if discard_pile.is_empty():
		return null
	return discard_pile.back()
```

**Step 2: Commit**

```bash
git add scripts/game/cards/monster_deck.gd
git commit -m "feat: add MonsterDeck class for card state management

- Manage draw pile and discard pile
- Implement draw, discard, shuffle operations
- Emit signals for UI updates

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 3: Create MonsterDeckConfig Resource

**Files:**
- Create: `scripts/game/cards/monster_deck_config.gd`

**Step 1: Write MonsterDeckConfig resource class**

Create `scripts/game/cards/monster_deck_config.gd`:

```gdscript
class_name MonsterDeckConfig
extends Resource
## Defines the composition of a monster's deck.

@export var deck_name: String = "Unnamed Deck"
@export var cards: Array[MonsterActionCard] = []
@export var card_counts: Array[int] = []


func create_deck() -> MonsterDeck:
	var deck := MonsterDeck.new()

	if cards.size() != card_counts.size():
		push_error("MonsterDeckConfig: cards and card_counts arrays must have same size")
		return deck

	# Populate draw pile
	for i in range(cards.size()):
		var card: MonsterActionCard = cards[i]
		var count: int = card_counts[i]

		if not card:
			push_warning("MonsterDeckConfig: null card at index %d" % i)
			continue

		for j in range(count):
			deck.draw_pile.append(card)

	# Shuffle
	deck.draw_pile.shuffle()

	return deck
```

**Step 2: Commit**

```bash
git add scripts/game/cards/monster_deck_config.gd
git commit -m "feat: add MonsterDeckConfig resource for deck presets

- Define deck composition with card array and counts
- Factory method to create shuffled MonsterDeck instances

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 4: Create First Card Resource

**Files:**
- Create: `data/cards/move_random_survivor.tres`

**Step 1: Create card resource in Godot editor**

Manual step using Godot editor:
1. Open Godot project
2. Navigate to `res://data/cards/`
3. Right-click → Create New → Resource
4. Select `MonsterActionCard`
5. Save as `move_random_survivor.tres`
6. Set properties:
   - `card_title`: "Relentless Pursuit"
   - `targeting_type`: RANDOM_SURVIVOR
   - `action_type`: MOVE_TOWARDS
   - `max_distance`: 6
   - `display_text`: "TARGET: Random Survivor\nACTION: Move up to 6 spaces toward target"
7. Save resource

**Step 2: Verify resource loads**

Run in Godot console or test script:
```gdscript
var card = load("res://data/cards/move_random_survivor.tres")
print(card.card_title)  # Should print "Relentless Pursuit"
print(card.get_targeting_description())
print(card.get_action_description())
```

Expected output:
```
Relentless Pursuit
Random Survivor
Move up to 6 spaces toward target
```

**Step 3: Commit**

```bash
git add data/cards/move_random_survivor.tres
git commit -m "feat: add first monster action card resource

Create Relentless Pursuit card (move towards random survivor)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 5: Create Basic Deck Config Resource

**Files:**
- Create: `data/decks/basic_monster_deck.tres`

**Step 1: Create deck config resource in Godot editor**

Manual step using Godot editor:
1. Open Godot project
2. Navigate to `res://data/decks/`
3. Right-click → Create New → Resource
4. Select `MonsterDeckConfig`
5. Save as `basic_monster_deck.tres`
6. Set properties:
   - `deck_name`: "Basic Monster"
   - `cards`: Add the `move_random_survivor.tres` resource
   - `card_counts`: Add `10` (creates 10 copies of the card)
7. Save resource

**Step 2: Test deck creation**

Run in Godot console:
```gdscript
var config = load("res://data/decks/basic_monster_deck.tres")
var deck = config.create_deck()
print("Draw pile count: ", deck.get_draw_pile_count())  # Should be 10
print("First card: ", deck.draw_card().card_title)  # Should be "Relentless Pursuit"
```

Expected output:
```
Draw pile count: 10
First card: Relentless Pursuit
```

**Step 3: Commit**

```bash
git add data/decks/basic_monster_deck.tres
git commit -m "feat: add basic monster deck configuration

10-card starter deck with only movement actions

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 2: Core Integration

### Task 6: Add Deck Support to MonsterAIController

**Files:**
- Modify: `scripts/game/monster_ai_controller.gd`

**Step 1: Add deck storage and initialization**

In `scripts/game/monster_ai_controller.gd`, add after line 11 (after `targeting_strategy` declaration):

```gdscript
var monster_decks: Dictionary = {}  # monster_id -> MonsterDeck
```

Add new initialization method at the end of the file:

```gdscript
func initialize_monster_deck(monster_id: String, deck_config: MonsterDeckConfig) -> void:
	if not deck_config:
		push_error("MonsterAIController: null deck_config for monster %s" % monster_id)
		return

	var deck: MonsterDeck = deck_config.create_deck()
	monster_decks[monster_id] = deck
```

**Step 2: Add targeting resolution method**

Add at the end of the file:

```gdscript
func _resolve_targeting(card: MonsterActionCard, monsters: Dictionary, survivors: Dictionary) -> String:
	# For now, only implement RANDOM_SURVIVOR
	# Future: extend to support other targeting types
	match card.targeting_type:
		MonsterActionCard.TargetingType.RANDOM_SURVIVOR:
			return targeting_strategy.pick_target("", monsters, survivors)
		_:
			push_warning("Targeting type not yet implemented: %d" % card.targeting_type)
			return ""
```

**Step 3: Add card action execution method**

Add at the end of the file:

```gdscript
func _execute_card_action(monster: EntityPlaceholder, card: MonsterActionCard, target_id: String) -> void:
	# For now, only implement MOVE_TOWARDS
	# Future: extend to support other action types
	match card.action_type:
		MonsterActionCard.ActionType.MOVE_TOWARDS:
			await _execute_move_action(monster, target_id, card.max_distance)
		_:
			push_warning("Action type not yet implemented: %d" % card.action_type)


func _execute_move_action(monster: EntityPlaceholder, target_id: String, max_distance: int) -> void:
	if not entities.has(target_id):
		return

	var target: EntityPlaceholder = entities[target_id]
	var monster_grid_pos: Vector2i = grid.world_to_grid(monster.global_position)
	var target_grid_pos: Vector2i = grid.world_to_grid(target.global_position)

	# Find path (using card's max_distance instead of hardcoded MAX_MOVE_DISTANCE)
	var path: Array[Vector2i] = pathfinder.find_path(monster_grid_pos, target_grid_pos, max_distance)

	if path.size() <= 1:
		return

	path.remove_at(0)
	await _animate_movement(monster, path)
```

**Step 4: Refactor execute_monster_turn to use cards**

Replace the existing `execute_monster_turn()` method (lines 24-35) with:

```gdscript
func execute_monster_turn() -> void:
	var monsters: Dictionary = _get_monsters()
	var survivors: Dictionary = _get_survivors()

	for monster_id in monsters:
		# Check if monster has a deck
		if not monster_decks.has(monster_id):
			push_warning("Monster %s has no deck, skipping turn" % monster_id)
			continue

		var deck: MonsterDeck = monster_decks[monster_id]

		# Shuffle if needed
		if deck.needs_shuffle():
			# TODO: Add shuffle animation when UI is ready
			deck.shuffle_discard_into_deck()

		# Draw card
		var card: MonsterActionCard = deck.draw_card()
		if not card:
			push_warning("Failed to draw card for monster %s" % monster_id)
			continue

		# TODO: Add card flip animation when UI is ready

		# Resolve targeting
		var target_id: String = _resolve_targeting(card, monsters, survivors)
		if target_id.is_empty():
			deck.discard_card(card)
			continue

		# Execute action
		await _execute_card_action(monsters[monster_id], card, target_id)

		# Discard card
		deck.discard_card(card)
		# TODO: Add discard animation when UI is ready

	turn_completed.emit()
```

**Step 5: Commit**

```bash
git add scripts/game/monster_ai_controller.gd
git commit -m "feat: integrate card system into MonsterAIController

- Add monster_decks dictionary to track each monster's deck
- Implement card-based turn execution (draw, resolve, execute, discard)
- Add targeting resolution and action execution methods
- Refactor execute_monster_turn to use cards instead of hardcoded behavior
- Preserve existing movement logic in _execute_move_action

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 7: Initialize Decks in TacticalGameScreen

**Files:**
- Modify: `scripts/game/tactical_game_screen.gd`

**Step 1: Add deck initialization to monster spawning**

Modify the `_spawn_entity` method (around line 70) to initialize decks for monsters:

```gdscript
func _spawn_entity(id: String, grid_pos: Vector2i, type: EntityPlaceholder.EntityType, label: String, color: Color) -> void:
	var entity: Node3D = ENTITY_PLACEHOLDER_SCENE.instantiate()
	entity_container.add_child(entity)
	entity.setup(id, type, label, color)
	entity.position = grid.grid_to_world(grid_pos.x, grid_pos.y)
	entities[id] = entity

	# Initialize deck for monsters
	if type == EntityPlaceholder.EntityType.MONSTER:
		_initialize_monster_deck(id)
```

**Step 2: Add deck initialization method**

Add at the end of the file:

```gdscript
func _initialize_monster_deck(monster_id: String) -> void:
	var deck_config: MonsterDeckConfig = load("res://data/decks/basic_monster_deck.tres")
	if not deck_config:
		push_error("Failed to load basic_monster_deck.tres")
		return

	monster_ai.initialize_monster_deck(monster_id, deck_config)
```

**Step 3: Test in Godot**

Run the game and verify:
1. Game starts without errors
2. Monster turn button works
3. Monster still moves toward survivors (behavior should be unchanged)
4. Check console for deck-related messages

Expected: No errors, monster behavior identical to before

**Step 4: Commit**

```bash
git add scripts/game/tactical_game_screen.gd
git commit -m "feat: initialize monster decks on spawn

Load basic_monster_deck config and create deck for each monster

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 8: Test Shuffle Mechanism

**Files:**
- Modify: `data/decks/basic_monster_deck.tres` (temporarily)

**Step 1: Reduce deck size to test shuffle**

Temporarily modify `basic_monster_deck.tres`:
- Change `card_counts` from `[10]` to `[2]`

**Step 2: Run game and trigger multiple monster turns**

1. Run the game
2. Press "Monster Turn" button multiple times (at least 3 times)
3. Watch console output for shuffle messages

Expected: After 2 turns, should see shuffle happening (draw pile refilled from discard)

**Step 3: Restore deck size**

Change `card_counts` back to `[10]`

**Step 4: Verify behavior**

Run game again, confirm:
- No errors
- Monster behavior consistent
- Deck system working correctly

**Step 5: Commit**

```bash
git add data/decks/basic_monster_deck.tres
git commit -m "test: verify shuffle mechanism works correctly

Temporarily reduced deck size to test shuffle, confirmed working, restored to 10 cards

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 3: UI Implementation

### Task 9: Create Action Card Display Component

**Files:**
- Create: `scenes/game/ui/action_card_display.tscn`
- Create: `scenes/game/ui/action_card_display.gd`

**Step 1: Create directory structure**

```bash
mkdir -p scenes/game/ui
```

**Step 2: Create scene in Godot editor**

Manual steps:
1. Scene → New Scene
2. Root node: PanelContainer, rename to "ActionCardDisplay"
3. Add MarginContainer as child
   - Set "Theme Overrides → Constants → Margin" all sides: 8
4. Add VBoxContainer as child of MarginContainer
   - Set "Separation": 4
5. Add Label as child of VBoxContainer, rename to "TitleLabel"
   - Set "Horizontal Alignment": Center
   - Set "Theme Overrides → Font Sizes → Font Size": 14
6. Add RichTextLabel as child of VBoxContainer, rename to "BodyLabel"
   - Set "Custom Minimum Size → y": 100
   - Set "Fit Content": true
   - Set "BBCode Enabled": true
7. Save scene as `scenes/game/ui/action_card_display.tscn`
8. Set custom minimum size on root: x=150, y=200

**Step 3: Create script**

Create `scenes/game/ui/action_card_display.gd`:

```gdscript
extends PanelContainer
## Displays a single action card (front or back).

@onready var title_label: Label = %TitleLabel
@onready var body_label: RichTextLabel = %BodyLabel

var current_card: MonsterActionCard = null
var showing_front: bool = false


func set_card_data(card: MonsterActionCard) -> void:
	current_card = card
	if showing_front:
		show_front()


func show_front() -> void:
	showing_front = true
	if not current_card:
		title_label.text = ""
		body_label.text = ""
		return

	title_label.text = current_card.card_title

	var target_text := "[b]TARGET:[/b] %s" % current_card.get_targeting_description()
	var action_text := "[b]ACTION:[/b] %s" % current_card.get_action_description()
	body_label.text = "%s\n\n%s" % [target_text, action_text]

	# Style: white background for front
	var style := get_theme_stylebox("panel").duplicate()
	if style is StyleBoxFlat:
		style.bg_color = Color(0.95, 0.95, 0.95)
		style.border_color = Color(0.3, 0.3, 0.3)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
	add_theme_stylebox_override("panel", style)


func show_back() -> void:
	showing_front = false
	title_label.text = ""
	body_label.text = "[center][b]?[/b][/center]"

	# Style: dark background for back
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.1, 0.15)
	style.border_color = Color(0.5, 0.3, 0.4)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	add_theme_stylebox_override("panel", style)


func clear() -> void:
	current_card = null
	showing_front = false
	title_label.text = ""
	body_label.text = ""

	# Style: empty placeholder
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.3)
	style.border_color = Color(0.5, 0.5, 0.5, 0.5)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.set_border_width_all(2)
	style.draw_center = false
	add_theme_stylebox_override("panel", style)
```

**Step 4: Attach script to scene**

1. Open `action_card_display.tscn`
2. Select root node
3. Attach script: `scenes/game/ui/action_card_display.gd`
4. Make TitleLabel and BodyLabel unique (right-click → "Access as Unique Name")
5. Save scene

**Step 5: Test card display**

Create a test scene or run in debugger:
```gdscript
var card_display = preload("res://scenes/game/ui/action_card_display.tscn").instantiate()
add_child(card_display)
var card = load("res://data/cards/move_random_survivor.tres")
card_display.set_card_data(card)
card_display.show_front()
```

Expected: Card displays with title and formatted body text

**Step 6: Commit**

```bash
git add scenes/game/ui/action_card_display.tscn scenes/game/ui/action_card_display.gd
git commit -m "feat: add action card display component

- Reusable card visual showing front/back/empty states
- Styled panels with borders
- Formatted text display for targeting and action

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 10: Create Monster Deck UI Layout

**Files:**
- Create: `scenes/game/ui/monster_deck_ui.tscn`
- Create: `scenes/game/ui/monster_deck_ui.gd`

**Step 1: Create scene structure in Godot editor**

Manual steps:
1. Scene → New Scene
2. Root: Control, rename to "MonsterDeckUI"
3. Set Layout → "Top Right" preset
4. Set "Custom Minimum Size": x=600, y=400
5. Add MarginContainer as child
   - Set all margins: 10
6. Add VBoxContainer as child, rename to "MonsterRowsContainer"
   - Set "Separation": 20
7. Save as `scenes/game/ui/monster_deck_ui.tscn`

**Step 2: Create script**

Create `scenes/game/ui/monster_deck_ui.gd`:

```gdscript
extends Control
## UI for displaying all monster decks, active card, and discard piles.

const ACTION_CARD_DISPLAY = preload("res://scenes/game/ui/action_card_display.tscn")

@onready var monster_rows_container: VBoxContainer = %MonsterRowsContainer

var monster_rows: Dictionary = {}  # monster_id -> MonsterDeckRow


func create_monster_row(monster_id: String, monster_label: String) -> void:
	var row := MonsterDeckRow.new(monster_id, monster_label)
	monster_rows_container.add_child(row)
	monster_rows[monster_id] = row


func update_deck_count(monster_id: String, count: int) -> void:
	if monster_rows.has(monster_id):
		monster_rows[monster_id].update_deck_count(count)


func update_discard_top(monster_id: String, card: MonsterActionCard) -> void:
	if monster_rows.has(monster_id):
		monster_rows[monster_id].update_discard_top(card)


func show_active_card(monster_id: String, card: MonsterActionCard) -> void:
	if monster_rows.has(monster_id):
		monster_rows[monster_id].show_active_card(card)


func clear_active_card(monster_id: String) -> void:
	if monster_rows.has(monster_id):
		monster_rows[monster_id].clear_active_card()


func highlight_monster(monster_id: String, enabled: bool) -> void:
	if monster_rows.has(monster_id):
		monster_rows[monster_id].set_highlighted(enabled)


## Inner class representing a single monster's deck row
class MonsterDeckRow extends HBoxContainer:
	var monster_id: String
	var deck_display: Control
	var active_card_display: Control
	var discard_display: Control
	var label: Label
	var deck_count_label: Label

	func _init(id: String, display_label: String) -> void:
		monster_id = id
		custom_minimum_size.y = 220

		# Monster label
		label = Label.new()
		label.text = display_label
		label.custom_minimum_size.x = 40
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(label)

		# Deck area
		var deck_container := VBoxContainer.new()
		deck_container.custom_minimum_size.x = 150
		add_child(deck_container)

		deck_count_label = Label.new()
		deck_count_label.text = "Deck: 0"
		deck_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		deck_container.add_child(deck_count_label)

		deck_display = ACTION_CARD_DISPLAY.instantiate()
		deck_display.show_back()
		deck_container.add_child(deck_display)

		# Active card area
		active_card_display = ACTION_CARD_DISPLAY.instantiate()
		active_card_display.clear()
		active_card_display.custom_minimum_size.x = 180
		add_child(active_card_display)

		# Discard area
		var discard_container := VBoxContainer.new()
		discard_container.custom_minimum_size.x = 150
		add_child(discard_container)

		var discard_label := Label.new()
		discard_label.text = "Discard"
		discard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		discard_container.add_child(discard_label)

		discard_display = ACTION_CARD_DISPLAY.instantiate()
		discard_display.clear()
		discard_container.add_child(discard_display)


	func update_deck_count(count: int) -> void:
		deck_count_label.text = "Deck: %d" % count
		if count > 0:
			deck_display.show_back()
		else:
			deck_display.clear()


	func update_discard_top(card: MonsterActionCard) -> void:
		if card:
			discard_display.set_card_data(card)
			discard_display.show_front()
		else:
			discard_display.clear()


	func show_active_card(card: MonsterActionCard) -> void:
		active_card_display.set_card_data(card)
		active_card_display.show_front()


	func clear_active_card() -> void:
		active_card_display.clear()


	func set_highlighted(enabled: bool) -> void:
		modulate = Color.WHITE if not enabled else Color(1.2, 1.2, 1.0)
```

**Step 3: Attach script and configure**

1. Open `monster_deck_ui.tscn`
2. Attach script to root node
3. Make MonsterRowsContainer unique
4. Save scene

**Step 4: Commit**

```bash
git add scenes/game/ui/monster_deck_ui.tscn scenes/game/ui/monster_deck_ui.gd
git commit -m "feat: add monster deck UI layout

- Create rows for each monster showing deck/active/discard
- Support multiple monsters with individual displays
- Deck count labels and highlighting support

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 11: Integrate Deck UI into Tactical Game Screen

**Files:**
- Modify: `scenes/game/tactical_game_screen.tscn`
- Modify: `scripts/game/tactical_game_screen.gd`

**Step 1: Add MonsterDeckUI to scene**

Manual steps in Godot editor:
1. Open `scenes/game/tactical_game_screen.tscn`
2. Select the CanvasLayer node
3. Instance Child Scene → `scenes/game/ui/monster_deck_ui.tscn`
4. Rename to "MonsterDeckUI"
5. Save scene

**Step 2: Add reference in script**

In `scripts/game/tactical_game_screen.gd`, add after line 11 (after `pause_menu` onready):

```gdscript
@onready var monster_deck_ui: Control = $CanvasLayer/MonsterDeckUI
```

**Step 3: Connect deck UI to MonsterAI**

Modify `_ready()` method, add after line 32 (after `monster_ai.turn_completed.connect`):

```gdscript
monster_ai.deck_ui = monster_deck_ui
```

**Step 4: Initialize UI rows for monsters**

Modify `_spawn_entity` method to create UI row:

```gdscript
func _spawn_entity(id: String, grid_pos: Vector2i, type: EntityPlaceholder.EntityType, label: String, color: Color) -> void:
	var entity: Node3D = ENTITY_PLACEHOLDER_SCENE.instantiate()
	entity_container.add_child(entity)
	entity.setup(id, type, label, color)
	entity.position = grid.grid_to_world(grid_pos.x, grid_pos.y)
	entities[id] = entity

	# Initialize deck for monsters
	if type == EntityPlaceholder.EntityType.MONSTER:
		_initialize_monster_deck(id)
		monster_deck_ui.create_monster_row(id, label)
```

**Step 5: Update deck counts in initialization**

Modify `_initialize_monster_deck`:

```gdscript
func _initialize_monster_deck(monster_id: String) -> void:
	var deck_config: MonsterDeckConfig = load("res://data/decks/basic_monster_deck.tres")
	if not deck_config:
		push_error("Failed to load basic_monster_deck.tres")
		return

	monster_ai.initialize_monster_deck(monster_id, deck_config)

	# Update UI with initial deck count
	var deck: MonsterDeck = monster_ai.monster_decks[monster_id]
	monster_deck_ui.update_deck_count(monster_id, deck.get_draw_pile_count())
```

**Step 6: Test UI display**

Run the game and verify:
1. Monster deck UI appears in top-right corner
2. Shows "M" label and "Deck: 10"
3. Shows card back for deck
4. Active and discard areas are empty placeholders

Expected: UI visible and showing deck state

**Step 7: Commit**

```bash
git add scenes/game/tactical_game_screen.tscn scripts/game/tactical_game_screen.gd
git commit -m "feat: integrate deck UI into tactical game screen

- Add MonsterDeckUI to canvas layer
- Create UI rows when monsters spawn
- Display initial deck counts

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 12: Connect Deck Events to UI Updates

**Files:**
- Modify: `scripts/game/monster_ai_controller.gd`

**Step 1: Add UI update methods**

In `scripts/game/monster_ai_controller.gd`, add after `initialize_monster_deck` method:

```gdscript
func _update_deck_ui(monster_id: String) -> void:
	if not deck_ui or not monster_decks.has(monster_id):
		return

	var deck: MonsterDeck = monster_decks[monster_id]
	deck_ui.update_deck_count(monster_id, deck.get_draw_pile_count())

	var top_discard := deck.get_top_discard()
	deck_ui.update_discard_top(monster_id, top_discard)
```

**Step 2: Update UI during turn execution**

Modify `execute_monster_turn()` to update UI at key points:

```gdscript
func execute_monster_turn() -> void:
	var monsters: Dictionary = _get_monsters()
	var survivors: Dictionary = _get_survivors()

	for monster_id in monsters:
		# Check if monster has a deck
		if not monster_decks.has(monster_id):
			push_warning("Monster %s has no deck, skipping turn" % monster_id)
			continue

		var deck: MonsterDeck = monster_decks[monster_id]

		# Highlight active monster
		if deck_ui:
			deck_ui.highlight_monster(monster_id, true)

		# Shuffle if needed
		if deck.needs_shuffle():
			# TODO: Add shuffle animation when ready
			deck.shuffle_discard_into_deck()
			_update_deck_ui(monster_id)

		# Draw card
		var card: MonsterActionCard = deck.draw_card()
		if not card:
			push_warning("Failed to draw card for monster %s" % monster_id)
			if deck_ui:
				deck_ui.highlight_monster(monster_id, false)
			continue

		# Update UI: show card and update deck count
		_update_deck_ui(monster_id)
		if deck_ui:
			deck_ui.show_active_card(monster_id, card)

		# TODO: Add card flip animation when ready
		await get_tree().create_timer(0.5).timeout  # Temporary delay to read card

		# Resolve targeting
		var target_id: String = _resolve_targeting(card, monsters, survivors)
		if target_id.is_empty():
			deck.discard_card(card)
			_update_deck_ui(monster_id)
			if deck_ui:
				deck_ui.clear_active_card(monster_id)
				deck_ui.highlight_monster(monster_id, false)
			continue

		# Execute action
		await _execute_card_action(monsters[monster_id], card, target_id)

		# Discard card
		deck.discard_card(card)
		_update_deck_ui(monster_id)
		if deck_ui:
			deck_ui.clear_active_card(monster_id)
			deck_ui.highlight_monster(monster_id, false)
		# TODO: Add discard animation when ready

	turn_completed.emit()
```

**Step 3: Test UI updates**

Run the game:
1. Press "Monster Turn"
2. Observe UI updates:
   - Monster row highlights
   - Active card shows with text
   - Deck count decreases
   - Card moves to discard pile after action
   - Highlight clears

Expected: UI updates in sync with turn execution

**Step 4: Commit**

```bash
git add scripts/game/monster_ai_controller.gd
git commit -m "feat: connect deck events to UI updates

- Update deck counts when cards drawn/discarded
- Show active card during turn execution
- Highlight active monster row
- Sync UI with deck state changes

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 4: Animation Polish

### Task 13: Add Card Flip Animation

**Files:**
- Modify: `scenes/game/ui/action_card_display.gd`
- Modify: `scripts/game/monster_ai_controller.gd`

**Step 1: Add flip animation to card display**

In `scenes/game/ui/action_card_display.gd`, add after `clear()` method:

```gdscript
func flip_to_front() -> void:
	# Start showing back
	show_back()

	# Animate rotation and reveal front
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Scale down horizontally (simulate rotation to edge)
	tween.tween_property(self, "scale:x", 0.0, 0.2)

	# Switch to front at midpoint
	tween.tween_callback(show_front)

	# Scale back up
	tween.tween_property(self, "scale:x", 1.0, 0.2)

	await tween.finished
```

**Step 2: Add animation method to MonsterDeckUI**

In `scenes/game/ui/monster_deck_ui.gd`, add after `clear_active_card()` method:

```gdscript
func play_card_flip_animation(monster_id: String, card: MonsterActionCard) -> void:
	if not monster_rows.has(monster_id):
		return

	var row: MonsterDeckRow = monster_rows[monster_id]
	row.active_card_display.set_card_data(card)
	await row.active_card_display.flip_to_front()
```

**Step 3: Use flip animation in MonsterAIController**

In `scripts/game/monster_ai_controller.gd`, replace the TODO comment and temporary timeout (around line where we show active card):

Replace:
```gdscript
# Update UI: show card and update deck count
_update_deck_ui(monster_id)
if deck_ui:
	deck_ui.show_active_card(monster_id, card)

# TODO: Add card flip animation when ready
await get_tree().create_timer(0.5).timeout  # Temporary delay to read card
```

With:
```gdscript
# Update UI: show card and update deck count
_update_deck_ui(monster_id)
if deck_ui:
	await deck_ui.play_card_flip_animation(monster_id, card)
else:
	await get_tree().create_timer(0.5).timeout
```

**Step 4: Test flip animation**

Run the game:
1. Press "Monster Turn"
2. Watch card flip from back to front in active area
3. Verify smooth animation

Expected: Card scales horizontally to 0, switches to front, scales back to 1

**Step 5: Commit**

```bash
git add scenes/game/ui/action_card_display.gd scenes/game/ui/monster_deck_ui.gd scripts/game/monster_ai_controller.gd
git commit -m "feat: add card flip animation

- Horizontal scale animation simulating 3D flip
- Transition from card back to front at midpoint
- Integrate flip into turn execution flow

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 14: Add Card Discard Animation

**Files:**
- Modify: `scenes/game/ui/monster_deck_ui.gd`
- Modify: `scripts/game/monster_ai_controller.gd`

**Step 1: Add slide animation to MonsterDeckUI**

In `scenes/game/ui/monster_deck_ui.gd`, add after `play_card_flip_animation()` method:

```gdscript
func play_card_discard_animation(monster_id: String, card: MonsterActionCard) -> void:
	if not monster_rows.has(monster_id):
		return

	var row: MonsterDeckRow = monster_rows[monster_id]

	# Animate active card sliding to discard position
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Fade out active card
	tween.tween_property(row.active_card_display, "modulate:a", 0.0, 0.2)

	await tween.finished

	# Update discard pile to show the card
	row.update_discard_top(card)

	# Clear and restore active card area
	row.clear_active_card()
	row.active_card_display.modulate.a = 1.0
```

**Step 2: Use discard animation in MonsterAIController**

In `scripts/game/monster_ai_controller.gd`, replace the discard section (around where we discard card):

Replace:
```gdscript
# Discard card
deck.discard_card(card)
_update_deck_ui(monster_id)
if deck_ui:
	deck_ui.clear_active_card(monster_id)
	deck_ui.highlight_monster(monster_id, false)
# TODO: Add discard animation when ready
```

With:
```gdscript
# Discard card
deck.discard_card(card)
_update_deck_ui(monster_id)
if deck_ui:
	await deck_ui.play_card_discard_animation(monster_id, card)
	deck_ui.highlight_monster(monster_id, false)
else:
	await get_tree().create_timer(0.2).timeout
```

**Step 3: Test discard animation**

Run the game and verify:
1. After action executes, active card fades out
2. Card appears in discard pile
3. Smooth transition

Expected: Active card fades, discard pile updates with new card

**Step 4: Commit**

```bash
git add scenes/game/ui/monster_deck_ui.gd scripts/game/monster_ai_controller.gd
git commit -m "feat: add card discard animation

- Fade out active card
- Update discard pile display
- Clean transition between active and discard states

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 15: Add Shuffle Animation

**Files:**
- Modify: `scenes/game/ui/monster_deck_ui.gd`
- Modify: `scripts/game/monster_ai_controller.gd`

**Step 1: Add shuffle animation to MonsterDeckUI**

In `scenes/game/ui/monster_deck_ui.gd`, add after `play_card_discard_animation()` method:

```gdscript
func play_shuffle_animation(monster_id: String) -> void:
	if not monster_rows.has(monster_id):
		return

	var row: MonsterDeckRow = monster_rows[monster_id]

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Gather: discard moves toward deck
	tween.tween_property(row.discard_display, "position:x", -50, 0.3).as_relative()
	tween.parallel().tween_property(row.discard_display, "modulate:a", 0.3, 0.3)

	# Shuffle effect: shake deck
	tween.tween_property(row.deck_display, "position:x", 5, 0.1).as_relative()
	tween.tween_property(row.deck_display, "position:x", -10, 0.1).as_relative()
	tween.tween_property(row.deck_display, "position:x", 5, 0.1).as_relative()
	tween.tween_property(row.deck_display, "position:x", 0, 0.1).as_relative()

	# Restore discard position and fade
	tween.tween_property(row.discard_display, "position:x", 50, 0.2).as_relative()
	tween.parallel().tween_property(row.discard_display, "modulate:a", 1.0, 0.2)

	await tween.finished

	# Clear discard pile visual after shuffle
	row.update_discard_top(null)
```

**Step 2: Use shuffle animation in MonsterAIController**

In `scripts/game/monster_ai_controller.gd`, replace shuffle section:

Replace:
```gdscript
# Shuffle if needed
if deck.needs_shuffle():
	# TODO: Add shuffle animation when ready
	deck.shuffle_discard_into_deck()
	_update_deck_ui(monster_id)
```

With:
```gdscript
# Shuffle if needed
if deck.needs_shuffle():
	if deck_ui:
		await deck_ui.play_shuffle_animation(monster_id)
	deck.shuffle_discard_into_deck()
	_update_deck_ui(monster_id)
```

**Step 3: Test shuffle animation**

Temporarily modify `basic_monster_deck.tres`:
- Set `card_counts` to `[2]`

Run game:
1. Press "Monster Turn" 3 times
2. On 3rd turn, should see shuffle animation
3. Discard moves toward deck, deck shakes, discard clears

Restore `card_counts` to `[10]`

**Step 4: Commit**

```bash
git add scenes/game/ui/monster_deck_ui.gd scripts/game/monster_ai_controller.gd
git commit -m "feat: add shuffle animation

- Discard pile moves and fades toward deck
- Deck shakes to indicate shuffling
- Discard clears after shuffle completes

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 16: Polish and Timing Adjustments

**Files:**
- Modify: `scripts/game/monster_ai_controller.gd`
- Modify: `scenes/game/ui/action_card_display.gd`

**Step 1: Add hold time after card flip**

In `scripts/game/monster_ai_controller.gd`, add delay after flip to let player read card:

After the flip animation call, add:
```gdscript
# Update UI: show card and update deck count
_update_deck_ui(monster_id)
if deck_ui:
	await deck_ui.play_card_flip_animation(monster_id, card)
	# Hold card visible for player to read
	await get_tree().create_timer(0.5).timeout
else:
	await get_tree().create_timer(0.5).timeout
```

**Step 2: Adjust animation timings for better feel**

In `scenes/game/ui/action_card_display.gd`, adjust flip timing if needed:

Current flip uses 0.2s each direction (0.4s total). This feels good based on design, but can be tweaked:
- Faster: 0.15s each (0.3s total)
- Slower: 0.25s each (0.5s total)

Keep at 0.2s each for now (matches design spec).

**Step 3: Test full animation flow**

Run the game multiple times:
1. Verify all animations flow smoothly
2. Check timing feels good
3. Ensure no visual glitches
4. Test with multiple monsters

Expected: Smooth, polished animation sequence

**Step 4: Commit**

```bash
git add scripts/game/monster_ai_controller.gd
git commit -m "polish: add card read delay and verify timing

- Add 0.5s hold after flip for readability
- Confirm animation timing matches design specs
- Test full animation flow

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 17: Final Testing and Verification

**Files:**
- None (testing only)

**Step 1: Full system test**

Run the game and test:
1. ✓ Monster spawns with deck UI visible
2. ✓ Deck shows count (10 cards)
3. ✓ Press "Monster Turn"
4. ✓ Monster row highlights
5. ✓ Card flips from back to front
6. ✓ Card displays targeting and action text
7. ✓ Monster executes movement
8. ✓ Card slides to discard
9. ✓ Deck count decrements
10. ✓ Repeat multiple turns

**Step 2: Test shuffle**

Temporarily set deck to 2 cards:
1. Run 3 monster turns
2. Verify shuffle animation plays
3. Verify deck refills
4. Verify discard clears
5. Restore deck to 10 cards

**Step 3: Test multiple monsters**

Modify `_spawn_initial_entities` to spawn 2 monsters:
```gdscript
var monster_pos: Vector2i = grid.get_grid_center()
_spawn_entity("monster_1", monster_pos, EntityPlaceholder.EntityType.MONSTER, "M1", Color(0.9, 0.2, 0.2))
_spawn_entity("monster_2", monster_pos + Vector2i(2, 0), EntityPlaceholder.EntityType.MONSTER, "M2", Color(0.9, 0.5, 0.2))
```

Test:
1. Both monsters show in UI
2. Both execute turns in sequence
3. Each highlights independently
4. Deck states track separately

Revert to single monster after testing.

**Step 4: Verify no console errors**

Check console output:
- No errors
- No warnings (except expected ones)
- Deck operations log correctly

**Step 5: Document completion**

All four phases complete:
- ✓ Phase 1: Data Foundation
- ✓ Phase 2: Core Integration
- ✓ Phase 3: UI Implementation
- ✓ Phase 4: Animation Polish

**Step 6: Final commit**

```bash
git commit --allow-empty -m "test: verify monster action card system complete

All phases implemented and tested:
- Card resource system with deck configs
- Card-driven monster AI behavior
- Visual deck UI with deck/active/discard displays
- Animated card flip, discard, and shuffle

System ready for extension with new card types.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Summary

This implementation plan delivers a complete monster action card system with:

- **Data-driven cards**: Resources define targeting + action combinations
- **Deck management**: Draw, discard, shuffle mechanics
- **Visual UI**: Top-right display showing all monster decks
- **Animations**: Card flip, discard, shuffle with proper timing
- **Extensibility**: Easy to add new targeting types and action types

The system maintains existing monster behavior while providing a flexible foundation for complex AI patterns.

**Next Steps (Future):**
- Add new targeting types (NEAREST, WOUNDED, etc.)
- Add new action types (ATTACK, SPECIAL_ABILITY, etc.)
- Create varied deck configurations for different monster types
- Add card effects that manipulate decks
