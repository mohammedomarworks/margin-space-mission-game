class_name MissionDebriefController
extends Node3D

# ==============================================================================
# MARGIN: MISSION DEBRIEF CONTROLLER (MILESTONE 4)
# Comprehensive 8-Pillar Scoring, Telemetry Audit, Interactive Timeline & Local Comparison
# ==============================================================================

const ScoringEngine = preload("res://margin/scripts/scoring_engine.gd")
const MissionEvaluationData = preload("res://margin/data/mission_evaluation_data.gd")
const MissionOperationsData = preload("res://margin/data/mission_operations_data.gd")
const SpacecraftState = preload("res://margin/scripts/spacecraft_state.gd")
const ComponentDatabase = preload("res://margin/data/component_data.gd")
const OrbitDatabase = preload("res://margin/data/orbit_data.gd")
const MarginTheme = preload("res://margin/ui/margin_theme.gd")

# 3D Node References
@onready var moon_mesh: MeshInstance3D = %MoonMesh
@onready var crater_markers_node: Node3D = %CraterMarkers
@onready var orbit_cam: Node3D = %OrbitCamera

# UI References - Top Bar
@onready var mission_title_label: Label = %MissionTitleLabel
@onready var config_summary_label: Label = %ConfigSummaryLabel
@onready var save_status_label: Label = %SaveStatusLabel

# UI References - Tab Buttons
@onready var tab_btn_overview: Button = %TabBtnOverview
@onready var tab_btn_science: Button = %TabBtnScience
@onready var tab_btn_audit: Button = %TabBtnAudit
@onready var tab_btn_timeline: Button = %TabBtnTimeline
@onready var tab_btn_team: Button = %TabBtnTeam
@onready var tab_btn_compare: Button = %TabBtnCompare

# UI References - Tab Containers
@onready var tab_overview: Control = %TabOverview
@onready var tab_science: Control = %TabScience
@onready var tab_audit: Control = %TabAudit
@onready var tab_timeline: Control = %TabTimeline
@onready var tab_team: Control = %TabTeam
@onready var tab_compare: Control = %TabCompare

# Tab 0: Overview & Scorecard
@onready var score_number_label: Label = %ScoreNumberLabel
@onready var grade_badge_label: Label = %GradeBadgeLabel
@onready var outcome_banner_panel: PanelContainer = %OutcomeBannerPanel
@onready var outcome_banner_label: Label = %OutcomeBannerLabel
@onready var outcome_reasons_container: VBoxContainer = %OutcomeReasonsContainer
@onready var pillars_grid_container: GridContainer = %PillarsGridContainer

# Tab 1: Scientific Report & Craters
@onready var sci_total_label: Label = %SciTotalLabel
@onready var craters_grid_container: GridContainer = %CratersGridContainer
@onready var nasa_benchmarks_container: VBoxContainer = %NasaBenchmarksContainer

# Tab 2: Engineering Decision Audit
@onready var audit_findings_container: VBoxContainer = %AuditFindingsContainer

# Tab 3: Interactive Timeline
@onready var timeline_pills_container: HBoxContainer = %TimelinePillsContainer
@onready var timeline_month_label: Label = %TimelineMonthLabel
@onready var timeline_event_label: Label = %TimelineEventLabel
@onready var timeline_condition_label: Label = %TimelineConditionLabel
@onready var timeline_telemetry_label: Label = %TimelineTelemetryLabel
@onready var timeline_warnings_container: VBoxContainer = %TimelineWarningsContainer

# Tab 4: Team Contribution
@onready var team_roles_container: GridContainer = %TeamRolesContainer

# Tab 5: Saved Missions & Comparison
@onready var saved_missions_list_container: VBoxContainer = %SavedMissionsListContainer
@onready var compare_dropdown_a: OptionButton = %CompareDropdownA
@onready var compare_dropdown_b: OptionButton = %CompareDropdownB
@onready var comparison_results_container: VBoxContainer = %ComparisonResultsContainer

# State & Debrief Report
var state: SpacecraftState
var report: Dictionary = {}
var history: Array = []
var _tab_buttons: Array[Button] = []
var _tab_panels: Array[Control] = []
var _selected_timeline_window: int = 1
var _crater_markers: Dictionary = {}

