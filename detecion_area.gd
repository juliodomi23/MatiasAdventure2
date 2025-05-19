extends Area2D

func _ready():
	# Verificar que la configuración es correcta
	print("Configuración de DetectionArea:")
	print("Layers:", collision_layer)
	print("Mask:", collision_mask)
	
	# Conectar señales manualmente si es necesario
	self.body_entered.connect(_on_body_entered)
	self.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	print("Body entered:", body.name)
	var shape = get_child(0) as CollisionShape2D
	if shape:
		print("Shape size:", shape.shape.get_rect())

func _on_body_exited(body):
	print("Body exited:", body.name)
