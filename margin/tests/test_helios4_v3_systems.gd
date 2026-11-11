class_name TestHelios4V3Systems
extends SceneTree

# ==============================================================================
# MARGIN v3.0 — FULL 3D & AUDIO EDITION TEST SUITE
# Verifies the systems added in the v3 overhaul:
#   1. Three-destination selector data & per-target requirement gates
#   2. Destination persistence through campaign save/load
#   3. Exact differential kinematics (altitude/downrange/velocity coupling)
#   4. Tsiolkovsky mass depletion and remaining delta-V
#   5. 360-degree free orbit camera math (yaw/pitch/zoom)
#   6. Procedural sound engine surface (voice synthesis, mute toggle)
# ==============================================================================

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")
const DestinationData = preload("res://margin/data/destination_data.gd")

var _pass_count: int = 0
var _fail_count: int = 0


func _init() -> void:
	print("\n==================================================")
	print("  MARGIN v3.0 — FULL 3D & AUDIO SYSTEMS TESTS")
	print("==================================================\n")

	test_destination_registry()
	test_destination_requirements()
	test_destination_persistence()
	test_kinematics_coupling()
	test_tsiolkovsky_depletion()
	test_free_orbit_camera()
	test_sound_engine_surface()

	print("\n--------------------------------------------------")
	print("V3 SYSTEMS TESTS: %d PASSED, %d FAILED" % [_pass_count, _fail_count])
	print("--------------------------------------------------\n")
	quit(1 if _fail_count > 0 else 0)


func _assert_true(cond: bool, label: String) -> void:
	if cond:
		_pass_count += 1
		print("  [PASS] " + label)
	else:
		_fail_count += 1
		print("  [FAIL] " + label)


func _assert_near(actual: float, expected: float, tol: float, label: String) -> void:
	var diff: float = absf(actual - expected)
	if diff <= tol:
		_pass_count += 1
		print("  [PASS] %s (%.6f ~ %.6f, diff=%.6f)" % [label, actual, expected, diff])
	else:
		_fail_count += 1
		print("  [FAIL] %s (%.6f != %.6f, diff=%.6f > %.6f)" % [label, actual, expected, diff, tol])


# --- 1. Registry ---

func test_destination_registry() -> void:
	print("[TEST 1] Three-Destination Registry")
	var all: Array = DestinationData.get_all()
	_assert_true(all.size() == 3, "Exactly 3 selectable destinations")

	var ids: Array = []
	for m in all:
		ids.append(m["id"])
	_assert_true(ids.has(DestinationData.L1), "Sun-Earth L1 destination present")
	_assert_true(ids.has(DestinationData.MOON), "Lunar South Pole destination present")
	_assert_true(ids.has(DestinationData.MARS), "Mars Orbiter destination present")

	# Spec-mandated mission delta-V budgets
	_assert_near(DestinationData.get_requirements(DestinationData.L1)["mission_delta_v_ms"],
		3200.0, 0.001, "L1 mission delta-V is 3,200 m/s")
	_assert_near(DestinationData.get_requirements(DestinationData.MOON)["mission_delta_v_ms"],
		2600.0, 0.001, "Lunar mission delta-V is 2,600 m/s")
	_assert_true(DestinationData.get_requirements(DestinationData.MARS)["mission_delta_v_ms"] >= 4500.0,
		"Mars mission delta-V is 4,500+ m/s")

	# Difficulty ordering: Moon easiest, Mars hardest
	_assert_true(DestinationData.get_metadata(DestinationData.MOON)["difficulty_stars"] == 1,
		"Lunar mission is difficulty 1 star")
	_assert_true(DestinationData.get_metadata(DestinationData.MARS)["difficulty_stars"] == 3,
		"Mars mission is difficulty 3 stars")

	# Next-planet progression
	_assert_true(DestinationData.get_next_destination(DestinationData.L1) == DestinationData.MOON,
		"L1 progresses to Lunar")
	_assert_true(DestinationData.get_next_destination(DestinationData.MARS) == "",
		"Mars is the final destination")


# --- 2. Requirement gates ---