func _ready() -> void:
	# Retrieve or create active spacecraft state
	state = SpacecraftState.active_instance
	if state == null:
		state = SpacecraftState.new()
	
	# Retrieve simulation summary
	var summary: Dictionary = MissionOperationsData.active_campaign_results
	if summary.is_empty():
		# Standalone test/fallback: generate realistic completed summary
		summary = {
			"is_completed": true,
			"is_terminated": false,
			"windows_completed": 12,
			"mission_days_elapsed": 365.0,
			"final_science_score": 86.5,
			"avg_polar_coverage_pct": 78.5,
			"hydrogen_candidates_found": 5,
			"battery_health_pct": 98.4,
			"battery_blackout_count": 0,
			"equipment_health_pct": 94.2,
			"pre_launch_reliability_pct": 92.5,
			"spacecraft_dev_cost_m": 112.5,
			"launch_cost_m": 32.0,
			"ops_cost_total_m": 14.9,
			"total_cost_m": 159.4,
			"data_downlinked_total_gbit": 175.2,
			"data_lost_overflow_gbit": 0.0,
			"propellant_remaining_kg": 24.6,
			"delta_v_remaining_ms": 78.0,
			"budget_remaining_m": 20.6,
			"mission_name": "Lunar South Pole Survey",
			"orbit_name": "Low Circular Polar Orbit",
			"transfer_name": "Low-Energy Ballistic Transfer",
			"vehicle_name": "Medium Commercial EELV-Class",
			"crater_coverage": {
				"crater_shackleton": 100.0,
				"crater_shoemaker": 85.0,
				"crater_faustini": 65.0,
				"crater_cabeus": 92.0,
				"crater_amundsen": 55.0,
				"crater_haworth": 74.0
			}
		}
	
	history = summary.get("history", [])
	
	# Execute Eight-Pillar Deterministic Scoring Engine
	report = ScoringEngine.evaluate_mission(summary, state, history)
	MissionEvaluationData.active_debrief_report = report
	
	# Setup UI Tabs
	_tab_buttons = [tab_btn_overview, tab_btn_science, tab_btn_audit, tab_btn_timeline, tab_btn_team, tab_btn_compare]
	_tab_panels = [tab_overview, tab_science, tab_audit, tab_timeline, tab_team, tab_compare]
	
	for i in range(_tab_buttons.size()):
		var idx: int = i
		_tab_buttons[i].pressed.connect(func(): _switch_tab(idx))
	
	# Setup 3D Moon & Crater Markers
	_setup_3d_moon_and_craters()
	
	# Populate all Debrief Sections
	_populate_top_header()
	_populate_overview_tab()
	_populate_science_tab()
	_populate_audit_tab()
	_populate_timeline_tab()
	_populate_team_tab()
	_populate_compare_tab()
	
	# Switch to Tab 0 and play score reveal animation
	_switch_tab(0)
	_animate_score_reveal()

func _process(delta: float) -> void:
	# Subtle 3D moon axial rotation
	if moon_mesh:
		moon_mesh.rotate_y(delta * 0.04)
	if crater_markers_node:
		crater_markers_node.rotate_y(delta * 0.04)

# --- 3D Scene Setup ---

func _setup_3d_moon_and_craters() -> void:
	var moon_r: float = 2.2
	var all_craters = MissionOperationsData.get_all_craters()
	var cov_map: Dictionary = report.get("crater_coverage", {})
	
	for c_id in all_craters:
		var c_data: Dictionary = all_craters[c_id]
		var lat_rad: float = deg_to_rad(c_data["lat_deg"])
		var lon_rad: float = deg_to_rad(c_data["lon_deg"])
		
		# Spherical coordinates on South Pole (-Y)
		var py: float = moon_r * sin(lat_rad)
		var r_horiz: float = moon_r * cos(lat_rad)
		var pz: float = r_horiz * cos(lon_rad)
		var px: float = r_horiz * sin(lon_rad)
		
		var marker := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.08
		cyl.bottom_radius = 0.04
		cyl.height = 0.16
		marker.mesh = cyl
		
		var cov: float = cov_map.get(c_id, 0.0)
		var mat := StandardMaterial3D.new()
		if cov >= 80.0:
			mat.albedo_color = Color(0.2, 0.85, 0.45, 0.95)
			mat.emission = Color(0.2, 0.85, 0.45)
		elif cov >= 45.0:
			mat.albedo_color = Color(1.0, 0.82, 0.25, 0.95)
			mat.emission = Color(1.0, 0.82, 0.25)
		else:
			mat.albedo_color = Color(0.22, 0.74, 0.96, 0.85)
			mat.emission = Color(0.15, 0.6, 0.9)
		mat.emission_enabled = true
		mat.emission_energy_multiplier = 1.4
		marker.material_override = mat
		
		marker.position = Vector3(px, py, pz)
		crater_markers_node.add_child(marker)
		marker.look_at(Vector3.ZERO, Vector3.UP)
		_crater_markers[c_id] = marker

