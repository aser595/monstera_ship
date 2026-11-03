extends CharacterBody2D

const SPEED = 400.0
const JUMP_VELOCITY = -300.0

# --- القتال ---
const MAX_HEALTH := 100
const ATTACK_DAMAGE := 20
const HIT_FRAME := 2            # رقم فريم الأنيميشن اللي الضربة بتتحسب عنده
const HITBOX_OFFSET_X := 40.0   # بُعد الهيت بوكس عن مركز اللاعب
const RESPAWN_TIME := 2.0

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
@onready var health_bar: ProgressBar = $HealthBar
@onready var hitbox: Area2D = $Hitbox

var is_attacking := false
var hit_done := false
var base_color := Color.WHITE
var _last_health := MAX_HEALTH
var _base_hitbox_y := 0.0

# بتتزامن عبر الـ MultiplayerSynchronizer عشان الباقي يشوفوا الأنيميشن والصحة
var synced_anim: StringName = &"default"
var synced_flip := false
var health := MAX_HEALTH
var is_dead := false


func _enter_tree() -> void:
	# صاحب اللاعب = الـ peer اللي id بتاعه هو اسم الـ node
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	var ids := Network.players.keys()
	ids.sort()
	var index := maxi(ids.find(name.to_int()), 0)

	name_label.text = Network.players.get(name.to_int(), {}).get("name", "?")
	base_color = PLAYER_COLORS[index % PLAYER_COLORS.size()]
	animated_sprite.modulate = base_color

	_setup_health_bar()
	_base_hitbox_y = hitbox.position.y
	_last_health = health
	animated_sprite.frame_changed.connect(_on_frame_changed)

	camera.enabled = is_multiplayer_authority()
	if is_multiplayer_authority():
		camera.make_current()
		global_position = _spawn_position()


func _spawn_position() -> Vector2:
	var ids := Network.players.keys()
	ids.sort()
	var index := maxi(ids.find(name.to_int()), 0)
	var spawn := get_tree().current_scene.get_node_or_null("SpawnPoint") as Node2D
	var base := spawn.global_position if spawn else global_position
	return base + Vector2(index * 80, 0)


func _process(_delta: float) -> void:
	# الصحة + الظهور (كل الـ peers)
	health_bar.value = health
	_update_bar_color()
	animated_sprite.visible = not is_dead
	health_bar.visible = not is_dead
	name_label.visible = not is_dead
	if health < _last_health and not is_dead:
		_flash_hurt()
	_last_health = health

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

	# لو ميت: مفيش تحكم
	if is_dead:
		velocity.x = 0
		move_and_slide()
		return

	# الهجوم
	if Input.is_action_just_pressed("ATTACK") and not is_attacking:
		attack()

	# القفز
	if Input.is_action_just_pressed("JUMP") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# اتجاه الحركة
	var direction := Input.get_axis("MOVE_LEFT", "MOVE_RIGHT")

	# قلب الشخصية (مش بنقلب وقت الهجوم عشان الهيت بوكس ما يتلخبطش)
	if not is_attacking:
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


# ---------- الهجوم ----------

func attack() -> void:
	is_attacking = true
	hit_done = false
	# حط الهيت بوكس قدام اللاعب حسب اتجاهه
	var dir := -1.0 if animated_sprite.flip_h else 1.0
	hitbox.position = Vector2(60.0 + HITBOX_OFFSET_X * dir, _base_hitbox_y)
	_play("attack")
	await animated_sprite.animation_finished
	is_attacking = false


func _on_frame_changed() -> void:
	if not is_multiplayer_authority() or is_dead:
		return
	if animated_sprite.animation == &"attack" and animated_sprite.frame == HIT_FRAME and not hit_done:
		hit_done = true
		_do_hit()


func _do_hit() -> void:
	if not Network.pvp_enabled:
		return
	for body in hitbox.get_overlapping_bodies():
		if body == self or not body.is_in_group("players"):
			continue
		if body.is_dead:
			continue
		# الضرر بيتبعت لصاحب اللاعب المضروب (هو اللي بيخصم من صحته)
		body.take_damage.rpc_id(body.get_multiplayer_authority(), ATTACK_DAMAGE)


## بتتنفذ عند صاحب اللاعب المضروب بس
@rpc("any_peer", "call_remote", "reliable")
func take_damage(amount: int) -> void:
	if not is_multiplayer_authority() or is_dead:
		return
	if not Network.pvp_enabled:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and not Network.players.has(sender):
		return
	health = maxi(health - amount, 0)
	if health <= 0:
		_die()


func _die() -> void:
	is_dead = true
	is_attacking = false
	velocity = Vector2.ZERO
	await get_tree().create_timer(RESPAWN_TIME).timeout
	health = MAX_HEALTH
	global_position = _spawn_position()
	is_dead = false


# ---------- الهيلث بار ----------

func _setup_health_bar() -> void:
	health_bar.min_value = 0
	health_bar.max_value = MAX_HEALTH
	health_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	health_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 0.85, 0.3)
	health_bar.add_theme_stylebox_override("fill", fill)


func _update_bar_color() -> void:
	var fill := health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill == null:
		return
	var ratio := float(health) / MAX_HEALTH
	if ratio > 0.6:
		fill.bg_color = Color(0.2, 0.85, 0.3)
	elif ratio > 0.3:
		fill.bg_color = Color(0.95, 0.8, 0.2)
	else:
		fill.bg_color = Color(0.9, 0.2, 0.2)


func _flash_hurt() -> void:
	animated_sprite.modulate = Color(1, 0.3, 0.3)
	var t := create_tween()
	t.tween_property(animated_sprite, "modulate", base_color, 0.25)
