class_name TestTeamCoop
extends SceneTree

const TeamData = preload("res://margin/data/team_data.gd")
const SpacecraftState = preload("res://margin/scripts/spacecraft_state.gd")
const ComponentDatabase = preload("res://margin/data/component_data.gd")
const MissionScenario = preload("res://margin/data/mission_scenario.gd")
const ScoringEngine = preload("res://margin/scripts/scoring_engine.gd")
const MissionSimulator = preload("res://margin/scripts/mission_simulator.gd")

var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	print("\n==================================================")
	print("  MARGIN: LOCAL COOPERATIVE TEAM MODE TEST SUITE")
	print("==================================================")
	
	test_team_configuration_and_roles()
	test_decision_attribution()
	test_frr_unanimous_go()
	test_frr_systems_no_go()
	test_frr_director_no_go()
	test_frr_flight_comms_no_go()
	test_frr_science_no_go()
	test_debrief_coordination_report()
	
	# Cleanup
	TeamData.reset_team_data()
	TeamData.configure_team(1)
	
	print("\n--------------------------------------------------")
	print("TEAM COOP TESTS: %d PASSED, %d FAILED" % [_passed, _failed])
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

func test_team_configuration_and_roles() -> void:
	print("\n[TEST 1] Team Configuration (1 to 4 Players) & Role Definitions")
	TeamData.reset_team_data()
	
	# 1 Player (Solo)
	TeamData.configure_team(1)
	_assert_true(TeamData.player_count == 1, "Player count is 1")
	_assert_true(not TeamData.is_team_mode_active, "Team mode inactive for solo player")
	_assert_true(TeamData.get_player_name_for_role(TeamData.ROLE_DIRECTOR).contains("Solo"), "Solo player covers Director")
	
	# 2 Players
	TeamData.configure_team(2)
	_assert_true(TeamData.player_count == 2, "Player count is 2")
	_assert_true(TeamData.is_team_mode_active, "Team mode active for 2 players")
	_assert_true(TeamData.get_player_name_for_role(TeamData.ROLE_DIRECTOR).contains("Player 1"), "Player 1 covers Director")
	_assert_true(TeamData.get_player_name_for_role(TeamData.ROLE_SYSTEMS).contains("Player 2"), "Player 2 covers Systems")
	
	# 4 Players
	TeamData.configure_team(4)
	_assert_true(TeamData.player_count == 4, "Player count is 4")
	_assert_true(TeamData.get_player_name_for_role(TeamData.ROLE_FLIGHT_COMMS).contains("Player 4"), "Player 4 covers Flight/Comms")
	
	# Verify all 4 roles exist
	var r1 = TeamData.get_role_info(TeamData.ROLE_DIRECTOR)
	var r2 = TeamData.get_role_info(TeamData.ROLE_SYSTEMS)
	var r3 = TeamData.get_role_info(TeamData.ROLE_SCIENCE)
	var r4 = TeamData.get_role_info(TeamData.ROLE_FLIGHT_COMMS)
	_assert_true(r1["title"] == "Mission Director", "Role 1 is Mission Director")
	_assert_true(r2["title"] == "Systems Engineer", "Role 2 is Systems Engineer")
	_assert_true(r3["title"] == "Science Lead", "Role 3 is Science Lead")
	_assert_true(r4["title"] == "Flight Dynamics & Comms Lead", "Role 4 is Flight Dynamics & Comms Lead")

