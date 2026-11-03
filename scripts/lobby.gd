extends Control
## scenes/lobby.tscn: Control فاضي وحط عليه السكريبت ده، الواجهة بتتبني بالكود.

var name_edit: LineEdit
var ip_edit: LineEdit
var host_btn: Button
var join_btn: Button
var start_btn: Button
var pvp_check: CheckBox
var players_label: Label
var status_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "اسمك"
	name_edit.text = "Player"
	box.add_child(name_edit)

	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "IP الهوست"
	ip_edit.text = "127.0.0.1"
	box.add_child(ip_edit)

	host_btn = Button.new()
	host_btn.text = "Host"
	host_btn.pressed.connect(_on_host)
	box.add_child(host_btn)

	join_btn = Button.new()
	join_btn.text = "Join"
	join_btn.pressed.connect(_on_join)
	box.add_child(join_btn)

	# خانة الـ PvP: الهوست بس هو اللي يقدر يغيرها
	pvp_check = CheckBox.new()
	pvp_check.text = "PvP (اللاعبين يضربوا بعض)"
	pvp_check.button_pressed = Network.pvp_enabled
	pvp_check.disabled = true
	pvp_check.toggled.connect(func(on: bool): Network.set_pvp(on))
	box.add_child(pvp_check)

	players_label = Label.new()
	box.add_child(players_label)

	status_label = Label.new()
	box.add_child(status_label)

	start_btn = Button.new()
	start_btn.text = "Start Game"
	start_btn.visible = false
	start_btn.pressed.connect(Network.start_game)
	box.add_child(start_btn)

	Network.players_changed.connect(_refresh)
	Network.settings_changed.connect(_refresh_pvp)
	Network.connection_failed.connect(func(): status_label.text = "فشل الاتصال")
	_refresh()


func _on_host() -> void:
	var err := Network.host_game(name_edit.text.strip_edges())
	status_label.text = "أنت الهوست" if err == OK else "مش قادر يفتح السيرفر (%s)" % error_string(err)
	_set_buttons_enabled(err != OK)


func _on_join() -> void:
	var err := Network.join_game(ip_edit.text.strip_edges(), name_edit.text.strip_edges())
	status_label.text = "بيتصل..." if err == OK else "خطأ: %s" % error_string(err)
	_set_buttons_enabled(err != OK)


func _set_buttons_enabled(enabled: bool) -> void:
	host_btn.disabled = not enabled
	join_btn.disabled = not enabled


func _refresh() -> void:
	var lines: PackedStringArray = []
	for id in Network.players:
		lines.append("• " + Network.players[id]["name"])
	players_label.text = "اللاعبين (%d/%d):\n%s" % [Network.players.size(), Network.MAX_PLAYERS, "\n".join(lines)]
	start_btn.visible = multiplayer.is_server() and not Network.players.is_empty()
	_refresh_pvp()
	if Network.players.is_empty():
		_set_buttons_enabled(true)


func _refresh_pvp() -> void:
	pvp_check.set_pressed_no_signal(Network.pvp_enabled)
	# بس الهوست (السيرفر) يقدر يلمس الخانة
	var is_host := multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not Network.players.is_empty()
	pvp_check.disabled = not is_host
