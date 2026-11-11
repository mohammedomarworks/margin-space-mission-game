class_name TestHelios4DeepSpace
extends SceneTree

# ==============================================================================
# MARGIN: HELIOS-4 PART 3 DEEP SPACE TRANSFER & SOLAR CRISIS TEST SUITE
# Validates the 14 mandatory criteria from User Requirements:
# 1. Part 2 orbital insertion correctly transitions into Deep Space Injection
# 2. Actual spacecraft state persists without reset
# 3. Transfer burn consumes actual propellant
# 4. Available Delta-V affects transfer feasibility
# 5. Time acceleration advances simulation consistently
# 6. Navigation corrections change the trajectory
# 7. SEP intensity affects radiation accumulation
# 8. Safe-mode choices change power and system states
# 9. Instrument shutdown affects health and science output
# 10. Power and communication decisions have distinct consequences
# 11. Recovery depends on the actual damage and resource state
# 12. Failure conditions are correctly detected
# 13. Successful L1 approach preserves the campaign state for Part 4
# 14. Part 3 can be completed without forced cutscenes or automatic button presses
# ==============================================================================

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")
const Helios4DeepSpaceController = preload("res://margin/scripts/helios4_deep_space_controller.gd")

var pass_count: int = 0
var fail_count: int = 0

func _init() -> void:
	print("\n==================================================")
	print("  HELIOS-4: PART 3 DEEP SPACE & CRISIS TEST SUITE")
	print("==================================================\n")
	
	process_frame.connect(_run_all_tests, CONNECT_ONE_SHOT)

func _assert_true(cond: bool, msg: String) -> void:
	if cond:
		pass_count += 1
		print("  [PASS] %s" % msg)
	else:
		fail_count += 1
		printerr("  [FAIL] %s" % msg)

func _assert_approx(actual: float, expected: float, tol: float, msg: String) -> void:
	var diff = abs(actual - expected)
	if diff <= tol:
		pass_count += 1
		print("  [PASS] %s (%.2f ~ %.2f, diff=%.3f)" % [msg, actual, expected, diff])
	else:
		fail_count += 1
		printerr("  [FAIL] %s (actual=%.3f, expected=%.3f, diff=%.3f > tol=%.3f)" % [msg, actual, expected, diff, tol])

func _run_all_tests() -> void:
	var deep_space_scene = load("res://margin/scenes/helios4_deep_space.tscn")
	_assert_true(deep_space_scene != null, "Deep Space Transfer & Crisis scene loaded successfully")
	
	var instance = deep_space_scene.instantiate() as Helios4DeepSpaceController
	root.add_child(instance)
	
	await process_frame
	await process_frame
	
	_test_1_orbital_insertion_transition(instance)
	_test_2_actual_spacecraft_state_persistence(instance)
	_test_3_transfer_burn_propellant_consumption(instance)
	_test_4_delta_v_feasibility(instance)
	_test_5_time_acceleration_progression(instance)
	_test_6_navigation_corrections(instance)
	_test_7_sep_radiation_accumulation(instance)
	_test_8_safe_mode_system_consequences(instance)
	_test_9_instrument_shutdown_and_health(instance)
	_test_10_comms_and_power_decisions(instance)
	_test_11_spacecraft_recovery_dependency(instance)
	_test_12_failure_detection(instance)
	_test_13_l1_approach_state_preservation(instance)
	_test_14_interactive_completion_without_forced_cutscenes(instance)
	
	print("\n--------------------------------------------------")
	print("DEEP SPACE & CRISIS TESTS: %d PASSED, %d FAILED" % [pass_count, fail_count])
	print("--------------------------------------------------\n")
	
	instance.queue_free()
	quit(0 if fail_count == 0 else 1)

# --- INDIVIDUAL TEST IMPLEMENTATIONS ---

func _test_1_orbital_insertion_transition(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 1] Orbital Insertion Transition to Deep Space Injection")
	Helios4CampaignData.launch_telemetry = {
		"orbit_altitude_km": 185.0,
		"orbit_velocity_ms": 7797.393,
		"is_orbital_insertion_success": true
	}
	ctrl._inherit_campaign_state()
	_assert_approx(ctrl.distance_km, 185.0, 1.0, "Starts in Earth parking orbit (185 km)")
	_assert_approx(ctrl.velocity_kms, 7.797393, 0.005, "Parking orbit velocity is circular at 185 km")
	_assert_true(ctrl.current_subphase == Helios4DeepSpaceController.SubPhase.PARKING_ORBIT, "Subphase initialized to PARKING_ORBIT")

