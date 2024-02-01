# ----------------------------------------------------------------------------------- #
# -------------- FEEL FREE TO USE IN ANY PROJECT, COMMERCIAL OR NON-COMMERCIAL ------ #
# ---------------------- 3D PLATFORMER CONTROLLER BY SD STUDIOS --------------------- #
# ---------------------------- ATTRIBUTION NOT REQUIRED ----------------------------- #
# ----------------------------------------------------------------------------------- #

extends CharacterBody3D

# ---------- VARIABLES ---------- #

@export_category("Player Properties")
@export var jump_event_name = "Play_Jump"
@export var jump_landed_event_name = "Play_JumpLanded"
@export_group("Controller settings")
@export var move_speed : float = 6
@export var jump_force : float = 5
@export var follow_lerp_factor : float = 4
@export var jump_limit : int = 2

@export_group("Game Juice")
@export var jumpStretchSize := Vector3(0.8, 1.2, 0.8)

# Booleans
var is_grounded = false
var can_double_jump = false

# Onready Variables
@onready var model = $gobot
@onready var animation = $gobot/AnimationPlayer
@onready var spring_arm = %Gimbal

@onready var particle_trail = $ParticleTrail

@onready var ak_event_jump := $AkEvent3DJump

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * 2

# ---------- FUNCTIONS ---------- #

func _ready():
	Wwise.register_game_obj(self, "Player")

func _process(delta):
	player_animations()
	get_input(delta)
	
	# Smoothly follow player's position
	spring_arm.position = lerp(spring_arm.position, position, delta * follow_lerp_factor)
	
	# Player Rotation
	if is_moving():
		var look_direction = Vector2(velocity.z, velocity.x)
		model.rotation.y = lerp_angle(model.rotation.y, look_direction.angle(), delta * 12)
	
	if not is_grounded and is_on_floor():
		Wwise.post_event(jump_landed_event_name, self)
	
	# Check if player is grounded or not
	is_grounded = true if is_on_floor() else false
	
	# Handle Jumping
	if is_grounded:
		can_double_jump = true
	
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			perform_jump()
		elif can_double_jump:
			if is_moving():
				perform_flip_jump()
	
	velocity.y -= gravity * delta

func perform_jump():
	Wwise.post_event(jump_event_name, self)
	jumpTween()
	animation.play("Jump")
	velocity.y = jump_force

func perform_flip_jump():
	animation.play("Flip", -1, 2)
	velocity.y = jump_force
	await animation.animation_finished
	can_double_jump = false
	animation.play("Jump", 0.5)
	Wwise.post_event(jump_event_name, self)

func is_moving():
	return abs(velocity.z) > 0 || abs(velocity.x) > 0

func jumpTween():
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", jumpStretchSize, 0.1)
	tween.tween_property(self, "scale", Vector3(1,1,1), 0.1)

# Get Player Input
func get_input(_delta):
	var move_direction := Vector3.ZERO
	move_direction.x = Input.get_axis("move_left", "move_right")
	move_direction.z = Input.get_axis("move_forward", "move_back")
	
	# Move The player Towards Spring Arm/Camera Rotation
	move_direction = move_direction.rotated(Vector3.UP, spring_arm.rotation.y).normalized()
	velocity = Vector3(move_direction.x * move_speed, velocity.y, move_direction.z * move_speed)

	move_and_slide()

# Handle Player Animations
func player_animations():
	particle_trail.emitting = false
	
	if is_on_floor():
		if is_moving(): # Checks if player is moving
			animation.play("Run", 0.5)
			particle_trail.emitting = true
		else:
			animation.play("Idle", 0.5)
