extends Control

# Viser de TOP_COUNT spillere med flest penge sparet op (Progress.savings).
# Alle kan se den, også uden at være logget ind.
# Tabellen (overskrift + én række pr. plads) bygges i kode af _build_table(),
# så kolonnerne altid passer sammen, og TOP_COUNT kan ændres uden at røre scenen.

const TITLE_SCENE := "res://Scenes&Scripts/InteractiveScenes/titlescreen.tscn"
const PROGRESS_TABLE := "Progress"
const TOP_COUNT := 10
# Står på de pladser, der ikke er nogen spiller til
const EMPTY_TEXT := "—"
const UNKNOWN_NAME := "?"
const LOADING_TEXT := "Henter leaderboard…"
const ERROR_COLOR := Color("ff5a5a")
const INFO_COLOR := Color.WHITE

# Plads 1, 2 og 3: guld, sølv og bronze (baggrund og en mørkere kant forneden)
const MEDAL_COLORS: Array[Color] = [Color("d4af37"), Color("c0c0c8"), Color("cd7f32")]
const MEDAL_BORDER_COLORS: Array[Color] = [Color(0.6, 0.47, 0.1), Color(0.5, 0.5, 0.55), Color(0.55, 0.32, 0.1)]
# Resten af pladserne: mørkegrå, så de ikke ligner sølv
const GREY_COLOR := Color(0.30, 0.32, 0.36)
const GREY_BORDER_COLOR := Color(0.2, 0.21, 0.24)
const TEXT_DARK := Color(0.1, 0.1, 0.1)
const TEXT_LIGHT := Color(0.92, 0.92, 0.95)
const HEADER_COLOR := Color(0.85, 0.85, 0.9)

# Kolonnebredder (overskrift og rækker bruger de samme)
const RANK_WIDTH := 80
const NAME_WIDTH := 320
const MONEY_WIDTH := 240
const COLUMN_SEPARATION := 16
const ROW_PADDING_X := 16

# Skriftstørrelser: plads 1 størst, 2-3 mellem, resten små, så 10 rækker kan være der
const HEADER_FONT_SIZE := 20
const FIRST_FONT_SIZE := 30
const MEDAL_FONT_SIZE := 24
const OTHER_FONT_SIZE := 18

var name_labels: Array[Label] = []
var money_labels: Array[Label] = []

@onready var rows_box: VBoxContainer = %Rows
@onready var status_label: Label = %StatusLabel
@onready var back_button: Button = %BackButton


func _ready() -> void:
	_build_table()
	back_button.pressed.connect(_go_to_title)
	_show_rows([])
	_show_status(LOADING_TEXT, INFO_COLOR)
	load_leaderboard()


func load_leaderboard() -> void:
	# Users(user_name) henter navnet i samme forespørgsel via fremmednøglen
	# Progress.user_id -> Users.id. Vælg aldrig user_login (adgangskoden).
	# Kun spillere med mere end 0 kr (game over nulstiller opsparingen).
	# Ved lige mange penge vinder det laveste user_id, så rækkefølgen er fast.
	# range() sætter Range-headeren, så kun top TOP_COUNT sendes tilbage.
	var query := SupabaseQuery.new().from(PROGRESS_TABLE) \
		.select(PackedStringArray(["savings", "Users(user_name)"])) \
		.gt("savings", "0") \
		.order("savings", SupabaseQuery.Directions.Descending, SupabaseQuery.Nullsorder.Last) \
		.order("user_id") \
		.range(0, TOP_COUNT - 1)
	# connect i stedet for await: trykker spilleren Tilbage, før svaret kommer,
	# forsvinder forbindelsen sammen med scenen (samme grund som i login.gd)
	Supabase.database.query(query).completed.connect(_on_leaderboard_loaded)


func _on_leaderboard_loaded(task) -> void:
	# Netværksfejl giver data == null uden en error, så tjek begge
	if task.error != null or not task.data is Array:
		_show_status("Kunne ikke hente leaderboardet", ERROR_COLOR)
		return
	_show_rows(task.data)
	if task.data.is_empty():
		_show_status("Ingen spillere har sparet penge op endnu", INFO_COLOR)
	else:
		_show_status("", INFO_COLOR)


# Skriv rækkerne ind i tabellen. Pladser uden en spiller får EMPTY_TEXT.
func _show_rows(rows: Array) -> void:
	for i in TOP_COUNT:
		if i < rows.size():
			name_labels[i].text = _user_name(rows[i])
			money_labels[i].text = TaxForm._kr(float(rows[i]["savings"]))
		else:
			name_labels[i].text = EMPTY_TEXT
			money_labels[i].text = EMPTY_TEXT


# Navnet fra den indlejrede Users-række ({"Users": {"user_name": ...}})
static func _user_name(row: Dictionary) -> String:
	var user = row.get("Users")
	if user is Dictionary and user.get("user_name") != null:
		return str(user["user_name"])
	return UNKNOWN_NAME


# --- Tabellen ---------------------------------------------------------------

# Overskrift, en streg og én række pr. plads. Fylder name_labels og money_labels.
func _build_table() -> void:
	var header := StyleBoxEmpty.new()
	header.content_margin_left = ROW_PADDING_X
	header.content_margin_right = ROW_PADDING_X
	_add_row(header, ["Rank", "Name", "Money"], HEADER_FONT_SIZE, HEADER_COLOR)
	rows_box.add_child(HSeparator.new())

	for i in TOP_COUNT:
		var is_medal := i < MEDAL_COLORS.size()
		var font_size := FIRST_FONT_SIZE if i == 0 else (MEDAL_FONT_SIZE if is_medal else OTHER_FONT_SIZE)
		var cells := _add_row(_row_style(i), ["#%d" % (i + 1), EMPTY_TEXT, EMPTY_TEXT],
			font_size, TEXT_DARK if is_medal else TEXT_LIGHT)
		name_labels.append(cells[1])
		money_labels.append(cells[2])


# Én række: et panel med en Rank-, Name- og Money-celle. Returnerer de tre labels.
func _add_row(style: StyleBox, texts: Array, font_size: int, color: Color) -> Array[Label]:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", style)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", COLUMN_SEPARATION)
	row.add_child(hbox)

	var rank := _make_cell(texts[0], RANK_WIDTH, font_size, color)
	var user := _make_cell(texts[1], NAME_WIDTH, font_size, color)
	user.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	user.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var money := _make_cell(texts[2], MONEY_WIDTH, font_size, color)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var cells: Array[Label] = [rank, user, money]
	for cell in cells:
		hbox.add_child(cell)
	rows_box.add_child(row)
	return cells


func _make_cell(text: String, width: int, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = width
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


# Guld, sølv og bronze til plads 1-3, grå til resten
func _row_style(i: int) -> StyleBoxFlat:
	var is_medal := i < MEDAL_COLORS.size()
	var style := StyleBoxFlat.new()
	style.bg_color = MEDAL_COLORS[i] if is_medal else GREY_COLOR
	style.border_color = MEDAL_BORDER_COLORS[i] if is_medal else GREY_BORDER_COLOR
	style.border_width_bottom = 4 if is_medal else 3
	style.set_corner_radius_all(10 if is_medal else 8)
	var padding_y := 5 if is_medal else 4
	style.content_margin_left = ROW_PADDING_X
	style.content_margin_right = ROW_PADDING_X
	style.content_margin_top = padding_y
	style.content_margin_bottom = padding_y
	return style


func _show_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)


func _go_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)