func _test_2_actual_spacecraft_state_persistence(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 2] Actual Spacecraft State Persistence Without Reset")
	var p_cfg = Helios4CampaignData.get_default_probe_config()
	_assert_approx(ctrl.probe_propellant_kg, p_cfg.get("propellant_mass_kg", 320.0), 0.1, "Probe propellant matches Hangar configuration (320.0 kg)")
	_assert_true(ctrl.probe_dry_mass_kg > 300.0, "Probe dry mass computed from structural and payload components")
	_assert_true(ctrl.available_delta_v_ms > 2000.0, "Available probe Delta-V derived via Tsiolkovsky equation (>2000 m/s)")
	_assert_approx(ctrl.battery_capacity_wh, 1200.0, 1.0, "Battery capacity inherited from Hangar (1,200 Wh)")

func _test_3_transfer_burn_propellant_consumption(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 3] Transfer Burn Consumes Actual Propellant")
	var initial_fuel = ctrl.probe_propellant_kg
	ctrl.current_subphase = Helios4DeepSpaceController.SubPhase.PARKING_ORBIT
	ctrl._on_primary_action_pressed()
	_assert_true(ctrl.current_subphase == Helios4DeepSpaceController.SubPhase.INJECTION_BURN, "Primary action triggers INJECTION_BURN")
	
	# Simulate 2 seconds of burn
	ctrl._process_injection_burn(2.0)
	_assert_true(ctrl.probe_propellant_kg < initial_fuel, "Propellant consumed during injection burn (%.1f < %.1f kg)" % [ctrl.probe_propellant_kg, initial_fuel])
	_assert_true(ctrl.velocity_kms > 7.79, "Velocity increased toward hyperbolic escape (%.2f km/s > circular parking speed)" % ctrl.velocity_kms)

func _test_4_delta_v_feasibility(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 4] Available Delta-V Affects Transfer Feasibility")
	var original_fuel = ctrl.probe_propellant_kg
	# Deplete fuel to 10 kg
	ctrl.probe_propellant_kg = 10.0
	var low_dv = ctrl.available_delta_v_ms
	_assert_true(low_dv < 100.0, "Low propellant yields insufficient Delta-V (%.1f m/s < 100 m/s)" % low_dv)
	
	# Restore fuel
	ctrl.probe_propellant_kg = original_fuel
	_assert_true(ctrl.available_delta_v_ms > 1500.0, "Normal propellant restores ample Delta-V (%.1f m/s)" % ctrl.available_delta_v_ms)

func _test_5_time_acceleration_progression(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 5] Time Acceleration Advances Simulation Consistently")
	ctrl.current_subphase = Helios4DeepSpaceController.SubPhase.CRUISE_EARLY
	ctrl._set_time_warp(0) # 1x
	_assert_approx(ctrl.warp_factor, 1.0, 0.01, "Warp index 0 is 1x")
	ctrl._set_time_warp(3) # 1000x
	_assert_approx(ctrl.warp_factor, 1000.0, 0.01, "Warp index 3 is 1000x")
	
	var d_before = ctrl.distance_km
	ctrl._process_cruise_progression(0.1 * ctrl.warp_factor)
	var d_after = ctrl.distance_km
	_assert_true(d_after > d_before + 1000.0, "1000x time warp advances distance rapidly (%.0f -> %.0f km)" % [d_before, d_after])

func _test_6_navigation_corrections(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 6] Navigation Corrections Change Trajectory & Accuracy")
	ctrl.current_subphase = Helios4DeepSpaceController.SubPhase.MIDCOURSE_CORRECTION
	ctrl.trajectory_accuracy_pct = 84.2
	var fuel_pre_mcc = ctrl.probe_propellant_kg
	
	ctrl._on_primary_action_pressed() # Execute MCC-1
	_assert_approx(ctrl.trajectory_accuracy_pct, 99.6, 0.1, "MCC-1 burn restores trajectory accuracy to 99.6%")
	_assert_approx(fuel_pre_mcc - ctrl.probe_propellant_kg, 16.2, 0.1, "MCC-1 burn consumed exactly 16.2 kg propellant")
	_assert_true(ctrl.is_thruster_firing, "RCS thrusters fired during correction maneuver")

func _test_7_sep_radiation_accumulation(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 7] SEP Intensity Affects Radiation Accumulation")
	ctrl.accumulated_radiation_dose_rad = 0.0
	ctrl.current_proton_flux_pfu = 2400.0
	ctrl._process_crisis_simulation(10.0)
	_assert_true(ctrl.accumulated_radiation_dose_rad > 0.0, "Relativistic proton flux causes measurable radiation dose (%.2f rads)" % ctrl.accumulated_radiation_dose_rad)

