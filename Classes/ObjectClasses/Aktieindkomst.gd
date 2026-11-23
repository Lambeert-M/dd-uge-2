class_name Aktieindkomst
extends TaxForm

const SPRITE_PATH := "res://Resources/Sprites/GameObjectSprites/TaxFormSprites/tax_paper_test.jpg"
const ICON_PATH := "res://Resources/Sprites/GameObjectSprites/TaxFormSprites/tax_paper_test.jpg"

# Liste med firmanavne (ét pr. linje under [COMPANIES])
const COMPANIES_PATH := "res://Resources/AssetData/stock_companies.txt"

const TRADE_COUNT := 3      # antal aktiehandler på blanketten
const LOSS_CHANCE := 0.25   # chance for, at en handel giver tab i stedet for gevinst

# Aktieskat 2026 (årlig). Den dobbelte grænse for ægtefæller bruges ikke.
const LOW_RATE := 0.27               # af nettogevinsten op til grænsen
const HIGH_RATE := 0.42              # af den del, der ligger over grænsen
const PROGRESSION_LIMIT := 79400.0

# Årets handler: {"company": String, "result": float}. Negativt resultat = tab.
var trades: Array[Dictionary] = []

# Summen af gevinster og summen af tab (begge positive tal).
# Tabet holdes for sig, fordi det trækkes fra gevinsten, før skatten beregnes.
var gevinst := 0.0
var tab := 0.0

func _init() -> void:
	super(SPRITE_PATH, 0.1, ICON_PATH, 0.025)
	_generate_trades()
	_build_ui()

func get_form_title() -> String:
	return "Aktieindkomst (årlig)"

# Læs firmanavnene fra txt-filen.
# Samme [SEKTION]-format som kundernes data, så vi genbruger CustomerData.
func _load_companies() -> Array:
	var file := FileAccess.open(COMPANIES_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open " + COMPANIES_PATH)
		return ["Ukendt firma"]
	var data := CustomerData.new(file.get_as_text().split("\n"))
	var companies := Array(data.read_section("[COMPANIES]"))
	return companies if not companies.is_empty() else ["Ukendt firma"]

# Lav årets handler: tilfældige (forskellige) firmaer og tilfældige resultater.
func _generate_trades() -> void:
	var companies := _load_companies()
	companies.shuffle()
	for i in TRADE_COUNT:
		var result := _random_result()
		trades.append({"company": companies[i % companies.size()], "result": result})
		if result < 0.0:
			tab += -result
		else:
			gevinst += result

# Tilfældigt resultat af én handel i hele hundreder. Oftest gevinst, nogle gange tab.
# Intervallerne gør, at nettogevinsten nogle gange kommer over grænsen på 79.400 kr,
# og en sjælden gang bliver negativ (så der ingen skat er).
func _random_result() -> float:
	if randf() < LOSS_CHANCE:
		return -randi_range(10, 600) * 100.0     # tab: 1.000 - 60.000 kr
	if randf() < 0.6:
		return randi_range(20, 400) * 100.0      # gevinst: 2.000 - 40.000 kr
	return randi_range(400, 1500) * 100.0        # gevinst: 40.000 - 150.000 kr

# Korrekt beløb at betale til SKAT.
# Tab trækkes fra gevinsten først. Af nettogevinsten betales 27 % op til grænsen
# og 42 % af resten. Er nettoresultatet 0 eller negativt, betales der ingen skat.
func get_correct_total() -> float:
	var netto := gevinst - tab
	if netto <= 0.0:
		return 0.0
	var lav := minf(netto, PROGRESSION_LIMIT) * LOW_RATE
	var hoej := maxf(netto - PROGRESSION_LIMIT, 0.0) * HIGH_RATE
	return snappedf(lav + hoej, 0.01)

func _add_fields(box: VBoxContainer) -> void:
	for trade in trades:
		var result: float = trade["result"]
		var kind := "Tab" if result < 0.0 else "Gevinst"
		box.add_child(_make_label("%s: %s %s" % [trade["company"], kind, _kr(result)]))
	box.add_child(_make_label("I alt at betale til SKAT:"))
