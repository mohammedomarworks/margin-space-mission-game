class_name MainMenuController
extends Node3D

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")
const ComponentDatabase = preload("res://margin/data/component_data.gd")

@onready var spacecraft: Spacecraft3D = $Spacecraft3D
@onready var orbit_cam: OrbitCamera = $OrbitCamera
@onready var how_to_play_modal: PanelContainer = %HowToPlayModal

var continue_btn: Button = null
var play_btn: Button = null
var selector_overlay: Control = null
var destination_selector: DestinationSelector = null

func _ready() -> void:
	_build_menu_starfield()
	var menu_ui := find_child("RootUI", true, false) as Control
	if menu_ui:
		menu_ui.theme = MarginTheme.get_theme()
		MarginTheme.apply_interactive_polish(menu_ui)
		Sfx.attach_hud_toggle(menu_ui)
	# Configure default 3D spacecraft for title display
	var default_cfg = ComponentDatabase.get_default_configuration()
	# Equip DSCOVR plasma boom if available for title display
	default_cfg[ComponentDatabase.Category.INSTRUMENTS] = "inst_dscovr_plasmapack"
	spacecraft.update_spacecraft(default_cfg)
	
	# Enable gentle auto-rotation for title screen
	orbit_cam.auto_rotate = true
	orbit_cam.auto_rotate_speed = 6.0 # deg/sec
	orbit_cam.distance = 3.8
	orbit_cam.pitch = 18.0
	
	if how_to_play_modal:
		how_to_play_modal.visible = false

	continue_btn = find_child("ContinueCampaignBtn", true, false) as Button
	if continue_btn:
		if not continue_btn.pressed.is_connected(_on_continue_campaign_pressed):
			continue_btn.pressed.connect(_on_continue_campaign_pressed)
		_update_continue_button_state()

	var settings_btn = find_child("SettingsHowToPlayBtn", true, false)
	if settings_btn and not settings_btn.pressed.is_connected(_on_how_to_play_pressed):
		settings_btn.pressed.connect(_on_how_to_play_pressed)

	_build_play_button(menu_ui)
	_build_selector_overlay(menu_ui)

func _update_continue_button_state() -> void:
	if not continue_btn:
		return
	if Helios4CampaignData.has_saved_campaign():
		continue_btn.disabled = false
		continue_btn.text = "CONTINUE CAMPAIGN [HELIOS-4]"
		continue_btn.tooltip_text = "Resume active HELIOS-4 campaign progress."
	else:
		continue_btn.disabled = true
		continue_btn.text = "CONTINUE CAMPAIGN (NO SAVE)"
		continue_btn.tooltip_text = "Start a New Campaign to begin."

func _on_new_campaign_pressed() -> void:
	Sfx.ui_click()
	print("[MainMenu] Launching New HELIOS-4 Campaign!")
	Helios4CampaignData.reset_campaign()
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.PROLOGUE, get_tree())

func _on_continue_campaign_pressed() -> void:
	print("[MainMenu] Continuing Saved Campaign...")
	if Helios4CampaignData.load_campaign_state():
		Helios4CampaignData.load_stage(Helios4CampaignData.current_stage, get_tree())
	else:
		var status := find_child("MDesc", true, false) as Label
		if status:
			status.text = "SAVE COULD NOT BE LOADED. Your file was not changed; choose NEW CAMPAIGN only if you want to restart."
			status.add_theme_color_override("font_color", Color(1.0, 0.62, 0.28))
		continue_btn.disabled = false
		continue_btn.text = "RETRY LOADING CAMPAIGN"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if how_to_play_modal and how_to_play_modal.visible:
			how_to_play_modal.visible = false

func _on_how_to_play_pressed() -> void:
	if how_to_play_modal:
		how_to_play_modal.visible = true

func _on_close_modal_pressed() -> void:
	if how_to_play_modal:
		how_to_play_modal.visible = false


func _build_menu_starfield() -> void:
	if has_node("MenuStarfield"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 2038
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.72, 0.84, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.5, 0.7, 1.0)
	material.emission_energy_multiplier = 1.8
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_POINTS, material)
	for _i in 520:
		var azimuth := rng.randf_range(0.0, TAU)
		var elevation := rng.randf_range(-1.35, 1.35)
		var radius := rng.randf_range(42.0, 105.0)
		mesh.surface_add_vertex(Vector3(
			radius * cos(elevation) * cos(azimuth),
		radius * sin(elevation),
		radius * cos(elevation) * sin(azimuth)
		))
	mesh.surface_end()
	var stars := MeshInstance3D.new()
	stars.name = "MenuStarfield"
	stars.mesh = mesh
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stars)


# --- ARCADE PLAY FLOW ---

func _build_play_button(root_ui: Control) -> void:
	if root_ui == null:
		return
	play_btn = Button.new()
	play_btn.name = "PlayMissionBtn"
	play_btn.text = "SELECT MISSION DESTINATION"
	play_btn.custom_minimum_size = Vector2(420, 72)
	play_btn.add_theme_font_size_override("font_size", 19)
	play_btn.focus_mode = Control.FOCUS_NONE
	play_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	play_btn.offset_left = -452.0
	play_btn.offset_top = -122.0
	play_btn.offset_right = -32.0
	play_btn.offset_bottom = -50.0
	play_btn.pressed.connect(_on_play_pressed)
	root_ui.add_child(play_btn)

	# Pulsing arcade glow
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(play_btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.75)
	tw.tween_property(play_btn, "modulate", Color(0.82, 0.92, 1.0, 0.88), 0.75)


func _build_selector_overlay(root_ui: Control) -> void:
	if root_ui == null:
		return
	selector_overlay = Control.new()
	selector_overlay.name = "DestinationSelectorOverlay"
	selector_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	selector_overlay.visible = false
	root_ui.add_child(selector_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.07, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	selector_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	selector_overlay.add_child(center)

	destination_selector = DestinationSelector.new()
	destination_selector.name = "DestinationSelector"
	destination_selector.custom_minimum_size = Vector2(900, 0)
	destination_selector.destination_selected.connect(_on_destination_confirmed)
	center.add_child(destination_selector)

	var close_btn := Button.new()
	close_btn.name = "CloseSelectorBtn"
	close_btn.text = "BACK"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.position = Vector2(-110, 20)
	close_btn.custom_minimum_size = Vector2(90, 34)
	close_btn.pressed.connect(func() -> void:
		Sfx.ui_back()
		selector_overlay.visible = false
	)
	selector_overlay.add_child(close_btn)


func _on_play_pressed() -> void:
	Sfx.ui_click()
	if selector_overlay:
		selector_overlay.visible = true


func _on_destination_confirmed(dest_id: String) -> void:
	print("[MainMenu] Destination confirmed: ", dest_id)
	Helios4CampaignData.reset_campaign()
	Helios4CampaignData.set_destination(dest_id)
	Helios4CampaignData.load_stage(Helios4CampaignData.Stage.PROLOGUE, get_tree())
