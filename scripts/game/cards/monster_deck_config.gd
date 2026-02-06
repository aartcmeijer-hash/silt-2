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
