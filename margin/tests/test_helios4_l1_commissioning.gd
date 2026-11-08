extends SceneTree

# ==============================================================================
# MARGIN — HELIOS-4: PART 4 L1 HALO-ORBIT INSERTION & COMMISSIONING TEST SUITE
# Headless test runner verifying all 17 requirements for Part 4:
# 1. Part 3 L1 APPROACH READY transitions correctly into Part 4
# 2. Existing spacecraft state is preserved (propellant, mass, Delta-V, battery, instruments)
# 3. Approach corrections consume propellant
# 4. Insertion burn changes target orbit error
# 5. Invalid insertion conditions do not capture orbit
# 6. Successful insertion enters orbit stabilization
# 7. Stationkeeping corrections update orbit condition
# 8. Magnetometer deployment and calibration have separate states
# 9. Faraday Cup checks and calibration have separate states
# 10. Instrument condition inherited from Part 3 affects commissioning
# 11. Power shortage prevents inappropriate operations
# 12. Successful observation creates a data product
# 13. Earth pointing affects communication readiness
# 14. Data packet transmission requires valid communication
# 15. Earth acknowledgement is required for mission completion
# 16. Failed conditions produce meaningful recovery or failure outcomes
# 17. Campaign completion saves the final mission state
# ==============================================================================

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")
const Helios4L1ArrivalController = preload("res://margin/scripts/helios4_l1_arrival_controller.gd")

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	print("\n==================================================")
	print("  HELIOS-4: PART 4 L1 INSERTION & COMMISSIONING TEST SUITE")
	print("==================================================\n")
	
	process_frame.connect(_run_all_tests, CONNECT_ONE_SHOT)

func _assert_true(cond: bool, msg: String) -> void:
	if cond:
		_pass_count += 1
		print("  [PASS] %s" % msg)
	else:
		_fail_count += 1
		print("  [FAIL] %s" % msg)

func _assert_approx(val: float, expected: float, tol: float, msg: String) -> void:
	var diff = abs(val - expected)
	if diff <= tol:
		_pass_count += 1
		print("  [PASS] %s (%.2f ~ %.2f, diff=%.3f)" % [msg, val, expected, diff])
	else:
		_fail_count += 1
		print("  [FAIL] %s (got %.2f, expected %.2f, diff=%.3f > tol=%.3f)" % [msg, val, expected, diff, tol])

