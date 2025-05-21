extends CharacterBody2D

## CONFIGURACIÓN ##
@export var health := 30
@export var speed := 50
@export var damage := 10
@export var attack_cooldown := 2  
@export var knockback_force := 150
@export var detection_range := 300.0
@export var attack_range := 20
@export var stopping_distance := 15.0
@export var attack_hit_delay := 0.15 
@export var hurtbox_size := Vector2(15, 25)

## ESTADOS ##
enum State {IDLE, CHASING, ATTACKING, HURT}
var current_state = State.IDLE
var player_ref: Node2D = null
var can_attack := true
var is_dying := false
var attack_connecting := false  # Para evitar ataques superpuestos

## NODOS ##
@onready var animated_sprite := $AnimatedSprite2D
@onready var attack_ray := $AttackRayCast2D
@onready var detection_area := $DetectionArea
@onready var attack_timer := $AttackCooldownTimer
@onready var hurtbox := $HurtBox
@onready var state_label := $StateLabel

func _ready():
	# Configurar RayCast
	attack_ray.target_position = Vector2(0, attack_range)
	attack_ray.enabled = false
	attack_ray.collide_with_bodies = true
	
	# Configurar hurtbox
	var hurtbox_shape = hurtbox.get_child(0)
	hurtbox_shape.shape = RectangleShape2D.new()
	hurtbox_shape.shape.extents = hurtbox_size
	
	# Conexión de señales
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	attack_timer.timeout.connect(_on_attack_cooldown_timer_timeout)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	
	animated_sprite.play("idle")

func _physics_process(delta):
	match current_state:
		State.IDLE:
			idle_state()
		State.CHASING:
			chasing_state(delta)
		State.ATTACKING:
			attacking_state(delta)
		State.HURT:
			pass
	
	# Debug visual del estado
	if Engine.get_frames_drawn() % 10 == 0 && state_label:
		state_label.text = State.keys()[current_state] + "\n" + \
						 "Pos: " + str(global_position) + "\n" + \
						 "Vel: " + str(velocity) + "\n" + \
						 "Player: " + ("Sí" if player_ref else "No")

func idle_state():
	animated_sprite.play("idle")
	velocity = Vector2.ZERO

func chasing_state(delta):
	if player_ref == null:
		current_state = State.IDLE
		return
	
	var to_player = player_ref.global_position - global_position
	var distance_to_player = to_player.length()
	var direction = to_player.normalized()
	
	# Actualizar dirección del RayCast continuamente
	attack_ray.target_position = direction * attack_range
	
	# Movimiento con distancia de parada
	if distance_to_player > stopping_distance:
		velocity = direction * speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
	
	# Orientación del sprite
	animated_sprite.flip_h = direction.x < 0
	animated_sprite.play("walk")
	
	# Verificar rango de ataque
	#if distance_to_player <= attack_range && can_attack && !attack_connecting:
	#	current_state = State.ATTACKING
	#	start_attack()

func attacking_state(delta):
	if player_ref == null:
		current_state = State.IDLE
		return
	
	# Mantener orientación hacia el jugador
	var to_player = (player_ref.global_position - global_position).normalized()
	animated_sprite.flip_h = to_player.x < 0
	
	# Suavizar la transición al estado de chasing
	velocity = Vector2.ZERO

func is_attacking() -> bool:
	return animated_sprite.animation == "attack" && animated_sprite.is_playing()

func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO):
	if current_state == State.HURT or is_dying:
		return
	
	health = max(0, health - amount)
	current_state = State.HURT
	animated_sprite.play("hurt")
	
	print("💀 Esqueleto recibió daño:", amount, "| Vida restante:", health)
	
	# Knockback reducido
	var kb_force = knockback_force * 0.7
	
	if source_position != Vector2.ZERO:
		var knockback_dir = (global_position - source_position).normalized()
		velocity = knockback_dir * kb_force
		move_and_slide()
	
	# Duración más corta del estado HURT
	await get_tree().create_timer(0.3).timeout
	
	if health <= 0 and not is_dying:
		die()
	else:
		current_state = State.CHASING
		animated_sprite.play("walk")

func die():
	if is_dying:
		return
	
	is_dying = true
	set_physics_process(false)
	detection_area.monitoring = false
	hurtbox.monitoring = false
	current_state = State.HURT
	
	# Detener cualquier animación previa
	animated_sprite.stop()
	
	# Reproducir animación de muerte una sola vez
	print("☠️ Esqueleto murió - Iniciando animación de muerte")
	animated_sprite.play("die")
	
	# Esperar a que termine la animación antes de eliminar
	await animated_sprite.animation_finished
	print("✅ Animación de muerte completada")
	queue_free()

func start_attack():
	if player_ref == null or attack_connecting:
		current_state = State.IDLE
		return
	
	attack_connecting = true
	can_attack = false
	animated_sprite.play("attack")
	velocity = Vector2.ZERO
	
	# Orientar el ataque hacia el jugador
	var to_player = (player_ref.global_position - global_position).normalized()
	animated_sprite.flip_h = to_player.x < 0
	
	# Ajustes para animación de 4 frames:
	# 1. Esperar hasta que la animación realmente empiece
	await get_tree().process_frame
	
	# 2. Dividir la animación en tiempos proporcionales (4 frames)
	# Asumiendo que quieres que el ataque dure aproximadamente 0.6 segundos
	var frame_delay = 0.6 / 4  # 0.15s por frame
	
	# Frame 1 (inicio)
	await get_tree().create_timer(frame_delay).timeout
	
	# Frame 2 (pre-impacto)
	await get_tree().create_timer(frame_delay).timeout
	
	# Frame 3 (impacto - momento de detectar)
	attack_ray.target_position = to_player * attack_range
	attack_ray.force_raycast_update()
	
	if attack_ray.is_colliding():
		var body = attack_ray.get_collider()
		if body.name == "Player" and not body.invincible:
			print("💥 Golpe al jugador en frame de impacto!")
			body.take_damage(damage, global_position)
	
	# Frame 4 (recovery)
	await get_tree().create_timer(frame_delay).timeout
	
	# Esperar a que termine completamente la animación
	await animated_sprite.animation_finished
	
	attack_connecting = false
	current_state = State.CHASING
	attack_timer.start(attack_cooldown)

## SEÑALES ##
func _on_detection_area_body_entered(body):
	if body.name == "Player":
		player_ref = body
		current_state = State.CHASING
		print("👀 Esqueleto detectó al jugador")

func _on_detection_area_body_exited(body):
	if body.name == "Player":
		player_ref = null
		current_state = State.IDLE
		print("👀 Esqueleto perdió de vista al jugador")

func _on_attack_cooldown_timer_timeout():
	can_attack = true
	print("⏱️ Cooldown de ataque terminado")

func _on_hurtbox_area_entered(area):
	if area.is_in_group("player_attack"):
		var player = area.get_parent()
		if player.is_attacking and not player.invincible:
			print("⚔️ Esqueleto recibió golpe de jugador | Daño:", player.attack_damage)
			take_damage(player.attack_damage, player.global_position)
