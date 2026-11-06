class_name LaunchPlannerController
extends Node3D

const MissionOperationsData = preload("res://margin/data/mission_operations_data.gd")

# 3D Scene Nodes
@onready var orbit_cam: OrbitCamera = $OrbitCamera
@onready var moon_mesh: MeshInstance3D = $Moon
@onready var spacecraft: Spacecraft3D = $Spacecraft3D
@onready var orbit_path_mesh: MeshInstance3D = $OrbitPathLine
@onready var sun_light: DirectionalLight3D = $SunLight

# UI Nodes - Header & Telemetry
@onready var top_mass_label: Label = %TopMassLabel
@onready var top_cost_label: Label = %TopCostLabel
@onready var top_dv_label: Label = %TopDvLabel
@onready var top_science_label: Label = %TopScienceLabel

# Selection Containers
@onready var transfer_cards_container: VBoxContainer = %TransferCardsContainer
@onready var orbit_cards_container: VBoxContainer = %OrbitCardsContainer
@onready var lv_cards_container: VBoxContainer = %LVCardsContainer

# Engineering Checklist Nodes
@onready var check_mass_status: Label = %CheckMassStatus
@onready var check_mass_detail: Label = %CheckMassDetail
@onready var check_mass_bar: ProgressBar = %CheckMassBar

@onready var check_vol_status: Label = %CheckVolStatus
@onready var check_vol_detail: Label = %CheckVolDetail
@onready var check_vol_bar: ProgressBar = %CheckVolBar

@onready var check_dim_status: Label = %CheckDimStatus
@onready var check_dim_detail: Label = %CheckDimDetail

@onready var check_prop_status: Label = %CheckPropStatus
@onready var check_prop_detail: Label = %CheckPropDetail
@onready var check_prop_bar: ProgressBar = %CheckPropBar

@onready var check_budget_status: Label = %CheckBudgetStatus
@onready var check_budget_detail: Label = %CheckBudgetDetail
@onready var check_budget_bar: ProgressBar = %CheckBudgetBar

# Launch Action & Diagnostics
@onready var launch_btn: Button = %ExecuteLaunchBtn
@onready var diagnostics_box: PanelContainer = %DiagnosticsBox
@onready var diagnostics_label: Label = %DiagnosticsLabel

# Cinematic Sequence Overlay
@onready var sequence_overlay: Control = %SequenceOverlay
@onready var seq_phase_label: Label = %SeqPhaseLabel
@onready var seq_detail_label: Label = %SeqDetailLabel
@onready var seq_progress_bar: ProgressBar = %SeqProgressBar
@onready var seq_telemetry_label: Label = %SeqTelemetryLabel

# Results Modal
@onready var results_modal: PanelContainer = %ResultsModal
@onready var result_title_label: Label = %ResultTitleLabel
@onready var result_orbit_label: Label = %ResultOrbitLabel
@onready var result_lv_label: Label = %ResultLVLabel
@onready var result_dv_label: Label = %ResultDvLabel
@onready var result_budget_label: Label = %ResultBudgetLabel
@onready var result_science_label: Label = %ResultScienceLabel

# State
static var last_selected_transfer_id: String = "transfer_low_energy"
static var last_selected_orbit_id: String = "orbit_low_circular"
static var last_selected_vehicle_id: String = "lv_commercial_medium"

var state: SpacecraftState
var selected_transfer_id: String = TransferDatabase.get_default_transfer_id()
var selected_orbit_id: String = OrbitDatabase.get_default_orbit_id()
var selected_vehicle_id: String = LaunchVehicleDatabase.get_default_vehicle_id()

var _transfer_card_nodes: Dictionary = {}
var _orbit_card_nodes: Dictionary = {}
var _lv_card_nodes: Dictionary = {}

var _orbit_anim_time: float = 0.0
var _is_launching: bool = false
var _current_validation: Dictionary = {}

# Moon radius in Godot 3D units
const MOON_RADIUS_3D: float = 2.2
# Scale factor for display altitude: 100 km ≈ 0.6 units
const ALT_SCALE: float = 0.006

func _ready() -> void:
	if SpacecraftState.active_instance != null:
		state = SpacecraftState.active_instance
	else:
		state = SpacecraftState.new()
	
	spacecraft.update_spacecraft(state.current_components)
	
	_build_transfer_cards()
	_build_orbit_cards()
	_build_lv_cards()
	_update_header_telemetry()
	_update_3d_orbit_path()
	_run_validation()
	
	sequence_overlay.visible = false
	results_modal.visible = false

func _process(delta: float) -> void:
	if not _is_launching:
		_animate_orbit(delta)

