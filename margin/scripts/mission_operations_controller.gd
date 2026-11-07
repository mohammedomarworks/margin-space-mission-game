class_name MissionOperationsController
extends Node3D

const MissionSimulator = preload("res://margin/scripts/mission_simulator.gd")
const MissionOperationsData = preload("res://margin/data/mission_operations_data.gd")
const SpacecraftState = preload("res://margin/scripts/spacecraft_state.gd")
const ComponentDatabase = preload("res://margin/data/component_data.gd")
const MarginTheme = preload("res://margin/ui/margin_theme.gd")
const MissionScenario = preload("res://margin/data/mission_scenario.gd")
const TeamData = preload("res://margin/data/team_data.gd")

# ==============================================================================
# MARGIN: MISSION OPERATIONS CONTROLLER (MILESTONE 3)
# Interactive 3D Lunar Orbital Operations & Resource Management System
# ==============================================================================

# 3D Node References
@onready var moon_mesh: MeshInstance3D = %MoonMesh
@onready var orbit_path_mesh: MeshInstance3D = %OrbitPathMesh
@onready var spacecraft_pivot: Node3D = %SpacecraftPivot
@onready var spacecraft_mesh: Node3D = %SpacecraftMesh
@onready var scan_beam: MeshInstance3D = %ScanBeam
@onready var ground_track_marker: MeshInstance3D = %GroundTrackMarker
@onready var crater_markers_node: Node3D = %CraterMarkers
@onready var orbit_cam: Node3D = %OrbitCamera

# UI References - Top Bar
@onready var top_timeline_label: Label = %TopTimelineLabel
@onready var top_timeline_bar: ProgressBar = %TopTimelineBar
@onready var top_prop_label: Label = %TopPropLabel
@onready var top_power_label: Label = %TopPowerLabel
@onready var top_data_label: Label = %TopDataLabel
@onready var top_dsn_label: Label = %TopDsnLabel
@onready var top_budget_label: Label = %TopBudgetLabel
@onready var top_science_label: Label = %TopScienceLabel

# UI References - Left Panel (Command Center)
@onready var event_title_label: Label = %EventTitleLabel
@onready var event_condition_label: Label = %EventConditionLabel
@onready var event_flavor_label: Label = %EventFlavorLabel
@onready var event_recommendation_label: Label = %EventRecommendationLabel
@onready var mode_container: VBoxContainer = %ModeContainer
@onready var crater_selector_container: GridContainer = %CraterSelectorContainer
@onready var execute_window_btn: Button = %ExecuteWindowBtn

# UI References - Right Panel (Science & Flight Log)
@onready var crater_bars_container: VBoxContainer = %CraterBarsContainer
@onready var log_container: VBoxContainer = %LogContainer
@onready var log_scroll: ScrollContainer = %LogScroll
@onready var candidate_counter_label: Label = %CandidateCounterLabel

# UI References - Campaign Summary Modal
@onready var campaign_modal: PanelContainer = %CampaignModal
@onready var summary_title_label: Label = %SummaryTitleLabel
@onready var summary_status_label: Label = %SummaryStatusLabel
@onready var summary_science_label: Label = %SummaryScienceLabel
@onready var summary_craters_label: Label = %SummaryCratersLabel
@onready var summary_data_label: Label = %SummaryDataLabel
@onready var summary_prop_label: Label = %SummaryPropLabel
@onready var summary_battery_label: Label = %SummaryBatteryLabel
@onready var summary_budget_label: Label = %SummaryBudgetLabel

# UI References - Emergency Decision Modal
@onready var emergency_modal: PanelContainer = %EmergencyModal
@onready var emergency_title_label: Label = %EmergencyTitleLabel
@onready var emergency_scenario_label: Label = %EmergencyScenarioLabel
@onready var choice_container: VBoxContainer = %ChoiceContainer
@onready var impact_preview_label: Label = %ImpactPreviewLabel
@onready var confirm_directive_btn: Button = %ConfirmDirectiveBtn

