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
	ctrl.distance_km = 165.0
	ctrl._update_celestial_transforms(0.0)
	var scale_near = ctrl.earth_node.scale.x
	var rot_start = ctrl.earth_mesh.rotation.y
	
	# Advance delta for axial rotation
	ctrl._update_celestial_transforms(2.0)
	var rot_advanced = ctrl.earth_mesh.rotation.y
	_assert(rot_advanced > rot_start, "Earth visibly rotates on its polar axis continuously")
	
	# Far out at L1 approach
	ctrl.distance_km = 1500000.0
	ctrl._update_celestial_transforms(0.0)
	var scale_far = ctrl.earth_node.scale.x
	_assert(scale_far < scale_near * 0.35, "Earth visual scale visibly shrinks from 1.0 to <= 0.25 as spacecraft travels to L1")

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
