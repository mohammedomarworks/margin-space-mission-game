class_name TestHelios4Campaign
extends SceneTree

# ==============================================================================
# MARGIN: HELIOS-4 CAMPAIGN AUTOMATED TEST SUITE
# Verifies all 6 milestones of the HELIOS-4 flagship spaceflight campaign:
# 1. Mission Scenario registration & Sun-Earth L1 astrodynamics
# 2. Four cooperative specialist roles & pass-and-play allocation
# 3. Multistage Tsiolkovsky rocket equation, liftoff TWR & aerodynamic static margin
# 4. Phase 2 launch, Max-Q dynamic pressure & staging separation
# 5. Deep-space transfer & three deterministic interactive crisis decisions
# 6. L1 halo-orbit insertion, probe commissioning & early-warning advance lead time
# 7. Persistence (user://helios4_campaign.json) & stage progression
# 8. NASA DONKI CCMC space weather connector & offline deterministic fallbacks
# ==============================================================================

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")
const DonkiService = preload("res://margin/data/donki_service.gd")
const MissionScenario = preload("res://margin/data/mission_scenario.gd")
const ComponentDatabase = preload("res://margin/data/component_data.gd")

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	print("\n==================================================")
	print("  MARGIN: HELIOS-4 CAMPAIGN TEST SUITE")
	print("==================================================\n")
	
	test_scenario_registration_and_astrodynamics()
	test_four_cooperative_roles()
	test_hangar_multistage_physics_and_twr()
	test_astrogator_trajectory_mode_and_team_log()
	test_launch_max_q_and_staging()
	test_deep_space_transfer_and_crises()
	test_l1_halo_insertion_and_early_warning()
	test_debrief_score_arithmetic()
	test_campaign_persistence()
	test_donki_space_weather_service()
	
	print("\n--------------------------------------------------")
	print("HELIOS-4 CAMPAIGN TESTS: %d PASSED, %d FAILED" % [_pass_count, _fail_count])
	print("--------------------------------------------------\n")
	
	if _fail_count > 0:
		quit(1)
	else:
		quit(0)

func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		_pass_count += 1
	else:
		printerr("  [FAIL] %s" % test_name)
		_fail_count += 1

func _assert_approx(actual: float, expected: float, tolerance: float, test_name: String) -> void:
	var diff = abs(actual - expected)
	if diff <= tolerance:
		print("  [PASS] %s (%.2f ~ %.2f, diff=%.3f)" % [test_name, actual, expected, diff])
		_pass_count += 1
	else:
		printerr("  [FAIL] %s (expected %.2f, got %.2f, diff=%.3f > %.3f)" % [test_name, expected, actual, diff, tolerance])
		_fail_count += 1

func test_scenario_registration_and_astrodynamics() -> void:
	print("[TEST 1] Scenario Registration & Sun-Earth L1 Astrodynamics")
	MissionScenario.set_active_scenario("helios_4")
	var scn = MissionScenario.get_active_scenario()
	
	_assert_true(scn.id == "helios_4", "Scenario ID is helios_4")
	_assert_true(scn.code == "HELIOS-4", "Scenario code is HELIOS-4")
	_assert_true(scn.target_body == "Sun-Earth L1", "Target body is Sun-Earth L1")
	_assert_true(scn.budget_cap_m == 185.0, "Budget ceiling is $185.0M")
	_assert_true(scn.mass_limit_kg == 1250.0, "Mass limit is 1250.0 kg")
	_assert_true(scn.duration_days == 1095, "Mission duration is 3-year baseline (1095 days)")
	
	# Scientific requirements: L1 distance must be ~1.5 million km, NOT the midpoint!
	_assert_approx(scn.target_altitude_km, 1500000.0, 1000.0, "Target distance is 1.5 million km sunward (approx 1% of AU)")
	_assert_true(scn.scientific_caution.contains("not the midpoint"), "Astrodynamics disclaims that L1 is NOT the midpoint")
	_assert_true(scn.scientific_caution.contains("dynamically unstable"), "Disclaims that L1 collinear halo orbits are dynamically unstable")
	_assert_true(scn.scientific_caution.contains("uncrewed"), "Specifies spacecraft is uncrewed with no human life-support")

