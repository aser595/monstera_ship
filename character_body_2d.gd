extends CharacterBody2D

const SPEED = 400.0
const JUMP_VELOCITY = -300.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _physics_process(delta: float) -> void:
	# الجاذبية
	if not is_on_floor():
		velocity += get_gravity() * delta

	# القفز
	if Input.is_action_just_pressed("JUMP") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# اتجاه الحركة: -1 شمال، 0 ثابت، 1 يمين
	var direction := Input.get_axis("MOVE_LEFT", "MOVE_RIGHT")

	# قلب الشخصية
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true

	# الأنيميشن
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
