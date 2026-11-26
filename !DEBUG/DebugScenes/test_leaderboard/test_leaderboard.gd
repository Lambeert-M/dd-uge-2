extends Node

# Automatisk test af leaderboardet (leaderboard.tscn) og dets knap på titelskærmen.
# Læser kun fra databasen: ingen brugere oprettes (bruger ingen af de 30 oprettelser
# pr. time), og intet gemmes. Toplisten på skærmen sammenlignes med en udregning ud fra
# hele Progress- og Users-tabellen.
# Lukker selv (exit code 1 hvis noget fejlede). Kræver forbindelse til databasen.

const AUTO_QUIT := true
const LEADERBOARD := preload("res://Scenes&Scripts/InteractiveScenes/leaderboard.tscn")
const LB := preload("res://Scenes&Scripts/InteractiveScenes/leaderboard.gd")
const TITLE := preload("res://Scenes&Scripts/InteractiveScenes/titlescreen.tscn")
const REQUEST_TIMEOUT := 10.0

var bot: TestBot

func _ready() -> void:
	bot = TestBot.new()
	add_child(bot)
	_run.call_deferred()

func _run() -> void:
	# 1. Mens der hentes, er alle pladser tomme
	var lb = LEADERBOARD.instantiate()
	add_child(lb)
	bot.check_equal(lb.name_labels.size(), LB.TOP_COUNT, "Der er bygget %d navne-celler" % LB.TOP_COUNT)
	bot.check_equal(lb.money_labels.size(), LB.TOP_COUNT, "Der er bygget %d penge-celler" % LB.TOP_COUNT)
	bot.check_equal(lb.status_label.text, LB.LOADING_TEXT, "Leaderboardet viser, at det henter")
	for i in LB.TOP_COUNT:
		bot.check_equal(lb.name_labels[i].text, LB.EMPTY_TEXT, "Plads %d er tom, mens der hentes" % (i + 1))
	bot.check(await _wait_until(func(): return lb.status_label.text != LB.LOADING_TEXT, REQUEST_TIMEOUT),
		"Leaderboardet blev hentet inden for %d s" % REQUEST_TIMEOUT)
	bot.check(lb.status_label.text != "Kunne ikke hente leaderboardet",
		"Hentningen lykkedes (status: '%s')" % lb.status_label.text)

	# 2. Sammenlign med toplisten udregnet ud fra hele tabellerne
	var expected = await _expected_top()
	if not bot.check(expected is Array, "Progress og Users kunne hentes til sammenligning"):
		bot.finish(AUTO_QUIT)
		return
	print("[test_leaderboard] Forventet topliste: ", expected)
	for i in LB.TOP_COUNT:
		var exp_name: String = LB.EMPTY_TEXT
		var exp_money: String = LB.EMPTY_TEXT
		if i < expected.size():
			exp_name = expected[i]["user_name"]
			exp_money = TaxForm._kr(expected[i]["savings"])
		bot.check_equal(lb.name_labels[i].text, exp_name, "Navnet på plads %d" % (i + 1))
		bot.check_equal(lb.money_labels[i].text, exp_money, "Pengene på plads %d" % (i + 1))
	if expected.is_empty():
		bot.check_equal(lb.status_label.text, "Ingen spillere har sparet penge op endnu",
			"Uden spillere står der, at ingen har sparet op")
	else:
		bot.check_equal(lb.status_label.text, "", "Statusteksten er tom, når der er spillere")
	await bot.screenshot("leaderboard_01")

	# 2a. Farver: guld, sølv og bronze på plads 1-3, grå på resten
	for i in LB.TOP_COUNT:
		var row: PanelContainer = lb.name_labels[i].get_parent().get_parent()
		var style := row.get_theme_stylebox("panel") as StyleBoxFlat
		var expected_color: Color = LB.MEDAL_COLORS[i] if i < LB.MEDAL_COLORS.size() else LB.GREY_COLOR
		bot.check(style != null and style.bg_color == expected_color,
			"Plads %d har farven %s" % [i + 1, expected_color.to_html(false)])

	# 2b. Alt kan være på skærmen, og Tilbage-knappen dækker ikke tabellen
	var view: Rect2 = lb.get_viewport_rect()
	var content: Rect2 = lb.get_node("CenterContainer/VBoxContainer").get_global_rect()
	var table: Rect2 = lb.get_node("CenterContainer/VBoxContainer/TablePanel").get_global_rect()
	var back: Rect2 = lb.back_button.get_global_rect()
	bot.check(view.encloses(content), "Titel, tabel og status er inden for skærmen (%s i %s)" % [content, view])
	bot.check(view.encloses(back), "Tilbage-knappen er inden for skærmen (%s)" % back)
	bot.check(not back.intersects(table), "Tilbage-knappen dækker ikke tabellen")

	# 2c. Alle pladser fyldt ud, med et langt navn og store beløb (kun til screenshot)
	var full := []
	for n in LB.TOP_COUNT:
		full.append({"savings": 1234567.89 - n * 98765.4, "Users": {"user_name": "Spiller%d" % (n + 1)}})
	full[1]["Users"]["user_name"] = "EtMegetLangtBrugernavnDerIkkeKanVaereDer1234567890"
	lb._show_rows(full)
	await bot.screenshot("leaderboard_02_full")

	# 2d. range() (Range-headeren) begrænser svaret. Uden gt-filteret er der flere rækker
	# end spillere med penge, så grænsen bliver prøvet, selvom toplisten ikke er fyldt ud.
	var all_rows = await Supabase.database.query(SupabaseQuery.new().from("Progress") \
		.select(PackedStringArray(["user_id"]))).completed
	var one_row = await Supabase.database.query(SupabaseQuery.new().from("Progress") \
		.select(PackedStringArray(["user_id"])).order("user_id").range(0, 0)).completed
	if bot.check(all_rows.data is Array and one_row.data is Array, "Progress kunne hentes med og uden range()"):
		bot.check_equal(one_row.data.size(), mini(1, all_rows.data.size()),
			"range(0, 0) giver højst 1 række (tabellen har %d)" % all_rows.data.size())

	# 3. _show_rows() med opdigtede rækker (intet fra databasen)
	lb._show_rows([{"savings": 1234.5, "Users": {"user_name": "Alice"}}])
	bot.check_equal(lb.name_labels[0].text, "Alice", "1 række: navnet står på plads 1")
	bot.check_equal(lb.money_labels[0].text, "1.234,50 kr", "1 række: beløbet er dansk formateret")
	bot.check_equal(lb.name_labels[1].text, LB.EMPTY_TEXT, "1 række: plads 2 er tom")
	bot.check_equal(lb.money_labels[2].text, LB.EMPTY_TEXT, "1 række: plads 3 er tom")

	lb._show_rows([{"savings": "99.9", "Users": null}])
	bot.check_equal(lb.name_labels[0].text, LB.UNKNOWN_NAME, "En række uden bruger viser '?'")
	bot.check_equal(lb.money_labels[0].text, "99,90 kr", "Et beløb som tekst bliver også formateret")

	var too_many := []
	for n in LB.TOP_COUNT + 1:
		too_many.append({"savings": 100 - n, "Users": {"user_name": "P%d" % n}})
	lb._show_rows(too_many)
	bot.check_equal(lb.name_labels[LB.TOP_COUNT - 1].text, "P%d" % (LB.TOP_COUNT - 1),
		"Med %d rækker vises kun de %d første" % [LB.TOP_COUNT + 1, LB.TOP_COUNT])

	lb._show_rows([])
	for i in LB.TOP_COUNT:
		bot.check_equal(lb.name_labels[i].text, LB.EMPTY_TEXT, "Ingen rækker: plads %d er tom" % (i + 1))
	lb.queue_free()
	await bot.wait_frames(2)

	# 4. Scenen lukkes, før svaret kommer (som når man trykker Tilbage med det samme).
	# Forbindelsen til _on_leaderboard_loaded forsvinder med scenen, så svaret må ikke
	# give fejl. Vent, til databasens HTTPRequest er færdig og fjernet.
	var pending_before: int = Supabase.database.get_child_count()
	lb = LEADERBOARD.instantiate()
	add_child(lb)
	bot.check_equal(Supabase.database.get_child_count(), pending_before + 1, "Forespørgslen er sendt")
	lb.free()
	bot.check(await _wait_until(func(): return Supabase.database.get_child_count() == pending_before, REQUEST_TIMEOUT),
		"Svaret kom, efter scenen var lukket (ingen fejl må stå i loggen her)")
	await bot.wait_frames(2)

	# 5. Titelskærmen har en Leaderboard-knap, der åbner scenen. Den trykkes ikke her,
	# for scene-skiftet ville lukke testen.
	var title = TITLE.instantiate()
	add_child(title)
	await bot.wait_frames(2)
	bot.check_equal(title.leaderboard_button.text, "Leaderboard", "Titelskærmen har en Leaderboard-knap")
	bot.check(title.leaderboard_button.pressed.is_connected(title._on_leaderboard_pressed),
		"Leaderboard-knappen er forbundet")
	bot.check(ResourceLoader.exists(title.LEADERBOARD_SCENE), "Knappen peger på en scene, der findes")
	await bot.screenshot("leaderboard_03_titlescreen")
	title.queue_free()
	await bot.wait_frames(2)

	bot.finish(AUTO_QUIT)

