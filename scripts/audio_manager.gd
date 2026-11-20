extends Node

# Audio files
var sound_streams: Dictionary = {}
var is_muted: bool = false
var master_volume: float = 1.0

# Player references
var propeller_player: AudioStreamPlayer
var charge_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var max_sfx_pool: int = 6

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_sounds()
	_setup_players()

func _load_sounds() -> void:
	var sound_names = [
		"propeller_hum",
		"charge",
		"success_ding",
		"warning_buzz",
		"click",
		"victory",
		"game_over"
	]
	
	for s_name in sound_names:
		var path = "res://audio/" + s_name + ".wav"
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream is AudioStreamWAV:
				if s_name == "propeller_hum":
					stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				elif s_name == "charge":
					stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
			sound_streams[s_name] = stream

func _setup_players() -> void:
	# Dedicated loop player for drone rotor
	propeller_player = AudioStreamPlayer.new()
	propeller_player.bus = "Master"
	propeller_player.volume_db = -12.0
	if sound_streams.has("propeller_hum"):
		propeller_player.stream = sound_streams["propeller_hum"]
	add_child(propeller_player)

	# Dedicated charge player for 2s loading/unloading
	charge_player = AudioStreamPlayer.new()
	charge_player.bus = "Master"
	charge_player.volume_db = -4.0
	if sound_streams.has("charge"):
		charge_player.stream = sound_streams["charge"]
	add_child(charge_player)

	# Pool for one-shot SFX
	for i in range(max_sfx_pool):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)

func play_sfx(sound_name: String, pitch_scale: float = 1.0) -> void:
	if is_muted:
		return
	if not sound_streams.has(sound_name):
		return
		
	var stream = sound_streams[sound_name]
	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch_scale
			p.volume_db = -2.0
			p.play()
			return
			
	# If all busy, reuse the first one
	var p = sfx_players[0]
	p.stop()
	p.stream = stream
	p.pitch_scale = pitch_scale
	p.volume_db = -2.0
	p.play()

func start_propeller() -> void:
	if is_muted:
		return
	if propeller_player and not propeller_player.playing:
		propeller_player.play()

func stop_propeller() -> void:
	if propeller_player:
		propeller_player.stop()

func set_propeller_pitch(pitch: float) -> void:
	if propeller_player:
		propeller_player.pitch_scale = clampf(pitch, 0.8, 1.4)

func start_charge() -> void:
	if is_muted:
		return
	if charge_player:
		charge_player.stop()
		charge_player.play()

func stop_charge() -> void:
	if charge_player and charge_player.playing:
		charge_player.stop()

func toggle_mute() -> bool:
	is_muted = not is_muted
	if is_muted:
		stop_propeller()
		stop_charge()
		for p in sfx_players:
			p.stop()
	else:
		start_propeller()
	return is_muted

func stop_all() -> void:
	stop_propeller()
	stop_charge()
	for p in sfx_players:
		p.stop()
