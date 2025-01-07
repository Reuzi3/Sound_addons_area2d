@icon("res://addons/audio_manager/sound.png")

extends Area2D

# Nome do som que será tocado ao entrar na área (customizável no Inspetor)
@export_category("Audio Settings")
@export var audio_name: String = "Nome do audio"
# Variável que aparece como "Audio name" no Inspetor

# Flag para evitar conflito entre play e stop
var is_transitioning: bool = false
var pending_entry: bool = false  # Indica se há uma entrada pendente

# Função chamada quando o corpo entra na área
func _on_body_entered(_body: Node2D) -> void:
	if audio_name == "":
		return
	
	if is_transitioning:
		pending_entry = true  # Marca que há uma entrada pendente
		print("Entrada pendente para: ", audio_name)
	else:
		AudioManager.play_sound(audio_name)
		print("Reproduzindo som: ", audio_name)

# Função chamada quando o corpo sai da área
func _on_body_exited(_body: Node2D) -> void:
	if audio_name == "":
		return
	
	is_transitioning = true  # Sinaliza que estamos em transição
	pending_entry = false  # Limpa qualquer entrada pendente
	await AudioManager.stop_sound(audio_name)  # Aguarda o fade-out
	is_transitioning = false
	print("Parou de tocar: ", audio_name)

	# Reproduz o som novamente se houver uma entrada pendente
	if pending_entry:
		AudioManager.play_sound(audio_name)
		print("Reproduzindo som após saída rápida: ", audio_name)
