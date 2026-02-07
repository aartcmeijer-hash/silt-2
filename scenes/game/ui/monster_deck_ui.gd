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


func play_card_flip_animation(monster_id: String, card: MonsterActionCard) -> void:
	if not monster_rows.has(monster_id):
		return

	var row: MonsterDeckRow = monster_rows[monster_id]
	row.active_card_display.set_card_data(card)
	await row.active_card_display.flip_to_front()


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
