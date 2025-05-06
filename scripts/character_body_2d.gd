extends CharacterBody2D

#movement constants
const SPEED = 250.0
const GROUND_ACCELERATION = 5000.0
const AIR_ACCELERATION = 1000.0
const GROUND_FRICTION = 3500.0
const AIR_FRICTION = 500.0
const CROUCH_SPEED_REDUCTION = 0.5
const GRAVITY = 1500

#jump constants
const JUMP_BUFFER_WINDOW = 0.2
const COYOTE_TIME_WINDOW = 0.1
const CHARGE_JUMP_MAX_TIME = 2.0
const CHARGE_JUMP_MIN_TIME = 0.3
const GROUND_JUMP_VELOCITY = -600.0
const COYOTE_JUMP_VELOCITY = -700.0
const COYOTE_JUMP_FORWARD = 350.0
const CHARGED_JUMP_VELOCITY = -850.0

#nodes
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

#variables
var is_crouching := false
var is_charging_jump := false
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var charge_jump_timer := 0.0
var charge_percent := 0.0
var standing_cshape: CollisionShape2D
var crouching_cshape: CollisionShape2D

#functions
func _ready():
	camera.make_current()
	camera.limit_left = 0
	camera.limit_right = 5000
	camera.limit_top = -1000
	camera.limit_bottom = 5000
	
	standing_cshape = $StandingCollision
	crouching_cshape = $CrouchingCollision
	crouching_cshape.disabled = true
	
func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	
	update_timers(delta)
	handle_movement(delta)
	handle_jump()
	move_and_slide()
	update_animations()
	
	if velocity.y < 0 and Input.is_action_just_released("ui_accept"):
		velocity.y *= 0.5
		
	if Input.is_action_just_pressed("crouch"):
		crouch()
	elif Input.is_action_just_released("crouch"):
		stand()
		
func update_timers(delta: float) -> void:
	
	if is_on_floor():
		coyote_timer = COYOTE_TIME_WINDOW
	else:
		coyote_timer = max(coyote_timer - delta, 0)
		
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_WINDOW
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0)
		
	if is_on_floor() and is_crouching:
		if Input.is_action_pressed("crouch") and not is_charging_jump:
			is_charging_jump = true
			charge_jump_timer = 0.0
			print("charge starting...") #debug
			
		if is_charging_jump:
			charge_jump_timer = min(charge_jump_timer + delta, CHARGE_JUMP_MAX_TIME)
			charge_percent = min((charge_jump_timer / CHARGE_JUMP_MAX_TIME) * 100, 100)
			
			if fmod(charge_percent, 10) < 0.5:
				print("charge: ", charge_percent, "%")
				
	elif is_charging_jump:
		is_charging_jump = false
		if charge_jump_timer > 0:
			print("charge cancelled")
		charge_jump_timer = 0.0
		charge_percent = 0.0
		
func handle_movement(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var acceleration = GROUND_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	var friction = GROUND_FRICTION if is_on_floor() else AIR_FRICTION
	
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true
		
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * SPEED, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		
func crouch():
	if is_crouching:
		return
	is_crouching = true
	if is_crouching:
		standing_cshape.disabled = true
		crouching_cshape.disabled = false
	
func stand():
	if is_crouching == false:
		return
	is_crouching = false
	if is_crouching == false:
		standing_cshape.disabled = false
		crouching_cshape.disabled = true
	
func handle_jump() -> void:
	
	if jump_buffer_timer > 0 and is_on_floor() and not is_crouching:
		velocity.y = GROUND_JUMP_VELOCITY
		jump_buffer_timer = 0.0
		print("ground jump triggered | velocity: ", velocity.y) #debug
		
	elif jump_buffer_timer > 0 and coyote_timer > 0 and not is_charging_jump:
		velocity.y = COYOTE_JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		print("coyote jump triggered | velocity: ", velocity.y) #debug
		
	elif is_charging_jump and Input.is_action_pressed("ui_accept"):
		charge_percent = min((charge_jump_timer / CHARGE_JUMP_MAX_TIME) * 100, 100)
		if charge_jump_timer >= CHARGE_JUMP_MIN_TIME:
			var jump_power = lerp(CHARGED_JUMP_VELOCITY * 0.8, CHARGED_JUMP_VELOCITY,
								inverse_lerp(CHARGE_JUMP_MIN_TIME, CHARGE_JUMP_MAX_TIME, charge_jump_timer))
			velocity.y = jump_power
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
			print("crouch jump triggered | velocity: ", velocity.y) #debug
	
		is_charging_jump = false
		is_crouching = false
		standing_cshape.disabled = false
		crouching_cshape.disabled = true
		charge_jump_timer = 0.0
		charge_percent = 0.0
		
	elif is_on_floor() and velocity.y > 0:
		velocity.y = 0
		
func update_animations() -> void:
	var direction := Input.get_axis("move_left", "move_right")
	
	if is_on_floor():
		if direction == 0:
			if is_crouching:
				animated_sprite.play("crouch_down")
				if animated_sprite.animation_finished:
					animated_sprite.play("crouch_idle")
			else:
				animated_sprite.play("idle")
		else:
			if is_crouching:
				animated_sprite.play("crouch_idle")
			else:
				animated_sprite.play("walk")
	else:
		if velocity.y < 0:
			animated_sprite.play("jump")
		elif velocity.y > 0:
			animated_sprite.play("fall")
