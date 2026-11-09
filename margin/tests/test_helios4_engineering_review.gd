extends SceneTree

const Helios4CampaignData = preload("res://margin/data/helios4_campaign_data.gd")
const REVIEW_SCENE = preload("res://margin/scenes/helios4_engineering_review.tscn")

var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)

func _assert_test(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] %s" % message)
		_passed += 1
	else:
		printerr("  [FAIL] %s" % message)
		_failed += 1

func _run_tests() -> void:
	print("\n[HELIOS-4] Engineering readiness review interaction regression")
	var vehicle := Helios4CampaignData.get_default_vehicle_config()
	vehicle["stage1_thrust_kn"] = 1.0 # Deliberately fail liftoff TWR to exercise waiver path.
	Helios4CampaignData.vehicle_config = vehicle
	Helios4CampaignData.probe_config = Helios4CampaignData.get_default_probe_config()
	Helios4CampaignData.team_player_names = {
		Helios4CampaignData.ROLE_PROPULSION: "Propulsion",
		Helios4CampaignData.ROLE_STRUCTURAL: "Structures",
		Helios4CampaignData.ROLE_ASTROGATOR: "Astrogator",
		Helios4CampaignData.ROLE_SYSTEMS: "Systems"
	}
	Helios4CampaignData.active_role = Helios4CampaignData.ROLE_PROPULSION
	Helios4CampaignData.is_launch_authorized = false
	Helios4CampaignData.launch_readiness_override = false
	Helios4CampaignData.team_decision_log.clear()

	var review := REVIEW_SCENE.instantiate()
	root.add_child(review)
	await process_frame

	_assert_test(review.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Full-screen review root does not intercept child button input")
	_assert_test(review.get_node("Background").mouse_filter == Control.MOUSE_FILTER_IGNORE, "Background cannot intercept review clicks")
	_assert_test(not review.telemetry["all_gate_checks_passed"], "Fixture contains a failed readiness gate")
	_assert_test(review.override_launch_btn != null and not review.override_launch_btn.disabled, "Visible waiver/auto-GO action is always enabled")

	for role_id in [Helios4CampaignData.ROLE_PROPULSION, Helios4CampaignData.ROLE_STRUCTURAL, Helios4CampaignData.ROLE_ASTROGATOR, Helios4CampaignData.ROLE_SYSTEMS]:
		var vote_button := review.find_child("VoteBtn_" + role_id, true, false) as Button
		_assert_test(vote_button != null and vote_button.mouse_filter == Control.MOUSE_FILTER_STOP, "%s sign-off button is an explicit pointer target" % role_id)
		if vote_button:
			vote_button.emit_signal("pressed")
			_assert_test(review.votes[role_id], "%s sign-off callback records its own role" % role_id)

	_assert_test(review.launch_btn.disabled, "Normal proceed remains gated while engineering checks fail")
	review.override_launch_btn.emit_signal("pressed")
	await process_frame
	_assert_test(Helios4CampaignData.current_stage == Helios4CampaignData.Stage.PHASE_2_LAUNCH, "Waiver reliably advances campaign to Launch")
	_assert_test(Helios4CampaignData.launch_readiness_override, "Readiness waiver is retained through the stage transition")
	var reloaded := Helios4CampaignData.load_campaign_state()
	_assert_test(reloaded and Helios4CampaignData.launch_readiness_override, "Readiness waiver survives campaign save/load")
	_assert_test(Helios4CampaignData.is_spacecraft_ready_for_flight(), "Launch controller readiness accepts an explicitly authorized waiver")
	_assert_test(Helios4CampaignData.team_decision_log.size() == 1, "Waiver is recorded in persistent team decision history")

	print("\nENGINEERING REVIEW TESTS: %d PASSED, %d FAILED" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
