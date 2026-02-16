extends Control
## UI panel with turn control buttons.

signal monster_turn_pressed
signal end_turn_pressed
signal simulate_survivors_pressed

@onready var monster_turn_btn: Button = $VBoxContainer/MonsterTurnButton
@onready var end_turn_btn: Button = $VBoxContainer/EndTurnButton
@onready var turn_label: Label = $VBoxContainer/TurnLabel
@onready var simulate_survivors_btn: Button = $VBoxContainer/SimulateSurvivorsButton


func _ready() -> void:
	monster_turn_btn.pressed.connect(_on_monster_turn_pressed)
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	simulate_survivors_btn.pressed.connect(_on_simulate_survivors_pressed)


func update_for_turn(turn: TurnState.Turn) -> void:
	match turn:
		TurnState.Turn.PLAYER:
			turn_label.text = "Player Turn"
			monster_turn_btn.disabled = false
			end_turn_btn.disabled = true
			simulate_survivors_btn.disabled = false
		TurnState.Turn.MONSTER:
			turn_label.text = "Monster Turn"
			monster_turn_btn.disabled = true
			end_turn_btn.disabled = false
			simulate_survivors_btn.disabled = true


func _on_monster_turn_pressed() -> void:
	monster_turn_pressed.emit()


func _on_end_turn_pressed() -> void:
	end_turn_pressed.emit()


## Disables or enables all turn control buttons.
## Used to prevent user input during monster AI turn execution.
func set_disabled(disabled: bool) -> void:
	monster_turn_btn.disabled = disabled
	end_turn_btn.disabled = disabled
	simulate_survivors_btn.disabled = disabled


func _on_simulate_survivors_pressed() -> void:
	simulate_survivors_pressed.emit()