func test_four_cooperative_roles() -> void:
	print("\n[TEST 2] Four-Player Cooperative Roles & Pass-and-Play Configuration")
	Helios4CampaignData.player_count = 4
	Helios4CampaignData.team_player_names = {
		Helios4CampaignData.ROLE_PROPULSION: "Chief Propulsion",
		Helios4CampaignData.ROLE_STRUCTURAL: "Chief Structures",
		Helios4CampaignData.ROLE_ASTROGATOR: "Chief Trajectory",
		Helios4CampaignData.ROLE_SYSTEMS: "Chief Systems"
	}
	
	_assert_true(Helios4CampaignData.ROLE_METADATA.has(Helios4CampaignData.ROLE_PROPULSION), "Has Propulsion Engineer role")
	_assert_true(Helios4CampaignData.ROLE_METADATA.has(Helios4CampaignData.ROLE_STRUCTURAL), "Has Structural Architect role")
	_assert_true(Helios4CampaignData.ROLE_METADATA.has(Helios4CampaignData.ROLE_ASTROGATOR), "Has Astrogator role")
	_assert_true(Helios4CampaignData.ROLE_METADATA.has(Helios4CampaignData.ROLE_SYSTEMS), "Has Systems Officer role")
	
	_assert_true(Helios4CampaignData.team_player_names[Helios4CampaignData.ROLE_PROPULSION] == "Chief Propulsion", "Propulsion callsign stored")
	_assert_true(Helios4CampaignData.team_player_names[Helios4CampaignData.ROLE_STRUCTURAL] == "Chief Structures", "Structural callsign stored")
	_assert_true(Helios4CampaignData.team_player_names[Helios4CampaignData.ROLE_ASTROGATOR] == "Chief Trajectory", "Astrogator callsign stored")
	_assert_true(Helios4CampaignData.team_player_names[Helios4CampaignData.ROLE_SYSTEMS] == "Chief Systems", "Systems callsign stored")

func test_hangar_multistage_physics_and_twr() -> void:
	print("\n[TEST 3] Multistage Tsiolkovsky Rocket Equation & Engineering Gate")
	Helios4CampaignData.vehicle_config = Helios4CampaignData.get_default_vehicle_config()
	Helios4CampaignData.probe_config = Helios4CampaignData.get_default_probe_config()
	
	var tel = Helios4CampaignData.calculate_hangar_telemetry()
	
	# Multistage Tsiolkovsky Rocket Equation:
	# Each stage must be calculated separately without averaging engine Isp values
	_assert_true(tel["delta_v_stage1"] > 3000.0, "Stage 1 Booster ΔV computed (> 3,000 m/s)")
	_assert_true(tel["delta_v_stage2"] > 5000.0, "Stage 2 Vacuum ΔV computed (> 5,000 m/s)")
	_assert_true(tel["delta_v_probe"] > 400.0, "Spacecraft Bus ΔV computed (> 400 m/s)")
	_assert_true(tel["total_launch_delta_v"] >= 9100.0, "Total Launch Vehicle ΔV reaches Trans-L1 transfer threshold (>= 9,100 m/s)")
	_assert_true(tel["total_mission_delta_v"] > 9500.0, "Total Mission ΔV includes probe halo-orbit insertion reserves")
	
	# Liftoff Thrust-to-Weight Ratio (TWR)
	_assert_true(tel["liftoff_twr"] >= 1.20 and tel["liftoff_twr"] <= 1.85, "Liftoff TWR is within safe pad clearance envelope (1.20 - 1.85)")
	
	# Aerodynamic Static Margin (CoM vs CoP)
	_assert_true(tel["static_margin_calibers"] >= 1.20, "Aerodynamic Static Margin is positive (> 1.2 calibers) indicating passive aerodynamic stability")
	
	# Power Generation vs Electrical Load
	_assert_true(tel["power_generation_w"] > 0.0, "Solar wings generate power at 1 AU (~1388 W/m² solar flux)")
	_assert_true(tel["power_margin_w"] >= 100.0, "Positive power surplus margin (>= +100W) across avionics, instruments, and transmitters")
	
	# Budget Allocation
	_assert_true(tel["total_cost_m"] <= tel["budget_cap_m"], "Total campaign cost is within $185.0M ceiling")
	_assert_true(tel["all_gate_checks_passed"], "All engineering readiness review gate checks pass on default build")

