class_name OrbitCamera
extends Camera3D

@export var target_position: Vector3 = Vector3.ZERO
@export var distance: float = 4.2
@export var min_distance: float = 1.6
@export var max_distance: float = 8.5
@export var yaw: float = -35.0 # degrees
@export var pitch: float = 22.0 # degrees
@export var min_pitch: float = -75.0
@export var max_pitch: float = 75.0
@export var rotate_speed: float = 0.35
@export var zoom_speed: float = 0.4
@export var pan_speed: float = 0.003
@export var smooth_speed: float = 12.0
@export var auto_rotate: bool = false
@export var auto_rotate_speed: float = 8.0 # deg/sec

var _current_target: Vector3 = Vector3.ZERO
var _current_distance: float = 4.2
var _current_yaw: float = -35.0
var _current_pitch: float = 22.0

var _is_orbiting: bool = false
var _is_panning: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

var _default_yaw: float = -35.0
var _default_pitch: float = 22.0
var _default_dist: float = 4.2
var _default_target: Vector3 = Vector3.ZERO

func _ready() -> void:
	_default_yaw = yaw
	_default_pitch = pitch
	_default_dist = distance
	_default_target = target_position
	
	_current_yaw = yaw
	_current_pitch = pitch
	_current_distance = distance
	_current_target = target_position
	_update_transform(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_is_orbiting = mb.pressed
			_last_mouse_pos = mb.position
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_is_panning = mb.pressed
			_last_mouse_pos = mb.position
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			distance = clamp(distance - zoom_speed, min_distance, max_distance)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			distance = clamp(distance + zoom_speed, min_distance, max_distance)
			
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var delta: Vector2 = mm.position - _last_mouse_pos
		_last_mouse_pos = mm.position
		
		if _is_orbiting:
			yaw -= delta.x * rotate_speed
			pitch = clamp(pitch - delta.y * rotate_speed, min_pitch, max_pitch)
		elif _is_panning:
			var right_dir: Vector3 = global_transform.basis.x
			var up_dir: Vector3 = global_transform.basis.y
			target_position += (-right_dir * delta.x + up_dir * delta.y) * (pan_speed * distance * 0.4)

func _process(delta: float) -> void:
	if auto_rotate and not _is_orbiting:
		yaw += auto_rotate_speed * delta
	
	# Smooth dampening
	_current_yaw = lerp(_current_yaw, yaw, clamp(smooth_speed * delta, 0.0, 1.0))
	_current_pitch = lerp(_current_pitch, pitch, clamp(smooth_speed * delta, 0.0, 1.0))
	_current_distance = lerp(_current_distance, distance, clamp(smooth_speed * delta, 0.0, 1.0))
	_current_target = _current_target.lerp(target_position, clamp(smooth_speed * delta, 0.0, 1.0))
	
	_update_transform(false)

func _update_transform(immediate: bool) -> void:
	var yaw_rad: float = deg_to_rad(_current_yaw if not immediate else yaw)
	var pitch_rad: float = deg_to_rad(_current_pitch if not immediate else pitch)
	var dist: float = _current_distance if not immediate else distance
	var target: Vector3 = _current_target if not immediate else target_position
	
	var offset: Vector3 = Vector3(
		sin(yaw_rad) * cos(pitch_rad),
		sin(pitch_rad),
		cos(yaw_rad) * cos(pitch_rad)
	) * dist
	
	global_position = target + offset
	look_at(target, Vector3.UP)

func focus_on(pos: Vector3, dist: float = 3.2) -> void:
	target_position = pos
	distance = clamp(dist, min_distance, max_distance)

func reset_view() -> void:
	yaw = _default_yaw
	pitch = _default_pitch
	distance = _default_dist
	target_position = _default_target
