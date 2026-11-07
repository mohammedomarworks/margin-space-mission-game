class_name WorkshopController
extends Node3D

const MissionScenario = preload("res://margin/data/mission_scenario.gd")
const TeamData = preload("res://margin/data/team_data.gd")

@onready var spacecraft: Spacecraft3D = $Spacecraft3D
@onready var orbit_cam: OrbitCamera = $OrbitCamera
@onready var sun_light: DirectionalLight3D = $SunLight

# UI Nodes
@onready var top_mass_label: Label = %TopMassLabel
@onready var top_cost_label: Label = %TopCostLabel
@onready var top_power_label: Label = %TopPowerLabel
@onready var top_science_label: Label = %TopScienceLabel

@onready var category_button_container: VBoxContainer = %CategoryButtonContainer
@onready var component_card_container: VBoxContainer = %ComponentCardContainer
@onready var active_cat_title: Label = %ActiveCategoryTitle

# 6 Resource UI Nodes
@onready var mass_val_label: Label = %MassValLabel
@onready var mass_margin_label: Label = %MassMarginLabel
@onready var mass_bar: ProgressBar = %MassBar

@onready var power_val_label: Label = %PowerValLabel
@onready var power_margin_label: Label = %PowerMarginLabel
@onready var power_bar: ProgressBar = %PowerBar

@onready var budget_val_label: Label = %BudgetValLabel
@onready var budget_margin_label: Label = %BudgetMarginLabel
@onready var budget_bar: ProgressBar = %BudgetBar

@onready var data_val_label: Label = %DataValLabel
@onready var data_margin_label: Label = %DataMarginLabel
@onready var data_bar: ProgressBar = %DataBar

@onready var comms_val_label: Label = %CommsValLabel
@onready var comms_margin_label: Label = %CommsMarginLabel
@onready var comms_bar: ProgressBar = %CommsBar

@onready var lifetime_val_label: Label = %LifetimeValLabel
@onready var lifetime_margin_label: Label = %LifetimeMarginLabel
@onready var lifetime_bar: ProgressBar = %LifetimeBar

# Qualification Status Box
@onready var qual_status_panel: PanelContainer = %QualStatusPanel
@onready var qual_title_label: Label = %QualTitleLabel
@onready var qual_desc_label: Label = %QualDescLabel
@onready var qual_science_label: Label = %QualScienceLabel

# Trade-Off Echo UI Nodes
@onready var echo_panel: PanelContainer = %TradeOffEchoPanel
@onready var echo_title: Label = %EchoTitle
@onready var echo_category: Label = %EchoCategory
@onready var echo_positives_container: VBoxContainer = %EchoPositivesContainer
@onready var echo_negatives_container: VBoxContainer = %EchoNegativesContainer
@onready var echo_insight_label: Label = %EchoInsightLabel

var state: SpacecraftState
var selected_category: ComponentDatabase.Category = ComponentDatabase.Category.STRUCTURE
var _category_buttons: Dictionary = {}
var _echo_hide_timer: float = 0.0

func _ready() -> void:
	state = SpacecraftState.new()
	state.configuration_changed.connect(_on_configuration_changed)
	state.telemetry_updated.connect(_on_telemetry_updated)
	
	_build_category_buttons()
	_select_category(ComponentDatabase.Category.STRUCTURE)
	
	# Initial spacecraft 3D build
	spacecraft.update_spacecraft(state.current_components)
	
	# Initial telemetry update
	_update_telemetry_ui(state.calculate_telemetry())
	
	# Initially hide echo panel until a component is swapped
	echo_panel.visible = false

func _process(delta: float) -> void:
	if echo_panel.visible and _echo_hide_timer > 0.0:
		_echo_hide_timer -= delta
		if _echo_hide_timer <= 0.0:
			_hide_echo_panel()

