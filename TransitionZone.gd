extends Area2D

@export var target_marker: Marker2D
@export var camera_limits: Rect2
@onready var fade_layer = get_node("/root/MainScene/FadeLayer")  # Referencia directa

func _ready():
	# Verificar que encontramos el FadeLayer
	if not fade_layer:
		printerr("ERROR: No se encontró FadeLayer. Revisa la estructura de nodos.")
	connect("body_entered", _on_body_entered)

func _on_body_entered(body):
	if not body.is_in_group("Player"):
		return
	
	# 1. Verificar que tenemos todo lo necesario
	if not target_marker or not fade_layer:
		printerr("Faltan componentes requeridos")
		return
	
	# 2. Fade out
	fade_layer.fade_out()
	await fade_layer.fade_out_completed  # Esperar señal personalizada
	
	# 3. Transportar jugador
	body.global_position = target_marker.global_position
	body.force_update_transform()
	
	# 4. Pequeña espera
	await get_tree().process_frame
	
	# 5. Fade in
	fade_layer.fade_in()
