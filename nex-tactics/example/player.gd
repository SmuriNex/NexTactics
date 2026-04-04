extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@export var Hp : int = 100
@onready var sprite: Sprite2D = $Sprite
@onready var hp_label: Label = $CanvasLayer/HpLabel


func _physics_process(delta: float) -> void:
	
	hp_label.text = str(Hp)
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
		if velocity.x > 0:
			sprite.scale.x = -1
		else:
			sprite.scale.x = 1
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()


func _on_contact_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		Hp = Hp - 10
		hp_label.text = str(Hp)
	
