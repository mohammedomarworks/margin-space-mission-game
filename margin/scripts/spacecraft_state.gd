class_name SpacecraftState
extends RefCounted

const MissionScenario = preload("res://margin/data/mission_scenario.gd")

signal configuration_changed(category: ComponentDatabase.Category, old_comp: Dictionary, new_comp: Dictionary)
signal telemetry_updated(telemetry: Dictionary)

static var active_instance: SpacecraftState = null

var current_components: Dictionary = {} # Category (enum) -> component_id (String)

func _init() -> void:
	active_instance = self
	reset_to_default()

func reset_to_default() -> void:
	current_components = ComponentDatabase.get_default_configuration().duplicate()
	recalculate_and_emit()

func set_component(category: ComponentDatabase.Category, component_id: String) -> void:
	var old_id: String = current_components.get(category, "")
	if old_id == component_id:
		return
	
	var old_comp: Dictionary = ComponentDatabase.get_component(old_id)
	var new_comp: Dictionary = ComponentDatabase.get_component(component_id)
	
	current_components[category] = component_id
	
	configuration_changed.emit(category, old_comp, new_comp)
	recalculate_and_emit()

func get_component_id(category: ComponentDatabase.Category) -> String:
	return current_components.get(category, "")

func get_component(category: ComponentDatabase.Category) -> Dictionary:
	var id: String = get_component_id(category)
	return ComponentDatabase.get_component(id)

func save_to_file(file_path: String = "user://sandbox_spacecraft.json") -> bool:
	var save_data = {
		"components": {},
		"saved_at": Time.get_datetime_string_from_system()
	}
	for cat in current_components:
		save_data["components"][str(cat)] = current_components[cat]
		
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	return true

func load_from_file(file_path: String = "user://sandbox_spacecraft.json") -> bool:
	if not FileAccess.file_exists(file_path):
		return false
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return false
	var text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(text) != OK:
		return false
	var data = json.get_data()
	if not data is Dictionary or not data.has("components"):
		return false
		
	var comps: Dictionary = data["components"]
	for cat_str in comps:
		var cat_int = int(cat_str)
		current_components[cat_int] = comps[cat_str]
		
	recalculate_and_emit()
	return true

