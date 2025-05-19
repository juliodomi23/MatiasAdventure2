extends ProgressBar
# En tu script HealthBar.gd
func init_health(max_hp):
	max_value = max_hp
	value = max_hp
	visible = true

func update_health(current_hp):
	value = current_hp
	# Agrega efectos visuales si quieres
