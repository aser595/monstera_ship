extends CharacterBody2D

const SPEED = 400.0
const JUMP_VELOCITY = -300.0

# لون مختلف لكل لاعب (حسب ترتيبه في اللوبي)
const PLAYER_COLORS := [
	Color(1, 1, 1),
	Color(0.55, 0.8, 1.0),
	Color(0.6, 1.0, 0.6),
	Color(1.0, 0.6, 0.6),
]

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var name_label: Label = $NameLabel
@onready var camera: Camera2D = $Camera2D

var is_attacking := false

# بتتزامن عبر الـ MultiplayerSynchronizer عشان الباقي يشوفوا الأنيميشن
var synced_anim: StringName = &"default"
var synced_flip := false


func _enter_tree() -> void:
	# صاحب اللاعب = الـ peer اللي id بتاعه هو اسم الـ node
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	var ids := Network.players.keys()
	ids.sort()
	var index := maxi(ids.find(name.to_int()), 0)

	name_label.text = Network.players.get(name.to_int(), {}).get("name", "?")
	animated_sprite.modulate = PLAYER_COLORS[index % PLAYER_COLORS.size()]

	camera.enabled = is_multiplayer_authority()
	if is_multiplayer_authority():
		camera.make_current()
		var spawn := get_tree().current_scene.get_node_or_null("SpawnPoint") as Node2D
		var base := spawn.global_position if spawn else global_position
		global_position = base + Vector2(index * 80, 0)


func _process(_delta: float) -> void:
	# اللاعبين التانيين: بس بنعرض اللي جاي من الشبكة
	if is_multiplayer_authority():
		return
	animated_sprite.flip_h = synced_flip
	if animated_sprite.animation != synced_anim:
		animated_sprite.play(synced_anim)


func _physics_process(delta: float) -> void:
	# كل لاعب يتحكم في شخصيته هو بس
	if not is_multiplayer_authority():
		return

	# الجاذبية
	if not is_on_floor():
		velocity += get_gravity() * delta

	# الهجوم
	if Input.is_action_just_pressed("ATTACK") and not is_attacking:
		attack()

	# القفز
	if Input.is_action_just_pressed("JUMP") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# اتجاه الحركة
	var direction := Input.get_axis("MOVE_LEFT", "MOVE_RIGHT")

	# قلب الشخصية
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true
	synced_flip = animated_sprite.flip_h

	# الأنيميشن (بس لو مش بيهاجم)
	if not is_attacking:
		if not is_on_floor():
			_play("jump")
		elif direction == 0:
			_play("default")
		else:
			_play("run_1")

	# الحركة
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()


func _play(anim: StringName) -> void:
	animated_sprite.play(anim)
	synced_anim = anim


func attack() -> void:
	is_attacking = true
	_play("attack")
	await animated_sprite.animation_finished
	is_attacking = false