func _build_category_buttons() -> void:
	for child in category_button_container.get_children():
		category_button_container.remove_child(child)
		child.queue_free()
	_category_buttons.clear()
	
	for cat in ComponentDatabase.Category.values():
		var btn := Button.new()
		var cat_name: String = ComponentDatabase.get_category_name(cat)
		btn.text = cat_name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(func(): _select_category(cat))
		category_button_container.add_child(btn)
		_category_buttons[cat] = btn

func _select_category(cat: ComponentDatabase.Category) -> void:
	selected_category = cat
	active_cat_title.text = ComponentDatabase.get_category_name(cat).to_upper()
	
	# Highlight selected category button
	for c in _category_buttons:
		var btn: Button = _category_buttons[c]
		if c == cat:
			btn.add_theme_color_override("font_color", Color(0.22, 0.74, 0.96))
		else:
			btn.remove_theme_color_override("font_color")
	
	# Glide orbit camera to focus on this subsystem
	var focal_pos: Vector3 = spacecraft.get_category_position(cat)
	orbit_cam.focus_on(focal_pos, 3.6)
	
	_populate_component_cards()

func _populate_component_cards() -> void:
	for child in component_card_container.get_children():
		component_card_container.remove_child(child)
		child.queue_free()
	
	var components: Array = ComponentDatabase.get_components_for_category(selected_category)
	var equipped_id: String = state.get_component_id(selected_category)
	
	for comp in components:
		var card := _create_component_card(comp, comp["id"] == equipped_id)
		component_card_container.add_child(card)

func _create_component_card(comp: Dictionary, is_equipped: bool) -> PanelContainer:
	var card := PanelContainer.new()
	var style: StyleBoxFlat = MarginTheme.create_card_style(is_equipped)
	card.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)
	
	# Header Row: Name + Tier
	var h_title := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = comp.get("name", "")
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_title.add_child(name_label)
	
	var tier_label := Label.new()
	tier_label.text = comp.get("tier", "")
	tier_label.add_theme_font_size_override("font_size", 11)
	tier_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))
	h_title.add_child(tier_label)
	vbox.add_child(h_title)
	
	# Specs Grid
	var h_specs := HBoxContainer.new()
	h_specs.add_theme_constant_override("separation", 12)
	
	# Mass
	var mass_txt := Label.new()
	mass_txt.text = "Mass: %0.1f kg" % comp.get("mass_kg", 0.0)
	mass_txt.add_theme_font_size_override("font_size", 11)
	mass_txt.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
	h_specs.add_child(mass_txt)
	
	# Cost
	var cost_txt := Label.new()
	cost_txt.text = "Cost: $%0.1fM" % comp.get("cost_m", 0.0)
	cost_txt.add_theme_font_size_override("font_size", 11)
	cost_txt.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
	h_specs.add_child(cost_txt)
	
	# Power
	var p_val: float = comp.get("power_w", 0.0)
	var power_txt := Label.new()
	if p_val > 0.0:
		power_txt.text = "Power: +%0.0f W" % p_val
		power_txt.add_theme_color_override("font_color", Color(0.2, 0.85, 0.4))
	elif p_val < 0.0:
		power_txt.text = "Power: -%0.0f W" % abs(p_val)
		power_txt.add_theme_color_override("font_color", Color(0.95, 0.6, 0.2))
	else:
		power_txt.text = "Power: 0 W"
		power_txt.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	power_txt.add_theme_font_size_override("font_size", 11)
	h_specs.add_child(power_txt)
	
	# Reliability
	var rel_txt := Label.new()
	rel_txt.text = "Rel: %0.0f%%" % comp.get("reliability_pct", 95.0)
	rel_txt.add_theme_font_size_override("font_size", 11)
	rel_txt.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
	h_specs.add_child(rel_txt)
	
	# Science Score if any
	if comp.get("science_score", 0.0) > 0.0:
		var sci_txt := Label.new()
		sci_txt.text = "Sci: +%0.0f pts" % comp.get("science_score", 0.0)
		sci_txt.add_theme_font_size_override("font_size", 11)
		sci_txt.add_theme_color_override("font_color", Color(0.22, 0.74, 0.96))
		h_specs.add_child(sci_txt)
	
	vbox.add_child(h_specs)
	
	# Description
	var desc := Label.new()
	desc.text = comp.get("description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
	vbox.add_child(desc)
	
	# Key Trade-offs
	var pos_lbl := Label.new()
	pos_lbl.text = "✓ " + comp.get("tradeoff_positive", "")
	pos_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pos_lbl.add_theme_font_size_override("font_size", 11)
	pos_lbl.add_theme_color_override("font_color", Color(0.25, 0.85, 0.45))
	vbox.add_child(pos_lbl)
	
	var neg_lbl := Label.new()
	neg_lbl.text = "⚠ " + comp.get("tradeoff_negative", "")
	neg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	neg_lbl.add_theme_font_size_override("font_size", 11)
	neg_lbl.add_theme_color_override("font_color", Color(0.95, 0.55, 0.25))
	vbox.add_child(neg_lbl)
	
	# Button Row
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 28)
	if is_equipped:
		btn.text = "EQUIPPED"
		btn.disabled = true
		btn.add_theme_color_override("font_disabled_color", Color(0.22, 0.74, 0.96))
	else:
		btn.text = "SELECT COMPONENT"
		btn.pressed.connect(func():
			state.set_component(selected_category, comp["id"])
		)
	vbox.add_child(btn)
	
	return card

