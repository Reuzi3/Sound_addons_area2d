@tool
extends Node2D

@export_subgroup("Sound Settings")
@export var audio_type : String = "AudioStreamPlayer"
@export_range(0.0, 1.0, 0.1) var default_volume : float = 1.0
@export_range(0.0, 1.0, 0.1) var default_pitch : float = 1.0

@export_subgroup("List of sounds", "sounds_")
@export var sounds: Array[SoundEntry] = []

# Clip Dictionary
var audio_clips : Dictionary = {}
var active_players : Array = []  # Para rastrear todos os players em execução

var is_fading_out: bool = false  # Para evitar conflitos durante o fade out
var current_audio_name: String = ""  # Nome do som atualmente tocando

func _ready():
	for sound_entry in sounds:
		if sound_entry.audio != null and sound_entry.audio is AudioStream:
			audio_clips[sound_entry.audio_name] = sound_entry
		else:
			print("Error: Invalid or missing audio in sound entry:", sound_entry.name)

# Function to play sound with optional fade in
func play_sound(audio_name: String, fade_in_duration: float = 0.6):
	if not audio_clips.has(audio_name):
		return

	var sound_entry: SoundEntry = audio_clips[audio_name]

	# Ajuste de tempos de início e fim
	var start_time = sound_entry.start_time
	var end_time = sound_entry.end_time if sound_entry.end_time > 0 else sound_entry.audio.get_length()
	var duration = end_time - start_time

	if duration <= 0:
		print("Error: Invalid start_time or end_time for:", audio_name)
		return

	# Verifica se é um AudioStreamRandomizer
	if sound_entry.audio is AudioStreamRandomizer:
		print("Playing AudioStreamRandomizer:", audio_name)

	if sound_entry.BGM:
		if audio_name == current_audio_name:
			return  # Já está tocando essa BGM

		# Aguarda o fade out do som atual, se necessário
		if is_fading_out:
			await wait_for_fade_out_to_complete()

		# Toca a nova BGM com fade in
		var sound_player = create_audio_stream_player()
		add_child(sound_player)
		sound_player.stream = sound_entry.audio
		sound_player.volume_db = -80.0  # Inicia mudo para fazer fade in
		sound_player.pitch_scale = sound_entry.audio_pitch if sound_entry.audio_pitch != 0 else default_pitch
		sound_player.play(start_time)
		active_players.append(sound_player)

		# Atualiza o nome da BGM atual
		current_audio_name = audio_name

		# Fade in para o volume desejado
		fade_in(sound_player, sound_entry.audio_volume if sound_entry.audio_volume != 0 else default_volume, fade_in_duration)

		# Timer para interromper o áudio no end_time
		if end_time < sound_entry.audio.get_length():
			var timer = Timer.new()
			timer.one_shot = true
			timer.wait_time = duration
			add_child(timer)
			timer.timeout.connect(func():
				if is_instance_valid(sound_player):
					sound_player.stop()
					active_players.erase(sound_player)
					sound_player.queue_free())
			timer.start()
	else:
		# Para SFX ou outros tipos, toca imediatamente respeitando start_time e end_time
		var sound_player = create_audio_stream_player()
		add_child(sound_player)
		sound_player.stream = sound_entry.audio
		sound_player.volume_db = linear_to_db(sound_entry.audio_volume)
		sound_player.pitch_scale = sound_entry.audio_pitch
		sound_player.play(start_time)
		active_players.append(sound_player)

		# Timer para interromper o áudio no end_time
		if end_time < sound_entry.audio.get_length():
			var timer = Timer.new()
			timer.one_shot = true
			timer.wait_time = duration
			add_child(timer)
			timer.timeout.connect(func():
				if is_instance_valid(sound_player):
					sound_player.stop()
					active_players.erase(sound_player)
					sound_player.queue_free())
			timer.start()

		# Remove o player quando o som terminar (se não houver end_time definido)
		sound_player.finished.connect(func():
			active_players.erase(sound_player)
			sound_player.queue_free())

# Function to stop sound with fade out (apenas o som especificado)
func stop_sound(audio_name: String, fade_out_duration: float = 1.8) -> void:
	if audio_name == "":
		print("Error: No audio name provided to stop.")
		return  # Não faz nada se nenhum nome for fornecido

	# Procura o player associado ao nome do som
	var target_player: AudioStreamPlayer = null
	for sound_player in active_players:
		if sound_player.stream == audio_clips.get(audio_name, null).audio:
			target_player = sound_player
			break

	if target_player != null:
		await fade_out(target_player, fade_out_duration)
		current_audio_name = ""  # Reseta o nome da música atual após o fade out
	else:
		print("No active sound found for:", audio_name)

# Fade out implementation (suave e assíncrono)
func fade_out(sound_player: AudioStreamPlayer, duration: float) -> void:
	is_fading_out = true
	if not is_instance_valid(sound_player):
		is_fading_out = false
		return
	var initial_volume = sound_player.volume_db
	var steps = int(duration * 60.0)
	var step_value = (initial_volume - -80.0) / steps
	for i in range(steps):
		if not is_instance_valid(sound_player):
			is_fading_out = false
			return
		sound_player.volume_db -= step_value
		await get_tree().create_timer(0.016).timeout  # 1/60 de segundo por frame
	if is_instance_valid(sound_player):
		sound_player.stop()
		active_players.erase(sound_player)
		sound_player.queue_free()
	is_fading_out = false

# Fade in implementation
func fade_in(sound_player: AudioStreamPlayer, target_volume: float, duration: float):
	if not is_instance_valid(sound_player):
		return
	var steps = int(duration * 60.0)
	var step_value = (linear_to_db(target_volume) - sound_player.volume_db) / steps
	for i in range(steps):
		if not is_instance_valid(sound_player):
			return
		sound_player.volume_db += step_value
		await get_tree().create_timer(0.016).timeout

# Função para aguardar o término do fade out
func wait_for_fade_out_to_complete():
	while is_fading_out:
		await get_tree().create_timer(0.1).timeout

# Create the audioplayer based on the type in editor
func create_audio_stream_player() -> Node:
	match audio_type:
		"AudioStreamPlayer2D":
			return AudioStreamPlayer2D.new()
		"AudioStreamPlayer3D":
			return AudioStreamPlayer3D.new()
		_:
			return AudioStreamPlayer.new()
