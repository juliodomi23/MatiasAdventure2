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
@export var attack_range := 20

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
@onready var attack_ray = $AttackRayCast2D
@onready var health_bar = $"../UI/HealthBar"
@onready var ui_contador = get_node("/root/MainScene/UI/ContadorIngredientes")

func _ready():
	current_health = max_health
	health_bar.init_health(max_health)
	health_bar.update_health(current_health)
	actualizar_ui()
	
	# Configurar RayCast
	attack_ray.target_position = Vector2(0, attack_range)
	attack_ray.enabled = false
	attack_ray.collide_with_areas = false  # Solo detectar cuerpos físicos
	attack_ray.collide_with_bodies = true
	
	# Debug: Verificar configuración de nodos
	print("Configuración del Jugador:")
	print("RayCast configurado. Rango:", attack_range)
	print("Máscara de colisión RayCast:", attack_ray.get_collision_mask())
	print("Hurtbox:", hurtbox.get_child(0).shape.get_rect().size if hurtbox.get_child_count() > 0 else "NO HURTBOX")

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
	if !can_attack or is_attacking:
		return
	
	print("⚔️ Iniciando ataque...")
	is_attacking = true
	can_attack = false
	velocity = Vector2.ZERO
	
	# Animación de ataque según dirección
	if abs(attack_direction.x) > abs(attack_direction.y):
		animated_sprite.flip_h = attack_direction.x < 0
		animated_sprite.play("Attack_Side")
		# Ajustar RayCast para ataque horizontal
		attack_ray.target_position = Vector2(attack_range if !animated_sprite.flip_h else -attack_range, 0)

	elif attack_direction.y < 0:
		animated_sprite.play("Attack_Up")
		# Ajustar RayCast para ataque vertical arriba
		attack_ray.target_position = Vector2(0, -attack_range)

	else:
		animated_sprite.play("Attack_Down")
		# Ajustar RayCast para ataque vertical abajo
		attack_ray.target_position = Vector2(0, attack_range)
		var shape = RectangleShape2D.new()
		attack_ray.shape = shape
	
	print("🎯 Dirección ataque:", attack_ray.target_position)
	
	# Muestreo múltiple mejorado
	var hit_confirmed = false
	for i in range(1): 
		attack_ray.force_raycast_update()
		
		# Debug visual
		var debug_pos = attack_ray.global_position
		var debug_end = debug_pos + attack_ray.target_position
		
		if attack_ray.is_colliding():
			var body = attack_ray.get_collider()
			print("🔍 Intento", i+1, "| Colisión con:", body.name, "| Pos:", body.global_position)
			if body.is_in_group("enemies"):
				var dist = global_position.distance_to(body.global_position)
				print("✅ Enemigo a distancia:", dist, "/", attack_range)
				body.take_damage(attack_damage, global_position)
				hit_confirmed = true
				break
		
		await get_tree().create_timer(0.02).timeout  # Reducido el delay entre chequeos
	
	if not hit_confirmed:
		print("❌ No se detectó colisión con enemigos")
		# Debug: Dibujar el área de ataque fallida

	
	# Cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	
	print("🔄 Ataque completado, reiniciando estados")
	is_attacking = false
	can_attack = true
	animated_sprite.play("Idle")

func take_damage(damage: int, source_position: Vector2 = Vector2.ZERO):
	if invincible:
		return
	
	# Efecto visual
	modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	
	print("💢 Jugador recibió daño:", damage, "de", source_position)
	current_health -= damage
	health_bar.update_health(current_health)
	
	# Aplicar knockback
	if source_position != Vector2.ZERO:
		var knockback_dir = (global_position - source_position).normalized()
		velocity = knockback_dir * knockback_force
		move_and_slide()
	
	# Efecto de invencibilidad
	invincible = true
	print("🛡️ Invencibilidad activada por", invincibility_duration, "segundos")
	await get_tree().create_timer(invincibility_duration).timeout
	invincible = false
	print("🛡️ Invencibilidad desactivada")
	
	if current_health <= 0:
		die()

func die():
	print("☠️ Jugador murió")
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

func _on_hurtbox_area_entered(area):
	print("[Jugador] Área entró en hurtbox:", area.name, 
		  "| Owner:", area.owner.name if area.owner else "None", 
		  "| Grupos:", area.get_groups())
	
	if area.is_in_group("enemy_attack"):
		if area.owner and area.owner.has_method("take_damage"):
			print("⚔️ Recibiendo daño de:", area.owner.name)
			take_damage(area.damage, area.global_position)
		else:
			print("❌ El ataque no tiene owner válido")
	else:
		print("❌ El área no está en grupo 'enemy_attack'")

func _on_animated_sprite_2d_animation_finished():
	# Solo manejar transiciones de movimiento a idle
	if animated_sprite.animation in ["Run_Side", "Run_Up", "Run_Down"]:
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