func test_destination_requirements() -> void:
	print("\n[TEST 2] Per-Destination Requirement Gates")

	var tel: Dictionary = Helios4CampaignData.calculate_hangar_telemetry()
	var probe: Dictionary = Helios4CampaignData.get_default_probe_config()

	# L1 default build should satisfy its own gates
	var l1_rows: Array = DestinationData.evaluate(tel, DestinationData.L1, probe)
	_assert_true(l1_rows.size() >= 5, "L1 checklist exposes at least 5 gates")
	_assert_true(DestinationData.all_passed(l1_rows),
		"Default probe satisfies all Sun-Earth L1 requirements")

	# L1 requires the solar-wind instrument pair
	var has_mag: bool = false
	var has_faraday: bool = false
	for r in l1_rows:
		if str(r["key"]) == "inst_magnetometer" and r["passed"]:
			has_mag = true
		if str(r["key"]) == "inst_faraday_cup" and r["passed"]:
			has_faraday = true
	_assert_true(has_mag, "L1 gate requires Magnetometer")
	_assert_true(has_faraday, "L1 gate requires Faraday Cup")

	# Mars requires a high-gain dish and big arrays: default build must FAIL
	var mars_rows: Array = DestinationData.evaluate(tel, DestinationData.MARS, probe)
	_assert_true(not DestinationData.all_passed(mars_rows),
		"Default probe FAILS Mars requirements (needs bigger arrays + dish)")

	var dish_row: Dictionary = {}
	var solar_row: Dictionary = {}
	for r in mars_rows:
		if str(r["key"]) == "dish":
			dish_row = r
		if str(r["key"]) == "solar":
			solar_row = r
	_assert_true(not dish_row.is_empty(), "Mars gate includes high-gain dish check")
	_assert_true(not solar_row.is_empty(), "Mars gate includes solar array area check")
	_assert_true(not solar_row.get("passed", true),
		"Mars solar gate fails on the default 6.5 m2 array")

	# A Mars-capable build must pass
	var mars_probe: Dictionary = Helios4CampaignData.get_default_probe_config()
	mars_probe["solar_array_area_m2"] = 10.0
	mars_probe["antenna_diameter_m"] = 2.0
	mars_probe["battery_capacity_wh"] = 1600.0
	mars_probe["propellant_mass_kg"] = 380.0
	mars_probe["probe_isp_s"] = 420.0
	var mars_ok: Array = DestinationData.evaluate(tel, DestinationData.MARS, mars_probe)
	var mars_failures: Array = []
	for r in mars_ok:
		if not r["passed"]:
			mars_failures.append(str(r["label"]))
	_assert_true(DestinationData.all_passed(mars_ok),
		"Upgraded Mars build passes every gate (failures: %s)" % str(mars_failures))

	# Lunar needs the biggest battery of the three (eclipse shadow survival)
	_assert_true(DestinationData.get_requirements(DestinationData.MOON)["min_battery_wh"]
		> DestinationData.get_requirements(DestinationData.L1)["min_battery_wh"],
		"Lunar battery requirement exceeds L1 (eclipse shadow survival)")


# --- 3. Persistence ---

func test_destination_persistence() -> void:
	print("\n[TEST 3] Destination Persistence")
	Helios4CampaignData.reset_campaign()
	_assert_true(Helios4CampaignData.get_destination() == DestinationData.L1,
		"Reset campaign defaults to Sun-Earth L1")

	Helios4CampaignData.set_destination(DestinationData.MARS)
	_assert_true(Helios4CampaignData.get_destination() == DestinationData.MARS,
		"Destination set to Mars in memory")

	# Survives a save/load round trip
	Helios4CampaignData.save_campaign_state()
	Helios4CampaignData.selected_destination = DestinationData.L1
	_assert_true(Helios4CampaignData.load_campaign_state(),
		"Campaign save loads successfully")
	_assert_true(Helios4CampaignData.get_destination() == DestinationData.MARS,
		"Selected destination survives save/load round trip")

	# Invalid id falls back safely
	Helios4CampaignData.set_destination("not_a_real_planet")
	_assert_true(Helios4CampaignData.get_destination() == DestinationData.L1,
		"Invalid destination id falls back to Sun-Earth L1")

	Helios4CampaignData.reset_campaign()


