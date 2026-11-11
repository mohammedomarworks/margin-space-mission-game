extends Node

# ==============================================================================
# MARGIN — PROCEDURAL WEB-SAFE SOUND ENGINE
# Zero external assets. Every sound is synthesized at runtime into a single
# AudioStreamGenerator buffer, so it works identically in WebGL, desktop and
# headless test runs (headless simply produces no audio device).
#
# Architecture:
#   One AudioStreamPlayer + AudioStreamGenerator at 22.05 kHz.
#   A flat voice list is mixed per-frame in _process() and pushed as
#   PackedVector2Array frames. Voices are cheap oscillator / filtered-noise
#   units with ADSR envelopes, so dozens can run at once.
# ==============================================================================

const MIX_RATE: float = 22050.0
const BUFFER_LENGTH: float = 0.12

# --- Voice kinds ---
const KIND_TONE: String = "tone"
const KIND_NOISE: String = "noise"

var muted: bool = false
var master_gain: float = 0.85

var _player: AudioStreamPlayer = null
var _playback: AudioStreamGeneratorPlayback = null
var _voices: Array = []
var _engine_voice = null
var _ambient_voice = null
var _klaxon_voice = null
var _available: bool = false


class Voice:
	extends RefCounted

	var kind: String = "tone"
	var wave: String = "sine"
	var freq: float = 440.0
	var freq_end: float = 440.0
	var amp: float = 0.25
	var attack: float = 0.004
	var decay: float = 0.08
	var sustain: float = 0.0
	var release: float = 0.12
	var duration: float = 0.2
	var loop: bool = false
	var alive: bool = true

	# Noise shaping
	var lp_coeff: float = 0.25
	var _lp_state: float = 0.0

	# Runtime
	var t: float = 0.0
	var phase: float = 0.0
	var gain_scale: float = 1.0
	var gain_target: float = 1.0
	var gain_smooth: float = 6.0

	# Optional tremolo (klaxon pulsing)
	var tremolo_hz: float = 0.0
	var tremolo_depth: float = 0.0

	func sample(dt: float) -> float:
		if not alive:
			return 0.0

		# Smoothly approach the requested gain (used for throttle-linked roar)
		gain_scale = lerpf(gain_scale, gain_target, clampf(gain_smooth * dt, 0.0, 1.0))

		# Envelope
		var env: float = 0.0
		if loop:
			env = 1.0
		elif t < attack:
			env = t / maxf(attack, 0.0001)
		elif t < attack + decay:
			var k: float = (t - attack) / maxf(decay, 0.0001)
			env = lerpf(1.0, sustain, k)
		elif t < duration:
			env = sustain
		else:
			var r: float = (t - duration) / maxf(release, 0.0001)
			env = sustain * (1.0 - r)
			if r >= 1.0:
				alive = false
				return 0.0

		# Frequency sweep
		var f: float = freq
		if not is_equal_approx(freq, freq_end) and duration > 0.0:
			f = lerpf(freq, freq_end, clampf(t / duration, 0.0, 1.0))

		phase += TAU * f * dt
		if phase > TAU:
			phase = fmod(phase, TAU)

		var raw: float = 0.0
		if kind == "noise":
			var n: float = randf_range(-1.0, 1.0)
			_lp_state += (n - _lp_state) * lp_coeff
			raw = _lp_state
		else:
			match wave:
				"square":
					raw = 1.0 if sin(phase) >= 0.0 else -1.0
				"saw":
					raw = (phase / TAU) * 2.0 - 1.0
				"tri":
					raw = asin(sin(phase)) * (2.0 / PI)
				_:
					raw = sin(phase)

		var out_v: float = raw * env * amp * gain_scale

		if tremolo_depth > 0.0 and tremolo_hz > 0.0:
			var trem: float = 0.5 + 0.5 * sin(TAU * tremolo_hz * t)
			out_v *= lerpf(1.0 - tremolo_depth, 1.0, trem)

		t += dt
		return out_v


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_generator()


func _setup_generator() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "ProceduralBus"
	_player.bus = "Master"
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = BUFFER_LENGTH
	_player.stream = gen
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	_available = _playback != null
	if not _available:
		print("[Sound] No audio device available (headless). Synth stays silent.")


