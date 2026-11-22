extends Node

# Automatisk test af "Registrer bruger" i login-scenen med TestBot.
# Kør scenen: den opretter en testbruger i Supabase, prøver samme navn igen
# og en for kort adgangskode, tjekker at man kan logge ind med den nye bruger,
# og sletter så testbrugeren igen. Lukker selv (exit code 1 hvis noget fejlede).
# Kræver forbindelse til databasen.
#
# Knapperne trykkes via deres `pressed`-signal. "Log ind"-knappen bruges ikke,
# fordi den skifter scene (og dermed lukker testen) efter et vellykket login.

const AUTO_QUIT := true
const LOGIN := preload("res://Scenes&Scripts/InteractiveScenes/login.tscn")
const LOGIN_SCRIPT := preload("res://Scenes&Scripts/InteractiveScenes/login.gd")
# Tegn, der ville ødelægge en URL, hvis de ikke blev kodet
const PASSWORD := "a&b #1+%"
const REQUEST_TIMEOUT := 10.0

var bot: TestBot

func _ready() -> void:
	bot = TestBot.new()
	add_child(bot)
	_run.call_deferred()

func _run() -> void:
	Global.current_user = {}
	var login = LOGIN.instantiate()
	add_child(login)
	await bot.wait_frames(2)

	var user_name := "testbot%d" % int(Time.get_unix_time_from_system())
	login.username_field.text = user_name
	login.password_field.text = PASSWORD

	# 1. Opret brugeren: alle knapper slås fra, mens databasen arbejder
	login.register_button.pressed.emit()
	_check_buttons_disabled(login, true, "under oprettelse")
	bot.check(await _wait_until_idle(login), "Oprettelsen blev færdig inden for %d s" % REQUEST_TIMEOUT)
	_check_buttons_disabled(login, false, "efter oprettelse")
	bot.check_equal(login.status_label.text, LOGIN_SCRIPT.REGISTER_SUCCESS_TEXT, "Beskeden siger, at brugeren er oprettet")
	bot.check(Global.current_user.is_empty(), "Spilleren er IKKE logget ind efter oprettelse")
	await bot.screenshot("register_01_oprettet")

	# Beskeden forsvinder efter 1 sekund
	await bot.wait(1.2)
	bot.check_equal(login.status_label.text, "", "Beskeden er væk efter 1 sekund")

	# 2. Brugeren findes i databasen, og login-forespørgslen (samme kodning som
	#    login.gd) finder den, selvom adgangskoden har specialtegn
	var query := SupabaseQuery.new().from("Users") \
		.select(PackedStringArray(["id", "user_name"])) \
		.eq("user_name", user_name) \
		.eq("user_login", PASSWORD.uri_encode())
	var task = await Supabase.database.query(query).completed
	bot.check(task.error == null and task.data is Array and task.data.size() == 1,
		"Man kan logge ind med den nye bruger (fik %s)" % [task.data])

	# 3. Samme brugernavn igen -> afvist
	login.register_button.pressed.emit()
	_check_buttons_disabled(login, true, "under anden oprettelse")
	bot.check(await _wait_until_idle(login), "Anden oprettelse blev færdig inden for %d s" % REQUEST_TIMEOUT)
	bot.check("brugernavnet er taget" in login.status_label.text,
		"Et brugernavn, der findes, bliver afvist (fik '%s')" % login.status_label.text)
	await bot.screenshot("register_02_taget")

	# 4. For kort adgangskode -> afvist uden at spørge databasen
	login.username_field.text = user_name + "x"
	login.password_field.text = "abc"
	login.register_button.pressed.emit()
	_check_buttons_disabled(login, false, "ved for kort adgangskode")
	bot.check("mindst 4 tegn" in login.status_label.text,
		"En for kort adgangskode bliver afvist (fik '%s')" % login.status_label.text)

	# 5. Tomt brugernavn -> afvist
	login.username_field.text = ""
	login.password_field.text = PASSWORD
	login.register_button.pressed.emit()
	bot.check("udfyld brugernavn" in login.status_label.text.to_lower(),
		"Et tomt brugernavn bliver afvist (fik '%s')" % login.status_label.text)
	bot.check(Global.current_user.is_empty(), "Spilleren er stadig ikke logget ind")

	# Ryd op: slet testbrugeren igen
	var cleanup := SupabaseQuery.new().from("Users").delete().eq("user_name", user_name)
	task = await Supabase.database.query(cleanup).completed
	bot.check(task.error == null and task.data is Array and task.data.size() == 1,
		"Testbrugeren blev slettet igen")

	bot.finish(AUTO_QUIT)

# Vent til login-scenen ikke længere venter på databasen
func _wait_until_idle(login: Node) -> bool:
	var end := Time.get_ticks_msec() + int(REQUEST_TIMEOUT * 1000)
	while login.register_button.disabled:
		if Time.get_ticks_msec() > end:
			return false
		await bot.wait_frames(1)
	return true

func _check_buttons_disabled(login: Node, disabled: bool, when: String) -> void:
	var state := "slået fra" if disabled else "slået til"
	bot.check_equal(login.login_button.disabled, disabled, "Log ind er %s %s" % [state, when])
	bot.check_equal(login.register_button.disabled, disabled, "Registrer er %s %s" % [state, when])
	bot.check_equal(login.back_button.disabled, disabled, "Tilbage er %s %s" % [state, when])
