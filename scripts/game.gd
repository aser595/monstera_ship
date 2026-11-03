extends Node2D
## الـ root بتاع scens/game.tscn
## تحته: Players (Node2D) + MultiplayerSpawner + SpawnPoint (Marker2D)

const PLAYER_SCENE := preload("res://scens/character_body_2d.tscn")

@onready var players_node: Node2D = $Players


func _ready() -> void:
	var peer := multiplayer.multiplayer_peer
	# لو شغلت game.tscn لوحده من الإديتور (F6) من غير لوبي: لعب فردي
	if peer == null or peer is OfflineMultiplayerPeer:
		Network.players = {1: {"name": "Player"}}
		_spawn_all_players()
		return

	if multiplayer.is_server():
		Network.all_players_loaded.connect(_spawn_all_players)
		multiplayer.peer_disconnected.connect(_remove_player)
	# بلّغ السيرفر إني حمّلت المشهد
	Network.player_loaded.rpc_id(1)


func _spawn_all_players() -> void:
	for id in Network.players.keys():
		var p := PLAYER_SCENE.instantiate()
		p.name = str(id)               # الاسم = peer id (مهم جداً)
		players_node.add_child(p, true)


func _remove_player(id: int) -> void:
	var node := players_node.get_node_or_null(str(id))
	if node:
		node.queue_free()
