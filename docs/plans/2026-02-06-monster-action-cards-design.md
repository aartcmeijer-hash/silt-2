# Monster Action Card System Design

**Date:** 2026-02-06
**Status:** Approved

## Overview

This design introduces a card-based system for governing monster behavior during their turns. Each monster will have its own deck of action cards that combine targeting strategy and action execution. Cards are drawn, animated, executed, and discarded, with automatic shuffling when the deck is exhausted.

## Current State

- Monster behavior is hardcoded in `MonsterAIController.execute_monster_turn()`
- Single behavior: "move towards random survivor"
- Targeting strategy (`RandomSurvivorTargeting`) and action execution are separate
- No visual representation of monster decision-making

## Goals

1. Replace hardcoded monster behavior with card-driven actions
2. Create visual deck/discard UI in top-right corner
3. Animate card draw with flip animation (0.3-0.5s)
4. Support multiple monsters with individual decks
5. Combine targeting + action into single card concept
6. Enable easy future expansion with new card types

---

## Architecture & Data Structure

### Core Components

1. **MonsterActionCard** (Resource) - Defines targeting + action combination
2. **MonsterDeck** (Class) - Manages deck, draw pile, and discard pile for one monster
3. **MonsterDeckUI** (Control node) - Visualizes the deck/discard state for all monsters

### Card Data Structure

Each `MonsterActionCard` resource stores:
- **Card title** (e.g., "Relentless Pursuit")
- **Targeting type** (enum: RANDOM_SURVIVOR, NEAREST_SURVIVOR, WOUNDED_SURVIVOR, etc.)
- **Action type** (enum: MOVE_TOWARDS, ATTACK, ABILITY, etc.)
- **Action parameters** (e.g., `max_distance: 6` for movement)
- **Display text** showing both parts (e.g., "TARGET: Random Survivor\nACTION: Move up to 6 spaces toward target")

### Execution Flow

When a card is drawn:
1. Resolve **targeting** using the card's targeting type → get `target_id`
2. Execute **action** using the card's action type → perform movement/attack/ability
3. Discard the card

This replaces the current separated `targeting_strategy.pick_target()` + `_execute_monster_action()` pattern. Each card is a complete "AI behavior" package.

---

## UI Layout & Visual Structure

### Top-Right Monster Deck Area

New `MonsterDeckUI` scene in `CanvasLayer` positioned top-right, containing:

- **Deck Display Area** (left): Stacked card backs with offset layering. Each monster gets its own deck visualization with monster identifier label (e.g., "M1")
- **Active Card Area** (center): Card slides here and flips when drawn. Size: ~200x300px
- **Discard Pile Area** (right): Shows top discarded card for each monster. Empty piles show outlined placeholder

### Multi-Monster Layout

Vertical list for multiple monsters:
```
[M1 Deck (5 cards)] → [Active Card Space] → [M1 Discard (top card)]
[M2 Deck (4 cards)] → [Active Card Space] → [M2 Discard (top card)]
```

When a monster's turn comes, their row highlights (subtle glow/border) and their card animates into the shared active card space.

### Card Visual Design

Cards are panels with:
- Card frame/border with shadow
- Title at top (smaller text)
- Two-section body: "TARGET: [targeting]" then "ACTION: [action description]"
- Card back: Monster-themed pattern (claws, eyes, dark colors)

### Discard Pile

Shows only the top discarded card for simplicity and cleanliness, matching typical board game behavior.

---

## Animation System & Timing

### Card Draw & Flip Animation

1. **Slide** (0.2s): Card slides from deck to active area, showing card back
2. **Flip** (0.4s): Card rotates 180° on Y-axis, transitioning to front. Use EASE_IN_OUT easing
3. **Hold** (0.5s): Card remains visible so player can read it
4. **Slide to Discard** (0.2s): After action completes, card slides to discard pile

**Total overhead:** ~1.3 seconds per card draw

