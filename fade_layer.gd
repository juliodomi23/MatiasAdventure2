extends CanvasLayer

signal fade_out_completed
signal fade_in_completed

@onready var animation_player = $Fade/AnimationPlayer

func fade_out():
	animation_player.play("fade_out")
	await animation_player.animation_finished
	emit_signal("fade_out_completed")

func fade_in():
	animation_player.play("fade_in")
	await animation_player.animation_finished
	emit_signal("fade_in_completed")
