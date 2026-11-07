class_name ScoringEngine
extends RefCounted

# ==============================================================================
# MARGIN: EIGHT-PILLAR DETERMINISTIC SCORING ENGINE (MILESTONE 4)
# Fully transparent mathematical evaluation grounded in actual Mission Operations telemetry.
# ==============================================================================

const SpacecraftState = preload("res://margin/scripts/spacecraft_state.gd")
const ComponentDatabase = preload("res://margin/data/component_data.gd")
const MissionData = preload("res://margin/data/mission_data.gd")
const MissionOperationsData = preload("res://margin/data/mission_operations_data.gd")
const MissionScenario = preload("res://margin/data/mission_scenario.gd")
const TeamData = preload("res://margin/data/team_data.gd")

# 8 Category Weights (Sum = 1.00)
const WEIGHT_SCIENCE: float = 0.25
const WEIGHT_POWER: float = 0.15
const WEIGHT_BUDGET: float = 0.10
const WEIGHT_MASS_VOL: float = 0.10
const WEIGHT_DATA_STORAGE: float = 0.10
const WEIGHT_COMMS: float = 0.10
const WEIGHT_LIFETIME: float = 0.10
const WEIGHT_RELIABILITY: float = 0.10

static func evaluate_mission(
	summary: Dictionary,
	state: SpacecraftState,
	history: Array = []
) -> Dictionary:
	if state == null:
		state = SpacecraftState.new()
	
	var t: Dictionary = state.calculate_telemetry()
	
	# Extract Telemetry Inputs
	var is_terminated: bool = summary.get("is_terminated", false)
	var term_reason: String = summary.get("termination_reason", "")
	var windows_completed: int = summary.get("windows_completed", 0)
	var final_science_score: float = summary.get("final_science_score", 0.0)
	var avg_polar_cov: float = summary.get("avg_polar_coverage_pct", 0.0)
	var hydrogen_found: int = summary.get("hydrogen_candidates_found", 0)
	
	var battery_health: float = summary.get("battery_health_pct", 100.0)
	var blackout_count: int = summary.get("battery_blackout_count", 0)
	var data_downlinked: float = summary.get("data_downlinked_total_gbit", 0.0)
	var data_overflow_lost: float = summary.get("data_lost_overflow_gbit", 0.0)
	var prop_remaining: float = summary.get("propellant_remaining_kg", 0.0)
	var dv_remaining: float = summary.get("delta_v_remaining_ms", 0.0)
	var budget_balance: float = summary.get("budget_remaining_m", 0.0)
	
	# Estimate total data generated across windows
	var total_data_generated: float = data_downlinked + data_overflow_lost + summary.get("data_buffer_gbit", 0.0)
	if total_data_generated <= 0.0:
		total_data_generated = 100.0
	
	# Compute max eclipse Depth of Discharge observed across history
	var max_eclipse_dod: float = 0.0
	var min_net_sunlight_power: float = 999.0
	for win_rep in history:
		var dod: float = win_rep.get("battery_dod_pct", 0.0)
		if dod > max_eclipse_dod:
			max_eclipse_dod = dod
		var p_net: float = win_rep.get("net_sunlight_power_w", 100.0)
		if p_net < min_net_sunlight_power:
			min_net_sunlight_power = p_net
	if max_eclipse_dod == 0.0:
		max_eclipse_dod = t.get("eclipse_dod_pct", 31.0)
	if min_net_sunlight_power == 999.0:
		min_net_sunlight_power = t.get("net_power_w", 245.0)

	# --------------------------------------------------------------------------
	# PILLAR 1: SCIENTIFIC ACHIEVEMENT (25%)
	# --------------------------------------------------------------------------
	var p1_raw_pts: float = min(1.0, final_science_score / 100.0) * 50.0
	var p1_cov_pts: float = (avg_polar_cov / 100.0) * 30.0
	var p1_cand_pts: float = (float(hydrogen_found) / 6.0) * 20.0
	var p1_score: float = clampf(p1_raw_pts + p1_cov_pts + p1_cand_pts, 0.0, 100.0)
	
	var p1_dict: Dictionary = {
		"id": "scientific_achievement",
		"name": "Scientific Achievement",
		"weight": WEIGHT_SCIENCE,
		"score": p1_score,
		"weighted_score": p1_score * WEIGHT_SCIENCE,
		"metric_val": "%0.1f pts | %0.1f%% Cov | %d/6 Targets" % [final_science_score, avg_polar_cov, hydrogen_found],
		"formula": "Score = (Final Science / 100 × 50) + (Avg Polar Coverage % × 30) + (Targets Confirmed / 6 × 20)",
		"explanation": "Evaluates neutron spectrometer spectra collected, total south-polar crater mapping density, and confirmed hydrogen proxy candidates identified in cold-trap sectors."
	}

	# --------------------------------------------------------------------------
	# PILLAR 2: POWER & ECLIPSE PERFORMANCE (15%)
	# --------------------------------------------------------------------------
	var p2_solar_pts: float = 30.0 if min_net_sunlight_power >= 0.0 else max(0.0, 30.0 + min_net_sunlight_power * 0.2)
	var p2_dod_pts: float = 0.0
	if max_eclipse_dod <= 40.0:
		p2_dod_pts = 40.0
	elif max_eclipse_dod <= 70.0:
		p2_dod_pts = 40.0 - ((max_eclipse_dod - 40.0) / 30.0) * 25.0
	elif max_eclipse_dod < 100.0:
		p2_dod_pts = max(0.0, 15.0 - ((max_eclipse_dod - 70.0) / 30.0) * 15.0)
	else:
		p2_dod_pts = 0.0
	
	var p2_health_pts: float = (battery_health / 100.0) * 30.0 - (float(blackout_count) * 15.0)
	var p2_score: float = clampf(p2_solar_pts + p2_dod_pts + p2_health_pts, 0.0, 100.0)
	
	var p2_dict: Dictionary = {
		"id": "power_eclipse",
		"name": "Power & Eclipse Performance",
		"weight": WEIGHT_POWER,
		"score": p2_score,
		"weighted_score": p2_score * WEIGHT_POWER,
		"metric_val": "%0.1f%% SOH | %0.1f%% Peak DoD | %d Blackouts" % [battery_health, max_eclipse_dod, blackout_count],
		"formula": "Score = Sunlight Solar Margin (30 pts) + Eclipse DoD Curve (40 pts) + Battery SOH Health (30 pts) - Blackouts",
		"explanation": "Assesses positive electrical balance in sunlight, battery Depth of Discharge (DoD) during 48-minute orbital eclipses, and avoidance of bus blackouts."
	}

	# --------------------------------------------------------------------------
	# PILLAR 3: BUDGET EFFICIENCY (10%)
	# Spacecraft Dev Cost, Launch Vehicle Cost, Ops Expenditure & Remaining Budget
	# --------------------------------------------------------------------------
	var dev_cost_m: float = t.get("total_cost_m", summary.get("spacecraft_dev_cost_m", 112.5))
	var launch_cost_m: float = summary.get("launch_cost_m", 32.0)
	var ops_cost_m: float = summary.get("ops_cost_total_m", 14.4)
	var total_lifecycle_cost_m: float = dev_cost_m + launch_cost_m + ops_cost_m
	var budget_balance_m: float = summary.get("budget_remaining_m", MissionData.SCENARIO_BUDGET_CAP_M - total_lifecycle_cost_m)
	
	# Pre-launch Cost Discipline (50 pts):
	var pre_launch_cost_m: float = dev_cost_m + launch_cost_m
	var p3_dev_pts: float = 0.0
	if pre_launch_cost_m <= 165.0:
		p3_dev_pts = 40.0 + 10.0 * clampf((165.0 - pre_launch_cost_m) / 25.0, 0.0, 1.0)
	elif pre_launch_cost_m <= MissionData.SCENARIO_BUDGET_CAP_M:
		p3_dev_pts = 40.0 * ((MissionData.SCENARIO_BUDGET_CAP_M - pre_launch_cost_m) / 15.0)
	else:
		p3_dev_pts = 0.0
	
	# Operations Expenditure & Remaining Budget Margin (50 pts):
	var p3_ops_pts: float = 0.0
	if budget_balance_m >= 0.0:
		p3_ops_pts = 30.0 + 20.0 * clampf(budget_balance_m / 15.0, 0.0, 1.0)
	else:
		p3_ops_pts = max(0.0, 30.0 - (abs(budget_balance_m) / 5.0) * 30.0)
	
	var p3_score: float = clampf(p3_dev_pts + p3_ops_pts, 0.0, 100.0)
	
	var reserve_str: String = ("+$%0.1fM" % budget_balance_m) if budget_balance_m >= 0.0 else ("-$%0.1fM" % abs(budget_balance_m))
	var p3_dict: Dictionary = {
		"id": "budget_efficiency",
		"name": "Budget Efficiency",
		"weight": WEIGHT_BUDGET,
		"score": p3_score,
		"weighted_score": p3_score * WEIGHT_BUDGET,
		"metric_val": "$%0.1fM Cost ($%0.1fM Dev + $%0.1fM LV + $%0.1fM Ops) | %s Reserve" % [
			total_lifecycle_cost_m, dev_cost_m, launch_cost_m, ops_cost_m, reserve_str
		],
		"formula": "Score = Pre-Launch Cost Discipline (50 pts) + Post-Mission Operations Reserve (50 pts)",
		"explanation": "Evaluates financial discipline across spacecraft development, launch procurement, operations expenditure, and net budget reserve under the $180M scenario cap."
	}

	# --------------------------------------------------------------------------
	# PILLAR 4: MASS & VOLUME EFFICIENCY (10%)
	# --------------------------------------------------------------------------
	var wet_mass: float = t.get("wet_mass_kg", 236.6)
	var tli_cap: float = summary.get("tli_payload_capacity_kg", 380.0)
	if tli_cap <= 0.0:
		tli_cap = 380.0
	var mass_margin_pct: float = ((tli_cap - wet_mass) / tli_cap) * 100.0
	
	var p4_mass_pts: float = 0.0
	if mass_margin_pct >= 0.0:
		p4_mass_pts = 60.0 * min(1.0, (mass_margin_pct + 5.0) / 25.0)
	else:
		p4_mass_pts = 0.0
	
	var stowed_vol: float = t.get("stowed_volume_m3", 1.35)
	var fairing_vol: float = summary.get("fairing_volume_m3", 4.2)
	if fairing_vol <= 0.0:
		fairing_vol = 4.2
	var p4_vol_pts: float = clampf(40.0 * (1.0 - (stowed_vol / fairing_vol) * 0.4), 0.0, 40.0)
	var p4_score: float = clampf(p4_mass_pts + p4_vol_pts, 0.0, 100.0)
	
	var p4_dict: Dictionary = {
		"id": "mass_volume_efficiency",
		"name": "Mass & Volume Efficiency",
		"weight": WEIGHT_MASS_VOL,
		"score": p4_score,
		"weighted_score": p4_score * WEIGHT_MASS_VOL,
		"metric_val": "%0.1f kg Wet (%+0.1f%% Margin) | %0.2f m³ Stowed" % [wet_mass, mass_margin_pct, stowed_vol],
		"formula": "Score = TLI Payload Mass Fraction (60 pts) + Fairing Volume Packaging Ratio (40 pts)",
		"explanation": "Rewards lightweight structural topology, component density, and positive payload launch margin inside the launch vehicle fairing."
	}

	# --------------------------------------------------------------------------
	# PILLAR 5: DATA STORAGE MANAGEMENT (10%)
	# --------------------------------------------------------------------------
	var buffer_loss_ratio: float = data_overflow_lost / max(1.0, total_data_generated)
	var p5_loss_pts: float = max(0.0, 1.0 - buffer_loss_ratio * 2.0) * 80.0
	var p5_integrity_pts: float = max(0.0, 20.0 - float(blackout_count) * 10.0)
	var p5_score: float = clampf(p5_loss_pts + p5_integrity_pts, 0.0, 100.0)
	
	var p5_dict: Dictionary = {
		"id": "data_storage_management",
		"name": "Data Storage Management",
		"weight": WEIGHT_DATA_STORAGE,
		"score": p5_score,
		"weighted_score": p5_score * WEIGHT_DATA_STORAGE,
		"metric_val": "%0.1f Gbit Overflow Loss (%0.1f%% Lost)" % [data_overflow_lost, buffer_loss_ratio * 100.0],
		"formula": "Score = Buffer Overflow Loss Prevention (80 pts) + Storage Integrity & Blackout Immunity (20 pts)",
		"explanation": "Evaluates solid-state memory capacity sizing, preventing buffer overflows during high-rate mapping and protecting volatile records."
	}

	# --------------------------------------------------------------------------
	# PILLAR 6: COMMUNICATIONS THROUGHPUT (10%)
	# --------------------------------------------------------------------------
	var downlink_ratio: float = data_downlinked / max(1.0, total_data_generated)
	var p6_downlink_pts: float = clampf(downlink_ratio * 70.0, 0.0, 70.0)
	
	var link_margin_db: float = t.get("link_margin_db", 8.2)
	var p6_link_pts: float = 0.0
	if link_margin_db >= 6.0:
		p6_link_pts = 30.0
	elif link_margin_db >= 3.0:
		p6_link_pts = 20.0
	elif link_margin_db >= 0.0:
		p6_link_pts = 10.0
	else:
		p6_link_pts = 0.0
	var p6_score: float = clampf(p6_downlink_pts + p6_link_pts, 0.0, 100.0)
	
	var p6_dict: Dictionary = {
		"id": "communications_throughput",
		"name": "Communications Throughput",
		"weight": WEIGHT_COMMS,
		"score": p6_score,
		"weighted_score": p6_score * WEIGHT_COMMS,
		"metric_val": "%0.1f Gbit Downlinked (%0.1f%%) | %+0.1f dB Margin" % [data_downlinked, downlink_ratio * 100.0, link_margin_db],
		"formula": "Score = Downlinked Data Ratio (70 pts) + RF Link Margin Scale (30 pts)",
		"explanation": "Assesses ground station pass scheduling, telemetry link closure with DSN antennas, and net science bits delivered to planetary scientists."
	}

	# --------------------------------------------------------------------------
	# PILLAR 7: MISSION LIFETIME & SCHEDULE (10%)
	# --------------------------------------------------------------------------
	var p7_win_pts: float = (float(windows_completed) / 12.0) * 80.0
	var p7_bonus: float = 20.0 if (windows_completed >= 12 and not is_terminated) else 0.0
	var p7_score: float = clampf(p7_win_pts + p7_bonus, 0.0, 100.0)
	
	var p7_dict: Dictionary = {
		"id": "mission_lifetime_schedule",
		"name": "Mission Lifetime & Schedule",
		"weight": WEIGHT_LIFETIME,
		"score": p7_score,
		"weighted_score": p7_score * WEIGHT_LIFETIME,
		"metric_val": "%d / 12 Windows (%0.1f Days)" % [windows_completed, summary.get("mission_days_elapsed", 0.0)],
		"formula": "Score = Operational Windows Completed (80 pts) + Full 365-Day Campaign Completion Bonus (20 pts)",
		"explanation": "Measures orbital longevity, adherence to the mission timeline, and successfully surviving through all 12 operational stress events."
	}

	# --------------------------------------------------------------------------
	# PILLAR 8: SYSTEM RELIABILITY & HEALTH (10%)
	# 50% Pre-Launch Composite Subsystem Reliability + 50% Final Equipment Health
	# --------------------------------------------------------------------------
	var pre_launch_rel_pct: float = t.get("system_reliability_pct", summary.get("pre_launch_reliability_pct", 92.0))
	var final_equip_health_pct: float = summary.get("equipment_health_pct", 95.0)
	
	var p8_rel_pts: float = clampf(pre_launch_rel_pct, 0.0, 100.0) * 0.50
	var p8_health_pts: float = clampf(final_equip_health_pct, 0.0, 100.0) * 0.50
	var p8_score: float = clampf(p8_rel_pts + p8_health_pts, 0.0, 100.0)
	
	var p8_dict: Dictionary = {
		"id": "system_reliability_health",
		"name": "System Reliability & Health",
		"weight": WEIGHT_RELIABILITY,
		"score": p8_score,
		"weighted_score": p8_score * WEIGHT_RELIABILITY,
		"metric_val": "%0.1f%% Pre-Launch Rel | %0.1f%% Equipment Health" % [pre_launch_rel_pct, final_equip_health_pct],
		"formula": "Score = 50% Pre-Launch Composite Reliability + 50% Final Equipment Health",
		"explanation": "Evaluates composite hardware engineering reliability (component redundancy and heritage) combined with actual on-orbit operational equipment health and environmental survival."
	}

	# --------------------------------------------------------------------------
	# TOTAL WEIGHTED SCORE
	# --------------------------------------------------------------------------
	var pillars: Array[Dictionary] = [
		p1_dict, p2_dict, p3_dict, p4_dict,
		p5_dict, p6_dict, p7_dict, p8_dict
	]
	
	var total_weighted_score: float = 0.0
	for p in pillars:
		total_weighted_score += p["weighted_score"]
	total_weighted_score = clampf(total_weighted_score, 0.0, 100.0)

	# --------------------------------------------------------------------------
	# MISSION OUTCOME CLASSIFICATION (SUCCESS / PARTIAL SUCCESS / FAILURE)
	# --------------------------------------------------------------------------
	var outcome: String = "SUCCESS"
	var outcome_name: String = "MISSION SUCCESSFUL"
	var outcome_reasons: Array[String] = []
	
	var active_scen = MissionScenario.get_active_scenario()
	var min_p1_succ: float = 70.0 if active_scen.id == "earth_climate_sentinel" else 65.0
	var min_total_succ: float = 75.0 if active_scen.id == "earth_climate_sentinel" else 70.0
	
	if is_terminated:
		outcome = "FAILURE"
		outcome_name = "MISSION FAILED"
		outcome_reasons.append("Catastrophic Mission Termination: %s" % term_reason)
	elif total_weighted_score < 50.0:
		outcome = "FAILURE"
		outcome_name = "MISSION FAILED"
		outcome_reasons.append("Overall engineering performance composite (%0.1f pts) fell below the critical viability threshold (50.0 pts)." % total_weighted_score)
	elif p1_score < 35.0:
		outcome = "FAILURE"
		outcome_name = "MISSION FAILED"
		outcome_reasons.append("Primary scientific objective unfulfilled: Scientific achievement score (%0.1f pts) failed minimum mission standard." % p1_score)
	elif total_weighted_score < min_total_succ or p1_score < min_p1_succ or windows_completed < 12:
		outcome = "PARTIAL_SUCCESS"
		outcome_name = "PARTIAL MISSION SUCCESS"
		if windows_completed < 12:
			outcome_reasons.append("Premature end of operations: Completed %d of 12 scheduled flight windows." % windows_completed)
		if p1_score < min_p1_succ:
			outcome_reasons.append("Scientific return was constrained (%0.1f pts); target observation coverage below requirement." % p1_score)
		if total_weighted_score < min_total_succ:
			outcome_reasons.append("Engineering margins were tight (%0.1f weighted composite pts); operating reserves depleted." % total_weighted_score)
	else:
		outcome = "SUCCESS"
		outcome_name = "MISSION SUCCESSFUL"
		if active_scen.id == "earth_climate_sentinel":
			outcome_reasons.append("Primary Earth climate monitoring objectives completed across all 12 operational windows.")
			outcome_reasons.append("Robust scientific yield: Fully observed %d global climate sentinel zones." % hydrogen_found)
		else:
			outcome_reasons.append("Primary volatile mapping objectives completed across all 12 operational windows.")
			outcome_reasons.append("Robust scientific yield: Identified %d confirmed hydrogen proxy crater sectors." % hydrogen_found)
		outcome_reasons.append("Positive spacecraft flight margins maintained: +%0.0f m/s ΔV reserve and %0.1f%% battery SOH." % [dv_remaining, battery_health])

	# Letter Grade
	var grade: String = "F"
	if outcome == "FAILURE":
		grade = "F"
	elif total_weighted_score >= 90.0:
		grade = "A+"
	elif total_weighted_score >= 82.0:
		grade = "A"
	elif total_weighted_score >= 74.0:
		grade = "B+"
	elif total_weighted_score >= 70.0:
		grade = "B"
	elif total_weighted_score >= 60.0:
		grade = "C"
	elif total_weighted_score >= 50.0:
		grade = "D"
	else:
		grade = "F"

	# --------------------------------------------------------------------------
	# ENGINEERING DECISION AUDIT (TELEMETRY-GROUNDED INSIGHTS)
	# --------------------------------------------------------------------------
	var findings: Array[Dictionary] = _generate_engineering_audit(state, summary, history, pillars)

	# --------------------------------------------------------------------------
	# TEAM CONTRIBUTION (4 LOCAL ROLES)
	# --------------------------------------------------------------------------
	var team: Dictionary = _generate_team_contributions(pillars, summary, state)

	return {
		"total_weighted_score": total_weighted_score,
		"letter_grade": grade,
		"outcome": outcome,
		"outcome_name": outcome_name,
		"outcome_reasons": outcome_reasons,
		"pillars": pillars,
		"engineering_findings": findings,
		"team_contributions": team,
		"team_coordination": TeamData.generate_coordination_report(summary, {"team_contributions": team}),
		
		# Telemetry Echo
		"mission_name": summary.get("mission_name", "Lunar South Pole Survey"),
		"orbit_name": summary.get("orbit_name", "Low Circular Polar Orbit"),
		"transfer_name": summary.get("transfer_name", "Low-Energy Ballistic Transfer"),
		"vehicle_name": summary.get("vehicle_name", "Medium Commercial EELV-Class"),
		"windows_completed": windows_completed,
		"final_science_score": final_science_score,
		"avg_polar_coverage_pct": avg_polar_cov,
		"hydrogen_candidates_found": hydrogen_found,
		"crater_coverage": summary.get("crater_coverage", {}),
		"data_downlinked_total_gbit": data_downlinked,
		"data_lost_overflow_gbit": data_overflow_lost,
		"propellant_remaining_kg": prop_remaining,
		"delta_v_remaining_ms": dv_remaining,
		"battery_health_pct": battery_health,
		"battery_blackout_count": blackout_count,
		"equipment_health_pct": final_equip_health_pct,
		"pre_launch_reliability_pct": pre_launch_rel_pct,
		"spacecraft_dev_cost_m": dev_cost_m,
		"launch_cost_m": launch_cost_m,
		"ops_cost_total_m": ops_cost_m,
		"budget_remaining_m": budget_balance_m,
		"total_cost_m": total_lifecycle_cost_m,
		"wet_mass_kg": wet_mass,
		"scientific_caution": "Scientific Fact: Epithermal neutron moderation detects hydrogen enrichment proxy. It is NOT definitive proof of pure surface water ice at every location."
	}