# Toplisten udregnet her i testen: spillere med savings > 0, flest penge først,
# ved lige mange penge det laveste user_id. null hvis databasen fejlede.
func _expected_top() -> Variant:
	var progress = await Supabase.database.query(SupabaseQuery.new().from("Progress") \
		.select(PackedStringArray(["user_id", "savings"]))).completed
	if progress.error != null or not progress.data is Array:
		return null
	var users = await Supabase.database.query(SupabaseQuery.new().from("Users") \
		.select(PackedStringArray(["id", "user_name"]))).completed
	if users.error != null or not users.data is Array:
		return null

	var names := {}
	for u in users.data:
		names[int(u["id"])] = str(u["user_name"])
	var rows := []
	for p in progress.data:
		var savings := float(p["savings"])
		if savings > 0.0:
			var id := int(p["user_id"])
			rows.append({"user_id": id, "savings": savings, "user_name": names.get(id, LB.UNKNOWN_NAME)})
	rows.sort_custom(func(a, b):
		if a["savings"] != b["savings"]:
			return a["savings"] > b["savings"]
		return a["user_id"] < b["user_id"])
	return rows.slice(0, LB.TOP_COUNT)

# Vent til condition() er sand, højst timeout sekunder
func _wait_until(condition: Callable, timeout: float) -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000)
	while not condition.call():
		if Time.get_ticks_msec() > end:
			return false
		await bot.wait_frames(1)
	return true