func calculate_telemetry() -> Dictionary:
	var dry_mass: float = 0.0
	var wet_mass: float = 0.0
	var total_cost: float = 0.0
	var power_gen_w: float = 0.0
	var power_load_w: float = 0.0
	var battery_wh: float = 450.0
	var data_gen_gbit_day: float = 0.0
	var downlink_gbit_day: float = 2.0
	var link_margin_db: float = 3.0
	var delta_v_ms: float = 0.0
	var prop_isp: float = 0.0
	var propellant_mass: float = 0.0
	var hardware_mass: float = 0.0
	var science_score: float = 0.0
	var reliability_accum: float = 1.0
	var pointing_deg: float = 0.1
	
	for cat in current_components:
		var comp_id: String = current_components[cat]
		var comp: Dictionary = ComponentDatabase.get_component(comp_id)
		if comp.is_empty():
			continue
		
		# Mass breakdown
		var m: float = comp.get("mass_kg", 0.0)
		hardware_mass += m
		if comp.has("propellant_mass_kg"):
			propellant_mass += comp.get("propellant_mass_kg", 0.0)
		if comp.has("isp_s"):
			prop_isp = comp.get("isp_s", 0.0)
		
		# Cost
		total_cost += comp.get("cost_m", 0.0)
		
		# Power
		var p: float = comp.get("power_w", 0.0)
		if p > 0.0:
			power_gen_w += p
		else:
			power_load_w += abs(p)
		
		# Battery
		if comp.has("storage_wh"):
			battery_wh = comp.get("storage_wh", 450.0)
		
		# Data & Comms
		if cat == ComponentDatabase.Category.INSTRUMENTS:
			data_gen_gbit_day += comp.get("data_rate_gbit_day", 0.0)
		elif cat == ComponentDatabase.Category.COMMUNICATIONS:
			downlink_gbit_day = comp.get("data_rate_gbit_day", 2.0)
			link_margin_db = comp.get("link_margin_db", 3.0)
		
		# Fallback delta-v if specified statically
		if comp.has("delta_v_ms"):
			delta_v_ms = comp.get("delta_v_ms", 0.0)
		
		# Pointing
		if comp.has("pointing_accuracy_deg"):
			pointing_deg = comp.get("pointing_accuracy_deg", 0.1)
		
		# Science score
		science_score += comp.get("science_score", 0.0)
		
		# Reliability
		var rel_pct: float = comp.get("reliability_pct", 95.0)
		reliability_accum *= (rel_pct / 100.0)
	
	# Internal consistency: dry mass vs propellant mass
	# Base electrical harness mass (5% of dry hardware)
	var dry_hardware_mass: float = max(0.0, hardware_mass - propellant_mass)
	var harness_mass: float = dry_hardware_mass * 0.05
	dry_mass = dry_hardware_mass + harness_mass
	wet_mass = dry_mass + propellant_mass
	
	# Deterministic Delta-V via Tsiolkovsky Rocket Equation:
	# ΔV = Isp * g0 * ln(m_wet / m_dry)
	if propellant_mass > 0.0 and prop_isp > 0.0 and dry_mass > 0.0:
		delta_v_ms = prop_isp * 9.80665 * log(wet_mass / dry_mass)
	
	# Fixed mission integration, testing and launch ops ($18.0M base)
	total_cost += 18.0
	
	# Base housekeeping telemetry: 0.2 Gbit/day
	data_gen_gbit_day += 0.2
	
	# Packed / Stowed Spacecraft Geometry (for fairing envelope validation)
	var stowed_diam: float = 1.05
	var stowed_h: float = 1.15
	var stowed_vol: float = 0.95
	var struct_comp = ComponentDatabase.get_component(current_components.get(ComponentDatabase.Category.STRUCTURE, ""))
	if not struct_comp.is_empty():
		stowed_diam = struct_comp.get("stowed_diameter_m", 1.05)
		stowed_h = struct_comp.get("stowed_height_m", 1.15)
		stowed_vol = struct_comp.get("stowed_vol_m3", 0.95)
	
	for cat in current_components:
		if cat == ComponentDatabase.Category.STRUCTURE:
			continue
		var c_id: String = current_components[cat]
		var comp_data: Dictionary = ComponentDatabase.get_component(c_id)
		if comp_data.is_empty():
			continue
		stowed_diam += comp_data.get("stowed_diameter_delta_m", 0.0)
		stowed_h += comp_data.get("stowed_height_delta_m", 0.0)
		stowed_vol += comp_data.get("stowed_vol_m3", 0.0)
	
	# Net power in sunlight
	var net_sunlight_power_w: float = power_gen_w - power_load_w
	
	# Orbital eclipse calculation: maximum duration spacecraft spends in the Moon's shadow cone (up to 48 min)
	var scenario = MissionScenario.get_active_scenario()
	var budget_cap_m: float = scenario.budget_cap_m
	var mass_limit_kg: float = scenario.mass_limit_kg
	var min_sci_points: float = scenario.min_science_points
	var scenario_req_dv_ms: float = scenario.required_delta_v_ms
	var scenario_max_eclipse_min: float = scenario.max_eclipse_min

	var eclipse_energy_required_wh: float = power_load_w * (scenario_max_eclipse_min / 60.0)
	var eclipse_dod_pct: float = (eclipse_energy_required_wh / max(battery_wh, 1.0)) * 100.0
	var eclipse_battery_margin_pct: float = ((0.70 * battery_wh) - eclipse_energy_required_wh) / (0.70 * battery_wh) * 100.0
	
	# Delta-V and mission maneuvers calculation:
	var delta_v_reserve_ms: float = delta_v_ms - scenario_req_dv_ms
	var delta_v_margin_pct: float = (delta_v_reserve_ms / max(1.0, scenario_req_dv_ms)) * 100.0
	
	# Remaining ΔV available for stationkeeping:
	var remaining_sk_dv: float = max(0.0, delta_v_ms - (scenario.ref_mcc_delta_v_ms + scenario.ref_loi_delta_v_ms))
	var achievable_lifetime_days: float = (remaining_sk_dv / max(1.0, scenario.ref_stationkeeping_delta_v_ms)) * float(scenario.duration_days)
	var lifetime_margin_pct: float = ((achievable_lifetime_days - float(scenario.duration_days)) / float(scenario.duration_days)) * 100.0
	var lifetime_qualified: bool = delta_v_ms >= scenario_req_dv_ms
	
	# Six Resource Margins:
	# 1. Mass Margin
	var mass_margin_pct: float = ((mass_limit_kg - wet_mass) / mass_limit_kg) * 100.0
	
	# 2. Power Margin (Sunlight surplus)
	var power_margin_pct: float = ((power_gen_w - power_load_w) / max(power_load_w, 1.0)) * 100.0
	
	# 3. Budget Margin
	var budget_margin_pct: float = ((budget_cap_m - total_cost) / budget_cap_m) * 100.0
	
	# 4. Data Margin (Downlink headroom)
	var data_margin_pct: float = ((downlink_gbit_day - data_gen_gbit_day) / max(downlink_gbit_day, 0.1)) * 100.0
	
	# 5. Comms Link Margin: dB above minimum link closure (3.0 dB threshold)
	var comms_effective_margin_db: float = link_margin_db - 3.0
	
	# System Reliability %
	var system_reliability_pct: float = reliability_accum * 100.0
	
	# Qualification checks
	var mass_qualified: bool = wet_mass <= mass_limit_kg
	var budget_qualified: bool = total_cost <= budget_cap_m
	var power_qualified: bool = net_sunlight_power_w >= 0.0 and eclipse_dod_pct <= 70.0
	var data_qualified: bool = downlink_gbit_day >= data_gen_gbit_day
	var comms_qualified: bool = link_margin_db >= 3.0
	var science_qualified: bool = science_score >= min_sci_points
	
	var all_qualified: bool = (mass_qualified and budget_qualified and power_qualified 
		and data_qualified and comms_qualified and lifetime_qualified and science_qualified)
	
	var deficits: Array[String] = []
	if not mass_qualified:
		deficits.append("Mass exceeds launcher limit (%0.1f kg > %0.1f kg)" % [wet_mass, mass_limit_kg])
	if not budget_qualified:
		deficits.append("Budget exceeds cap ($%0.1fM > $%0.1fM)" % [total_cost, budget_cap_m])
	if not power_qualified:
		if net_sunlight_power_w < 0.0:
			deficits.append("Power deficit in sunlight (%0.1f W deficit)" % [abs(net_sunlight_power_w)])
		if eclipse_dod_pct > 70.0:
			deficits.append("Battery Depth of Discharge exceeds 70%% limit during orbital eclipse (%0.1f%% DoD)" % [eclipse_dod_pct])
	if not data_qualified:
		deficits.append("Downlink bottleneck: %0.1f Gbit/day generated vs %0.1f Gbit/day bandwidth" % [data_gen_gbit_day, downlink_gbit_day])
	if not comms_qualified:
		deficits.append("Link margin below 3.0 dB closure threshold (%0.1f dB)" % [link_margin_db])
	if not lifetime_qualified:
		deficits.append("Insufficient onboard ΔV for mission maneuvers (%0.0f m/s < %0.0f m/s baseline: %0.0f m/s MCC + %0.1f m/s LOI + %0.0f m/s stationkeeping)" % [delta_v_ms, scenario_req_dv_ms, scenario.ref_mcc_delta_v_ms, scenario.ref_loi_delta_v_ms, scenario.ref_stationkeeping_delta_v_ms])
	if not science_qualified:
		deficits.append("Science score below minimum mission criteria (%0.1f < %0.1f pts)" % [science_score, min_sci_points])
	
	return {
		"wet_mass_kg": wet_mass,
		"dry_mass_kg": dry_mass,
		"propellant_mass_kg": propellant_mass,
		"mass_margin_pct": mass_margin_pct,
		"mass_qualified": mass_qualified,
		
		"stowed_diameter_m": stowed_diam,
		"stowed_height_m": stowed_h,
		"stowed_volume_m3": stowed_vol,
		
		"total_cost_m": total_cost,
		"budget_margin_pct": budget_margin_pct,
		"budget_qualified": budget_qualified,
		
		"power_gen_w": power_gen_w,
		"power_load_w": power_load_w,
		"net_power_w": net_sunlight_power_w,
		"power_margin_pct": power_margin_pct,
		"battery_capacity_wh": battery_wh,
		"eclipse_dod_pct": eclipse_dod_pct,
		"eclipse_margin_pct": eclipse_battery_margin_pct,
		"power_qualified": power_qualified,
		
		"data_gen_gbit_day": data_gen_gbit_day,
		"downlink_gbit_day": downlink_gbit_day,
		"data_margin_pct": data_margin_pct,
		"data_qualified": data_qualified,
		
		"link_margin_db": link_margin_db,
		"comms_effective_margin_db": comms_effective_margin_db,
		"comms_qualified": comms_qualified,
		
		"delta_v_ms": delta_v_ms,
		"delta_v_reserve_ms": delta_v_reserve_ms,
		"delta_v_margin_pct": delta_v_margin_pct,
		"mcc_req_ms": MissionData.REF_MCC_DELTA_V_MS,
		"loi_req_ms": MissionData.REF_LOI_DELTA_V_MS,
		"sk_req_ms": MissionData.REF_STATIONKEEPING_DELTA_V_MS,
		"achievable_lifetime_days": achievable_lifetime_days,
		"lifetime_margin_pct": lifetime_margin_pct,
		"lifetime_qualified": lifetime_qualified,
		
		"science_score": science_score,
		"science_qualified": science_qualified,
		"system_reliability_pct": system_reliability_pct,
		"pointing_deg": pointing_deg,
		
		"all_qualified": all_qualified,
		"deficits": deficits
	}

func recalculate_and_emit() -> void:
	var t: Dictionary = calculate_telemetry()
	telemetry_updated.emit(t)
