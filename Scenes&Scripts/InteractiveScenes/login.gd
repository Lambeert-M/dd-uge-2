extends Control

# De eneste tegn, der må stå i et brugernavn (ingen mellemrum eller specialtegn)
const USERNAME_CHARS := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const TITLE_SCENE := "res://Scenes&Scripts/InteractiveScenes/titlescreen.tscn"
const SUCCESS_COLOR := Color("4cd964")
const ERROR_COLOR := Color("ff5a5a")
const INFO_COLOR := Color.WHITE
const MIN_PASSWORD_LENGTH := 4
# Postgres' fejlkode, når user_name allerede findes (unique-constraint på Users)
const UNIQUE_VIOLATION := "23505"
# Fejlkoden fra databasens grænse på 30 nye brugere pr. IP pr. time (private.check_request)
const RATE_LIMITED := "rate_limit"
const REGISTER_SUCCESS_TEXT := "Bruger oprettet – du kan nu logge ind"

@onready var username_field: LineEdit = %UsernameField
@onready var password_field: LineEdit = %PasswordField
@onready var login_button: Button = %LoginButton
@onready var register_button: Button = %RegisterButton
@onready var back_button: Button = %BackButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	# Check if user is already logged in
	if Global.is_logged_in() == true:
		print("User is already logged in")
		login_button.set_disabled(true)
	username_field.text_changed.connect(_on_username_changed)
	password_field.text_submitted.connect(func(_text: String): _on_login_pressed())
	login_button.pressed.connect(_on_login_pressed)
	register_button.pressed.connect(_on_register_pressed)
	back_button.pressed.connect(_go_to_title)
	username_field.grab_focus()


# Fjern alt andet end bogstaver og tal, mens spilleren skriver (også ved indsæt).
# Samme fremgangsmåde som TaxForm._on_answer_changed().
# Undgå injections ift brugernavn
func _on_username_changed(new_text: String) -> void:
	var clean := _only_username_chars(new_text)
	if clean == new_text:
		return
	# Behold markørens plads: tæl de gyldige tegn til venstre for den
	var caret := _only_username_chars(new_text.left(username_field.caret_column)).length()
	username_field.text = clean # udløser ikke text_changed igen
	username_field.caret_column = caret


static func _only_username_chars(text: String) -> String:
	var out := ""
	for c in text:
		if c in USERNAME_CHARS:
			out += c
	return out


func _on_login_pressed() -> void:
	# Knappen er slået fra, mens vi venter på databasen (også når der trykkes Enter)
	if login_button.disabled:
		# Button does nothing
		return

	var username := username_field.text
	var password := password_field.text
	if username.is_empty() or password.is_empty():
		_show_status("Udfyld brugernavn og adgangskode", ERROR_COLOR)
		return

	_set_busy(true)
	_show_status("Logger ind…", INFO_COLOR)

	# Vælg kun id og brugernavn, så adgangskoden aldrig sendes tilbage.
	# Addon'et sætter værdierne direkte ind i URL'en, så adgangskoden skal kodes
	# (ellers ødelægger tegn som & # + % og mellemrum forespørgslen).
	var query := SupabaseQuery.new().from("Users") \
		.select(PackedStringArray(["id", "user_name"])) \
		.eq("user_name", username) \
		.eq("user_login", password.uri_encode())
	var task = await Supabase.database.query(query).completed

	# Netværksfejl giver data == null uden en error, så tjek begge
	if task.error != null or not task.data is Array:
		_show_status("Kunne ikke forbinde til databasen", ERROR_COLOR)
		_set_busy(false)
		return

	if task.data.is_empty():
		_show_status("Forkert brugernavn eller adgangskode", ERROR_COLOR)
		_set_busy(false)
		return

	Global.current_user = task.data[0]
	_show_status("Login lykkedes", SUCCESS_COLOR)
	# Knapperne forbliver slået fra, indtil vi skifter scene
	await get_tree().create_timer(1.0).timeout
	_go_to_title()


# Opretter en ny bruger, men logger IKKE ind på den.
func _on_register_pressed() -> void:
	# Knappen er slået fra, mens vi venter på databasen
	if register_button.disabled:
		return

	var username := username_field.text
	var password := password_field.text
	if username.is_empty() or password.is_empty():
		_show_status("Udfyld brugernavn og adgangskode", ERROR_COLOR)
		return
	if password.length() < MIN_PASSWORD_LENGTH:
		_show_status("Adgangskoden skal være mindst %d tegn" % MIN_PASSWORD_LENGTH, ERROR_COLOR)
		return

	_set_busy(true)
	_show_status("Opretter bruger…", INFO_COLOR)

	# insert sender rækken som JSON i body (ikke i URL'en), så adgangskoden
	# skal IKKE uri_encode's her. Den gemmes præcis som spilleren skrev den.
	var query := SupabaseQuery.new().from("Users") \
		.insert([{"user_name": username, "user_login": password}])
	var task = await Supabase.database.query(query).completed
	_set_busy(false)

	if task.error != null and task.error.code == UNIQUE_VIOLATION:
		_show_status("Kunne ikke oprette bruger: brugernavnet er taget", ERROR_COLOR)
	elif task.error != null and task.error.code == RATE_LIMITED:
		_show_status("Kunne ikke oprette bruger: for mange nye brugere fra dit netværk – prøv igen senere", ERROR_COLOR)
	elif task.error != null:
		_show_status("Kunne ikke oprette bruger: databasen afviste brugeren", ERROR_COLOR)
	elif not task.data is Array:
		# Netværksfejl giver data == null uden en error
		_show_status("Kunne ikke oprette bruger: ingen forbindelse til databasen", ERROR_COLOR)
	else:
		_show_status(REGISTER_SUCCESS_TEXT, SUCCESS_COLOR)
		# Signal i stedet for await: forbindelsen fjernes automatisk, hvis
		# scenen lukkes (Tilbage) inden for sekundet
		get_tree().create_timer(1.0).timeout.connect(_clear_register_success)


# Fjern beskeden efter 1 sekund, men kun hvis der ikke er kommet en nyere besked
func _clear_register_success() -> void:
	if status_label.text == REGISTER_SUCCESS_TEXT:
		_show_status("", INFO_COLOR)


func _set_busy(busy: bool) -> void:
	# En bruger, der allerede er logget ind, kan ikke logge ind igen
	login_button.disabled = busy or Global.is_logged_in()
	register_button.disabled = busy
	back_button.disabled = busy


func _show_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)


func _go_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)