# --- AUDIT FINDINGS GENERATOR ---

static func _generate_engineering_audit(
	state: SpacecraftState,
	summary: Dictionary,
	history: Array,
	pillars: Array
) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var t: Dictionary = state.calculate_telemetry()
	
	# 1. Payload Instrument Impact
	var inst = state.get_component(ComponentDatabase.Category.INSTRUMENTS)
	var inst_id: String = inst.get("id", "")
	if inst_id == "inst_gamma_neutron_lend":
		findings.append({
			"subsystem": "Scientific Instruments",
			"decision": "Equipped Collimated Neutron Detector Array (LRO LEND Heritage)",
			"verdict": "POSITIVE / RESOURCE-HEAVY",
			"impact_type": "positive",
			"detail": "Narrow passive collimator shielding enabled sharp 10 km spatial resolution over crater cold-traps, maximizing spectrometry points. However, its 28.5 kg dry mass and 46 W continuous power draw imposed significant battery demands during eclipse seasons."
		})
	elif inst_id == "inst_neutron_spectrometer":
		findings.append({
			"subsystem": "Scientific Instruments",
			"decision": "Equipped Helium-3 Proportional Counter (Lunar Prospector Heritage)",
			"verdict": "HIGH EFFICIENCY / COARSE RESOLUTION",
			"impact_type": "neutral",
			"detail": "Proportional counter consumed minimal power (16 W) and mass (14.5 kg), leaving generous electrical margins. Its broader 50 km footprint provided uniform regional surveys but could not isolate narrow crater PSR rims as sharply."
		})
	
	# 2. Operational Mode Usage Audit
	var mode_counts: Dictionary = { "mode_nominal": 0, "mode_high_res": 0, "mode_conserve": 0, "mode_comm_priority": 0 }
	for w in history:
		var m_name: String = w.get("mode_name", "")
		if "High-Resolution" in m_name:
			mode_counts["mode_high_res"] += 1
		elif "Power Conservation" in m_name:
			mode_counts["mode_conserve"] += 1
		elif "Communication" in m_name:
			mode_counts["mode_comm_priority"] += 1
		else:
			mode_counts["mode_nominal"] += 1
	
	if mode_counts["mode_high_res"] >= 4:
		findings.append({
			"subsystem": "Flight Operations Strategy",
			"decision": "Aggressive High-Resolution Mapping (%d / %d Windows)" % [mode_counts["mode_high_res"], history.size()],
			"verdict": "HIGH SCIENTIFIC RETURN",
			"impact_type": "positive",
			"detail": "Frequent high-resolution passes accelerated crater mapping and pushed science yield above target. Increased buffer fill rates required careful downlink synchronization."
		})
	
	if mode_counts["mode_conserve"] >= 1:
		findings.append({
			"subsystem": "Power & Thermal Management",
			"decision": "Power Conservation Activated During Eclipse / Stress Windows (%d Windows)" % mode_counts["mode_conserve"],
			"verdict": "CRITICAL BATTERY LIFESPAN PROTECTION",
			"impact_type": "positive",
			"detail": "Throttling secondary systems during peak eclipse windows kept battery Depth-of-Discharge well within electrochemical survival limits, preventing irreversible cell degradation."
		})
	
	# 3. Communications & Buffer Storage
	var overflow_lost: float = summary.get("data_lost_overflow_gbit", 0.0)
	if overflow_lost > 0.0:
		findings.append({
			"subsystem": "Command & Data Handling / Comms",
			"decision": "Solid-State Recorder Buffer Exceeded Downlink Capacity",
			"verdict": "DATA OVERFLOW BOTTLENECK (-%0.1f Gbit)" % overflow_lost,
			"impact_type": "negative",
			"detail": "Instrument data generation outpaced ground contact downlink bandwidth during tracking outages, filling the solid-state recorder and causing unrecovered data loss. Upgrading antenna aperture or activating Comm Priority mode would have preserved these packets."
		})
	else:
		findings.append({
			"subsystem": "Command & Data Handling / Comms",
			"decision": "Zero Solid-State Buffer Overflow Loss",
			"verdict": "FLAWLESS DATA THROUGHPUT",
			"impact_type": "positive",
			"detail": "Downlink scheduling and onboard recorder sizing successfully accommodated all generated science packets with 100% data preservation."
		})
	
	# 4. Propulsion Reserve & Orbit Integrity
	var dv_rem: float = summary.get("delta_v_remaining_ms", 0.0)
	if dv_rem >= 40.0:
		findings.append({
			"subsystem": "Propulsion & Trajectory",
			"decision": "Positive Flight Propulsion Reserve (+%0.0f m/s ΔV)" % dv_rem,
			"verdict": "EXTENDED MISSION CAPABLE",
			"impact_type": "positive",
			"detail": "The dual-mode chemical engine successfully completed LOI capture and all 12 monthly mascon stationkeeping burns while retaining +%0.0f m/s reserve for extended mission science." % dv_rem
		})
	else:
		findings.append({
			"subsystem": "Propulsion & Trajectory",
			"decision": "Tight Stationkeeping Delta-V Reserve (+%0.0f m/s)" % dv_rem,
			"verdict": "MARGINAL STATIONKEEPING BALANCE",
			"impact_type": "warning",
			"detail": "Spacecraft concluded primary mission near propellant exhaustion. Gravitational mascon perturbations consumed nearly all allocated propellant."
		})
	
	# Emergency Operational Directives Audit
	var emerg_list: Array = summary.get("emergency_decisions", [])
	for dec in emerg_list:
		var ev_id: String = dec.get("event_id", "")
		var ch_id: String = dec.get("choice_id", "")
		if ev_id == "event_solar_storm":
			if ch_id == "choice_safe_mode":
				findings.append({
					"subsystem": "Flight Operations & Thermal",
					"decision": "Executed Full Safe Mode During Solar Particle Storm",
					"verdict": "PRUDENT VEHICLE CONSERVATION",
					"impact_type": "positive",
					"detail": "Suspended non-essential instruments to protect sensitive detectors and optics from high-energy proton flux at the cost of reduced observation yield."
				})
			elif ch_id == "choice_partial_protection":
				findings.append({
					"subsystem": "Flight Operations & Thermal",
					"decision": "Executed Partial Protection & Protective Attitude Stance",
					"verdict": "BALANCED SCIENCE & PROTECTION",
					"impact_type": "neutral",
					"detail": "Disabled vulnerable optical payloads while retaining protected secondary sensors. Attitude alignment preserved 75% science with minimal modeled degradation (-2.5%)."
				})
			else:
				findings.append({
					"subsystem": "Flight Operations & Thermal",
					"decision": "Continued Operations Through Solar Storm",
					"verdict": "AGGRESSIVE SCIENCE / HARDWARE WEAR",
					"impact_type": "warning",
					"detail": "Preserved continuous orbital observations through particle storm, but accepted modeled sensor wear (-7.5% equipment health) and persistent SEU noise."
				})
		elif ev_id == "event_dsn_outage":
			if ch_id == "choice_backup_comm":
				findings.append({
					"subsystem": "Communications & Ground Networks",
					"decision": "Activated Commercial S-Band Relay During DSN Outage",
					"verdict": "BUFFER PRESERVATION",
					"impact_type": "positive",
					"detail": "Successfully mitigated solid-state recorder overflow by expending +$0.5M operations budget to secure commercial backup ground passes."
				})
			else:
				findings.append({
					"subsystem": "Communications & Ground Networks",
					"decision": "Buffered Science Data Onboard During DSN Madrid Outage",
					"verdict": "CONSERVATIVE BUDGET / ELEVATED BUFFER RISK",
					"impact_type": "neutral",
					"detail": "Saved operations funds by holding spectra in onboard memory, but sharply increased recorder occupancy heading into subsequent mapping passes."
				})
		elif ev_id == "event_battery_emergency":
			if ch_id == "choice_shed_load":
				findings.append({
					"subsystem": "Electrical Power Subsystem (EPS)",
					"decision": "Shed Non-Critical Loads During Deep Eclipse Emergency",
					"verdict": "BATTERY PRESERVATION",
					"impact_type": "positive",
					"detail": "Duty-cycled payload electronics during shadow transit, maintaining battery Depth-of-Discharge within safe limits and preserving cell longevity."
				})
			else:
				findings.append({
					"subsystem": "Electrical Power Subsystem (EPS)",
					"decision": "Maintained Full Science Load Through Deep Eclipse Emergency",
					"verdict": "HIGH ELECTRICAL STRESS",
					"impact_type": "warning",
					"detail": "Preserved observation rates during shadow pass, but subjected battery to severe Depth-of-Discharge (>85% DoD), accelerating cell capacity degradation."
				})
	
	# 5. Primary Positive and Negative Drivers
	var best_pillar: Dictionary = pillars[0]
	var worst_pillar: Dictionary = pillars[0]
	for p in pillars:
		if p["score"] > best_pillar["score"]:
			best_pillar = p
		if p["score"] < worst_pillar["score"]:
			worst_pillar = p
	
	findings.append({
		"subsystem": "System Synergy Analysis",
		"decision": "Primary Positive Engineering Driver: %s (%0.1f/100 pts)" % [best_pillar["name"], best_pillar["score"]],
		"verdict": "TOP PERFORMANCE DRIVER",
		"impact_type": "highlight_positive",
		"detail": best_pillar["explanation"]
	})
	
	findings.append({
		"subsystem": "System Synergy Analysis",
		"decision": "Primary Subsystem Bottleneck: %s (%0.1f/100 pts)" % [worst_pillar["name"], worst_pillar["score"]],
		"verdict": "KEY ENGINEERING BOTTLENECK",
		"impact_type": "highlight_negative",
		"detail": worst_pillar["explanation"]
	})
	
	return findings

