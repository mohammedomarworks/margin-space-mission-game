class_name LunarFrontierCamera
extends Node3D

@export var target: Node3D
@export var distance: float = 6.8
@export var height: float = 2.6
@export var pitch_degrees: float = -14.0
@export var position_smooth: float = 8.0
@export var rotation_smooth: float = 5.0

var camera: Camera3D
var current_yaw: float = 0.0
var manual_yaw_offset: float = 0.0

func _ready() -> void:
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 70.0
	camera.near = 0.1
	camera.far = 600.0
	add_child(camera)
	
	if target:
		reset_camera()

func _physics_process(delta: float) -> void:
	if not target or not is_inside_tree():
		return

	# Smoothly track target yaw
	var target_yaw: float = (target.global_rotation.y if target.is_inside_tree() else target.rotation.y) + manual_yaw_offset
	current_yaw = lerp_angle(current_yaw, target_yaw, rotation_smooth * delta)

	# Calculate desired camera position in world space
	var desired_pos: Vector3 = _calculate_desired_position()

	# Raycast terrain collision check to prevent clipping through lunar obstacles
	if get_world_3d() != null:
		var space_state = get_world_3d().direct_space_state
		var focus_pt = _get_target_focus()
		var query = PhysicsRayQueryParameters3D.create(focus_pt, desired_pos)
		query.exclude = [target.get_rid()]
		var result = space_state.intersect_ray(query)
		if result:
			var hit_pos: Vector3 = result.position
			desired_pos = hit_pos.lerp(focus_pt, 0.15)

	# Smooth position lerp
	global_position = global_position.lerp(desired_pos, position_smooth * delta)

	# Camera look-at
	camera.look_at(_get_target_focus(), Vector3.UP)

func _get_target_focus() -> Vector3:
	if not target:
		return Vector3.ZERO
	if target.is_inside_tree():
		return target.global_position + Vector3(0.0, 0.9, 0.0)
	else:
		return target.position + Vector3(0.0, 0.9, 0.0)

func _calculate_desired_position() -> Vector3:
	var focus: Vector3 = _get_target_focus()
	var horizontal_offset = Vector3(0.0, 0.0, distance).rotated(Vector3.UP, current_yaw)
	var final_pos = focus + horizontal_offset + Vector3(0.0, height, 0.0)
	return final_pos

func reset_camera() -> void:
	if target:
		current_yaw = target.global_rotation.y if target.is_inside_tree() else target.rotation.y
		var desired = _calculate_desired_position()
		if is_inside_tree():
			global_position = desired
		else:
			position = desired
		if camera:
			camera.look_at(_get_target_focus(), Vector3.UP)
