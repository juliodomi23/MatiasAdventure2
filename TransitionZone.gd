# ZonaGeneracion.gd
extends Area2D

@export var esqueleto_scene: PackedScene
@export var max_enemies := 5
@export var spawn_interval := 3.0

var player_in_zone := false
var enemy_count := 0
var spawn_timer := 0.0

func _ready():
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)

func _process(delta):
	if player_in_zone and enemy_count < max_enemies:
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			spawn_enemy()
			spawn_timer = 0.0

func _on_body_entered(body):
	if body.name == "Player":
		player_in_zone = true

func _on_body_exited(body):
	if body.name == "Player":
		player_in_zone = false

func spawn_enemy():
	if esqueleto_scene and enemy_count < max_enemies:
		var enemy = esqueleto_scene.instantiate()
		get_parent().add_child(enemy)
		enemy.global_position = get_random_position_near_player()
		enemy.player_ref = $Player  # Asegúrate de que la referencia al jugador sea correcta
		enemy.add_to_group("enemies")
		enemy_count += 1
		
		# Conectar señal si el enemigo es eliminado
		enemy.tree_exiting.connect(_on_enemy_died)

func get_random_position_near_player():
	var player_pos = $Player.global_position
	var offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
	return player_pos + offset

func _on_enemy_died():
	enemy_count -= 1