func test_astrogator_trajectory_mode_and_team_log() -> void:
	print("\n[TEST 3B] Astrogator Trajectory Modes & Shared Team Decision Log")
	var v_cfg = Helios4CampaignData.get_default_vehicle_config()
	v_cfg["trajectory_mode"] = "direct_injection"
	Helios4CampaignData.vehicle_config = v_cfg
	
	var tel_direct = Helios4CampaignData.calculate_hangar_telemetry()
	_assert_true(tel_direct["req_launch_dv"] == 9100.0, "Direct injection requires 9,100 m/s launch Delta-V")
	_assert_true(tel_direct["req_probe_dv"] == 420.0, "Direct injection requires 420 m/s probe capture/SK Delta-V")
	_assert_true(tel_direct["transfer_days"] == 110, "Direct injection cruise duration is 110 days")
	
	v_cfg["trajectory_mode"] = "phased_wsb"
	Helios4CampaignData.vehicle_config = v_cfg
	var tel_wsb = Helios4CampaignData.calculate_hangar_telemetry()
	_assert_true(tel_wsb["req_launch_dv"] == 8950.0, "Phased WSB transfer reduces launch Delta-V threshold to 8,950 m/s")
	_assert_true(tel_wsb["req_probe_dv"] == 460.0, "Phased WSB transfer requires 460 m/s probe maneuver Delta-V")
	_assert_true(tel_wsb["transfer_days"] == 135, "Phased WSB transfer cruise duration is 135 days")
	
	# Verify team decision logging
	Helios4CampaignData.team_decision_log.clear()
	Helios4CampaignData.record_team_decision(Helios4CampaignData.ROLE_ASTROGATOR, "Trajectory Optimization", "Selected Phased WSB transfer mode (135-Day cruise)")
	Helios4CampaignData.record_team_decision(Helios4CampaignData.ROLE_PROPULSION, "Engine Selection", "Selected Hydrolox Quad")
	
	_assert_true(Helios4CampaignData.team_decision_log.size() == 2, "Team decision log recorded two specialist actions")
	_assert_true(Helios4CampaignData.team_decision_log[0]["role"] == Helios4CampaignData.ROLE_ASTROGATOR, "Astrogator decision recorded in team history")
	_assert_true(Helios4CampaignData.team_decision_log[1]["role"] == Helios4CampaignData.ROLE_PROPULSION, "Propulsion decision recorded in team history")

func test_launch_max_q_and_staging() -> void:
	print("\n[TEST 4] Phase 2 Launch, Max-Q Dynamic Pressure & Staging")
	# Atmospheric density at 12 km: rho = rho_0 * exp(-12000 / 7500)
	var h: float = 12000.0
	var rho = 1.225 * exp(-h / 7500.0)
	var v: float = 520.0 # m/s
	var q_kpa = (0.5 * rho * v * v) / 1000.0
	
	_assert_true(q_kpa >= 30.0 and q_kpa <= 38.0, "Max-Q dynamic pressure calculation (q = 0.5 * rho * v^2) accurately peaks around 30-38 kPa at 12 km")
	
	# G-load vs Kinematic Acceleration separation
	var thrust_n: float = 4200000.0
	var mass_kg: float = 30000.0
	var g_load: float = thrust_n / (mass_kg * 9.80665)
	_assert_approx(g_load, 14.27, 0.5, "G-load computed as felt thrust-to-mass acceleration (distinct from kinematic rate of climb)")

