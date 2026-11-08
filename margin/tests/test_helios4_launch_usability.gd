extends SceneTree

# ==============================================================================
# HELIOS-4 LAUNCH USABILITY & DYNAMIC CAMERA AUTOMATED TEST SUITE
# ==============================================================================

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")
var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	print("\n==================================================")
	print("  HELIOS-4: LAUNCH USABILITY & CAMERA VERIFICATION")
	print("==================================================\n")

	process_frame.connect(_run_all_tests, CONNECT_ONE_SHOT)

func _finish_tests() -> void:
	print("\n--------------------------------------------------")
	print("TEST RESULTS: %d PASSED, %d FAILED" % [_passed, _failed])
	print("--------------------------------------------------\n")

	quit(0 if _failed == 0 else 1)

func _assert_test(cond: bool, msg: String) -> void:
	if cond:
		print("  [PASS] %s" % msg)
		_passed += 1
	else:
		printerr("  [FAIL] %s" % msg)
		_failed += 1

func _run_all_tests() -> void:
	# Ensure clean campaign state with ready spacecraft
	Helios4CampaignData.vehicle_config = Helios4CampaignData.get_default_vehicle_config()
	Helios4CampaignData.probe_config = Helios4CampaignData.get_default_probe_config()
	Helios4CampaignData.set_launch_authorized(true)

	var launch_scene = load("res://margin/scenes/helios4_launch.tscn")
	_assert_test(launch_scene != null, "Launch scene loaded successfully")
	var instance = launch_scene.instantiate()
	# Node added to tree automatically runs _ready()
	root.add_child(instance)

	print("\n[TEST 1] Flight Objective Panel UI Hierarchy & Wiring")
	var obj_panel = instance.find_child("FlightObjectivePanel", true, false)
	_assert_test(obj_panel != null, "FlightObjectivePanel exists in RootUI")
	var lbl_phase = instance.find_child("LblObjectivePhase", true, false)
	_assert_test(lbl_phase != null, "LblObjectivePhase exists")
	var lbl_status = instance.find_child("LblObjectiveStatus", true, false)
	_assert_test(lbl_status != null, "LblObjectiveStatus exists")
	var lbl_primary = instance.find_child("LblObjectivePrimary", true, false)
	_assert_test(lbl_primary != null, "LblObjectivePrimary exists")
	var lbl_action = instance.find_child("LblObjectiveAction", true, false)
	_assert_test(lbl_action != null, "LblObjectiveAction exists")
	var lbl_next = instance.find_child("LblObjectiveNext", true, false)
	_assert_test(lbl_next != null, "LblObjectiveNext exists")
	var lbl_ctrls = instance.find_child("LblObjectiveControls", true, false)
	_assert_test(lbl_ctrls != null, "LblObjectiveControls exists")

	print("\n[TEST 2] Dynamic Player Controls & Actions Presence")
	var btn_fairing = instance.find_child("BtnFairingJettison", true, false) as Button
	_assert_test(btn_fairing != null, "BtnFairingJettison exists in RightFlightPanel")
	_assert_test(btn_fairing.disabled == true, "BtnFairingJettison initially disabled on pad")

	var btn_pause = instance.find_child("BtnPauseFlight", true, false) as Button
	_assert_test(btn_pause != null, "BtnPauseFlight exists")
	var btn_abort = instance.find_child("BtnAbortFlight", true, false) as Button
	_assert_test(btn_abort != null, "BtnAbortFlight exists")
	var btn_throt_up = instance.find_child("BtnThrotUp", true, false) as Button
	_assert_test(btn_throt_up != null, "BtnThrotUp exists")
	var btn_throt_down = instance.find_child("BtnThrotDown", true, false) as Button
	_assert_test(btn_throt_down != null, "BtnThrotDown exists")
	var val_throttle = instance.find_child("ValThrottleDisplay", true, false) as Label
	_assert_test(val_throttle != null, "ValThrottleDisplay exists")
	var btn_pitch_left = instance.find_child("BtnPitchLeft", true, false) as Button
	_assert_test(btn_pitch_left != null, "BtnPitchLeft (Zenith) exists")
	var btn_pitch_right = instance.find_child("BtnPitchRight", true, false) as Button
	_assert_test(btn_pitch_right != null, "BtnPitchRight (Horizon) exists")
	var lbl_pitch_readout = instance.find_child("LblPitchReadout", true, false) as Label
	_assert_test(lbl_pitch_readout != null, "LblPitchReadout exists")

	print("\n[TEST 3] Camera Mode Switching is Pure Perspective (No Simulation Advance)")
	instance.current_phase = instance.FlightPhase.ASCENT_STAGE1
	instance.altitude_m = 12000.0
	instance.velocity_ms = 450.0
	instance.flight_time_s = 35.0

	var init_phase = instance.current_phase
	var init_alt = instance.altitude_m
	var init_vel = instance.velocity_ms
	var init_time = instance.flight_time_s

	# Cycle through all 7 camera modes
	for mode_idx in range(7):
		instance._set_camera_mode(mode_idx, true)
		_assert_test(instance.current_cam_mode == mode_idx, "Switched to camera mode %d" % mode_idx)
		_assert_test(instance.current_phase == init_phase, "Phase unchanged during camera switch to %d" % mode_idx)
		_assert_test(instance.altitude_m == init_alt, "Altitude unchanged during camera switch to %d" % mode_idx)
		_assert_test(instance.velocity_ms == init_vel, "Velocity unchanged during camera switch to %d" % mode_idx)
		_assert_test(instance.flight_time_s == init_time, "Flight time unchanged during camera switch to %d" % mode_idx)

	print("\n[TEST 4] Dynamic Camera Zero Velocity Lag & Rocket Framing")
	print("DEBUG: instance.rocket = ", instance.rocket)
	print("DEBUG: instance.launch_cam = ", instance.launch_cam)
	# Set Chase camera and test tracking across high ascent velocities
	instance._set_camera_mode(instance.CameraMode.CHASE, true)
	var test_altitudes = [500.0, 5000.0, 25000.0, 65000.0, 120000.0]

	for alt in test_altitudes:
		instance.altitude_m = alt
		instance.downrange_m = alt * 0.4
		instance.pitch_deg = clamp(90.0 - (alt / 140000.0) * 80.0, 10.0, 90.0)
		instance._update_3d_visuals(0.016)
		instance._update_camera_smooth(0.016)

		var rocket_pos = instance.rocket.global_position
		var cam_pos = instance.launch_cam.global_position
		var v_dir = instance.rocket.global_transform.basis.y.normalized()
		var v_center = rocket_pos + v_dir * 8.0
		var nose_pos = rocket_pos + v_dir * 16.5
		var engine_pos = rocket_pos - v_dir * 0.5

		# In Chase mode, cam_pos is exactly v_center + _cam_relative_offset
		var expected_cam_pos = v_center + instance._cam_relative_offset
		var lag_dist = cam_pos.distance_to(expected_cam_pos)
		_assert_test(lag_dist < 0.1, "At alt %.0fm, camera has 0 velocity lag (offset diff: %.3fm)" % [alt, lag_dist])

		# Verify camera is looking at target and both nose and engines are in front of camera
		var cam_forward = -instance.launch_cam.global_transform.basis.z.normalized()
		var nose_vec = (nose_pos - cam_pos).normalized()
		var engine_vec = (engine_pos - cam_pos).normalized()

		var dot_nose = cam_forward.dot(nose_vec)
		var dot_engine = cam_forward.dot(engine_vec)
		_assert_test(dot_nose > 0.80, "At alt %.0fm, nose cone is centered in camera view (dot=%.3f)" % [alt, dot_nose])
		_assert_test(dot_engine > 0.80, "At alt %.0fm, engines/exhaust are centered in camera view (dot=%.3f)" % [alt, dot_engine])

	print("\n[TEST 5] Simulation Pause / Resume Mechanics")
	_assert_test(instance.is_flight_paused == false, "Simulation initially unpaused")
	instance._toggle_flight_pause()
	_assert_test(instance.is_flight_paused == true, "Simulation paused via _toggle_flight_pause()")
	_assert_test(instance.pause_banner_panel.visible == true, "Pause banner visible when paused")

	var paused_time = instance.flight_time_s
	var paused_alt = instance.altitude_m
	instance._physics_process(0.5)
	_assert_test(instance.flight_time_s == paused_time, "Flight time does not advance while paused")
	_assert_test(instance.altitude_m == paused_alt, "Altitude does not advance while paused")

	# Unpause
	instance._toggle_flight_pause()
	_assert_test(instance.is_flight_paused == false, "Simulation unpaused via _toggle_flight_pause()")
	_assert_test(instance.pause_banner_panel.visible == false, "Pause banner hidden when resumed")
	instance._physics_process(0.1)
	_assert_test(instance.flight_time_s > paused_time, "Flight time advances normally when resumed")

	print("\n[TEST 6] Interactive Fairing Jettison Gating")
	instance.altitude_m = 45000.0
	instance.fairing_separated = false
	instance.btn_fairing_jettison.disabled = true
	instance._check_phase_transitions()
	_assert_test(instance.btn_fairing_jettison.disabled == true, "Fairing jettison locked below 68 km")
	_assert_test(instance.fairing_separated == false, "Fairing not separated automatically below 68 km")

	instance.altitude_m = 69000.0
	instance._check_phase_transitions()
	_assert_test(instance.btn_fairing_jettison.disabled == false, "Fairing jettison unlocked above 68 km")
	_assert_test(instance.fairing_separated == false, "Fairing remains attached awaiting player action")

	# Trigger fairing jettison
	instance._execute_fairing_jettison()
	_assert_test(instance.fairing_separated == true, "Fairing jettison executed successfully")
	_assert_test(instance.btn_fairing_jettison.disabled == true, "Fairing button disabled after jettison")
	_assert_test(instance.btn_fairing_jettison.text == "FAIRING JETTISONED ✓", "Fairing button shows confirmed checkmark")

	print("\n[TEST 7] Steering and Throttle Controls Direction")
	instance.throttle = 1.0
	# Test throttle down
	var ev_s = InputEventKey.new()
	ev_s.keycode = KEY_S
	ev_s.pressed = true
	instance._unhandled_input(ev_s)
	_assert_test(is_equal_approx(instance.throttle, 0.95), "Key [S] throttles down to 95%")

	var ev_w = InputEventKey.new()
	ev_w.keycode = KEY_W
	ev_w.pressed = true
	instance._unhandled_input(ev_w)
	_assert_test(is_equal_approx(instance.throttle, 1.0), "Key [W] throttles up to 100%")

	# Test pitch steering direction
	instance.pitch_deg = 45.0
	var ev_d = InputEventKey.new()
	ev_d.keycode = KEY_D
	ev_d.pressed = true
	instance._unhandled_input(ev_d)
	_assert_test(instance.pitch_deg < 45.0, "Key [D] pitches down toward horizon (pitch=%.1f°)" % instance.pitch_deg)

	var ev_a = InputEventKey.new()
	ev_a.keycode = KEY_A
	ev_a.pressed = true
	instance._unhandled_input(ev_a)
	_assert_test(instance.pitch_deg == 45.0, "Key [A] pitches up toward zenith (pitch=%.1f°)" % instance.pitch_deg)

	print("\n[TEST 8] Flight Objective Panel Content Verification Across Phases")
	var phase_checks = [
		{"phase": instance.FlightPhase.PRE_LAUNCH_PREPARATION, "expected_phase": "PRE-LAUNCH CHECKOUT", "expected_action": "Press [V]"},
		{"phase": instance.FlightPhase.COUNTDOWN, "expected_phase": "TERMINAL COUNTDOWN", "expected_action": "Stand by for ignition"},
		{"phase": instance.FlightPhase.ASCENT_STAGE1, "expected_phase": "BOOSTER ASCENT (STAGE 1)", "expected_action": "Steer pitch with [A/D]"},
		{"phase": instance.FlightPhase.MAX_Q_CORRIDOR, "expected_phase": "MAX-Q TRANSONIC CORRIDOR", "expected_action": "throttle down to 70%"},
		{"phase": instance.FlightPhase.STAGE1_BURNOUT, "expected_phase": "MECO (STAGE 1 DEPLETED)", "expected_action": "STAGE SEPARATION"},
		{"phase": instance.FlightPhase.ORBITAL_INJECTION, "expected_phase": "PARKING ORBIT CONFIRMED", "expected_action": "SYSTEMS ACTIVATE"},
		{"phase": instance.FlightPhase.SYSTEMS_ACTIVATION, "expected_phase": "MISSION READY (L1 INJECTION)", "expected_action": "PROCEED TO DEEP SPACE TRANSFER"}
	]

	for item in phase_checks:
		instance.current_phase = item["phase"]
		instance._update_flight_objective_panel()
		_assert_test(item["expected_phase"] in instance.lbl_obj_phase.text, "Phase label matches for %s" % item["expected_phase"])
		_assert_test(item["expected_action"] in instance.lbl_obj_action.text, "Action label contains '%s'" % item["expected_action"])

	instance.queue_free()
	_finish_tests()
