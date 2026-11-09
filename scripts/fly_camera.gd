extends Camera3D
## Free-look fly camera.
## Click the window to capture the mouse, Esc to release it.
## WASD = move, Q/E = down/up, Shift = fast, Ctrl = slow, mouse wheel = change speed.

@export var speed: float = 6.0
@export var sensitivity: float = 0.0025
@export var smoothing: float = 12.0  ## higher = snappier, 0 = no smoothing

var _velocity := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	# Take over orientation from wherever the generator pointed the camera.
	_yaw = rotation.y
	_pitch = rotation.x
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			MOUSE_BUTTON_WHEEL_UP:
				speed = minf(speed * 1.15, 200.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				speed = maxf(speed / 1.15, 0.2)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * sensitivity
		_pitch = clampf(_pitch - event.relative.y * sensitivity, -1.55, 1.55)
		rotation = Vector3(_pitch, _yaw, 0.0)


func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): dir.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S): dir.z += 1.0
	if Input.is_physical_key_pressed(KEY_A): dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_E): dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q): dir.y -= 1.0

	var mult := 1.0
	if Input.is_physical_key_pressed(KEY_SHIFT): mult = 3.0
	elif Input.is_physical_key_pressed(KEY_CTRL): mult = 0.3

	# Move relative to where the camera looks (Q/E stay world-vertical).
	var target := (global_transform.basis * Vector3(dir.x, 0.0, dir.z)) + Vector3(0.0, dir.y, 0.0)
	target = target.normalized() * speed * mult if target != Vector3.ZERO else Vector3.ZERO
	var t := 1.0 if smoothing <= 0.0 else 1.0 - exp(-smoothing * delta)
	_velocity = _velocity.lerp(target, t)
	global_position += _velocity * delta
