extends Node

# Automatisk test af Escape → titelskærmen → PLAY (main.gd, titlescreen.gd og Global.paused_game).
# Kør scenen. Den skriver intet til databasen og bruger ingen af de 30 oprettelser i timen:
# den "logger ind" som bruger-id 0 (findes aldrig), så hentningen bare giver en ny spiller.
# Hentningen kræver forbindelse til databasen. Lukker selv (exit code 1 hvis noget fejlede).

const AUTO_QUIT := true
const MAIN_SCENE := preload("res://Scenes&Scripts/main/main.tscn")
const TITLE_PATH := "res://Scenes&Scripts/InteractiveScenes/titlescreen.tscn"
const REQUEST_TIMEOUT := 10.0
const ANIMATION_TIMEOUT := 6.0

var bot: TestBot

func _ready() -> void:
	bot = TestBot.new()
	add_child(bot)
	_run.call_deferred()

func _run() -> void:
	Global.current_user = {}
	Global.savings = 0.0

	# Main skal være current_scene som i spillet. Testnoden er så ikke længere current_scene
	# og overlever skiftene til titelskærmen.
	var main := MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await bot.wait_frames(2)
	var wp = main.work_place

	# 1. Gæst: Escape midt i en sprint, mens kunden går ind, et papir trækkes og en dialog er åben
	wp.sprint_money = 25.0
	wp.served_during_sprint = 1
	var note := _find_board(func(b): return b is NotePaper) as NotePaper
	note.text_edit.text = "mine noter"
	var dragged := _find_board(func(b): return not b is NotePaper) as Board
	dragged.dragging = true
	DialogueBox.start("Test", PackedStringArray(["linje 1", "linje 2"]))
	wp.customer_arrive()
	await bot.wait_frames(2)
	var customer: Customer = wp.current_customer

	await bot.press_key(KEY_ESCAPE)
	await bot.wait_frames(2)
	var title := get_tree().current_scene
	bot.check(title != null and title.scene_file_path == TITLE_PATH, "Escape skifter til titelskærmen")
	bot.check(Global.paused_game == main, "Spillet er sat på pause i Global")
	bot.check(is_instance_valid(main) and not main.is_inside_tree(), "Spillet findes stadig, men uden for scenetræet")
	bot.check(not DialogueBox.visible, "Dialogboksen er skjult på titelskærmen")
	bot.check(not dragged.dragging, "Papiret, der blev trukket, er sluppet")
	bot.check(title.paused_game_label.visible and "logger du ind" in title.paused_game_label.text,
		"Titelskærmen advarer gæsten om, at login starter et nyt spil")

	var parked_x := customer.position.x
	await bot.wait(1.5)
	bot.check_near(customer.position.x, parked_x, 0.001, "Kunden står stille, mens spillet er på pause")
	bot.check(not DialogueText.visible, "Kundens hilsen vises ikke på titelskærmen")
	await bot.screenshot("pause_01_title")

	# 2. PLAY: det samme spil kommer tilbage, præcis som det var
	title.play_button.pressed.emit()
	await bot.wait_frames(2)
	bot.check(get_tree().current_scene == main, "PLAY sætter det samme spil ind igen")
	bot.check(Global.paused_game == null, "Intet spil er på pause længere")
	bot.check_near(wp.sprint_money, 25.0, 0.001, "Sprintens penge er bevaret")
	bot.check_equal(wp.served_during_sprint, 1, "Antal betjente kunder er bevaret")
	bot.check_equal(note.text_edit.text, "mine noter", "Noterne er bevaret")
	bot.check(DialogueBox.visible, "Dialogboksen vises igen")
	DialogueBox.hide()
	bot.check(await _wait_until(func(): return customer.can_interact, ANIMATION_TIMEOUT),
		"Kunden går færdig ind efter pausen")
	bot.check(DialogueText.visible, "Kunden hilser, når den er gået ind")
	await bot.screenshot("pause_02_resumed")
	DialogueText.hide()

	# 3. Game over: Escape venter, til Retry kan trykkes, og PLAY starter så et nyt job
	wp.sprint_money = 0.0
	wp.finish_sprint()
	await bot.press_key(KEY_ESCAPE)
	await bot.wait_frames(2)
	bot.check(get_tree().current_scene == main, "Escape virker ikke, før game over-skærmen er færdig")
	bot.check(await _wait_until(func(): return not wp.retry_button.disabled, ANIMATION_TIMEOUT),
		"Retry kan trykkes efter animationen")
	await bot.press_key(KEY_ESCAPE)
	await bot.wait_frames(2)
	title = get_tree().current_scene
	bot.check(title != null and title.scene_file_path == TITLE_PATH, "Escape efter game over går til titelskærmen")
	bot.check(Global.paused_game == null, "Et tabt spil sættes ikke på pause")
	bot.check(not is_instance_valid(main), "Det tabte spil er frigjort")
	bot.check(not title.paused_game_label.visible, "Titelskærmen viser ingen 'fortsæt'-tekst")
	bot.check_near(AudioPlayer.music_player.volume_db, 0.0, 0.001, "Musikken er skruet op igen på titelskærmen")
	title.play_button.pressed.emit()
	await bot.wait_frames(2)
	main = get_tree().current_scene
	wp = main.work_place
	bot.check(not Global.game_over, "PLAY starter et nyt job efter game over")
	bot.check_near(wp.sprint_money, 0.0, 0.001, "Det nye job starter med 0 kr")

	# 4. Gæst → login: gæstespillet smides væk, og brugerens fremskridt hentes
	wp.sprint_money = 30.0
	await bot.press_key(KEY_ESCAPE)
	await bot.wait_frames(2)
	var guest_game := main
	bot.check(Global.can_resume_game(), "Gæstens spil er på pause")
	# Som login.gd: id kommer fra JSON som float, og login vender tilbage til titelskærmen
	Global.current_user = {"id": 0.0, "user_name": "testbot_pause"}
	get_tree().change_scene_to_file(TITLE_PATH)
	await bot.wait_frames(3)
	title = get_tree().current_scene
	bot.check(Global.paused_game == null, "Gæstespillet er smidt væk efter login")
	bot.check(not is_instance_valid(guest_game), "Gæstespillet er frigjort")
	bot.check(not title.paused_game_label.visible, "Titelskærmen viser ingen 'fortsæt'-tekst efter login")
	title.play_button.pressed.emit()
	await bot.wait_frames(2)
	main = get_tree().current_scene
	wp = main.work_place
	bot.check(main != null and main.scene_file_path == MAIN_SCENE.resource_path, "PLAY starter et nyt spil")
	bot.check_near(wp.sprint_money, 0.0, 0.001, "Gæstens 30 kr følger ikke med ind på kontoen")
	bot.check(await _wait_until(func(): return not wp.is_loading_progress, REQUEST_TIMEOUT),
		"Brugerens fremskridt blev hentet inden for %d s" % REQUEST_TIMEOUT)
	bot.check(wp.has_loaded_progress, "Hentningen lykkedes")
	bot.check_equal(wp.sprint_size, 3, "Bruger uden gemt fremskridt starter i første sprint")

	# 5. Logget ind: Escape og PLAY giver det samme spil tilbage
	wp.sprint_money = 12.0
	wp.served_during_sprint = 2
	await bot.press_key(KEY_ESCAPE)
	await bot.wait_frames(2)
	title = get_tree().current_scene
	bot.check_equal(Global.paused_game_owner, 0, "Spillet på pause tilhører brugeren")
	bot.check_equal(title.paused_game_label.text, "Tryk PLAY for at fortsætte", "Titelskærmen tilbyder at fortsætte")
	title.play_button.pressed.emit()
	await bot.wait_frames(2)
	bot.check(get_tree().current_scene == main, "Brugeren får det samme spil tilbage")
	bot.check_near(wp.sprint_money, 12.0, 0.001, "Brugerens sprintpenge er bevaret")
	bot.check_equal(wp.served_during_sprint, 2, "Brugerens betjente kunder er bevaret")

	# Ryd op
	Global.current_user = {}
	Global.discard_paused_game()
	Global.savings = 0.0
	bot.finish(AUTO_QUIT)

func _find_board(condition: Callable) -> Board:
	for b in get_tree().get_nodes_in_group("boards"):
		if condition.call(b):
			return b
	return null

# Vent til condition() er sand, højst timeout sekunder
func _wait_until(condition: Callable, timeout: float) -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000)
	while not condition.call():
		if Time.get_ticks_msec() > end:
			return false
		await bot.wait_frames(1)
	return true
