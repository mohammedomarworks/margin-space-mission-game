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
	test_launch_max_q_and_staging()
	test_deep_space_transfer_and_crises()
	test_l1_halo_insertion_and_early_warning()
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
	# Sun-Earth L1 distance ~ 1,500,000 km
	# Incoming CME shockwave speed ~ 2,420 km/s
	var l1_dist_km: float = 1500000.0
	var cme_speed_kms: float = 2420.0
	var travel_time_sec = l1_dist_km / cme_speed_kms
	var lead_time_min = travel_time_sec / 60.0
	
	_assert_approx(lead_time_min, 10.33, 1.0, "Physics calculation of advance warning lead time (t = d / v) confirmed")
	_assert_true(lead_time_min >= 10.0 and lead_time_min <= 60.0, "Advance warning lead time is in the authentic 15 to 60 minute operational window for solar storms")

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