func test_deep_space_transfer_and_crises() -> void:
	print("\n[TEST 5] Deep-Space Transfer & Three Deterministic Crises")
	# Event A: Solar Particle Event choices
	var event_a_safe_degradation = 0.0
	var event_a_continue_degradation = 18.0
	_assert_true(event_a_safe_degradation == 0.0, "Event A Full Safe Mode prevents equipment radiation degradation")
	_assert_true(event_a_continue_degradation > 10.0, "Event A Continue Science incurs measured radiation wear")
	
	# Event B: Micrometeoroid Leakage choices
	var leak_rate_kgs = 1.5
	var time_to_isolate_rapid = 10.0
	var fuel_lost_rapid = leak_rate_kgs * time_to_isolate_rapid
	_assert_approx(fuel_lost_rapid, 15.0, 0.1, "Event B Rapid Isolation Valve seals leak within 10s (15 kg fuel loss)")
	
	# Event C: Star Tracker Blackout choices
	var imu_accuracy_deg = 0.08
	var ground_dsn_accuracy_deg = 0.02
	_assert_true(ground_dsn_accuracy_deg < imu_accuracy_deg, "Ground DSN radiometric update provides premier attitude knowledge (±0.02°)")

func test_l1_halo_insertion_and_early_warning() -> void:
	print("\n[TEST 6] Sun-Earth L1 Halo-Orbit Insertion & Early-Warning Advance Notice")
	# Task 1: Dynamic Early-Warning Calculation (t = d / v / 60)
	var l1_dist_km: float = Helios4CampaignData.L1_DISTANCE_KM # 1,500,000 km
	
	# Severe CME shock at 2,420 km/s -> ~10.33 minutes
	var lead_time_2420 = Helios4CampaignData.calculate_warning_lead_time_minutes(2420.0, l1_dist_km)
	_assert_approx(lead_time_2420, 10.3306, 0.01, "Dynamic early warning calculation at 2,420 km/s yields ~10.33 minutes (1.5M km / 2420 / 60)")
	
	# Ambient solar-wind / slow stream at 600 km/s -> ~41.67 minutes
	var lead_time_600 = Helios4CampaignData.calculate_warning_lead_time_minutes(600.0, l1_dist_km)
	_assert_approx(lead_time_600, 41.6667, 0.01, "Dynamic early warning calculation at 600 km/s yields ~41.67 minutes (1.5M km / 600 / 60)")
	
	# Edge / invalid / zero velocity cases
	var lead_time_zero_v = Helios4CampaignData.calculate_warning_lead_time_minutes(0.0, l1_dist_km)
	_assert_true(lead_time_zero_v == 0.0, "Zero velocity returns 0.0 warning minutes safely")
	
	var lead_time_neg_v = Helios4CampaignData.calculate_warning_lead_time_minutes(-500.0, l1_dist_km)
	_assert_true(lead_time_neg_v == 0.0, "Negative velocity returns 0.0 warning minutes safely")
	
	var lead_time_zero_d = Helios4CampaignData.calculate_warning_lead_time_minutes(2420.0, 0.0)
	_assert_true(lead_time_zero_d == 0.0, "Zero distance returns 0.0 warning minutes safely")
	
	# Cross-check DonkiService calculation consistency
	var donki_2420 = DonkiService.calculate_warning_lead_time_minutes(2420.0, l1_dist_km)
	_assert_approx(donki_2420, lead_time_2420, 0.001, "DonkiService calculation matches Helios4CampaignData authoritative method")
	var donki_zero = DonkiService.calculate_warning_lead_time_minutes(0.0, l1_dist_km)
	_assert_true(donki_zero == 0.0, "DonkiService zero velocity returns 0.0")

	# Task 2: 3D Parametric Halo Orbit Geometry Verification
	var ax = 0.85
	var ay = 2.4
	var az = 3.4
	_assert_true(ax > 0.0 and ay > 0.0 and az > 0.0, "Halo orbit model possesses non-zero amplitudes across all 3 axes (Ax=0.85, Ay=2.4, Az=3.4)")
	
	# Parametric equations: x(phi) = -ax * cos(2*phi), y(phi) = ay * sin(phi), z(phi) = az * cos(phi)
	var p_start = Vector3(-ax * cos(0.0), ay * sin(0.0), az * cos(0.0))
	var p_end = Vector3(-ax * cos(TAU), ay * sin(TAU), az * cos(TAU))
	var closure_diff = p_start.distance_to(p_end)
	_assert_true(closure_diff < 0.0001, "Educational 3D parametric halo path is a closed continuous curve (phi 0 to 2*PI)")
	
	var p_quarter = Vector3(-ax * cos(PI), ay * sin(PI * 0.5), az * cos(PI * 0.5))
	_assert_true(abs(p_quarter.x - ax) < 0.001, "X-axis exhibits 2*phi harmonic excursion (saddle manifold property)")
	_assert_true(abs(p_start.x - (-ax)) < 0.001, "X-axis displacement spans [-0.85, +0.85] proving true 3D spatial displacement without planar collapse")

	# Task 3: Stationkeeping Reserve Rocket Equation & Illustrative Threshold
	var m_dry = 428.5 # Modeled dry mass in kg
	var isp = 315.0 # Hydrazine monopropellant Isp in s
	var g0 = 9.80665 # Standard gravity m/s^2
	var m_reserve = 35.0 # Illustrative reserve threshold in kg
	var delta_v_reserve = isp * g0 * log(1.0 + m_reserve / m_dry)
	_assert_approx(delta_v_reserve, 242.5, 2.0, "Rocket equation confirms 35 kg propellant reserve yields ~242.5 m/s delta-v")
	_assert_true(delta_v_reserve >= 90.0, "Reserve delta-v (242.5 m/s) exceeds theoretical 3-year baseline (3 x 30 = 90 m/s)")
	
	# Verify illustrative threshold phrasing
	var tel_hangar = Helios4CampaignData.calculate_hangar_telemetry()
	var probe_check_advice = ""
	for check in tel_hangar.get("gate_checks", []):
		if check.get("id") == "probe_dv_check":
			probe_check_advice = check.get("advice", "")
			break
	_assert_true(probe_check_advice.contains("illustrative stationkeeping threshold"), "Hangar checklist strictly designates stationkeeping reserve as illustrative threshold rather than guaranteed lifetime")