# Simulator Engine & State
var sim: MissionSimulator
var state: SpacecraftState
var selected_mode_id: String = "mode_nominal"
var selected_target_crater_id: String = "crater_shackleton"
var _selected_emergency_choice_id: String = ""
var _emergency_choice_buttons: Dictionary = {}

# 3D Animation Variables
var _orbit_angle: float = 0.0
var _orbit_speed: float = 0.45 # rad/s
var _scan_pulse_time: float = 0.0
var _mode_buttons: Dictionary = {}
var _crater_buttons: Dictionary = {}
var _crater_progress_bars: Dictionary = {}
var _crater_status_labels: Dictionary = {}
var _crater_marker_nodes: Dictionary = {}

func _ready() -> void:
	# Retrieve or create active spacecraft state
	state = SpacecraftState.active_instance
	if state == null:
		state = SpacecraftState.new()
	
	# Instantiate and initialize the deterministic simulation engine
	sim = MissionSimulator.new()
	sim.initialize(
		state,
		MissionOperationsData.active_orbit_id,
		MissionOperationsData.active_transfer_id,
		MissionOperationsData.active_vehicle_id
	)
	
	# Connect simulator signals
	sim.window_advanced.connect(_on_window_advanced)
	sim.campaign_completed.connect(_on_campaign_completed)
	sim.mission_terminated.connect(_on_mission_terminated)
	
	# Setup visual environment
	var active_targets = MissionOperationsData.get_targets_for_scenario()
	if active_targets.size() > 0:
		selected_target_crater_id = active_targets.keys()[0]

	_setup_3d_moon_and_craters()
	_setup_orbit_trajectory_mesh()
	_setup_mode_buttons()
	_setup_crater_selectors()
	_setup_crater_tracking_ui()
	
	# Initial UI Refresh
	campaign_modal.visible = false
	if emergency_modal:
		emergency_modal.visible = false
	if confirm_directive_btn and not confirm_directive_btn.pressed.is_connected(_on_confirm_directive_pressed):
		confirm_directive_btn.pressed.connect(_on_confirm_directive_pressed)
	_refresh_ui()
	
	# Append initial commissioning log
	_append_log("T+00:00:00 — Spacecraft operational checkout nominal in %s." % sim.selected_orbit["name"], Color(0.22, 0.74, 0.96))
	_append_log("Stationkeeping allocated: %0.0f m/s. Initial ΔV reserve: +%0.0f m/s." % [sim.selected_orbit.get("stationkeeping_delta_v_ms", 150.0), sim.delta_v_remaining_ms], Color(0.2, 0.85, 0.45))
	_append_log("Primary science payload online: %s." % state.get_component(ComponentDatabase.Category.INSTRUMENTS).get("name", "Neutron Spectrometer"), Color(0.95, 0.96, 0.98))

func _process(delta: float) -> void:
	if not sim:
		return
	
	# Orbital mechanics visualization: update spacecraft position along polar orbit
	var semi_major: float = 3.2 # Visual scale in Godot coordinates
	var semi_minor: float = 3.2
	if sim.selected_orbit.get("id", "") == "orbit_elliptical_frozen":
		semi_major = 3.6
		semi_minor = 2.8
	
	_orbit_angle += delta * _orbit_speed
	if _orbit_angle > TAU:
		_orbit_angle -= TAU
	
	# Polar orbit in Y-Z plane around Moon at (0, 0, 0)
	var sc_y: float = -sin(_orbit_angle) * semi_major
	var sc_z: float = cos(_orbit_angle) * semi_minor
	var sc_x: float = 0.0
	
	if spacecraft_pivot:
		spacecraft_pivot.position = Vector3(sc_x, sc_y, sc_z)
		# Point nadir toward Moon center (0, 0, 0)
		spacecraft_pivot.look_at(Vector3.ZERO, Vector3.RIGHT)
	
	# Ground-track indicator on lunar sphere (radius ~2.2)
	if ground_track_marker:
		var norm_pos = Vector3(sc_x, sc_y, sc_z).normalized()
		ground_track_marker.position = norm_pos * 2.22
		ground_track_marker.look_at(Vector3.ZERO, Vector3.UP)
	
	# Science scanning beam pulsation
	_scan_pulse_time += delta * 4.0
	if scan_beam and scan_beam.get_surface_override_material(0):
		var mat = scan_beam.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			var alpha_pulse: float = 0.25 + 0.15 * sin(_scan_pulse_time)
			mat.albedo_color.a = alpha_pulse

