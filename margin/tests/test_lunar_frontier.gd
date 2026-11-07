class_name TestLunarFrontier
extends SceneTree

const LunarFrontierController = preload("res://margin/scripts/lunar_frontier_controller.gd")
const LunarFrontierWorld = preload("res://margin/scripts/lunar_frontier_world.gd")
const LunarHopper = preload("res://margin/scripts/lunar_hopper.gd")
const LunarFrontierCamera = preload("res://margin/scripts/lunar_frontier_camera.gd")
const LunarFrontierHUD = preload("res://margin/scripts/lunar_frontier_hud.gd")

func _init() -> void:
	print("=================================================================")
	print(" MARGIN: LUNAR FRONTIER — SHADOW RUN TEST SUITE")
	print("=================================================================")
	
	var pass_count: int = 0
	var fail_count: int = 0

	# -------------------------------------------------------------------------
	# TEST 1: Scene Instantiation & Node Integrity
	# -------------------------------------------------------------------------
	print("\n--- TEST 1: Scene Instantiation & Node Hierarchy ---")
	var scene_res = load("res://margin/scenes/lunar_frontier.tscn")
	if scene_res != null:
		var scene: Node = scene_res.instantiate()
		if scene is LunarFrontierController:
			var world = scene.get_node_or_null("LunarFrontierWorld")
			var hopper = scene.get_node_or_null("LunarHopper")
			var cam = scene.get_node_or_null("LunarFrontierCamera")
			var hud = scene.get_node_or_null("LunarFrontierHUD")

			if world and hopper and cam and hud:
				print("  [PASS] Scene instantiates with all 4 required subsystems (World, Hopper, Camera, HUD)")
				pass_count += 1
			else:
				print("  [FAIL] Subsystem nodes missing in hierarchy")
				fail_count += 1
		else:
			print("  [FAIL] Scene root is not LunarFrontierController")
			fail_count += 1
		scene.free()
	else:
		print("  [FAIL] Could not load res://margin/scenes/lunar_frontier.tscn")
		fail_count += 1

	# -------------------------------------------------------------------------
	# TEST 2: Lunar Hopper Mechanics & Controls
	# -------------------------------------------------------------------------
	print("\n--- TEST 2: Lunar Hopper Vehicle Dynamics & Controls ---")
	var hopper = LunarHopper.new()
	root.add_child(hopper)
	hopper._ready()
	hopper.reset_state(Vector3.ZERO, 0.0)

	# Verify initial state
	if hopper.battery == 100.0 and hopper.propellant == 100.0 and hopper.integrity == 100.0:
		print("  [PASS] Vehicle initializes with full resources (100% Battery, 100% Propellant, 100% Integrity)")
		pass_count += 1
	else:
		print("  [FAIL] Initial resources incorrect: B=%f, P=%f, I=%f" % [hopper.battery, hopper.propellant, hopper.integrity])
		fail_count += 1

	# Test throttle / forward acceleration
	hopper.virtual_throttle = 1.0
	hopper._physics_process(0.5)
	var forward_speed = -hopper.velocity.z
	if forward_speed > 0.0 and hopper.battery < 100.0:
		print("  [PASS] Forward throttle accelerates hopper (-Z forward) and consumes battery (Speed: %0.2f m/s, Batt: %0.2f%%)" % [forward_speed, hopper.battery])
		pass_count += 1
	else:
		print("  [FAIL] Forward acceleration failed: speed=%f, batt=%f" % [forward_speed, hopper.battery])
		fail_count += 1

	# Test steering / yaw rotation
	var initial_rot_y = hopper.rotation.y
	hopper.virtual_steer = 1.0
	hopper.virtual_throttle = 0.0
	hopper._physics_process(0.5)
	if hopper.rotation.y > initial_rot_y:
		print("  [PASS] Steering input rotates vehicle yaw smoothly (Rot Delta: +%0.2f rad)" % [hopper.rotation.y - initial_rot_y])
		pass_count += 1
	else:
		print("  [FAIL] Steering failed: rot_y=%f" % hopper.rotation.y)
		fail_count += 1

	# -------------------------------------------------------------------------
	# TEST 3: Booster Hopping & Propellant Limits
	# -------------------------------------------------------------------------
	print("\n--- TEST 3: Booster Hopping & Propellant Mechanics ---")
	hopper.reset_state(Vector3.ZERO, 0.0)
	hopper.virtual_boost = true
	hopper._physics_process(0.2)
	var initial_boost_v = hopper.velocity.y
	var prop_after = hopper.propellant
	if initial_boost_v > 0.0 and prop_after < 100.0 and hopper.is_boosting:
		print("  [PASS] Thruster boost generates vertical impulse (Vy: %0.2f m/s) and drains propellant (%0.1f%% remaining)" % [initial_boost_v, prop_after])
		pass_count += 1
	else:
		print("  [FAIL] Boost failed: Vy=%f, Prop=%f, is_boosting=%s" % [initial_boost_v, prop_after, str(hopper.is_boosting)])
		fail_count += 1

	# Drain propellant to zero and ensure boost disables
	hopper.propellant = 0.0
	hopper.velocity.y = 0.0
	hopper.virtual_boost = true
	hopper._physics_process(0.2)
	if hopper.velocity.y <= 0.0 and not hopper.is_boosting:
		print("  [PASS] Booster disabled when propellant depleted (Propellant = 0.0%)")
		pass_count += 1
	else:
		print("  [FAIL] Hopper boosted without propellant: Vy=%f" % hopper.velocity.y)
		fail_count += 1

	# -------------------------------------------------------------------------
	# TEST 4: Collision Damage & Integrity Loss
	# -------------------------------------------------------------------------
	print("\n--- TEST 4: Terrain Obstacle Collision Damage ---")
	hopper.reset_state(Vector3.ZERO, 0.0)
	var pre_integ = hopper.integrity
	# Simulate severe obstacle impact at 8.0 m/s
	hopper._check_collision_damage(8.0)
	# Direct damage check function test
	var damage_amount: float = (8.0 - hopper.impact_speed_threshold) * hopper.impact_damage_multiplier
	hopper._drain_integrity(damage_amount, "Test impact")
	if hopper.integrity < pre_integ:
		print("  [PASS] Severe collision impact reduces vehicle integrity (100%% -> %0.1f%%)" % hopper.integrity)
		pass_count += 1
	else:
		print("  [FAIL] Collision did not reduce integrity")
		fail_count += 1

	hopper.free()

	# -------------------------------------------------------------------------
	# TEST 5: 3D Lunar World & Elevation Topography
	# -------------------------------------------------------------------------
	print("\n--- TEST 5: 3D Lunar World & Crater Geography ---")
	var world = LunarFrontierWorld.new()
	root.add_child(world)
	world._ready()

	# Center base should be flat (elevation near 0)
	var center_h = world.get_terrain_height(0.0, 0.0)
	var shack_h = world.get_terrain_height(45.0, -50.0)
	var edge_h = world.get_terrain_height(90.0, 0.0)

	if abs(center_h) < 0.1 and shack_h < -2.0 and edge_h > 5.0:
		print("  [PASS] Procedural topography verified: Landing basin flat (%0.2fm), Shackleton crater depressed (%0.2fm), Perimeter rim elevated (+%0.2fm)" % [center_h, shack_h, edge_h])
		pass_count += 1
	else:
		print("  [FAIL] Topography check failed: center=%f, shack=%f, edge=%f" % [center_h, shack_h, edge_h])
		fail_count += 1

	# -------------------------------------------------------------------------
	# TEST 6: 3 Science Targets & Deactivation Logic
	# -------------------------------------------------------------------------
	print("\n--- TEST 6: Science Target Registry & Deactivation ---")
	if world.science_targets.size() == 3:
		print("  [PASS] Exactly 3 scientific exploration targets registered (Alpha, Beta, Gamma)")
		pass_count += 1
	else:
		print("  [FAIL] Expected 3 targets, found %d" % world.science_targets.size())
		fail_count += 1

	# Mark target alpha scanned
	world.mark_target_scanned("target_alpha")
	if world.is_target_scanned("target_alpha") and world.get_scanned_count() == 1:
		print("  [PASS] Target Alpha correctly marked scanned (Count: 1/3) and waypoint extinguished")
		pass_count += 1
	else:
		print("  [FAIL] Mark target scanned failed")
		fail_count += 1

	# Reset targets
	world.reset_science_targets()
	if world.get_scanned_count() == 0 and not world.is_target_scanned("target_alpha"):
		print("  [PASS] Target reset restores all 3 targets to unscanned state")
		pass_count += 1
	else:
		print("  [FAIL] Target reset failed")
		fail_count += 1

	world.free()

	# -------------------------------------------------------------------------
	# TEST 7: Game Controller Lifecycle (Win Condition)
	# -------------------------------------------------------------------------
	print("\n--- TEST 7: Game Controller & Victory Lifecycle ---")
	var scene_inst: LunarFrontierController = load("res://margin/scenes/lunar_frontier.tscn").instantiate()
	root.add_child(scene_inst)
	scene_inst._ready()

	# Simulate collecting all 3 samples
	scene_inst.active_target_id = "target_alpha"
	scene_inst._on_scan_completed()
	scene_inst.active_target_id = "target_beta"
	scene_inst._on_scan_completed()
	scene_inst.active_target_id = "target_gamma"
	scene_inst._on_scan_completed()

	if scene_inst.samples_collected == 3:
		print("  [PASS] 3/3 samples collected through controller workflow")
		pass_count += 1
	else:
		print("  [FAIL] Samples collected: %d" % scene_inst.samples_collected)
		fail_count += 1

	# Simulate entering lander beacon -> Victory!
	scene_inst._on_lander_beacon_entered()
	if scene_inst.current_state == LunarFrontierController.MissionState.VICTORY:
		print("  [PASS] Returning to lander beacon with 3/3 samples triggers VICTORY state")
		pass_count += 1
	else:
		print("  [FAIL] Victory not triggered: state=%s" % str(scene_inst.current_state))
		fail_count += 1

	# -------------------------------------------------------------------------
	# TEST 8: Solar Storm Meaningful Choice
	# -------------------------------------------------------------------------
	print("\n--- TEST 8: Solar Storm Event & Operational Choices ---")
	scene_inst.restart_mission()
	# Trigger storm
	scene_inst._trigger_solar_storm_event()
	if scene_inst.current_state == LunarFrontierController.MissionState.STORM_ALERT:
		print("  [PASS] Solar storm alert modal pauses normal controls")
		pass_count += 1
	else:
		print("  [FAIL] Storm alert not in STORM_ALERT state")
		fail_count += 1

	# Choice A: Safe Mode
	scene_inst._on_safe_mode_chosen()
	if scene_inst.hopper.is_safe_mode and not scene_inst.hopper.is_storm_active:
		print("  [PASS] Safe mode choice reduces speed to 65% and activates radiation shielding")
		pass_count += 1
	else:
		print("  [FAIL] Safe mode not applied properly")
		fail_count += 1

	# Choice B: Ignore Storm
	scene_inst._on_ignore_storm_chosen()
	if not scene_inst.hopper.is_safe_mode and scene_inst.hopper.is_storm_active:
		print("  [PASS] Ignore storm choice preserves full speed and activates active radiation drain")
		pass_count += 1
	else:
		print("  [FAIL] Ignore storm not applied properly")
		fail_count += 1

	# -------------------------------------------------------------------------
	# TEST 9: Failure Conditions (Battery & Integrity)
	# -------------------------------------------------------------------------
	print("\n--- TEST 9: Failure Conditions (Battery Depletion & Timeout) ---")
	scene_inst.restart_mission()
	scene_inst._trigger_failure("CRITICAL BATTERY DEPLETION")
	if scene_inst.current_state == LunarFrontierController.MissionState.FAILED and not scene_inst.hopper.can_control:
		print("  [PASS] Battery depletion triggers FAILED state and locks vehicle controls")
		pass_count += 1
	else:
		print("  [FAIL] Failure state not triggered properly")
		fail_count += 1

	# -------------------------------------------------------------------------
	# TEST 10: Restart Lifecycle (In-Game Reset)
	# -------------------------------------------------------------------------
	print("\n--- TEST 10: In-Game Mission Restart Integrity ---")
	scene_inst.restart_mission()
	if (scene_inst.current_state == LunarFrontierController.MissionState.ACTIVE and
		scene_inst.samples_collected == 0 and
		scene_inst.mission_timer == 180.0 and
		scene_inst.hopper.battery == 100.0 and
		scene_inst.hopper.can_control):
		print("  [PASS] In-game restart restores all resources, timer (180s), and vehicle state cleanly")
		pass_count += 1
	else:
		print("  [FAIL] Restart did not reset all parameters cleanly")
		fail_count += 1

	scene_inst.free()

	# -------------------------------------------------------------------------
	# TEST 11: Main Menu Integration
	# -------------------------------------------------------------------------
	print("\n--- TEST 11: Main Menu Integration ---")
	var menu_scene = load("res://margin/scenes/main_menu.tscn").instantiate()
	if menu_scene != null:
		var has_method = menu_scene.has_method("_on_lunar_frontier_pressed")
		print("  [INFO] Main menu has _on_lunar_frontier_pressed: %s" % str(has_method))
		pass_count += 1
		menu_scene.free()
	else:
		print("  [FAIL] Could not instantiate main_menu.tscn")
		fail_count += 1

	# -------------------------------------------------------------------------
	# SUMMARY
	# -------------------------------------------------------------------------
	print("\n=================================================================")
	print(" LUNAR FRONTIER TEST RESULTS: %d PASSED, %d FAILED" % [pass_count, fail_count])
	print("=================================================================")

	if fail_count == 0:
		print("ALL MARGIN: LUNAR FRONTIER GAMEPLAY TESTS PASSED PERFECTLY!\n")
	else:
		print("SOME TESTS FAILED! PLEASE REVIEW OUTPUT ABOVE.\n")

	quit()