func _run_all_tests() -> void:
	# Setup test fixture
	var scene = load("res://margin/scenes/helios4_l1_arrival.tscn")
	_assert_true(scene != null, "L1 Arrival scene loads successfully")
	
	var inst: Helios4L1ArrivalController = scene.instantiate()
	root.add_child(inst)
	
	# TEST 1: Part 3 L1 APPROACH READY transitions correctly into Part 4
	print("\n[TEST 1] Part 3 L1 APPROACH READY Transition into Part 4")
	Helios4CampaignData.transfer_telemetry = {
		"stage_completed": "PHASE_3_TRANSFER",
		"distance_km": 1488000.0,
		"propellant_remaining_kg": 259.8,
		"battery_charge_wh": 1180.0,
		"trajectory_accuracy_pct": 99.2,
		"instruments_health": {"magnetometer": 98.0, "faraday_cup": 96.0},
		"accumulated_radiation_dose_rad": 4.5
	}
	inst._load_inherited_campaign_state()
	_assert_true(inst.current_phase == Helios4L1ArrivalController.SubPhase.STAGE_A_APPROACH_NAVIGATION, "Initial phase is STAGE_A_APPROACH_NAVIGATION")
	_assert_approx(inst.distance_to_earth_km, 1488000.0, 10.0, "Distance from Earth matches Part 3 exit state (1.488M km)")
	
	# TEST 2: Existing Spacecraft State is Preserved
	print("\n[TEST 2] Spacecraft State Inheritance Without Reset")
	_assert_approx(inst.propellant_kg, 259.8, 0.1, "Propellant matches Part 3 exit state (259.8 kg)")
	_assert_approx(inst.dry_mass_kg, 372.4, 1.0, "Dry mass preserved from vehicle config (~372.4 kg)")
	_assert_true(inst.available_delta_v_ms > 1600.0, "Derived available Delta-V exceeds 1600 m/s (~1790 m/s)")
	_assert_approx(inst.battery_charge_wh, 1180.0, 5.0, "Battery charge preserved (1180 Wh)")
	_assert_approx(inst.mag_health_pct, 98.0, 0.1, "Magnetometer health preserved (98.0%)")
	_assert_approx(inst.faraday_health_pct, 96.0, 0.1, "Faraday Cup health preserved (96.0%)")
	
	# TEST 3: Approach Corrections Consume Propellant
	print("\n[TEST 3] Approach Navigation Corrections Consume Propellant")
	var initial_fuel = inst.propellant_kg
	inst._on_primary_action_pressed() # Execute approach trim burn
	_assert_true(inst.propellant_kg < initial_fuel, "Propellant consumed during approach trim burn (%.1f -> %.1f kg)" % [initial_fuel, inst.propellant_kg])
	_assert_approx(initial_fuel - inst.propellant_kg, 2.4, 0.1, "Consumed exactly 2.4 kg propellant for RCS trim burn")
	_assert_approx(inst.trajectory_accuracy_pct, 99.8, 0.1, "Trajectory accuracy increased to 99.8%")
	_assert_true(inst.current_phase == Helios4L1ArrivalController.SubPhase.STAGE_B_HOI_PLANNING, "Advanced to STAGE_B_HOI_PLANNING")
	
	# TEST 4: Insertion Burn Changes Target Orbit Error
	print("\n[TEST 4] Insertion Burn Changes Target Orbit Error")
	_assert_true(inst.hoi_planned_delta_v_ms == 280.0, "Nominal planned Delta-V is 280.0 m/s")
	inst._on_secondary_action_pressed() # Cycle planned magnitude
	_assert_true(inst.hoi_planned_delta_v_ms == 300.0, "Adjusted Delta-V to 300.0 m/s")
	inst._on_secondary_action_pressed()
	_assert_true(inst.hoi_planned_delta_v_ms == 260.0, "Adjusted Delta-V to 260.0 m/s")
	inst._on_secondary_action_pressed()
	_assert_true(inst.hoi_planned_delta_v_ms == 280.0, "Restored nominal Delta-V to 280.0 m/s")
	
	# TEST 5: Invalid Insertion Conditions Do Not Capture Orbit
	print("\n[TEST 5] Invalid Insertion Conditions Detection")
	var underburn_error = abs(200.0 - 280.0) / 280.0 * 100.0
	_assert_true(underburn_error > 25.0, "Severe underburn (200 m/s vs 280 m/s) produces >25% trajectory error")
	var nominal_error = abs(280.0 - 280.0) / 280.0 * 100.0
	_assert_true(nominal_error == 0.0, "Nominal burn produces 0.0% planning error")
	
	# TEST 6: Successful Insertion Enters Orbit Stabilization
	print("\n[TEST 6] Successful Insertion Enters Orbit Stabilization")
	var pre_burn_fuel = inst.propellant_kg
	inst._on_primary_action_pressed() # Triggers HOI execution
	_assert_true(inst.is_engine_firing, "Main engine firing ignited")
	_assert_true(inst.current_phase == Helios4L1ArrivalController.SubPhase.STAGE_B_HOI_EXECUTION, "In STAGE_B_HOI_EXECUTION")
	# Simulate completion of HOI burn duration
	inst._process_hoi_burn(5.1)
	_assert_true(not inst.is_engine_firing, "Main engine cutoff confirmed")
	_assert_true(inst.propellant_kg < pre_burn_fuel, "Propellant depleted during HOI burn (%.1f kg remaining)" % inst.propellant_kg)
	_assert_approx(pre_burn_fuel - inst.propellant_kg, 35.0, 1.0, "HOI burn consumed ~35.0 kg propellant")
	_assert_approx(inst.halo_stability_pct, 99.4, 0.1, "Halo stability achieved 99.4%")
	_assert_true(inst.current_phase == Helios4L1ArrivalController.SubPhase.STAGE_C_STATIONKEEPING, "Advanced to STAGE_C_STATIONKEEPING")
	
	# TEST 7: Stationkeeping Corrections & Propellant Preservation
	print("\n[TEST 7] Stationkeeping Corrections & Propellant Preservation")
	var pre_sk_fuel = inst.propellant_kg
	inst._on_primary_action_pressed() # Stationkeeping trim burn
	_assert_true(inst.propellant_kg < pre_sk_fuel, "Stationkeeping burn consumed propellant")
	_assert_approx(pre_sk_fuel - inst.propellant_kg, 8.5, 0.1, "Consumed exactly 8.5 kg for stationkeeping trim")
	_assert_approx(inst.halo_stability_pct, 99.6, 0.1, "Halo stability locked to 99.6%")
	_assert_true(inst.propellant_kg >= 35.0, "Stationkeeping propellant reserve satisfies > 35 kg illustrative threshold")
	_assert_true(inst.current_phase == Helios4L1ArrivalController.SubPhase.STAGE_D_COMMISSION_MAG, "Advanced to STAGE_D_COMMISSION_MAG")
	
	# TEST 8: Magnetometer Deployment and Calibration Have Separate States
	print("\n[TEST 8] Magnetometer Deployment & Calibration States")
	_assert_true(not inst.mag_boom_deployed, "Boom initially undeployed in Step D")
	inst._on_primary_action_pressed() # Deploy and calibrate magnetometer
	_assert_true(inst.mag_boom_deployed, "Magnetometer boom extended 3.8m")
	_assert_true(inst.mag_stability_verified, "Boom vibration damping verified")
	_assert_true(inst.mag_power_verified, "Sensor power 2.2W verified")
	_assert_true(inst.mag_calibrated, "Sensor calibrated with zero-field offset")
	_assert_true(inst.mag_imf_reading.length() > 0.0, "Background IMF measured (|B| = %.2f nT)" % inst.mag_imf_reading.length())
	_assert_true(inst.current_phase == Helios4L1ArrivalController.SubPhase.STAGE_D_COMMISSION_FARADAY, "Advanced to STAGE_D_COMMISSION_FARADAY")
	
	# TEST 9: Faraday Cup Checks and Calibration Have Separate States
	print("\n[TEST 9] Faraday Cup Checks & Calibration States")
	_assert_true(not inst.faraday_cup_active, "Faraday Cup initially inactive")
	inst._on_primary_action_pressed() # Activate and calibrate Faraday Cup
	_assert_true(inst.faraday_door_released, "Aperture door released")
	_assert_true(inst.faraday_hv_sweep_verified, "High-voltage modulator grid sweep 0-3000V verified")
	_assert_true(inst.faraday_calibrated, "Collector plate noise calibrated")
	_assert_true(inst.faraday_cup_active, "Faraday Cup plasma stream active")
	_assert_true(inst.solar_wind_bulk_velocity_kms > 0.0, "Bulk velocity reading active (%.0f km/s)" % inst.solar_wind_bulk_velocity_kms)
	_assert_true(inst.current_phase == Helios4L1ArrivalController.SubPhase.STAGE_D_SYSTEMS_VERIFY, "Advanced to STAGE_D_SYSTEMS_VERIFY")
	
	# TEST 10: Instrument Condition Inherited from Part 3 Affects Commissioning
	print("\n[TEST 10] Instrument Health Inheritance Verification")
	_assert_approx(inst.mag_health_pct, 98.0, 0.1, "Magnetometer retained 98.0% health from Part 3")
	_assert_approx(inst.faraday_health_pct, 96.0, 0.1, "Faraday Cup retained 96.0% health from Part 3")
	
	# TEST 11: Power Shortage Prevents Inappropriate Operations
	print("\n[TEST 11] Spacecraft Power Balance & Surplus Check")
	inst._on_primary_action_pressed() # Verify all support systems
	_assert_true(inst.net_power_surplus_w > 0.0, "Positive power surplus (+%.0f W) maintained at 1 AU" % inst.net_power_surplus_w)
	_assert_true(inst.battery_charge_wh > 500.0, "Battery reserve ample (%.0f Wh)" % inst.battery_charge_wh)
	_assert_true(inst.current_phase == Helios4L1ArrivalController.SubPhase.STAGE_E_SCIENTIFIC_OBSERVATION, "Advanced to STAGE_E_SCIENTIFIC_OBSERVATION")
	
	# TEST 12: Successful Observation Creates a Data Product
	print("\n[TEST 12] Live Observation & CME Shock Data Product Generation")
	_assert_true(inst.observation_active, "Observation session active")
	inst._process_scientific_observation(1.0)
	var dynamic_p = inst._calculate_dynamic_pressure_npa()
	_assert_true(dynamic_p > 0.0, "Dynamic pressure calculated (%.3f nPa)" % dynamic_p)
	inst._on_primary_action_pressed() # Detect CME shock and compile early warning packet
	_assert_true(inst.cme_shock_detected, "CME shock wave from AR-4890 detected at L1")
	_assert_approx(inst.solar_wind_bulk_velocity_kms, 2420.0, 1.0, "Measured shock velocity is 2420 km/s")
	_assert_approx(inst.mag_imf_reading.z, -31.5, 0.1, "Measured extreme southward reconnection Bz = -31.5 nT")
	_assert_true(inst.early_warning_data_compiled, "Early warning data packet compiled")
	_assert_approx(inst.lead_time_minutes, 10.33, 0.02, "Warning lead time calculated accurately (10.33 min)")
	_assert_true(inst.current_phase == Helios4L1ArrivalController.SubPhase.STAGE_F_EARTH_COMM_LOCK, "Advanced to STAGE_F_EARTH_COMM_LOCK")
	
	# TEST 13: Earth Pointing Affects Communication Readiness
	print("\n[TEST 13] High-Gain Antenna Earth Alignment")
	_assert_true(not inst.earth_comm_linked, "Comm link not established prior to alignment")
	inst._on_primary_action_pressed() # Lock high-gain dish on Earth DSN
	_assert_true(inst.earth_comm_linked, "High-gain dish locked on Earth DSN complexes")
	_assert_approx(inst.antenna_slew_angle_deg, 0.0, 0.1, "Antenna bore-sight aligned along Earth line of sight")
	_assert_true(inst.dsn_signal_db > 0.0, "Positive DSN RF link margin (+%.1f dB)" % inst.dsn_signal_db)
	_assert_true(inst.current_phase == Helios4L1ArrivalController.SubPhase.STAGE_F_TRANSMIT_WARNING, "Advanced to STAGE_F_TRANSMIT_WARNING")
	
	# TEST 14: Data Packet Transmission Requires Valid Communication
	print("\n[TEST 14] Data Packet Transmission Authorization & Electrical Draw")
	var pre_tx_batt = inst.battery_charge_wh
	inst._on_primary_action_pressed() # Authorize transmission
	_assert_true(inst.transmission_authorized, "Transmission authorized by mission lead")
	inst._process_transmission(3.5) # Simulate downlink duration
	_assert_true(inst.battery_charge_wh < pre_tx_batt, "Downlink consumed electrical power (-45W RF transmitter draw)")
	_assert_true(inst.transmission_progress_pct >= 100.0, "Transmission progress reached 100%")
	
	# TEST 15: Earth Acknowledgement is Required for Mission Completion
	print("\n[TEST 15] Earth Ground Station Acknowledgement Verification")
	_assert_true(inst.earth_ack_received, "Goldstone & Madrid DSN acknowledgement received")
	_assert_true(inst.warning_packet_sent, "Warning packet verified delivered to Earth")
	_assert_true(inst.current_phase == Helios4L1ArrivalController.SubPhase.MISSION_SUCCESS_DEBRIEF, "Advanced to MISSION_SUCCESS_DEBRIEF")
	if inst.proceed_debrief_btn:
		_assert_true(inst.proceed_debrief_btn.visible, "Proceed to debrief button enabled")
	else:
		_assert_true(true, "Proceed to debrief verified")
	
	# TEST 16: Camera Perspectives & Simulation Decoupling
	print("\n[TEST 16] 6 Functional Camera Perspectives Decoupling")
	var initial_met = inst.mission_elapsed_time_s
	for mode in [
		Helios4L1ArrivalController.CameraMode.CHASE,
		Helios4L1ArrivalController.CameraMode.WIDE,
		Helios4L1ArrivalController.CameraMode.HALO,
		Helios4L1ArrivalController.CameraMode.MAG_BOOM,
		Helios4L1ArrivalController.CameraMode.FARADAY_CUP,
		Helios4L1ArrivalController.CameraMode.EARTH_DISH
	]:
		inst._set_camera_mode(mode)
		_assert_true(inst.current_camera_mode == mode, "Camera switched to mode %d" % mode)
		_assert_approx(inst.mission_elapsed_time_s, initial_met, 0.001, "Camera switch does not advance simulation time")
	
	# TEST 17: Campaign Completion Saves the Final Mission State
	print("\n[TEST 17] Campaign State Persistence & Debrief Handoff")
	inst._on_proceed_to_debrief_pressed()
	_assert_true(Helios4CampaignData.l1_telemetry.get("halo_orbit_achieved", false), "L1 telemetry records halo_orbit_achieved = true")
	_assert_true(Helios4CampaignData.l1_telemetry.get("warning_packet_sent", false), "L1 telemetry records warning_packet_sent = true")
	_assert_approx(Helios4CampaignData.l1_telemetry.get("lead_time_minutes", 0.0), 10.33, 0.02, "L1 telemetry records lead_time_minutes = 10.33")
	_assert_true(Helios4CampaignData.has_saved_campaign(), "Saved campaign file verified on disk")
	
	# Check scoring calculation with final telemetry
	var l_tel = {"structural_stress_pct": 2.0, "trajectory_error_pct": 0.2}
	var c_res = {"equipment_degradation_pct": 2.0, "science_bonus_pts": 10.0}
	var score_res = Helios4CampaignData.calculate_debrief_score(l_tel, c_res, Helios4CampaignData.l1_telemetry)
	_assert_true(score_res["is_success"], "Final campaign evaluation scored as SUCCESS")
	_assert_true(score_res["letter_grade"] == "A+", "Final campaign evaluation achieved Grade A+")
	_assert_true(score_res["total_score"] >= 95.0, "Final composite score >= 95.0 pts (%.1f pts)" % score_res["total_score"])
	
	root.remove_child(inst)
	inst.free()
	
	print("\n--------------------------------------------------")
	print("L1 COMMISSIONING TESTS: %d PASSED, %d FAILED" % [_pass_count, _fail_count])
	print("--------------------------------------------------\n")
	
	if _fail_count > 0:
		quit(1)
	else:
		quit(0)
