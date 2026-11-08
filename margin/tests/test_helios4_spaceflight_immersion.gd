class_name TestHelios4SpaceflightImmersion
extends SceneTree

# ==============================================================================
# HELIOS-4: POST-LAUNCH SPACEFLIGHT IMMERSION TEST SUITE
# Verifies continuous physical 3D world motion, receding Earth, sun tracking,
# space dust velocity feedback, interactive orbit camera, star parallax,
# halo orbit motion, and animated mechanical deployments.
# ==============================================================================

var passed_count: int = 0
var failed_count: int = 0

func _init() -> void:
	print("\n==================================================")
	print("  HELIOS-4: SPACEFLIGHT IMMERSION VERIFICATION SUITE")
	print("==================================================\n")
	process_frame.connect(_run_all_tests, CONNECT_ONE_SHOT)

func _assert(condition: bool, message: String) -> void:
	if condition:
		passed_count += 1
		print("  [PASS] %s" % message)
	else:
		failed_count += 1
		printerr("  [FAIL] %s" % message)

func _assert_approx(val: float, target: float, tolerance: float, message: String) -> void:
	var diff = abs(val - target)
	_assert(diff <= tolerance, "%s (%.2f ~ %.2f, diff=%.3f)" % [message, val, target, diff])

func _run_all_tests() -> void:
	var deep_space_scene = load("res://margin/scenes/helios4_deep_space.tscn") as PackedScene
	_assert(deep_space_scene != null, "helios4_deep_space.tscn loads successfully")
	var ds_ctrl = deep_space_scene.instantiate() as Helios4DeepSpaceController
	root.add_child(ds_ctrl)
	await process_frame
	await process_frame

	await test_deep_space_scene_instantiation(ds_ctrl)
	await test_physical_trajectory_progression(ds_ctrl)
	await test_earth_receding_and_axial_rotation(ds_ctrl)
	await test_sunward_and_earthward_tracking(ds_ctrl)
	await test_space_dust_velocity_cues(ds_ctrl)
	await test_3d_spatial_starfield_parallax(ds_ctrl)
	await test_interactive_camera_controls(ds_ctrl)
	await test_time_warp_motion_acceleration(ds_ctrl)
	await test_p1_earth_clearance_1000_points(ds_ctrl)
	await test_p1_parking_to_tli_continuity(ds_ctrl)
	await test_p1_tli_to_cruise_continuity(ds_ctrl)
	await test_p1_floating_point_render_precision(ds_ctrl)
	await test_p1_normal_speed_visual_motion(ds_ctrl)

	ds_ctrl.queue_free()
	await process_frame

	var l1_scene = load("res://margin/scenes/helios4_l1_arrival.tscn") as PackedScene
	_assert(l1_scene != null, "helios4_l1_arrival.tscn loads successfully")
	var l1_ctrl = l1_scene.instantiate() as Helios4L1ArrivalController
	root.add_child(l1_ctrl)
	await process_frame
	await process_frame

	await test_l1_halo_orbit_continuous_motion(l1_ctrl)
	await test_l1_mechanical_deployment_animations(l1_ctrl)
	await test_l1_interactive_camera_and_dust(l1_ctrl)

	l1_ctrl.queue_free()
	await process_frame

	print("\n--------------------------------------------------")
	print("IMMERSION TESTS: %d PASSED, %d FAILED" % [passed_count, failed_count])
	print("--------------------------------------------------\n")
	
	if failed_count > 0:
		quit(1)
	else:
		quit(0)

func test_deep_space_scene_instantiation(ctrl: Helios4DeepSpaceController) -> void:
	print("[TEST 1] Deep Space Scene Instantiation & Node Hierarchy")
	_assert(ctrl.probe_node != null, "ProbeNode exists")
	_assert(ctrl.earth_node != null, "EarthNode exists")
	_assert(ctrl.sun_node != null, "SunNode exists")
	_assert(ctrl.space_dust_emitter != null, "SpaceDustParticles emitter instantiated")
	_assert(ctrl.starfield_cluster != null, "SpatialStarfield cluster instantiated")

