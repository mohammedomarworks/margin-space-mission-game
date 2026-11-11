class_name Helios4DebriefController
extends Control

# ==============================================================================
# MARGIN — HELIOS-4: MISSION DEBRIEF & SCIENTIFIC AUDIT
# Scorecard, 4-Officer Team Contribution, Stationkeeping Margin, and
# Space Weather Early-Warning Delivery Report.
# ==============================================================================

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")

@onready var outcome_lbl: Label = %OutcomeLabel
@onready var grade_lbl: Label = %GradeLabel
@onready var score_lbl: Label = %ScoreLabel
@onready var summary_text: RichTextLabel = %DebriefSummaryText
@onready var team_report_text: RichTextLabel = %TeamReportText

@onready var save_btn: Button = %SaveAndCompleteBtn
@onready var replay_btn: Button = %ReplayMissionBtn
@onready var menu_btn: Button = %MainMenuBtn

var total_score: float = 0.0
var letter_grade: String = "A"
var is_success: bool = true

func _ready() -> void:
	theme = MarginTheme.get_theme()
	_calculate_debrief_score()
	_populate_ui()
	if is_success:
		Sfx.victory_fanfare()
	else:
		Sfx.failure_powerdown()
	
	save_btn.pressed.connect(_on_save_and_complete_pressed)
	replay_btn.pressed.connect(_on_replay_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)
	MarginTheme.apply_interactive_polish(self)

	get_tree().process_frame.connect(func():
		if save_btn: print("[Debrief] SaveAndCompleteBtn center: ", save_btn.get_global_rect().get_center())
		if menu_btn: print("[Debrief] MainMenuBtn center: ", menu_btn.get_global_rect().get_center())
	, CONNECT_ONE_SHOT)

func _calculate_debrief_score() -> void:
	var l_tel = Helios4CampaignData.launch_telemetry
	var c_res = Helios4CampaignData.crisis_results
	var l1_tel = Helios4CampaignData.l1_telemetry
	
	var res = Helios4CampaignData.calculate_debrief_score(l_tel, c_res, l1_tel)
	total_score = res["total_score"]
	letter_grade = res["letter_grade"]
	is_success = res["is_success"]
	Helios4CampaignData.final_debrief_data = res

