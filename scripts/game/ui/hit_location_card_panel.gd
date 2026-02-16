class_name HitLocationCardPanel
extends CanvasLayer
## Modal panel shown after a survivor lands hits on a monster.
## Displays drawn hit location cards as large buttons.
## Player clicks cards one at a time to choose wound order.

signal card_chosen(card: HitLocationCard)
signal all_cards_resolved()

var _cards: Array[HitLocationCard] = []
var _buttons: Array[Button] = []
var _vbox: VBoxContainer


func _ready() -> void:
	layer = 10

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 100)
	panel.offset_left = -200
	panel.offset_top = -250
	panel.offset_right = 200
	panel.offset_bottom = 250
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(outer_vbox)

	var title := Label.new()
	title.text = "Choose hit location to wound first:"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(title)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 8)
	outer_vbox.add_child(_vbox)


func setup(cards: Array[HitLocationCard]) -> void:
	_cards = cards.duplicate()
	_rebuild_buttons()


func _rebuild_buttons() -> void:
	for btn in _buttons:
		btn.queue_free()
	_buttons.clear()

	for i in range(_cards.size()):
		var card: HitLocationCard = _cards[i]
		var btn := Button.new()
		btn.text = card.card_name
		btn.custom_minimum_size = Vector2(0, 80)
		var idx := i
		btn.pressed.connect(func(): _on_card_pressed(idx))
		_vbox.add_child(btn)
		_buttons.append(btn)


func _on_card_pressed(index: int) -> void:
	var card: HitLocationCard = _cards[index]
	card_chosen.emit(card)
	_cards.remove_at(index)
	_rebuild_buttons()
	if _cards.is_empty():
		all_cards_resolved.emit()
		queue_free()