func test_physical_trajectory_progression(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 2] Continuous Physical 3D World Spaceflight Trajectory")
	# Initial in parking orbit
	_assert(ctrl.current_subphase == Helios4DeepSpaceController.SubPhase.PARKING_ORBIT, "Starts in PARKING_ORBIT")
	var p0 = ctrl.probe_node.global_position
	ctrl._process(1.0)
	var p1 = ctrl.probe_node.global_position
	_assert(p0.distance_to(p1) > 0.1, "Spacecraft physically moves in 3D orbit around Earth during parking orbit")
	
	# Execute TLI burn
	ctrl._on_primary_action_pressed()
	_assert(ctrl.current_subphase == Helios4DeepSpaceController.SubPhase.INJECTION_BURN, "Enters INJECTION_BURN")
	ctrl._process(4.1) # Complete burn
	_assert(ctrl.current_subphase == Helios4DeepSpaceController.SubPhase.CRUISE_EARLY, "TLI burn transitions into CRUISE_EARLY")
	
	# Check probe position along trajectory
	var pos_early = ctrl.probe_node.global_position
	ctrl.distance_km = 450000.0
	ctrl._process(0.1)
	var pos_mid = ctrl.probe_node.global_position
	_assert(pos_early.distance_to(pos_mid) > 5.0, "Spacecraft translates through 3D world space along transfer arc as distance advances")
	
	# Tangent alignment
	var u = clamp((ctrl.distance_km - 165.0) / (ctrl.TARGET_L1_DISTANCE_KM - 165.0), 0.0, 1.0)
	var expected_pos = ctrl.get_trajectory_point(u)
	_assert_approx(ctrl.probe_node.position.distance_to(expected_pos), 0.0, 0.01, "Probe position precisely matches parametric trajectory curve")

func test_earth_receding_and_axial_rotation(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 3] Earth Receding & Axial Rotation Over Transfer")
	# Near Earth
	ctrl.current_subphase = Helios4DeepSpaceController.SubPhase.PARKING_ORBIT
	ctrl.distance_km = 165.0
	ctrl.transfer_progress_km = 0.0
	ctrl._process(0.01)
	ctrl._update_celestial_transforms(0.0)
	var rot_start = ctrl.earth_mesh.rotation.y
	_assert(ctrl.earth_node.scale == Vector3.ONE, "Earth visual scale remains strictly Vector3.ONE (no artificial distance-dependent scaling)")
	var dist_near = ctrl.probe_node.global_position.distance_to(ctrl.earth_node.global_position)
	
	# Advance delta for axial rotation
	ctrl._update_celestial_transforms(2.0)
	var rot_advanced = ctrl.earth_mesh.rotation.y
	_assert(rot_advanced > rot_start, "Earth visibly rotates on its polar axis continuously")
	
	# Far out at L1 approach
	ctrl.current_subphase = Helios4DeepSpaceController.SubPhase.CRUISE_EARLY
	ctrl.distance_km = 1500000.0
	ctrl._process(0.1)
	ctrl._update_celestial_transforms(0.0)
	_assert(ctrl.earth_node.scale == Vector3.ONE, "Earth scale remains strictly Vector3.ONE at L1")
	var dist_far = ctrl.probe_node.global_position.distance_to(ctrl.earth_node.global_position)
	_assert(dist_far > dist_near * 200.0, "Earth recedes naturally via 3D perspective distance across transfer (%.2f -> %.2f units)" % [dist_near, dist_far])

func test_sunward_and_earthward_tracking(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 4] Articulated Sun-Tracking Solar Panels & Earth-Tracking High Gain Dish")
	_assert(ctrl.dish_pivot != null, "High-gain dish pivot exists")
	_assert(ctrl.solar_wing_left != null and ctrl.solar_wing_right != null, "Solar array wings exist")
	
	# Advance tracking
	ctrl.distance_km = 500000.0
	ctrl._process(0.5)
	
	var dish_facing = ctrl.dish_pivot.global_transform.basis * Vector3.BACK
	var to_earth = (ctrl.earth_node.global_position - ctrl.dish_pivot.global_position).normalized()
	_assert(dish_facing.dot(to_earth) > 0.4, "High-gain antenna dish orients towards Earth")

