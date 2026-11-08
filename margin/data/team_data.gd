class_name TeamData
extends RefCounted

# ==============================================================================
# MARGIN: LOCAL COOPERATIVE TEAM MODE (PASS-AND-PLAY)
# 1–4 local participants across 4 mission roles:
# 1. Mission Director (Trajectory, Budget & Schedule Architecture, FRR Go/No-Go)
# 2. Systems Engineer (Spacecraft Bus, Power, Thermal, Mass & Reliability)
# 3. Science Lead (Instruments, Observation Target Priority, Scientific Yield)
# 4. Flight Dynamics & Comms Lead (Orbit, Transfer, Launcher & DSN Comms)
# ==============================================================================

const ROLE_DIRECTOR: String = "planner"
const ROLE_SYSTEMS: String = "engineer"
const ROLE_SCIENCE: String = "science_lead"
const ROLE_FLIGHT_COMMS: String = "comms_officer"

static var is_team_mode_active: bool = false
static var player_count: int = 1 # 1 to 4 players

# Player Names mapped to roles
static var role_assignments: Dictionary = {
	ROLE_DIRECTOR: "Player 1 (Director)",
	ROLE_SYSTEMS: "Player 2 (Systems)",
	ROLE_SCIENCE: "Player 3 (Science)",
	ROLE_FLIGHT_COMMS: "Player 4 (Flight/Comms)"
}

# Role definitions & metadata
static var role_definitions: Dictionary = {
	ROLE_DIRECTOR: {
		"id": ROLE_DIRECTOR,
		"title": "Mission Director",
		"alias": "director",
		"callsign": "FLIGHT DIRECTOR",
		"focus": "Overall Mission Objectives, Budget & Schedule, Launch Approval",
		"color": Color(0.95, 0.75, 0.2), # Gold
		"icon": "★"
	},
	ROLE_SYSTEMS: {
		"id": ROLE_SYSTEMS,
		"title": "Systems Engineer",
		"alias": "systems",
		"callsign": "CHIEF SYSTEMS",
		"focus": "Spacecraft Bus Configuration, Mass, Power Balance & Bus Health",
		"color": Color(0.2, 0.85, 0.45), # Green
		"icon": "⚙"
	},
	ROLE_SCIENCE: {
		"id": ROLE_SCIENCE,
		"title": "Science Lead",
		"alias": "science",
		"callsign": "PRINCIPAL INVESTIGATOR",
		"focus": "Payload Instrumentation, Observation Targets & Scientific Yield",
		"color": Color(0.22, 0.74, 0.96), # Cyan
		"icon": "🔬"
	},
	ROLE_FLIGHT_COMMS: {
		"id": ROLE_FLIGHT_COMMS,
		"title": "Flight Dynamics & Comms Lead",
		"alias": "flight_comms",
		"callsign": "FLIGHT DYNAMICS",
		"focus": "Orbital Geometry, Delta-V Trajectory, Launcher & DSN Downlink",
		"color": Color(0.85, 0.45, 0.95), # Magenta/Purple
		"icon": "📡"
	}
}

# Decision Attribution Log across Workshop, Launch Planning & Operations
static var decision_history: Array = []

# Pre-Launch Flight Readiness Review (FRR) Voting Log
static var frr_review_results: Dictionary = {}

# --- SETUP & INITIALIZATION ---

static func configure_team(num_players: int, names: Dictionary = {}) -> void:
	player_count = clamp(num_players, 1, 4)
	is_team_mode_active = (player_count > 1)
	
	if names.is_empty():
		if player_count == 1:
			role_assignments[ROLE_DIRECTOR] = "Solo Operator"
			role_assignments[ROLE_SYSTEMS] = "Solo Operator"
			role_assignments[ROLE_SCIENCE] = "Solo Operator"
			role_assignments[ROLE_FLIGHT_COMMS] = "Solo Operator"
		elif player_count == 2:
			role_assignments[ROLE_DIRECTOR] = "Player 1 (Director & Flight)"
			role_assignments[ROLE_FLIGHT_COMMS] = "Player 1 (Director & Flight)"
			role_assignments[ROLE_SYSTEMS] = "Player 2 (Systems & Science)"
			role_assignments[ROLE_SCIENCE] = "Player 2 (Systems & Science)"
		elif player_count == 3:
			role_assignments[ROLE_DIRECTOR] = "Player 1 (Director)"
			role_assignments[ROLE_SYSTEMS] = "Player 2 (Systems)"
			role_assignments[ROLE_SCIENCE] = "Player 3 (Science)"
			role_assignments[ROLE_FLIGHT_COMMS] = "Player 1 (Director & Flight)"
		else:
			role_assignments[ROLE_DIRECTOR] = "Player 1 (Director)"
			role_assignments[ROLE_SYSTEMS] = "Player 2 (Systems)"
			role_assignments[ROLE_SCIENCE] = "Player 3 (Science)"
			role_assignments[ROLE_FLIGHT_COMMS] = "Player 4 (Flight/Comms)"
	else:
		for role in names:
			if role_assignments.has(role):
				role_assignments[role] = names[role]

