class_name RoyaleUI
extends EventUI

var _ended := false
var _spectating_player: Player
var _alive_players: Array[Player]

@rpc("call_local", "reliable")
func set_alive_players(count: int) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	($Main/PlayerCounter as Label).text = str(count)


@rpc("reliable", "call_local")
func show_winner(winner: int, winner_name: String) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	
	_ended = true
	if winner == multiplayer.get_unique_id():
		($Main/GameEnd as Label).text = "ТЫ ПОБЕДИЛ!!!"
	else:
		($Main/GameEnd as Label).text = "ПОБЕДИТЕЛЬ: %s" % winner_name
	($Main/GameEnd/AnimationPlayer as AnimationPlayer).play(&"Victory")
	($Main/SpectatorMenu as CanvasItem).hide()


@rpc("reliable", "call_local")
func kill_player(which: int, killer: int) -> void:
	if multiplayer.get_remote_sender_id() != MultiplayerPeer.TARGET_PEER_SERVER:
		push_error("This method must be called only by server.")
		return
	if Globals.headless:
		return
	
	_alive_players = Array(get_tree().get_nodes_in_group(&"Player"), TYPE_OBJECT,
			&"CharacterBody2D", Player)
	for player: Player in _alive_players:
		if player.id == which:
			_alive_players.erase(player)
			break
	if _alive_players.is_empty() or which != _spectating_player.id:
		return
	if killer < 0:
		_set_player_to_spectate(randi() % _alive_players.size())
		return
	for idx: int in range(_alive_players.size()):
		if _alive_players[idx].id == killer:
			_set_player_to_spectate(idx)


func show_defeat() -> void:
	if _ended:
		return
	($Main/GameEnd as Label).text = "ПОРАЖЕНИЕ!"
	($Main/GameEnd/AnimationPlayer as AnimationPlayer).play(&"Defeat")
	($Main/SpectatorMenu as CanvasItem).show()


func next_player() -> void:
	var new_id: int = (_alive_players.find(_spectating_player) + 1) % _alive_players.size()
	_set_player_to_spectate(new_id)


func previous_player() -> void:
	var new_id: int = (_alive_players.find(_spectating_player) + _alive_players.size() - 1) \
			% _alive_players.size()
	_set_player_to_spectate(new_id)


func _set_player_to_spectate(idx: int) -> void:
	_spectating_player = _alive_players[idx]
	(%SpectatingName as Label).text = _spectating_player.player_name
	(get_viewport().get_camera_2d() as SmartCamera).target = _spectating_player


func _on_local_player_created(player: Player) -> void:
	_spectating_player = player
