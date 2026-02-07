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
