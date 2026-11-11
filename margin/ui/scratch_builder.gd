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
			{"label": "Active Louvers + MLI (nominal)", "apply": {"thermal_type": "thermal_active_louvers_mli", "thermal_power_w": 25.0, "thermal_mass_kg": 18.0, "thermal_cost_m": 4.5}},
			{"label": "Heavy Shield (CME hardened)", "apply": {"thermal_type": "thermal_heavy_shield", "thermal_power_w": 40.0, "thermal_mass_kg": 42.0, "thermal_cost_m": 9.0}},
			{"label": "Passive MLI (light)", "apply": {"thermal_type": "thermal_passive_mli", "thermal_power_w": 10.0, "thermal_mass_kg": 12.0, "thermal_cost_m": 3.0}}
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

var current_step: int = 0
var _step_label: Label = null
var _desc_label: Label = null
var _options_box: VBoxContainer = null
var _progress_label: Label = null
var _completed: Dictionary = {}


func _ready() -> void:
	theme = MarginTheme.get_theme()
	_build()
	_show_step(0)


func _build() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.09, 0.15, 0.94)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.22, 0.34, 0.48)
	sb.set_content_margin_all(10)
	add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)

	var head := Label.new()
	head.text = "SCRATCH BUILD"
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", Color(0.85, 0.93, 1.0))
	vb.add_child(head)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 10)
	_progress_label.add_theme_color_override("font_color", Color(0.62, 0.74, 0.86))
	vb.add_child(_progress_label)

	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", 12)
	_step_label.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
	vb.add_child(_step_label)

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 10)
	_desc_label.add_theme_color_override("font_color", Color(0.66, 0.76, 0.86))
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_desc_label)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 4)
	vb.add_child(_options_box)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 6)
	vb.add_child(nav)

	var prev := Button.new()
	prev.name = "ScratchPrevBtn"
	prev.text = "◀ BACK"
	prev.add_theme_font_size_override("font_size", 11)
	prev.focus_mode = Control.FOCUS_NONE
	prev.pressed.connect(_on_prev)
	nav.add_child(prev)

	var next := Button.new()
	next.name = "ScratchNextBtn"
	next.text = "NEXT ▶"
	next.add_theme_font_size_override("font_size", 11)
	next.focus_mode = Control.FOCUS_NONE
	next.pressed.connect(_on_next)
	nav.add_child(next)

	var auto := Button.new()
	auto.name = "AutoBuildPresetBtn"
	auto.text = "AUTO-BUILD NASA PRESET"
	auto.add_theme_font_size_override("font_size", 11)
	auto.focus_mode = Control.FOCUS_NONE
	auto.pressed.connect(_on_auto_build)
	vb.add_child(auto)


func _show_step(idx: int) -> void:
	current_step = clampi(idx, 0, STEPS.size() - 1)
	var step: Dictionary = STEPS[current_step]
	_step_label.text = "STEP %d / %d — %s" % [current_step + 1, STEPS.size(), step["title"]]
	_desc_label.text = str(step["desc"])

	var done: int = _completed.size()
	_progress_label.text = "%d / %d steps configured" % [done, STEPS.size()]

	for c in _options_box.get_children():
		c.queue_free()

	for opt in step["options"]:
		var btn := Button.new()
		btn.text = str(opt["label"])
		btn.add_theme_font_size_override("font_size", 10)
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var payload: Dictionary = opt["apply"]
		var step_id: String = str(step["id"])
		btn.pressed.connect(func() -> void: _apply_option(step_id, payload))
		_options_box.add_child(btn)


func _apply_option(step_id: String, payload: Dictionary) -> void:
	if Helios4CampaignData.probe_config.is_empty():
		Helios4CampaignData.probe_config = Helios4CampaignData.get_default_probe_config()
	for k in payload:
		Helios4CampaignData.probe_config[k] = payload[k]
	_completed[step_id] = true
	Sfx.part_attach()
	_progress_label.text = "%d / %d steps configured" % [_completed.size(), STEPS.size()]
	build_changed.emit()
	# Auto-advance so the player is always pushed to the next step
	if current_step < STEPS.size() - 1:
		_show_step(current_step + 1)


func _on_prev() -> void:
	Sfx.ui_back()
	_show_step(current_step - 1)


func _on_next() -> void:
	Sfx.ui_click()
	_show_step(current_step + 1)


func _on_auto_build() -> void:
	var dest: String = Helios4CampaignData.get_destination()
	Helios4CampaignData.probe_config = Helios4CampaignData.get_default_probe_config()

	# Destination-aware preset: the NASA reference build that satisfies the gates.
	match dest:
		"mars_orbiter":
			Helios4CampaignData.probe_config["solar_array_area_m2"] = 10.0
			Helios4CampaignData.probe_config["battery_capacity_wh"] = 1600.0
			Helios4CampaignData.probe_config["propellant_mass_kg"] = 380.0
			Helios4CampaignData.probe_config["probe_isp_s"] = 420.0
			Helios4CampaignData.probe_config["antenna_diameter_m"] = 2.0
			Helios4CampaignData.probe_config["thermal_type"] = "thermal_heavy_shield"
			Helios4CampaignData.probe_config["thermal_power_w"] = 40.0
			Helios4CampaignData.probe_config["thermal_mass_kg"] = 42.0
		"lunar_south_pole":
			Helios4CampaignData.probe_config["battery_capacity_wh"] = 1600.0
			Helios4CampaignData.probe_config["solar_array_area_m2"] = 6.5
			Helios4CampaignData.probe_config["instruments"] = {
				"radar": {"id": "inst_sar_radar", "name": "Synthetic Aperture Radar", "heritage": "NASA LRO Mini-RF", "mass_kg": 16.0, "power_w": 22.0, "science_score": 20.0, "cost_m": 11.0, "data_rate_kbps": 10.0},
				"spectrometer": {"id": "inst_neutron_spectrometer", "name": "Neutron Spectrometer", "heritage": "NASA Lunar Prospector LP-NS", "mass_kg": 11.0, "power_w": 14.0, "science_score": 17.0, "cost_m": 8.0, "data_rate_kbps": 5.0}
			}
		_:
			# Sun-Earth L1 default suite already ships Mag + Faraday + SEP
			Helios4CampaignData.probe_config["solar_array_area_m2"] = 6.5
			Helios4CampaignData.probe_config["battery_capacity_wh"] = 1200.0

	for s in STEPS:
		_completed[str(s["id"])] = true
	Sfx.success_chime()
	_progress_label.text = "%d / %d steps configured" % [_completed.size(), STEPS.size()]
	build_changed.emit()
	_show_step(STEPS.size() - 1)