### Deck Shuffle Animation

When deck is empty and discard shuffles back:

1. **Gather** (0.3s): Discard pile cards collapse/stack together
2. **Shuffle Effect** (0.4s): Quick shake/blur effect suggesting shuffling
3. **Move to Deck** (0.2s): Pile slides back to deck position

This happens at the START of the monster turn before drawing.

### Deck Visual Updates

The stacked card back visual updates immediately when:
- Card drawn (one layer removed from stack)
- Discard gains a card (new top card appears)
- Deck replenished (stack rebuilds with animation)

All animations use Godot's `Tween`, consistent with existing movement animations in `MonsterAIController`.

---

## Deck Management Logic

### MonsterDeck Class

Runtime state manager (not a Resource):

```gdscript
class MonsterDeck:
    var draw_pile: Array[MonsterActionCard] = []
    var discard_pile: Array[MonsterActionCard] = []

    func draw_card() -> MonsterActionCard
    func discard_card(card: MonsterActionCard) -> void
    func needs_shuffle() -> bool
    func shuffle_discard_into_deck() -> void
```

### Deck Initialization - Data-Driven

Use **Godot Resource files (.tres)** for deck composition:

**MonsterDeckConfig Resource:**
```gdscript
class_name MonsterDeckConfig
extends Resource

@export var deck_name: String = "Starter Deck"
@export var cards: Array[MonsterActionCard] = []
@export var card_counts: Array[int] = []  # How many of each card
```

Example file `res://data/decks/basic_monster_deck.tres`:
```
deck_name: "Basic Monster"
cards: [movement_card_resource]
card_counts: [10]
```

**Loading Example:**
```gdscript
var deck_config = load("res://data/decks/basic_monster_deck.tres")
var deck = MonsterDeck.new()
for i in range(deck_config.cards.size()):
    var card = deck_config.cards[i]
    var count = deck_config.card_counts[i]
    for j in range(count):
        deck.draw_pile.append(card)
deck.shuffle_deck()
```

### Shuffle Logic

When `draw_pile.is_empty()` at start of turn:
1. Transfer all cards from `discard_pile` to `draw_pile`
2. Clear `discard_pile`
3. Randomize using `draw_pile.shuffle()`
4. Play shuffle animation

### Turn Flow Changes

`MonsterAIController.execute_monster_turn()` becomes:
```
For each monster:
    1. Check if deck needs shuffle → shuffle if needed (with animation)
    2. Draw card from deck
    3. Animate card flip
    4. Resolve targeting from card
    5. Execute action from card
    6. Discard card
    7. Update UI
```

---

## Integration with MonsterAIController

### Refactored execute_monster_turn()

**OLD:**
```gdscript
var target_id = targeting_strategy.pick_target(...)
await _execute_monster_action(monster, target_id)
```

**NEW:**
```gdscript
var monster_deck: MonsterDeck = monster_decks[monster_id]

# Check and shuffle if needed
if monster_deck.needs_shuffle():
    await ui.play_shuffle_animation(monster_id)
    monster_deck.shuffle_discard_into_deck()

# Draw and display card
var card: MonsterActionCard = monster_deck.draw_card()
await ui.play_card_draw_animation(monster_id, card)

# Resolve targeting from card
var target_id: String = _resolve_targeting(card, monsters, survivors)

# Execute action from card
await _execute_card_action(monster, card, target_id)

# Discard card
monster_deck.discard_card(card)
await ui.play_card_discard_animation(monster_id, card)
```

### New Data Storage

Add to `MonsterAIController`:
```gdscript
var monster_decks: Dictionary = {}  # monster_id -> MonsterDeck
var deck_ui: MonsterDeckUI  # Reference to UI component
```

### Initialization Changes

