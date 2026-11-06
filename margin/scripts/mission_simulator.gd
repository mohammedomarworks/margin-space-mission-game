class_name MissionSimulator
extends RefCounted

const SpacecraftState = preload("res://margin/scripts/spacecraft_state.gd")
const ComponentDatabase = preload("res://margin/data/component_data.gd")
const OrbitDatabase = preload("res://margin/data/orbit_data.gd")
const TransferDatabase = preload("res://margin/data/transfer_data.gd")
const LaunchVehicleDatabase = preload("res://margin/data/launch_vehicle_data.gd")
const MissionOperationsData = preload("res://margin/data/mission_operations_data.gd")
const MissionData = preload("res://margin/data/mission_data.gd")

# ==============================================================================
# MARGIN: MISSION OPERATIONS SIMULATOR ENGINE
# Fully deterministic multi-system simulation for 12 monthly operational windows
# ==============================================================================

signal window_advanced(window_idx: int, report: Dictionary)
signal campaign_completed(final_report: Dictionary)
signal mission_terminated(reason: String, report: Dictionary)

# State Variables
var current_window: int = 1 # 1 to 12
var mission_days_elapsed: float = 0.0 # days
var total_mission_days: float = 365.0
var window_duration_days: float = 365.0 / 12.0 # 30.4167 days per window

# Resources & Telemetry
var propellant_remaining_kg: float = 0.0
var delta_v_remaining_ms: float = 0.0
var dry_mass_kg: float = 170.0
var prop_isp_s: float = 295.0

var battery_capacity_wh: float = 450.0
var battery_health_pct: float = 100.0
var equipment_health_pct: float = 100.0
var battery_current_dod_pct: float = 0.0
var battery_blackout_count: int = 0

var data_buffer_gbit: float = 0.0
var data_buffer_capacity_gbit: float = 512.0 # 64 GB default
var data_downlinked_total_gbit: float = 0.0
var data_lost_overflow_gbit: float = 0.0

var operational_budget_remaining_m: float = 0.0
var spacecraft_dev_cost_m: float = 0.0
var launch_cost_m: float = 0.0
var ops_cost_total_m: float = 0.0
var science_score_total: float = 0.0

# Scientific Progress & Craters
var crater_coverage: Dictionary = {} # crater_id -> float % (0 to 100)
var hydrogen_candidates_found: int = 0

# Configuration References
var state: SpacecraftState
var selected_orbit: Dictionary = {}
var selected_transfer: Dictionary = {}
var selected_vehicle: Dictionary = {}
var current_mode_id: String = "mode_nominal"
var current_target_crater_id: String = "crater_shackleton"

# Operational Log
var window_history: Array[Dictionary] = []
var is_completed: bool = false
var is_terminated: bool = false
var termination_reason: String = ""

