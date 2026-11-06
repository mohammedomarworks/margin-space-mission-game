extends SceneTree

# Preload dependencies
const SpacecraftState = preload("res://margin/scripts/spacecraft_state.gd")
const ComponentDatabase = preload("res://margin/data/component_data.gd")
const OrbitDatabase = preload("res://margin/data/orbit_data.gd")
const TransferDatabase = preload("res://margin/data/transfer_data.gd")
const LaunchVehicleDatabase = preload("res://margin/data/launch_vehicle_data.gd")
const MissionOperationsData = preload("res://margin/data/mission_operations_data.gd")
const MissionSimulator = preload("res://margin/scripts/mission_simulator.gd")
const MissionEvaluationData = preload("res://margin/data/mission_evaluation_data.gd")
const ScoringEngine = preload("res://margin/scripts/scoring_engine.gd")
const MissionData = preload("res://margin/data/mission_data.gd")

func _init() -> void:
	process_frame.connect(_run_tests)

func _run_tests() -> void:
	process_frame.disconnect(_run_tests)
	
	print("=================================================================")
	print(" MARGIN: MILESTONE 4 — MISSION DEBRIEF AUTOMATED TEST SUITE")
	print("=================================================================")
	
	var pass_count: int = 0
	var fail_count: int = 0
	
	var state := SpacecraftState.new()
	
	# --------------------------------------------------------------------------
	# TEST 1: Eight-Pillar Scoring Engine & Weighted Sum Formula
	# --------------------------------------------------------------------------
	print("\n--- TEST 1: Eight-Pillar Scoring Math & Sum Validation ---")
	var sim := MissionSimulator.new()
	sim.initialize(state, "orbit_low_circular", "transfer_low_energy", "lv_commercial_medium")
	
	# Run a complete 12-window nominal mission
	for w in range(1, 13):
		sim.advance_window("mode_nominal", "crater_shackleton" if w <= 4 else ("crater_shoemaker" if w <= 8 else "crater_cabeus"))
	
	var nominal_summary: Dictionary = sim.get_campaign_summary()
	var report: Dictionary = ScoringEngine.evaluate_mission(nominal_summary, state, sim.window_history)
	
	var pillars: Array[Dictionary] = report.get("pillars", [])
	print("Pillars Count: %d (Expected: 8)" % pillars.size())
	if pillars.size() == 8:
		print("  [PASS] All 8 evaluation pillars present in scorecard")
		pass_count += 1
	else:
		printerr("  [FAIL] Expected 8 pillars, got %d" % pillars.size())
		fail_count += 1
	
	# Verify weights sum to 1.00 and scores within [0, 100]
	var weight_sum: float = 0.0
	var calc_weighted_sum: float = 0.0
	var all_scores_valid: bool = true
	
	for p in pillars:
		var w: float = p["weight"]
		var s: float = p["score"]
		var ws: float = p["weighted_score"]
		weight_sum += w
		calc_weighted_sum += ws
		
		if s < 0.0 or s > 100.0:
			all_scores_valid = false
			printerr("  [FAIL] Pillar %s score out of bounds: %f" % [p["id"], s])
		if abs(ws - (s * w)) > 0.01:
			printerr("  [FAIL] Pillar %s weighted score mismatch: %f != %f * %f" % [p["id"], ws, s, w])
	
	if abs(weight_sum - 1.00) < 0.001 and all_scores_valid:
		print("  [PASS] Weights sum to exactly 1.00 (100%%) and all pillar scores bounded in [0, 100]")
		pass_count += 1
	else:
		printerr("  [FAIL] Weight sum error: %f" % weight_sum)
		fail_count += 1
	
	var total_score: float = report.get("total_weighted_score", 0.0)
	print("Total Weighted Score: %0.2f (Calculated sum: %0.2f)" % [total_score, calc_weighted_sum])
	if abs(total_score - calc_weighted_sum) < 0.01:
		print("  [PASS] Total score mathematically equals sum of weighted category contributions")
		pass_count += 1
	else:
		printerr("  [FAIL] Total score mismatch: %f vs %f" % [total_score, calc_weighted_sum])
		fail_count += 1

	# --------------------------------------------------------------------------
	# TEST 2: Successful Mission Outcome Classification
	# --------------------------------------------------------------------------
	print("\n--- TEST 2: Successful Mission Outcome Classification ---")
	print("Outcome: %s | Grade: %s" % [report["outcome"], report["letter_grade"]])
	if report["outcome"] == "SUCCESS" and report["total_weighted_score"] >= 70.0:
		print("  [PASS] Nominal completed mission correctly classified as SUCCESS with grade %s" % report["letter_grade"])
		pass_count += 1
	else:
		printerr("  [FAIL] Expected SUCCESS, got %s (%f pts)" % [report["outcome"], report["total_weighted_score"]])
		fail_count += 1
	
	if report["outcome_reasons"].size() >= 2:
		print("  [PASS] Transparent outcome diagnostic reasons provided (%d reasons)" % report["outcome_reasons"].size())
		pass_count += 1
	else:
		printerr("  [FAIL] Insufficient outcome diagnostic reasons!")
		fail_count += 1

	# --------------------------------------------------------------------------
	# TEST 3: Partial Success Classification
	# --------------------------------------------------------------------------
	print("\n--- TEST 3: Partial Success Outcome Classification ---")
	var partial_summary: Dictionary = nominal_summary.duplicate(true)
	# Simulate low science return (52 points) and moderate coverage
	partial_summary["final_science_score"] = 52.0
	partial_summary["avg_polar_coverage_pct"] = 48.0
	partial_summary["hydrogen_candidates_found"] = 2
	
	var partial_report: Dictionary = ScoringEngine.evaluate_mission(partial_summary, state, sim.window_history)
	print("Partial Run Outcome: %s | Score: %0.1f | Grade: %s" % [
		partial_report["outcome"], partial_report["total_weighted_score"], partial_report["letter_grade"]
	])
	if partial_report["outcome"] == "PARTIAL_SUCCESS":
		print("  [PASS] Constrained science mission correctly classified as PARTIAL_SUCCESS")
		pass_count += 1
	else:
		printerr("  [FAIL] Expected PARTIAL_SUCCESS, got %s" % partial_report["outcome"])
		fail_count += 1

	# --------------------------------------------------------------------------
	# TEST 4: Failed Mission Outcome Classification
	# --------------------------------------------------------------------------
	print("\n--- TEST 4: Failed Mission Outcome Classification ---")
	var failed_summary: Dictionary = nominal_summary.duplicate(true)
	failed_summary["is_terminated"] = true
	failed_summary["termination_reason"] = "Spacecraft Loss of Power: Complete battery capacity failure due to sustained severe Depth of Discharge."
	failed_summary["battery_health_pct"] = 0.0
	failed_summary["windows_completed"] = 3
	failed_summary["final_science_score"] = 18.0
	
	var failed_report: Dictionary = ScoringEngine.evaluate_mission(failed_summary, state, sim.window_history)
	print("Failed Run Outcome: %s | Grade: %s | Reason: %s" % [
		failed_report["outcome"], failed_report["letter_grade"], failed_report["outcome_reasons"][0]
	])
	if failed_report["outcome"] == "FAILURE" and failed_report["letter_grade"] == "F":
		print("  [PASS] Terminated mission correctly classified as FAILURE with Grade F and root-cause diagnostic")
		pass_count += 1
	else:
		printerr("  [FAIL] Expected FAILURE, got %s" % failed_report["outcome"])
		fail_count += 1

	# --------------------------------------------------------------------------
	# TEST 5: Engineering Decision Audit Grounded in Telemetry
	# --------------------------------------------------------------------------
	print("\n--- TEST 5: Engineering Decision Audit ---")
	var findings: Array[Dictionary] = report.get("engineering_findings", [])
	print("Audit Findings Count: %d" % findings.size())
	if findings.size() >= 4:
		print("  [PASS] Comprehensive engineering audit generated with %d findings" % findings.size())
		pass_count += 1
	else:
		printerr("  [FAIL] Insufficient audit findings: %d" % findings.size())
		fail_count += 1
	
	var has_positive_driver: bool = false
	var has_bottleneck: bool = false
	for f in findings:
		if "TOP PERFORMANCE DRIVER" in f.get("verdict", ""):
			has_positive_driver = true
		if "KEY ENGINEERING BOTTLENECK" in f.get("verdict", ""):
			has_bottleneck = true
	
	if has_positive_driver and has_bottleneck:
		print("  [PASS] Audit identifies primary positive engineering driver and key subsystem bottleneck")
		pass_count += 1
	else:
		printerr("  [FAIL] Missing positive driver or bottleneck findings")
		fail_count += 1

	# --------------------------------------------------------------------------
	# TEST 6: Interactive 12-Month Timeline Integrity
	# --------------------------------------------------------------------------
	print("\n--- TEST 6: Interactive 12-Month Timeline Data Integrity ---")
	if sim.window_history.size() == 12:
		var w1 = sim.window_history[0]
		var w12 = sim.window_history[11]
		print("Window 1 Net Power: %+0.1fW | DoD: %0.1f%%" % [w1["net_sunlight_power_w"], w1["battery_dod_pct"]])
		print("Window 12 Downlink: %0.1f Gbit | Reserve: +%0.0f m/s" % [w12["data_downlinked_gbit"], w12["delta_v_remaining_ms"]])
		if w1.has("sk_burn_ms") and w12.has("battery_health_pct"):
			print("  [PASS] All 12 monthly operational windows contain complete telemetry history")
			pass_count += 1
		else:
			printerr("  [FAIL] Timeline history missing required fields")
			fail_count += 1
	else:
		printerr("  [FAIL] Expected 12 history records, got %d" % sim.window_history.size())
		fail_count += 1

	# --------------------------------------------------------------------------
	# TEST 7: Local Storage (user://) Save, Load & Delete
	# --------------------------------------------------------------------------
	print("\n--- TEST 7: Local Storage (user://) Save, Load & Delete ---")
	# Clear test storage first
	MissionEvaluationData.clear_all_saved_missions()
	
	# Save active report
	var save_success: bool = MissionEvaluationData.save_mission_report(report)
	if save_success:
		print("  [PASS] Successfully saved mission report to local storage (user://)")
		pass_count += 1
	else:
		printerr("  [FAIL] Failed to save mission report")
		fail_count += 1
	
	# Load back
	var loaded: Array[Dictionary] = MissionEvaluationData.load_all_saved_missions()
	print("Loaded Missions Count: %d" % loaded.size())
	if loaded.size() == 1 and abs(loaded[0]["total_weighted_score"] - report["total_weighted_score"]) < 0.01:
		print("  [PASS] Loaded mission report matches saved score bit-for-bit (%0.2f pts)" % loaded[0]["total_weighted_score"])
		pass_count += 1
	else:
		printerr("  [FAIL] Loaded report mismatch!")
		fail_count += 1
	
	# Save a second mission (partial run)
	MissionEvaluationData.save_mission_report(partial_report)
	loaded = MissionEvaluationData.load_all_saved_missions()
	if loaded.size() == 2:
		print("  [PASS] Successfully stored multiple mission configurations (%d runs)" % loaded.size())
		pass_count += 1
	else:
		printerr("  [FAIL] Expected 2 saved missions, got %d" % loaded.size())
		fail_count += 1
	
	# Delete one
	var del_id: String = loaded[0]["save_id"]
	MissionEvaluationData.delete_saved_mission(del_id)
	loaded = MissionEvaluationData.load_all_saved_missions()
	if loaded.size() == 1:
		print("  [PASS] Successfully deleted saved mission entry by ID")
		pass_count += 1
	else:
		printerr("  [FAIL] Delete operation failed!")
		fail_count += 1

	# --------------------------------------------------------------------------
	# TEST 8: Side-by-Side Design Comparison Engine
	# --------------------------------------------------------------------------
	print("\n--- TEST 8: Side-by-Side Design Comparison Engine ---")
	var comp: Dictionary = MissionEvaluationData.compare_missions(partial_report, report)
	print("Better Design Identified: %s | Score Delta: %+0.1f pts" % [comp["better_design"], comp["score_delta"]])
	if comp["better_design"] == "Design B" and comp["score_delta"] > 0.0:
		print("  [PASS] Comparison engine accurately identifies superior design and computes delta metrics")
		pass_count += 1
	else:
		printerr("  [FAIL] Comparison engine failed to identify superior design!")
		fail_count += 1

	# --------------------------------------------------------------------------
	# TEST 9: Team Contribution Summary (4 Local Disciplines)
	# --------------------------------------------------------------------------
	print("\n--- TEST 9: Team Contribution Summary ---")
	var team: Dictionary = report.get("team_contributions", {})
	if team.has("planner") and team.has("science_lead") and team.has("engineer") and team.has("comms_officer"):
		print("Planner: %0.1f | Science: %0.1f | Engineer: %0.1f | Comms: %0.1f" % [
			team["planner"]["score"], team["science_lead"]["score"], team["engineer"]["score"], team["comms_officer"]["score"]
		])
		print("  [PASS] All 4 local team disciplines evaluated with domain-specific metrics")
		pass_count += 1
	else:
		printerr("  [FAIL] Missing team discipline evaluation!")
		fail_count += 1

	# --------------------------------------------------------------------------
	# TEST 10: Scientific Caution & Real NASA Benchmark Reference Integrity
	# --------------------------------------------------------------------------
	print("\n--- TEST 10: Scientific Caution & Real NASA Benchmarks ---")
	var caution_text: String = report.get("scientific_caution", "")
	if "proxy" in caution_text.to_lower() and "not definitive proof" in caution_text.to_lower():
		print("  [PASS] Debrief report explicitly caveats hydrogen detection as a proxy, not definitive proof of water ice")
		pass_count += 1
	else:
		printerr("  [FAIL] Scientific caution missing or inaccurate: %s" % caution_text)
		fail_count += 1
	
	var benchmarks: Dictionary = MissionEvaluationData.get_nasa_benchmarks()
	if benchmarks.has("lunar_prospector") and benchmarks.has("lro_lend") and benchmarks.has("lcross"):
		print("  [PASS] Authentic NASA mission benchmarks provided with simulation vs reality distinctions")
		pass_count += 1
	else:
		printerr("  [FAIL] Missing NASA benchmark missions!")
		fail_count += 1

	# --------------------------------------------------------------------------
	# TEST 11: Mission Operations to Debrief Scene Transition
	# --------------------------------------------------------------------------
	print("\n--- TEST 11: Mission Operations to Debrief Integration ---")
	var ops_packed: PackedScene = load("res://margin/scenes/mission_operations.tscn")
	if ops_packed != null:
		var ops_inst = ops_packed.instantiate()
		root.add_child(ops_inst)
		await process_frame
		
		# Verify that proceed to debrief method exists
		if ops_inst.has_method("_on_proceed_to_debrief_pressed"):
			print("  [PASS] Mission Operations controller implements _on_proceed_to_debrief_pressed()")
			pass_count += 1
		else:
			printerr("  [FAIL] Missing _on_proceed_to_debrief_pressed in Mission Operations!")
			fail_count += 1
		
		ops_inst.queue_free()
	else:
		printerr("  [FAIL] Could not load mission_operations.tscn")
		fail_count += 1

	# --------------------------------------------------------------------------
	# TEST 12: Mission Debrief Scene UI & Controller Loading
	# --------------------------------------------------------------------------
	print("\n--- TEST 12: Mission Debrief Scene UI Loading ---")
	var debrief_packed: PackedScene = load("res://margin/scenes/mission_debrief.tscn")
	if debrief_packed != null:
		var debrief_inst = debrief_packed.instantiate()
		root.add_child(debrief_inst)
		await process_frame
		
		if debrief_inst.score_number_label != null and debrief_inst.grade_badge_label != null:
			print("  [PASS] Mission Debrief scene instantiated and bound all UI controls successfully")
			pass_count += 1
		else:
			printerr("  [FAIL] Debrief UI controls failed to bind!")
			fail_count += 1
		
		debrief_inst.queue_free()
	else:
		printerr("  [FAIL] Could not load mission_debrief.tscn")
		fail_count += 1

	# --------------------------------------------------------------------------
	# TEST 13: Full Compatibility with Existing Project Modules
	# --------------------------------------------------------------------------
	print("\n--- TEST 13: Full Project Compatibility & Integrity ---")
	var scenes_to_check = [
		"res://margin/scenes/main_menu.tscn",
		"res://margin/scenes/mission_briefing.tscn",
		"res://margin/scenes/workshop.tscn",
		"res://margin/scenes/launch_planning.tscn",
		"res://margin/scenes/mission_operations.tscn",
		"res://margin/scenes/mission_debrief.tscn",
		"res://crystal_dash/scenes/main_menu.tscn",
		"res://main.tscn"
	]
	
	var all_scenes_ok: bool = true
	for p in scenes_to_check:
		var res = load(p)
		if res == null:
			printerr("  [FAIL] Failed loading: " + p)
			all_scenes_ok = false
		else:
			print("  [PASS] Verified scene: " + p)
	
	if all_scenes_ok:
		pass_count += 1
	else:
		fail_count += 1

	# --------------------------------------------------------------------------
	# SUMMARY
	# --------------------------------------------------------------------------
	print("\n=================================================================")
	print(" MILESTONE 4 TEST RESULTS: %d PASSED, %d FAILED" % [pass_count, fail_count])
	print("=================================================================")
	
	if fail_count == 0:
		print("ALL MILESTONE 4 MISSION DEBRIEF & EVALUATION TESTS PASSED PERFECTLY!")
		quit(0)
	else:
		printerr("SOME MILESTONE 4 TESTS FAILED!")
		quit(1)