# --- 3D Scene Setup ---

func _setup_3d_moon_and_craters() -> void:
	var is_earth: bool = (MissionScenario.get_active_scenario_id() == "earth_climate_sentinel")
	if moon_mesh:
		var body_mat := StandardMaterial3D.new()
		if is_earth:
			body_mat.albedo_color = Color(0.12, 0.36, 0.65) # Deep Earth ocean blue
			body_mat.roughness = 0.55
			body_mat.rim_enabled = true
			body_mat.rim = 0.6
			body_mat.rim_tint = 0.5
		else:
			body_mat.albedo_color = Color(0.65, 0.67, 0.70) # Lunar regolith grey
			body_mat.roughness = 0.95
		moon_mesh.material_override = body_mat

	# Instantiate visual 3D pins/markers for each target
	var moon_r: float = 2.2
	var all_targets = MissionOperationsData.get_targets_for_scenario()
	
	for c_id in all_targets:
		var c_data = all_targets[c_id]
		var lat_rad: float = deg_to_rad(c_data["lat_deg"])
		var lon_rad: float = deg_to_rad(c_data["lon_deg"])
		
		# Spherical to Cartesian coords
		var py: float = moon_r * sin(lat_rad)
		var r_horiz: float = moon_r * cos(lat_rad)
		var pz: float = r_horiz * cos(lon_rad)
		var px: float = r_horiz * sin(lon_rad)
		
		var marker := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.08
		cyl.bottom_radius = 0.04
		cyl.height = 0.15
		marker.mesh = cyl
		
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.9, 0.5, 0.85) if is_earth else Color(0.22, 0.74, 0.96, 0.85)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.8, 0.4) if is_earth else Color(0.15, 0.6, 0.9)
		mat.emission_energy_multiplier = 1.2
		marker.material_override = mat
		
		marker.position = Vector3(px, py, pz)
		crater_markers_node.add_child(marker)
		marker.look_at(Vector3.ZERO, Vector3.UP)
		_crater_marker_nodes[c_id] = marker

func _setup_orbit_trajectory_mesh() -> void:
	if not orbit_path_mesh:
		return
	var imm: ImmediateMesh = orbit_path_mesh.mesh as ImmediateMesh
	if not imm:
		imm = ImmediateMesh.new()
		orbit_path_mesh.mesh = imm
	
	imm.clear_surfaces()
	imm.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	
	var semi_major: float = 3.2
	var semi_minor: float = 3.2
	if sim.selected_orbit.get("id", "") == "orbit_elliptical_frozen":
		semi_major = 3.6
		semi_minor = 2.8
	
	var segments: int = 72
	for i in range(segments + 1):
		var theta: float = (float(i) / float(segments)) * TAU
		var y: float = -sin(theta) * semi_major
		var z: float = cos(theta) * semi_minor
		imm.surface_add_vertex(Vector3(0.0, y, z))
	
	imm.surface_end()
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.22, 0.74, 0.96, 0.45)
	orbit_path_mesh.material_override = mat

# --- UI Setup Helpers ---

func _setup_mode_buttons() -> void:
	for child in mode_container.get_children():
		child.queue_free()
	_mode_buttons.clear()
	
	var modes = MissionOperationsData.get_all_modes()
	for m_id in modes:
		var mode_data: Dictionary = modes[m_id]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 36)
		btn.text = "%s [%s]" % [mode_data["name"], mode_data["tag"]]
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(func(): _select_mode(m_id))
		mode_container.add_child(btn)
		_mode_buttons[m_id] = btn
	
	_update_mode_button_styles()

