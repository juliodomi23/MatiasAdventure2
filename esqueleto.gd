extends CharacterBody2D

# Configuración de propiedades
@export var health := 30
@export var speed := 50
@export var sprint_speed := 80  # Velocidad cuando está cerca del jugador
@export var damage := 10
@export var attack_cooldown := 1.5
@export var chase_range := 300.0
@export var attack_range := 50.0
@export var stopping_distance := 20.0  # Distancia para detenerse cerca del jugador

# Estados del esqueleto
enum State {IDLE, CHASING, ATTACKING, HURT}
var current_state = State.IDLE
var player_ref: Node2D = null
var can_attack := true

# Referencias a nodos
@onready var animated_sprite := $AnimatedSprite2D
@onready var attack_area := $AttackArea
@onready var detection_area := $DetectionArea
@onready var attack_timer := $AttackCooldownTimer

func _ready():
	# Conexión segura de señales
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	else:
		push_error("DetectionArea no encontrado!")
	
	if attack_timer:
		attack_timer.timeout.connect(_on_attack_cooldown_timer_timeout)
	else:
		push_error("AttackCooldownTimer no encontrado!")
	
	animated_sprite.play("idle")

func _physics_process(delta):
	match current_state:
		State.IDLE:
			idle_state()
		State.CHASING:
			chasing_state(delta)
		State.ATTACKING:
			attacking_state()
		State.HURT:
			pass  # No hacer nada mientras está en estado de daño

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
	
	# Ajustar velocidad según la distancia
	var current_speed = speed
	if distance_to_player < attack_range * 1.5:  # Zona cercana
		current_speed = sprint_speed
	
	# Movimiento con distancia de parada
	if distance_to_player > stopping_distance:
		velocity = direction * current_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
	
	# Orientación del sprite
	animated_sprite.flip_h = direction.x < 0
	animated_sprite.play("walk")
	
	# Verificar si está en rango de ataque
	if distance_to_player <= attack_range and can_attack:
		current_state = State.ATTACKING
		start_attack()

func attacking_state():
	velocity = Vector2.ZERO
	if not is_attacking():
		current_state = State.CHASING

func is_attacking() -> bool:
	return animated_sprite.animation == "attack" and animated_sprite.is_playing()

func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO):
	if current_state == State.HURT:
		return
	
	health -= amount
	current_state = State.HURT
	animated_sprite.play("hurt")
	
	# Aplicar knockback si hay posición de origen
	if source_position != Vector2.ZERO:
		var knockback_dir = (global_position - source_position).normalized()
		velocity = knockback_dir * 150  # Fuerza de retroceso
		move_and_slide()
	
	await animated_sprite.animation_finished
	
	if health <= 0:
		die()
	else:
		current_state = State.CHASING

func die():
	animated_sprite.play("die")
	set_physics_process(false)
	attack_area.set_deferred("monitoring", false)
	detection_area.set_deferred("monitoring", false)
	await animated_sprite.animation_finished
	queue_free()

func start_attack():
	can_attack = false
	animated_sprite.play("attack")
	velocity = Vector2.ZERO
	
	# Esperar al frame de impacto
	await get_tree().create_timer(0.3).timeout
	
	# Aplicar daño si el jugador sigue en rango
	if attack_area.has_overlapping_bodies():
		for body in attack_area.get_overlapping_bodies():
			if body.name == "Player":
				body.take_damage(damage, global_position)
	
	# Esperar que termine la animación
	await animated_sprite.animation_finished
	
	# Volver a perseguir
	current_state = State.CHASING
	attack_timer.start(attack_cooldown)

func _on_detection_area_body_entered(body):
	if body.name == "Player":
		print("Jugador detectado - Iniciando persecución")
		player_ref = body
		current_state = State.CHASING

func _on_detection_area_body_exited(body):
	if body.name == "Player":
		print("Jugador perdió - Volviendo a estado IDLE")
		player_ref = null
		current_state = State.IDLE

func _on_attack_cooldown_timer_timeout():
	print("Ataque disponible nuevamente")
	can_attack = true
