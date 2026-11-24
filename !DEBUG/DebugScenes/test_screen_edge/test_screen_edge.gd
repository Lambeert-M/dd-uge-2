extends Node2D

# Automatisk test: et board kan ikke trækkes ud over skærmkanten.
# Under et træk kan musen godt forlade vinduet, men boardet skal stoppe ved kanten.
# Kør scenen: den trækker en blanket ud over alle kanter, tjekker at den bliver
# på skærmen og lukker selv, når den er færdig.
# Sæt AUTO_QUIT til false, hvis vinduet skal blive åbent bagefter.

const AUTO_QUIT := true
const FAR := Vector2(2000, 2000)    # langt uden for skærmen

var bot: TestBot
var screen: Rect2

func _ready() -> void:
	bot = TestBot.new()
	add_child(bot)
	_run.call_deferred()

func _run() -> void:
	screen = get_viewport_rect()
	var form := A_Indkomst.new()
	form.position = Vector2(300, 200)
	add_child(form)
	await bot.wait_frames(3)

	# 1. Ud over venstre og øverste kant -> blanketten stopper i hjørnet
	var grab := _grab_point(form)
	await bot.drag(grab, grab - FAR)
	bot.check(_on_screen(form), "Blanketten blev på skærmen (trukket mod venstre/op)")
	bot.check_equal(form.global_position, screen.position, "Blanketten stoppede i øverste venstre hjørne")
	await bot.screenshot("screen_edge_01_venstre_top")

	# 2. Ud over højre og nederste kant -> blanketten stopper i det andet hjørne
	grab = _grab_point(form)
	await bot.drag(grab, grab + FAR)
	bot.check(_on_screen(form), "Blanketten blev på skærmen (trukket mod højre/ned)")
	bot.check_equal(form.get_global_rect().end, screen.end, "Blanketten stoppede i nederste højre hjørne")
	await bot.screenshot("screen_edge_02_hoejre_bund")

	# 3. Ud og tilbage i ét træk -> blanketten venter ved kanten, og grebet glider ikke
	var corner := form.global_position
	grab = _grab_point(form)
	await bot.press(grab)
	await bot.move_mouse(grab + FAR)
	bot.check(form.dragging, "Blanketten bliver trukket")
	bot.check_equal(form.global_position, corner, "Blanketten blev ved kanten, mens musen var uden for")
	var back := grab - Vector2(300, 200)
	await bot.move_mouse(back)
	bot.check_equal(form.global_position, corner - Vector2(300, 200), "Stedet, der blev grebet, er under musen igen")
	await bot.release(back)
	await bot.move_mouse(back + Vector2(1, 0))
	bot.check(not form.dragging, "Trækket sluttede")

	# 4. Et board uden for skærmen (fx efter at vinduet blev mindre) hentes ind
	var lost := A_Indkomst.new()
	lost.position = screen.end + Vector2(200, 200)
	add_child(lost)
	await bot.wait_frames(1)
	lost.keep_on_screen()
	bot.check(_on_screen(lost), "keep_on_screen() hentede et board uden for skærmen ind")

	# 5. Et board, der er større end skærmen, beholder sit øverste venstre hjørne på skærmen
	var huge := Board.new("res://Resources/UIAssets/Alien.png", 100.0)
	huge.position = Vector2(-300, -300)
	add_child(huge)
	await bot.wait_frames(1)
	bot.check(huge.size.x > screen.size.x and huge.size.y > screen.size.y, "Test-boardet er større end skærmen")
	huge.keep_on_screen()
	bot.check_equal(huge.global_position, screen.position, "Et for stort board lægges i øverste venstre hjørne")
	huge.queue_free()

	bot.finish(AUTO_QUIT)

# Grib blanketten i margenen øverst (som i test_input)
func _grab_point(board: Board) -> Vector2:
	return board.global_position + Vector2(board.size.x / 2, 8)

# Ligger hele boardet på skærmen? (lidt luft for afrundingsfejl)
func _on_screen(board: Board) -> bool:
	return screen.grow(0.01).encloses(board.get_global_rect())