func test_space_dust_velocity_cues(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 5] Relativistic Space Dust Physical Motion Cues")
	_assert(ctrl.space_dust_emitter.emitting, "Space dust particles actively emitting")
	
	# Check dust at 1x warp
	ctrl._set_time_warp(0)
	ctrl.distance_km = 400000.0
	ctrl._update_space_dust(0.1)
	var speed_1x = ctrl.space_dust_emitter.initial_velocity_min
	
	# Check dust at 1000x warp
	ctrl._set_time_warp(3)
	ctrl._update_space_dust(0.1)
	var speed_1000x = ctrl.space_dust_emitter.initial_velocity_min
	_assert(speed_1000x > speed_1x * 2.5, "Space dust velocity visibly accelerates with time warp factor (%.1f > %.1f m/s)" % [speed_1000x, speed_1x])

func test_3d_spatial_starfield_parallax(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 6] 3D Spatial Starfield Multi-Depth Parallax")
	_assert(ctrl.starfield_cluster != null, "3D spatial starfield cluster attached")
	_assert(ctrl.starfield_cluster.get_child_count() > 0, "Starfield contains 3D point star meshes")

func test_interactive_camera_controls(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 7] Interactive 3D Orbit & Zoom Camera Controls")
	var cam = ctrl.deep_space_cam
	ctrl._set_camera_mode(Helios4DeepSpaceController.CamMode.CHASE_3_4)
	ctrl._update_camera(2.0)
	ctrl._update_camera(2.0)
	var base_cam_pos = cam.global_position
	var dist_base = base_cam_pos.distance_to(ctrl.probe_node.global_position)
	
	# Simulate mouse drag / arrow key yaw rotation
	ctrl._cam_orbit_yaw = 0.8
	ctrl._update_camera(2.0)
	var yaw_cam_pos = cam.global_position
	_assert(base_cam_pos.distance_to(yaw_cam_pos) > 0.5, "Camera orbits dynamically around spacecraft on yaw input")
	
	# Simulate zoom in
	ctrl._cam_orbit_yaw = 0.0
	ctrl._cam_zoom_mult = 0.5
	ctrl._update_camera(2.0)
	ctrl._update_camera(2.0)
	var zoom_cam_pos = cam.global_position
	var dist_zoomed = zoom_cam_pos.distance_to(ctrl.probe_node.global_position)
	_assert(dist_zoomed < dist_base * 0.75, "Camera zoom multiplier smoothly scales distance to probe (%.2f < %.2f)" % [dist_zoomed, dist_base * 0.75])
	
	# Reset on preset switch
	ctrl._set_camera_mode(Helios4DeepSpaceController.CamMode.WIDE_TRAJECTORY)
	_assert(ctrl._cam_orbit_yaw == 0.0, "Camera mode switch resets orbit yaw to nominal preset")
	_assert(ctrl._cam_zoom_mult == 1.0, "Camera mode switch resets zoom to 1.0x")

func test_time_warp_motion_acceleration(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 8] Time Warp Progression Acceleration")
	ctrl.current_subphase = Helios4DeepSpaceController.SubPhase.CRUISE_EARLY
	ctrl.distance_km = 50000.0 # Stay below the 300,000 km MCC alert threshold
	ctrl._set_time_warp(0) # 1x
	var d0 = ctrl.distance_km
	ctrl._process(1.0)
	var delta_1x = ctrl.distance_km - d0
	
	ctrl._set_time_warp(2) # 100x
	var d1 = ctrl.distance_km
	ctrl._process(1.0)
	var delta_100x = ctrl.distance_km - d1
	_assert(delta_100x > delta_1x * 50.0, "100x time warp accelerates spatial trajectory progression proportionally")