static func get_player_name_for_role(role_id: String) -> String:
	return role_assignments.get(role_id, "Flight Team")

static func get_role_info(role_id: String) -> Dictionary:
	return role_definitions.get(role_id, role_definitions[ROLE_DIRECTOR])

static func reset_team_data() -> void:
	decision_history.clear()
	frr_review_results.clear()

# --- DECISION ATTRIBUTION LOGGING ---

static func log_decision(role_id: String, phase: String, decision_title: String, detail: String) -> void:
	var role = get_role_info(role_id)
	var player = get_player_name_for_role(role_id)
	decision_history.append({
		"role_id": role_id,
		"role_title": role["title"],
		"player_name": player,
		"phase": phase,
		"title": decision_title,
		"detail": detail,
		"timestamp": Time.get_ticks_msec()
	})

static func get_attribution_summary() -> Dictionary:
	var counts = {
		ROLE_DIRECTOR: 0,
		ROLE_SYSTEMS: 0,
		ROLE_SCIENCE: 0,
		ROLE_FLIGHT_COMMS: 0
	}
	for entry in decision_history:
		var r_id = entry.get("role_id", "")
		if counts.has(r_id):
			counts[r_id] += 1
			
	return {
		"total_decisions": decision_history.size(),
		"counts": counts,
		"history": decision_history.duplicate(true)
	}

# --- PRE-LAUNCH FLIGHT READINESS REVIEW (FRR) ---