func test_decision_attribution() -> void:
	print("\n[TEST 2] Decision Attribution Tracking Across Phases")
	TeamData.reset_team_data()
	TeamData.configure_team(4)
	
	# Log decisions across Workshop, Launch, Operations
	TeamData.log_decision(TeamData.ROLE_SYSTEMS, "Workshop", "Selected CFRP Structure", "Mass saving")
	TeamData.log_decision(TeamData.ROLE_SYSTEMS, "Workshop", "Selected Triple-Junction Solar Panels", "Power margin")
	TeamData.log_decision(TeamData.ROLE_SCIENCE, "Workshop", "Equipped Neutron Spectrometer", "Primary science")
	TeamData.log_decision(TeamData.ROLE_FLIGHT_COMMS, "Launch Planning", "Targeted Low Circular Orbit", "Resolution optimization")
	TeamData.log_decision(TeamData.ROLE_DIRECTOR, "Launch Planning", "FRR Go-For-Launch Directive", "Approved flight profile")
	TeamData.log_decision(TeamData.ROLE_DIRECTOR, "Operations", "Set High-Res Survey Mode", "Boost science yield")
	
	var attr = TeamData.get_attribution_summary()
	_assert_true(attr["total_decisions"] == 6, "Total decisions recorded is 6")
	_assert_true(attr["counts"][TeamData.ROLE_SYSTEMS] == 2, "Systems Engineer led 2 decisions")
	_assert_true(attr["counts"][TeamData.ROLE_SCIENCE] == 1, "Science Lead led 1 decision")
	_assert_true(attr["counts"][TeamData.ROLE_FLIGHT_COMMS] == 1, "Flight Dynamics led 1 decision")
	_assert_true(attr["counts"][TeamData.ROLE_DIRECTOR] == 2, "Mission Director led 2 decisions")

func test_frr_unanimous_go() -> void:
	print("\n[TEST 3] FRR Voting — Unanimous GO Evaluation")
	var state = SpacecraftState.new()
	var t = state.calculate_telemetry()
	var scen = MissionScenario.get_active_scenario()
	
	var frr = TeamData.evaluate_flight_readiness_review(t, scen)
	_assert_true(frr["all_go"], "FRR result is UNANIMOUS GO when telemetry meets all criteria")
	_assert_true(frr["go_count"] == 4, "All 4 roles voted GO")
	_assert_true(frr["no_go_count"] == 0, "0 NO-GO votes")
	_assert_true(frr["consensus_rating"] == "UNANIMOUS GO FOR LAUNCH", "Consensus is UNANIMOUS GO FOR LAUNCH")
	_assert_true(frr["votes"][TeamData.ROLE_DIRECTOR]["is_go"], "Director voted GO")
	_assert_true(frr["votes"][TeamData.ROLE_SYSTEMS]["is_go"], "Systems voted GO")
	_assert_true(frr["votes"][TeamData.ROLE_SCIENCE]["is_go"], "Science voted GO")
	_assert_true(frr["votes"][TeamData.ROLE_FLIGHT_COMMS]["is_go"], "Flight Comms voted GO")

func test_frr_systems_no_go() -> void:
	print("\n[TEST 4] FRR Voting — Systems Engineer NO-GO on Power/Mass Deficit")
	var t = {
		"mass_qualified": false,
		"power_qualified": false,
		"budget_qualified": true,
		"data_qualified": true,
		"comms_qualified": true,
		"lifetime_qualified": true,
		"science_score": 85.0,
		"system_reliability_pct": 50.0
	}
	var scen = MissionScenario.get_active_scenario()
	var frr = TeamData.evaluate_flight_readiness_review(t, scen)
	
	_assert_true(not frr["all_go"], "FRR fails unanimous go")
	_assert_true(not frr["votes"][TeamData.ROLE_SYSTEMS]["is_go"], "Systems Engineer voted NO-GO")
	_assert_true(frr["votes"][TeamData.ROLE_SYSTEMS]["reasons"].size() >= 2, "Systems cited specific engineering reasons")
	_assert_true(frr["votes"][TeamData.ROLE_DIRECTOR]["is_go"], "Director is still GO")

func test_frr_director_no_go() -> void:
	print("\n[TEST 5] FRR Voting — Mission Director NO-GO on Cost Overrun")
	var t = {
		"mass_qualified": true,
		"power_qualified": true,
		"budget_qualified": false,
		"budget_margin_pct": -5.0,
		"data_qualified": true,
		"comms_qualified": true,
		"lifetime_qualified": true,
		"science_score": 85.0,
		"system_reliability_pct": 92.0
	}
	var scen = MissionScenario.get_active_scenario()
	var frr = TeamData.evaluate_flight_readiness_review(t, scen)
	
	_assert_true(not frr["votes"][TeamData.ROLE_DIRECTOR]["is_go"], "Director voted NO-GO on budget overrun")
	_assert_true(frr["votes"][TeamData.ROLE_SYSTEMS]["is_go"], "Systems Engineer is GO")