func _animate_orbit(delta: float) -> void:
	_orbit_anim_time += delta * 0.4
	var orb: Dictionary = OrbitDatabase.get_orbit(selected_orbit_id)
	var geom: String = orb.get("geometry_type", "circular_low")
	
	var peri_r: float = MOON_RADIUS_3D + (orb.get("perilune_km", 100.0) * ALT_SCALE)
	var apo_r: float = MOON_RADIUS_3D + (orb.get("apolune_km", 100.0) * ALT_SCALE)
	
	# Polar orbit in Y-Z plane
	var angle: float = _orbit_anim_time
	var r: float
	if geom == "elliptical":
		var a: float = (peri_r + apo_r) * 0.5
		var e: float = (apo_r - peri_r) / (apo_r + peri_r)
		r = a * (1.0 - e * e) / (1.0 + e * sin(angle))
	else:
		r = peri_r
	
	var y: float = sin(angle) * r
	var z: float = cos(angle) * r
	spacecraft.position = Vector3(0.0, y, z)
	
	# Point nadir towards Moon center (Vector3.ZERO)
	spacecraft.look_at(Vector3.ZERO, Vector3.RIGHT)

func _update_3d_orbit_path() -> void:
	var orb: Dictionary = OrbitDatabase.get_orbit(selected_orbit_id)
	var geom: String = orb.get("geometry_type", "circular_low")
	
	var peri_r: float = MOON_RADIUS_3D + (orb.get("perilune_km", 100.0) * ALT_SCALE)
	var apo_r: float = MOON_RADIUS_3D + (orb.get("apolune_km", 100.0) * ALT_SCALE)
	
	var imm: ImmediateMesh
	if orbit_path_mesh.mesh is ImmediateMesh:
		imm = orbit_path_mesh.mesh as ImmediateMesh
		imm.clear_surfaces()
	else:
		imm = ImmediateMesh.new()
		orbit_path_mesh.mesh = imm
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.22, 0.74, 0.96)
	orbit_path_mesh.material_override = mat
	
	imm.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var segments: int = 72
	for i in range(segments + 1):
		var theta: float = float(i) * TAU / float(segments)
		var r: float
		if geom == "elliptical":
			var a: float = (peri_r + apo_r) * 0.5
			var e: float = (apo_r - peri_r) / (apo_r + peri_r)
			r = a * (1.0 - e * e) / (1.0 + e * sin(theta))
		else:
			r = peri_r
		
		var y: float = sin(theta) * r
		var z: float = cos(theta) * r
		imm.surface_add_vertex(Vector3(0.0, y, z))
	imm.surface_end()

# --- Transfer Strategy Selection ---

func _build_transfer_cards() -> void:
	for child in transfer_cards_container.get_children():
		transfer_cards_container.remove_child(child)
		child.queue_free()
	_transfer_card_nodes.clear()
	
	var all_transfers = TransferDatabase.get_all_transfers()
	for t_id in all_transfers:
		var trans: Dictionary = all_transfers[t_id]
		var card := _create_transfer_card(trans)
		transfer_cards_container.add_child(card)
		_transfer_card_nodes[t_id] = card

func _create_transfer_card(trans: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var is_sel: bool = (trans["id"] == selected_transfer_id)
	card.add_theme_stylebox_override("panel", MarginTheme.create_card_style(is_sel))
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)
	
	# Title Row
	var h_title := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = trans["name"]
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_title.add_child(name_lbl)
	
	var tag_lbl := Label.new()
	tag_lbl.text = trans["tag"]
	tag_lbl.add_theme_font_size_override("font_size", 10)
	tag_lbl.add_theme_color_override("font_color", Color(0.22, 0.74, 0.96))
	h_title.add_child(tag_lbl)
	vbox.add_child(h_title)
	
	# Specs Grid
	var specs_lbl := Label.new()
	specs_lbl.text = "Transit: %s | 100km LOI Ref: %0.1f m/s\nThruster Constraint: %s" % [
		trans["duration_desc"], trans["loi_ref_100km_ms"], trans["thrust_requirement_text"]
	]
	specs_lbl.add_theme_font_size_override("font_size", 10)
	specs_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
	vbox.add_child(specs_lbl)
	
	# Trade-off note
	var trade_lbl := Label.new()
	trade_lbl.text = trans["educational_tradeoff"]
	trade_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trade_lbl.add_theme_font_size_override("font_size", 10)
	trade_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
	vbox.add_child(trade_lbl)
	
	# Citation Note (Muted)
	var cite_lbl := Label.new()
	cite_lbl.text = "Citation: " + trans["jpl_citation"]
	cite_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cite_lbl.add_theme_font_size_override("font_size", 9)
	cite_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	vbox.add_child(cite_lbl)
	
	# Select Button
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 26)
	btn.add_theme_font_size_override("font_size", 11)
	if is_sel:
		btn.text = "SELECTED STRATEGY"
		btn.disabled = true
		btn.add_theme_color_override("font_disabled_color", Color(0.22, 0.74, 0.96))
	else:
		btn.text = "SELECT STRATEGY"
		btn.pressed.connect(func(): _select_transfer(trans["id"]))
	vbox.add_child(btn)
	
	return card

