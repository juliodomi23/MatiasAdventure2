extends CharacterBody2D

## MOVIMIENTO ##
@export var speed = 100
@export var acceleration = 15
@export var friction = 10

## COMBATE ##
@export var max_health := 100
@export var attack_damage := 15
@export var attack_cooldown := 0.5
@export var knockback_force := 200
@export var invincibility_duration := 0.5

var current_health: int
var is_attacking := false
var can_attack := true
var attack_direction := Vector2.DOWN
var invincible := false

## INVENTARIO ##
var ingredientes_recolectados: int = 0
var total_ingredientes: int = 3

## NODOS ##
@onready var animated_sprite = $AnimatedSprite2D
@onready var hurtbox = $HurtBox
@onready var hitbox = $Hitbox/CollisionShape2D
@onready var health_bar = $"../UI/HealthBar"
@onready var ui_contador = get_node("/root/MainScene/UI/ContadorIngredientes")

func _ready():
	current_health = max_health
	health_bar.init_health(max_health)
	health_bar.update_health(current_health)
	actualizar_ui()
	hitbox.disabled = true

func _physics_process(delta):
	if is_attacking:
		return
	
	handle_movement(delta)
	move_and_slide()
	check_ingredient_collisions()
	
	if Input.is_action_just_pressed("attack") and can_attack:
		attack()

func handle_movement(delta):
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	input_vector = input_vector.normalized()
	
	if input_vector != Vector2.ZERO:
		velocity = velocity.lerp(input_vector * speed, acceleration * delta)
		attack_direction = input_vector
		update_movement_animation(input_vector)
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction * delta)
		animated_sprite.play("Idle")

func update_movement_animation(input_vector):
	if input_vector.x != 0:
		animated_sprite.flip_h = input_vector.x < 0
		animated_sprite.play("Run_Side")
	elif input_vector.y < 0:
		animated_sprite.play("Run_Up")
	elif input_vector.y > 0:
		animated_sprite.play("Run_Down")

func attack():
	is_attacking = true
	can_attack = false
	velocity = Vector2.ZERO
	
	# Animación de ataque según dirección
	if abs(attack_direction.x) > abs(attack_direction.y):
		animated_sprite.flip_h = attack_direction.x < 0
		animated_sprite.play("Attack_Side")
	elif attack_direction.y < 0:
		animated_sprite.play("Attack_Up")
	else:
		animated_sprite.play("Attack_Down")
	
	# Activar hitbox con temporizador
	await get_tree().create_timer(0.2).timeout
	if is_attacking:
		hitbox.disabled = false
		await get_tree().create_timer(0.1).timeout
		hitbox.disabled = true
	
	# Cooldown del ataque
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true
	is_attacking = false

func take_damage(damage: int, source_position: Vector2 = Vector2.ZERO):
	if invincible:
		return
	
	current_health -= damage
	health_bar.update_health(current_health)
	
	# Aplicar knockback
	if source_position != Vector2.ZERO:
		var knockback_dir = (global_position - source_position).normalized()
		velocity = knockback_dir * knockback_force
		move_and_slide()
	
	# Efecto de invencibilidad
	invincible = true
	await get_tree().create_timer(invincibility_duration).timeout
	invincible = false
	
	if current_health <= 0:
		die()

func die():
	animated_sprite.play("Die")
	set_physics_process(false)
	hurtbox.set_deferred("disabled", true)
	await animated_sprite.animation_finished
	get_tree().reload_current_scene()

func check_ingredient_collisions():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider().is_in_group("ingredientes"):
			recolectar_ingrediente(collision.get_collider())

func _on_hitbox_body_entered(body):
	if body.is_in_group("enemies") and is_attacking:
		body.take_damage(attack_damage, global_position)

func _on_hurtbox_area_entered(area):
	if area.is_in_group("enemy_attack"):
		take_damage(area.damage, area.global_position)

func _on_animated_sprite_2d_animation_finished():
	if animated_sprite.animation.begins_with("Attack"):
		is_attacking = false
		animated_sprite.play("Idle")

func recolectar_ingrediente(ingrediente: Node):
	ingredientes_recolectados += 1
	ingrediente.queue_free()
	
	# Efecto visual mejorado
	var tween = create_tween()
	tween.tween_property(ui_contador, "modulate", Color.GOLD, 0.1)
	tween.tween_property(ui_contador, "scale", Vector2(1.2, 1.2), 0.1)
	tween.parallel().tween_property(ui_contador, "modulate", Color.WHITE, 0.3)
	tween.parallel().tween_property(ui_contador, "scale", Vector2(1, 1), 0.3)
	
	actualizar_ui()
	
	if ingredientes_recolectados >= total_ingredientes:
		ui_contador.text = "¡Todos los ingredientes recolectados!"

func actualizar_ui():
	ui_contador.text = "Ingredientes: %d/%d" % [ingredientes_recolectados, total_ingredientes]