# --- Tab Switching ---

func _switch_tab(tab_idx: int) -> void:
	for i in range(_tab_panels.size()):
		_tab_panels[i].visible = (i == tab_idx)
		if i == tab_idx:
			_tab_buttons[i].add_theme_color_override("font_color", Color(0.22, 0.74, 0.96))
		else:
			_tab_buttons[i].remove_theme_color_override("font_color")

# --- UI Population ---

func _populate_top_header() -> void:
	var t: Dictionary = state.calculate_telemetry()
	mission_title_label.text = "MARGIN — MISSION EVALUATION & FLIGHT DEBRIEF"
	config_summary_label.text = "Craft: %s | Launcher: %s | Orbit: %s | Transit: %s" % [
		state.get_component(ComponentDatabase.Category.STRUCTURE).get("name", "Spacecraft"),
		report.get("vehicle_name", "Medium Commercial EELV-Class"),
		report.get("orbit_name", "100 km Circular Polar"),
		report.get("transfer_name", "Low-Energy BLT")
	]

func _populate_overview_tab() -> void:
	# Outcome Banner & Grade
	var outcome: String = report.get("outcome", "SUCCESS")
	var outcome_name: String = report.get("outcome_name", "MISSION SUCCESSFUL")
	outcome_banner_label.text = outcome_name
	
	var style_banner := StyleBoxFlat.new()
	style_banner.set_corner_radius_all(6)
	style_banner.content_margin_top = 8.0
	style_banner.content_margin_bottom = 8.0
	
	if outcome == "SUCCESS":
		style_banner.bg_color = Color(0.08, 0.35, 0.2, 0.95)
		style_banner.border_color = Color(0.2, 0.85, 0.45, 1)
		style_banner.set_border_width_all(2)
		outcome_banner_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.45))
	elif outcome == "PARTIAL_SUCCESS":
		style_banner.bg_color = Color(0.35, 0.28, 0.08, 0.95)
		style_banner.border_color = Color(1.0, 0.82, 0.25, 1)
		style_banner.set_border_width_all(2)
		outcome_banner_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	else:
		style_banner.bg_color = Color(0.35, 0.08, 0.08, 0.95)
		style_banner.border_color = Color(0.95, 0.35, 0.25, 1)
		style_banner.set_border_width_all(2)
		outcome_banner_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25))
	
	outcome_banner_panel.add_theme_stylebox_override("panel", style_banner)
	grade_badge_label.text = "GRADE " + report.get("letter_grade", "B")
	
	# Outcome Diagnostic Reasons
	for child in outcome_reasons_container.get_children():
		child.queue_free()
	for reason in report.get("outcome_reasons", []):
		var lbl := Label.new()
		lbl.text = "• " + reason
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
		outcome_reasons_container.add_child(lbl)
	
	# 8-Pillar Scorecard Grid
	for child in pillars_grid_container.get_children():
		child.queue_free()
	
	var pillars: Array = report.get("pillars", [])
	for p in pillars:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(340, 100)
		card.add_theme_stylebox_override("panel", MarginTheme.create_card_style(false))
		
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		card.add_child(vbox)
		
		# Title & Weighted Contribution
		var h_title := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = "%s (%0.0f%%)" % [p["name"], p["weight"] * 100.0]
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_title.add_child(name_lbl)
		
		var score_lbl := Label.new()
		score_lbl.text = "%0.1f/100 (+%0.1f pts)" % [p["score"], p["weighted_score"]]
		score_lbl.add_theme_font_size_override("font_size", 11)
		score_lbl.add_theme_color_override("font_color", Color(0.22, 0.74, 0.96))
		h_title.add_child(score_lbl)
		vbox.add_child(h_title)
		
		# Progress Bar
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 8)
		bar.max_value = 100.0
		bar.value = p["score"]
		bar.show_percentage = false
		vbox.add_child(bar)
		
		# Telemetry metric value
		var val_lbl := Label.new()
		val_lbl.text = "Metric: " + p["metric_val"]
		val_lbl.add_theme_font_size_override("font_size", 9)
		val_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
		vbox.add_child(val_lbl)
		
		# Formula & Explanation
		var exp_lbl := Label.new()
		exp_lbl.text = p["explanation"]
		exp_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		exp_lbl.add_theme_font_size_override("font_size", 9)
		exp_lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
		vbox.add_child(exp_lbl)
		
		pillars_grid_container.add_child(card)

