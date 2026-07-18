extends CharacterBody3D


const g = Vector3(0, 9.8, 0)
@export var jUp : int     # = 10
@export var s : float     # = 0.02

@onready var atlas = $axis/atlas
@onready var axis = $axis

@onready var rayR = $axis/rayR
@onready var rayL = $axis/rayL

#for movement
var inputDirection
var direction

#states dictionary
var states = {
	"walk":{
		"moveSpeed" : 9,
	},
	"air":{
		"moveSpeed" : 0.3,
	},
	"slide":{
		"moveSpeed" : 0.3,
		"speedLoss" : 0.006,
		"stopSpeed" : 3,
	},
	"sprint":{
		"moveSpeed" : 0.5,
		"maxSpeed" : 20,
		"acceleration" : 0.1
	},
	"wallrun":{
		"speedLoss" : 0.006,
		"stopSpeed" : 3,
	},
}

var state = states.air

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseMotion:
		axis.rotate_y(-event.relative.x*s)
		atlas.rotate_x(-event.relative.y*s)
		atlas.rotation.x = clamp(atlas.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	#state match statement
	match state:
		states.air:
			#gravity
			velocity -= g * delta

			#get the input direction and handle the movement
			inputDirection = Input.get_vector("a", "d", "w", "s")
			direction = (axis.transform.basis * Vector3(inputDirection.x, 0, inputDirection.y)).normalized()

			if direction:
				velocity = (velocity + direction*state.moveSpeed).normalized()*velocity.length()

				if (velocity + direction).length() < velocity.length():
					velocity += direction*state.moveSpeed

			#update state
			if is_on_floor():
				if Input.is_action_pressed("ctrl"):
					state = states.slide
				elif Input.is_action_pressed("shift"):
					state = states.sprint
				else:
					state = states.walk
			elif Input.is_action_pressed("q"):
				state = states.wallrun

			move_and_slide()

		states.walk:
			#get the input direction and handle the movement
			inputDirection = Input.get_vector("a", "d", "w", "s")
			direction = (axis.transform.basis * Vector3(inputDirection.x, 0, inputDirection.y)).normalized()

			if direction:
				velocity.x = direction.x * state.moveSpeed
				velocity.z = direction.z * state.moveSpeed
			else:
				velocity = Vector3(0, velocity.y, 0)
				
			#update state and handle jump
			if not is_on_floor():
				state = states.air
			elif Input.is_action_just_pressed("space"):
				velocity.y = jUp
				state = states.air
			elif Input.is_action_just_pressed("ctrl"):
				state = states.slide
			elif Input.is_action_just_pressed("shift"):
				state = states.sprint

			move_and_slide()

		states.slide:
			#get the input direction and handle the movement
			inputDirection = Input.get_vector("a", "d", "w", "s")
			direction = (axis.transform.basis * Vector3(inputDirection.x, 0, inputDirection.y)).normalized()

			if direction:
				velocity = (velocity + direction*state.moveSpeed).normalized()*velocity.length()

			#friction
			velocity = velocity * (1-state.speedLoss)

			if velocity.length() < state.stopSpeed:
				velocity = Vector3(0, velocity.y, 0)

			#update state and handle jump
			if not is_on_floor():
				state = states.air
			elif Input.is_action_just_pressed("space"):
				velocity.y = jUp
				state = states.air
			elif Input.is_action_just_released("ctrl"):
				if Input.is_action_pressed("shift"):
					state = states.sprint
				else:
					state = states.walk

			move_and_slide()

		states.sprint:
			#get the input direction and handle the movement and friction
			inputDirection = Input.get_vector("a", "d", "w", "s")
			direction = (axis.transform.basis * Vector3(inputDirection.x, 0, inputDirection.y)).normalized()

			if direction:
				#accelerate
				if velocity.length() < state.maxSpeed:
					velocity.x += direction.x * state.acceleration
					velocity.z += direction.z * state.acceleration
				elif velocity.length() > state.maxSpeed:
					velocity = velocity.normalized()*state.maxSpeed

				#turn
				velocity = (velocity + direction*state.moveSpeed).normalized()*velocity.length()

			#update state and handle jump
			if not is_on_floor():
				state = states.air
			elif Input.is_action_just_pressed("space"):
				velocity.y = jUp
				state = states.air
			elif Input.is_action_just_pressed("ctrl"):
				state = states.slide
			elif Input.is_action_just_released("shift"):
				state = states.walk

			move_and_slide()

		states.wallrun:
			#gravity
			velocity -= g * delta

			#get wall direaction and push against wall
			var wallDirection = Vector3(0, 0, 0)
			velocity += wallDirection

			rayR.force_raycast_update()
			rayL.force_raycast_update()

			var rayRrot = rayR.global_rotation.y
			var rayLrot = rayL.global_rotation.y
			print(rad_to_deg( rayR.get_collision_normal().angle_to(Vector3(sin(rayRrot), 0, cos(rayRrot))) ))
			print(rad_to_deg( rayL.get_collision_normal().angle_to(Vector3(sin(rayLrot), 0, cos(rayLrot))) ))

			#update state and handle wall jump
			if is_on_floor():
				if Input.is_action_pressed("ctrl"):
					state = states.slide
				elif Input.is_action_pressed("shift"):
					state = states.sprint
				else:
					state = states.walk

			move_and_slide()
