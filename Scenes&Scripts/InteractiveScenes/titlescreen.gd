extends Control

const MAIN_SCENE := "res://Scenes&Scripts/main/main.tscn"
const LEADERBOARD_SCENE := "res://Scenes&Scripts/InteractiveScenes/leaderboard.tscn"

@onready var play_button: TextureButton = $MainMenuPlayButton
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var login_button: Button = $MainMenuLoginButton
@onready var leaderboard_button: Button = $MainMenuLeaderboardButton
@onready var login_status_label: Label = %LoginStatusLabel
@onready var paused_game_label: Label = %PausedGameLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	play_button.pressed.connect(button_pressed)
	login_button.pressed.connect(_on_login_pressed)
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	if Global.is_logged_in():
		login_status_label.text = "Logget ind som %s" % Global.current_user["user_name"]
	else:
		login_status_label.text = "Ikke logget ind"

	# Et spil på pause, som en anden spiller startede (en gæst, der har logget ind imens),
	# må ikke fortsættes: det smides væk, og PLAY henter brugerens eget fremskridt.
	if is_instance_valid(Global.paused_game) and not Global.can_resume_game():
		Global.discard_paused_game()
	_update_paused_game_label()

	AudioPlayer.play_custom_track("res://Resources/Audio/Music/Theme For Ernie (Remastered 2026) (320kbps).mp3")
	# Musikken kan være fadet ud af game over-skærmen (Escape, efter man er blevet fyret)
	AudioPlayer.music_player.volume_db = 0.0

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


func _update_paused_game_label() -> void:
	if not Global.can_resume_game():
		paused_game_label.hide()
		return
	if Global.is_logged_in():
		paused_game_label.text = "Tryk PLAY for at fortsætte"
	else:
		paused_game_label.text = "Tryk PLAY for at fortsætte – logger du ind, starter et nyt spil"
	paused_game_label.show()


# PLAY: fortsæt spillet på pause, hvis der er et, ellers start et nyt
func button_pressed() -> void:
	if Global.can_resume_game():
		get_tree().change_scene_to_node(Global.take_paused_game())
	else:
		Global.discard_paused_game()
		get_tree().change_scene_to_file(MAIN_SCENE)


func _on_login_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes&Scripts/InteractiveScenes/login.tscn")


# Leaderboardet kan ses af alle, også uden login. Et spil på pause ligger i Global
# og kan stadig fortsættes, når man kommer tilbage.
func _on_leaderboard_pressed() -> void:
	get_tree().change_scene_to_file(LEADERBOARD_SCENE)