func _process(_delta: float) -> void:
	if not _available or _playback == null:
		return
	var frames: int = _playback.get_frames_available()
	if frames <= 0:
		return

	var dt: float = 1.0 / MIX_RATE
	var buffer := PackedVector2Array()
	buffer.resize(frames)

	var active: Array = []
	for v in _voices:
		if v.alive:
			active.append(v)

	if active.is_empty():
		# Feed silence so the generator never starves and clicks.
		for i in frames:
			buffer[i] = Vector2.ZERO
		_playback.push_buffer(buffer)
		return

	var g: float = 0.0 if muted else master_gain
	for i in frames:
		var mix: float = 0.0
		for v in active:
			mix += v.sample(dt)
		# Soft clip to keep the bus clean when many voices stack
		mix = clampf(mix, -1.0, 1.0)
		mix = mix - (mix * mix * mix) / 3.0
		var s: float = mix * g
		buffer[i] = Vector2(s, s)

	_playback.push_buffer(buffer)

	# Reap dead voices
	var keep: Array = []
	for v in _voices:
		if v.alive:
			keep.append(v)
	_voices = keep


# ------------------------------------------------------------------------------
# Voice helpers
# ------------------------------------------------------------------------------

func _add_voice(v: Voice) -> Voice:
	_voices.append(v)
	return v


func _tone(freq: float, dur: float, amp: float, wave: String = "sine",
		attack: float = 0.004, decay: float = 0.05, sustain: float = 0.0,
		release: float = 0.08, freq_end: float = -1.0) -> Voice:
	var v := Voice.new()
	v.kind = KIND_TONE
	v.wave = wave
	v.freq = freq
	v.freq_end = freq if freq_end < 0.0 else freq_end
	v.duration = dur
	v.amp = amp
	v.attack = attack
	v.decay = decay
	v.sustain = sustain
	v.release = release
	return _add_voice(v)


func _noise(dur: float, amp: float, lp: float, attack: float = 0.002,
		decay: float = 0.06, sustain: float = 0.0, release: float = 0.1) -> Voice:
	var v := Voice.new()
	v.kind = KIND_NOISE
	v.duration = dur
	v.amp = amp
	v.lp_coeff = lp
	v.attack = attack
	v.decay = decay
	v.sustain = sustain
	v.release = release
	return _add_voice(v)


# ------------------------------------------------------------------------------
# 1. UI & HANGAR
# ------------------------------------------------------------------------------

func play_ui_hover() -> void:
	_tone(1580.0, 0.03, 0.10, "sine", 0.002, 0.02, 0.0, 0.03, 2100.0)


func play_ui_click() -> void:
	_tone(880.0, 0.05, 0.16, "square", 0.001, 0.03, 0.0, 0.05, 1320.0)
	_tone(1760.0, 0.04, 0.07, "sine", 0.001, 0.02, 0.0, 0.04)


func play_ui_back() -> void:
	_tone(660.0, 0.07, 0.13, "square", 0.001, 0.04, 0.0, 0.06, 330.0)


# Mechanical hydraulic clunk: low thud + metallic snap transient
func play_part_attach() -> void:
	_noise(0.10, 0.30, 0.10, 0.001, 0.05, 0.0, 0.10)
	_tone(96.0, 0.14, 0.34, "sine", 0.001, 0.06, 0.0, 0.12, 58.0)
	_tone(2400.0, 0.045, 0.10, "square", 0.001, 0.02, 0.0, 0.04, 1700.0)


func play_part_detach() -> void:
	_noise(0.12, 0.20, 0.14, 0.001, 0.06, 0.0, 0.10)
	_tone(140.0, 0.12, 0.20, "sine", 0.001, 0.05, 0.0, 0.10, 70.0)


func play_warning_buzzer() -> void:
	_tone(196.0, 0.30, 0.20, "square", 0.004, 0.02, 0.85, 0.08)
	_tone(146.0, 0.30, 0.14, "saw", 0.004, 0.02, 0.80, 0.08)


func play_success_chime() -> void:
	_tone(784.0, 0.10, 0.14, "sine", 0.003, 0.05, 0.3, 0.10)
	_tone(1046.5, 0.14, 0.13, "sine", 0.003, 0.05, 0.3, 0.12)
	_tone(1318.5, 0.18, 0.12, "sine", 0.003, 0.05, 0.3, 0.16)


# ------------------------------------------------------------------------------
# 2. LAUNCH
# ------------------------------------------------------------------------------

