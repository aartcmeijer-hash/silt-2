class_name HitLocationDeck
extends RefCounted
## Manages a monster's hit location card draw and discard piles.
## Auto-shuffles discard into draw when draw pile is exhausted.

var draw_pile: Array[HitLocationCard] = []
var discard_pile: Array[HitLocationCard] = []


func draw_card() -> HitLocationCard:
	if draw_pile.is_empty():
		if discard_pile.is_empty():
			push_error("HitLocationDeck.draw_card() called with empty deck")
			return null
		_shuffle_discard_into_deck()
	return draw_pile.pop_front()


func discard_card(card: HitLocationCard) -> void:
	if card:
		discard_pile.append(card)


func get_total_count() -> int:
	return draw_pile.size() + discard_pile.size()


func _shuffle_discard_into_deck() -> void:
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	draw_pile.shuffle()
