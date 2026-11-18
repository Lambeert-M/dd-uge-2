extends Control

@onready var play_button: TextureButton = $MainMenuPlayButton
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	play_button.pressed.connect(button_pressed)
	AudioPlayer.play_custom_track("res://Resources/Audio/Music/Theme For Ernie (Remastered 2026) (320kbps).mp3")

	# Vis den gemte lydstyrke (sættes før connect, så den ikke kalder set_..._volume igen)
	music_slider.value = AudioPlayer.music_volume
	music_slider.value_changed.connect(AudioPlayer.set_music_volume)
	# Gem til disk, når musen slippes (sker også ved et enkelt klik på baren)
	music_slider.drag_ended.connect(func(_changed: bool): AudioPlayer.save_settings())

	sfx_slider.value = AudioPlayer.sfx_volume
	sfx_slider.value_changed.connect(AudioPlayer.set_sfx_volume)
	sfx_slider.drag_ended.connect(_on_sfx_slider_released)


func _on_sfx_slider_released(_changed: bool) -> void:
	AudioPlayer.save_settings()
	# Prøvelyd, så man kan høre den nye lydstyrke (titelskærmen har ellers ingen lydeffekter)
	AudioPlayer.play_sound_effect("res://Resources/Audio/SoundEffects/GameObjectSoundEffects/bell_ring.mp3")


func button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes&Scripts/main/main.tscn")