func _on_configuration_changed(cat: ComponentDatabase.Category, old_comp: Dictionary, new_comp: Dictionary) -> void:
	# Update 3D model
	spacecraft.update_component(cat, new_comp["id"])
	
	# Decision attribution
	var role_id: String = TeamData.ROLE_SCIENCE if cat == ComponentDatabase.Category.INSTRUMENTS else TeamData.ROLE_SYSTEMS
	TeamData.log_decision(role_id, "Spacecraft Workshop", "Equipped " + new_comp.get("name", ""), "$%0.1fM | %0.1f kg" % [new_comp.get("cost_m", 0.0), new_comp.get("mass_kg", 0.0)])
	
	# Refresh cards to update "EQUIPPED" status
	_populate_component_cards()
	
	# Trigger Signature Trade-Off Echo
	_show_trade_off_echo(cat, old_comp, new_comp)

func _show_trade_off_echo(cat: ComponentDatabase.Category, old_comp: Dictionary, new_comp: Dictionary) -> void:
	var analysis: Dictionary = TradeOffEcho.analyze_tradeoff(cat, old_comp, new_comp)
	var role_id: String = TeamData.ROLE_SCIENCE if cat == ComponentDatabase.Category.INSTRUMENTS else TeamData.ROLE_SYSTEMS
	var role_info = TeamData.get_role_info(role_id)
	var player_name = TeamData.get_player_name_for_role(role_id)
	
	echo_title.text = "TRADE-OFF ECHO: %s" % analysis["new_name"].to_upper()
	echo_category.text = "SUBSYSTEM: %s | Lead: %s [%s]" % [analysis["category_name"].to_upper(), role_info["title"], player_name]
	
	for child in echo_positives_container.get_children():
		echo_positives_container.remove_child(child)
		child.queue_free()
	for child in echo_negatives_container.get_children():
		echo_negatives_container.remove_child(child)
		child.queue_free()
	
	for pos in analysis["positives"]:
		var pill := Label.new()
		pill.text = pos
		pill.add_theme_font_size_override("font_size", 12)
		pill.add_theme_color_override("font_color", Color(0.2, 0.9, 0.45))
		echo_positives_container.add_child(pill)
	
	for neg in analysis["negatives"]:
		var pill := Label.new()
		pill.text = neg
		pill.add_theme_font_size_override("font_size", 12)
		pill.add_theme_color_override("font_color", Color(0.95, 0.5, 0.3))
		echo_negatives_container.add_child(pill)
	
	echo_insight_label.text = "AEROSPACE INSIGHT: " + analysis["insight"]
	
	# Animate smooth appearance
	echo_panel.visible = true
	echo_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(echo_panel, "modulate:a", 1.0, 0.25)
	
	_echo_hide_timer = 9.0 # Display for 9 seconds or until next swap / manual close

