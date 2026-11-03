extends Node
## Autoload اسمه "Network" (Project Settings > Globals > Autoload)

const PORT := 7777
const MAX_PLAYERS := 4
const GAME_SCENE := "res://scens/game.tscn"
const LOBBY_SCENE := "res://scens/lobby.tscn"

signal players_changed
signal connection_failed
signal all_players_loaded
signal settings_changed

var players := {}          # peer_id -> {"name": String}
var my_name := "Player"
var players_loaded := 0
var pvp_enabled := true     # الهوست بس هو اللي بيغيرها من اللوبي


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# ---------- Host / Join ----------

func host_game(player_name: String) -> Error:
	my_name = player_name
	var peer := ENetMultiplayerPeer.new()
	# max_clients = 3 عشان الهوست نفسه هو اللاعب الرابع
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	players.clear()
	players[1] = {"name": player_name}   # الهوست دايماً id = 1
	players_changed.emit()
	settings_changed.emit()
	return OK


func join_game(address: String, player_name: String) -> Error:
	my_name = player_name
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	players_changed.emit()


# ---------- Player list (السيرفر هو المرجع) ----------

func _on_connected_ok() -> void:
	# العميل اتصل: يبعت اسمه للسيرفر
	_register_player.rpc_id(1, my_name)


@rpc("any_peer", "reliable")
func _register_player(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	players[id] = {"name": player_name}
	_sync_players.rpc(players)
	_sync_settings.rpc(pvp_enabled)   # اللاعب الجديد يعرف حالة الـ PvP


@rpc("authority", "call_local", "reliable")
func _sync_players(new_players: Dictionary) -> void:
	players = new_players
	players_changed.emit()


## الهوست بيشغّل/بيقفل الـ PvP
func set_pvp(enabled: bool) -> void:
	if multiplayer.is_server():
		_sync_settings.rpc(enabled)


@rpc("authority", "call_local", "reliable")
func _sync_settings(pvp: bool) -> void:
	pvp_enabled = pvp
	settings_changed.emit()


func _on_peer_connected(_id: int) -> void:
	pass   # التسجيل الفعلي بيحصل في _register_player


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		players.erase(id)
		_sync_players.rpc(players)


func _on_connected_fail() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	leave()
	get_tree().change_scene_to_file(LOBBY_SCENE)


# ---------- Start game ----------

func start_game() -> void:
	if multiplayer.is_server():
		_load_game.rpc()


@rpc("authority", "call_local", "reliable")
func _load_game() -> void:
	players_loaded = 0
	get_tree().change_scene_to_file(GAME_SCENE)


## كل لاعب يناديها لما يخلص تحميل المشهد. السيرفر بيعد لحد ما الكل يجهز.
@rpc("any_peer", "call_local", "reliable")
func player_loaded() -> void:
	if not multiplayer.is_server():
		return
	players_loaded += 1
	if players_loaded == players.size():
		all_players_loaded.emit()