func _setup_crater_selectors() -> void:
	for child in crater_selector_container.get_children():
		child.queue_free()
	_crater_buttons.clear()
	
	var all_targets = MissionOperationsData.get_targets_for_scenario()
	for c_id in all_targets:
		var c_data: Dictionary = all_targets[c_id]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(130, 32)
		btn.text = c_data["name"]
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(func(): _select_target_crater(c_id))
		crater_selector_container.add_child(btn)
		_crater_buttons[c_id] = btn
	
	_update_crater_button_styles()

func _setup_crater_tracking_ui() -> void:
	for child in crater_bars_container.get_children():
		child.queue_free()
	_crater_progress_bars.clear()
	_crater_status_labels.clear()
	
	var all_targets = MissionOperationsData.get_targets_for_scenario()
	for c_id in all_targets:
		var c_data: Dictionary = all_targets[c_id]
		
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", MarginTheme.create_card_style(false))
		
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		card.add_child(vbox)
		
		var h_header := HBoxContainer.new()
		var name_lbl := Label.new()
		var lat_str = "%0.1f°S" % abs(c_data["lat_deg"]) if c_data["lat_deg"] < 0 else "%0.1f°N" % c_data["lat_deg"]
		name_lbl.text = "%s (%s)" % [c_data["name"], lat_str]
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_header.add_child(name_lbl)
		
		var cov_lbl := Label.new()
		cov_lbl.text = "0% Mapped"
		cov_lbl.add_theme_font_size_override("font_size", 10)
		cov_lbl.add_theme_color_override("font_color", Color(0.22, 0.74, 0.96))
		h_header.add_child(cov_lbl)
		vbox.add_child(h_header)
		
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 10)
		bar.max_value = 100.0
		bar.value = 0.0
		bar.show_percentage = false
		vbox.add_child(bar)
		
		var status_lbl := Label.new()
		status_lbl.text = "Status: Calibration baseline pass"
		status_lbl.add_theme_font_size_override("font_size", 9)
		status_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
		status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(status_lbl)
		
		crater_bars_container.add_child(card)
		_crater_progress_bars[c_id] = bar
		_crater_status_labels[c_id] = { "cov": cov_lbl, "status": status_lbl, "card": card }

# --- User Actions ---

func _select_mode(mode_id: String) -> void:
	selected_mode_id = mode_id
	_update_mode_button_styles()
	TeamData.log_decision(TeamData.ROLE_DIRECTOR, "Mission Operations", "Mode: " + MissionOperationsData.get_mode(mode_id)["name"], MissionOperationsData.get_mode(mode_id)["tag"])

func _select_target_crater(crater_id: String) -> void:
	selected_target_crater_id = crater_id
	_update_crater_button_styles()
	TeamData.log_decision(TeamData.ROLE_SCIENCE, "Mission Operations", "Target: " + MissionOperationsData.get_target(crater_id)["name"], "Prioritized observation")
	
	# Focus camera or marker visual highlight
	for c_id in _crater_marker_nodes:
		var marker: MeshInstance3D = _crater_marker_nodes[c_id]
		var mat = marker.material_override as StandardMaterial3D
		if mat:
			if c_id == selected_target_crater_id:
				mat.emission = Color(1.0, 0.8, 0.2)
				mat.albedo_color = Color(1.0, 0.85, 0.3)
				marker.scale = Vector3(1.5, 1.5, 1.5)
			else:
				mat.emission = Color(0.15, 0.6, 0.9)
				mat.albedo_color = Color(0.22, 0.74, 0.96, 0.85)
				marker.scale = Vector3.ONE