func _animate_score_reveal() -> void:
	var final_score: float = report.get("total_weighted_score", 0.0)
	score_number_label.text = "0.0 / 100"
	
	var tween := create_tween()
	tween.tween_method(
		func(val: float):
			score_number_label.text = "%0.1f / 100" % val,
		0.0,
		final_score,
		1.4
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _populate_science_tab() -> void:
	sci_total_label.text = "Total Scientific Achievement: %0.1f points | Avg Polar Survey Coverage: %0.1f%% | Volatile Reservoirs Identified: %d / 6" % [
		report.get("final_science_score", 0.0),
		report.get("avg_polar_coverage_pct", 0.0),
		report.get("hydrogen_candidates_found", 0)
	]
	
	# Populate 6 crater cards
	for child in craters_grid_container.get_children():
		child.queue_free()
	
	var all_craters = MissionOperationsData.get_all_craters()
	var cov_map: Dictionary = report.get("crater_coverage", {})
	
	for c_id in all_craters:
		var c = all_craters[c_id]
		var cov: float = cov_map.get(c_id, 0.0)
		
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(340, 110)
		card.add_theme_stylebox_override("panel", MarginTheme.create_card_style(cov >= 50.0))
		
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		card.add_child(vbox)
		
		var h_top := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = "%s (%0.1f°S, %0.1f°E)" % [c["name"], abs(c["lat_deg"]), c["lon_deg"]]
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_top.add_child(name_lbl)
		
		var cov_lbl := Label.new()
		cov_lbl.text = "%0.1f%% Mapped" % cov
		cov_lbl.add_theme_font_size_override("font_size", 11)
		cov_lbl.add_theme_color_override("font_color", Color(0.2, 0.85, 0.45) if cov >= 50.0 else Color(0.22, 0.74, 0.96))
		h_top.add_child(cov_lbl)
		vbox.add_child(h_top)
		
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 8)
		bar.max_value = 100.0
		bar.value = cov
		bar.show_percentage = false
		vbox.add_child(bar)
		
		var specs_lbl := Label.new()
		specs_lbl.text = "Diameter: %0.0f km | Depth: %0.1f km | PSR Area: %0.0f km²" % [c["diameter_km"], c["depth_km"], c["psr_area_km2"]]
		specs_lbl.add_theme_font_size_override("font_size", 9)
		specs_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
		vbox.add_child(specs_lbl)
		
		var note_lbl := Label.new()
		note_lbl.text = "Proxy Observation: " + c["scientific_proxy_note"]
		note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note_lbl.add_theme_font_size_override("font_size", 9)
		note_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
		vbox.add_child(note_lbl)
		
		craters_grid_container.add_child(card)
	
	# Populate NASA Benchmarks
	for child in nasa_benchmarks_container.get_children():
		child.queue_free()
	
	var benchmarks: Dictionary = MissionEvaluationData.get_nasa_benchmarks()
	for b_id in benchmarks:
		var b = benchmarks[b_id]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", MarginTheme.create_card_style(false))
		
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		card.add_child(vbox)
		
		var name_lbl := Label.new()
		name_lbl.text = b["mission"] + " [" + b["type"] + "]"
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color(0.22, 0.74, 0.96))
		vbox.add_child(name_lbl)
		
		var details_lbl := Label.new()
		details_lbl.text = "Wet Mass: %0.0f kg | Instrument: %s | Orbit: %s" % [b["wet_mass_kg"], b["instrument"], b["orbit_km"]]
		details_lbl.add_theme_font_size_override("font_size", 9)
		details_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
		vbox.add_child(details_lbl)
		
		var find_lbl := Label.new()
		find_lbl.text = "Historical Finding: " + b["key_findings"]
		find_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		find_lbl.add_theme_font_size_override("font_size", 9)
		find_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
		vbox.add_child(find_lbl)
		
		var dist_lbl := Label.new()
		dist_lbl.text = "Simulation vs Reality: " + b["caution_distinction"]
		dist_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dist_lbl.add_theme_font_size_override("font_size", 9)
		dist_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
		vbox.add_child(dist_lbl)
		
		nasa_benchmarks_container.add_child(card)