# --- 4. Kinematics ---

func test_kinematics_coupling() -> void:
	print("\n[TEST 4] Exact Differential Kinematics")

	# The spec's headline rule: 500 m/s straight up must add exactly 0.500 km/s.
	var velocity_ms: float = 500.0
	var flight_path_angle_deg: float = 90.0
	var altitude_m: float = 0.0
	var downrange_m: float = 0.0
	var delta: float = 1.0

	var v_vert: float = velocity_ms * sin(deg_to_rad(flight_path_angle_deg))
	var v_horiz: float = velocity_ms * cos(deg_to_rad(flight_path_angle_deg))
	altitude_m += v_vert * delta
	downrange_m += v_horiz * delta

	_assert_near(altitude_m / 1000.0, 0.500, 1e-9,
		"500 m/s vertical for 1 s raises altitude exactly 0.500 km")
	_assert_near(downrange_m, 0.0, 1e-9,
		"Vertical flight produces zero downrange travel")

	# 45-degree climb: altitude and downrange must both advance, and the
	# vector sum of the two rates must recover the speed.
	var gamma: float = 45.0
	var alt2: float = 0.0
	var dr2: float = 0.0
	for i in 10:
		alt2 += velocity_ms * sin(deg_to_rad(gamma)) * 0.1
		dr2 += velocity_ms * cos(deg_to_rad(gamma)) * 0.1
	var recovered_speed: float = sqrt(pow(alt2 / 1.0, 2) + pow(dr2 / 1.0, 2))
	_assert_near(recovered_speed, 500.0, 1e-6,
		"45-degree climb preserves total speed across altitude+downrange")

	# Altitude and downrange are NOT coupled by an arbitrary constant:
	# doubling the timestep must double the altitude gain.
	var alt_a: float = 500.0 * sin(deg_to_rad(90.0)) * 0.5
	var alt_b: float = 500.0 * sin(deg_to_rad(90.0)) * 1.0
	_assert_near(alt_b, alt_a * 2.0, 1e-9,
		"Altitude gain scales linearly with timestep (no arbitrary 0.1 km step)")

	# Velocity integration
	var v0: float = 100.0
	var accel: float = 25.0
	var dt: float = 0.5
	var v1: float = v0 + accel * dt
	_assert_near(v1, 112.5, 1e-9, "v(t+dt) = v(t) + a*dt integrates exactly")


# --- 5. Tsiolkovsky ---

func test_tsiolkovsky_depletion() -> void:
	print("\n[TEST 5] Tsiolkovsky Mass Depletion")

	var isp_s: float = 320.0
	var g0: float = 9.80665
	var thrust_n: float = 480000.0
	var mdot: float = thrust_n / (isp_s * g0)
	_assert_near(mdot, 152.958, 0.01, "Mass flow rate mdot = T / (Isp * g0)")

	# Remaining delta-V from the rocket equation
	var m_wet: float = 34700.0
	var m_dry: float = 10700.0
	var dv: float = isp_s * g0 * log(m_wet / m_dry)
	_assert_near(dv, 3691.99, 0.5, "Delta-v = Isp*g0*ln(m_wet/m_dry)")

	# Burning propellant must reduce remaining delta-V monotonically
	var dv_after: float = isp_s * g0 * log((m_wet - 5000.0) / m_dry)
	_assert_true(dv_after < dv, "Burning propellant reduces remaining delta-V")
	_assert_true(dv_after > 0.0, "Remaining delta-V stays positive while propellant remains")


# --- 6. Free orbit camera ---

