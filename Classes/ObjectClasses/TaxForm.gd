@abstract class_name TaxForm
extends Board


# Abstrakt klasse: lav aldrig TaxForm.new() direkte.
# Hver rigtig blanket (fx A_Indkomst) arver herfra, laver sin egen _init()
# og kalder super("<sti til blankettens billede>", <skala>) og derefter _build_ui().
#
# En blanket skal selv implementere:
#   get_form_title()     -> titlen øverst på blanketten
#   get_correct_total()  -> det korrekte beløb
#   _add_fields(box)     -> blankettens egne linjer (labels)
# Resten (titel, svarfelt, validate, formatering) arves herfra.
# _progressive_tax() regner mellem-, top- og toptopskat ud for blanketterne.
	
# FONT_SIZE, TITLE_FONT_SIZE og _make_label() arves fra Board.
const AM_RATE := 0.08 # AM-bidrag er 8 % ved lov
const ANSWER_CHARS := "0123456789,." # De eneste tegn, spilleren kan skrive i svarfeltet

# Progressive skatter 2026: årlig grænse (efter AM-bidrag) og ekstra sats.
# Den ekstra sats gælder kun for den del af indkomsten, der ligger over grænsen.
# Det står i TaxForm, fordi den kan være relevant for flere forskellige typer skat.
const PROGRESSIVE_BRACKETS := [
	{"name": "Mellemskat", "limit": 641200.0,  "rate": 0.075},
	{"name": "Topskat",    "limit": 777900.0,  "rate": 0.075},
	{"name": "Toptopskat", "limit": 2592700.0, "rate": 0.05},
]

var answer_field: LineEdit

# Blankettens titel, fx "A-indkomst"
@abstract func get_form_title() -> String

# Det korrekte beløb, spilleren skulle have skrevet
@abstract func get_correct_total() -> float

# Tilføj blankettens egne linjer mellem titlen og svarfeltet
@abstract func _add_fields(box: VBoxContainer) -> void

# Forskel mellem korrekt skat og spillerens svar (Aka fejl).
# Kan overskrives, hvis en blanket har flere svarfelter.
func validate() -> float:
	return get_correct_total() - _parse_kr(answer_field.text)

# Byg blankettens skelet: titel, egne linjer og svarfelt
func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(16, 16)
	box.size = Vector2(size.x - 32, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	box.add_child(_make_label(get_form_title(), TITLE_FONT_SIZE))
	_add_fields(box)

	answer_field = LineEdit.new()
	answer_field.placeholder_text = "0000,00"
	answer_field.add_theme_font_size_override("font_size", FONT_SIZE)
	answer_field.text_changed.connect(_on_answer_changed)
	box.add_child(answer_field)

# Fjern alt andet end cifre, komma og punktum, mens spilleren skriver (også ved indsæt).
func _on_answer_changed(new_text: String) -> void:
	var clean := _only_amount_chars(new_text)
	if clean == new_text:
		return
	# Behold markørens plads: tæl de gyldige tegn til venstre for den
	var caret := _only_amount_chars(new_text.left(answer_field.caret_column)).length()
	answer_field.text = clean # udløser ikke text_changed igen
	answer_field.caret_column = caret

# Behold kun de tegn, der må stå i et beløb (se ANSWER_CHARS)
static func _only_amount_chars(text: String) -> String:
	var out := ""
	for c in text:
		if c in ANSWER_CHARS:
			out += c
	return out

# Ekstra skat oven i trækprocenten (mellem-, top- og toptopskat).
# grundlag = indkomst efter AM-bidrag, men FØR fradrag. Hovedkort-fradraget
# gælder kun trækprocenten, ikke mellem-, top- og toptopskat!
# periods = 12 for månedlige blanketter (grænserne deles med 12), 1 for årlige.
# Det her står ikke i A-SKAT alene, da den også bruges til B-SKAT.
static func _progressive_tax(grundlag: float, periods: int = 12) -> float:
	var total := 0.0
	for bracket in PROGRESSIVE_BRACKETS:
		var limit := roundf(float(bracket["limit"]) / periods)
		total += maxf(grundlag - limit, 0.0) * float(bracket["rate"])
	return total

# Formatér beløb på dansk, fx 30.000,00 kr
static func _kr(value: float) -> String:
	if not is_finite(value): # NaN/INF har intet decimalpunktum -> parts[1] findes ikke
		push_error("_kr fik et ugyldigt beløb: %s" % value)
		return "??? kr"
	var parts := ("%.2f" % absf(value)).split(".")
	var whole := parts[0]
	var out := ""
	while whole.length() > 3:
		out = "." + whole.right(3) + out
		whole = whole.left(whole.length() - 3)
	out = whole + out
	return ("-" if value < 0 else "") + out + "," + parts[1] + " kr"

# Læs et beløb som tal. Komma er altid decimaltegn (dansk: 30.000,50).
# Uden komma er punktum tusindtalsseparator, hvis der står præcis 3 cifre efter det
# (30.000) eller der er flere punktummer (1.234.567). Ellers er det et decimaltegn (30.5).
# Ugyldigt input giver 0.
static func _parse_kr(text: String) -> float:
	text = text.strip_edges().replace(" ", "")
	if text.contains(","):
		text = text.replace(".", "").replace(",", ".")
	elif text.count(".") > 1 or text.get_slice(".", 1).length() == 3:
		text = text.replace(".", "")
	return text.to_float() if text.is_valid_float() else 0.0
	