func initialize(
	p_state: SpacecraftState,
	orbit_id: String = "orbit_low_circular",
	transfer_id: String = "transfer_low_energy",
	vehicle_id: String = "lv_commercial_medium"
) -> void:
	state = p_state
	if state == null:
		state = SpacecraftState.new()
	
	selected_orbit = OrbitDatabase.get_orbit(orbit_id)
	selected_transfer = TransferDatabase.get_transfer(transfer_id)
	selected_vehicle = LaunchVehicleDatabase.get_vehicle(vehicle_id)
	
	var t: Dictionary = state.calculate_telemetry()
	
	# Determine Dry Mass and Isp
	dry_mass_kg = t.get("dry_mass_kg", 170.0)
	var prop_comp = state.get_component(ComponentDatabase.Category.PROPULSION)
	prop_isp_s = prop_comp.get("isp_s", 295.0)
	
	# Starting ΔV Reserve at start of science operations:
	# Total onboard ΔV minus (MCC + LOI retro-burn)
	var onboard_dv: float = t.get("delta_v_ms", 1020.0)
	var mcc_dv: float = selected_orbit.get("mcc_delta_v_ms", 20.0)
	var loi_dv: float = OrbitDatabase.get_loi_delta_v(orbit_id, transfer_id)
	
	var transit_expended_dv: float = mcc_dv + loi_dv
	delta_v_remaining_ms = max(0.0, onboard_dv - transit_expended_dv)
	
	# Compute propellant mass remaining for science operations using Tsiolkovsky
	if prop_isp_s > 0.0 and dry_mass_kg > 0.0 and delta_v_remaining_ms > 0.0:
		var current_wet_mass: float = dry_mass_kg * exp(delta_v_remaining_ms / (prop_isp_s * 9.80665))
		propellant_remaining_kg = current_wet_mass - dry_mass_kg
	else:
		propellant_remaining_kg = 0.0
	
	# Battery & equipment storage
	battery_capacity_wh = t.get("battery_capacity_wh", t.get("battery_wh", 450.0))
	battery_health_pct = 100.0
	equipment_health_pct = 100.0
	battery_blackout_count = 0
	
	# Data buffer capacity from computer storage (GB to Gbit: 1 GB = 8 Gbit)
	var comp_comp = state.get_component(ComponentDatabase.Category.COMPUTER)
	var storage_gb: float = comp_comp.get("storage_gb", 64.0)
	data_buffer_capacity_gbit = storage_gb * 8.0
	data_buffer_gbit = 0.0
	data_downlinked_total_gbit = 0.0
	data_lost_overflow_gbit = 0.0
	
	# Budget tracking under $180M scenario cap:
	# Phase E Mission Operations is allocated a $15.0M baseline operations grant
	# plus unspent development savings as contingency reserve
	spacecraft_dev_cost_m = t.get("total_cost_m", 112.5)
	launch_cost_m = selected_vehicle.get("launch_cost_m", 48.0)
	ops_cost_total_m = 0.0
	var unspent_dev_savings: float = max(0.0, MissionData.SCENARIO_BUDGET_CAP_M - (spacecraft_dev_cost_m + launch_cost_m))
	operational_budget_remaining_m = 15.0 + unspent_dev_savings
	
	# Base science points
	science_score_total = 0.0
	
	# Initialize crater coverage
	crater_coverage.clear()
	for c_id in MissionOperationsData.get_all_craters():
		crater_coverage[c_id] = 0.0
	hydrogen_candidates_found = 0
	
	# Reset lifecycle
	current_window = 1
	mission_days_elapsed = 0.0
	window_history.clear()
	is_completed = false
	is_terminated = false
	termination_reason = ""

