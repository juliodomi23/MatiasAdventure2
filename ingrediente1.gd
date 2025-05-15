extends Area2D

func _ready():
	# Conectamos la señal de body_entered automáticamente
	body_entered.connect(_on_body_entered)
	# Opcional: Mostrar que el ingrediente está listo
	print("Ingrediente listo para recolectar en posición: ", global_position)

func _on_body_entered(body: Node):
	# Debug: Mostrar qué cuerpo entró en colisión
	print("Colisión detectada con: ", body.name)
	
	# Verificamos que sea el jugador (de dos formas alternativas)
	if body.is_in_group("player") or body.name == "Player":
		# Debug
		print("¡Jugador recolectó el ingrediente!")
		
		# Verificamos que el jugador tenga el script correcto
		if body.has_method("recolectar_ingrediente"):
			body.recolectar_ingrediente(self)
		else:
			# Si no tiene el método, hacemos la recolección básica
			if body.has_method("actualizar_ui"):
				body.ingredientes_recolectados += 1
				body.actualizar_ui()
				print("Ingredientes actuales: ", body.ingredientes_recolectados)
			else:
				print("Error: El jugador no tiene sistema de inventario")
		
		# Eliminamos el ingrediente
		queue_free()
	else:
		print("Colisión con objeto no jugador: ", body.name)

# Función opcional para mostrar el área de colisión
func _draw():
	draw_circle(Vector2.ZERO, $CollisionShape2D.shape.radius, Color(1, 0, 0, 0.3))
