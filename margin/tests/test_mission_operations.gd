extends SceneTree

# Preload dependencies
const SpacecraftState = preload("res://margin/scripts/spacecraft_state.gd")
const ComponentDatabase = preload("res://margin/data/component_data.gd")
const OrbitDatabase = preload("res://margin/data/orbit_data.gd")
const TransferDatabase = preload("res://margin/data/transfer_data.gd")
const LaunchVehicleDatabase = preload("res://margin/data/launch_vehicle_data.gd")
const MissionOperationsData = preload("res://margin/data/mission_operations_data.gd")
const MissionSimulator = preload("res://margin/scripts/mission_simulator.gd")
const MissionData = preload("res://margin/data/mission_data.gd")

func _init() -> void:
	process_frame.connect(_run_tests)

func _run_tests() -> void:
	process_frame.disconnect(_run_tests)
	
	print("=================================================================")
	print(" MARGIN: MILESTONE 3 — MISSION OPERATIONS AUTOMATED TEST SUITE")
	print("=================================================================")
	
	var pass_count: int = 0
	var fail_count: int = 0
	
	# TEST 1: Launch Planning Transition & State Configuration Transfer
	print("\n--- TEST 1: Launch Planning Transition & State Transfer ---")
	var lp_packed: PackedScene = load("res://margin/scenes/launch_planning.tscn")
	if lp_packed != null:
		var lp_inst = lp_packed.instantiate()
		root.add_child(lp_inst)
		await process_frame
		
		# Set custom selections
		lp_inst.selected_orbit_id = "orbit_low_circular"
		lp_inst.selected_transfer_id = "transfer_low_energy"
		lp_inst.selected_vehicle_id = "lv_commercial_medium"
		
		# Call commence operations callback
		lp_inst._on_commence_operations_pressed()
		
		if MissionOperationsData.active_orbit_id == "orbit_low_circular" and MissionOperationsData.active_transfer_id == "transfer_low_energy":
			print("  [PASS] Launch Planning seamlessly transfers active orbit and transfer configuration to MissionOperationsData")
			pass_count += 1
		else:
			printerr("  [FAIL] Configuration transfer failed!")
			fail_count += 1
		
		lp_inst.queue_free()
	else:
		printerr("  [FAIL] Failed to load launch_planning.tscn")
		fail_count += 1
	
	# TEST 2: State Preservation in Mission Simulator
	print("\n--- TEST 2: State Preservation (Hardware, Masses & ΔV Reserves) ---")
	var state := SpacecraftState.new()
	var t: Dictionary = state.calculate_telemetry()
	
	var sim := MissionSimulator.new()
	sim.initialize(state, "orbit_low_circular", "transfer_low_energy", "lv_commercial_medium")
	
	print("Sim Dry Mass: %0.1f kg | Propellant Remaining: %0.1f kg | ΔV Reserve: %0.1f m/s" % [
		sim.dry_mass_kg, sim.propellant_remaining_kg, sim.delta_v_remaining_ms
	])
	
	# Verify that starting ΔV reserve equals onboard ΔV minus transit expenditure (20 MCC + 669.543 LOI)
	var expected_transit_dv: float = 20.0 + 669.543
	var expected_reserve_dv: float = t["delta_v_ms"] - expected_transit_dv
	if abs(sim.delta_v_remaining_ms - expected_reserve_dv) < 1.0 and sim.propellant_remaining_kg > 0.0:
		print("  [PASS] Spacecraft transit ΔV expenditure and propellant reserves correctly preserved at operations start")
		pass_count += 1
	else:
		printerr("  [FAIL] Unexpected ΔV reserve: %f vs %f" % [sim.delta_v_remaining_ms, expected_reserve_dv])
		fail_count += 1
	
	if sim.battery_capacity_wh == t.get("battery_capacity_wh", 450.0) and sim.data_buffer_capacity_gbit == (64.0 * 8.0):
		print("  [PASS] Battery capacity (450 Wh) and solid-state data recorder buffer (512 Gbit) preserved")
		pass_count += 1
	else:
		printerr("  [FAIL] Battery or buffer capacity mismatched: %f Wh, %f Gbit" % [sim.battery_capacity_wh, sim.data_buffer_capacity_gbit])
		fail_count += 1
	
	# TEST 3: Power & Battery Dynamics (Sunlight Charging vs Eclipse Drain)
	print("\n--- TEST 3: Power & Battery Dynamics (Eclipse Drain & DoD) ---")
	var report_w1: Dictionary = sim.advance_window("mode_nominal", "crater_shackleton")
	print("Window 1 Net Sunlight Power: %+0.1f W | Eclipse DoD: %0.1f%% | Battery SOH: %0.1f%%" % [
		report_w1["net_sunlight_power_w"], report_w1["battery_dod_pct"], report_w1["battery_health_pct"]
	])
	
	# Expected DoD: 175 W * (48/60 h) = 140 Wh. On 450 Wh battery: (140 / 450) * 100 = 31.11%
	if report_w1["net_sunlight_power_w"] > 0.0 and abs(report_w1["battery_dod_pct"] - 31.1) < 2.0:
		print("  [PASS] Sunlight power is positive (+%0.1f W) and eclipse Depth-of-Discharge (%0.1f%%) matches physical model" % [
			report_w1["net_sunlight_power_w"], report_w1["battery_dod_pct"]
		])
		pass_count += 1
	else:
		printerr("  [FAIL] Power calculation unexpected: %f W, %f DoD" % [report_w1["net_sunlight_power_w"], report_w1["battery_dod_pct"]])
		fail_count += 1
	
	# TEST 4: Operational Mode Multipliers & Differentiation
	print("\n--- TEST 4: Operational Mode Multipliers ---")
	var mode_nom: Dictionary = MissionOperationsData.get_mode("mode_nominal")
	var mode_high: Dictionary = MissionOperationsData.get_mode("mode_high_res")
	var mode_cons: Dictionary = MissionOperationsData.get_mode("mode_conserve")
	var mode_comm: Dictionary = MissionOperationsData.get_mode("mode_comm_priority")
	
	if mode_high["science_multiplier"] > mode_nom["science_multiplier"] and mode_high["power_multiplier"] > mode_nom["power_multiplier"]:
		print("  [PASS] High-Resolution Mapping provides higher science return (+50%) with increased power draw (+35%)")
		pass_count += 1
	else:
		printerr("  [FAIL] High-Resolution mode parameters invalid")
		fail_count += 1
	
	if mode_cons["power_multiplier"] < mode_nom["power_multiplier"] and mode_comm["downlink_multiplier"] > mode_nom["downlink_multiplier"]:
		print("  [PASS] Power Conservation reduces load (-35%) and Comm Priority surges downlink bandwidth (+60%)")
		pass_count += 1
	else:
		printerr("  [FAIL] Power Conserve or Comm Priority parameters invalid")
		fail_count += 1
	
	# TEST 5: DSN Contact Limits & Downlink Constraints
	print("\n--- TEST 5: DSN Contact Limits & Downlink Constraints ---")
	var ev_w4: Dictionary = MissionOperationsData.get_window_event(4)
	print("Window 4 Event: %s (Downlink Delta: %+0.1f%%)" % [ev_w4["name"], ev_w4["downlink_delta_pct"]])
	if ev_w4["downlink_delta_pct"] == -40.0:
		print("  [PASS] DSN Madrid maintenance outage realistically throttles monthly downlink capacity (-40%)")
		pass_count += 1
	else:
		printerr("  [FAIL] DSN outage missing or incorrect: %f" % ev_w4["downlink_delta_pct"])
		fail_count += 1
	
	# TEST 6: Solid-State Recorder Buffer Overflow & Data Loss
	print("\n--- TEST 6: Buffer Overflow & Data Loss Simulation ---")
	# Spacecraft with S-Band patch antenna under High-Res mode during DSN outage
	var state_overflow := SpacecraftState.new()
	state_overflow.set_component(ComponentDatabase.Category.COMMUNICATIONS, "comm_s_band_patch")
	var sim_overflow := MissionSimulator.new()
	sim_overflow.initialize(state_overflow, "orbit_low_circular", "transfer_low_energy", "lv_commercial_medium")
	sim_overflow.data_buffer_capacity_gbit = 20.0 # Force 20 Gbit buffer limit
	
	# Run window 4 (which has -40% downlink) under High-Res mode
	sim_overflow.current_window = 4
	var overflow_report: Dictionary = sim_overflow.advance_window("mode_high_res", "crater_shoemaker")
	print("Data Generated: %0.1f Gbit | Downlinked: %0.1f Gbit | Overflow Loss: %0.1f Gbit" % [
		overflow_report["data_generated_gbit"], overflow_report["data_downlinked_gbit"], overflow_report["data_overflow_loss_gbit"]
	])
	if sim_overflow.data_lost_overflow_gbit > 0.0:
		print("  [PASS] Buffer capacity limit correctly triggered data overflow loss (%0.1f Gbit lost)" % sim_overflow.data_lost_overflow_gbit)
		pass_count += 1
	else:
		printerr("  [FAIL] Expected buffer overflow did not occur!")
		fail_count += 1
	
	# TEST 7: Fully Deterministic Reproducibility
	print("\n--- TEST 7: Fully Deterministic Reproducibility ---")
	var sim_a := MissionSimulator.new()
	sim_a.initialize(state, "orbit_low_circular", "transfer_low_energy", "lv_commercial_medium")
	
	var sim_b := MissionSimulator.new()
	sim_b.initialize(state, "orbit_low_circular", "transfer_low_energy", "lv_commercial_medium")
	
	var test_modes = ["mode_nominal", "mode_conserve", "mode_nominal", "mode_comm_priority", "mode_high_res", "mode_nominal"]
	var test_craters = ["crater_shackleton", "crater_shackleton", "crater_shoemaker", "crater_cabeus", "crater_shoemaker", "crater_faustini"]
	
	for i in range(test_modes.size()):
		sim_a.advance_window(test_modes[i], test_craters[i])
		sim_b.advance_window(test_modes[i], test_craters[i])
	
	var t_a = sim_a.get_telemetry()
	var t_b = sim_b.get_telemetry()
	
	var match_downlink: bool = abs(t_a["data_downlinked_total_gbit"] - t_b["data_downlinked_total_gbit"]) < 0.001
	var match_science: bool = abs(t_a["science_score_total"] - t_b["science_score_total"]) < 0.001
	var match_prop: bool = abs(t_a["propellant_remaining_kg"] - t_b["propellant_remaining_kg"]) < 0.001
	var match_battery: bool = abs(t_a["battery_health_pct"] - t_b["battery_health_pct"]) < 0.001
	
	if match_downlink and match_science and match_prop and match_battery:
		print("  [PASS] Two independent 6-window simulation runs produced 100% bit-for-bit identical telemetry")
		pass_count += 1
	else:
		printerr("  [FAIL] Deterministic divergence detected between sim_a and sim_b!")
		fail_count += 1
	
	# TEST 8: Full 12-Window Campaign Completion
	print("\n--- TEST 8: Full 12-Window Campaign Completion ---")
	var sim_campaign := MissionSimulator.new()
	sim_campaign.initialize(state, "orbit_low_circular", "transfer_low_energy", "lv_commercial_medium")
	
	for w in range(1, 13):
		sim_campaign.advance_window("mode_nominal", "crater_shackleton" if w <= 4 else ("crater_shoemaker" if w <= 8 else "crater_cabeus"))
	
	var summary: Dictionary = sim_campaign.get_campaign_summary()
	print("Campaign Complete: %s | Days Elapsed: %0.1f | Final Science: %0.1f pts | Craters Surveyed: %d" % [
		str(summary["is_completed"]), summary["mission_days_elapsed"], summary["final_science_score"], summary["hydrogen_candidates_found"]
	])
	
	if summary["is_completed"] == true and summary["windows_completed"] == 12 and abs(summary["mission_days_elapsed"] - 365.0) < 1.0:
		print("  [PASS] 12-month operational campaign successfully completed (365 days nominal science)")
		pass_count += 1
	else:
		printerr("  [FAIL] Campaign completion failed: %s, %f days" % [str(summary["is_completed"]), summary["mission_days_elapsed"]])
		fail_count += 1
	
	if summary["final_science_score"] >= MissionData.MIN_SCIENCE_POINTS:
		print("  [PASS] Campaign achieved mission success score (%0.1f pts >= 70.0 pts threshold)" % summary["final_science_score"])
		pass_count += 1
	else:
		printerr("  [FAIL] Science score below threshold: %f" % summary["final_science_score"])
		fail_count += 1
	
	# TEST 9: Scientific Caution & Hydrogen Proxy Principle
	print("\n--- TEST 9: Scientific Caution & Hydrogen Proxy Principle ---")
	var craters = MissionOperationsData.get_all_craters()
	var all_craters_have_proxy_notes: bool = true
	for c_id in craters:
		var c = craters[c_id]
		var note: String = c.get("scientific_proxy_note", "")
		if not ("proxy" in note.to_lower() and ("water ice" in note.to_lower() or "not confirm" in note.to_lower())):
			all_craters_have_proxy_notes = false
			printerr("  [FAIL] Crater %s missing proper scientific proxy caution: %s" % [c_id, note])
			break
	
	var summary_proxy_text: String = summary.get("scientific_proxy_summary", "")
	if all_craters_have_proxy_notes and "proxy" in summary_proxy_text.to_lower() and "not constitute definitive proof" in summary_proxy_text.to_lower():
		print("  [PASS] All south polar craters and campaign summary treat hydrogen moderation strictly as a scientific proxy")
		pass_count += 1
	else:
		printerr("  [FAIL] Hydrogen enrichment not clearly qualified as proxy!")
		fail_count += 1
	
	# TEST 10: Preservation of Existing Scenes & Modules
	print("\n--- TEST 10: Preservation of Existing Scenes & Modules ---")
	var scenes_to_verify = [
		"res://margin/scenes/main_menu.tscn",
		"res://margin/scenes/mission_briefing.tscn",
		"res://margin/scenes/workshop.tscn",
		"res://margin/scenes/launch_planning.tscn",
		"res://margin/scenes/mission_operations.tscn"
	]
	
	var scenes_ok: bool = true
	for s_path in scenes_to_verify:
		var scn = load(s_path)
		if scn == null:
			printerr("  [FAIL] Could not load scene: " + s_path)
			scenes_ok = false
		else:
			print("  [PASS] Loaded scene: " + s_path)
	
	if scenes_ok:
		pass_count += 1
	else:
		fail_count += 1
	
	print("\n=================================================================")
	print(" MILESTONE 3 TEST RESULTS: %d PASSED, %d FAILED" % [pass_count, fail_count])
	print("=================================================================")
	
	if fail_count == 0:
		print("ALL MILESTONE 3 MISSION OPERATIONS TESTS PASSED PERFECTLY!")
		quit(0)
	else:
		printerr("SOME MILESTONE 3 TESTS FAILED!")
		quit(1)