func _update_mode_button_styles() -> void:
	for m_id in _mode_buttons:
		var btn: Button = _mode_buttons[m_id]
		if m_id == selected_mode_id:
			btn.add_theme_color_override("font_color", Color(0.22, 0.74, 0.96))
			btn.text = "▶ " + MissionOperationsData.get_mode(m_id)["name"] + " (ACTIVE)"
		else:
			btn.remove_theme_color_override("font_color")
			btn.text = MissionOperationsData.get_mode(m_id)["name"] + " [" + MissionOperationsData.get_mode(m_id)["tag"] + "]"

func _update_crater_button_styles() -> void:
	for c_id in _crater_buttons:
		var btn: Button = _crater_buttons[c_id]
		if c_id == selected_target_crater_id:
			btn.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2))
			btn.text = "★ " + MissionOperationsData.get_crater(c_id)["name"]
		else:
			btn.remove_theme_color_override("font_color")
			btn.text = MissionOperationsData.get_crater(c_id)["name"]

func _on_execute_window_pressed() -> void:
	if sim.is_completed or sim.is_terminated:
		return
	
	var emerg: Dictionary = sim.get_current_emergency_event()
	if not emerg.is_empty():
		_show_emergency_modal(emerg)
		return
	
	_execute_window_step("")

func _show_emergency_modal(emerg: Dictionary) -> void:
	if not emergency_modal:
		_execute_window_step("")
		return
	
	print("[Operations] Emergency modal triggered for Window %d: %s (%d choices)" % [
		sim.current_window, emerg.get("id", ""), emerg.get("choices", []).size()
	])
	
	emergency_modal.visible = true
	emergency_title_label.text = emerg.get("title", "EMERGENCY DIRECTIVE REQUIRED")
	emergency_scenario_label.text = emerg.get("scenario", "")
	
	for child in choice_container.get_children():
		child.queue_free()
	_emergency_choice_buttons.clear()
	
	var choices: Array = emerg.get("choices", [])
	var default_ch_id: String = emerg.get("default_choice_id", "")
	if default_ch_id == "" and choices.size() > 0:
		default_ch_id = choices[0]["id"]
	
	_selected_emergency_choice_id = default_ch_id
	
	for ch in choices:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 48)
		btn.text = "%s — [%s]\n%s" % [ch["name"], ch["tag"], ch["description"]]
		btn.add_theme_font_size_override("font_size", 10)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(func(): _select_emergency_choice(ch))
		choice_container.add_child(btn)
		_emergency_choice_buttons[ch["id"]] = btn
	
	_update_emergency_choice_styles()
	_update_impact_preview()

func _select_emergency_choice(choice: Dictionary) -> void:
	_selected_emergency_choice_id = choice["id"]
	_update_emergency_choice_styles()
	_update_impact_preview()

func _update_emergency_choice_styles() -> void:
	for ch_id in _emergency_choice_buttons:
		var btn: Button = _emergency_choice_buttons[ch_id]
		if ch_id == _selected_emergency_choice_id:
			btn.add_theme_color_override("font_color", Color(0.22, 0.74, 0.96))
		else:
			btn.remove_theme_color_override("font_color")

func _update_impact_preview() -> void:
	var emerg: Dictionary = sim.get_current_emergency_event()
	for ch in emerg.get("choices", []):
		if ch["id"] == _selected_emergency_choice_id:
			impact_preview_label.text = "PROJECTED OUTCOME: " + ch["impact_summary"]
			return
	impact_preview_label.text = "Select an operational directive above to review predicted telemetry impact."

func _on_confirm_directive_pressed() -> void:
	if emergency_modal:
		emergency_modal.visible = false
	print("[Operations] Confirmed directive for Window %d: %s" % [sim.current_window, _selected_emergency_choice_id])
	_execute_window_step(_selected_emergency_choice_id)

