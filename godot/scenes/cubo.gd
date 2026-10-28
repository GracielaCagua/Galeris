extends CharacterBody3D

@export var velocidad := 5.0

func _physics_process(_delta):
	var direccion := Vector3.ZERO

	if Input.is_physical_key_pressed(KEY_W):
		direccion.z -= 1.0

	if Input.is_physical_key_pressed(KEY_S):
		direccion.z += 1.0

	if Input.is_physical_key_pressed(KEY_A):
		direccion.x -= 1.0

	if Input.is_physical_key_pressed(KEY_D):
		direccion.x += 1.0

	direccion = direccion.normalized()

	velocity.x = direccion.x * velocidad
	velocity.z = direccion.z * velocidad

	move_and_slide()
