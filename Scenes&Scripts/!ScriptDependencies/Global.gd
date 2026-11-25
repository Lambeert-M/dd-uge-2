extends Node
# Autoload

# Global constants
const PIXEL_SCALE := 6.0

# Global variables
var game_over := false
# Sand, mens en EndScreen er åben (sættes af EndScreen selv). Boards ignorerer musen imens.
var boards_locked := false

# Den bruger, der er logget ind: {"id": int, "user_name": String}. Tom = ikke logget ind.
# Adgangskoden gemmes aldrig her. Log ud med: Global.current_user = {}
var current_user: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func is_logged_in() -> bool:
	return not current_user.is_empty()

# De penge, spilleren har sparet op: det, der var tilbage efter kvoten i hver klaret sprint.
# For en bruger, der er logget ind, gemmes de i databasen (tabellen Progress, se work_place.gd).
var savings := 0.00

# --- Spil på pause (Escape → titelskærmen, PLAY → fortsæt) ---
# Main-scenen ligger uden for scenetræet, mens titelskærmen vises, og sættes ind igen af PLAY.
# Spillet kan kun fortsættes af den spiller, der satte det på pause. Logger en gæst ind
# imens, smides gæstespillet væk, og et nyt spil henter brugerens fremskridt fra databasen.

const GUEST_ID := -1 # ejeren af et spil, når ingen er logget ind

var paused_game: Node = null
var paused_game_owner := GUEST_ID


# Brugerens id, eller GUEST_ID for en gæst. id kommer fra JSON som float, derfor int().
func player_id() -> int:
	return int(current_user["id"]) if is_logged_in() else GUEST_ID


func park_game(game: Node) -> void:
	discard_paused_game()
	paused_game = game
	paused_game_owner = player_id()


func can_resume_game() -> bool:
	return is_instance_valid(paused_game) and paused_game_owner == player_id()


# Giver spillet tilbage og glemmer det (det skal sættes ind i træet igen)
func take_paused_game() -> Node:
	var game := paused_game
	paused_game = null
	return game


func discard_paused_game() -> void:
	if is_instance_valid(paused_game):
		paused_game.free() # ligger uden for træet, så free() er sikkert
	paused_game = null


# Lukkes spillet på titelskærmen, skal spillet på pause også frigøres (ellers "leaked at exit")
func _exit_tree() -> void:
	discard_paused_game()
