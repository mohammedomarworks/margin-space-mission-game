class_name ScratchBuilder
extends PanelContainer

# ==============================================================================
# MARGIN — SCRATCH-BUILD STEPPER
# Five-step guided spacecraft assembly for the Hangar:
#   Step 1 Core Bus -> Step 2 Propulsion -> Step 3 Solar & Battery
#   -> Step 4 Thermal Shield -> Step 5 Science Payload
# Each step offers concrete hardware choices that write straight into
# Helios4CampaignData.probe_config / vehicle_config, so the 3D model, telemetry
# and destination checklist all update live. AUTO-BUILD NASA PRESET applies a
# known-good configuration for the selected destination.
# ==============================================================================

signal build_changed

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")

const STEPS: Array = [
	{
		"id": "bus",
		"title": "1. CORE BUS",
		"desc": "Structural frame and avionics core.",
		"options": [
			{"label": "Carbon Composite (light)", "apply": {"bus_structure": "struct_carbon_composite", "structure_mass_kg": 180.0, "structure_cost_m": 14.0}},
			{"label": "Aluminium Honeycomb (cheap)", "apply": {"bus_structure": "struct_al_honeycomb", "structure_mass_kg": 240.0, "structure_cost_m": 9.0}},
			{"label": "Rad-Hard Titanium (tough)", "apply": {"bus_structure": "struct_titanium_rad", "structure_mass_kg": 300.0, "structure_cost_m": 20.0}}
		]
	},
	{
		"id": "propulsion",
		"title": "2. PROPULSION ENGINE",
		"desc": "Probe engine and propellant load.",
		"options": [
			{"label": "Dual-Mode Bipropellant (balanced)", "apply": {"propulsion_type": "prop_dual_mode_biprop", "propellant_mass_kg": 320.0, "probe_isp_s": 315.0, "propulsion_cost_m": 12.0}},
			{"label": "High-Isp Ion (max delta-V)", "apply": {"propulsion_type": "prop_ion_high_isp", "propellant_mass_kg": 380.0, "probe_isp_s": 420.0, "propulsion_cost_m": 18.0}},
			{"label": "Monoprop Hydrazine (light)", "apply": {"propulsion_type": "prop_mono_hydrazine", "propellant_mass_kg": 220.0, "probe_isp_s": 285.0, "propulsion_cost_m": 8.0}}
		]
	},
	{
		"id": "power",
		"title": "3. SOLAR & BATTERY",
		"desc": "Array area and battery reserve.",
		"options": [
			{"label": "Tri-Junction 6.5 m2 + 1200 Wh", "apply": {"solar_array_type": "power_tri_junction_wings", "solar_array_area_m2": 6.5, "solar_efficiency": 0.31, "battery_type": "batt_li_ion_rad_hard", "battery_capacity_wh": 1200.0}},
			{"label": "Large Array 10 m2 + 1600 Wh", "apply": {"solar_array_type": "power_tri_junction_wings", "solar_array_area_m2": 10.0, "solar_efficiency": 0.31, "battery_type": "batt_li_ion_rad_hard", "battery_capacity_wh": 1600.0}},
			{"label": "Compact 3.5 m2 + 1500 Wh", "apply": {"solar_array_type": "power_tri_junction_wings", "solar_array_area_m2": 3.5, "solar_efficiency": 0.31, "battery_type": "batt_li_ion_rad_hard", "battery_capacity_wh": 1500.0}}
		]
	},
	{
		"id": "thermal",
		"title": "4. THERMAL SHIELD",
		"desc": "Heat rejection and radiation shielding.",
		"options": [
			{"label": "Active Louvers + MLI (nominal)", "apply": {"thermal_type": "thermal_active_louvers_mli", "thermal_power_w": 25.0, "thermal_mass_kg": 18.0, "thermal_emissivity": 0.82, "thermal_absorptivity": 0.23, "thermal_radiator_area_m2": 1.8, "thermal_max_temp_k": 360.0, "thermal_cost_m": 4.5}},
			{"label": "Heavy Shield (CME hardened)", "apply": {"thermal_type": "thermal_heavy_shield", "thermal_power_w": 40.0, "thermal_mass_kg": 42.0, "thermal_emissivity": 0.78, "thermal_absorptivity": 0.15, "thermal_radiator_area_m2": 2.2, "thermal_max_temp_k": 415.0, "thermal_cost_m": 9.0}},
			{"label": "Passive MLI (light)", "apply": {"thermal_type": "thermal_passive_mli", "thermal_power_w": 10.0, "thermal_mass_kg": 12.0, "thermal_emissivity": 0.55, "thermal_absorptivity": 0.34, "thermal_radiator_area_m2": 1.6, "thermal_max_temp_k": 335.0, "thermal_cost_m": 3.0}}
		]
	},
	{
		"id": "science",
		"title": "5. SCIENCE PAYLOAD",
		"desc": "Instruments determine science score and mission fit.",
		"options": [
			{"label": "Solar Wind Suite (Mag + Faraday)", "apply": {"instruments": {
				"faraday_cup": {"id": "inst_faraday_cup", "name": "Faraday Cup Solar Wind Plasma Analyzer", "heritage": "NASA DSCOVR PlasMag & SOHO CELIAS", "mass_kg": 14.0, "power_w": 18.0, "science_score": 18.0, "cost_m": 9.0, "data_rate_kbps": 8.0},
				"magnetometer": {"id": "inst_fluxgate_mag", "name": "Triaxial Fluxgate Magnetometer & 4m Deployable Boom", "heritage": "NASA DSCOVR Magnetometer", "mass_kg": 12.0, "power_w": 12.0, "science_score": 16.0, "cost_m": 8.0, "data_rate_kbps": 6.0},
				"radiation_monitor": {"id": "inst_solar_particle_rad", "name": "Solar Energetic Particle (SEP) Spectrometer", "heritage": "NOAA GOES EPS", "mass_kg": 9.0, "power_w": 15.0, "science_score": 12.0, "cost_m": 6.0, "data_rate_kbps": 4.0}
			}}},
			{"label": "Lunar Radar Suite (Radar + Spectrometer)", "apply": {"instruments": {
				"radar": {"id": "inst_sar_radar", "name": "Synthetic Aperture Radar", "heritage": "NASA LRO Mini-RF", "mass_kg": 16.0, "power_w": 22.0, "science_score": 20.0, "cost_m": 11.0, "data_rate_kbps": 10.0},
				"spectrometer": {"id": "inst_neutron_spectrometer", "name": "Neutron Spectrometer", "heritage": "NASA Lunar Prospector LP-NS", "mass_kg": 11.0, "power_w": 14.0, "science_score": 17.0, "cost_m": 8.0, "data_rate_kbps": 5.0}
			}}},
			{"label": "Deep Space Survey (Full Suite)", "apply": {"instruments": {
				"faraday_cup": {"id": "inst_faraday_cup", "name": "Faraday Cup Solar Wind Plasma Analyzer", "heritage": "NASA DSCOVR PlasMag", "mass_kg": 14.0, "power_w": 18.0, "science_score": 18.0, "cost_m": 9.0, "data_rate_kbps": 8.0},
				"magnetometer": {"id": "inst_fluxgate_mag", "name": "Triaxial Fluxgate Magnetometer", "heritage": "NASA DSCOVR Magnetometer", "mass_kg": 12.0, "power_w": 12.0, "science_score": 16.0, "cost_m": 8.0, "data_rate_kbps": 6.0},
				"radar": {"id": "inst_sar_radar", "name": "Synthetic Aperture Radar", "heritage": "NASA LRO Mini-RF", "mass_kg": 16.0, "power_w": 22.0, "science_score": 20.0, "cost_m": 11.0, "data_rate_kbps": 10.0}
			}}}
		]
	}
]

