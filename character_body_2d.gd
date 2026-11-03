extends CharacterBody2D

const SPEED = 400.0
const JUMP_VELOCITY = -300.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_attacking := false

func _physics_process(delta: float) -> void:
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

	# الأنيميشن (بس لو مش بيهاجم)
	if not is_attacking:
		if not is_on_floor():
			animated_sprite.play("jump")
		elif direction == 0:
			animated_sprite.play("default")
		else:
			animated_sprite.play("run_1")

	# الحركة
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func attack() -> void:
	is_attacking = true
	animated_sprite.play("attack")
	await animated_sprite.animation_finished
	is_attacking = false
