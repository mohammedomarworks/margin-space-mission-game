class_name TestSandboxMode
extends SceneTree

const MissionScenario = preload("res://margin/data/mission_scenario.gd")
const SpacecraftState = preload("res://margin/scripts/spacecraft_state.gd")
const ComponentDatabase = preload("res://margin/data/component_data.gd")
const MissionSimulator = preload("res://margin/scripts/mission_simulator.gd")
const ScoringEngine = preload("res://margin/scripts/scoring_engine.gd")

var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	print("\n==================================================")
	print("  MARGIN: CREATIVE SANDBOX MODE TEST SUITE")
	print("==================================================")
	
	test_sandbox_activation()
	test_sandbox_relaxed_constraints()
	test_sandbox_telemetry_accuracy()
	test_sandbox_save_load_reset()
	test_sandbox_simulation_run()
	test_sandbox_debrief_evaluation()
	
	# Cleanup
	MissionScenario.set_active_scenario("lunar_south_pole")
	var dir = DirAccess.open("user://")
	if dir and dir.file_exists("test_sandbox_save.json"):
		dir.remove("test_sandbox_save.json")
		
	print("\n--------------------------------------------------")
	print("SANDBOX MODE TESTS: %d PASSED, %d FAILED" % [_passed, _failed])
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

func test_sandbox_activation() -> void:
	print("\n[TEST 1] Sandbox Mode Activation & Metadata")
	MissionScenario.set_active_scenario("sandbox")
	_assert_true(MissionScenario.is_sandbox_active(), "Sandbox scenario is active")
	
	var sbx = MissionScenario.get_active_scenario()
	_assert_true(sbx.id == "sandbox", "Scenario ID is sandbox")
	_assert_true(sbx.code == "SBX-00", "Scenario code is SBX-00")
	_assert_true(is_equal_approx(sbx.budget_cap_m, 999.0), "Budget cap relaxed to $999.0M")
	_assert_true(is_equal_approx(sbx.mass_limit_kg, 9999.0), "Mass limit relaxed to 9999.0 kg")
	_assert_true(is_equal_approx(sbx.min_science_points, 0.0), "Competitive science requirement disengaged (0.0 pts)")

func test_sandbox_relaxed_constraints() -> void:
	print("\n[TEST 2] Relaxed Constraints Validation Under Extreme Hardware")
	MissionScenario.set_active_scenario("sandbox")
	
	var state = SpacecraftState.new()
	# Equip heaviest, most power-hungry and expensive instrumentation
	state.set_component(ComponentDatabase.Category.INSTRUMENTS, "inst_polarimetric_ice_sar") # $42M, 58 kg, 135W
	
	var t = state.calculate_telemetry()
	_assert_true(t["budget_qualified"], "Expensive design qualified under $999.0M sandbox budget")
	_assert_true(t["mass_qualified"], "Heavy spacecraft qualified under 9999.0 kg sandbox limit")
	_assert_true(t["budget_margin_pct"] > 80.0, "Budget margin is massively positive")

func test_sandbox_telemetry_accuracy() -> void:
	print("\n[TEST 3] Real Live Telemetry Calculations in Sandbox")
	MissionScenario.set_active_scenario("sandbox")
	
	var state = SpacecraftState.new()
	var t = state.calculate_telemetry()
	
	_assert_true(t["wet_mass_kg"] > 0.0, "Wet mass computed dynamically")
	_assert_true(t["dry_mass_kg"] > 0.0, "Dry mass computed dynamically")
	_assert_true(t["delta_v_ms"] > 0.0, "Tsiolkovsky delta-V computed dynamically")
	_assert_true(t["power_gen_w"] > 0.0, "Power generation computed dynamically")
	_assert_true(t["system_reliability_pct"] > 0.0, "Composite reliability computed dynamically")
	_assert_true(t["science_score"] > 0.0, "Science score computed dynamically")

func test_sandbox_save_load_reset() -> void:
	print("\n[TEST 4] Custom Spacecraft Configuration Save, Load & Reset")
	var save_path = "user://test_sandbox_save.json"
	
	var state = SpacecraftState.new()
	state.set_component(ComponentDatabase.Category.INSTRUMENTS, "inst_ghg_spectrometer")
	var initial_t = state.calculate_telemetry()
	
	# 1. Save custom configuration
	var saved = state.save_to_file(save_path)
	_assert_true(saved, "Successfully saved custom spacecraft to JSON")
	_assert_true(FileAccess.file_exists(save_path), "Save file exists on disk")
	
	# 2. Reset to default
	state.reset_to_default()
	var reset_t = state.calculate_telemetry()
	_assert_true(state.get_component_id(ComponentDatabase.Category.INSTRUMENTS) == "inst_neutron_spectrometer", "Reset restored default instrument")
	
	# 3. Load custom configuration back
	var loaded = state.load_from_file(save_path)
	_assert_true(loaded, "Successfully loaded custom spacecraft from JSON")
	_assert_true(state.get_component_id(ComponentDatabase.Category.INSTRUMENTS) == "inst_ghg_spectrometer", "Loaded configuration restored GHG spectrometer")
	
	var reloaded_t = state.calculate_telemetry()
	_assert_true(is_equal_approx(reloaded_t["wet_mass_kg"], initial_t["wet_mass_kg"]), "Wet mass matches pre-save state bit-for-bit")
	_assert_true(is_equal_approx(reloaded_t["total_cost_m"], initial_t["total_cost_m"]), "Total cost matches pre-save state bit-for-bit")

func test_sandbox_simulation_run() -> void:
	print("\n[TEST 5] Sandbox Mission Simulation Flight")
	MissionScenario.set_active_scenario("sandbox")
	
	var state = SpacecraftState.new()
	state.set_component(ComponentDatabase.Category.POWER_GENERATION, "power_roflex_array")
	state.set_component(ComponentDatabase.Category.BATTERY, "batt_solid_state")
	state.set_component(ComponentDatabase.Category.PROPULSION, "prop_bipropellant_mon")
	state.set_component(ComponentDatabase.Category.INSTRUMENTS, "inst_polarimetric_ice_sar")
	
	var sim = MissionSimulator.new()
	sim.initialize(state, "orbit_low_circular", "transfer_direct", "lv_heavy_dedicated")
	
	for i in range(12):
		sim.advance_window("mode_high_res", "crater_shackleton", "")
		
	_assert_true(sim.is_completed, "Sandbox mission simulation completed 12 windows")
	var summary = sim.get_campaign_summary()
	_assert_true(summary["scenario_id"] == "sandbox", "Summary scenario is sandbox")
	_assert_true(summary["is_success"], "Sandbox campaign is successful (no prohibitive threshold)")

func test_sandbox_debrief_evaluation() -> void:
	print("\n[TEST 6] Sandbox Debrief Evaluation & Leaderboard Exemption")
	MissionScenario.set_active_scenario("sandbox")
	
	var state = SpacecraftState.new()
	var sim = MissionSimulator.new()
	sim.initialize(state, "orbit_low_circular", "transfer_direct", "lv_heavy_dedicated")
	for i in range(12):
		sim.advance_window("mode_nominal", "crater_shackleton", "")
		
	var summary = sim.get_campaign_summary()
	var debrief = ScoringEngine.evaluate_mission(summary, state)
	
	_assert_true(debrief.has("outcome"), "Debrief outcome generated")
	_assert_true(debrief.has("pillars"), "All 8 pillars evaluated for telemetry study")
	_assert_true(debrief["total_weighted_score"] > 0.0, "Total score calculated for engineering insight")