func _select_transfer(trans_id: String) -> void:
	selected_transfer_id = trans_id
	last_selected_transfer_id = trans_id
	_build_transfer_cards()
	_build_orbit_cards() # Rebuild orbit cards to reflect updated required ΔV
	_run_validation()

# --- Orbit Selection ---

func _build_orbit_cards() -> void:
	for child in orbit_cards_container.get_children():
		orbit_cards_container.remove_child(child)
		child.queue_free()
	_orbit_card_nodes.clear()
	
	var all_orbits = OrbitDatabase.get_all_orbits()
	for o_id in all_orbits:
		var orb: Dictionary = all_orbits[o_id]
		var card := _create_orbit_card(orb)
		orbit_cards_container.add_child(card)
		_orbit_card_nodes[o_id] = card

func _create_orbit_card(orb: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var is_sel: bool = (orb["id"] == selected_orbit_id)
	card.add_theme_stylebox_override("panel", MarginTheme.create_card_style(is_sel))
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)
	
	# Title Row
	var h_title := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = orb["name"]
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_title.add_child(name_lbl)
	
	var tag_lbl := Label.new()
	tag_lbl.text = orb["tag"]
	tag_lbl.add_theme_font_size_override("font_size", 10)
	tag_lbl.add_theme_color_override("font_color", Color(0.22, 0.74, 0.96))
	h_title.add_child(tag_lbl)
	vbox.add_child(h_title)
	
	# Specs Grid (Dynamically updated for selected transfer strategy)
	var loi_dv: float = OrbitDatabase.get_loi_delta_v(orb["id"], selected_transfer_id)
	var req_dv: float = OrbitDatabase.get_required_delta_v(orb["id"], selected_transfer_id)
	var mcc_dv: float = orb.get("mcc_delta_v_ms", 20.0)
	var sk_dv: float = orb.get("stationkeeping_delta_v_ms", 150.0)
	
	var specs_lbl := Label.new()
	specs_lbl.text = "Alt: %0.0f-%0.0f km | Period: %0.0f min | Max Eclipse: %0.0f min\nReq ΔV: %0.0f m/s (%0.0f MCC + %0.1f LOI + %0.0f Stationkeeping)" % [
		orb["perilune_km"], orb["apolune_km"], orb["period_min"], orb["max_eclipse_min"],
		req_dv, mcc_dv, loi_dv, sk_dv
	]
	specs_lbl.add_theme_font_size_override("font_size", 10)
	specs_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
	vbox.add_child(specs_lbl)
	
	# Trade-off note
	var trade_lbl := Label.new()
	trade_lbl.text = orb["educational_tradeoff"]
	trade_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trade_lbl.add_theme_font_size_override("font_size", 10)
	trade_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
	vbox.add_child(trade_lbl)
	
	# Select Button
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 26)
	btn.add_theme_font_size_override("font_size", 11)
	if is_sel:
		btn.text = "SELECTED ORBIT"
		btn.disabled = true
		btn.add_theme_color_override("font_disabled_color", Color(0.22, 0.74, 0.96))
	else:
		btn.text = "SELECT ORBIT"
		btn.pressed.connect(func(): _select_orbit(orb["id"]))
	vbox.add_child(btn)
	
	return card

func _select_orbit(orb_id: String) -> void:
	selected_orbit_id = orb_id
	last_selected_orbit_id = orb_id
	_update_3d_orbit_path()
	_build_orbit_cards()
	_run_validation()

# --- Launch Vehicle Selection ---

func _build_lv_cards() -> void:
	for child in lv_cards_container.get_children():
		lv_cards_container.remove_child(child)
		child.queue_free()
	_lv_card_nodes.clear()
	
	var all_v = LaunchVehicleDatabase.get_all_vehicles()
	for v_id in all_v:
		var lv: Dictionary = all_v[v_id]
		var card := _create_lv_card(lv)
		lv_cards_container.add_child(card)
		_lv_card_nodes[v_id] = card