func play_countdown_beep(is_final: bool = false) -> void:
	if is_final:
		_tone(1200.0, 0.22, 0.22, "square", 0.002, 0.04, 0.6, 0.12)
		_tone(1600.0, 0.22, 0.10, "sine", 0.002, 0.04, 0.5, 0.12)
	else:
		_tone(880.0, 0.09, 0.16, "square", 0.002, 0.03, 0.4, 0.06)


func play_telemetry_tick() -> void:
	_tone(2200.0, 0.02, 0.05, "sine", 0.001, 0.01, 0.0, 0.02)


# Continuous engine roar. Call once, then modulate with set_engine_level().
func start_engine_roar() -> void:
	if _engine_voice != null and _engine_voice.alive:
		return
	var v := Voice.new()
	v.kind = KIND_NOISE
	v.loop = true
	v.amp = 0.55
	v.lp_coeff = 0.06
	v.gain_scale = 0.0
	v.gain_target = 0.0
	v.gain_smooth = 3.0
	_engine_voice = _add_voice(v)
	# Sub-bass rumble layer
	var sub := Voice.new()
	sub.kind = KIND_TONE
	sub.wave = "sine"
	sub.freq = 42.0
	sub.freq_end = 42.0
	sub.loop = true
	sub.amp = 0.30
	sub.gain_scale = 0.0
	sub.gain_target = 0.0
	sub.gain_smooth = 3.0
	_engine_voice.set_meta("sub", _add_voice(sub))


# throttle 0..1, density 0..1 (1 = sea level, 0 = vacuum)
func set_engine_level(throttle: float, density: float) -> void:
	if _engine_voice == null or not _engine_voice.alive:
		return
	var t: float = clampf(throttle, 0.0, 1.0)
	var d: float = clampf(density, 0.0, 1.0)
	# Roar is loudest in thick air; vacuum gives a thin, quieter burn
	_engine_voice.gain_target = t * lerpf(0.22, 1.0, d)
	_engine_voice.lp_coeff = lerpf(0.03, 0.30, d)
	_engine_voice.freq = lerpf(60.0, 110.0, d)
	var sub = _engine_voice.get_meta("sub", null)
	if sub != null and sub.alive:
		sub.gain_target = t * lerpf(0.12, 0.55, d)
		sub.freq = lerpf(38.0, 52.0, d)


func stop_engine_roar() -> void:
	if _engine_voice != null and _engine_voice.alive:
		_engine_voice.gain_target = 0.0
		_engine_voice.release = 0.35
		_engine_voice.duration = _engine_voice.t
		_engine_voice.loop = false
		_engine_voice.sustain = 0.0
		var sub = _engine_voice.get_meta("sub", null)
		if sub != null and sub.alive:
			sub.gain_target = 0.0
			sub.loop = false
			sub.duration = sub.t
			sub.sustain = 0.0
			sub.release = 0.35


# Explosive separation thump (MECO / staging / fairing)
func play_thump(intensity: float = 1.0) -> void:
	var k: float = clampf(intensity, 0.2, 1.5)
	_noise(0.28, 0.42 * k, 0.05, 0.001, 0.10, 0.05, 0.24)
	_tone(70.0, 0.34, 0.40 * k, "sine", 0.001, 0.08, 0.0, 0.28, 34.0)
	_tone(180.0, 0.10, 0.16 * k, "square", 0.001, 0.03, 0.0, 0.08, 90.0)


func play_meco() -> void:
	play_thump(0.7)
	_tone(520.0, 0.30, 0.10, "sine", 0.01, 0.10, 0.2, 0.20, 300.0)


# ------------------------------------------------------------------------------
# 3. SPACE & CRISIS
# ------------------------------------------------------------------------------

func start_space_ambient() -> void:
	if _ambient_voice != null and _ambient_voice.alive:
		return
	var v := Voice.new()
	v.kind = KIND_TONE
	v.wave = "sine"
	v.freq = 55.0
	v.freq_end = 55.0
	v.loop = true
	v.amp = 0.10
	v.gain_scale = 0.0
	v.gain_target = 1.0
	v.gain_smooth = 0.8
	v.tremolo_hz = 0.13
	v.tremolo_depth = 0.35
	_ambient_voice = _add_voice(v)
	var shimmer := Voice.new()
	shimmer.kind = KIND_TONE
	shimmer.wave = "sine"
	shimmer.freq = 164.8
	shimmer.freq_end = 164.8
	shimmer.loop = true
	shimmer.amp = 0.030
	shimmer.gain_scale = 0.0
	shimmer.gain_target = 1.0
	shimmer.gain_smooth = 0.5
	shimmer.tremolo_hz = 0.07
	shimmer.tremolo_depth = 0.6
	_ambient_voice.set_meta("shimmer", _add_voice(shimmer))


