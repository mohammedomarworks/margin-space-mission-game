class_name MissionBriefingController
extends Control

const MissionScenario = preload("res://margin/data/mission_scenario.gd")
const TeamData = preload("res://margin/data/team_data.gd")

func _ready() -> void:
	if has_node("%ScenarioLunarBtn"):
		var lunar_btn = get_node("%ScenarioLunarBtn") as Button
		if not lunar_btn.pressed.is_connected(_on_lunar_selected):
			lunar_btn.pressed.connect(_on_lunar_selected)
	
	if has_node("%ScenarioEarthBtn"):
		var earth_btn = get_node("%ScenarioEarthBtn") as Button
		if not earth_btn.pressed.is_connected(_on_earth_selected):
			earth_btn.pressed.connect(_on_earth_selected)
			
	if has_node("%TeamSoloBtn"):
		get_node("%TeamSoloBtn").pressed.connect(func(): _set_team_players(1))
	if has_node("%Team2PBtn"):
		get_node("%Team2PBtn").pressed.connect(func(): _set_team_players(2))
	if has_node("%Team3PBtn"):
		get_node("%Team3PBtn").pressed.connect(func(): _set_team_players(3))
	if has_node("%Team4PBtn"):
		get_node("%Team4PBtn").pressed.connect(func(): _set_team_players(4))
			
	_refresh_briefing()
	_refresh_team_ui()

func _set_team_players(count: int) -> void:
	TeamData.configure_team(count)
	_refresh_team_ui()

func _refresh_team_ui() -> void:
	var count = TeamData.player_count
	var btns = {
		1: "%TeamSoloBtn",
		2: "%Team2PBtn",
		3: "%Team3PBtn",
		4: "%Team4PBtn"
	}
	for c in btns:
		if has_node(btns[c]):
			var btn = get_node(btns[c]) as Button
			btn.modulate = Color(0.2, 1.0, 0.5, 1.0) if c == count else Color(0.6, 0.7, 0.8, 1.0)
			
	if has_node("%TeamStatusLabel"):
		var lbl = get_node("%TeamStatusLabel") as Label
		if count == 1:
			lbl.text = "Flight Crew: Solo Operator (Leading All 4 Disciplines)"
		elif count == 2:
			lbl.text = "Flight Crew: 2 Players [P1: Director & Flight | P2: Systems & Science]"
		elif count == 3:
			lbl.text = "Flight Crew: 3 Players [P1: Director & Flight | P2: Systems | P3: Science]"
		else:
			lbl.text = "Flight Crew: 4 Players [P1: Director | P2: Systems | P3: Science | P4: Flight/Comms]"

func _on_lunar_selected() -> void:
	MissionScenario.set_active_scenario("lunar_south_pole")
	_refresh_briefing()

func _on_earth_selected() -> void:
	MissionScenario.set_active_scenario("earth_climate_sentinel")
	_refresh_briefing()

func _refresh_briefing() -> void:
	var s: MissionScenario = MissionScenario.get_active_scenario()
	var is_earth: bool = (s.id == "earth_climate_sentinel")
	
	if has_node("%ScenarioLunarBtn"):
		var lunar_btn = get_node("%ScenarioLunarBtn") as Button
		lunar_btn.modulate = Color(0.6, 0.7, 0.8, 1.0) if is_earth else Color(0.2, 1.0, 0.5, 1.0)
		lunar_btn.text = "MISSION 1: LUNAR SOUTH POLE (LSP-01)" + ("" if is_earth else " [ACTIVE]")
		
	if has_node("%ScenarioEarthBtn"):
		var earth_btn = get_node("%ScenarioEarthBtn") as Button
		earth_btn.modulate = Color(0.2, 1.0, 0.5, 1.0) if is_earth else Color(0.6, 0.7, 0.8, 1.0)
		earth_btn.text = "MISSION 2: EARTH CLIMATE SENTINEL (ECS-01)" + (" [ACTIVE]" if is_earth else "")

	if has_node("%Badge"):
		var badge = get_node("%Badge") as Label
		badge.text = "MARGIN // FLIGHT READINESS DOSSIER — MISSION ID: %s" % s.code
		
	if has_node("%MissionTitle"):
		var title_lbl = get_node("%MissionTitle") as Label
		title_lbl.text = s.title
		
	if has_node("%MissionSubtitle"):
		var sub_lbl = get_node("%MissionSubtitle") as Label
		sub_lbl.text = s.subtitle
		
	if has_node("%BudgetValue"):
		var budget_lbl = get_node("%BudgetValue") as Label
		budget_lbl.text = "$%.1fM" % s.budget_cap_m
		
	if has_node("%MassValue"):
		var mass_lbl = get_node("%MassValue") as Label
		mass_lbl.text = "%.1f kg" % s.mass_limit_kg
		
	if has_node("%DurationValue"):
		var dur_lbl = get_node("%DurationValue") as Label
		dur_lbl.text = "%d Days" % s.duration_days
		
	if has_node("%OrbitValue"):
		var orbit_lbl = get_node("%OrbitValue") as Label
		orbit_lbl.text = "705 km SSO" if is_earth else "100 km Polar"
		
	if has_node("%OrbitSub"):
		var orbit_sub = get_node("%OrbitSub") as Label
		orbit_sub.text = "i = 98.2° | 98.8 min period" if is_earth else "i = 90° | 118 min period"
		
	if has_node("%Sec1Text"):
		var sec1_lbl = get_node("%Sec1Text") as Label
		sec1_lbl.text = s.scientific_goal
		
	if has_node("%CautionText"):
		var caution_lbl = get_node("%CautionText") as Label
		caution_lbl.text = s.scientific_caution

func _on_proceed_to_workshop_pressed() -> void:
	get_tree().change_scene_to_file("res://margin/scenes/workshop.tscn")

func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://margin/scenes/main_menu.tscn")
