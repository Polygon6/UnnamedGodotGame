extends CharacterBody3D


const g = Vector3(0, 9.8, 0)
@export var jUp : int     # = 10
@export var s : float     # = 0.02

@onready var atlas = $axis/atlas
@onready var axis = $axis

@onready var rayR = $axis/rayR
@onready var rayL = $axis/rayL

#for general movement
var inputDirection
var direction

#for wallrun
var wallAngle
var wallDirection
var ray

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
		"pseudoGravity" : g/4,
		"pullStrength" : 1,
		"speedLoss" : 0.003,
		"detachAngle" : 85,
		"attachAngle" : 60,
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
			rayR.force_raycast_update()
			rayL.force_raycast_update()

			if is_on_floor():
				if Input.is_action_pressed("ctrl"):
					state = states.slide
				elif Input.is_action_pressed("shift"):
					state = states.sprint
				else:
					state = states.walk
			elif (get_slide_collision_count() > 0) && (rayR.is_colliding() || rayL.is_colliding()):
				state = states.wallrun

				if rayR.is_colliding():
					ray = rayR
				else:
					ray = rayL

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
			print("wallrunning")
			print(velocity)
			print(Vector2(velocity.x, velocity.z).length())

			#raycast
			ray.force_raycast_update()

			#update wall data
			wallDirection = ray.get_collision_normal()

			#gravity
			velocity -= state.pseudoGravity * delta

			#friction
			velocity.x = velocity.x * (1-state.speedLoss)
			velocity.z = velocity.z * (1-state.speedLoss)

			#cling to wall
			move_and_collide(wallDirection*-1)

			if ray == rayR:
				velocity = Vector3(wallDirection.z*Vector2(velocity.x, velocity.z).length()*-1, velocity.y, wallDirection.x*Vector2(velocity.x, velocity.z).length())
			else:
				velocity = Vector3(wallDirection.z*Vector2(velocity.x, velocity.z).length(), velocity.y, wallDirection.x*Vector2(velocity.x, velocity.z).length()*-1)

			#update state
			if is_on_floor():
				if Input.is_action_pressed("ctrl"):
					state = states.slide
				elif Input.is_action_pressed("shift"):
					state = states.sprint
				else:
					state = states.walk

			move_and_slide()