func _create_lv_card(lv: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var is_sel: bool = (lv["id"] == selected_vehicle_id)
	card.add_theme_stylebox_override("panel", MarginTheme.create_card_style(is_sel))
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)
	
	# Header
	var h_title := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = lv["name"]
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_title.add_child(name_lbl)
	
	var cost_lbl := Label.new()
	cost_lbl.text = "$%0.1fM (Est.)" % lv["launch_cost_m"]
	cost_lbl.tooltip_text = "Educational scenario estimate: Illustrative model for engineering trade-offs; not a commercial or NASA quote."
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_lbl.add_theme_color_override("font_color", Color(0.22, 0.74, 0.96))
	h_title.add_child(cost_lbl)
	vbox.add_child(h_title)
	
	# Key capabilities
	var caps := Label.new()
	caps.text = "TLI Payload Cap: %0.0f kg | Fairing: %0.2fm ⌀ × %0.2fm H (%0.1f m³) | Rel: %0.1f%%" % [
		lv["tli_payload_capacity_kg"], lv["fairing_max_diameter_m"], lv["fairing_max_height_m"],
		lv["fairing_volume_m3"], lv["reliability_pct"]
	]
	caps.add_theme_font_size_override("font_size", 10)
	caps.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
	vbox.add_child(caps)
	
	# Injection capability distinction
	var role_lbl := Label.new()
	role_lbl.text = "Role: " + lv["injection_role"]
	role_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role_lbl.add_theme_font_size_override("font_size", 10)
	role_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
	vbox.add_child(role_lbl)
	
	# Button
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 26)
	btn.add_theme_font_size_override("font_size", 11)
	if is_sel:
		btn.text = "SELECTED LAUNCHER"
		btn.disabled = true
		btn.add_theme_color_override("font_disabled_color", Color(0.22, 0.74, 0.96))
	else:
		btn.text = "SELECT LAUNCHER"
		btn.pressed.connect(func(): _select_vehicle(lv["id"]))
	vbox.add_child(btn)
	
	return card

func _select_vehicle(v_id: String) -> void:
	selected_vehicle_id = v_id
	last_selected_vehicle_id = v_id
	_build_lv_cards()
	_run_validation()

func _update_header_telemetry() -> void:
	var t: Dictionary = state.calculate_telemetry()
	top_mass_label.text = "Wet Mass: %0.1f kg" % t["wet_mass_kg"]
	top_cost_label.text = "Spacecraft: $%0.1fM" % t["total_cost_m"]
	top_dv_label.text = "Onboard ΔV: %0.0f m/s" % t["delta_v_ms"]
	top_science_label.text = "Science Score: %0.0f pts" % t["science_score"]

