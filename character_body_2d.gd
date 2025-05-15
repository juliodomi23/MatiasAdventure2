extends CharacterBody2D

# Movimiento
@export var speed = 100
@export var acceleration = 15
@export var friction = 10

# Inventario
var ingredientes_recolectados: int = 0
var total_ingredientes: int = 3
@onready var ui_contador = get_node("/root/MainScene/UI/ContadorIngredientes")  # Asegúrate de que la ruta sea correcta

# Animaciones
@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	actualizar_ui()  # Inicializa el contador UI

func _physics_process(delta):
	# Movimiento (manteniendo tu lógica original)
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	input_vector = input_vector.normalized()
	
	if input_vector != Vector2.ZERO:
		velocity = velocity.lerp(input_vector * speed, acceleration * delta)
		
		# Animaciones
		if input_vector.x != 0:
			animated_sprite.flip_h = input_vector.x < 0
			animated_sprite.play("Run_Side")
		elif input_vector.y < 0:
			animated_sprite.play("Run_Up")
		elif input_vector.y > 0:
			animated_sprite.play("Run_Down")
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction * delta)
		animated_sprite.play("Idle")
	
	move_and_slide()

	# Detección de ingredientes (opcional: si usas señales no es necesario)
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider().is_in_group("ingredientes"):
			recolectar_ingrediente(collision.get_collider())

func recolectar_ingrediente(ingrediente: Node):
	ingredientes_recolectados += 1
	ingrediente.queue_free()  # Elimina el ingrediente de la escena
	actualizar_ui()

func actualizar_ui():
	ui_contador.text = "Ingredientes: %s/%s" % [ingredientes_recolectados, total_ingredientes]  # Formato corregido
	# Efecto visual opcional
	ui_contador.modulate = Color.GOLD
	await get_tree().create_timer(0.3).timeout
	ui_contador.modulate = Color.WHITE
