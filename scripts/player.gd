extends CharacterBody2D
## scenes/player.tscn
## Nodes: CharacterBody2D (الـ root) + CollisionShape2D + Sprite2D + Camera2D + Label
##        + MultiplayerSynchronizer (بيزامن position)

const SPEED := 300.0

@onready var name_label: Label = $Label
@onready var camera: Camera2D = $Camera2D


func _enter_tree() -> void:
	# صاحب اللاعب ده هو الـ peer اللي id بتاعه = اسم الـ node
	# لازم يتحط هنا (قبل _ready) عشان الـ Synchronizer يشوفه
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	name_label.text = Network.players.get(name.to_int(), {}).get("name", "?")
	camera.enabled = is_multiplayer_authority()
	if is_multiplayer_authority():
		camera.make_current()
		# مكان البداية حسب ترتيب اللاعب
		var ids := Network.players.keys()
		ids.sort()
		global_position = Vector2(200 + ids.find(name.to_int()) * 100, 300)


func _physics_process(_delta: float) -> void:
	# كل واحد يتحكم في لاعبه هو بس
	if not is_multiplayer_authority():
		return
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * SPEED
	move_and_slide()
