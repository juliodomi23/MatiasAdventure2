extends Camera2D

func _ready():
	# Asegurar que la cámara sigue al jugador
	position_smoothing_enabled = true
	position_smoothing_speed = 5.0
