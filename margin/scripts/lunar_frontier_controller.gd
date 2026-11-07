class_name LunarFrontierController
extends Node3D

const LunarFrontierWorld = preload("res://margin/scripts/lunar_frontier_world.gd")
const LunarHopper = preload("res://margin/scripts/lunar_hopper.gd")
const LunarFrontierCamera = preload("res://margin/scripts/lunar_frontier_camera.gd")
const LunarFrontierHUD = preload("res://margin/scripts/lunar_frontier_hud.gd")

enum MissionState {
	ACTIVE,
	STORM_ALERT,
	PAUSED,
	VICTORY,
	FAILED
}

const TOTAL_MISSION_TIME: float = 180.0
const STORM_TRIGGER_TIME: float = 100.0 # Triggers around 80s into mission

@onready var world: LunarFrontierWorld = $LunarFrontierWorld
@onready var hopper: LunarHopper = $LunarHopper
@onready var camera_rig: LunarFrontierCamera = $LunarFrontierCamera
@onready var hud: LunarFrontierHUD = $LunarFrontierHUD

var current_state: MissionState = MissionState.ACTIVE
var mission_timer: float = TOTAL_MISSION_TIME
var samples_collected: int = 0
var storm_event_triggered: bool = false
var active_target_id: String = ""
var active_target_name: String = ""

func _ready() -> void:
	_connect_signals()
	_setup_mission_start()

func _connect_signals() -> void:
	# World signals
	world.target_entered.connect(_on_target_entered)
	world.target_exited.connect(_on_target_exited)
	world.lander_beacon_entered.connect(_on_lander_beacon_entered)
	world.lander_beacon_exited.connect(_on_lander_beacon_exited)

	# Hopper signals
	hopper.resource_changed.connect(_on_hopper_resource_changed)
	hopper.collision_impact.connect(_on_hopper_collision)
	hopper.vehicle_disabled.connect(_on_hopper_disabled)

	# HUD signals
	hud.scan_initiated.connect(_on_scan_completed)
	hud.safe_mode_chosen.connect(_on_safe_mode_chosen)
	hud.ignore_storm_chosen.connect(_on_ignore_storm_chosen)
	hud.restart_requested.connect(restart_mission)
	hud.main_menu_requested.connect(_on_main_menu_requested)
	hud.pause_toggled.connect(_on_pause_toggled)

func _setup_mission_start() -> void:
	# Spawn hopper near the lander facing north
	hopper.reset_state(Vector3(0.0, 0.8, 6.2), 0.0)
	camera_rig.target = hopper
	camera_rig.reset_camera()
	
	mission_timer = TOTAL_MISSION_TIME
	samples_collected = 0
	storm_event_triggered = false
	current_state = MissionState.ACTIVE
	
	hud.reset_hud()
	hud.show_warning("MISSION DISPATCH: Locate and scan 3 volatile anomalies.", 4.0)

func _process(delta: float) -> void:
	if current_state != MissionState.ACTIVE:
		return

	# 1. Mission Timer Countdown
	mission_timer -= delta
	hud.update_timer(mission_timer)

	if mission_timer <= 0.0:
		_trigger_failure("MISSION TIMEOUT: Orbiting communications relay moved beyond lunar line-of-sight.")
		return

	# 2. Check Solar Storm Event Trigger
	if not storm_event_triggered and (mission_timer <= STORM_TRIGGER_TIME or samples_collected >= 1):
		_trigger_solar_storm_event()

	# 3. Handle Scan Input (E key)
	_process_scan_input()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if current_state == MissionState.ACTIVE:
				_on_pause_toggled(true)
			elif current_state == MissionState.PAUSED:
				_on_pause_toggled(false)

func _process_scan_input() -> void:
	if active_target_id == "":
		return

	var is_e_held: bool = Input.is_key_pressed(KEY_E)
	if is_e_held:
		hopper.set_scanning(true)
		hud.start_scanning()
	else:
		if hopper.is_scanning:
			hopper.set_scanning(false)
			hud.cancel_scanning()

# --- Proximity & Target Callbacks ---