func _execute_window_step(emergency_choice_id: String) -> void:
	execute_window_btn.disabled = true
	
	var report: Dictionary = sim.advance_window(selected_mode_id, selected_target_crater_id, emergency_choice_id)
	_refresh_ui()
	
	# Log reporting
	var win_num: int = report.get("window", sim.current_window - 1)
	_append_log("--- MONTH %d COMPLETED (%s) ---" % [win_num, report["event_name"]], Color(0.22, 0.74, 0.96))
	if report.has("emergency_decision"):
		var dec = report["emergency_decision"]
		_append_log("DIRECTIVE CONFIRMED: %s [%s]" % [dec["name"], dec["impact_summary"]], Color(1.0, 0.85, 0.3))
		var r_id = TeamData.ROLE_DIRECTOR
		var d_id: String = dec.get("id", "")
		if d_id.contains("pass") or d_id.contains("downlink") or d_id.contains("store"):
			r_id = TeamData.ROLE_FLIGHT_COMMS
		elif d_id.contains("load") or d_id.contains("shed") or d_id.contains("power"):
			r_id = TeamData.ROLE_SYSTEMS
		TeamData.log_decision(r_id, "Mission Operations", "Directive: " + dec.get("name", ""), dec.get("impact_summary", ""))
	_append_log("Target: %s (%0.1f%% coverage) | Mode: %s" % [report["target_crater_name"], report.get("target_crater_coverage", 0.0), report["mode_name"]], Color(0.85, 0.9, 0.95))
	_append_log("Power: Net %+0.1fW | Eclipse DoD: %0.1f%% | Batt SOH: %0.1f%%" % [report["net_sunlight_power_w"], report["battery_dod_pct"], report["battery_health_pct"]], Color(0.7, 0.8, 0.9))
	_append_log("Comms: Downlinked %0.1f Gbit | Buffer: %0.1f Gbit" % [report["data_downlinked_gbit"], report["data_buffer_gbit"]], Color(0.7, 0.8, 0.9))
	_append_log("Propulsion: Burned %0.2f kg propellant (%0.1f m/s SK) | Reserve: +%0.0f m/s" % [report["propellant_burned_kg"], report["sk_burn_ms"], report["delta_v_remaining_ms"]], Color(0.7, 0.8, 0.9))
	
	for warn in report.get("warnings", []):
		_append_log("WARNING: " + warn, Color(0.95, 0.35, 0.25))
	
	if not sim.is_completed and not sim.is_terminated:
		execute_window_btn.disabled = false

# --- Simulation Signal Handlers ---

func _on_window_advanced(window_idx: int, report: Dictionary) -> void:
	_refresh_ui()

func _on_campaign_completed(final_report: Dictionary) -> void:
	execute_window_btn.disabled = true
	execute_window_btn.text = "12-MONTH MISSION CAMPAIGN COMPLETE"
	_show_campaign_summary(final_report)

func _on_mission_terminated(reason: String, report: Dictionary) -> void:
	execute_window_btn.disabled = true
	execute_window_btn.text = "MISSION TERMINATED (CRITICAL FAILURE)"
	_append_log("CRITICAL FAILURE: " + reason, Color(0.95, 0.3, 0.2))
	_show_campaign_summary(sim.get_campaign_summary())

# --- UI Updates ---