In `tactical_game_screen.gd`, when spawning monsters:
```gdscript
func _spawn_entity(...):
    # existing code...
    if type == EntityPlaceholder.EntityType.MONSTER:
        _initialize_monster_deck(id)

func _initialize_monster_deck(monster_id: String) -> void:
    var deck_config = load("res://data/decks/basic_monster_deck.tres")
    var deck = MonsterDeck.new()
    # Initialize from config...
    monster_ai.monster_decks[monster_id] = deck
```

### Backwards Compatibility

Existing targeting strategies (`RandomSurvivorTargeting`) remain in codebase and are referenced by cards via enum mapping. Current code structure is preserved while adding the card layer on top.

---

## File Structure & New Components

### New Files to Create

```
scripts/game/cards/
├── monster_action_card.gd          # Resource: card definition
├── monster_deck.gd                  # Class: deck state manager
└── monster_deck_config.gd           # Resource: deck composition preset

scenes/game/ui/
├── monster_deck_ui.tscn             # UI scene for all monster decks
├── monster_deck_ui.gd               # Controller for deck UI
├── action_card_display.tscn         # Single card visual (reusable)
└── action_card_display.gd           # Card display controller

data/decks/
├── basic_monster_deck.tres          # Starter deck config
└── (future: other deck variants)

data/cards/
└── move_random_survivor.tres        # First card instance
```

### Modified Files

```
scripts/game/monster_ai_controller.gd    # Add card draw/execution logic
scripts/game/tactical_game_screen.gd     # Initialize decks, connect UI
scenes/game/tactical_game_screen.tscn    # Add MonsterDeckUI to CanvasLayer
```

### Card Display Component

`action_card_display.tscn` is a reusable Control node with:
- Panel/background
- Label for title
- RichTextLabel for target/action text
- Methods: `show_front()`, `show_back()`, `set_card_data(card: MonsterActionCard)`

This component is instantiated for each deck/discard position, plus one shared instance for the active card area.

### Targeting Strategy Integration

Keep existing `scripts/game/ai/` folder. Cards reference strategies by type enum, and `MonsterAIController` maps enum → strategy instance.

---

## Implementation Phases

### Phase 1 - Data Foundation
1. Create `MonsterActionCard` resource class with targeting + action enums
2. Create `MonsterDeck` class with draw/discard/shuffle logic
3. Create `MonsterDeckConfig` resource class
4. Create first card: `move_random_survivor.tres`
5. Create first deck config: `basic_monster_deck.tres`

**Test:** Can load card data from .tres files

### Phase 2 - Core Integration
1. Modify `MonsterAIController` to use decks instead of direct targeting
2. Add deck initialization in `tactical_game_screen.gd`
3. Test that cards draw, execute actions, and discard correctly (no UI yet)
4. Verify shuffle triggers when deck is empty

**Test:** Monster behavior unchanged, but now driven by cards

### Phase 3 - UI Implementation
1. Create `action_card_display.tscn` (card visual component)
2. Create `monster_deck_ui.tscn` (full deck UI layout)
3. Implement card positioning for deck/active/discard areas
4. Test static display (no animations yet)

**Test:** Can see deck state, drawn cards visible

### Phase 4 - Animation Polish
1. Add card draw animation (slide + flip)
2. Add discard animation
3. Add shuffle animation
4. Add highlight for active monster row
5. Tune timing and easing

**Test:** Full animated card system working

---

## Future Extensibility

This design makes it easy to add:

- **New targeting types:** NEAREST, WOUNDED, HIGHEST_HEALTH, ALL_SURVIVORS
- **New action types:** ATTACK, SPECIAL_ABILITY, SPAWN, TELEPORT
- **Different deck compositions** per monster type
- **Card effects** that modify deck (remove cards, add cards, draw extra, etc.)
- **Conditional cards** (e.g., "if target health < 50%")
- **Multi-action cards** (e.g., "Move 3, then Attack")

The targeting + action combination structure provides a flexible foundation for complex monster behaviors while keeping individual cards simple and readable.