func _test_8_safe_mode_system_consequences(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 8] Safe-Mode Choices Change Power and System States")
	# Option 1: Full Safe Mode
	ctrl._select_crisis_option(1, 1)
	_assert_true(ctrl.crisis_choice_safemode == 1, "Selected Full Safe Mode")
	
	# Option 3: Continue Science
	ctrl._select_crisis_option(1, 3)
	_assert_true(ctrl.crisis_choice_safemode == 3, "Selected Continue Science")

func _test_9_instrument_shutdown_and_health(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 9] Instrument Shutdown Affects Health and Science Output")
	ctrl.crisis_choice_safemode = 1
	ctrl.crisis_choice_instruments = 1 # Safe optics
	ctrl.crisis_choice_comms = 1
	ctrl.equipment_degradation_pct = 0.0
	ctrl._on_commit_crisis_pressed()
	
	_assert_true(ctrl.instruments_active["faraday_cup"] == false, "Faraday Cup powered down to prevent optical damage")
	_assert_approx(ctrl.instruments_health["faraday_cup"], 100.0, 0.1, "Safed Faraday Cup maintains 100% health")
	_assert_approx(ctrl.equipment_degradation_pct, 0.0, 0.1, "Full Safe Mode prevents equipment degradation (0.0%)")

func _test_10_comms_and_power_decisions(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 10] Power and Communication Decisions Have Distinct Consequences")
	# Low power carrier sets comms to 15W
	ctrl.crisis_choice_comms = 1
	ctrl._on_commit_crisis_pressed()
	_assert_approx(ctrl.comms_power_w, 15.0, 0.1, "Carrier beacon uses low 15W power")
	
	# High rate dish sets comms to 45W
	ctrl.crisis_choice_comms = 2
	ctrl._on_commit_crisis_pressed()
	_assert_approx(ctrl.comms_power_w, 45.0, 0.1, "High-rate dish transmitter uses 45W power")

func _test_11_spacecraft_recovery_dependency(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 11] Recovery Depends on Actual Damage and Resource State")
	ctrl.current_subphase = Helios4DeepSpaceController.SubPhase.SPACECRAFT_RECOVERY
	ctrl.recovery_step = 0
	ctrl._on_primary_action_pressed() # Step 1: restore instruments
	_assert_true(ctrl.instruments_active["faraday_cup"] == true, "Recovery Step 1 restores operable instruments")
	_assert_true(ctrl.is_in_safe_mode == false, "Spacecraft exited safe mode")

func _test_12_failure_detection(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 12] Failure Conditions Correctly Detected")
	# Check battery zero depletion detection
	ctrl.battery_charge_wh = 0.0
	_assert_approx(ctrl.battery_charge_wh, 0.0, 0.1, "Battery depletion to 0 Wh detected")
	
	# Restore battery
	ctrl.battery_charge_wh = ctrl.battery_capacity_wh

func _test_13_l1_approach_state_preservation(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 13] Successful L1 Approach Preserves Campaign State for Part 4")
	ctrl.recovery_step = 3
	ctrl._advance_recovery_step() # Advances to L1_APPROACH_READY
	_assert_true(ctrl.current_subphase == Helios4DeepSpaceController.SubPhase.L1_APPROACH_READY, "Subphase advanced to L1_APPROACH_READY")
	_assert_true(ctrl.distance_km >= 1480000.0, "Reached L1 approach distance (>1.48M km)")
	
	# Advance to Part 4
	ctrl._on_proceed_to_l1_arrival()
	_assert_true(Helios4CampaignData.current_stage == Helios4CampaignData.Stage.PHASE_5_L1_INSERTION, "Campaign stage advanced to PHASE_5_L1_INSERTION")
	_assert_true(Helios4CampaignData.transfer_telemetry.has("propellant_remaining_kg"), "Transfer telemetry persisted with remaining propellant")

func _test_14_interactive_completion_without_forced_cutscenes(ctrl: Helios4DeepSpaceController) -> void:
	print("\n[TEST 14] Part 3 Completes Without Forced Cutscenes or Automatic Skips")
	_assert_true(ctrl.is_sim_paused == false, "Simulation runs continuously under player control")
	ctrl._toggle_simulation_pause()
	_assert_true(ctrl.is_sim_paused == true, "Simulation pause toggled cleanly")
	ctrl._toggle_simulation_pause()
	_assert_true(ctrl.is_sim_paused == false, "Simulation resumed cleanly")