func _populate_ui() -> void:
	if is_success:
		outcome_lbl.text = "MISSION SUCCESSFUL — HELIOS-4 FULLY COMMISSIONED"
		outcome_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
	else:
		outcome_lbl.text = "MISSION DEGRADED — LOSS OF MINIMUM OBJECTIVES"
		outcome_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
		
	grade_lbl.text = "GRADE: " + letter_grade
	score_lbl.text = "%.1f / 100 PTS" % total_score
	
	var c_res = Helios4CampaignData.crisis_results
	var l1_tel = Helios4CampaignData.l1_telemetry
	var lead_time = l1_tel.get("lead_time_minutes", 0.0)
	var shock_speed = l1_tel.get("solar_wind_speed_kms", 0.0)
	var l1_dist = l1_tel.get("l1_distance_km", Helios4CampaignData.L1_DISTANCE_KM)
	var equip_health = 100.0 - c_res.get("equipment_degradation_pct", 0.0)
	var rem_fuel = l1_tel.get("final_propellant_kg", 0.0)
	var design_telemetry: Dictionary = Helios4CampaignData.calculate_hangar_telemetry()
	var science_score: float = l1_tel.get("science_score", design_telemetry.get("science_score", 0.0)) + c_res.get("science_bonus_pts", 0.0)
	var power_remaining: float = l1_tel.get("battery_remaining_wh", 0.0)
	var payload_mass: float = design_telemetry.get("probe_wet_mass_kg", 0.0)
	var mass_margin: float = 1250.0 - payload_mass
	var power_margin: float = l1_tel.get("power_margin_w", design_telemetry.get("power_margin_w", 0.0))
	
	var p1 = Helios4CampaignData.final_debrief_data.get("launch_pillar", 25.0)
	var p2 = Helios4CampaignData.final_debrief_data.get("crisis_pillar", 25.0)
	var p3 = Helios4CampaignData.final_debrief_data.get("l1_pillar", 25.0)
	var p4 = Helios4CampaignData.final_debrief_data.get("warning_pillar", 25.0)
	var perk := Helios4CampaignData.get_active_team_perk()
	var perk_str: String = "%s (%s)" % [
		perk.get("title", "Propulsion Lead"),
		"ACTIVE IN CAMPAIGN" if perk.get("active", false) else "DEFAULT LEAD ROLE"
	]
	var waiver_str: String = "PASSED ALL FRR GATES CLEANLY"
	if Helios4CampaignData.launch_readiness_override:
		var wg := Helios4CampaignData.waived_gates
		waiver_str = "FLIGHT DIRECTOR WAIVER USED (%s)" % (", ".join(wg) if not wg.is_empty() else "Manual override")
	var v_cfg := Helios4CampaignData.vehicle_config
	var p_cfg := Helios4CampaignData.probe_config
	var t_tel := Helios4CampaignData.transfer_telemetry
	var l_tel := Helios4CampaignData.launch_telemetry
	var shield_mode_str := "Sunward Thermal Shield" if t_tel.get("thermal_shield_sunward", true) else "Off-Sun Science Attitude"
	var crisis_batt := float(t_tel.get("battery_charge_wh", power_remaining))
	var crisis_temp := float(t_tel.get("thermal_bus_temp_c", 22.0))
	var packet_status := "DELIVERED TO EARTH DSN" if l1_tel.get("warning_packet_sent", false) else "NOT DELIVERED"
	
	summary_text.text = """[b]END-TO-END CAUSE & EFFECT CHAIN (HANGAR → L1):[/b]
• [color=#38bdf8]1. Hangar Build:[/color] Engine [b]%s[/b] • Bus [b]%s[/b] • Solar [b]%.1f m²[/b] • Trajectory [b]%s[/b]
• [color=#facc15]2. Team Lead Perk:[/color] [b]%s[/b] — %s
• [color=#fb923c]3. Engineering Gate & Launch:[/color] [b]%s[/b] (Max-Q Stress: %.1f%% • Ascent Error: %.1f%%)
• [color=#f87171]4. Deep-Space Solar CME Crisis:[/color] [b]%s[/b] → Degradation: %.1f%% • Bus Temp: %.1f°C • Battery: %.0f Wh
• [color=#4ade80]5. L1 Science & Early Warning:[/color] Halo Stability %.1f%% • Packet [b]%s[/b] • Notice: [b]%.2f min[/b]

[b]SCIENTIFIC & OPERATIONAL AUDIT:[/b]
• [color=#38bdf8]Target Orbit:[/color] Educational 3D Parametric Halo Orbit around Sun-Earth L1 (Closed 3D model: x, y, z; ~1.5M km Sunward; simplified educational visualization).
• [color=#4ade80]Space Weather Warning Lead Time:[/color] [b]%.2f Minutes Advance Notice Delivered to Earth[/b] (Shock Speed: %.0f km/s • Baseline Distance: %.1fM km; t = d / v / 60).
• [color=#fbbf24]Stationkeeping Propellant Reserve:[/color] %.1f kg (Exceeds > 35 kg illustrative threshold; modeled ~15–30 m/s/yr educational assumption, not a guaranteed operational lifetime).
• [color=#c084fc]Subsystem Health:[/color] %.1f%% Sensor Suite Integrity (Rad-Hardened Avionics Nominal).
	• [color=#f87171]NASA Heritage:[/color] Educational design inspired by DSCOVR PlasMag instrumentation; not an operational validation.

[b]DESIGN TRADE-OFFS & REMAINING MARGINS:[/b]
	• Science return: %.1f instrument + crisis points • Payload wet mass: %.1f kg (%.1f kg below the 1,250 kg fairing limit)
• Remaining battery: %.1f Wh • Power margin: %+.1f W • Probe propellant: %.1f kg
• Selected trajectory: %s • Selected payload instruments: %d

[b]EVALUATION BREAKDOWN & SCORING PILLARS:[/b]
• [color=#fb923c]Launch & Staging (Pillar 1):[/color] %.1f / 25.0 pts
• [color=#f87171]Deep-Space Hazard Survival (Pillar 2):[/color] %.1f / 25.0 pts
• [color=#38bdf8]L1 Halo Orbit & Stationkeeping (Pillar 3):[/color] %.1f / 25.0 pts
• [color=#4ade80]Early-Warning Telemetry Delivery (Pillar 4):[/color] %.1f / 25.0 pts
• [color=#fbbf24][b]Total Score:[/b][/color] %.1f + %.1f + %.1f + %.1f = [b]%.1f / 100.0 PTS[/b]""" % [
		str(v_cfg.get("stage1_engine", "eng_hydrolox_quad")),
		str(p_cfg.get("bus_structure", "struct_carbon_composite")),
		float(p_cfg.get("solar_array_area_m2", 6.5)),
		str(v_cfg.get("trajectory_mode", "direct_injection")),
		perk_str, str(perk.get("summary", "")),
		waiver_str, float(l_tel.get("structural_stress_pct", 0.0)), float(l_tel.get("trajectory_error_pct", 0.0)),
		shield_mode_str, float(c_res.get("equipment_degradation_pct", 0.0)), crisis_temp, crisis_batt,
		float(l1_tel.get("halo_stability_pct", 99.0)), packet_status, lead_time,
		lead_time, shock_speed, l1_dist / 1000000.0,
		rem_fuel, equip_health,
		science_score, payload_mass, mass_margin, power_remaining, power_margin, rem_fuel,
		str(Helios4CampaignData.vehicle_config.get("trajectory_mode", "direct_injection")), Helios4CampaignData.probe_config.get("instruments", {}).size(),
		p1, p2, p3, p4,
		p1, p2, p3, p4, total_score
	]

	var names = Helios4CampaignData.team_player_names
	var prop_name = names.get(Helios4CampaignData.ROLE_PROPULSION, "Specialist 1")
	var struct_name = names.get(Helios4CampaignData.ROLE_STRUCTURAL, "Specialist 2")
	var astro_name = names.get(Helios4CampaignData.ROLE_ASTROGATOR, "Specialist 3")
	var sys_name = names.get(Helios4CampaignData.ROLE_SYSTEMS, "Specialist 4")
	
	var prop_decisions: Array = []
	var struct_decisions: Array = []
	var astro_decisions: Array = []
	var sys_decisions: Array = []
	
	for d in Helios4CampaignData.team_decision_log:
		var role = d.get("role", "")
		var desc = d.get("description", "")
		match role:
			Helios4CampaignData.ROLE_PROPULSION:
				prop_decisions.append(desc)
			Helios4CampaignData.ROLE_STRUCTURAL:
				struct_decisions.append(desc)
			Helios4CampaignData.ROLE_ASTROGATOR:
				astro_decisions.append(desc)
			Helios4CampaignData.ROLE_SYSTEMS:
				sys_decisions.append(desc)
				
	var prop_extra = (" [i]Logged: " + prop_decisions[-1] + "[/i]") if not prop_decisions.is_empty() else ""
	var struct_extra = (" [i]Logged: " + struct_decisions[-1] + "[/i]") if not struct_decisions.is_empty() else ""
	var astro_extra = (" [i]Logged: " + astro_decisions[-1] + "[/i]") if not astro_decisions.is_empty() else ""
	var sys_extra = (" [i]Logged: " + sys_decisions[-1] + "[/i]") if not sys_decisions.is_empty() else ""

	team_report_text.text = """[b]COOPERATIVE 4-OFFICER TEAM CONTRIBUTION REPORT:[/b]
• [color=#fb923c]Propulsion Engineer [%s]:[/color] Controlled multi-stage ascent throttle, executed staging separation, and isolated damaged propellant manifold during micrometeoroid strike.%s
• [color=#4ade80]Structural Architect [%s]:[/color] Maintained aerodynamic static margin > 1.2 calibers, monitored dynamic pressure through Max-Q (32 kPa), and audited spacecraft hull stress.%s
• [color=#38bdf8]Astrogator [%s]:[/color] Programmed trajectory pitch schedule, calculated MCC-1 mid-course burn, and executed halo-orbit insertion capture at Sun-Earth L1.%s
• [color=#e879f9]Systems Officer [%s]:[/color] Balanced solar power generation vs electrical load, managed radiation safe mode, deployed magnetometer boom, and beamed the early-warning telemetry packet.%s""" % [
		prop_name, prop_extra,
		struct_name, struct_extra,
		astro_name, astro_extra,
		sys_name, sys_extra
	]

func _on_save_and_complete_pressed() -> void:
	if Helios4CampaignData.advance_to_stage(Helios4CampaignData.Stage.CAMPAIGN_COMPLETED):
		save_btn.text = "★ CAMPAIGN PROGRESS SAVED!"
		save_btn.disabled = true
		print("[Debrief] HELIOS-4 campaign completed and persisted to user://helios4_campaign.json")
	else:
		save_btn.text = "SAVE FAILED — CLICK TO RETRY"
		save_btn.disabled = false
		if outcome_lbl:
			outcome_lbl.text = "DEBRIEF COMPLETE — SAVE FAILED; YOUR MISSION REPORT REMAINS OPEN"
			outcome_lbl.add_theme_color_override("font_color", Color(1.0, 0.62, 0.28))

func _on_replay_pressed() -> void:
	Helios4CampaignData.reset_campaign()
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.PHASE_1_HANGAR, get_tree())

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://margin/scenes/main_menu.tscn")