func test_frr_flight_comms_no_go() -> void:
	print("\n[TEST 6] FRR Voting — Flight Dynamics NO-GO on Delta-V / Link Deficit")
	var t = {
		"mass_qualified": true,
		"power_qualified": true,
		"budget_qualified": true,
		"data_qualified": true,
		"comms_qualified": false,
		"link_margin_db": 1.2, # Below 3.0 dB
		"lifetime_qualified": false,
		"delta_v_reserve_ms": -50.0,
		"science_score": 85.0,
		"system_reliability_pct": 92.0
	}
	var scen = MissionScenario.get_active_scenario()
	var frr = TeamData.evaluate_flight_readiness_review(t, scen)
	
	_assert_true(not frr["votes"][TeamData.ROLE_FLIGHT_COMMS]["is_go"], "Flight Dynamics voted NO-GO on negative reserves & low RF link")
	_assert_true(frr["votes"][TeamData.ROLE_SCIENCE]["is_go"], "Science is GO")

func test_frr_science_no_go() -> void:
	print("\n[TEST 7] FRR Voting — Science Lead NO-GO on Underperforming Payload")
	var t = {
		"mass_qualified": true,
		"power_qualified": true,
		"budget_qualified": true,
		"data_qualified": true,
		"comms_qualified": true,
		"lifetime_qualified": true,
		"science_score": 45.0, # Below 70.0 threshold
		"system_reliability_pct": 92.0
	}
	var scen = MissionScenario.get_active_scenario()
	var frr = TeamData.evaluate_flight_readiness_review(t, scen)
	
	_assert_true(not frr["votes"][TeamData.ROLE_SCIENCE]["is_go"], "Science Lead voted NO-GO on sub-threshold score")

func test_debrief_coordination_report() -> void:
	print("\n[TEST 8] Debrief Coordination Report Integration")
	TeamData.reset_team_data()
	TeamData.configure_team(4)
	
	var state = SpacecraftState.new()
	var sim = MissionSimulator.new()
	sim.initialize(state, "orbit_low_circular", "transfer_low_energy", "lv_commercial_medium")
	
	# Simulate decisions
	TeamData.log_decision(TeamData.ROLE_DIRECTOR, "Workshop", "Approved baseline budget", "")
	TeamData.log_decision(TeamData.ROLE_SYSTEMS, "Workshop", "Equipped GaAS solar array", "")
	TeamData.log_decision(TeamData.ROLE_SCIENCE, "Workshop", "Selected LP-NS spectrometer", "")
	TeamData.log_decision(TeamData.ROLE_FLIGHT_COMMS, "Launch Planning", "Committed to Low-Energy BLT", "")
	
	for i in range(12):
		sim.advance_window("mode_nominal", "crater_shackleton", "")
		
	var summary = sim.get_campaign_summary()
	var debrief = ScoringEngine.evaluate_mission(summary, state)
	
	_assert_true(debrief.has("team_coordination"), "Debrief includes team_coordination report")
	var coord = debrief["team_coordination"]
	_assert_true(coord["is_team_mode"], "Coordination report reflects active team mode")
	_assert_true(coord["player_count"] == 4, "Report reflects 4-player crew")
	_assert_true(coord.has("synergy_score"), "Has crew synergy score")
	_assert_true(coord.has("role_reports"), "Has breakdown for all roles")
	_assert_true(coord["role_reports"].size() == 4, "Exactly 4 role reports present")
	_assert_true(coord["total_team_decisions"] >= 4, "Attributed at least 4 decisions")
	
	# Ensure 8-pillar scoring weights were NOT altered
	_assert_true(debrief["pillars"].size() == 8, "Debrief still evaluates exactly 8 pillars")
	var sum_w = 0.0
	for p in debrief["pillars"]:
		sum_w += p["weight"]
	_assert_true(is_equal_approx(sum_w, 1.0), "8-pillar weights still sum to exactly 1.00 (100%)")
