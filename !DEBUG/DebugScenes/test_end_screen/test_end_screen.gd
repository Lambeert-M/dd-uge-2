extends Node

# Automatisk test af slutskærmen (EndScreen), der vises, når en dag (sprint) er klaret.
# Spiller som gæst, så den skriver intet til databasen og bruger ingen af de 30 oprettelser i timen.
# Lukker selv (exit code 1 hvis noget fejlede).
# Kør den med --headless for at teste, at papirerne ikke kan trækkes: i et vindue læser Board
# den rigtige cursor (get_global_mouse_position()), så TestBots falske træk rammer ikke.
# Uden --headless springes de to træk-tjek over, men screenshottet tages.

const AUTO_QUIT := true
const WORK_PLACE := preload("res://Scenes&Scripts/work_place/work_place.tscn")
const ANIMATION_TIMEOUT := 6.0
const POP_WAIT := 0.5 # slutskærmens pop-animation er færdig
const GAME_OVER_WAIT := 4.0 # længere end popups'ene før slutskærmen (ca. 3 s)

var bot: TestBot

func _ready() -> void:
	bot = TestBot.new()
	add_child(bot)
	_run.call_deferred()

func _run() -> void:
	Global.current_user = {}
	Global.savings = 0.0
	Global.game_over = false

	# 1. Dagen klares med 46 kr (kvote 40): popups først, ingen kunder imens
	var wp = WORK_PLACE.instantiate()
	add_child(wp)
	await bot.wait_frames(2)
	wp.sprint_money = 46.0
	wp.finish_sprint()
	bot.check(wp.is_day_over, "Dagen er slut, når kvoten er nået")
	bot.check(wp.end_screen == null, "Slutskærmen venter, til popups'ene er færdige")
	wp.customer_arrive()
	bot.check(wp.current_customer == null, "Klokken kalder ingen kunde, når dagen er slut")

	# 2. Slutskærmen viser dagens tal, og næste dag er ikke startet
	bot.check(await _wait_until(func(): return wp.end_screen != null, ANIMATION_TIMEOUT),
		"Slutskærmen vises efter popups'ene")
	var screen: EndScreen = wp.end_screen
	if screen == null:
		bot.finish(AUTO_QUIT)
		return
	bot.check(screen.is_inside_tree() and screen.get_parent() == wp, "Slutskærmen er et barn af arbejdspladsen")
	bot.check_equal(screen.earned_label.text, TaxForm._kr(46.0), "Slutskærmen viser dagens penge")
	bot.check_equal(screen.quota_label.text, TaxForm._kr(40.0), "Slutskærmen viser kvoten")
	bot.check_equal(screen.kept_label.text, TaxForm._kr(6.0), "Slutskærmen viser det, spilleren beholder")
	bot.check_equal(screen.next_day_button.text, "Start næste dag", "Knappen hedder \"Start næste dag\"")
	bot.check(Global.boards_locked, "Boardene er låst, mens slutskærmen er åben")
	bot.check_equal(wp.sprint_size, 3, "Næste dag starter ikke, før knappen trykkes")
	bot.check_near(Global.savings, 6.0, 0.001, "De 6 kr er lagt i opsparingen")
	await bot.wait(POP_WAIT)
	await bot.screenshot("end_screen_01_open")

	# 3. Papirerne kan ikke trækkes, og klokken kan ikke kalde en kunde
	var can_drag := DisplayServer.get_name() == "headless"
	var note := _find_board(func(b): return b is NotePaper) as Board
	if can_drag:
		var start_pos: Vector2 = note.global_position
		var grab: Vector2 = note.global_position + note.size / 2.0
		await bot.drag(grab, grab + Vector2(0, -200))
		bot.check(note.global_position.distance_to(start_pos) < 0.01, "Notepapiret kan ikke trækkes under slutskærmen")
	else:
		print("[test_end_screen] Springer træk-tjekkene over (kør med --headless)")
	wp.customer_arrive()
	bot.check(wp.current_customer == null, "Ingen kunde kommer, mens slutskærmen er åben")

	# 4. Escape-pause (som main.gd): skærmen følger med ud af træet og kommer igen
	remove_child(wp)
	bot.check(not Global.boards_locked, "Boardene er ikke låst, mens spillet er på pause")
	add_child(wp)
	bot.check(Global.boards_locked, "Boardene er låst igen, når spillet fortsætter")
	bot.check(wp.end_screen == screen and screen.is_inside_tree(), "Slutskærmen er der stadig efter pausen")
	await bot.wait_frames(2)

	# 5. "Start næste dag": næste dag starter, og spilleren ringer selv på klokken
	await bot.click(screen.next_day_button.get_global_rect().get_center())
	await bot.wait_frames(2)
	bot.check(not is_instance_valid(screen), "Slutskærmen er lukket og frigjort")
	bot.check(wp.end_screen == null, "Arbejdspladsen har ingen slutskærm længere")
	bot.check(not Global.boards_locked, "Boardene er låst op igen")
	bot.check(not wp.is_day_over, "Den nye dag er i gang")
	bot.check_equal(wp.sprint_size, 4, "Næste dag har 4 kunder")
	bot.check_near(wp.sprint_quota, snappedf(wp.get_sprint_quota(4), 0.01), 0.001, "Næste dag har kvoten for 4 kunder")
	bot.check_equal(wp.served_during_sprint, 0, "Næste dag starter med 0 betjente kunder")
	bot.check(wp.current_customer == null, "Ingen kunde kommer af sig selv")

	# Samme træk som før virker nu (så tjekket i 3. ikke bare var et træk, der aldrig ramte)
	if can_drag:
		var start_pos: Vector2 = note.global_position
		var grab: Vector2 = note.global_position + note.size / 2.0
		await bot.drag(grab, grab + Vector2(0, -200))
		bot.check(note.global_position.distance_to(start_pos) > 50, "Notepapiret kan trækkes igen")
	wp.customer_arrive()
	bot.check(wp.current_customer != null, "Klokken kalder en kunde igen")
	wp.queue_free()
	await bot.wait_frames(2)

	# 6. En tabt dag giver game over og ingen slutskærm
	Global.savings = 0.0
	wp = WORK_PLACE.instantiate()
	add_child(wp)
	await bot.wait_frames(2)
	wp.sprint_money = 0.0
	wp.finish_sprint()
	bot.check(Global.game_over, "Game over, når kvoten ikke nås")
	await bot.wait(GAME_OVER_WAIT)
	bot.check(wp.end_screen == null and not wp.get_children().any(func(c): return c is EndScreen),
		"Ingen slutskærm, når kvoten ikke nås")
	bot.check(not Global.boards_locked, "Boardene låses ikke af en slutskærm ved game over")
	wp.queue_free()
	await bot.wait_frames(2)

	# Ryd op
	Global.game_over = false
	Global.savings = 0.0
	AudioPlayer.music_player.volume_db = 0.0 # game over skruede musikken ned
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
