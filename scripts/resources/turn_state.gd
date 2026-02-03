class_name TurnState
extends Resource
## Manages tactical turn state (Player vs Monster).

signal turn_changed(new_turn: Turn)

enum Turn { PLAYER, MONSTER }

var current_turn: Turn = Turn.PLAYER


func set_turn(new_turn: Turn) -> void:
	if current_turn != new_turn:
		current_turn = new_turn
		turn_changed.emit(current_turn)


func toggle_turn() -> void:
	if current_turn == Turn.PLAYER:
		set_turn(Turn.MONSTER)
	else:
		set_turn(Turn.PLAYER)


func is_player_turn() -> bool:
	return current_turn == Turn.PLAYER


func is_monster_turn() -> bool:
	return current_turn == Turn.MONSTER
