extends Node

# Automatisk test af at gemme og hente fremskridt (tabellen Progress) i work_place.gd.
# Kør scenen: den opretter en testbruger i Supabase (bruger 1 af de 30 oprettelser
# pr. IP pr. time), logger ind som den, klarer en sprint, genindlæser arbejdspladsen,
# fejler en sprint og sletter så testbrugeren igen (rækken i Progress slettes med).
# Lukker selv (exit code 1 hvis noget fejlede). Kræver forbindelse til databasen.

const AUTO_QUIT := true
const WORK_PLACE := preload("res://Scenes&Scripts/work_place/work_place.tscn")
const REQUEST_TIMEOUT := 10.0
const ANIMATION_TIMEOUT := 6.0

var bot: TestBot

func _ready() -> void:
	bot = TestBot.new()
	add_child(bot)
	_run.call_deferred()

func _run() -> void:
	# 1. Opret en testbruger og log ind som den
	var user_name := "testbot%d" % int(Time.get_unix_time_from_system())
	var task = await Supabase.database.query(SupabaseQuery.new().from("Users") \
		.insert([{"user_name": user_name, "user_login": "testbot"}])).completed
	if not bot.check(task.error == null and task.data is Array and task.data.size() == 1,
			"Testbrugeren blev oprettet (fejl: %s)" % [task.error]):
		bot.finish(AUTO_QUIT)
		return
	var user_id := int(task.data[0]["id"])
	Global.current_user = {"id": user_id, "user_name": user_name}
	Global.savings = 0.0

	# 2. Ny spiller: ingen række i Progress, så første sprint
	var wp = WORK_PLACE.instantiate()
	add_child(wp)
	bot.check(wp.is_loading_progress, "Fremskridtet hentes, når arbejdspladsen starter")
	wp.customer_arrive()
	bot.check(wp.current_customer == null, "Ingen kunde kan komme, mens fremskridtet hentes")
	bot.check(await _wait_until(func(): return not wp.is_loading_progress, REQUEST_TIMEOUT),
		"Fremskridtet blev hentet inden for %d s" % REQUEST_TIMEOUT)
	bot.check(wp.has_loaded_progress, "Hentningen lykkedes")
	bot.check_equal(wp.quotas_served, 0, "Ny spiller har 0 klarede sprints")
	bot.check_equal(wp.sprint_size, 3, "Ny spiller starter med 3 kunder")
	bot.check_near(wp.sprint_quota, 40.0, 0.001, "Ny spiller starter med en kvote på 40 kr")
	bot.check_near(Global.savings, 0.0, 0.001, "Ny spiller har 0 kr sparet op")
	bot.check_equal(await _progress_row(user_id), null, "Ny spiller har endnu ingen række i Progress")

	# 3. Klar sprinten med 46 kr: kvoten på 40 trækkes fra, 6 kr spares op
	wp.sprint_money = 46.0
	wp.finish_sprint()
	bot.check(wp.is_saving, "Fremskridtet gemmes, når sprinten er klaret")
	bot.check(await _wait_until(func(): return not wp.is_saving, REQUEST_TIMEOUT),
		"Gemningen blev færdig inden for %d s" % REQUEST_TIMEOUT)
	bot.check_near(Global.savings, 6.0, 0.001, "De 6 kr over kvoten lægges i opsparingen")
	bot.check_near(wp.sprint_money, 0.0, 0.001, "Sprintens penge starter forfra")
	bot.check_equal(wp.sprint_money_label.text, TaxForm._kr(0.0), "Den store pengelabel er nulstillet")
	var row = await _progress_row(user_id)
	bot.check(row is Dictionary, "Rækken i Progress blev oprettet (fik %s)" % [row])
	if row is Dictionary:
		bot.check_equal(int(row["sprints_completed"]), 1, "Databasen har 1 klaret sprint")
		bot.check_near(float(row["savings"]), 6.0, 0.001, "Databasen har 6 kr sparet op")
	bot.check(await _wait_until(func(): return wp.sprint_size == 4, ANIMATION_TIMEOUT),
		"Næste sprint starter efter animationen")
	var quota_4: float = snappedf(wp.get_sprint_quota(4), 0.01)
	bot.check_near(wp.sprint_quota, quota_4, 0.001, "Næste sprint har kvoten for 4 kunder")

	# 4. Genstart: arbejdspladsen henter 1 klaret sprint og 6 kr
	wp.queue_free()
	await bot.wait_frames(2)
	Global.savings = 0.0
	wp = WORK_PLACE.instantiate()
	add_child(wp)
	bot.check(await _wait_until(func(): return not wp.is_loading_progress, REQUEST_TIMEOUT),
		"Fremskridtet blev hentet igen inden for %d s" % REQUEST_TIMEOUT)
	bot.check_equal(wp.quotas_served, 1, "1 klaret sprint blev hentet")
	bot.check_equal(wp.sprint_size, 4, "Sprinten har 4 kunder efter genstart")
	bot.check_near(wp.sprint_quota, quota_4, 0.001, "Kvoten passer efter genstart")
	bot.check_near(Global.savings, 6.0, 0.001, "Opsparingen på 6 kr blev hentet")
	bot.check_equal(wp.served_during_sprint, 0, "Sprinten starter med 0 betjente kunder")

	# 5. Fejl sprinten: alt nulstilles, også i databasen
	wp.sprint_money = 0.0
	wp.finish_sprint()
	bot.check(Global.game_over, "Spillet er slut, når kvoten ikke nås")
	bot.check(await _wait_until(func(): return not wp.is_saving, REQUEST_TIMEOUT),
		"Nulstillingen blev gemt inden for %d s" % REQUEST_TIMEOUT)
	bot.check_equal(wp.quotas_served, 0, "Klarede sprints er nulstillet")
	bot.check_near(Global.savings, 0.0, 0.001, "Opsparingen er nulstillet")
	row = await _progress_row(user_id)
	bot.check(row is Dictionary, "Rækken i Progress findes stadig (fik %s)" % [row])
	if row is Dictionary:
		bot.check_equal(int(row["sprints_completed"]), 0, "Databasen har 0 klarede sprints")
		bot.check_near(float(row["savings"]), 0.0, 0.001, "Databasen har 0 kr sparet op")
	bot.check(await _wait_until(func(): return not wp.retry_button.disabled, ANIMATION_TIMEOUT),
		"Retry kan trykkes, når nulstillingen er gemt")
	await bot.screenshot("progress_01_game_over")
	wp.queue_free()
	await bot.wait_frames(2)

	# 6. Uden login hentes og gemmes intet
	Global.current_user = {}
	Global.game_over = false
	wp = WORK_PLACE.instantiate()
	add_child(wp)
	bot.check(not wp.is_loading_progress and not wp.has_loaded_progress, "En gæst henter ikke fremskridt")
	wp.sprint_money = 50.0
	wp.finish_sprint()
	bot.check(not wp.is_saving, "En gæsts sprint gemmes ikke")
	bot.check(await _wait_until(func(): return wp.sprint_size == 4, ANIMATION_TIMEOUT),
		"Gæstens næste sprint starter efter animationen")
	wp.queue_free()
	await bot.wait_frames(2)
	Global.savings = 0.0

	# Ryd op: slet testbrugeren. Rækken i Progress slettes med (on delete cascade).
	task = await Supabase.database.query(
		SupabaseQuery.new().from("Users").delete().eq("id", str(user_id))).completed
	bot.check(task.error == null and task.data is Array and task.data.size() == 1,
		"Testbrugeren blev slettet igen")
	bot.check_equal(await _progress_row(user_id), null, "Rækken i Progress blev slettet med brugeren")

	bot.finish(AUTO_QUIT)

# Brugerens række i Progress, null hvis den ikke findes, eller "fejl" hvis databasen fejlede
func _progress_row(user_id: int) -> Variant:
	var query := SupabaseQuery.new().from("Progress") \
		.select(PackedStringArray(["sprints_completed", "savings"])) \
		.eq("user_id", str(user_id))
	var task = await Supabase.database.query(query).completed
	if task.error != null or not task.data is Array:
		return "fejl: %s" % [task.error]
	return task.data[0] if not task.data.is_empty() else null

# Vent til condition() er sand, højst timeout sekunder
func _wait_until(condition: Callable, timeout: float) -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000)
	while not condition.call():
		if Time.get_ticks_msec() > end:
			return false
		await bot.wait_frames(1)
	return true