func _populate_audit_tab() -> void:
	for child in audit_findings_container.get_children():
		child.queue_free()
	
	var findings: Array = report.get("engineering_findings", [])
	for f in findings:
		var card := PanelContainer.new()
		var is_highlight: bool = "highlight" in f.get("impact_type", "")
		card.add_theme_stylebox_override("panel", MarginTheme.create_card_style(is_highlight))
		
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		card.add_child(vbox)
		
		var h_top := HBoxContainer.new()
		var sub_lbl := Label.new()
		sub_lbl.text = f["subsystem"] + " — " + f["decision"]
		sub_lbl.add_theme_font_size_override("font_size", 11)
		sub_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_top.add_child(sub_lbl)
		
		var verd_lbl := Label.new()
		verd_lbl.text = f["verdict"]
		verd_lbl.add_theme_font_size_override("font_size", 10)
		if f.get("impact_type", "") == "positive" or f.get("impact_type", "") == "highlight_positive":
			verd_lbl.add_theme_color_override("font_color", Color(0.2, 0.85, 0.45))
		elif f.get("impact_type", "") == "negative" or f.get("impact_type", "") == "highlight_negative":
			verd_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25))
		else:
			verd_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
		h_top.add_child(verd_lbl)
		vbox.add_child(h_top)
		
		var det_lbl := Label.new()
		det_lbl.text = f["detail"]
		det_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		det_lbl.add_theme_font_size_override("font_size", 9)
		det_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
		vbox.add_child(det_lbl)
		
		audit_findings_container.add_child(card)

func _populate_timeline_tab() -> void:
	for child in timeline_pills_container.get_children():
		child.queue_free()
	
	for w in range(1, 13):
		var btn := Button.new()
		btn.text = "Month %d" % w
		btn.custom_minimum_size = Vector2(54, 28)
		btn.add_theme_font_size_override("font_size", 10)
		var win_idx: int = w
		btn.pressed.connect(func(): _select_timeline_window(win_idx))
		timeline_pills_container.add_child(btn)
	
	_select_timeline_window(1)

