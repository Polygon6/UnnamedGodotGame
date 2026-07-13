extends CharacterBody3D


const g = Vector3(0, -9.8, 0)
@export var jUp : int     # = 10
@export var s : float     # = 0.02

@onready var atlas = $axis/atlas
@onready var axis = $axis

#states dictionary
var states = {
	"walk":{
		"moveSpeed" : 9,
	},
	"air":{
		"moveSpeed" : 0.3,
		"moveSpeedDefault" : 0.3,
		"time" : 0,
		"timeLimit" : 0.5,
		"timeLimitDefault" : 0.5,
		"doubleJumps": 1,
		"doubleJumpsMax" : 1,
		"doubleJumpSpeed" : 1.2,
		"doubleJumpTime" : 1.2,
	},
}


var state = states.air

func resetAir():
	states.air.time = 0
	states.air.doubleJumps = states.air.doubleJumpsMax
	states.air.moveSpeed = states.air.moveSpeedDefault
	states.air.timeLimit = states.air.timeLimitDefault

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseMotion:
		axis.rotate_y(-event.relative.x*s)
		atlas.rotate_x(-event.relative.y*s)
		atlas.rotation.x = clamp(atlas.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	#update state
	if is_on_floor():
		state = states.walk
		resetAir()
	else:
		state = states.air
	
	#state match statement
	match state:
		states.air:
			#gravity
			velocity += g * delta

			#add to air time
			state.time += 1*delta

			#handle double jump
			if Input.is_action_just_pressed("ui_accept") and (state.doubleJumps > 0):
				velocity.y += jUp
				state.doubleJumps -= 1
				state.time = 0
				state.movementSpeed = state.doubleJumpSpeed
				state.timeLimit = state.doubleJumpTime

			#get the input direction and handle the movement
			var input_dir := Input.get_vector("a", "d", "w", "s")
			var direction = (axis.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

			if direction:
				velocity.x += direction.x * state.moveSpeed * (state.timeLimit - clamp(state.time, 0, state.timeLimit))
				velocity.z += direction.z * state.moveSpeed * (state.timeLimit - clamp(state.time, 0, state.timeLimit))

			move_and_slide()

		states.walk:
			#handle jump
			if Input.is_action_just_pressed("ui_accept") and is_on_floor():
				velocity.y = jUp

			#get the input direction and handle the movement
			var input_dir := Input.get_vector("a", "d", "w", "s")
			var direction = (axis.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

			if direction:
				velocity.x = direction.x * state.moveSpeed
				velocity.z = direction.z * state.moveSpeed
			else:
				velocity = Vector3(0, 0, 0)

			move_and_slide()
