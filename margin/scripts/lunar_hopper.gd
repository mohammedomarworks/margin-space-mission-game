class_name LunarHopper
extends CharacterBody3D

signal resource_changed(battery: float, propellant: float, integrity: float)
signal collision_impact(damage: float, current_integrity: float)
signal boost_state_changed(is_boosting: bool)
signal vehicle_disabled(reason: String)

# Physics constants
@export var max_speed: float = 10.0
@export var reverse_speed: float = 5.0
@export var acceleration: float = 14.0
@export var deceleration: float = 18.0
@export var turn_speed: float = 2.6
@export var boost_vertical_impulse: float = 8.5
@export var boost_forward_impulse: float = 4.0
@export var gravity: float = 6.2 # Scaled lunar gravity for responsive game feel
@export var impact_speed_threshold: float = 4.8
@export var impact_damage_multiplier: float = 3.5

# Resources (0.0 to 100.0)
var battery: float = 100.0
var propellant: float = 100.0
var integrity: float = 100.0

# Resource consumption rates (per second)
var drain_idle_battery: float = 0.08
var drain_driving_battery: float = 0.75
var drain_boost_propellant: float = 18.0
var drain_boost_battery: float = 2.5
var drain_scan_battery: float = 3.5
var drain_storm_battery: float = 2.2
var drain_storm_integrity: float = 1.2

# State flags
var can_control: bool = true
var is_safe_mode: bool = false
var is_storm_active: bool = false
var is_scanning: bool = false
var is_boosting: bool = false
var last_collision_time: float = 0.0

# Virtual / touch input overrides
var virtual_steer: float = 0.0
var virtual_throttle: float = 0.0
var virtual_boost: bool = false
var virtual_scan: bool = false

# Visual nodes
var visuals_root: Node3D
var thruster_flame: MeshInstance3D
var thruster_light: OmniLight3D
var headlight_left: SpotLight3D
var headlight_right: SpotLight3D

func _ready() -> void:
	_build_hopper_visuals()

func _physics_process(delta: float) -> void:
	if not can_control:
		_apply_passive_physics(delta)
		return

	# 1. Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Process Input
	var throttle_input: float = 0.0
	var steer_input: float = 0.0
	var boost_requested: bool = false

	# Keyboard input
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		throttle_input += 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		throttle_input -= 1.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		steer_input += 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		steer_input -= 1.0
	if Input.is_key_pressed(KEY_SPACE):
		boost_requested = true

	# Merge with virtual touch inputs if present
	if abs(virtual_throttle) > 0.01:
		throttle_input = virtual_throttle
	if abs(virtual_steer) > 0.01:
		steer_input = virtual_steer
	if virtual_boost:
		boost_requested = true

	# 3. Steering (Yaw rotation)
	if abs(steer_input) > 0.01:
		rotation.y += steer_input * turn_speed * delta

	# 4. Forward / Reverse Propulsion
	var effective_max_speed: float = max_speed
	if is_safe_mode:
		effective_max_speed *= 0.65

	var target_speed: float = 0.0
	if throttle_input > 0.0:
		target_speed = throttle_input * effective_max_speed
	elif throttle_input < 0.0:
		target_speed = throttle_input * reverse_speed

	# Forward vector in world space (Godot forward is -Z)
	var forward_dir: Vector3 = -transform.basis.z.normalized()
	
	# Horizontal velocity projected onto heading
	var horizontal_vel: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var current_forward_speed: float = horizontal_vel.dot(forward_dir)

	if abs(throttle_input) > 0.01 and battery > 0.0:
		current_forward_speed = move_toward(current_forward_speed, target_speed, acceleration * delta)
		# Battery drain while driving
		var drive_drain = drain_driving_battery * (0.6 if is_safe_mode else 1.0)
		_drain_battery(drive_drain * delta)
	else:
		current_forward_speed = move_toward(current_forward_speed, 0.0, deceleration * delta)

	# Lateral friction (eliminate sideways slide)
	var right_dir: Vector3 = transform.basis.x.normalized()
	var lateral_speed: float = horizontal_vel.dot(right_dir)
	lateral_speed = move_toward(lateral_speed, 0.0, deceleration * 1.5 * delta)

	var new_horizontal_vel: Vector3 = (forward_dir * current_forward_speed) + (right_dir * lateral_speed)
	velocity.x = new_horizontal_vel.x
	velocity.z = new_horizontal_vel.z

	# 5. Lunar Hopper Booster Jump
	if boost_requested and propellant > 0.0 and battery > 0.0:
		if not is_boosting:
			is_boosting = true
			emit_signal("boost_state_changed", true)
			_set_thruster_active(true)

		# Upward and forward push
		velocity.y = max(velocity.y + (boost_vertical_impulse * delta * 4.0), boost_vertical_impulse * 0.7)
		velocity += forward_dir * (boost_forward_impulse * delta * 2.0)

		# Drain propellant & battery
		_drain_propellant(drain_boost_propellant * delta)
		_drain_battery(drain_boost_battery * delta)
	else:
		if is_boosting:
			is_boosting = false
			emit_signal("boost_state_changed", false)
			_set_thruster_active(false)

	# 6. Idle & Environmental Drains
	_drain_battery(drain_idle_battery * delta)

	if is_scanning:
		_drain_battery(drain_scan_battery * delta)

	if is_storm_active and not is_safe_mode:
		_drain_battery(drain_storm_battery * delta)
		_drain_integrity(drain_storm_integrity * delta, "Radiation degradation")

	# 7. Move and Slide
	if is_inside_tree() and get_world_3d() != null:
		var pre_collision_speed: float = velocity.length()
		move_and_slide()
		# 8. Collision Impact Check
		_check_collision_damage(pre_collision_speed)

	# 9. Notify HUD of Resource Changes
	emit_signal("resource_changed", battery, propellant, integrity)

	# 10. Check Resource Failures
	_check_resource_fatalities()