func _on_target_entered(target_id: String, target_name: String) -> void:
	if world.is_target_scanned(target_id):
		return
	active_target_id = target_id
	active_target_name = target_name
	hud.show_scan_prompt(target_name)

func _on_target_exited(target_id: String) -> void:
	if active_target_id == target_id:
		active_target_id = ""
		active_target_name = ""
		hopper.set_scanning(false)
		hud.hide_scan_prompt()

func _on_scan_completed() -> void:
	if active_target_id == "":
		return

	var tid: String = active_target_id
	world.mark_target_scanned(tid)
	samples_collected += 1
	hopper.set_scanning(false)
	hud.hide_scan_prompt()
	hud.update_samples(samples_collected, 3)

	active_target_id = ""
	active_target_name = ""

	if samples_collected >= 3:
		hud.show_warning("ALL 3 SAMPLES SECURED! Return to Lander Beacon immediately!", 6.0)
	else:
		hud.show_warning("SAMPLE SCANNED (+1): %d of 3 samples secured." % samples_collected, 3.5)

# --- Lander Beacon Return ---

func _on_lander_beacon_entered() -> void:
	if current_state != MissionState.ACTIVE:
		return

	if samples_collected >= 3:
		_trigger_victory()
	else:
		hud.show_warning("LANDER BASE: Return requires all 3 science samples (%d/3 secured)." % samples_collected, 3.5)

func _on_lander_beacon_exited() -> void:
	pass

# --- Vehicle Telemetry & Collision Callbacks ---

func _on_hopper_resource_changed(battery: float, propellant: float, integrity: float) -> void:
	hud.update_resources(battery, propellant, integrity)

func _on_hopper_collision(damage: float, remaining_integrity: float) -> void:
	hud.show_warning("COLLISION SHOCK! -%d%% Hull Integrity" % int(damage), 2.2)

func _on_hopper_disabled(reason: String) -> void:
	_trigger_failure(reason)

# --- Solar Storm Event ---

func _trigger_solar_storm_event() -> void:
	storm_event_triggered = true
	current_state = MissionState.STORM_ALERT
	hopper.can_control = false
	hud.show_storm_event()

func _on_safe_mode_chosen() -> void:
	current_state = MissionState.ACTIVE
	hopper.can_control = true
	hopper.set_safe_mode(true)
	hopper.set_storm_active(false)
	hud.show_warning("SAFE MODE ACTIVATED: Speed restricted to 65%. Radiation shield intact.", 4.5)

func _on_ignore_storm_chosen() -> void:
	current_state = MissionState.ACTIVE
	hopper.can_control = true
	hopper.set_safe_mode(false)
	hopper.set_storm_active(true)
	hud.show_warning("WARNING IGNORED: Spacecraft exposed to solar radiation degradation!", 4.5)

# --- Victory & Failure Handlers ---

func _trigger_victory() -> void:
	current_state = MissionState.VICTORY
	hopper.can_control = false

	var time_left: float = max(0.0, mission_timer)
	var batt: float = hopper.battery
	var fuel: float = hopper.propellant
	var integ: float = hopper.integrity

	# Deterministic Grade Calculation
	var grade: String = "C"
	if time_left >= 50.0 and batt >= 35.0 and integ >= 65.0:
		grade = "S"
	elif time_left >= 25.0 and batt >= 20.0 and integ >= 45.0:
		grade = "A"
	elif time_left > 0.0 and batt > 0.0 and integ > 0.0:
		grade = "B"

	hud.show_victory(time_left, batt, fuel, integ, grade)

func _trigger_failure(reason: String) -> void:
	current_state = MissionState.FAILED
	hopper.can_control = false
	hud.show_failure(reason)

# --- State Control & Navigation ---

func _on_pause_toggled(paused: bool) -> void:
	if paused:
		current_state = MissionState.PAUSED
		hopper.can_control = false
		hud.pause_modal.visible = true
	else:
		current_state = MissionState.ACTIVE
		hopper.can_control = true
		hud.pause_modal.visible = false

func restart_mission() -> void:
	world.reset_science_targets()
	_setup_mission_start()

func _on_main_menu_requested() -> void:
	get_tree().change_scene_to_file("res://margin/scenes/main_menu.tscn")