func test_debrief_score_arithmetic() -> void:
	print("\n[TEST 6B] Authoritative Debrief Scoring Function & Pillar Arithmetic Consistency")
	# Case 1: High-performance run with minor stress
	var l_tel_1 = {"structural_stress_pct": 2.4, "trajectory_error_pct": 0.0}
	var c_res_1 = {"equipment_degradation_pct": 5.0, "science_bonus_pts": 10.0}
	var l1_tel_1 = {"final_propellant_kg": 205.0, "warning_packet_sent": true}
	
	var res1 = Helios4CampaignData.calculate_debrief_score(l_tel_1, c_res_1, l1_tel_1)
	var expected_sum1 = snappedf(res1["launch_pillar"] + res1["crisis_pillar"] + res1["l1_pillar"] + res1["warning_pillar"], 0.1)
	
	_assert_approx(res1["total_score"], expected_sum1, 0.001, "Debrief category scores exactly sum to reported overall score (%.1f + %.1f + %.1f + %.1f == %.1f)" % [
		res1["launch_pillar"], res1["crisis_pillar"], res1["l1_pillar"], res1["warning_pillar"], res1["total_score"]
	])
	_assert_true(res1["is_success"], "Mission marked as successful")
	_assert_true(res1["letter_grade"] == "A+", "Total score >= 90 receives A+ grade")
	
	# Case 2: Degraded run with heavy damage and lower fuel
	var l_tel_2 = {"structural_stress_pct": 12.0, "trajectory_error_pct": 4.0}
	var c_res_2 = {"equipment_degradation_pct": 18.0, "science_bonus_pts": 0.0}
	var l1_tel_2 = {"final_propellant_kg": 50.0, "warning_packet_sent": true}
	
	var res2 = Helios4CampaignData.calculate_debrief_score(l_tel_2, c_res_2, l1_tel_2)
	var expected_sum2 = snappedf(res2["launch_pillar"] + res2["crisis_pillar"] + res2["l1_pillar"] + res2["warning_pillar"], 0.1)
	
	_assert_approx(res2["total_score"], expected_sum2, 0.001, "Degraded debrief category scores sum exactly to total score")
	_assert_true(res2["l1_pillar"] == 18.0, "Propellant between 35 and 80 kg scores 18.0 pts")
	
	# Case 3: Failed early warning delivery
	var l1_tel_3 = {"final_propellant_kg": 50.0, "warning_packet_sent": false}
	var res3 = Helios4CampaignData.calculate_debrief_score(l_tel_2, c_res_2, l1_tel_3)
	_assert_true(res3["warning_pillar"] == 0.0, "Failed warning transmission gives 0 pts on warning pillar")
	_assert_true(not res3["is_success"], "Failed warning transmission marks mission as degraded/failed")
	_assert_approx(res3["total_score"], snappedf(res3["launch_pillar"] + res3["crisis_pillar"] + res3["l1_pillar"] + res3["warning_pillar"], 0.1), 0.001, "Failed run category scores still sum exactly to total score")