func _apply_passive_physics(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	move_and_slide()

func _check_collision_damage(pre_speed: float) -> void:
	var col_count: int = get_slide_collision_count()
	if col_count == 0:
		return

	var now: float = Time.get_ticks_msec() / 1000.0
	if now - last_collision_time < 0.4:
		return # Cooldown between collision damage events

	for i in range(col_count):
		var col = get_slide_collision(i)
		var normal: Vector3 = col.get_normal()
		# Only detect collisions with steep obstacles/boulders, not the flat floor
		if normal.y < 0.7 and pre_speed > impact_speed_threshold:
			var excess_speed: float = pre_speed - impact_speed_threshold
			var damage: float = excess_speed * impact_damage_multiplier
			damage = clamp(damage, 4.0, 35.0)
			_drain_integrity(damage, "Terrain impact")
			last_collision_time = now
			emit_signal("collision_impact", damage, integrity)
			break

func _drain_battery(amount: float) -> void:
	battery = max(0.0, battery - amount)

func _drain_propellant(amount: float) -> void:
	propellant = max(0.0, propellant - amount)

func _drain_integrity(amount: float, reason: String = "") -> void:
	integrity = max(0.0, integrity - amount)

func _check_resource_fatalities() -> void:
	if not can_control:
		return
	if battery <= 0.0:
		can_control = false
		_set_thruster_active(false)
		emit_signal("vehicle_disabled", "CRITICAL BATTERY DEPLETION: Power loss in cryogenic lunar shadow.")
	elif integrity <= 0.0:
		can_control = false
		_set_thruster_active(false)
		emit_signal("vehicle_disabled", "STRUCTURAL CATASTROPHE: Vehicle hull integrity compromised by obstacle collision.")

func set_safe_mode(enabled: bool) -> void:
	is_safe_mode = enabled

func set_storm_active(active: bool) -> void:
	is_storm_active = active

func set_scanning(scanning: bool) -> void:
	is_scanning = scanning

func reset_state(spawn_pos: Vector3, spawn_rot_y: float = 0.0) -> void:
	if is_inside_tree():
		global_position = spawn_pos
		global_rotation.y = spawn_rot_y
	else:
		position = spawn_pos
		rotation.y = spawn_rot_y
	velocity = Vector3.ZERO
	battery = 100.0
	propellant = 100.0
	integrity = 100.0
	can_control = true
	is_safe_mode = false
	is_storm_active = false
	is_scanning = false
	is_boosting = false
	virtual_steer = 0.0
	virtual_throttle = 0.0
	virtual_boost = false
	virtual_scan = false
	_set_thruster_active(false)
	emit_signal("resource_changed", battery, propellant, integrity)

func _set_thruster_active(active: bool) -> void:
	if thruster_flame:
		thruster_flame.visible = active
	if thruster_light:
		thruster_light.visible = active

# --- 3D Procedural Visuals Assembly ---

func _build_hopper_visuals() -> void:
	visuals_root = Node3D.new()
	visuals_root.name = "HopperVisuals"
	add_child(visuals_root)

	# 1. Main Chassis (Gold multi-layer insulation hex core)
	var chassis_mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1.4, 0.65, 1.6)
	chassis_mesh.mesh = box
	chassis_mesh.position = Vector3(0.0, 0.65, 0.0)

	var gold_mat: StandardMaterial3D = StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.92, 0.72, 0.22)
	gold_mat.metallic = 0.88
	gold_mat.roughness = 0.28
	chassis_mesh.material_override = gold_mat
	visuals_root.add_child(chassis_mesh)

	# 2. Top Avionics Deck (Titanium / Ceramic White)
	var deck_mesh: MeshInstance3D = MeshInstance3D.new()
	var deck_box: BoxMesh = BoxMesh.new()
	deck_box.size = Vector3(1.1, 0.25, 1.2)
	deck_mesh.mesh = deck_box
	deck_mesh.position = Vector3(0.0, 1.05, -0.05)

	var white_mat: StandardMaterial3D = StandardMaterial3D.new()
	white_mat.albedo_color = Color(0.85, 0.88, 0.92)
	white_mat.metallic = 0.3
	white_mat.roughness = 0.4
	deck_mesh.material_override = white_mat
	visuals_root.add_child(deck_mesh)

	# 3. Sensor Dome / High-Tech Science Mast
	var sensor_dome: MeshInstance3D = MeshInstance3D.new()
	var dome_sphere: SphereMesh = SphereMesh.new()
	dome_sphere.radius = 0.22
	dome_sphere.height = 0.35
	sensor_dome.mesh = dome_sphere
	sensor_dome.position = Vector3(0.0, 1.25, -0.35)

	var glass_mat: StandardMaterial3D = StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.1, 0.8, 0.95)
	glass_mat.emission_enabled = true
	glass_mat.emission = Color(0.15, 0.75, 0.95)
	glass_mat.emission_energy_multiplier = 1.2
	glass_mat.metallic = 0.9
	glass_mat.roughness = 0.1
	sensor_dome.material_override = glass_mat
	visuals_root.add_child(sensor_dome)

	# 4. High-Gain Antenna Dish (Direction of travel indicator)
	var dish: MeshInstance3D = MeshInstance3D.new()
	var dish_cylinder: CylinderMesh = CylinderMesh.new()
	dish_cylinder.top_radius = 0.28
	dish_cylinder.bottom_radius = 0.05
	dish_cylinder.height = 0.12
	dish.mesh = dish_cylinder
	dish.position = Vector3(0.0, 1.35, 0.3)
	dish.rotation_degrees = Vector3(-35, 0, 0)
	dish.material_override = gold_mat
	visuals_root.add_child(dish)

	# 5. Dual Lateral Solar Arrays
	var solar_mat: StandardMaterial3D = StandardMaterial3D.new()
	solar_mat.albedo_color = Color(0.06, 0.12, 0.26)
	solar_mat.metallic = 0.85
	solar_mat.roughness = 0.2

	for side in [-1.0, 1.0]:
		var panel: MeshInstance3D = MeshInstance3D.new()
		var panel_box: BoxMesh = BoxMesh.new()
		panel_box.size = Vector3(0.65, 0.04, 1.3)
		panel.mesh = panel_box
		panel.position = Vector3(side * 1.05, 0.75, 0.0)
		panel.material_override = solar_mat
		visuals_root.add_child(panel)

	# 6. Four Articulated Landing Legs & Footpads
	var leg_mat: StandardMaterial3D = StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.4, 0.44, 0.48)
	leg_mat.metallic = 0.9
	leg_mat.roughness = 0.35

	var leg_offsets = [
		Vector3(-0.75, 0.4, -0.75),
		Vector3(0.75, 0.4, -0.75),
		Vector3(-0.75, 0.4, 0.75),
		Vector3(0.75, 0.4, 0.75)
	]
	for pos in leg_offsets:
		# Leg Strut
		var leg: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.04
		cyl.bottom_radius = 0.04
		cyl.height = 0.65
		leg.mesh = cyl
		leg.position = pos
		leg.rotation_degrees = Vector3(pos.z * 25.0, 0, -pos.x * 25.0)
		leg.material_override = leg_mat
		visuals_root.add_child(leg)

		# Footpad
		var pad: MeshInstance3D = MeshInstance3D.new()
		var pad_cyl: CylinderMesh = CylinderMesh.new()
		pad_cyl.top_radius = 0.16
		pad_cyl.bottom_radius = 0.18
		pad_cyl.height = 0.06
		pad.mesh = pad_cyl
		pad.position = Vector3(pos.x * 1.25, 0.05, pos.z * 1.25)
		pad.material_override = leg_mat
		visuals_root.add_child(pad)

	# 7. Headlights (for navigating dark polar craters)
	headlight_left = SpotLight3D.new()
	headlight_left.position = Vector3(-0.45, 0.65, -0.85)
	headlight_left.rotation_degrees = Vector3(-5, 180, 0) # Cast forward (-Z)
	headlight_left.spot_range = 28.0
	headlight_left.spot_angle = 38.0
	headlight_left.light_energy = 2.4
	headlight_left.light_color = Color(0.92, 0.96, 1.0)
	visuals_root.add_child(headlight_left)

	headlight_right = SpotLight3D.new()
	headlight_right.position = Vector3(0.45, 0.65, -0.85)
	headlight_right.rotation_degrees = Vector3(-5, 180, 0)
	headlight_right.spot_range = 28.0
	headlight_right.spot_angle = 38.0
	headlight_right.light_energy = 2.4
	headlight_right.light_color = Color(0.92, 0.96, 1.0)
	visuals_root.add_child(headlight_right)

	# 8. Ventral Thruster Nozzle & Dynamic Boost Flame
	var nozzle: MeshInstance3D = MeshInstance3D.new()
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.12
	cone.bottom_radius = 0.22
	cone.height = 0.25
	nozzle.mesh = cone
	nozzle.position = Vector3(0.0, 0.28, 0.0)
	nozzle.material_override = leg_mat
	visuals_root.add_child(nozzle)

	thruster_flame = MeshInstance3D.new()
	var flame_cone: CylinderMesh = CylinderMesh.new()
	flame_cone.top_radius = 0.02
	flame_cone.bottom_radius = 0.2
	flame_cone.height = 0.75
	thruster_flame.mesh = flame_cone
	thruster_flame.position = Vector3(0.0, -0.22, 0.0)

	var flame_mat: StandardMaterial3D = StandardMaterial3D.new()
	flame_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.albedo_color = Color(0.2, 0.85, 1.0, 0.9)
	thruster_flame.material_override = flame_mat
	thruster_flame.visible = false
	visuals_root.add_child(thruster_flame)

	thruster_light = OmniLight3D.new()
	thruster_light.position = Vector3(0.0, -0.15, 0.0)
	thruster_light.light_color = Color(0.25, 0.8, 1.0)
	thruster_light.light_energy = 3.5
	thruster_light.omni_range = 6.0
	thruster_light.visible = false
	visuals_root.add_child(thruster_light)

	# 9. Physics Collision Shape (Box covering main chassis)
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(1.7, 1.1, 1.8)
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, 0.58, 0.0)
	add_child(col_shape)