func stop_space_ambient() -> void:
	var targets: Array = []
	if _ambient_voice != null:
		targets.append(_ambient_voice)
		var shimmer = _ambient_voice.get_meta("shimmer", null)
		if shimmer != null:
			targets.append(shimmer)
	for v in targets:
		if v != null and v.alive:
			v.loop = false
			v.duration = v.t
			v.sustain = 0.0
			v.release = 0.8
			v.gain_target = 0.0


func play_rcs_hiss() -> void:
	_noise(0.22, 0.20, 0.55, 0.006, 0.05, 0.25, 0.16)


func play_radar_ping() -> void:
	_tone(1400.0, 0.16, 0.16, "sine", 0.002, 0.06, 0.15, 0.14, 900.0)
	_tone(2100.0, 0.10, 0.06, "sine", 0.002, 0.04, 0.0, 0.10)


func start_klaxon() -> void:
	if _klaxon_voice != null and _klaxon_voice.alive:
		return
	var v := Voice.new()
	v.kind = KIND_TONE
	v.wave = "square"
	v.freq = 740.0
	v.freq_end = 520.0
	v.loop = true
	v.duration = 0.55
	v.amp = 0.20
	v.gain_scale = 0.0
	v.gain_target = 1.0
	v.gain_smooth = 8.0
	v.tremolo_hz = 2.2
	v.tremolo_depth = 0.55
	_klaxon_voice = _add_voice(v)


func stop_klaxon() -> void:
	if _klaxon_voice != null and _klaxon_voice.alive:
		_klaxon_voice.loop = false
		_klaxon_voice.duration = _klaxon_voice.t
		_klaxon_voice.sustain = 0.0
		_klaxon_voice.release = 0.25
		_klaxon_voice.gain_target = 0.0


func play_victory_fanfare() -> void:
	# Rising major arpeggio with a bright tail
	var notes: Array = [523.25, 659.25, 783.99, 1046.5]
	for i in notes.size():
		var v := _tone(notes[i], 0.16, 0.20, "sine", 0.004, 0.05, 0.5, 0.14)
		v.t = -0.13 * i
	_tone(1046.5, 0.55, 0.16, "sine", 0.01, 0.10, 0.45, 0.40)
	_tone(1567.98, 0.50, 0.09, "sine", 0.01, 0.10, 0.35, 0.40)


func play_failure_powerdown() -> void:
	# Descending detuned power-down with a dying reactor hum
	_tone(392.0, 0.70, 0.22, "saw", 0.01, 0.20, 0.35, 0.50, 98.0)
	_tone(196.0, 0.85, 0.16, "square", 0.01, 0.25, 0.30, 0.55, 49.0)
	_noise(0.60, 0.14, 0.04, 0.02, 0.20, 0.15, 0.45)


# ------------------------------------------------------------------------------
# Mute control
# ------------------------------------------------------------------------------

func set_muted(value: bool) -> void:
	muted = value
	if muted:
		stop_klaxon()


func toggle_mute() -> bool:
	set_muted(not muted)
	return muted


# Builds a standard [SOUND: ON/OFF] HUD button and wires it to this engine.
func create_mute_button() -> Button:
	var btn := Button.new()
	btn.name = "SoundToggleBtn"
	btn.text = "SOUND: OFF" if muted else "SOUND: ON"
	btn.tooltip_text = "Toggle all procedural game audio."
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(118, 30)
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(func() -> void:
		var now_muted: bool = toggle_mute()
		btn.text = "SOUND: OFF" if now_muted else "SOUND: ON"
		if not now_muted:
			play_ui_click()
	)
	return btn


# Finds the scene's TopBar and appends the [SOUND: ON/OFF] toggle.
# Safe to call from any controller _ready(); no-ops if no TopBar exists.
func attach_hud_toggle(root_ui: Control) -> Button:
	if root_ui == null:
		return null
	var existing := root_ui.find_child("SoundToggleBtn", true, false) as Button
	if existing != null:
		return existing
	var bar := root_ui.find_child("TopBar", true, false) as HBoxContainer
	if bar == null:
		return null
	var btn := create_mute_button()
	bar.add_child(btn)
	return btn
