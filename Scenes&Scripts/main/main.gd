extends Node2D

const TITLE_SCENE := "res://Scenes&Scripts/InteractiveScenes/titlescreen.tscn"

@onready var work_place := $WorkPlace

# Var kundens dialogboks åben, da spillet blev sat på pause? Så vises den igen ved PLAY.
var dialogue_was_open := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AudioPlayer.play_custom_track("res://Resources/Audio/Music/Theme For Ernie (Remastered 2026) (320kbps).mp3")
	AudioPlayer.music_player.volume_db = 0.0


# Kører også, når PLAY sætter spillet ind igen. Første gang er noden ikke klar endnu.
func _enter_tree() -> void:
	if is_node_ready() and dialogue_was_open:
		DialogueBox.show()


# Escape: tilbage til titelskærmen. _input kommer før GUI'en, så det virker også,
# mens der skrives i notepapiret eller svarfeltet.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		# Udskudt, så noden ikke fjernes fra træet midt i input-behandlingen
		_go_to_title.call_deferred()


func _go_to_title() -> void:
	# Er Escape trykket to gange i samme frame, er spillet allerede væk
	if not is_inside_tree():
		return

	# Fyret: der er intet at fortsætte, så spillet lukkes, og PLAY starter et nyt job.
	# Vent som Retry, til nulstillingen er gemt, så et nyt spil ikke henter det gamle fremskridt.
	if Global.game_over:
		if work_place.retry_button.disabled:
			return
		get_tree().change_scene_to_file(TITLE_SCENE)
		return

	# Escape midt i et træk virker som at slippe papiret
	work_place.release_boards()
	# Dialogerne er autoloads og ville ellers ligge over titelskærmen (og tage klikket på PLAY).
	# hide() i stedet for at lukke dem, så kunden stadig venter på, at dialogen slutter.
	dialogue_was_open = DialogueBox.visible
	DialogueBox.hide()
	DialogueText.hide()

	# Uden for træet står alt stille: input, _process og de tweens, der er bundet til noder.
	# current_scene bliver null, når noden fjernes, så scene-skiftet frigør den ikke.
	var tree := get_tree()
	get_parent().remove_child(self)
	Global.park_game(self)
	tree.change_scene_to_file(TITLE_SCENE)