static func evaluate_flight_readiness_review(telemetry: Dictionary, scenario = null) -> Dictionary:
	var min_sci = 70.0
	var req_dv = 839.5
	if scenario != null:
		min_sci = scenario.min_science_points
		req_dv = scenario.required_delta_v_ms
		
	var votes: Dictionary = {}
	
	# 1. Mission Director Review
	var dir_go: bool = true
	var dir_reasons: Array = []
	if telemetry.get("budget_qualified", true) == false or telemetry.get("budget_margin_pct", 5.0) < 0.0:
		dir_go = false
		dir_reasons.append("Spacecraft development exceeds scenario budget cap")
	if dir_go:
		dir_reasons.append("Budget reserves nominal (+$%0.1fM margin)" % telemetry.get("budget_margin_m", 15.0))
		dir_reasons.append("Mission schedule baseline verified for 365-day science operations")
		
	votes[ROLE_DIRECTOR] = {
		"role": role_definitions[ROLE_DIRECTOR]["title"],
		"player": get_player_name_for_role(ROLE_DIRECTOR),
		"is_go": dir_go,
		"reasons": dir_reasons,
		"metric": "Budget Margin: %+0.1f%%" % telemetry.get("budget_margin_pct", 10.0)
	}
	
	# 2. Systems Engineer Review
	var sys_go: bool = true
	var sys_reasons: Array = []
	if telemetry.get("mass_qualified", true) == false:
		sys_go = false
		sys_reasons.append("Spacecraft wet mass exceeds launch vehicle payload limit")
	if telemetry.get("power_qualified", true) == false:
		sys_go = false
		sys_reasons.append("Power deficit in sunlight or battery Depth of Discharge exceeds 70% in shadow")
	if telemetry.get("system_reliability_pct", 92.0) < 60.0:
		sys_go = false
		sys_reasons.append("Composite bus reliability below 60% aerospace threshold")
	if sys_go:
		sys_reasons.append("Bus power positive (+%0.1fW in sunlight, %0.1f%% DoD in eclipse)" % [
			telemetry.get("net_power_w", 120.0), telemetry.get("eclipse_dod_pct", 30.0)
		])
		sys_reasons.append("Thermal MLI and ADCS reaction wheels within design margins")
		
	votes[ROLE_SYSTEMS] = {
		"role": role_definitions[ROLE_SYSTEMS]["title"],
		"player": get_player_name_for_role(ROLE_SYSTEMS),
		"is_go": sys_go,
		"reasons": sys_reasons,
		"metric": "Mass: %0.1f kg | Rel: %0.1f%%" % [telemetry.get("wet_mass_kg", 250.0), telemetry.get("system_reliability_pct", 92.0)]
	}
	
	# 3. Science Lead Review
	var sci_go: bool = true
	var sci_reasons: Array = []
	var sci_score: float = telemetry.get("science_score", 85.0)
	if sci_score < min_sci:
		sci_go = false
		sci_reasons.append("Payload baseline science score (%0.1f pts) below required threshold (%0.1f pts)" % [sci_score, min_sci])
	if telemetry.get("data_qualified", true) == false:
		sci_go = false
		sci_reasons.append("Science data generation exceeds downlink bandwidth capacity")
	if sci_go:
		sci_reasons.append("Sensor resolution and integration parameters validated for target survey")
		sci_reasons.append("Solid-state data recorder buffer sized for orbital passes")
		
	votes[ROLE_SCIENCE] = {
		"role": role_definitions[ROLE_SCIENCE]["title"],
		"player": get_player_name_for_role(ROLE_SCIENCE),
		"is_go": sci_go,
		"reasons": sci_reasons,
		"metric": "Payload Score: %0.1f pts" % sci_score
	}
	
	# 4. Flight Dynamics & Comms Lead Review
	var flt_go: bool = true
	var flt_reasons: Array = []
	var dv_reserve: float = telemetry.get("delta_v_reserve_ms", 100.0)
	var link_margin: float = telemetry.get("link_margin_db", 3.5)
	if dv_reserve < 0.0 or telemetry.get("lifetime_qualified", true) == false:
		flt_go = false
		flt_reasons.append("Propellant budget insufficient for required orbital maneuvers and stationkeeping")
	if link_margin < 3.0 or telemetry.get("comms_qualified", true) == false:
		flt_go = false
		flt_reasons.append("RF Link margin (+%0.1f dB) fails +3.0 dB DSN ground closure standard" % link_margin)
	if flt_go:
		flt_reasons.append("Delta-V margin positive (+%0.0f m/s reserve for mid-course and capture)" % dv_reserve)
		flt_reasons.append("DSN link closure verified with +%0.1f dB link margin" % link_margin)
		
	votes[ROLE_FLIGHT_COMMS] = {
		"role": role_definitions[ROLE_FLIGHT_COMMS]["title"],
		"player": get_player_name_for_role(ROLE_FLIGHT_COMMS),
		"is_go": flt_go,
		"reasons": flt_reasons,
		"metric": "ΔV Reserve: +%0.0f m/s | Link: +%0.1f dB" % [dv_reserve, link_margin]
	}
	
	var go_count: int = 0
	for r_id in votes:
		if votes[r_id]["is_go"]:
			go_count += 1
			
	var frr_result = {
		"all_go": (go_count == 4),
		"go_count": go_count,
		"no_go_count": 4 - go_count,
		"votes": votes,
		"consensus_rating": "UNANIMOUS GO FOR LAUNCH" if go_count == 4 else ("MAJORITY GO (%d/4)" % go_count if go_count >= 3 else "FLIGHT READINESS HOLD")
	}
	
	frr_review_results = frr_result
	return frr_result

# --- DEBRIEF COORDINATION REPORT ---

static func generate_coordination_report(summary: Dictionary, debrief: Dictionary) -> Dictionary:
	var attr = get_attribution_summary()
	var team_contrib = debrief.get("team_contributions", {})
	
	var role_reports: Array = []
	var total_role_score: float = 0.0
	
	for r_id in [ROLE_DIRECTOR, ROLE_SYSTEMS, ROLE_SCIENCE, ROLE_FLIGHT_COMMS]:
		var def = role_definitions[r_id]
		var player = get_player_name_for_role(r_id)
		var contrib = team_contrib.get(r_id, {})
		var score = contrib.get("score", 85.0)
		total_role_score += score
		
		role_reports.append({
			"role_id": r_id,
			"title": def["title"],
			"player": player,
			"score": score,
			"decisions_led": attr["counts"].get(r_id, 0),
			"assessment": contrib.get("assessment", "Contributed to nominal operations."),
			"key_stat": contrib.get("key_stat", ""),
			"color": def["color"]
		})
		
	var avg_team_score: float = total_role_score / 4.0
	var synergy_label: String = "EXEMPLARY CREW COHESION"
	if avg_team_score < 70.0:
		synergy_label = "CHALLENGED CREW COORDINATION"
	elif avg_team_score < 85.0:
		synergy_label = "NOMINAL CREW COOPERATION"
		
	return {
		"is_team_mode": is_team_mode_active,
		"player_count": player_count,
		"synergy_score": avg_team_score,
		"synergy_rating": synergy_label,
		"frr_consensus": frr_review_results.get("consensus_rating", "UNANIMOUS GO FOR LAUNCH"),
		"role_reports": role_reports,
		"total_team_decisions": attr["total_decisions"],
		"attribution_history": attr["history"]
	}