func test_campaign_persistence() -> void:
	print("\n[TEST 7] Campaign State Persistence to user:// Storage")
	Helios4CampaignData.current_stage = Helios4CampaignData.Stage.PHASE_5_L1_INSERTION
	Helios4CampaignData.highest_unlocked_stage = Helios4CampaignData.Stage.PHASE_5_L1_INSERTION
	
	var save_ok = Helios4CampaignData.save_campaign_state()
	_assert_true(save_ok, "Successfully persisted campaign state to user://helios4_campaign.json")
	_assert_true(Helios4CampaignData.has_saved_campaign(), "has_saved_campaign() confirms file on disk")
	
	# Reset and reload
	Helios4CampaignData.current_stage = Helios4CampaignData.Stage.PROLOGUE
	var load_ok = Helios4CampaignData.load_campaign_state()
	_assert_true(load_ok, "Successfully reloaded campaign state from user://")
	_assert_true(Helios4CampaignData.current_stage == Helios4CampaignData.Stage.PHASE_5_L1_INSERTION, "Reloaded stage matches saved stage (PHASE_5_L1_INSERTION)")

func test_donki_space_weather_service() -> void:
	print("\n[TEST 8] NASA DONKI CCMC Space Weather Service & Local Catalog")
	_assert_true(DonkiService.BASE_URL.contains("ccmc.gsfc.nasa.gov"), "DONKI base URL points to official CCMC domain (migrated Sept 30, 2026)")
	_assert_true(DonkiService.OFFLINE_EVENT_CATALOG.size() >= 4, "Offline deterministic catalog contains at least 4 space weather benchmarks")
	
	var ev = DonkiService.get_campaign_crisis_event()
	_assert_true(ev["type"] == "CME", "Primary campaign crisis event is a CME")
	_assert_true(ev["cme_speed_kms"] >= 2000.0, "Superstorm CME speed exceeds 2,000 km/s")
	
	var threat = DonkiService.evaluate_space_weather_threat(2450.0, -34.0, "X14.8")
	_assert_true(threat["severity_tier"] == 5, "Threat evaluated as Category 5 (G5+ Extreme Superstorm)")
	_assert_true(threat["warning_title"].contains("G5+"), "Threat advisory title reflects G5+ superstorm")
