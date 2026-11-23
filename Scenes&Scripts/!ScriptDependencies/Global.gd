extends Node
# Autoload

# Global constants
const PIXEL_SCALE := 6.0

# Global variables
var game_over := false

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
