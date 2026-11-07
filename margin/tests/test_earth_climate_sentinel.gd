class_name TestEarthClimateSentinel
extends SceneTree

const MissionScenario = preload("res://margin/data/mission_scenario.gd")
const MissionData = preload("res://margin/data/mission_data.gd")
const ComponentDatabase = preload("res://margin/data/component_data.gd")
const OrbitData = preload("res://margin/data/orbit_data.gd")
const TransferData = preload("res://margin/data/transfer_data.gd")
const LaunchVehicleData = preload("res://margin/data/launch_vehicle_data.gd")
const MissionOperationsData = preload("res://margin/data/mission_operations_data.gd")
const SpacecraftState = preload("res://margin/scripts/spacecraft_state.gd")
const MissionSimulator = preload("res://margin/scripts/mission_simulator.gd")
const ScoringEngine = preload("res://margin/scripts/scoring_engine.gd")

var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	print("\n==================================================")
	print("  MARGIN: EARTH CLIMATE SENTINEL (ECS-01) TEST SUITE")
	print("==================================================")
	
	test_scenario_switching()
	test_earth_instruments()
	test_earth_orbits_and_transfers()
	test_launch_vehicle_leo_capacity()
	test_earth_climate_targets()
	test_spacecraft_state_with_earth_scenario()
	test_ecs_simulation_run()
	test_ecs_scoring_thresholds()
	
	# Cleanup: restore default lunar scenario
	MissionScenario.set_active_scenario("lunar_south_pole")
	
	print("\n--------------------------------------------------")
	print("ECS-01 TESTS: %d PASSED, %d FAILED" % [_passed, _failed])
	print("--------------------------------------------------\n")
	
	if _failed > 0:
		quit(1)
	else:
		quit(0)

func _assert_true(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] %s" % msg)
	else:
		_failed += 1
		printerr("  [FAIL] %s" % msg)

func test_scenario_switching() -> void:
	print("\n[TEST 1] Scenario Registration and Switching")
	MissionScenario.set_active_scenario("lunar_south_pole")
	var lsp = MissionScenario.get_active_scenario()
	_assert_true(lsp.id == "lunar_south_pole", "Default scenario is lunar_south_pole")
	_assert_true(lsp.code == "LSP-01", "Lunar scenario code is LSP-01")
	_assert_true(is_equal_approx(lsp.budget_cap_m, 180.0), "LSP-01 budget is $180.0M")
	_assert_true(is_equal_approx(lsp.mass_limit_kg, 380.0), "LSP-01 mass limit is 380.0 kg")
	_assert_true(is_equal_approx(lsp.min_science_points, 70.0), "LSP-01 target threshold is 70.0 pts")
	
	MissionScenario.set_active_scenario("earth_climate_sentinel")
	var ecs = MissionScenario.get_active_scenario()
	_assert_true(ecs.id == "earth_climate_sentinel", "Active scenario switched to earth_climate_sentinel")
	_assert_true(ecs.code == "ECS-01", "ECS scenario code is ECS-01")
	_assert_true(is_equal_approx(ecs.budget_cap_m, 140.0), "ECS-01 budget is $140.0M")
	_assert_true(is_equal_approx(ecs.mass_limit_kg, 550.0), "ECS-01 mass limit is 550.0 kg")
	_assert_true(is_equal_approx(ecs.min_science_points, 75.0), "ECS-01 target threshold is 75.0 pts")
	_assert_true(is_equal_approx(ecs.required_delta_v_ms, 75.0), "ECS-01 required delta-V is 75.0 m/s")
	_assert_true(is_equal_approx(ecs.max_eclipse_min, 35.0), "ECS-01 max eclipse is 35.0 min (vs 48 min lunar)")

