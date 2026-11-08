class_name Helios4PrologueController
extends Node3D

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")
const DonkiService = preload("res://margin/data/donki_service.gd")

@onready var sun_mesh: MeshInstance3D = $SunMesh
@onready var donki_modal: PanelContainer = %DonkiModal

var _flare_time: float = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if donki_modal and donki_modal.visible:
			donki_modal.visible = false

func _ready() -> void:
	if donki_modal:
		donki_modal.visible = false
		
	var proceed_btn = find_child("ProceedBtn", true, false)
	if proceed_btn:
		proceed_btn.pressed.connect(_on_proceed_pressed)
		
	var donki_btn = find_child("DonkiBtn", true, false)
	if donki_btn:
		donki_btn.pressed.connect(_on_donki_pressed)
		
	var back_btn = find_child("BackToMenuBtn", true, false)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
		
	var close_donki_btn = find_child("CloseDonkiBtn", true, false)
	if close_donki_btn:
		close_donki_btn.pressed.connect(func(): donki_modal.visible = false)

	get_tree().process_frame.connect(func():
		if proceed_btn: print("[Prologue] ProceedBtn global_rect: ", proceed_btn.get_global_rect(), " center: ", proceed_btn.get_global_rect().get_center())
		if donki_btn: print("[Prologue] DonkiBtn global_rect: ", donki_btn.get_global_rect(), " center: ", donki_btn.get_global_rect().get_center())
	, CONNECT_ONE_SHOT)

func _process(delta: float) -> void:
	_flare_time += delta
	if sun_mesh and sun_mesh.material_override:
		var pulse: float = 3.5 + 0.8 * sin(_flare_time * 2.0)
		sun_mesh.material_override.set("emission_energy_multiplier", pulse)

func _on_proceed_pressed() -> void:
	print("[Prologue] Advancing to Stage 1: Team Assignment")
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.TEAM_ASSIGNMENT, get_tree())

func _on_donki_pressed() -> void:
	if not donki_modal:
		return
	donki_modal.visible = true
	var close_donki_btn = find_child("CloseDonkiBtn", true, false)
	if close_donki_btn:
		print("[Prologue] CloseDonkiBtn center: ", close_donki_btn.get_global_rect().get_center())
	_populate_donki_modal()

func _populate_donki_modal() -> void:
	var list_container = donki_modal.find_child("DonkiEventList", true, false)
	if not list_container:
		return
	for c in list_container.get_children():
		c.queue_free()
		
	for ev in DonkiService.OFFLINE_EVENT_CATALOG:
		var panel := PanelContainer.new()
		var p_style := StyleBoxFlat.new()
		p_style.bg_color = Color(0.08, 0.11, 0.16, 0.9)
		p_style.border_color = Color(0.25, 0.35, 0.5, 0.6)
		p_style.set_border_width_all(1)
		p_style.set_corner_radius_all(4)
		p_style.content_margin_left = 12
		p_style.content_margin_top = 8
		p_style.content_margin_right = 12
		p_style.content_margin_bottom = 8
		panel.add_theme_stylebox_override("panel", p_style)
		
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		
		var title_lbl := Label.new()
		title_lbl.text = "[%s] %s" % [ev["type"], ev["label"]]
		title_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
		title_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(title_lbl)
		
		var detail_lbl := Label.new()
		detail_lbl.text = "CME Speed: %.0f km/s • Risk: %s • Lead Time: ~%.0f min\nSource: %s\n%s" % [
			ev["cme_speed_kms"], ev["educational_risk_level"], ev["transit_time_hours"] * 60.0 / 24.0, ev["source"], ev["impact_description"]
		]
		detail_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
		detail_lbl.add_theme_font_size_override("font_size", 10)
		detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(detail_lbl)
		
		panel.add_child(vbox)
		list_container.add_child(panel)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://margin/scenes/main_menu.tscn")