func test_l1_halo_orbit_continuous_motion(ctrl: Helios4L1ArrivalController) -> void:
	print("\n[TEST 9] L1 Halo Orbit Continuous 3D Motion")
	ctrl.current_phase = Helios4L1ArrivalController.SubPhase.STAGE_C_STATIONKEEPING
	ctrl._process(0.0)
	var p0 = ctrl.probe_node.position
	ctrl._process(1.5)
	var p1 = ctrl.probe_node.position
	_assert(p0.distance_to(p1) > 0.4, "Spacecraft continuously moves in 3D world space along the periodic halo orbit")
	
	var tan_expected = Vector3(
		2.0 * ctrl.HALO_AX * sin(2.0 * ctrl._halo_angle),
		ctrl.HALO_AY * cos(ctrl._halo_angle),
		-ctrl.HALO_AZ * sin(ctrl._halo_angle)
	).normalized()
	var forward_axis = -ctrl.probe_node.transform.basis.z.normalized()
	_assert(forward_axis.dot(tan_expected) > 0.85, "Spacecraft attitude aligns smoothly with halo orbit velocity tangent")

func test_l1_mechanical_deployment_animations(ctrl: Helios4L1ArrivalController) -> void:
	print("\n[TEST 10] L1 Mechanical Deployments Smooth Animated Tweens")
	_assert(ctrl.mag_boom.scale.y < 0.2, "Magnetometer boom initially in stowed configuration")
	_assert(ctrl.faraday_cover.rotation_degrees.x < 10.0, "Faraday Cup aperture cover initially closed")
	
	# Deploy Magnetometer
	ctrl.current_phase = Helios4L1ArrivalController.SubPhase.STAGE_D_COMMISSION_MAG
	ctrl._on_primary_action_pressed()
	_assert(ctrl.mag_boom_deployed, "Magnetometer state transitions to deployed")
	
	# Deploy Faraday Cup
	ctrl._on_primary_action_pressed()
	_assert(ctrl.faraday_door_released, "Faraday Cup cover release triggered")
	
	# Earth Dish Lock
	ctrl.current_phase = Helios4L1ArrivalController.SubPhase.STAGE_F_EARTH_COMM_LOCK
	ctrl._on_primary_action_pressed()
	_assert(ctrl.earth_comm_linked, "High-gain dish lock triggered")

func test_l1_interactive_camera_and_dust(ctrl: Helios4L1ArrivalController) -> void:
	print("\n[TEST 11] L1 Interactive Camera Orbit & Space Dust Emitter")
	_assert(ctrl.space_dust_emitter != null and ctrl.space_dust_emitter.emitting, "Space dust particles active in L1 scene")
	
	var cam = ctrl.camera
	ctrl._process(0.1)
	var base_cam_pos = cam.global_position
	
	# Interactive orbit in L1
	ctrl._cam_orbit_yaw = 0.75
	ctrl._cam_orbit_pitch = 0.35
	ctrl._update_camera_transform(0.0)
	var orbit_cam_pos = cam.global_position
	_assert(base_cam_pos.distance_to(orbit_cam_pos) > 0.5, "L1 camera orbits dynamically around spacecraft in halo orbit")

# --- P1 SPECIFIC VERIFICATION TESTS ---