# --- TEAM CONTRIBUTIONS GENERATOR ---

static func _generate_team_contributions(
	pillars: Array,
	summary: Dictionary,
	state: SpacecraftState
) -> Dictionary:
	# Extract pillar scores by ID
	var p_scores: Dictionary = {}
	for p in pillars:
		p_scores[p["id"]] = p["score"]
	
	# 1. Mission Planner Role
	var planner_score: float = (p_scores.get("budget_efficiency", 80.0) * 0.40) + \
		(p_scores.get("mission_lifetime_schedule", 80.0) * 0.35) + \
		(p_scores.get("mass_volume_efficiency", 80.0) * 0.25)
	
	# 2. Science Lead Role
	var science_score: float = (p_scores.get("scientific_achievement", 80.0) * 0.70) + \
		(p_scores.get("communications_throughput", 80.0) * 0.30)
	
	# 3. Spacecraft Engineer Role
	var engineer_score: float = (p_scores.get("power_eclipse", 80.0) * 0.40) + \
		(p_scores.get("system_reliability_health", 80.0) * 0.35) + \
		(p_scores.get("mass_volume_efficiency", 80.0) * 0.25)
	
	# 4. Operations & Communications Officer Role
	var ops_score: float = (p_scores.get("communications_throughput", 80.0) * 0.45) + \
		(p_scores.get("data_storage_management", 80.0) * 0.35) + \
		(p_scores.get("power_eclipse", 80.0) * 0.20)
	
	return {
		"planner": {
			"role": "Mission Planner",
			"title": "Trajectory, Budget & Launch Architect",
			"score": clampf(planner_score, 0.0, 100.0),
			"assessment": "Successfully matched orbital delta-V with launcher capability under scenario cost constraints.",
			"key_stat": "$%0.1fM Dev Cost | %d Windows Completed" % [summary.get("total_cost_m", 160.0), summary.get("windows_completed", 12)]
		},
		"science_lead": {
			"role": "Science Lead",
			"title": "Principal Investigator & Payload Lead",
			"score": clampf(science_score, 0.0, 100.0),
			"assessment": "Achieved volatile survey mapping goals across south-polar PSR cold traps.",
			"key_stat": "%0.1f Science pts | %d Craters Confirmed" % [summary.get("final_science_score", 85.0), summary.get("hydrogen_candidates_found", 6)]
		},
		"engineer": {
			"role": "Spacecraft Engineer",
			"title": "Systems, Power & Propulsion Lead",
			"score": clampf(engineer_score, 0.0, 100.0),
			"assessment": "Maintained positive bus power in sunlight and protected battery longevity through deep eclipses.",
			"key_stat": "%0.1f%% Pre-Launch Rel | %0.1f%% Equip Health" % [summary.get("pre_launch_reliability_pct", 92.0), summary.get("equipment_health_pct", 95.0)]
		},
		"comms_officer": {
			"role": "Operations & Comms Officer",
			"title": "Flight Director & DSN Ground Manager",
			"score": clampf(ops_score, 0.0, 100.0),
			"assessment": "Coordinated DSN passes and managed solid-state storage buffer against overflow risk.",
			"key_stat": "%0.1f Gbit Downlinked | %0.1f Gbit Lost" % [summary.get("data_downlinked_total_gbit", 140.0), summary.get("data_lost_overflow_gbit", 0.0)]
		}
	}
