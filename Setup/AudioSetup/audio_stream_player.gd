extends Node
# Autoload

@onready var music_player: AudioStreamPlayer = $MusicPlayer

# Lydstyrken styres på busserne "Music" og "SFX" (default_bus_layout.tres), ikke på de enkelte players.
# På den måde kan fades (fx game over) bruge music_player.volume_db uden at overskrive spillerens indstilling.
const SETTINGS_PATH := "user://settings.cfg"
var music_volume: float = 1.0  # 0.0 = slukket, 1.0 = fuld styrke
var sfx_volume: float = 1.0    # alle lydeffekter, der ikke er musik

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		music_volume = config.get_value("audio", "music_volume", 1.0)
		sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
	_apply_bus_volume("Music", music_volume)
	_apply_bus_volume("SFX", sfx_volume)

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume("Music", music_volume)

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume("SFX", sfx_volume)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)  # behold andre indstillinger, der allerede ligger i filen
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save(SETTINGS_PATH)

func _apply_bus_volume(bus_name: String, value: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(bus, linear_to_db(value))  # 0..1 -> decibel
	AudioServer.set_bus_mute(bus, value <= 0.0)  # helt til venstre = helt slukket

func play_sound_effect(file_path: String) -> void:
	var sound := load(file_path) as AudioStream
	if sound == null:
		push_error("Could not load sound: " + file_path)
		return
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = sound
	sfx_player.bus = &"SFX"  # så lydeffekt-slideren styrer den
	add_child(sfx_player)
	sfx_player.finished.connect(sfx_player.queue_free)
	sfx_player.play()

# Forward the music functions so everything goes through one name
func play_custom_track(file_path: String) -> void:
	music_player.play_custom_track(file_path)

func stop_music() -> void:
	music_player.stop_music()