func advance_window(mode_id: String, target_crater_id: String) -> Dictionary:
	if is_terminated or is_completed:
		return get_campaign_summary()
	
	current_mode_id = mode_id
	current_target_crater_id = target_crater_id
	
	var mode: Dictionary = MissionOperationsData.get_mode(mode_id)
	var target_crater: Dictionary = MissionOperationsData.get_crater(target_crater_id)
	var event: Dictionary = MissionOperationsData.get_window_event(current_window)
	var t: Dictionary = state.calculate_telemetry()
	
	var report: Dictionary = {
		"window": current_window,
		"event_name": event["name"],
		"event_condition": event["condition"],
		"mode_name": mode["name"],
		"target_crater_name": target_crater["name"],
		"warnings": []
	}
	
	# --------------------------------------------------------------------------
	# 1. POWER & BATTERY SIMULATION
	# --------------------------------------------------------------------------
	var p_load_w: float = t.get("power_load_w", 175.0) * mode["power_multiplier"]
	var p_gen_w: float = t.get("power_gen_w", 420.0) * max(0.0, 1.0 + (event["power_delta_pct"] / 100.0))
	var net_sunlight_power_w: float = p_gen_w - p_load_w
	
	var orbit_period_min: float = selected_orbit.get("period_min", 118.0)
	var max_eclipse_min: float = selected_orbit.get("max_eclipse_min", 48.0)
	var eclipse_hours: float = max_eclipse_min / 60.0
	
	# Energy drained from battery during each orbital eclipse pass (Wh)
	var eclipse_energy_drain_wh: float = p_load_w * eclipse_hours
	var usable_battery_wh: float = battery_capacity_wh * (battery_health_pct / 100.0)
	
	if usable_battery_wh > 0.0:
		battery_current_dod_pct = (eclipse_energy_drain_wh / usable_battery_wh) * 100.0
	else:
		battery_current_dod_pct = 100.0
	
	# Battery & Equipment Health Degradation / Blackout Checks
	var blackout_this_window: bool = false
	if battery_current_dod_pct >= 100.0 or net_sunlight_power_w < 0.0:
		blackout_this_window = true
		battery_blackout_count += 1
		battery_health_pct = max(0.0, battery_health_pct - 25.0)
		equipment_health_pct = max(0.0, equipment_health_pct - 5.0)
		report["warnings"].append("POWER BLACKOUT: Battery depleted during eclipse shadow! Onboard computer rebooted; uncommitted volatile buffer lost (-5.0% equipment health).")
		data_buffer_gbit = 0.0 # Volatile data wiped in blackout
	elif battery_current_dod_pct > 70.0:
		battery_health_pct = max(0.0, battery_health_pct - 3.5)
		report["warnings"].append("High Depth-of-Discharge (DoD %0.1f%%): Accelerated battery cell chemical degradation (-3.5%% SOH)." % battery_current_dod_pct)
	elif battery_current_dod_pct > 50.0:
		battery_health_pct = max(0.0, battery_health_pct - 1.2)
	else:
		battery_health_pct = max(0.0, battery_health_pct - 0.2)
	
	if battery_health_pct <= 0.0:
		is_terminated = true
		termination_reason = "Mission Terminated: Spacecraft electrical bus failure. Battery storage capacity permanently exhausted due to continuous deep eclipse discharges."
		report["terminated"] = true
		mission_terminated.emit(termination_reason, report)
		return report

	# Subsystem Equipment Aging & Environmental Stress Degradation
	var equip_loss: float = 0.3 # baseline monthly vacuum & radiation aging
	if mode_id == "mode_high_res":
		equip_loss += 0.3 # extra detector and reaction wheel wear
	elif mode_id == "mode_conserve":
		equip_loss = 0.1 # low duty cycling protects instruments
	
	if event.get("effect_type", "") == "radiation":
		equip_loss += 1.5
	elif event.get("effect_type", "") == "micrometeoroid":
		equip_loss += 1.0
	elif event.get("effect_type", "") == "thermal_stress":
		equip_loss += 1.2
	
	equipment_health_pct = max(0.0, equipment_health_pct - equip_loss)
	if equipment_health_pct <= 0.0:
		is_terminated = true
		termination_reason = "Mission Terminated: Spacecraft equipment failure. Critical avionics and payload subsystems suffered catastrophic on-orbit breakdown."
		report["terminated"] = true
		mission_terminated.emit(termination_reason, report)
		return report
	
	report["battery_dod_pct"] = battery_current_dod_pct
	report["battery_health_pct"] = battery_health_pct
	report["equipment_health_pct"] = equipment_health_pct
	report["net_sunlight_power_w"] = net_sunlight_power_w
	
	# --------------------------------------------------------------------------
	# 2. STATIONKEEPING PROPULSION & PROPELLANT DRAIN
	# --------------------------------------------------------------------------
	var req_sk_dv: float = event.get("sk_burn_required_ms", 12.5)
	# Quasi-frozen orbit cuts required stationkeeping by 50%
	if selected_orbit.get("id", "") == "orbit_elliptical_frozen":
		req_sk_dv *= 0.5
	
	if delta_v_remaining_ms < req_sk_dv:
		is_terminated = true
		termination_reason = "Mission Terminated: Propellant depletion. Spacecraft lacked required stationkeeping ΔV (%0.1f m/s required, %0.1f m/s remaining) to counteract lunar mascon perturbations." % [
			req_sk_dv, delta_v_remaining_ms
		]
		report["terminated"] = true
		mission_terminated.emit(termination_reason, report)
		return report
	
	# Expended Delta-V and calculate mass loss via rocket equation
	delta_v_remaining_ms -= req_sk_dv
	var current_total_mass: float = dry_mass_kg + propellant_remaining_kg
	var mass_consumed: float = 0.0
	if prop_isp_s > 0.0 and current_total_mass > 0.0:
		mass_consumed = current_total_mass * (1.0 - exp(-req_sk_dv / (prop_isp_s * 9.80665)))
	propellant_remaining_kg = max(0.0, propellant_remaining_kg - mass_consumed)
	
	report["sk_burn_ms"] = req_sk_dv
	report["propellant_burned_kg"] = mass_consumed
	report["propellant_remaining_kg"] = propellant_remaining_kg
	report["delta_v_remaining_ms"] = delta_v_remaining_ms
	
	# --------------------------------------------------------------------------
	# 3. DATA GENERATION, BUFFER OVERFLOW & DSN DOWNLINK
	# --------------------------------------------------------------------------
	var gen_daily: float = t.get("data_gen_gbit_day", 2.0) * mode["data_multiplier"]
	var win_generated_gbit: float = gen_daily * window_duration_days
	
	var dsn_eff: float = max(0.1, 1.0 + (event["downlink_delta_pct"] / 100.0))
	var dl_daily: float = t.get("downlink_gbit_day", 14.5) * mode["downlink_multiplier"] * dsn_eff
	var win_downlink_capacity_gbit: float = dl_daily * window_duration_days
	
	# Add generated data to solid-state buffer
	var incoming_buffer: float = data_buffer_gbit + win_generated_gbit
	var actual_downlinked_gbit: float = min(incoming_buffer, win_downlink_capacity_gbit)
	var buffer_post_dl: float = incoming_buffer - actual_downlinked_gbit
	
	# Check buffer overflow limit
	var overflow_loss_gbit: float = 0.0
	if buffer_post_dl > data_buffer_capacity_gbit:
		overflow_loss_gbit = buffer_post_dl - data_buffer_capacity_gbit
		data_buffer_gbit = data_buffer_capacity_gbit
		data_lost_overflow_gbit += overflow_loss_gbit
		report["warnings"].append("DATA BUFFER OVERFLOW: %0.1f Gbit of scientific spectra dropped due to solid-state recorder capacity limit (%0.0f Gbit)." % [
			overflow_loss_gbit, data_buffer_capacity_gbit
		])
	else:
		data_buffer_gbit = buffer_post_dl
	
	data_downlinked_total_gbit += actual_downlinked_gbit
	
	report["data_generated_gbit"] = win_generated_gbit
	report["data_downlinked_gbit"] = actual_downlinked_gbit
	report["data_buffer_gbit"] = data_buffer_gbit
	report["data_overflow_loss_gbit"] = overflow_loss_gbit
	
	# --------------------------------------------------------------------------
	# 4. POLAR MAPPING, CRATER COVERAGE & SCIENTIFIC SCORE
	# --------------------------------------------------------------------------
	var orb_sci_mult: float = selected_orbit.get("science_multiplier", 1.0)
	var target_coverage_gain: float = 28.0 * mode["science_multiplier"] * orb_sci_mult
	var bg_coverage_gain: float = 6.0 * mode["science_multiplier"] * orb_sci_mult
	
	# Apply to target crater
	var cur_tgt_cov: float = crater_coverage.get(target_crater_id, 0.0)
	crater_coverage[target_crater_id] = min(100.0, cur_tgt_cov + target_coverage_gain)
	
	# Apply background sweep to other craters
	for c_id in crater_coverage:
		if c_id != target_crater_id:
			var prev_cov: float = crater_coverage[c_id]
			crater_coverage[c_id] = min(100.0, prev_cov + bg_coverage_gain)
	
	# Recalculate confirmed hydrogen candidate proxies (coverage >= 50%)
	hydrogen_candidates_found = 0
	for c_id in crater_coverage:
		if crater_coverage[c_id] >= 50.0:
			hydrogen_candidates_found += 1
	
	# Calculate window science score increment:
	# Downlink fidelity ratio (0.0 to 1.0)
	var downlink_fidelity: float = actual_downlinked_gbit / max(1.0, win_generated_gbit)
	var instrument_base_sci: float = t.get("science_score", 76.0)
	var window_science_gain: float = (instrument_base_sci / 12.0) * downlink_fidelity * mode["science_multiplier"] * orb_sci_mult
	window_science_gain += event.get("science_bonus", 0.0) * 0.5
	
	science_score_total += window_science_gain
	report["science_score_gain"] = window_science_gain
	report["science_score_total"] = science_score_total
	report["target_crater_coverage"] = crater_coverage[target_crater_id]
	report["hydrogen_candidates_found"] = hydrogen_candidates_found
	
	# --------------------------------------------------------------------------
	# 5. OPERATIONAL BUDGET DRAIN
	# --------------------------------------------------------------------------
	var base_monthly_ops_m: float = 1.2
	if mode_id == "mode_high_res" or mode_id == "mode_comm_priority":
		base_monthly_ops_m += 0.35 # Extra DSN ground antenna pass fees
	
	ops_cost_total_m += base_monthly_ops_m
	operational_budget_remaining_m -= base_monthly_ops_m
	report["ops_cost_m"] = base_monthly_ops_m
	report["ops_cost_total_m"] = ops_cost_total_m
	report["budget_remaining_m"] = operational_budget_remaining_m
	report["total_cost_m"] = spacecraft_dev_cost_m + launch_cost_m + ops_cost_total_m
	
	if operational_budget_remaining_m < -5.0:
		is_terminated = true
		termination_reason = "Mission Terminated: Ground operations funding exhausted. Mission Operations Center shut down due to budget insolvency."
		report["terminated"] = true
		mission_terminated.emit(termination_reason, report)
		return report
	
	# --------------------------------------------------------------------------
	# 6. ADVANCE TIMELINE & CHECK COMPLETION
	# --------------------------------------------------------------------------
	mission_days_elapsed += window_duration_days
	window_history.append(report)
	
	window_advanced.emit(current_window, report)
	
	current_window += 1
	if current_window > 12:
		is_completed = true
		var final_report = get_campaign_summary()
		campaign_completed.emit(final_report)
		return final_report
	
	return report