func _run_validation() -> void:
	var t: Dictionary = state.calculate_telemetry()
	var trans: Dictionary = TransferDatabase.get_transfer(selected_transfer_id)
	var orb: Dictionary = OrbitDatabase.get_orbit(selected_orbit_id)
	var lv: Dictionary = LaunchVehicleDatabase.get_vehicle(selected_vehicle_id)
	
	var wet_mass: float = t["wet_mass_kg"]
	var tli_cap: float = lv["tli_payload_capacity_kg"]
	var stowed_vol: float = t.get("stowed_volume_m3", 1.35)
	var fairing_vol: float = lv["fairing_volume_m3"]
	var stowed_diam: float = t.get("stowed_diameter_m", 1.20)
	var fairing_diam: float = lv["fairing_max_diameter_m"]
	var stowed_h: float = t.get("stowed_height_m", 1.45)
	var fairing_h: float = lv["fairing_max_height_m"]
	var onboard_dv: float = t["delta_v_ms"]
	var req_dv: float = OrbitDatabase.get_required_delta_v(selected_orbit_id, selected_transfer_id)
	var loi_dv: float = OrbitDatabase.get_loi_delta_v(selected_orbit_id, selected_transfer_id)
	var mcc_dv: float = orb.get("mcc_delta_v_ms", 20.0)
	var sk_dv: float = orb.get("stationkeeping_delta_v_ms", 150.0)
	var total_mission_cost: float = t["total_cost_m"] + lv["launch_cost_m"]
	var budget_cap: float = MissionData.SCENARIO_BUDGET_CAP_M
	
	# 1. Mass Check
	var pass_mass: bool = wet_mass <= tli_cap
	var mass_margin_pct: float = ((tli_cap - wet_mass) / tli_cap) * 100.0
	check_mass_status.text = "PASS (+%0.1f%%)" % mass_margin_pct if pass_mass else "FAIL (%+0.1f%%)" % mass_margin_pct
	check_mass_status.add_theme_color_override("font_color", Color(0.2, 0.85, 0.45) if pass_mass else Color(0.95, 0.35, 0.25))
	check_mass_detail.text = "%0.1f kg wet / %0.0f kg TLI cap" % [wet_mass, tli_cap]
	check_mass_bar.max_value = tli_cap
	check_mass_bar.value = wet_mass
	
	# 2. Volume Check
	var pass_vol: bool = stowed_vol <= fairing_vol
	var vol_margin_pct: float = ((fairing_vol - stowed_vol) / fairing_vol) * 100.0
	check_vol_status.text = "PASS (+%0.0f%%)" % vol_margin_pct if pass_vol else "FAIL (%+0.0f%%)" % vol_margin_pct
	check_vol_status.add_theme_color_override("font_color", Color(0.2, 0.85, 0.45) if pass_vol else Color(0.95, 0.35, 0.25))
	check_vol_detail.text = "%0.2f m³ stowed / %0.2f m³ fairing" % [stowed_vol, fairing_vol]
	check_vol_bar.max_value = fairing_vol
	check_vol_bar.value = stowed_vol
	
	# 3. Dimension Check
	var pass_diam: bool = stowed_diam <= fairing_diam
	var pass_h: bool = stowed_h <= fairing_h
	var pass_dim: bool = pass_diam and pass_h
	check_dim_status.text = "PASS" if pass_dim else "FAIL"
	check_dim_status.add_theme_color_override("font_color", Color(0.2, 0.85, 0.45) if pass_dim else Color(0.95, 0.35, 0.25))
	check_dim_detail.text = "%0.2fm ⌀ × %0.2fm H (Limit: %0.2fm × %0.2fm)" % [stowed_diam, stowed_h, fairing_diam, fairing_h]
	
	# 4. Propulsion Delta-V & Thrust Dynamics Check
	var prop_comp: Dictionary = state.get_component(ComponentDatabase.Category.PROPULSION)
	var is_low_thrust: bool = prop_comp.get("is_low_thrust", false)
	var requires_impulsive: bool = trans.get("requires_impulsive_thrust", false)
	
	var pass_prop_dv: bool = onboard_dv >= req_dv
	var pass_thrust: bool = true
	if requires_impulsive and is_low_thrust:
		pass_thrust = false
	
	var pass_prop_power: bool = true
	if is_low_thrust and t["net_power_w"] < 0.0:
		pass_prop_power = false
	
	var pass_prop: bool = pass_prop_dv and pass_thrust and pass_prop_power
	var dv_margin_pct: float = ((onboard_dv - req_dv) / max(req_dv, 1.0)) * 100.0
	var remaining_dv_val: float = onboard_dv - req_dv
	
	if pass_prop:
		check_prop_status.text = "PASS (+%0.0f%%)" % dv_margin_pct
		check_prop_status.add_theme_color_override("font_color", Color(0.2, 0.85, 0.45))
		check_prop_detail.text = "%0.0f m/s onboard / %0.0f m/s req (%0.0f MCC + %0.1f LOI + %0.0f SK) | +%0.0f m/s reserve" % [
			onboard_dv, req_dv, mcc_dv, loi_dv, sk_dv, remaining_dv_val
		]
	else:
		if not pass_thrust:
			check_prop_status.text = "FAIL (LOW THRUST)"
		elif not pass_prop_power:
			check_prop_status.text = "FAIL (THRUST POWER)"
		else:
			check_prop_status.text = "FAIL (%+0.0f%%)" % dv_margin_pct
		check_prop_status.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25))
		check_prop_detail.text = "%0.0f m/s onboard / %0.0f m/s req (%0.0f MCC + %0.1f LOI + %0.0f SK) | -%0.0f m/s deficit" % [
			onboard_dv, req_dv, mcc_dv, loi_dv, sk_dv, abs(remaining_dv_val)
		]
	check_prop_bar.max_value = max(req_dv * 1.5, onboard_dv)
	check_prop_bar.value = onboard_dv
	
	# 5. Combined Mission Budget Check
	var pass_budget: bool = total_mission_cost <= budget_cap
	var b_margin_pct: float = ((budget_cap - total_mission_cost) / budget_cap) * 100.0
	check_budget_status.text = "PASS (+%0.1f%%)" % b_margin_pct if pass_budget else "FAIL (%+0.1f%%)" % b_margin_pct
	check_budget_status.add_theme_color_override("font_color", Color(0.2, 0.85, 0.45) if pass_budget else Color(0.95, 0.35, 0.25))
	check_budget_detail.text = "$%0.1fM total ($%0.1fM craft + $%0.1fM launch) / $%0.0fM cap" % [total_mission_cost, t["total_cost_m"], lv["launch_cost_m"], budget_cap]
	check_budget_bar.max_value = budget_cap
	check_budget_bar.value = total_mission_cost
	
	var all_pass: bool = pass_mass and pass_vol and pass_dim and pass_prop and pass_budget
	
	var blocking_issues: Array[String] = []
	if not pass_mass:
		blocking_issues.append("Mass Deficit: Spacecraft wet mass (%0.1f kg) exceeds %s TLI capacity (%0.1f kg) by %0.1f kg. Fix: Select a higher-capacity launch vehicle or reduce dry mass in the Workshop." % [
			wet_mass, lv["name"], tli_cap, wet_mass - tli_cap
		])
	if not pass_vol:
		blocking_issues.append("Volume Deficit: Stowed spacecraft volume (%0.2f m³) exceeds fairing volume (%0.2f m³) by %0.2f m³. Fix: Upgrade to a launcher with a larger fairing." % [
			stowed_vol, fairing_vol, stowed_vol - fairing_vol
		])
	if not pass_dim:
		var dim_err: String = "Dimension Deficit: Spacecraft (%0.2fm ⌀ × %0.2fm H) exceeds fairing envelope (%0.2fm ⌀ × %0.2fm H). " % [stowed_diam, stowed_h, fairing_diam, fairing_h]
		if not pass_diam:
			dim_err += "Diameter too wide (+%0.2fm). " % [stowed_diam - fairing_diam]
		if not pass_h:
			dim_err += "Height too tall (+%0.2fm). " % [stowed_h - fairing_h]
		dim_err += "Fix: Select a wider fairing launcher or reduce subsystem sizes."
		blocking_issues.append(dim_err)
	if not pass_prop:
		if not pass_thrust:
			blocking_issues.append("Propulsion Model Limitation: The miniature Hall-effect thruster (~25 mN) produces millinewton-class thrust and requires a continuous low-thrust spiral trajectory model (typically 6-12 months), which is not yet implemented in this mission. Both the Direct transfer and the 83.7-day Ballistic Lunar Transfer (BLT) require chemical propulsion for impulsive perilune capture burns. Fix: Equip Dual-Mode Chemical Propulsion in the Workshop.")
		elif not pass_prop_power:
			blocking_issues.append("Electric Thruster Power Deficit: Miniature Hall thruster draws 165 W continuous power, causing a net sunlight power deficit of %0.1f W. Fix: Equip larger solar panels in the Workshop." % abs(t["net_power_w"]))
		elif not pass_prop_dv:
			var deficit: float = req_dv - onboard_dv
			blocking_issues.append("Propulsion Deficit: Onboard ΔV (%0.0f m/s) is insufficient for %s with %s (%0.0f m/s needed: %0.0f m/s MCC + %0.1f m/s LOI + %0.0f m/s stationkeeping). Deficit: %0.0f m/s. Fix: Switch to Low-Energy Transfer (saves ~170.3 m/s LOI in cited JPL cases), select an orbit with lower capture energy (Quasi-Frozen Elliptical), or upgrade propulsion/lighten structure in the Workshop." % [
				onboard_dv, orb["name"], trans["name"], req_dv, mcc_dv, loi_dv, sk_dv, deficit
			])
	if not pass_budget:
		blocking_issues.append("Budget Deficit: Combined mission cost ($%0.1fM) exceeds scenario cap ($%0.0fM) by $%0.1fM. Fix: Select a more economical launch profile or reduce component costs in the Workshop." % [
			total_mission_cost, budget_cap, total_mission_cost - budget_cap
		])
	
	# Update Diagnostics Box & Launch Button
	if all_pass:
		diagnostics_box.visible = false
		launch_btn.disabled = false
		launch_btn.text = "EXECUTE LUNAR LAUNCH SEQUENCE →"
		launch_btn.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	else:
		diagnostics_box.visible = true
		var msg: String = "LAUNCH BLOCKED — %d CRITICAL DEFICIT(S):\n" % blocking_issues.size()
		for issue in blocking_issues:
			msg += "• " + issue + "\n"
		diagnostics_label.text = msg.strip_edges()
		launch_btn.disabled = true
		launch_btn.text = "LAUNCH BLOCKED (RESOLVE DEFICITS)"
		launch_btn.add_theme_color_override("font_disabled_color", Color(0.95, 0.45, 0.35))
	
	_current_validation = {
		"all_pass": all_pass,
		"wet_mass": wet_mass,
		"total_cost": total_mission_cost,
		"onboard_dv": onboard_dv,
		"req_dv": req_dv,
		"loi_dv": loi_dv,
		"mcc_dv": mcc_dv,
		"sk_dv": sk_dv,
		"transfer": trans,
		"orbit": orb,
		"lv": lv,
		"science_score": t["science_score"] * orb["science_multiplier"]
	}

