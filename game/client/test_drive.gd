extends Node3D
## Playable flat-ground scene for judging how the car handles.
##
## Phase 1.3 replaces the ground plane with a real generated track; this exists
## so the handling can be felt before there is anywhere to drive.

const GROUND_EXTENT: float = 6000.0
const GROUND_THICKNESS: float = 4.0

const GROUND_SHADER := """
shader_type spatial;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = floor(world_position.xz / 12.0);
	float checker = mod(cell.x + cell.y, 2.0);
	ALBEDO = mix(vec3(0.21, 0.23, 0.25), vec3(0.15, 0.17, 0.19), checker);
	ROUGHNESS = 0.92;
	SPECULAR = 0.15;
}
"""

var _car: CarBody
var _controls: PlayerInput
var _autopilot: bool = false
var _elapsed: float = 0.0


func _ready() -> void:
	_build_environment()
	_build_ground()
	_spawn_car()
	_autopilot = GameConfig.args.has("autopilot")
	Log.info("TestDrive", "Ready (autopilot=%s)" % _autopilot)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_car.input = _scripted_input() if _autopilot else _controls.poll(delta)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("reset_car"):
		_reset()
	if Input.is_action_just_pressed("pause"):
		get_tree().quit()


## Drives itself so screenshots and captures show a car in motion rather than
## one parked at the origin.
func _scripted_input() -> DriverInput:
	return DriverInput.create(
		clampf(0.30 + _elapsed / 3.0, 0.0, 0.9),
		0.0,
		sin(_elapsed * 0.35) * 0.30
	)


func _reset() -> void:
	_elapsed = 0.0
	_controls.reset()
	_car.teleport_to(Transform3D(
		Basis.IDENTITY, Vector3(0.0, _car.setup.contact_depth() + 0.15, 0.0)
	))


func _spawn_car() -> void:
	_car = CarBody.new()
	_car.position = Vector3(0.0, _car.setup.contact_depth() + 0.15, 0.0)
	add_child(_car)

	var visuals := CarVisuals.new()
	visuals.car = _car
	add_child(visuals)

	var camera := ChaseCamera.new()
	camera.target = _car
	camera.current = true
	camera.far = 8000.0
	add_child(camera)

	# Controls need a CanvasLayer to be laid out against the screen rather
	# than inherit a 3D parent's zero-sized rect.
	var overlay := CanvasLayer.new()
	var hud := DrivingHud.new()
	hud.car = _car
	overlay.add_child(hud)
	add_child(overlay)

	_controls = PlayerInput.new()
	add_child(_controls)


func _build_ground() -> void:
	var shader := Shader.new()
	shader.code = GROUND_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader

	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_EXTENT, GROUND_EXTENT)
	var surface := MeshInstance3D.new()
	surface.mesh = plane
	surface.material_override = material

	var box := BoxShape3D.new()
	box.size = Vector3(GROUND_EXTENT, GROUND_THICKNESS, GROUND_EXTENT)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = Vector3(0.0, -GROUND_THICKNESS * 0.5, 0.0)

	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.add_child(shape)
	ground.add_child(surface)
	add_child(ground)


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.22, 0.36, 0.60)
	sky_material.sky_horizon_color = Color(0.62, 0.70, 0.78)
	sky_material.ground_horizon_color = Color(0.42, 0.44, 0.46)

	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.85

	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 38.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