var _slot_selectors: Dictionary = {}
var _equations_label: Label = null
var last_changed_slot_id: String = ""


func _ready() -> void:
	theme = MarginTheme.get_theme()
	_build()
	refresh_from_config()


func _build() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.09, 0.15, 0.94)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.22, 0.34, 0.48)
	sb.set_content_margin_all(10)
	add_theme_stylebox_override("panel", sb)

	var scroll := ScrollContainer.new()
	scroll.name = "WorkbenchScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.add_theme_constant_override("margin_right", 4)
	add_child(scroll)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 7)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)

	var head := Label.new()
	head.text = "SPACECRAFT ASSEMBLY WORKBENCH"
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", Color(0.85, 0.93, 1.0))
	vb.add_child(head)

	var intro := Label.new()
	intro.text = "Select a module in each station. The spacecraft and flight math update live."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 10)
	intro.add_theme_color_override("font_color", Color(0.65, 0.78, 0.90))
	vb.add_child(intro)

	for i in STEPS.size():
		var step: Dictionary = STEPS[i]
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", 3)
		var slot_title := Label.new()
		slot_title.text = step["title"]
		slot_title.add_theme_font_size_override("font_size", 10)
		slot_title.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
		slot.add_child(slot_title)
		var selector := OptionButton.new()
		selector.name = "AssemblySlot_" + str(step["id"])
		selector.custom_minimum_size = Vector2(0.0, 30.0)
		selector.add_theme_font_size_override("font_size", 9)
		selector.focus_mode = Control.FOCUS_NONE
		for opt in step["options"]:
			selector.add_item(str(opt["label"]))
		var step_index: int = i
		selector.item_selected.connect(func(option_index: int) -> void:
			_apply_option(step_index, option_index)
		)
		slot.add_child(selector)
		vb.add_child(slot)
		_slot_selectors[str(step["id"])] = selector

	var eq_panel := PanelContainer.new()
	eq_panel.name = "LiveEquationsPanel"
	var eq_style := StyleBoxFlat.new()
	eq_style.bg_color = Color(0.025, 0.055, 0.095, 0.98)
	eq_style.border_color = Color(0.20, 0.62, 0.82, 0.85)
	eq_style.set_border_width_all(1)
	eq_style.set_corner_radius_all(5)
	eq_style.set_content_margin_all(8)
	eq_panel.add_theme_stylebox_override("panel", eq_style)
	var eq_box := VBoxContainer.new()
	eq_box.add_theme_constant_override("separation", 4)
	eq_panel.add_child(eq_box)
	var eq_title := Label.new()
	eq_title.text = "LIVE FLIGHT EQUATIONS"
	eq_title.add_theme_font_size_override("font_size", 11)
	eq_title.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
	eq_box.add_child(eq_title)
	_equations_label = Label.new()
	_equations_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_equations_label.add_theme_font_size_override("font_size", 9)
	_equations_label.add_theme_color_override("font_color", Color(0.87, 0.92, 0.98))
	eq_box.add_child(_equations_label)
	vb.add_child(eq_panel)

	var rad_note := Label.new()
	rad_note.text = "CME proton survival needs rad-hard avionics;\nthermal shields alone do not block particles."
	rad_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rad_note.add_theme_font_size_override("font_size", 8)
	rad_note.add_theme_color_override("font_color", Color(0.98, 0.72, 0.42))
	vb.add_child(rad_note)