func get_campaign_summary() -> Dictionary:
	var total_cov: float = 0.0
	for c_id in crater_coverage:
		total_cov += crater_coverage[c_id]
	var avg_coverage_pct: float = total_cov / max(1.0, float(crater_coverage.size()))
	
	var is_success: bool = not is_terminated and science_score_total >= MissionData.MIN_SCIENCE_POINTS
	
	var summary: Dictionary = {
		"is_completed": is_completed,
		"is_terminated": is_terminated,
		"termination_reason": termination_reason,
		"is_success": is_success,
		"windows_completed": min(12, current_window - 1),
		"mission_days_elapsed": mission_days_elapsed,
		"final_science_score": science_score_total,
		"target_threshold_score": MissionData.MIN_SCIENCE_POINTS,
		"hydrogen_candidates_found": hydrogen_candidates_found,
		"total_craters_tracked": crater_coverage.size(),
		"avg_polar_coverage_pct": avg_coverage_pct,
		"crater_coverage": crater_coverage.duplicate(),
		"data_downlinked_total_gbit": data_downlinked_total_gbit,
		"data_lost_overflow_gbit": data_lost_overflow_gbit,
		"propellant_remaining_kg": propellant_remaining_kg,
		"delta_v_remaining_ms": delta_v_remaining_ms,
		"battery_health_pct": battery_health_pct,
		"battery_blackout_count": battery_blackout_count,
		"equipment_health_pct": equipment_health_pct,
		"pre_launch_reliability_pct": state.calculate_telemetry().get("system_reliability_pct", 92.0),
		"spacecraft_dev_cost_m": spacecraft_dev_cost_m,
		"launch_cost_m": launch_cost_m,
		"ops_cost_total_m": ops_cost_total_m,
		"total_cost_m": spacecraft_dev_cost_m + launch_cost_m + ops_cost_total_m,
		"budget_cap_m": MissionData.SCENARIO_BUDGET_CAP_M,
		"budget_remaining_m": operational_budget_remaining_m,
		"orbit_name": selected_orbit.get("name", "Low Circular Polar Orbit"),
		"transfer_name": selected_transfer.get("name", "Low-Energy Ballistic Transfer"),
		"vehicle_name": selected_vehicle.get("name", "Medium Commercial EELV-Class"),
		"scientific_proxy_summary": "Hydrogen enhancement detected via epithermal neutron moderation. Scientific proxy for volatile/hydrogenous regolith; does not constitute definitive proof of pure surface water ice."
	}
	
	MissionOperationsData.active_campaign_results = summary
	return summary

