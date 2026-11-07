class_name TestInteractiveOperations
extends SceneTree

const MissionSimulator = preload("res://margin/scripts/mission_simulator.gd")
const SpacecraftState = preload("res://margin/scripts/spacecraft_state.gd")
const ScoringEngine = preload("res://margin/scripts/scoring_engine.gd")
const MissionOperationsData = preload("res://margin/data/mission_operations_data.gd")

var _passed_count: int = 0
var _failed_count: int = 0

func _init() -> void:
	print("\n=================================================================")
	print(" MARGIN: INTERACTIVE MISSION OPERATIONS TEST SUITE")
	print("=================================================================\n")
	
	_test_event_definitions()
	_test_solar_storm_decisions()
	_test_dsn_outage_decisions()
	_test_battery_emergency_decisions()
	_test_persistent_consequences_and_audit()
	_test_backward_compatibility()
	
	print("\n=================================================================")
	print(" INTERACTIVE OPERATIONS RESULTS: %d PASSED, %d FAILED" % [_passed_count, _failed_count])
	print("=================================================================\n")
	
	if _failed_count > 0:
		printerr("TEST FAILURES DETECTED!")
		quit(1)
	else:
		print("ALL INTERACTIVE MISSION OPERATIONS TESTS PASSED PERFECTLY!")
		quit(0)

func _assert(condition: bool, test_name: String) -> void:
	if condition:
		_passed_count += 1
		print("  [PASS] %s" % test_name)
	else:
		_failed_count += 1
		printerr("  [FAIL] %s" % test_name)

func _test_event_definitions() -> void:
	print("--- TEST 1: Emergency Event Database Definitions ---")
	var ev3: Dictionary = MissionOperationsData.get_emergency_event(3)
	_assert(not ev3.is_empty() and ev3["id"] == "event_solar_storm", "Window 3 contains Solar Storm emergency event")
	_assert(ev3["choices"].size() == 2, "Solar Storm has exactly 2 strategic choices (Safe Mode vs Continue Science)")
	
	var ev4: Dictionary = MissionOperationsData.get_emergency_event(4)
	_assert(not ev4.is_empty() and ev4["id"] == "event_dsn_outage", "Window 4 contains DSN Outage emergency event")
	_assert(ev4["choices"].size() == 2, "DSN Outage has exactly 2 strategic choices (Store Data vs Backup Comm)")
	
	var ev7: Dictionary = MissionOperationsData.get_emergency_event(7)
	_assert(not ev7.is_empty() and ev7["id"] == "event_battery_emergency", "Window 7 contains Battery Emergency event")
	_assert(ev7["choices"].size() == 2, "Battery Emergency has exactly 2 strategic choices (Shed Load vs Full Ops)")

func _test_solar_storm_decisions() -> void:
	print("\n--- TEST 2: Event A — Solar Storm Trade-Off Dynamics ---")
	
	# Case 1: Safe Mode Choice
	var sim_safe := MissionSimulator.new()
	sim_safe.initialize(SpacecraftState.new())
	sim_safe.advance_window("mode_nominal", "crater_shackleton") # Win 1
	sim_safe.advance_window("mode_nominal", "crater_shackleton") # Win 2
	var rep3_safe: Dictionary = sim_safe.advance_window("mode_nominal", "crater_shackleton", "choice_safe_mode") # Win 3
	
	# Case 2: Continue Science Choice
	var sim_risk := MissionSimulator.new()
	sim_risk.initialize(SpacecraftState.new())
	sim_risk.advance_window("mode_nominal", "crater_shackleton") # Win 1
	sim_risk.advance_window("mode_nominal", "crater_shackleton") # Win 2
	var rep3_risk: Dictionary = sim_risk.advance_window("mode_nominal", "crater_shackleton", "choice_continue_science") # Win 3
	
	# Verify Safe Mode protected equipment and reduced science
	_assert(rep3_safe["equipment_health_pct"] > rep3_risk["equipment_health_pct"], 
		"Safe Mode yields higher equipment health (%0.1f%%) than Continuing Full Science (%0.1f%%)" % [
			rep3_safe["equipment_health_pct"], rep3_risk["equipment_health_pct"]
		])
	_assert(rep3_safe["science_score_gain"] < rep3_risk["science_score_gain"],
		"Safe Mode sacrifices science gain (%0.1f pts) compared to Continuing Full Science (%0.1f pts)" % [
			rep3_safe["science_score_gain"], rep3_risk["science_score_gain"]
		])
	_assert(sim_risk.persistent_sensor_noise == true and sim_safe.persistent_sensor_noise == false,
		"Continuing Science activates persistent sensor SEU degradation flag for future windows")