func _select_timeline_window(win_idx: int) -> void:
	_selected_timeline_window = win_idx
	
	# Highlight active pill
	var pills = timeline_pills_container.get_children()
	for i in range(pills.size()):
		var btn = pills[i] as Button
		if (i + 1) == win_idx:
			btn.add_theme_color_override("font_color", Color(0.22, 0.74, 0.96))
		else:
			btn.remove_theme_color_override("font_color")
	
	# Retrieve history record if available, or generate from event data
	var ev_data: Dictionary = MissionOperationsData.get_window_event(win_idx)
	var win_record: Dictionary = {}
	if win_idx <= history.size():
		win_record = history[win_idx - 1]
	
	timeline_month_label.text = "OPERATIONAL WINDOW %d (Day %0.1f of 365)" % [win_idx, float(win_idx) * (365.0 / 12.0)]
	timeline_event_label.text = "Environmental Event: " + ev_data["name"]
	timeline_condition_label.text = "Condition: %s\nFlavor: %s" % [ev_data["condition"], ev_data["flavor"]]
	
	if not win_record.is_empty():
		timeline_telemetry_label.text = "Mode: %s | Target: %s\nPower: Net %+0.1fW | Eclipse DoD: %0.1f%% | Batt Health: %0.1f%%\nData: %0.1f Gbit Gen | %0.1f Gbit Downlinked | Buffer: %0.1f Gbit\nPropulsion: %0.1f m/s SK Burn (%0.2f kg fuel) | Reserve: +%0.0f m/s" % [
			win_record.get("mode_name", "Nominal"),
			win_record.get("target_crater_name", "Shackleton"),
			win_record.get("net_sunlight_power_w", 245.0),
			win_record.get("battery_dod_pct", 30.4),
			win_record.get("battery_health_pct", 99.8),
			win_record.get("data_generated_gbit", 54.0),
			win_record.get("data_downlinked_gbit", 54.0),
			win_record.get("data_buffer_gbit", 0.0),
			win_record.get("sk_burn_ms", 12.5),
			win_record.get("propellant_burned_kg", 1.2),
			win_record.get("delta_v_remaining_ms", 78.0)
		]
		
		for child in timeline_warnings_container.get_children():
			child.queue_free()
		var warns: Array = win_record.get("warnings", [])
		if warns.is_empty():
			var lbl := Label.new()
			lbl.text = "• Flight Status: Nominal operations throughout this window. Zero critical subsystem alarms."
			lbl.add_theme_font_size_override("font_size", 9)
			lbl.add_theme_color_override("font_color", Color(0.2, 0.85, 0.45))
			timeline_warnings_container.add_child(lbl)
		else:
			for w in warns:
				var lbl := Label.new()
				lbl.text = "⚠ " + str(w)
				lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				lbl.add_theme_font_size_override("font_size", 9)
				lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25))
				timeline_warnings_container.add_child(lbl)
	else:
		timeline_telemetry_label.text = "Mission concluded before Window %d was executed." % win_idx

func _populate_team_tab() -> void:
	for child in team_roles_container.get_children():
		child.queue_free()
	
	var team: Dictionary = report.get("team_contributions", {})
	for role_key in team:
		var r = team[role_key]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(340, 110)
		card.add_theme_stylebox_override("panel", MarginTheme.create_card_style(false))
		
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		card.add_child(vbox)
		
		var h_top := HBoxContainer.new()
		var role_lbl := Label.new()
		role_lbl.text = r["role"]
		role_lbl.add_theme_font_size_override("font_size", 12)
		role_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
		role_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_top.add_child(role_lbl)
		
		var score_lbl := Label.new()
		score_lbl.text = "%0.1f / 100" % r["score"]
		score_lbl.add_theme_font_size_override("font_size", 12)
		score_lbl.add_theme_color_override("font_color", Color(0.22, 0.74, 0.96))
		h_top.add_child(score_lbl)
		vbox.add_child(h_top)
		
		var title_lbl := Label.new()
		title_lbl.text = r["title"]
		title_lbl.add_theme_font_size_override("font_size", 10)
		title_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
		vbox.add_child(title_lbl)
		
		var stat_lbl := Label.new()
		stat_lbl.text = "Key Stat: " + r["key_stat"]
		stat_lbl.add_theme_font_size_override("font_size", 9)
		stat_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
		vbox.add_child(stat_lbl)
		
		var assess_lbl := Label.new()
		assess_lbl.text = "Assessment: " + r["assessment"]
		assess_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		assess_lbl.add_theme_font_size_override("font_size", 9)
		assess_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
		vbox.add_child(assess_lbl)
		
		team_roles_container.add_child(card)

func _populate_compare_tab() -> void:
	for child in saved_missions_list_container.get_children():
		child.queue_free()
	
	compare_dropdown_a.clear()
	compare_dropdown_b.clear()
	
	var saved_list: Array[Dictionary] = MissionEvaluationData.load_all_saved_missions()
	
	if saved_list.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No saved missions found in local storage. Click [SAVE THIS MISSION REPORT] above to save your run!"
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
		saved_missions_list_container.add_child(empty_lbl)
		return
	
	for i in range(saved_list.size()):
		var s = saved_list[i]
		var s_name: String = "%s (Score: %0.1f | %s)" % [
			s.get("saved_at", "Mission " + str(i + 1)),
			s.get("total_weighted_score", 0.0),
			s.get("outcome_name", "COMPLETED")
		]
		compare_dropdown_a.add_item(s_name, i)
		compare_dropdown_b.add_item(s_name, i)
		
		# Card in list
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", MarginTheme.create_card_style(false))
		
		var hbox := HBoxContainer.new()
		var desc_lbl := Label.new()
		desc_lbl.text = s_name + " — " + s.get("orbit_name", "Low Circular") + " (" + s.get("vehicle_name", "Medium Commercial EELV-Class") + ")"
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(desc_lbl)
		
		var del_btn := Button.new()
		del_btn.text = "DELETE"
		del_btn.add_theme_font_size_override("font_size", 9)
		var s_id: String = s.get("save_id", "")
		del_btn.pressed.connect(func(): _delete_saved(s_id))
		hbox.add_child(del_btn)
		
		card.add_child(hbox)
		saved_missions_list_container.add_child(card)
	
	if saved_list.size() >= 2:
		compare_dropdown_b.selected = 1
	else:
		compare_dropdown_b.selected = 0