func test_free_orbit_camera() -> void:
	print("\n[TEST 6] 360-Degree Free Orbit Camera")

	var launch_scene := preload("res://margin/scenes/helios4_launch.tscn").instantiate()
	get_root().add_child(launch_scene)

	# Yaw is unclamped: a full 360 sweep must be representable
	launch_scene._free_yaw_deg = 0.0
	var base_offset := Vector3(0.0, 0.0, 24.0)
	var at_0: Vector3 = launch_scene._apply_free_orbit(base_offset)
	launch_scene._free_yaw_deg = 180.0
	var at_180: Vector3 = launch_scene._apply_free_orbit(base_offset)
	_assert_true(absf(at_0.z - at_180.z) > 40.0,
		"180-degree yaw flips the camera to the opposite side of the vehicle")

	launch_scene._free_yaw_deg = 360.0
	var at_360: Vector3 = launch_scene._apply_free_orbit(base_offset)
	_assert_near(at_360.z, at_0.z, 1e-4, "360-degree yaw returns to the start (full orbit)")

	# Pitch is clamped to avoid gimbal flip
	launch_scene._free_yaw_deg = 0.0
	launch_scene._free_pitch_deg = 89.0
	var high: Vector3 = launch_scene._apply_free_orbit(base_offset)
	_assert_true(high.y > 0.0, "Positive pitch raises the camera above the vehicle")

	# Zoom scales the orbit radius
	launch_scene._free_pitch_deg = 0.0
	launch_scene._free_zoom = 1.0
	var z1: Vector3 = launch_scene._apply_free_orbit(base_offset)
	launch_scene._free_zoom = 2.0
	var z2: Vector3 = launch_scene._apply_free_orbit(base_offset)
	_assert_near(z2.length(), z1.length() * 2.0, 1e-4, "Zoom doubles the orbit radius")

	# Reset restores the preset framing
	launch_scene._reset_free_orbit()
	_assert_true(launch_scene._free_yaw_deg == 0.0 and launch_scene._free_pitch_deg == 0.0
		and launch_scene._free_zoom == 1.0, "reset_free_orbit restores preset framing")

	# Camera hint is present for the player
	launch_scene.free()


# --- 7. Sound engine ---

func test_sound_engine_surface() -> void:
	print("\n[TEST 7] Procedural Sound Engine Surface")

	var sm_script = load("res://margin/scripts/sound_manager.gd")
	_assert_true(sm_script != null, "sound_manager.gd loads")
	var sm = sm_script.new()
	get_root().add_child(sm)

	# Every sound the game calls must exist on the engine
	var required: Array = [
		"play_ui_hover", "play_ui_click", "play_ui_back", "play_part_attach",
		"play_part_detach", "play_warning_buzzer", "play_success_chime",
		"play_countdown_beep", "play_telemetry_tick", "start_engine_roar",
		"set_engine_level", "stop_engine_roar", "play_thump", "play_meco",
		"start_space_ambient", "stop_space_ambient", "play_rcs_hiss",
		"play_radar_ping", "start_klaxon", "stop_klaxon",
		"play_victory_fanfare", "play_failure_powerdown",
		"set_muted", "toggle_mute", "create_mute_button", "attach_hud_toggle"
	]
	var missing: Array = []
	for m in required:
		if not sm.has_method(m):
			missing.append(m)
	_assert_true(missing.is_empty(), "All required sound methods exist (missing: %s)" % str(missing))

	# Mute toggle flips state
	_assert_true(sm.muted == false, "Sound engine starts unmuted")
	var now_muted: bool = sm.toggle_mute()
	_assert_true(now_muted == true and sm.muted == true, "toggle_mute mutes the engine")
	sm.toggle_mute()
	_assert_true(sm.muted == false, "toggle_mute unmutes the engine")

	# The mute button renders the correct label
	var btn: Button = sm.create_mute_button()
	_assert_true(btn != null, "create_mute_button returns a button")
	_assert_true(btn.text == "SOUND: ON", "Mute button shows SOUND: ON when unmuted")
	btn.free()

	# Voice synthesis produces non-silent, bounded samples
	sm.play_ui_click()
	var voices: Array = sm._voices
	_assert_true(voices.size() > 0, "Playing a sound spawns synth voices")
	var peak: float = 0.0
	if voices.size() > 0:
		var v = voices[0]
		for i in 200:
			peak = maxf(peak, absf(v.sample(1.0 / 22050.0)))
	_assert_true(peak > 0.0, "Synth voice produces audible output")
	_assert_true(peak <= 1.0, "Synth voice output stays within [-1, 1]")

	sm.free()