func _test_dsn_outage_decisions() -> void:
	print("\n--- TEST 3: Event B — DSN Communication Outage Dynamics ---")
	
	# Case 1: Store Data Onboard
	var sim_store := MissionSimulator.new()
	sim_store.initialize(SpacecraftState.new())
	for w in range(1, 4):
		sim_store.advance_window("mode_nominal", "crater_shackleton")
	var rep4_store: Dictionary = sim_store.advance_window("mode_nominal", "crater_shackleton", "choice_store_data")
	
	# Case 2: Backup S-Band Relay
	var sim_backup := MissionSimulator.new()
	sim_backup.initialize(SpacecraftState.new())
	for w in range(1, 4):
		sim_backup.advance_window("mode_nominal", "crater_shackleton")
	var rep4_backup: Dictionary = sim_backup.advance_window("mode_nominal", "crater_shackleton", "choice_backup_comm")
	
	_assert(rep4_store["data_downlinked_gbit"] == 0.0, "Store Data results in 0 Gbit downlinked this window")
	_assert(rep4_backup["data_downlinked_gbit"] > 0.0, 
		"Backup Comm downlinked %0.1f Gbit through commercial relay" % rep4_backup["data_downlinked_gbit"])
	_assert(rep4_store["data_buffer_gbit"] > rep4_backup["data_buffer_gbit"],
		"Store Data fills buffer (%0.1f Gbit) higher than Backup Comm (%0.1f Gbit)" % [
			rep4_store["data_buffer_gbit"], rep4_backup["data_buffer_gbit"]
		])
	_assert(rep4_backup["ops_cost_m"] > rep4_store["ops_cost_m"],
		"Backup Comm incurs commercial pass fee (+$0.5M ops cost)")

func _test_battery_emergency_decisions() -> void:
	print("\n--- TEST 4: Event C — Battery Emergency Load Shedding ---")
	
	# Case 1: Shed Load
	var sim_shed := MissionSimulator.new()
	sim_shed.initialize(SpacecraftState.new())
	for w in range(1, 7):
		sim_shed.advance_window("mode_nominal", "crater_shackleton")
	var rep7_shed: Dictionary = sim_shed.advance_window("mode_nominal", "crater_shackleton", "choice_shed_load")
	
	# Case 2: Continue Full Ops
	var sim_full := MissionSimulator.new()
	sim_full.initialize(SpacecraftState.new())
	for w in range(1, 7):
		sim_full.advance_window("mode_nominal", "crater_shackleton")
	var rep7_full: Dictionary = sim_full.advance_window("mode_nominal", "crater_shackleton", "choice_continue_full_ops")
	
	_assert(rep7_shed["battery_health_pct"] > rep7_full["battery_health_pct"],
		"Shedding load preserves battery state of health (%0.1f%% SOH vs %0.1f%% SOH)" % [
			rep7_shed["battery_health_pct"], rep7_full["battery_health_pct"]
		])
	_assert(rep7_shed["battery_dod_pct"] < rep7_full["battery_dod_pct"],
		"Shedding load reduces eclipse Depth-of-Discharge (%0.1f%% DoD vs %0.1f%% DoD)" % [
			rep7_shed["battery_dod_pct"], rep7_full["battery_dod_pct"]
		])
	_assert(rep7_shed["science_score_gain"] < rep7_full["science_score_gain"],
		"Shedding load sacrifices science output in exchange for bus safety")

func _test_persistent_consequences_and_audit() -> void:
	print("\n--- TEST 5: Subsequent Window Consequences & Debrief Audit ---")
	var sim := MissionSimulator.new()
	sim.initialize(SpacecraftState.new())
	
	# Advance 12 windows making specific emergency choices
	for w in range(1, 13):
		var choice: String = ""
		if w == 3:
			choice = "choice_safe_mode"
		elif w == 4:
			choice = "choice_backup_comm"
		elif w == 7:
			choice = "choice_shed_load"
		sim.advance_window("mode_nominal", "crater_shackleton", choice)
	
	var summary: Dictionary = sim.get_campaign_summary()
	_assert(summary["emergency_decisions"].size() == 3, "All 3 emergency decisions logged in campaign summary")
	
	var eval: Dictionary = ScoringEngine.evaluate_mission(summary, SpacecraftState.new(), sim.window_history)
	var findings: Array = eval.get("engineering_findings", [])
	
	var found_solar_finding: bool = false
	var found_dsn_finding: bool = false
	var found_battery_finding: bool = false
	for f in findings:
		var dec_text: String = f.get("decision", "")
		if "Solar Particle Storm" in dec_text:
			found_solar_finding = true
		if "Commercial S-Band" in dec_text:
			found_dsn_finding = true
		if "Deep Eclipse Emergency" in dec_text:
			found_battery_finding = true
	
	_assert(found_solar_finding, "Audit reflects Solar Particle Storm Safe Mode directive")
	_assert(found_dsn_finding, "Audit reflects Commercial S-Band backup directive")
	_assert(found_battery_finding, "Audit reflects Battery Emergency load shedding directive")

func _test_backward_compatibility() -> void:
	print("\n--- TEST 6: Backward Compatibility (Default Decisions) ---")
	var sim := MissionSimulator.new()
	sim.initialize(SpacecraftState.new())
	
	# Call advance_window with standard 2 arguments only
	for w in range(1, 13):
		sim.advance_window("mode_nominal", "crater_shackleton")
	
	var summary: Dictionary = sim.get_campaign_summary()
	_assert(summary["is_completed"] == true, "Standard 12-window campaign completes without explicit choice arguments")
	_assert(summary["emergency_decisions"].size() == 3, "Default recommendations applied automatically when unguided")