func _refresh_ui() -> void:
	var t: Dictionary = sim.get_telemetry()
	var cur_win: int = min(12, sim.current_window)
	var event: Dictionary = MissionOperationsData.get_window_event(cur_win)
	
	# Top Bar
	top_timeline_label.text = "MONTH %d / 12 (Day %0.0f / 365)" % [cur_win, sim.mission_days_elapsed]
	top_timeline_bar.value = float(cur_win)
	
	top_prop_label.text = "Propellant: %0.1f kg (+%0.0f m/s)" % [t["propellant_remaining_kg"], t["delta_v_remaining_ms"]]
	top_power_label.text = "Battery: %0.0f%% SOH (DoD: %0.0f%%)" % [t["battery_health_pct"], t["battery_dod_pct"]]
	top_data_label.text = "Buffer: %0.0f/%0.0f Gbit (Down: %0.0f)" % [t["data_buffer_gbit"], t["data_buffer_capacity_gbit"], t["data_downlinked_total_gbit"]]
	
	# Ground station name rotates deterministically based on window
	var is_earth: bool = (MissionScenario.get_active_scenario_id() == "earth_climate_sentinel")
	var dsn_stations = ["Svalbard (SG-3)", "McMurdo (MGS)", "TrollSat (Antarctica)", "Fairbanks (ASF)"] if is_earth else ["Goldstone (34m)", "Madrid (70m)", "Canberra (34m)", "Goldstone (70m)"]
	var dsn_st = dsn_stations[cur_win % dsn_stations.size()]
	top_dsn_label.text = ("GS: " if is_earth else "DSN: ") + dsn_st
	top_budget_label.text = "Budget: $%0.1fM" % t["budget_remaining_m"]
	top_science_label.text = "Science: %0.1f pts" % t["science_score_total"]
	
	# Left Panel Event Card
	if not sim.is_completed:
		event_title_label.text = "WINDOW %d: %s" % [cur_win, event["name"]]
		event_condition_label.text = "Condition: " + event["condition"]
		event_flavor_label.text = event["flavor"]
		event_recommendation_label.text = "Flight Director Note: " + event["recommendation"]
	else:
		event_title_label.text = "CAMPAIGN COMPLETED"
		event_condition_label.text = "All 12 monthly operational windows concluded."
		event_flavor_label.text = "The earth climate sentinel monitoring dataset is preserved and ready for flight debrief." if is_earth else "The lunar polar volatile survey dataset is preserved and ready for flight debrief."
		event_recommendation_label.text = "Inspect the Mission Campaign Performance Debrief below."
	
	# Right Panel Target Coverage Bars
	for c_id in sim.crater_coverage:
		var cov: float = sim.crater_coverage[c_id]
		if _crater_progress_bars.has(c_id):
			_crater_progress_bars[c_id].value = cov
		if _crater_status_labels.has(c_id):
			var dict = _crater_status_labels[c_id]
			dict["cov"].text = "%0.1f%% Mapped" % cov
			
			var c_data = MissionOperationsData.get_crater(c_id)
			if cov >= 80.0:
				if is_earth:
					dict["status"].text = "Confirmed Proxy: %s [%s]" % [c_data.get("baseline_metric", "Nominal"), c_data.get("confidence", "Nominal")]
				else:
					dict["status"].text = "Confirmed Proxy: -%0.1f%% epithermal flux depression [%s]" % [c_data.get("baseline_depression_pct", 20.0), c_data.get("confidence", "Nominal")]
				dict["status"].add_theme_color_override("font_color", Color(0.2, 0.85, 0.45))
			elif cov >= 45.0:
				dict["status"].text = "Candidate Proxy Detected: High signal-to-noise observation" if is_earth else "Candidate Proxy Detected: Moderate neutron depression signature"
				dict["status"].add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			elif cov > 0.0:
				dict["status"].text = "In-progress observation pass: Integrating sensor swath" if is_earth else "In-progress survey pass: Integrating neutron counts"
				dict["status"].add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
			else:
				dict["status"].text = "Awaiting primary orbital ground tracks"
				dict["status"].add_theme_color_override("font_color", Color(0.45, 0.5, 0.58))
	
	if is_earth:
		candidate_counter_label.text = "Climate Sentinels Fully Monitored: %d / 6" % sim.hydrogen_candidates_found
	else:
		candidate_counter_label.text = "Candidate Volatile Reservoirs Identified: %d / 6" % sim.hydrogen_candidates_found

func _append_log(msg: String, color: Color = Color(0.85, 0.9, 0.95)) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", color)
	log_container.add_child(lbl)
	
	# Keep log size manageable
	if log_container.get_child_count() > 60:
		var first = log_container.get_child(0)
		log_container.remove_child(first)
		first.queue_free()
	
	# Scroll down
	await get_tree().process_frame
	if log_scroll:
		log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)

# --- Campaign Summary Modal ---