func _hide_echo_panel() -> void:
	var tween := create_tween()
	tween.tween_property(echo_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): echo_panel.visible = false)

func _on_telemetry_updated(t: Dictionary) -> void:
	_update_telemetry_ui(t)

func _update_telemetry_ui(t: Dictionary) -> void:
	var mass_limit: float = MissionData.get_active_mass_limit_kg()
	var budget_cap: float = MissionData.get_active_budget_cap_m()
	
	# Top bar readouts
	top_mass_label.text = "Mass: %0.1f / %0.0f kg" % [t["wet_mass_kg"], mass_limit]
	top_cost_label.text = "Cost: $%0.1fM / $%0.0fM" % [t["total_cost_m"], budget_cap]
	top_power_label.text = "Power: %+0.0f W" % t["net_power_w"]
	top_science_label.text = "Science: %0.0f pts" % t["science_score"]
	
	# 1. Mass Indicator
	mass_val_label.text = "%0.1f kg / %0.0f kg" % [t["wet_mass_kg"], mass_limit]
	var m_pct: float = t["mass_margin_pct"]
	mass_margin_label.text = "%+0.1f%% Margin" % m_pct
	mass_bar.max_value = mass_limit
	mass_bar.value = t["wet_mass_kg"]
	_set_indicator_color(mass_margin_label, mass_bar, m_pct > 15.0, m_pct >= 0.0)
	
	# 2. Power Balance Indicator
	power_val_label.text = "Sun: %+0.0f W | Eclipse DoD: %0.1f%%" % [t["net_power_w"], t["eclipse_dod_pct"]]
	var p_pct: float = t["power_margin_pct"]
	power_margin_label.text = "%+0.0f%% Margin" % p_pct
	power_bar.max_value = 100.0
	power_bar.value = clamp(100.0 - t["eclipse_dod_pct"], 0.0, 100.0)
	_set_indicator_color(power_margin_label, power_bar, t["net_power_w"] > 50.0 and t["eclipse_dod_pct"] <= 55.0, t["net_power_w"] >= 0.0 and t["eclipse_dod_pct"] <= 70.0)
	
	# 3. Budget Indicator
	budget_val_label.text = "$%0.1fM / $%0.0fM" % [t["total_cost_m"], budget_cap]
	var b_pct: float = t["budget_margin_pct"]
	budget_margin_label.text = "%+0.1f%% Margin" % b_pct
	budget_bar.max_value = budget_cap
	budget_bar.value = t["total_cost_m"]
	_set_indicator_color(budget_margin_label, budget_bar, b_pct > 10.0, b_pct >= 0.0)
	
	# 4. Data Balance Indicator
	data_val_label.text = "Gen: %0.1f / Link: %0.1f Gbit/d" % [t["data_gen_gbit_day"], t["downlink_gbit_day"]]
	var d_pct: float = t["data_margin_pct"]
	data_margin_label.text = "%+0.1f%% Margin" % d_pct
	data_bar.max_value = max(t["downlink_gbit_day"], 0.1)
	data_bar.value = t["data_gen_gbit_day"]
	_set_indicator_color(data_margin_label, data_bar, d_pct > 20.0, d_pct >= 0.0)
	
	# 5. Comms Link Margin
	comms_val_label.text = "Link: %+0.1f dB (DSN 34m)" % t["link_margin_db"]
	comms_margin_label.text = "%+0.1f dB Margin" % t["comms_effective_margin_db"]
	comms_bar.max_value = 15.0
	comms_bar.value = clamp(t["link_margin_db"], 0.0, 15.0)
	_set_indicator_color(comms_margin_label, comms_bar, t["link_margin_db"] >= 6.0, t["link_margin_db"] >= 3.0)
	
	# 6. Orbit Lifetime Margin
	lifetime_val_label.text = "%0.0f Days / 365 Req (ΔV: %0.0f m/s)" % [t["achievable_lifetime_days"], t["delta_v_ms"]]
	var l_pct: float = t["lifetime_margin_pct"]
	lifetime_margin_label.text = "%+0.0f%% Margin" % l_pct
	lifetime_bar.max_value = 500.0
	lifetime_bar.value = clamp(t["achievable_lifetime_days"], 0.0, 500.0)
	_set_indicator_color(lifetime_margin_label, lifetime_bar, l_pct > 20.0, l_pct >= 0.0)
	
	# Overall Qualification Card
	if MissionScenario.is_sandbox_active():
		qual_title_label.text = "CREATIVE SANDBOX MODE [UNRESTRICTED EXPERIMENTAL]"
		qual_title_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
		qual_desc_label.text = "All fiscal caps, mass envelopes, and flight restrictions disengaged for experimental spacecraft prototyping."
		qual_science_label.text = "Simulated Science: %0.0f pts | Bus Reliability: %0.1f%% | Wet Mass: %0.1f kg" % [
			t["science_score"], t["system_reliability_pct"], t["wet_mass_kg"]
		]
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.14, 0.05, 0.88)
		style.border_color = Color(0.95, 0.75, 0.2, 0.9)
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		qual_status_panel.add_theme_stylebox_override("panel", style)
	elif t["all_qualified"]:
		qual_title_label.text = "ENGINEERING MARGINS PASS"
		qual_title_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.45))
		qual_desc_label.text = "All mass, budget, power, comms, and orbital lifetime constraints are fully satisfied."
		qual_science_label.text = "Estimated Science Return: %0.0f points | Reliability: %0.1f%%" % [t["science_score"], t["system_reliability_pct"]]
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.22, 0.14, 0.88)
		style.border_color = Color(0.2, 0.85, 0.45, 0.9)
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		qual_status_panel.add_theme_stylebox_override("panel", style)
	else:
		qual_title_label.text = "CRITICAL MARGIN DEFICITS DETECTED"
		qual_title_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25))
		var desc: String = ""
		for d in t["deficits"]:
			desc += "• " + d + "\n"
		qual_desc_label.text = desc.strip_edges()
		qual_science_label.text = "Resolve deficits to qualify for flight launch!"
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.24, 0.08, 0.08, 0.88)
		style.border_color = Color(0.95, 0.35, 0.25, 0.9)
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		qual_status_panel.add_theme_stylebox_override("panel", style)