func test_earth_instruments() -> void:
	print("\n[TEST 2] Earth Observation Payloads")
	var inst_rad = ComponentDatabase.get_component("inst_multispectral_radiometer")
	_assert_true(not inst_rad.is_empty(), "Multispectral Radiometer exists")
	_assert_true(inst_rad.get("power_w", 0) == -52.0, "Radiometer power draw is -52W")
	
	var inst_ghg = ComponentDatabase.get_component("inst_ghg_spectrometer")
	_assert_true(not inst_ghg.is_empty(), "GHG Spectrometer exists")
	_assert_true(inst_ghg.get("heritage_name", "").contains("OCO-2"), "GHG Spectrometer cites OCO-2 heritage")
	
	var inst_sar = ComponentDatabase.get_component("inst_polarimetric_ice_sar")
	_assert_true(not inst_sar.is_empty(), "Polarimetric Ice SAR exists")
	_assert_true(inst_sar.get("heritage_name", "").contains("CryoSat-2"), "Ice SAR cites CryoSat-2 heritage")

func test_earth_orbits_and_transfers() -> void:
	print("\n[TEST 3] Earth Orbits and Direct Ascent Transfers")
	var earth_orbits = OrbitData.get_orbits_for_scenario("earth_climate_sentinel")
	_assert_true(earth_orbits.has("orbit_earth_sso"), "Earth orbits includes 705 km SSO")
	_assert_true(earth_orbits.has("orbit_earth_polar_leo"), "Earth orbits includes 450 km Polar LEO")
	_assert_true(not earth_orbits.has("orbit_low_circular"), "Earth orbits excludes lunar orbits")
	
	var sso = OrbitData.get_orbit("orbit_earth_sso")
	_assert_true(is_equal_approx(sso.get("avg_altitude_km", 0.0), 705.0), "SSO altitude is 705.0 km")
	_assert_true(sso.get("orbit_type", "").contains("98.2°"), "SSO inclination is 98.2 deg")
	
	var earth_transfers = TransferData.get_transfers_for_scenario("earth_climate_sentinel")
	_assert_true(earth_transfers.has("transfer_leo_direct"), "Earth transfers includes transfer_leo_direct")
	_assert_true(not earth_transfers.has("transfer_low_energy"), "Earth transfers excludes translunar BLT")

func test_launch_vehicle_leo_capacity() -> void:
	print("\n[TEST 4] Launch Vehicle LEO Payload Capacity")
	var small_lv = LaunchVehicleData.get_vehicle("lv_rideshare_small")
	var leo_cap = LaunchVehicleData.get_vehicle_payload_capacity("lv_rideshare_small", "earth_climate_sentinel")
	var tli_cap = LaunchVehicleData.get_vehicle_payload_capacity("lv_rideshare_small", "lunar_south_pole")
	_assert_true(leo_cap == 650.0, "Small rideshare LEO capacity is 650 kg")
	_assert_true(tli_cap == 260.0, "Small rideshare TLI capacity is 260 kg")
	_assert_true(leo_cap > tli_cap, "LEO capacity is significantly higher than TLI capacity")

func test_earth_climate_targets() -> void:
	print("\n[TEST 5] Global Climate Sentinel Targets")
	var sentinels = MissionOperationsData.get_targets_for_scenario("earth_climate_sentinel")
	_assert_true(sentinels.size() == 6, "ECS-01 has exactly 6 global sentinels")
	_assert_true(sentinels.has("sentinel_greenland"), "Has Greenland Summit sentinel")
	_assert_true(sentinels.has("sentinel_antarctic_peninsula"), "Has Antarctic Peninsula sentinel")
	_assert_true(sentinels.has("sentinel_amazon_basin"), "Has Amazon Basin sentinel")
	_assert_true(sentinels.has("sentinel_sahel_boundary"), "Has Sahel boundary sentinel")
	_assert_true(sentinels.has("sentinel_north_atlantic"), "Has North Atlantic AMOC sentinel")
	_assert_true(sentinels.has("sentinel_siberian_permafrost"), "Has Siberian permafrost sentinel")
	
	var grn = sentinels["sentinel_greenland"]
	_assert_true(grn.get("lat_deg", 0.0) > 70.0, "Greenland is Arctic high latitude")
	_assert_true(grn.get("science_weight", 0.0) >= 1.2, "Greenland science weight is valid")

