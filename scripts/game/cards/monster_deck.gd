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