func get_telemetry() -> Dictionary:
	var total_cov: float = 0.0
	for c_id in crater_coverage:
		total_cov += crater_coverage[c_id]
	var avg_coverage_pct: float = total_cov / max(1.0, float(crater_coverage.size()))
	
	return {
		"current_window": current_window,
		"mission_days_elapsed": mission_days_elapsed,
		"propellant_remaining_kg": propellant_remaining_kg,
		"delta_v_remaining_ms": delta_v_remaining_ms,
		"battery_health_pct": battery_health_pct,
		"battery_dod_pct": battery_current_dod_pct,
		"equipment_health_pct": equipment_health_pct,
		"data_buffer_gbit": data_buffer_gbit,
		"data_buffer_capacity_gbit": data_buffer_capacity_gbit,
		"data_downlinked_total_gbit": data_downlinked_total_gbit,
		"data_lost_overflow_gbit": data_lost_overflow_gbit,
		"ops_cost_total_m": ops_cost_total_m,
		"total_cost_m": spacecraft_dev_cost_m + launch_cost_m + ops_cost_total_m,
		"budget_remaining_m": operational_budget_remaining_m,
		"science_score_total": science_score_total,
		"hydrogen_candidates_found": hydrogen_candidates_found,
		"avg_polar_coverage_pct": avg_coverage_pct,
		"is_completed": is_completed,
		"is_terminated": is_terminated,
		"termination_reason": termination_reason
	}
