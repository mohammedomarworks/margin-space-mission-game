extends SceneTree

func _init() -> void:
	process_frame.connect(_run_tests)

func _run_tests() -> void:
	process_frame.disconnect(_run_tests)
	
	print("=================================================================")
	print(" MARGIN: MISSION MANEUVER & TRANSFER STRATEGY AUDIT TEST SUITE")
	print("=================================================================")
	
	var pass_count: int = 0
	var fail_count: int = 0
	
	# TEST 1: Internal Consistency of Rocket Equation & Mass Conservation
	print("\n--- TEST 1: Internal Consistency (Tsiolkovsky & Mass Conservation) ---")
	var state := SpacecraftState.new()
	var t := state.calculate_telemetry()
	
	var wet_mass: float = t["wet_mass_kg"]
	var dry_mass: float = t["dry_mass_kg"]
	var prop_mass: float = t["propellant_mass_kg"]
	var dv: float = t["delta_v_ms"]
	
	print("Wet Mass: %0.2f kg | Dry Mass: %0.2f kg | Propellant Mass: %0.2f kg" % [wet_mass, dry_mass, prop_mass])
	if abs((dry_mass + prop_mass) - wet_mass) < 0.01:
		print("  [PASS] Mass conservation: wet_mass == dry_mass + propellant_mass")
		pass_count += 1
	else:
		printerr("  [FAIL] Mass conservation violated: %f != %f + %f" % [wet_mass, dry_mass, prop_mass])
		fail_count += 1
	
	# Verify Tsiolkovsky calculation: ΔV = Isp * 9.80665 * ln(m_wet / m_dry)
	var comp: Dictionary = state.get_component(ComponentDatabase.Category.PROPULSION)
	var isp: float = comp.get("isp_s", 295.0)
	var g0: float = 9.80665
	var expected_dv: float = isp * g0 * log(wet_mass / dry_mass)
	print("Onboard ΔV: %0.1f m/s (Calculated) vs %0.1f m/s (Tsiolkovsky)" % [dv, expected_dv])
	if abs(dv - expected_dv) < 1.0:
		print("  [PASS] Tsiolkovsky Rocket Equation mathematically verified")
		pass_count += 1
	else:
		printerr("  [FAIL] Tsiolkovsky mismatch: %f vs %f" % [dv, expected_dv])
		fail_count += 1
	
	# TEST 2: Transfer Strategy Database Verification
	print("\n--- TEST 2: Transfer Strategy Database Verification (JPL Monograph Consistent Reference Pair) ---")
	var all_transfers = TransferDatabase.get_all_transfers()
	if all_transfers.has("transfer_direct") and all_transfers.has("transfer_low_energy"):
		print("  [PASS] Both Direct Conventional and Low-Energy transfer strategies exist")
		pass_count += 1
	else:
		printerr("  [FAIL] Missing transfer strategies in TransferDatabase")
		fail_count += 1
	
	var trans_direct: Dictionary = TransferDatabase.get_transfer("transfer_direct")
	var trans_low_energy: Dictionary = TransferDatabase.get_transfer("transfer_low_energy")
	
	print("Direct Transfer Duration: %s | Cited JPL LOI: %0.3f m/s | Chemical Required: %s" % [
		trans_direct["duration_desc"], trans_direct["loi_ref_100km_ms"], str(trans_direct.get("requires_chemical_propulsion", false))
	])
	if abs(trans_direct["loi_ref_100km_ms"] - 839.878) < 0.01 and trans_direct["requires_chemical_propulsion"] == true:
		print("  [PASS] Direct transfer correctly cites 839.878 m/s JPL monograph example (4.036d) and enforces chemical propulsion")
		pass_count += 1
	else:
		printerr("  [FAIL] Direct transfer parameters incorrect: %f" % trans_direct["loi_ref_100km_ms"])
		fail_count += 1
	
	print("Low-Energy Transfer Duration: %s | Cited JPL LOI: %0.3f m/s | Chemical Required: %s" % [
		trans_low_energy["duration_desc"], trans_low_energy["loi_ref_100km_ms"], str(trans_low_energy.get("requires_chemical_propulsion", false))
	])
	if abs(trans_low_energy["loi_ref_100km_ms"] - 669.543) < 0.01 and trans_low_energy["requires_chemical_propulsion"] == true:
		print("  [PASS] Low-energy transfer correctly cites 669.543 m/s JPL 83.706-day polar example and requires chemical propulsion (BLT is not electric spiral)")
		pass_count += 1
	else:
		printerr("  [FAIL] Low-energy transfer parameters incorrect: %f" % trans_low_energy["loi_ref_100km_ms"])
		fail_count += 1
	
	# TEST 3: Orbit Database Multi-Strategy Maneuvers
	print("\n--- TEST 3: Orbit Database Multi-Strategy Maneuvers ---")
	var req_low_circ_direct: float = OrbitDatabase.get_required_delta_v("orbit_low_circular", "transfer_direct")
	var req_low_circ_le: float = OrbitDatabase.get_required_delta_v("orbit_low_circular", "transfer_low_energy")
	print("Low Circular Req ΔV: %0.3f m/s (Direct: 20 MCC + 839.878 LOI + 150 SK)" % req_low_circ_direct)
	print("Low Circular Req ΔV: %0.3f m/s (Low-Energy: 20 MCC + 669.543 LOI + 150 SK)" % req_low_circ_le)
	
	if abs(req_low_circ_direct - 1009.878) < 0.01 and abs(req_low_circ_le - 839.543) < 0.01:
		print("  [PASS] Low Circular orbit ΔV correctly scales between Direct (1009.878 m/s) and Low-Energy (839.543 m/s)")
		pass_count += 1
	else:
		printerr("  [FAIL] Unexpected Low Circular ΔV requirements: %f, %f" % [req_low_circ_direct, req_low_circ_le])
		fail_count += 1
	
	var req_frozen_direct: float = OrbitDatabase.get_required_delta_v("orbit_elliptical_frozen", "transfer_direct")
	var req_frozen_le: float = OrbitDatabase.get_required_delta_v("orbit_elliptical_frozen", "transfer_low_energy")
	if abs(req_frozen_direct - 775.0) < 0.01 and abs(req_frozen_le - 635.0) < 0.01:
		print("  [PASS] Quasi-Frozen Elliptical orbit ΔV correctly scales between Direct (775 m/s) and Low-Energy (635 m/s)")
		pass_count += 1
	else:
		printerr("  [FAIL] Unexpected Frozen Elliptical ΔV requirements: %f, %f" % [req_frozen_direct, req_frozen_le])
		fail_count += 1
	
	# TEST 4: Propulsion Dynamics & Thrust Limitations
	print("\n--- TEST 4: Propulsion Dynamics & Thrust Limitations ---")
	# 4A: Cold gas is underpowered for both
	state.set_component(ComponentDatabase.Category.PROPULSION, "prop_cold_gas")
	t = state.calculate_telemetry()
	print("Cold Gas ΔV: %0.1f m/s (Underpowered)" % t["delta_v_ms"])
	if t["delta_v_ms"] < 120.0:
		print("  [PASS] Cold gas thrusters correctly blocked as underpowered")
		pass_count += 1
	else:
		printerr("  [FAIL] Cold gas unexpectedly qualified!")
		fail_count += 1
	
	# 4B: Nominal Dual-Mode Chemical
	state.set_component(ComponentDatabase.Category.PROPULSION, "prop_hydrazine_mono")
	t = state.calculate_telemetry()
	print("Dual-Mode Chemical ΔV: %0.1f m/s" % t["delta_v_ms"])
	if t["delta_v_ms"] >= req_low_circ_le:
		print("  [PASS] Dual-mode chemical qualifies for Low-Energy transfer to Low Circular orbit (+%0.1f m/s reserve)" % [t["delta_v_ms"] - req_low_circ_le])
		pass_count += 1
	else:
		printerr("  [FAIL] Dual-mode chemical failed Low-Energy transfer!")
		fail_count += 1
	
	# 4C: Hall-Effect Thruster thrust limitation
	var hall_comp = ComponentDatabase.get_component("prop_hall_ion")
	print("Hall Thruster: is_low_thrust = %s, thrust = %s mN, power = %s W" % [
		str(hall_comp.get("is_low_thrust", false)),
		str(hall_comp.get("thrust_mn", 0.0)),
		str(hall_comp.get("power_w", 0.0))
	])
	if hall_comp.get("is_low_thrust", false) == true and hall_comp.get("power_w", 0.0) == -165.0:
		print("  [PASS] Hall-effect propulsion correctly flags low thrust (~25 mN) and high power draw (-165 W)")
		pass_count += 1
	else:
		printerr("  [FAIL] Hall-effect thruster missing low thrust or power flags!")
		fail_count += 1
	
	# TEST 5: Launch Planner UI Controller Verification
	print("\n--- TEST 5: Launch Planner UI Controller Verification ---")
	var lp_packed: PackedScene = load("res://margin/scenes/launch_planning.tscn")
	if lp_packed != null:
		var lp_inst = lp_packed.instantiate()
		root.add_child(lp_inst)
		await process_frame
		
		# Test Nominal Chemical with Low-Energy Transfer: should PASS
		state.set_component(ComponentDatabase.Category.PROPULSION, "prop_hydrazine_mono")
		lp_inst.state = state
		lp_inst.selected_transfer_id = "transfer_low_energy"
		lp_inst.selected_orbit_id = "orbit_low_circular"
		lp_inst._run_validation()
		
		var valid: Dictionary = lp_inst._current_validation
		print("Nominal Chemical + Low-Energy All Pass: %s (Expected: true)" % str(valid.get("all_pass", false)))
		if valid.get("all_pass", false) == true:
			print("  [PASS] Nominal chemical spacecraft passes Low-Energy transfer validation")
			pass_count += 1
		else:
			printerr("  [FAIL] Nominal chemical spacecraft failed Low-Energy validation!")
			fail_count += 1
		
		# Test Nominal Chemical with Direct Transfer into Low Circular: should FAIL due to ΔV deficit (946 m/s < 1009.878 m/s)
		lp_inst.selected_transfer_id = "transfer_direct"
		lp_inst._run_validation()
		valid = lp_inst._current_validation
		print("Nominal Chemical + Direct Transfer Low Circular All Pass: %s (Expected: false)" % str(valid.get("all_pass", false)))
		if valid.get("all_pass", false) == false:
			print("  [PASS] Direct transfer correctly enforces higher 1009.9 m/s ΔV threshold for low circular orbit")
			pass_count += 1
		else:
			printerr("  [FAIL] Direct transfer allowed with insufficient ΔV!")
			fail_count += 1
		
		# Test Nominal Chemical with Direct Transfer into Quasi-Frozen Elliptical: should PASS (946 m/s >= 775 m/s)
		lp_inst.selected_orbit_id = "orbit_elliptical_frozen"
		lp_inst._run_validation()
		valid = lp_inst._current_validation
		print("Nominal Chemical + Direct Transfer Frozen Elliptical All Pass: %s (Expected: true)" % str(valid.get("all_pass", false)))
		if valid.get("all_pass", false) == true:
			print("  [PASS] Direct transfer into eccentric orbit succeeds with chemical engine (+%0.1f m/s reserve)" % [lp_inst._current_validation["onboard_dv"] - lp_inst._current_validation["req_dv"]])
			pass_count += 1
		else:
			printerr("  [FAIL] Direct transfer into frozen elliptical unexpectedly failed!")
			fail_count += 1
		
		# Test Hall Thruster with Direct Transfer: should FAIL due to propulsion model limitation
		state.set_component(ComponentDatabase.Category.PROPULSION, "prop_hall_ion")
		lp_inst.selected_transfer_id = "transfer_direct"
		lp_inst._run_validation()
		valid = lp_inst._current_validation
		print("Hall Thruster + Direct Transfer All Pass: %s (Expected: false)" % str(valid.get("all_pass", false)))
		var diag_text: String = lp_inst.diagnostics_label.text
		if valid.get("all_pass", false) == false and "Propulsion Model Limitation" in diag_text and "millinewton-class" in diag_text:
			print("  [PASS] Hall thruster correctly blocked from Direct Transfer due to millinewton thrust limitation")
			pass_count += 1
		else:
			printerr("  [FAIL] Hall thruster was not blocked for thrust limitation!")
			fail_count += 1
		
		# Test Hall Thruster with Low-Energy Transfer: should ALSO FAIL because BLT is not an electric spiral
		lp_inst.selected_transfer_id = "transfer_low_energy"
		lp_inst.selected_orbit_id = "orbit_low_circular"
		lp_inst._run_validation()
		valid = lp_inst._current_validation
		print("Hall Thruster + Low-Energy All Pass: %s (Expected: false)" % str(valid.get("all_pass", false)))
		diag_text = lp_inst.diagnostics_label.text
		if valid.get("all_pass", false) == false and "Propulsion Model Limitation" in diag_text:
			print("  [PASS] Hall thruster correctly blocked from Ballistic Lunar Transfer (BLT is not an electric spiral; requires chemical propulsion)")
			pass_count += 1
		else:
			printerr("  [FAIL] Hall thruster was erroneously permitted on BLT without spiral model!")
			fail_count += 1
		
		# Clean up scene
		lp_inst.queue_free()
	else:
		printerr("  [FAIL] Failed to load launch_planning.tscn!")
		fail_count += 1
	
	print("\n=================================================================")
	print(" AUDIT RESULTS: %d PASSED, %d FAILED" % [pass_count, fail_count])
	print("=================================================================")
	
	if fail_count == 0:
		print("ALL TRANSFER STRATEGY & MANEUVER AUDIT CHECKS PASSED PERFECTLY!")
		quit(0)
	else:
		printerr("SOME AUDIT CHECKS FAILED!")
		quit(1)
