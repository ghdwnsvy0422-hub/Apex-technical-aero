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
var _track: Track
var _controls: PlayerInput
var _top_camera: Camera3D
var _autopilot: bool = false
var _elapsed: float = 0.0
var _ticks: int = 0


func _ready() -> void:
	_build_environment()
	if GameConfig.args.has("flat"):
		_build_ground()
	else:
		_build_track()
	_spawn_car()
	_autopilot = GameConfig.args.has("autopilot")
	Log.info("TestDrive", "Ready (autopilot=%s)" % _autopilot)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_car.input = _scripted_input() if _autopilot else _controls.poll(delta)
	_ticks += 1
	if _autopilot and _ticks % 480 == 0:
		Log.info("TestDrive", "t=%.0f v=%.0f steer=%+.2f grounded=%d pos=%v" % [
			_elapsed, _car.speed_kph(), _car.input.steer, _car.grounded_wheel_count(),
			_car.global_position.snapped(Vector3.ONE)])


func _process(_delta: float) -> void:
	if _top_camera != null:
		var heading := _car.global_transform.basis * Vector3.FORWARD
		_top_camera.global_position = _car.global_position + Vector3(0.0, 46.0, 0.0) - heading * 24.0
		_top_camera.look_at(_car.global_position + heading * 12.0, Vector3.UP)

	if Input.is_action_just_pressed("reset_car"):
		_reset()
	if Input.is_action_just_pressed("pause"):
		get_tree().quit()


## Drives itself so a capture shows a car in motion rather than one parked at
## the origin. Deliberately crude: this only has to keep the car roughly on the
## road for a screenshot. The real racing-line driver arrives in Phase 1.7.
func _scripted_input() -> DriverInput:
	var throttle := clampf(0.25 + _elapsed / 4.0, 0.0, 0.55)
	if _track == null:
		return DriverInput.create(throttle, 0.0, sin(_elapsed * 0.35) * 0.30)
	return DriverInput.create(throttle, 0.0, _steer_towards_centreline())


func _steer_towards_centreline() -> float:
	var curve := _track.curve
	var here := _car.global_position
	var offset := curve.get_closest_offset(here)
	# Aim well ahead of the car: steering at the point beside it produces a
	# permanent weave, because any correction arrives after the error has gone.
	var lookahead := clampf(_car.linear_velocity.length() * 1.1, 25.0, 90.0)
	var target := _track.frame_at_distance(offset + lookahead).origin

	var forward := _car.global_transform.basis * Vector3.FORWARD
	var to_target := (target - here)
	to_target.y = 0.0
	if to_target.length_squared() < 1.0:
		return 0.0
	# forward x up is the car's right, so a positive component means the target
	# lies to the right and the car must steer right.
	var lateral := to_target.normalized().dot(forward.cross(Vector3.UP).normalized())
	return clampf(lateral * 3.0, -1.0, 1.0)


func _reset() -> void:
	_elapsed = 0.0
	_controls.reset()
	_car.teleport_to(_start_transform())


func _start_transform() -> Transform3D:
	var ride_height := _car.setup.contact_depth() + 0.15
	if _track == null:
		return Transform3D(Basis.IDENTITY, Vector3(0.0, ride_height, 0.0))
	return _track.start_transform(ride_height)


func _build_track() -> void:
	_track = Track.new()
	_track.curve = CurveBuilder.oval(900.0, 260.0, 6.0)
	add_child(_track)
	_track.build()


func _spawn_car() -> void:
	_car = CarBody.new()
	_car.transform = _start_transform()
	add_child(_car)

	var visuals := CarVisuals.new()
	visuals.car = _car
	add_child(visuals)

	if GameConfig.args.has("topdown"):
		# A grazing chase view cannot show whether the kerbs, runoff and
		# barrier are actually where the profile says they are.
		_top_camera = Camera3D.new()
		_top_camera.current = true
		_top_camera.far = 8000.0
		add_child(_top_camera)
	else:
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
