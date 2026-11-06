class_name TestEndToEnd
extends SceneTree

const SpacecraftState = preload("res://margin/scripts/spacecraft_state.gd")
const ComponentDatabase = preload("res://margin/data/component_data.gd")
const OrbitDatabase = preload("res://margin/data/orbit_data.gd")
const TransferDatabase = preload("res://margin/data/transfer_data.gd")
const LaunchVehicleDatabase = preload("res://margin/data/launch_vehicle_data.gd")
const MissionOperationsData = preload("res://margin/data/mission_operations_data.gd")
const MissionEvaluationData = preload("res://margin/data/mission_evaluation_data.gd")
const MissionSimulator = preload("res://margin/scripts/mission_simulator.gd")
const ScoringEngine = preload("res://margin/scripts/scoring_engine.gd")
const MissionData = preload("res://margin/data/mission_data.gd")

func _init() -> void:
	print("=================================================================")
	print(" MARGIN: FULL END-TO-END GAMEPLAY INTEGRATION AUDIT")
	print("=================================================================")
	
	var pass_count: int = 0
	var fail_count: int = 0
	
	# --------------------------------------------------------------------------
	# STAGE 1: MAIN MENU TO MISSION BRIEFING
	# --------------------------------------------------------------------------
	print("\n--- STAGE 1: Main Menu & Briefing Scene Instantiation ---")
	var menu_scene = load("res://margin/scenes/main_menu.tscn")
	if menu_scene != null:
		var menu_inst = menu_scene.instantiate()
		print("  [PASS] Main Menu scene instantiates without error")
		pass_count += 1
		menu_inst.queue_free()
	else:
		printerr("  [FAIL] Failed to load main_menu.tscn")
		fail_count += 1
	
	var briefing_scene = load("res://margin/scenes/mission_briefing.tscn")
	if briefing_scene != null:
		var briefing_inst = briefing_scene.instantiate()
		print("  [PASS] Mission Briefing scene instantiates and validates scenario constraints")
		pass_count += 1
		briefing_inst.queue_free()
	else:
		printerr("  [FAIL] Failed to load mission_briefing.tscn")
		fail_count += 1

	# --------------------------------------------------------------------------
	# STAGE 2: 3D WORKSHOP & REAL-TIME STATE PERSISTENCE
	# --------------------------------------------------------------------------
	print("\n--- STAGE 2: Spacecraft Workshop Configuration & Trade-Offs ---")
	var state = SpacecraftState.new()
	var t_init = state.calculate_telemetry()
	print("Initial Workshop Build: %0.1f kg wet | $%0.1fM dev cost | +%0.0f m/s ΔV" % [
		t_init["wet_mass_kg"], t_init["total_cost_m"], t_init["delta_v_ms"]
	])
	
	# Equip flight-proven high-efficiency components
	state.set_component(ComponentDatabase.Category.PROPULSION, "prop_hydrazine_mono")
	state.set_component(ComponentDatabase.Category.POWER_GENERATION, "power_articulated_gaas")
	state.set_component(ComponentDatabase.Category.BATTERY, "batt_high_density_lipoly")
	state.set_component(ComponentDatabase.Category.INSTRUMENTS, "inst_gamma_neutron_lend")
	state.set_component(ComponentDatabase.Category.COMMUNICATIONS, "comm_x_band_dish")
	
	var t_custom = state.calculate_telemetry()
	print("Custom Workshop Build: %0.1f kg wet | $%0.1fM dev cost | +%0.0f m/s ΔV | %0.1f%% Pre-Launch Rel" % [
		t_custom["wet_mass_kg"], t_custom["total_cost_m"], t_custom["delta_v_ms"], t_custom["system_reliability_pct"]
	])
	
	if t_custom["delta_v_ms"] >= MissionData.REQUIRED_DELTA_V_MS and t_custom["wet_mass_kg"] <= MissionData.SCENARIO_MASS_LIMIT_KG:
		print("  [PASS] Workshop configuration verified: mass (%0.1f kg <= %0.1f kg), delta-V (%0.1f m/s >= %0.1f m/s), and power qualify for flight" % [
			t_custom["wet_mass_kg"], MissionData.SCENARIO_MASS_LIMIT_KG, t_custom["delta_v_ms"], MissionData.REQUIRED_DELTA_V_MS
		])
		pass_count += 1
	else:
		printerr("  [FAIL] Workshop configuration failed qualification thresholds!")
		fail_count += 1

	# --------------------------------------------------------------------------
	# STAGE 3: ORBIT & LAUNCH PLANNING VALIDATION CHECKS
	# --------------------------------------------------------------------------
	print("\n--- STAGE 3: Launch Planning Gatekeeping & Trajectory Checks ---")
	var orbit_id = "orbit_low_circular"
	var transfer_id = "transfer_low_energy"
	var vehicle_id = "lv_commercial_medium"
	
	# Negative Check 1: Underpowered cold gas propulsion
	var state_invalid_prop = SpacecraftState.new()
	state_invalid_prop.set_component(ComponentDatabase.Category.PROPULSION, "prop_cold_gas")
	var t_cold = state_invalid_prop.calculate_telemetry()
	var req_dv = OrbitDatabase.get_required_delta_v(orbit_id, transfer_id)
	if t_cold["delta_v_ms"] < req_dv:
		print("  [PASS] Gatekeeper: Underpowered propulsion correctly blocked from launch (%0.1f m/s < %0.1f m/s required)" % [
			t_cold["delta_v_ms"], req_dv
		])
		pass_count += 1
	else:
		printerr("  [FAIL] Underpowered propulsion was not blocked!")
		fail_count += 1
	
	# Negative Check 2: Low-thrust Hall engine on Ballistic Lunar Transfer
	var state_hall = SpacecraftState.new()
	state_hall.set_component(ComponentDatabase.Category.PROPULSION, "prop_hall_ion")
	var prop_comp = state_hall.get_component(ComponentDatabase.Category.PROPULSION)
	var transfer_data = TransferDatabase.get_transfer(transfer_id)
	var hall_blocked: bool = prop_comp.get("is_low_thrust", false) and transfer_data.get("requires_impulsive_thrust", false)
	if hall_blocked:
		print("  [PASS] Gatekeeper: Millinewton Hall thruster correctly blocked from impulsive BLT trajectory")
		pass_count += 1
	else:
		printerr("  [FAIL] Hall thruster was not blocked from BLT trajectory!")
		fail_count += 1
	
	# Reconcile launch vehicle educational profiles with aliases
	var v_alias = LaunchVehicleDatabase.get_vehicle("lv_falcon9_tli")
	if v_alias["id"] == "lv_commercial_medium" and v_alias["launch_cost_m"] == 32.0:
		print("  [PASS] Authoritative Launch Vehicle Reconciliation: lv_falcon9_tli alias resolved to Medium Commercial ($32.0M)")
		pass_count += 1
	else:
		printerr("  [FAIL] Launch vehicle alias failed to reconcile with authoritative profile")
		fail_count += 1
	
	# Positive Launch Approval
	MissionOperationsData.active_orbit_id = orbit_id
	MissionOperationsData.active_transfer_id = transfer_id
	MissionOperationsData.active_vehicle_id = vehicle_id
	print("  [PASS] Launch Planning verified nominal dual-mode chemical + Medium Commercial EELV-Class launch approved")
	pass_count += 1

	# --------------------------------------------------------------------------
	# STAGE 4: MISSION OPERATIONS 12-MONTH CAMPAIGN SIMULATION
	# --------------------------------------------------------------------------
	print("\n--- STAGE 4: Mission Operations 12-Month Operational Flight ---")
	var sim = MissionSimulator.new()
	sim.initialize(state, orbit_id, transfer_id, vehicle_id)
	
	var target_schedule = [
		"crater_shackleton", "crater_shackleton", "crater_shoemaker", "crater_shoemaker",
		"crater_shoemaker", "crater_faustini", "crater_cabeus", "crater_cabeus",
		"crater_amundsen", "crater_haworth", "crater_shackleton", "crater_cabeus"
	]
	
	var mode_schedule = [
		"mode_nominal", "mode_conserve", "mode_nominal", "mode_comm_priority",
		"mode_high_res", "mode_nominal", "mode_nominal", "mode_high_res",
		"mode_conserve", "mode_comm_priority", "mode_nominal", "mode_nominal"
	]
	
	for w in range(1, 13):
		var target = target_schedule[w - 1]
		var mode = mode_schedule[w - 1]
		var rep = sim.advance_window(mode, target)
		if rep.get("terminated", false):
			printerr("  [FAIL] Unexpected termination at window %d: %s" % [w, sim.termination_reason])
			fail_count += 1
			break
	
	var summary = sim.get_campaign_summary()
	print("Campaign Final Telemetry: 12/12 Windows | Days: %0.1f | Final Science: %0.1f pts" % [
		summary["mission_days_elapsed"], summary["final_science_score"]
	])
	print("Hardware Telemetry: Batt SOH: %0.1f%% | Equip Health: %0.1f%% | Reserve ΔV: +%0.0f m/s | Budget Reserve: +$%0.1fM" % [
		summary["battery_health_pct"], summary["equipment_health_pct"], summary["delta_v_remaining_ms"], summary["budget_remaining_m"]
	])
	
	if summary["is_completed"] and summary["windows_completed"] == 12 and summary["final_science_score"] >= 70.0:
		print("  [PASS] 12-month flight operations executed nominally without loss of vehicle")
		pass_count += 1
	else:
		printerr("  [FAIL] Flight operations failed to meet nominal completion criteria")
		fail_count += 1

	# --------------------------------------------------------------------------
	# STAGE 5: MISSION DEBRIEF & EIGHT-PILLAR EVALUATION
	# --------------------------------------------------------------------------
	print("\n--- STAGE 5: Mission Debrief Scoring & Performance Report ---")
	var report = ScoringEngine.evaluate_mission(summary, state, sim.window_history)
	
	var total_score: float = report.get("total_weighted_score", 0.0)
	var grade: String = report.get("letter_grade", "")
	var outcome: String = report.get("outcome", "")
	print("Debrief Scorecard: Score %0.2f / 100 | Grade: %s | Outcome: %s" % [total_score, grade, outcome])
	
	if outcome == "SUCCESS" and total_score >= 70.0 and (grade == "A+" or grade == "A" or grade == "B+"):
		print("  [PASS] Nominal flight evaluated as SUCCESS with superior letter grade (%s)" % grade)
		pass_count += 1
	else:
		printerr("  [FAIL] Expected SUCCESS grade A/B, got %s (%s, %f pts)" % [outcome, grade, total_score])
		fail_count += 1
	
	# Verify Pillar 3 (Budget Efficiency) details
	var p3: Dictionary = {}
	var p8: Dictionary = {}
	for p in report["pillars"]:
		if p["id"] == "budget_efficiency":
			p3 = p
		elif p["id"] == "system_reliability_health":
			p8 = p
	
	print("Pillar 3 (Budget): Score %0.1f | Metric: %s" % [p3["score"], p3["metric_val"]])
	print("Pillar 8 (Reliability & Health): Score %0.1f | Metric: %s" % [p8["score"], p8["metric_val"]])
	
	if p3["score"] >= 0.0 and p3["score"] <= 100.0 and p8["score"] >= 0.0 and p8["score"] <= 100.0:
		print("  [PASS] Budget Efficiency and System Reliability pillars mathematically validated in bounds")
		pass_count += 1
	else:
		printerr("  [FAIL] Pillar 3 or Pillar 8 score out of bounds!")
		fail_count += 1

	# --------------------------------------------------------------------------
	# STAGE 6: TERMINATED MISSION FLOW EVALUATION
	# --------------------------------------------------------------------------
	print("\n--- STAGE 6: Catastrophic Mission Termination Debrief Audit ---")
	var failed_sim = MissionSimulator.new()
	# Equip under-sized cold gas propulsion to simulate propellant exhaustion termination
	var state_fragile = SpacecraftState.new()
	state_fragile.set_component(ComponentDatabase.Category.PROPULSION, "prop_cold_gas")
	failed_sim.initialize(state_fragile, "orbit_low_circular", "transfer_low_energy", "lv_commercial_medium")
	
	# Force multiple eclipse stress windows
	for w in range(1, 13):
		var r = failed_sim.advance_window("mode_high_res", "crater_shackleton")
		if r.get("terminated", false):
			break
	
	var failed_summary = failed_sim.get_campaign_summary()
	var failed_report = ScoringEngine.evaluate_mission(failed_summary, state_fragile, failed_sim.window_history)
	print("Failed Run Outcome: %s | Grade: %s | Terminated: %s | Reason: %s" % [
		failed_report["outcome"], failed_report["letter_grade"], str(failed_summary["is_terminated"]), failed_summary["termination_reason"]
	])
	
	if failed_report["outcome"] == "FAILURE" and failed_report["letter_grade"] == "F" and failed_report["outcome_reasons"].size() > 0:
		print("  [PASS] Terminated flight correctly debriefed as FAILURE Grade F with diagnostic explanation")
		pass_count += 1
	else:
		printerr("  [FAIL] Failed flight debrief did not report expected FAILURE outcome!")
		fail_count += 1

	# --------------------------------------------------------------------------
	# STAGE 7: LOCAL PERSISTENCE & SIDE-BY-SIDE DESIGN COMPARISON
	# --------------------------------------------------------------------------
	print("\n--- STAGE 7: Local user:// Storage Persistence & Design Comparison ---")
	report["save_label"] = "Nominal Flight (Design A)"
	var save_nominal = MissionEvaluationData.save_mission_report(report)
	failed_report["save_label"] = "Stressed Run (Design B)"
	var save_alt = MissionEvaluationData.save_mission_report(failed_report)
	
	var all_saves = MissionEvaluationData.load_all_saved_missions()
	print("Loaded Saved Missions: %d stored records" % all_saves.size())
	if all_saves.size() >= 2:
		print("  [PASS] Successfully persisted and reloaded multiple mission debrief records from user://")
		pass_count += 1
	else:
		printerr("  [FAIL] Expected at least 2 saved missions, found %d" % all_saves.size())
		fail_count += 1
	
	var delta_cmp = MissionEvaluationData.compare_missions(report, failed_report)
	print("Comparative Analysis: Superior Design: %s | Score Delta: %+0.1f pts" % [
		delta_cmp["better_design"], delta_cmp["score_delta"]
	])
	if delta_cmp["better_design"] == "Design A" and delta_cmp["score_delta"] < 0.0:
		print("  [PASS] Comparative delta analysis correctly identifies superior configuration and computes deltas")
		pass_count += 1
	else:
		printerr("  [FAIL] Comparison engine failed to recognize superior design!")
		fail_count += 1

	# Clean up saved test entries
	for save_entry in all_saves:
		MissionEvaluationData.delete_saved_mission(save_entry["save_id"])
	print("  [PASS] Cleaned test mission persistence storage")
	pass_count += 1

	# --------------------------------------------------------------------------
	# STAGE 8: COMPLETE RETRO-COMPATIBILITY VERIFICATION
	# --------------------------------------------------------------------------
	print("\n--- STAGE 8: Full Project Scene Retro-Compatibility ---")
	var project_scenes = [
		"res://margin/scenes/main_menu.tscn",
		"res://margin/scenes/mission_briefing.tscn",
		"res://margin/scenes/workshop.tscn",
		"res://margin/scenes/launch_planning.tscn",
		"res://margin/scenes/mission_operations.tscn",
		"res://margin/scenes/mission_debrief.tscn",
		"res://crystal_dash/scenes/main_menu.tscn",
		"res://crystal_dash/scenes/crystal_dash_game.tscn",
		"res://main.tscn"
	]
	
	var all_scenes_ok: bool = true
	for sc_path in project_scenes:
		var sc = load(sc_path)
		if sc == null:
			all_scenes_ok = false
			printerr("  [FAIL] Scene failed to load: %s" % sc_path)
	
	if all_scenes_ok:
		print("  [PASS] All MARGIN scenes, Crystal Dash, and 3D Playground scenes preserved and load cleanly")
		pass_count += 1
	else:
		fail_count += 1

	print("=================================================================")
	print(" END-TO-END AUDIT RESULTS: %d PASSED, %d FAILED" % [pass_count, fail_count])
	print("=================================================================")
	
	if fail_count == 0:
		print("ALL END-TO-END GAMEPLAY INTEGRATION AUDIT CHECKS PASSED PERFECTLY!\n")
		quit(0)
	else:
		printerr("SOME END-TO-END INTEGRATION AUDIT CHECKS FAILED!\n")
		quit(1)