# --- Launch Sequence Execution ---

func _on_execute_launch_pressed() -> void:
	if not _current_validation.get("all_pass", false):
		return
	
	_is_launching = true
	sequence_overlay.visible = true
	launch_btn.disabled = true
	
	var trans: Dictionary = _current_validation["transfer"]
	var orb: Dictionary = _current_validation["orbit"]
	var lv: Dictionary = _current_validation["lv"]
	var onboard_dv: float = _current_validation["onboard_dv"]
	var req_dv: float = _current_validation["req_dv"]
	var mcc_dv: float = _current_validation["mcc_dv"]
	var loi_dv: float = _current_validation["loi_dv"]
	var sk_dv: float = _current_validation["sk_dv"]
	var reserve_dv: float = onboard_dv - req_dv
	var is_direct: bool = (trans["id"] == "transfer_direct")
	
	# Phase 1: Trans-Lunar Injection (TLI)
	seq_phase_label.text = "PHASE 1: TRANS-LUNAR INJECTION (TLI)"
	if is_direct:
		seq_detail_label.text = "%s upper stage executes high-precision TLI burn. Spacecraft departs Earth on a 4.5-day direct translunar trajectory." % lv["name"]
		seq_telemetry_label.text = "Geocentric Inertial Velocity: 10.92 km/s (at TLI burnout relative to Earth center, LEO perigee alt ~185 km) | TLI Injection Accuracy: 99.8% | Fairing Jettison: COMPLETE"
	else:
		seq_detail_label.text = "%s upper stage executes precision high-apogee TLI burn toward Sun-Earth L1/L2 corridor. Spacecraft departs Earth on an ~84-day Weak Stability Boundary (WSB/BLT) ballistic lunar trajectory." % lv["name"]
		seq_telemetry_label.text = "Geocentric Inertial Velocity: 10.99 km/s (at TLI burnout relative to Earth center, LEO perigee alt ~185 km) | TLI Injection Accuracy: 99.9% | Fairing Jettison: COMPLETE"
	
	seq_progress_bar.value = 15.0
	orbit_cam.focus_on(Vector3(0.0, 0.0, 0.0), 6.5)
	
	var tween := create_tween()
	tween.tween_interval(2.0)
	
	# Phase 2: Translunar Cruise & Mid-Course Correction (MCC)
	tween.tween_callback(func():
		if is_direct:
			seq_phase_label.text = "PHASE 2: DIRECT TRANSLUNAR CRUISE & MID-COURSE CORRECTION (MCC)"
			seq_detail_label.text = "Spacecraft deploys solar arrays and establishes communications with Deep Space Network. Spacecraft thrusters execute deterministic %0.1f m/s trajectory correction (Day 2.1 of 4.5)." % mcc_dv
			seq_telemetry_label.text = "Spacecraft MCC Burn: %0.1f m/s COMPLETED | Transit Day: 2.1 / 4.5 | DSN Lock: 34m Goldstone (+8.2 dB)" % mcc_dv
		else:
			seq_phase_label.text = "PHASE 2: WEAK STABILITY BOUNDARY CRUISE & MID-COURSE CORRECTION (MCC)"
			seq_detail_label.text = "Spacecraft deploys solar arrays and navigates Sun-Earth-Moon libration corridor. Autonomous TCM burns execute deterministic %0.1f m/s trajectory corrections (Day 42.0 of 84.0)." % mcc_dv
			seq_telemetry_label.text = "Spacecraft MCC Burn: %0.1f m/s COMPLETED | Transit Day: 42.0 / 84.0 | WSB Trajectory: NOMINAL" % mcc_dv
		seq_progress_bar.value = 45.0
		orbit_cam.focus_on(Vector3(0.0, 0.0, 0.0), 5.2)
	)
	tween.tween_interval(2.2)
	
	# Phase 3: Lunar Orbit Insertion (LOI) Retro-Burn
	tween.tween_callback(func():
		if is_direct:
			seq_phase_label.text = "PHASE 3: IMPULSIVE LUNAR ORBIT INSERTION (LOI)"
			seq_detail_label.text = "Spacecraft main engine fires high-thrust impulsive retro-burn (%0.1f m/s) over lunar south pole to capture into %s (Ref: JPL direct insertion example)." % [loi_dv, orb["name"]]
			seq_telemetry_label.text = "Impulsive LOI Burn: %0.1f m/s EXPENDED | Capture Status: CONFIRMED | Periapsis Lock: 90.0° Polar" % loi_dv
		else:
			seq_phase_label.text = "PHASE 3: LOW-ENERGY LUNAR ORBIT INSERTION (LOI)"
			seq_detail_label.text = "Spacecraft executes low-energy capture retro-burn (%0.1f m/s) over lunar pole into %s (Ref: JPL 84-day WSB polar transfer example)." % [loi_dv, orb["name"]]
			seq_telemetry_label.text = "Low-Energy LOI Burn: %0.1f m/s EXPENDED | Ballistic Capture: CONFIRMED | Periapsis Lock: 90.0° Polar" % loi_dv
		seq_progress_bar.value = 80.0
		orbit_cam.focus_on(Vector3(0.0, -1.5, 0.0), 3.8)
	)
	tween.tween_interval(2.5)
	
	# Phase 4: Orbit Achieved & Commissioning Complete
	tween.tween_callback(func():
		seq_phase_label.text = "PHASE 4: TARGET ORBIT ACHIEVED — STATIONKEEPING ALLOCATED"
		seq_detail_label.text = "Spacecraft successfully captured into %s! Transit time: %s. 1-year stationkeeping allocated (%0.0f m/s game assumption). Reserve ΔV: +%0.0f m/s." % [
			orb["name"], trans["duration_desc"], sk_dv, reserve_dv
		]
		seq_progress_bar.value = 100.0
		seq_telemetry_label.text = "Target Orbit: %s | Remaining ΔV Reserve: +%0.0f m/s | Instruments: READY" % [orb["name"], reserve_dv]
		orbit_cam.focus_on(Vector3(0.0, 0.0, 0.0), 4.5)
	)
	tween.tween_interval(1.8)
	
	# Show Final Results Modal
	tween.tween_callback(func():
		_show_results_modal()
	)