func _set_indicator_color(label: Label, bar: ProgressBar, is_optimal: bool, is_valid: bool) -> void:
	if is_optimal:
		label.add_theme_color_override("font_color", Color(0.25, 0.85, 0.45))
	elif is_valid:
		label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25))
	else:
		label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25))

# UI Button Callbacks
func _on_reset_build_pressed() -> void:
	state.reset_to_default()
	spacecraft.update_spacecraft(state.current_components)
	_populate_component_cards()
	orbit_cam.reset_view()

func save_sandbox_spacecraft(file_path: String = "user://sandbox_spacecraft.json") -> bool:
	return state.save_to_file(file_path)

func load_sandbox_spacecraft(file_path: String = "user://sandbox_spacecraft.json") -> bool:
	var success = state.load_from_file(file_path)
	if success:
		spacecraft.update_spacecraft(state.current_components)
		_populate_component_cards()
		_update_telemetry_ui(state.calculate_telemetry())
	return success

func _on_mission_briefing_pressed() -> void:
	get_tree().change_scene_to_file("res://margin/scenes/mission_briefing.tscn")

func _on_plan_launch_pressed() -> void:
	get_tree().change_scene_to_file("res://margin/scenes/launch_planning.tscn")

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://margin/scenes/main_menu.tscn")

func _on_reset_camera_pressed() -> void:
	orbit_cam.reset_view()

func _on_dismiss_echo_pressed() -> void:
	_hide_echo_panel()