func test_spacecraft_state_with_earth_scenario() -> void:
	print("\n[TEST 6] Spacecraft State Telemetry in ECS-01")
	MissionScenario.set_active_scenario("earth_climate_sentinel")
	
	var state = SpacecraftState.new()
	state.set_component(ComponentDatabase.Category.INSTRUMENTS, "inst_multispectral_radiometer")
	
	var t = state.calculate_telemetry()
	_assert_true(t["budget_qualified"], "State budget is qualified under ECS-01 limit ($140.0M)")
	_assert_true(t["mass_qualified"], "State mass is qualified under ECS-01 limit (550.0 kg)")
	_assert_true(t["delta_v_reserve_ms"] > 0.0, "Delta-V reserve is positive for LEO operations")

func test_ecs_simulation_run() -> void:
	print("\n[TEST 7] 12-Month Mission Operations Simulation in ECS-01")
	MissionScenario.set_active_scenario("earth_climate_sentinel")
	
	var state = SpacecraftState.new()
	state.set_component(ComponentDatabase.Category.INSTRUMENTS, "inst_ghg_spectrometer")
	
	var sim = MissionSimulator.new()
	sim.initialize(state, "orbit_earth_sso", "transfer_leo_direct", "lv_rideshare_small")
	
	_assert_true(sim.crater_coverage.has("sentinel_greenland"), "Simulator initialized with Greenland sentinel")
	_assert_true(sim.selected_orbit["id"] == "orbit_earth_sso", "Simulator using 705 km SSO")
	
	var targets = ["sentinel_greenland", "sentinel_antarctic_peninsula", "sentinel_amazon_basin", "sentinel_sahel_boundary", "sentinel_north_atlantic", "sentinel_siberian_permafrost"]
	for i in range(12):
		var target_id = targets[i % targets.size()]
		sim.advance_window("mode_nominal", target_id, "opt_shelter")
	
	_assert_true(sim.is_completed, "ECS-01 campaign completed 12 windows")
	var summary = sim.get_campaign_summary()
	_assert_true(summary["scenario_id"] == "earth_climate_sentinel", "Summary scenario is earth_climate_sentinel")
	_assert_true(summary["final_science_score"] >= 75.0, "Science score achieved threshold (>= 75.0 pts)")
	_assert_true(summary["is_success"], "Campaign completed successfully")

func test_ecs_scoring_thresholds() -> void:
	print("\n[TEST 8] Scoring Engine ECS-01 Threshold Evaluation")
	MissionScenario.set_active_scenario("earth_climate_sentinel")
	
	var state = SpacecraftState.new()
	state.set_component(ComponentDatabase.Category.INSTRUMENTS, "inst_polarimetric_ice_sar")
	
	var sim = MissionSimulator.new()
	sim.initialize(state, "orbit_earth_sso", "transfer_leo_direct", "lv_rideshare_small")
	
	var targets = ["sentinel_greenland", "sentinel_antarctic_peninsula", "sentinel_amazon_basin", "sentinel_sahel_boundary", "sentinel_north_atlantic", "sentinel_siberian_permafrost"]
	for i in range(12):
		sim.advance_window("mode_nominal", targets[i % targets.size()], "")
	
	var summary = sim.get_campaign_summary()
	var debrief = ScoringEngine.evaluate_mission(summary, state)
	
	_assert_true(debrief.has("outcome"), "Debrief generated outcome")
	_assert_true(debrief["outcome"] == "SUCCESS", "Debrief outcome is SUCCESS for compliant mission")
	_assert_true(debrief.has("pillars"), "Debrief has 8 pillars")
	_assert_true(debrief["pillars"].size() == 8, "Exactly 8 pillars evaluated")
	_assert_true(debrief["total_weighted_score"] >= 75.0, "Total score meets ECS-01 requirement (>= 75.0 pts)")