func test_p1_earth_clearance_1000_points(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST P1-1] Trajectory Earth Clearance Across 1,000 Sampled Points")
	var sample_count = 1000
	var min_clearance_km = 999999.0
	var min_center_dist_km = 999999.0
	
	# Test nominal trajectory across 1,000 points
	for i in range(sample_count + 1):
		var u = float(i) / float(sample_count)
		var p_sim = ctrl.get_trajectory_point_sim_km(u)
		var r_km = p_sim.length()
		var clearance_km = r_km - ctrl.EARTH_RADIUS_KM
		if clearance_km < min_clearance_km:
			min_clearance_km = clearance_km
		if r_km < min_center_dist_km:
			min_center_dist_km = r_km
			
	print("  -> Sampled 1,000 trajectory points: Minimum Earth Center Distance = %.2f km, Minimum Physical Surface Clearance = %.2f km" % [min_center_dist_km, min_clearance_km])
	_assert(min_center_dist_km >= ctrl.PARKING_ORBIT_RADIUS_KM - 0.01, "Trajectory center distance never drops below parking orbit radius (%.2f >= %.2f km)" % [min_center_dist_km, ctrl.PARKING_ORBIT_RADIUS_KM])
	_assert(min_clearance_km >= 165.0 - 0.01, "Earth clearance strictly exceeds parking orbit altitude (165.0 km) across all 1,000 points (minimum: %.2f km)" % min_clearance_km)
	
	# Test across various initial parking orbit angles (e.g., 0, 45, 90, 180, 270 degrees)
	var test_angles = [0.0, PI * 0.25, PI * 0.5, PI, PI * 1.5]
	for ang in test_angles:
		ctrl.transfer_start_x_km = cos(ang) * ctrl.PARKING_ORBIT_RADIUS_KM
		ctrl.transfer_start_y_km = sin(ang) * 1850.0
		ctrl.transfer_start_z_km = sin(ang) * ctrl.PARKING_ORBIT_RADIUS_KM
		for i in range(200):
			var u = float(i) / 200.0
			var p = ctrl.get_trajectory_point_sim_km(u)
			var clr = p.length() - ctrl.EARTH_RADIUS_KM
			_assert(clr >= 165.0 - 0.01, "Arbitrary departure angle %.2f rad maintains >= 165 km clearance (got %.2f km)" % [ang, clr])

func test_p1_parking_to_tli_continuity(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST P1-2] Parking Orbit to TLI Transition Continuity")
	ctrl._set_time_warp(0) # 1x nominal
	ctrl.current_subphase = Helios4DeepSpaceController.SubPhase.PARKING_ORBIT
	ctrl.parking_orbit_theta = 0.5
	ctrl._process(0.01)
	
	var pos_parking = Vector3(ctrl.spacecraft_x_km, ctrl.spacecraft_y_km, ctrl.spacecraft_z_km)
	var vel_parking = ctrl.velocity_kms
	
	# Initiate TLI
	ctrl._on_primary_action_pressed()
	_assert(ctrl.current_subphase == Helios4DeepSpaceController.SubPhase.INJECTION_BURN, "Transitioned to INJECTION_BURN")
	
	var pos_tli_start = Vector3(ctrl.spacecraft_x_km, ctrl.spacecraft_y_km, ctrl.spacecraft_z_km)
	var pos_jump = pos_parking.distance_to(pos_tli_start)
	_assert(pos_jump < 0.001, "Zero position jump at Parking -> TLI transition (jump: %.4f km)" % pos_jump)
	_assert_approx(ctrl.velocity_kms, 7.75, 0.05, "Parking orbit velocity 7.75 km/s preserved at ignition start")