func _show_results_modal() -> void:
	sequence_overlay.visible = false
	results_modal.visible = true
	
	var trans: Dictionary = _current_validation["transfer"]
	var orb: Dictionary = _current_validation["orbit"]
	var lv: Dictionary = _current_validation["lv"]
	var onboard_dv: float = _current_validation["onboard_dv"]
	var req_dv: float = _current_validation["req_dv"]
	var mcc_dv: float = _current_validation["mcc_dv"]
	var loi_dv: float = _current_validation["loi_dv"]
	var sk_dv: float = _current_validation["sk_dv"]
	var remaining_dv: float = onboard_dv - req_dv
	var budget_margin: float = MissionData.SCENARIO_BUDGET_CAP_M - _current_validation["total_cost"]
	var final_sci: float = _current_validation["science_score"]
	var total_mission_days: float = float(MissionData.SCENARIO_DURATION_DAYS) + trans["duration_days"]
	
	result_title_label.text = "LUNAR MISSION LAUNCH SUCCESSFUL"
	result_orbit_label.text = "Strategy: %s (%s) → %s (Alt: %0.0f–%0.0f km)" % [
		trans["name"], trans["duration_desc"], orb["name"], orb["perilune_km"], orb["apolune_km"]
	]
	result_lv_label.text = "Launch Vehicle: %s ($%0.1fM | Rel: %0.1f%%) | Total Mission: %0.1f Days" % [
		lv["name"], lv["launch_cost_m"], lv["reliability_pct"], total_mission_days
	]
	result_dv_label.text = "Spacecraft ΔV Breakdown: %0.0f m/s onboard - %0.0f m/s req (%0.0f MCC + %0.1f LOI + %0.0f SK) = +%0.0f m/s flight reserve" % [
		onboard_dv, req_dv, mcc_dv, loi_dv, sk_dv, remaining_dv
	]
	result_budget_label.text = "Budget Reserve: +$%0.1fM remaining under scenario limit ($%0.0fM cap)" % [budget_margin, MissionData.SCENARIO_BUDGET_CAP_M]
	result_science_label.text = "Science Performance Rating: %0.1f points (Coverage: %s)" % [
		final_sci, orb["spatial_resolution_rating"]
	]

# Navigation Callbacks
func _on_commence_operations_pressed() -> void:
	last_selected_transfer_id = selected_transfer_id
	last_selected_orbit_id = selected_orbit_id
	last_selected_vehicle_id = selected_vehicle_id
	MissionOperationsData.active_orbit_id = selected_orbit_id
	MissionOperationsData.active_transfer_id = selected_transfer_id
	MissionOperationsData.active_vehicle_id = selected_vehicle_id
	get_tree().change_scene_to_file("res://margin/scenes/mission_operations.tscn")

func _on_back_to_workshop_pressed() -> void:
	get_tree().change_scene_to_file("res://margin/scenes/workshop.tscn")

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://margin/scenes/main_menu.tscn")

func _on_reset_view_pressed() -> void:
	orbit_cam.reset_view()