func _apply_option(step_index: int, option_index: int) -> void:
	var step: Dictionary = STEPS[step_index]
	var opt: Dictionary = step["options"][option_index]
	var step_id: String = str(step["id"])
	var payload: Dictionary = opt["apply"]
	last_changed_slot_id = step_id
	if Helios4CampaignData.probe_config.is_empty():
		Helios4CampaignData.probe_config = Helios4CampaignData.get_default_probe_config()
	for k in payload:
		Helios4CampaignData.probe_config[k] = payload[k]
	Sfx.part_attach()
	_refresh_equations()
	build_changed.emit()

func refresh_from_config() -> void:
	if Helios4CampaignData.probe_config.is_empty():
		Helios4CampaignData.probe_config = Helios4CampaignData.get_default_probe_config()
	for step in STEPS:
		var step_id: String = str(step["id"])
		var selector: OptionButton = _slot_selectors.get(step_id, null)
		if selector == null:
			continue
		var selected_index: int = _find_matching_option(step, Helios4CampaignData.probe_config)
		selector.set_block_signals(true)
		selector.select(selected_index)
		selector.set_block_signals(false)
	_refresh_equations()

func _find_matching_option(step: Dictionary, config: Dictionary) -> int:
	for i in step["options"].size():
		var payload: Dictionary = step["options"][i]["apply"]
		var matches: bool = true
		for key in payload:
			if not config.has(key) or config[key] != payload[key]:
				matches = false
				break
		if matches:
			return i
	return 0

func _refresh_equations() -> void:
	if _equations_label == null:
		return
	var tel: Dictionary = Helios4CampaignData.calculate_hangar_telemetry()
	var dest_id: String = Helios4CampaignData.get_destination()
	var req: Dictionary = DestinationData.get_requirements(dest_id)
	var meta: Dictionary = DestinationData.get_metadata(dest_id)
	var probe_dv: float = tel.get("delta_v_probe", 0.0)
	var launch_dv: float = tel.get("total_launch_delta_v", 0.0)
	var power_net: float = tel.get("power_margin_w", 0.0)
	var thermal: float = tel.get("thermal_flux_tolerance_w_m2", 0.0)
	_equations_label.text = "Δv = Isp · g0 · ln(mwet / mdry)\nWet mass: %.0f kg | Probe: %.0f / %.0f m/s\nLaunch: %.0f / %.0f m/s | Cost: $%.1fM / $%.1fM\n\nTWR = Fthrust / (mwet · 9.81) = %.2f | target > 1.20\n\nPnet = Pgen - Pload = %.0f W - %.0f W = %+.0f W\nPgen = A·η·1361·(1 AU / %.2f AU)^2·0.96\nPload = Pav + Padcs + Pthermal + Pcomm + Pscience\nArray flux at target: %.0f W/m^2\n\nThermal limit: εσTmax^4/α = %.0f W/m^2 at %.0f K\nMission minimum: %.0f W/m^2" % [
		tel.get("liftoff_wet_mass_kg", 0.0),
		probe_dv, req.get("min_probe_delta_v_ms", tel.get("req_probe_dv", 0.0)),
		launch_dv, tel.get("req_launch_dv", 0.0), tel.get("total_cost_m", 0.0), tel.get("budget_cap_m", 0.0),
		tel.get("liftoff_twr", 0.0),
		power_net + tel.get("total_power_load_w", 0.0), tel.get("total_power_load_w", 0.0), power_net,
		meta.get("solar_distance_au", 1.0),
		tel.get("solar_flux_w_m2", 1361.0),
		thermal, tel.get("thermal_max_temp_k", 360.0),
		req.get("min_thermal_flux_tolerance_w_m2", 0.0)
	]