func test_p1_tli_to_cruise_continuity(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST P1-3] TLI Burnout to Cruise Continuity & Velocity Handoff")
	ctrl._set_time_warp(0) # 1x nominal
	_assert(ctrl.current_subphase == Helios4DeepSpaceController.SubPhase.INJECTION_BURN, "Currently in INJECTION_BURN")
	
	# Verify trajectory at u=0 matches exact departure anchor
	var departure_pos = Vector3(ctrl.transfer_start_x_km, ctrl.transfer_start_y_km, ctrl.transfer_start_z_km)
	var u0_pos = ctrl.get_trajectory_point_sim_km(0.0)
	var departure_offset = departure_pos.distance_to(u0_pos)
	_assert(departure_offset < 0.001, "Trajectory u=0 precisely anchors to parking orbit departure position (offset: %.4f km)" % departure_offset)
	
	# Advance burn to completion (duration is 4.0s)
	ctrl._process(4.1)
	_assert(ctrl.current_subphase == Helios4DeepSpaceController.SubPhase.CRUISE_EARLY, "Subphase transitioned to CRUISE_EARLY at burnout")
	_assert_approx(ctrl.velocity_kms, 10.95, 0.05, "Velocity seamlessly reaches hyperbolic escape velocity 10.95 km/s")
	
	var burnout_pos = Vector3(ctrl.spacecraft_x_km, ctrl.spacecraft_y_km, ctrl.spacecraft_z_km)
	var u_burnout = clamp(ctrl.transfer_progress_km / ctrl.L1_DISTANCE_KM, 0.0, 1.0)
	var expected_burnout_pos = ctrl.get_trajectory_point_sim_km(u_burnout)
	var burnout_jump = burnout_pos.distance_to(expected_burnout_pos)
	_assert(burnout_jump < 0.001, "Zero position jump at TLI burnout transition (jump: %.4f km)" % burnout_jump)
	
	# Process next step in cruise at 1x
	ctrl._set_time_warp(0)
	ctrl._process(0.01)
	var cruise_step_pos = Vector3(ctrl.spacecraft_x_km, ctrl.spacecraft_y_km, ctrl.spacecraft_z_km)
	var step_distance = burnout_pos.distance_to(cruise_step_pos)
	_assert(step_distance < 5.0, "Smooth continuous progression into cruise (delta: %.4f km)" % step_distance)

func test_p1_floating_point_render_precision(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST P1-4] Floating-Point Coordinate Frame & Visual Precision")
	_assert(ctrl.VISUAL_SCALE == 0.0001, "Visual scale factor is exactly 0.0001 (1 Godot unit = 10,000 km)")
	
	# Check scalar storage types
	_assert(typeof(ctrl.spacecraft_x_km) == TYPE_FLOAT, "spacecraft_x_km stored as 64-bit float")
	_assert(typeof(ctrl.spacecraft_y_km) == TYPE_FLOAT, "spacecraft_y_km stored as 64-bit float")
	_assert(typeof(ctrl.spacecraft_z_km) == TYPE_FLOAT, "spacecraft_z_km stored as 64-bit float")
	
	# Verify celestial positions in visual space
	_assert(ctrl.EARTH_SIM_POS_KM == Vector3.ZERO, "Earth simulation position is strictly (0, 0, 0) km")
	_assert(ctrl.L1_SIM_POS_KM == Vector3(-1500000.0, 0.0, 0.0), "L1 simulation position is (-1500000, 0, 0) km")
	_assert(ctrl.SUN_SIM_POS_KM == Vector3(-150000000.0, 0.0, 0.0), "Sun simulation position is (-150000000, 0, 0) km")
	
	# Visual coordinates in Godot units
	var earth_vis = ctrl.earth_node.position
	_assert(earth_vis == Vector3.ZERO, "Earth node centered at visual (0, 0, 0)")
	var sun_vis = ctrl.sun_node.position
	_assert_approx(sun_vis.x, -15000.0, 0.1, "Sun node located at visual x = -15000 units")
	
	# Camera frustum
	_assert(ctrl.deep_space_cam.far >= 40000.0, "Camera far clip plane >= 40000 units to view Sun at -15000 without clipping")

func test_p1_normal_speed_visual_motion(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST P1-5] Normal Speed (1x) Dynamic Visual Motion & Cues")
	ctrl._set_time_warp(0) # 1x
	_assert(ctrl.warp_factor == 1.0, "Time warp set to 1x normal speed")
	
	# Verify space dust particles moving even at 1x
	ctrl._update_space_dust(0.016)
	_assert(ctrl.space_dust_emitter.initial_velocity_min > 5.0, "Space dust velocity active at 1x speed (%.2f m/s)" % ctrl.space_dust_emitter.initial_velocity_min)
	
	# Verify starfield cluster centers on probe
	var starfield_dist = ctrl.starfield_cluster.global_position.distance_to(ctrl.probe_node.global_position)
	_assert(starfield_dist < 0.01, "Spatial starfield cluster dynamically tracks probe position (dist: %.4f units)" % starfield_dist)

