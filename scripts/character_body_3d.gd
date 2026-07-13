extends CharacterBody3D


const g = Vector3(0, -9.8, 0)
@export var jUp : int     # = 10
@export var s : float     # = 0.02

@onready var atlas = $axis/atlas
@onready var axis = $axis

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
			velocity += g * delta

			#get the input direction and handle the movement
			inputDirection = Input.get_vector("a", "d", "w", "s")
			direction = (axis.transform.basis * Vector3(inputDirection.x, 0, inputDirection.y)).normalized()

			if direction:
				velocity = (velocity + direction*state.moveSpeed).normalized()*velocity.length()

				if (velocity + direction).length() < velocity.length():
					velocity += direction*state.moveSpeed

			move_and_slide()

			#update state
			if is_on_floor():
				state = states.walk

		states.walk:
			#get the input direction and handle the movement
			inputDirection = Input.get_vector("a", "d", "w", "s")
			direction = (axis.transform.basis * Vector3(inputDirection.x, 0, inputDirection.y)).normalized()

			if direction:
				velocity.x = direction.x * state.moveSpeed
				velocity.z = direction.z * state.moveSpeed
			else:
				velocity = Vector3(0, velocity.y, 0)
				
			#handle jump
			if Input.is_action_just_pressed("ui_accept") and is_on_floor():
				velocity.y = jUp
				state = states.air

			move_and_slide()