func _show_campaign_summary(summary: Dictionary) -> void:
	campaign_modal.visible = true
	
	var is_succ: bool = summary.get("is_success", false)
	summary_title_label.text = "MISSION OPERATIONS CAMPAIGN COMPLETE" if is_succ else "MISSION OPERATIONS CONCLUDED"
	
	if is_succ:
		summary_status_label.text = "MISSION OBJECTIVE ACHIEVED: Polar epithermal neutron survey successfully completed with positive flight reserves."
		summary_status_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.45))
	else:
		if summary.get("is_terminated", false):
			summary_status_label.text = "CRITICAL MISSION FAILURE: " + summary.get("termination_reason", "System failed.")
		else:
			summary_status_label.text = "MISSION DEFICIT: Scientific threshold not reached (%0.1f pts vs %0.1f target)." % [
				summary.get("final_science_score", 0.0), summary.get("target_threshold_score", 70.0)
			]
		summary_status_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25))
	
	summary_science_label.text = "Final Science Score: %0.1f points (Target Threshold: %0.1f pts)" % [
		summary.get("final_science_score", 0.0), summary.get("target_threshold_score", 70.0)
	]
	summary_craters_label.text = "Polar Craters Surveyed: %d / %d with verified hydrogen proxies (Avg Coverage: %0.1f%%)" % [
		summary.get("hydrogen_candidates_found", 0), summary.get("total_craters_tracked", 6), summary.get("avg_polar_coverage_pct", 0.0)
	]
	summary_data_label.text = "Scientific Data Return: %0.1f Gbit downlinked to DSN (Buffer Overflow Loss: %0.1f Gbit)" % [
		summary.get("data_downlinked_total_gbit", 0.0), summary.get("data_lost_overflow_gbit", 0.0)
	]
	summary_prop_label.text = "Propulsion Reserves: %0.1f kg propellant remaining (Remaining ΔV: +%0.0f m/s)" % [
		summary.get("propellant_remaining_kg", 0.0), summary.get("delta_v_remaining_ms", 0.0)
	]
	summary_battery_label.text = "System Health: %0.1f%% Battery SOH | %0.1f%% Equipment Health (Blackouts: %d)" % [
		summary.get("battery_health_pct", 100.0), summary.get("equipment_health_pct", 100.0), summary.get("battery_blackout_count", 0)
	]
	var budget_rem: float = summary.get("budget_remaining_m", 5.1)
	var budget_rem_str: String = ("+$%0.1fM" % budget_rem) if budget_rem >= 0.0 else ("-$%0.1fM" % abs(budget_rem))
	summary_budget_label.text = "Budget: $%0.1fM Total Cost ($%0.1fM Dev + $%0.1fM LV + $%0.1fM Ops) | %s Reserve" % [
		summary.get("total_cost_m", 174.9), summary.get("spacecraft_dev_cost_m", 112.5), summary.get("launch_cost_m", 48.0), summary.get("ops_cost_total_m", 14.4), budget_rem_str
	]

# --- Navigation Callbacks ---

func _on_proceed_to_debrief_pressed() -> void:
	# Commit active campaign results for scoring engine and debrief
	var summary_data: Dictionary = sim.get_campaign_summary()
	summary_data["history"] = sim.window_history.duplicate(true)
	MissionOperationsData.active_campaign_results = summary_data
	get_tree().change_scene_to_file("res://margin/scenes/mission_debrief.tscn")

func _on_back_to_workshop_pressed() -> void:
	get_tree().change_scene_to_file("res://margin/scenes/workshop.tscn")

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://margin/scenes/main_menu.tscn")

func _on_polar_view_pressed() -> void:
	if orbit_cam:
		orbit_cam.focus_on(Vector3(0.0, -2.2, 0.0), 3.5)

func _on_global_view_pressed() -> void:
	if orbit_cam:
		orbit_cam.focus_on(Vector3.ZERO, 6.0)

func _on_reset_cam_pressed() -> void:
	if orbit_cam:
		orbit_cam.reset_view()
