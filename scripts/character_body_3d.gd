extends CharacterBody3D


const g = Vector3(0, 9.8, 0)
var jUp = 8

var s = 0.02

@onready var atlas = $axis/atlas
@onready var axis = $axis

@onready var cam = $axis/atlas/Camera3D

@onready var col = $CollisionShape3D

@onready var rayR = $axis/rayR
@onready var rayL = $axis/rayL

@onready var timer = $Timer

#FOV
var targetFOV = 75
var FOVchangeSpeed = 0.25

#for general movement
var inputDirection
var direction

#for slide
var slideScale = 0.25
var slideScalingSpeed = 0.06
var slideFOVcoefficient = 1.1

#for wallrun
var wallrunTilt = 5
var wallrunTiltChangeRate = 0.4

var wallAngle
var wallDirection
var ray
var collision
var wallrunCooldown = 0
var lastNormal

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
		"crouchSpeed" : 3,
		"speedLoss" : 0.006,
		"stopSpeed" : 4.5,
	},
	"sprint":{
		"moveSpeed" : 0.5,
		"maxSpeed" : 20,
		"acceleration" : 0.1
	},
	"wallrun":{
		"pullStrength" : 1,
		"speedLoss" : 0.003,

		"detachAngle" : 80,
		"attachAngle1" : -60,
		"attachAngle2" : 10,

		"walljumpUp" : 8,
		"walljumpForward" : 6,
		"walljumpAway" : 16,
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
	timer.timeout.connect(_on_timeout)

func _on_timeout():
	if wallrunCooldown > 0:
		wallrunCooldown -= 1
	else:
		timer.stop()

func _physics_process(delta: float) -> void:
	#provisional sensetivity settings
	if Input.is_action_just_pressed("k"):
		s += 0.002
	if Input.is_action_just_pressed("l"):
		s = clamp(s - 0.002, 0.001, 999)

	#camera effects
	handledWallrunCam()
	handleCamSpeedVFX()
	handleSlideLowering()
	setFOV()

	match state:
		states.air:
			#gravity
			velocity -= (g * delta)

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
			elif (get_slide_collision_count() > 0) && (rayR.is_colliding() || rayL.is_colliding()) && (wallrunCooldown <= 0):
				if rayR.is_colliding():
					ray = rayR
				else:
					ray = rayL

				wallAngle = rad_to_deg(ray.get_collision_normal().angle_to(Vector3(sin(axis.global_rotation.y), 0, cos(axis.global_rotation.y))))-90
				if (wallAngle < states.wallrun.attachAngle2) && (wallAngle >= states.wallrun.attachAngle1):
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

			#crouch
			if velocity == Vector3(0, velocity.y, 0):
				if direction:
					velocity.x = direction.x * state.crouchSpeed
					velocity.z = direction.z * state.crouchSpeed
				else:
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
			#raycast
			ray.force_raycast_update()

			#update wall data
			lastNormal = wallDirection
			wallDirection = ray.get_collision_normal()
			wallAngle = rad_to_deg(ray.get_collision_normal().angle_to(Vector3(sin(axis.global_rotation.y), 0, cos(axis.global_rotation.y))))-90

			if lastNormal == null:
				lastNormal = wallDirection

			#gravity
			velocity -= (g * delta)

			#friction
			velocity.x = velocity.x * (1-state.speedLoss)
			velocity.z = velocity.z * (1-state.speedLoss)

			#cling to wall
			collision = move_and_collide(wallDirection*state.pullStrength*-1)

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

				wallDirection = null
			else:
				if Input.is_action_just_pressed("space") || (collision == null) || (wallAngle > state.detachAngle) || (snapped(rad_to_deg(abs(lastNormal.angle_to(wallDirection))), 1) == 90):
					velocity.y += state.walljumpUp
				
					if ray == rayR:
						velocity += Vector3(velocity.normalized().x*state.walljumpForward, 0, velocity.normalized().z*state.walljumpForward)
						velocity += Vector3(velocity.normalized().z*state.walljumpAway, 0, velocity.normalized().x*state.walljumpAway*-1)
					else:
						velocity += Vector3(velocity.normalized().x*state.walljumpForward, 0, velocity.normalized().z*state.walljumpForward)
						velocity += Vector3(velocity.normalized().z*state.walljumpAway*-1, 0, velocity.normalized().x*state.walljumpAway)

					state = states.air
					wallrunCooldown = 5
					timer.start()
					wallDirection = null

			move_and_slide()

func handleCamSpeedVFX():
	#quadratic equation
	var x = velocity.length()*-1
	var a = 0.172616
	var b = -4.20233
	var c = 100

	if velocity.length() > 14:
		if state == states.slide:
			targetFOV = clamp((a*(x*x) - b*x + c), 75, 100)*slideFOVcoefficient
		else:
			targetFOV = clamp((a*(x*x) - b*x + c), 75, 100)
	else:
		if state == states.slide:
			targetFOV = 75*slideFOVcoefficient
		else:
			targetFOV = 75

func handledWallrunCam():
	if state == states.wallrun:
		if ray == rayR:
			cam.rotation.z = deg_to_rad(clamp(rad_to_deg(cam.rotation.z) + wallrunTiltChangeRate, wallrunTilt*-1, wallrunTilt))
		else:
			cam.rotation.z = deg_to_rad(clamp(rad_to_deg(cam.rotation.z) - wallrunTiltChangeRate, wallrunTilt*-1, wallrunTilt))
	else:
		if ray == rayR:
			cam.rotation.z = deg_to_rad(clamp(rad_to_deg(cam.rotation.z) - wallrunTiltChangeRate, 0, wallrunTilt))
		else:
			cam.rotation.z = deg_to_rad(clamp(rad_to_deg(cam.rotation.z) + wallrunTiltChangeRate, wallrunTilt*-1, 0))

func handleSlideLowering():
	if state == states.slide:
		col.scale.y = clamp(col.scale.y - slideScalingSpeed, slideScale, 1)
	else:
		col.scale.y = clamp(col.scale.y + slideScalingSpeed, slideScale, 1)

func setFOV():
	if cam.fov < targetFOV:
		cam.fov = clamp(cam.fov + (FOVchangeSpeed * (targetFOV - cam.fov)), cam.fov, targetFOV)
	elif cam.fov > targetFOV:
		cam.fov = clamp(cam.fov - (FOVchangeSpeed * (cam.fov - targetFOV)), targetFOV, cam.fov)