func _on_compare_button_pressed() -> void:
	var saved_list: Array[Dictionary] = MissionEvaluationData.load_all_saved_missions()
	if saved_list.size() < 2:
		for child in comparison_results_container.get_children():
			child.queue_free()
		var lbl := Label.new()
		lbl.text = "Please save at least 2 mission configurations to generate a side-by-side comparison."
		lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
		comparison_results_container.add_child(lbl)
		return
	
	var idx_a: int = compare_dropdown_a.selected
	var idx_b: int = compare_dropdown_b.selected
	var comp: Dictionary = MissionEvaluationData.compare_missions(saved_list[idx_a], saved_list[idx_b])
	
	for child in comparison_results_container.get_children():
		child.queue_free()
	
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", MarginTheme.create_card_style(true))
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)
	
	var res_lbl := Label.new()
	res_lbl.text = "COMPARISON VERDICT: %s is the superior configuration (Score Delta: %+0.1f pts)" % [
		comp["better_design"], comp["score_delta"]
	]
	res_lbl.add_theme_font_size_override("font_size", 12)
	res_lbl.add_theme_color_override("font_color", Color(0.2, 0.85, 0.45))
	vbox.add_child(res_lbl)
	
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	
	_add_compare_row(grid, "Metric", comp["design_a_name"], comp["design_b_name"])
	_add_compare_row(grid, "Outcome", comp["design_a_outcome"], comp["design_b_outcome"])
	_add_compare_row(grid, "Science Delta", "-", "%+0.1f pts" % comp["science_delta"])
	var cost_delta_val: float = comp["cost_delta"]
	var cost_delta_str: String = ("+$%0.1fM" % cost_delta_val) if cost_delta_val >= 0.0 else ("-$%0.1fM" % abs(cost_delta_val))
	_add_compare_row(grid, "Cost Delta", "-", cost_delta_str)
	_add_compare_row(grid, "Wet Mass Delta", "-", "%+0.1f kg" % comp["mass_delta"])
	_add_compare_row(grid, "Propellant Delta", "-", "%+0.1f kg" % comp["propellant_delta"])
	_add_compare_row(grid, "Downlink Delta", "-", "%+0.1f Gbit" % comp["downlink_delta"])
	
	vbox.add_child(grid)
	comparison_results_container.add_child(card)

func _add_compare_row(grid: GridContainer, col1: String, col2: String, col3: String) -> void:
	var l1 := Label.new()
	l1.text = col1
	l1.add_theme_font_size_override("font_size", 10)
	l1.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	grid.add_child(l1)
	
	var l2 := Label.new()
	l2.text = col2
	l2.add_theme_font_size_override("font_size", 10)
	l2.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	grid.add_child(l2)
	
	var l3 := Label.new()
	l3.text = col3
	l3.add_theme_font_size_override("font_size", 10)
	l3.add_theme_color_override("font_color", Color(0.22, 0.74, 0.96))
	grid.add_child(l3)

func _delete_saved(save_id: String) -> void:
	MissionEvaluationData.delete_saved_mission(save_id)
	_populate_compare_tab()

# --- Save Action ---

func _on_save_report_pressed() -> void:
	var success: bool = MissionEvaluationData.save_mission_report(report)
	if success:
		save_status_label.text = "✓ Report saved to local storage!"
		save_status_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.45))
		_populate_compare_tab()
	else:
		save_status_label.text = "✗ Error saving report"
		save_status_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25))

# --- Navigation Callbacks ---

func _on_replay_mission_pressed() -> void:
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
