class_name NotePaper
extends Board

# Et stykke notepapir, hvor spilleren kan skrive sine resultater og mellemregninger.
# Hele papiret er ét stort tekstfelt (TextEdit), hvor man kan skrive hvad som helst.
# På skrivebordet er papiret et ikon (en clipboard). Trækkes det væk fra skrivebordet,
# bliver det til papiret, man kan skrive på (det klarer Board selv).
# Teksten bliver liggende, når papiret er et ikon, men den gemmes ikke, når spillet lukkes.
#
# Brug:
#   desk.place_board(NotePaper.new(), Vector2(100, 30))

const SPRITE_PATH := "res://Resources/Sprites/GameObjectSprites/rulebook_page_placeholder.png"
# 600x400 -> 360x240: plads til ca. 13 linjer, men mindre end en side i regelbogen
const SPRITE_SCALE := 0.6

const ICON_PATH := "res://Resources/Sprites/GameObjectSprites/noteBoard.png"
# 1000x1392 -> 70x97: samme størrelse som blanketternes ikoner
const ICON_SCALE := 0.07

const MARGIN := 12.0 # afstand fra papirets kant til teksten

var text_edit: TextEdit

func _init() -> void:
	super(SPRITE_PATH, SPRITE_SCALE, ICON_PATH, ICON_SCALE)
	_build_ui()

func _ready() -> void:
	super()
	# Board._ready() skjuler barn nr. 2, når der er præcis 3 børn (ment til blanketternes VBox).
	# Her er barn nr. 2 tekstfeltet, så vis det igen (medmindre papiret allerede er et ikon).
	text_edit.visible = not is_icon

# Tekstfeltet dækker hele papiret (minus en lille margen)
func _build_ui() -> void:
	text_edit = TextEdit.new()
	text_edit.position = Vector2(MARGIN, MARGIN)
	text_edit.size = size - Vector2(MARGIN, MARGIN) * 2
	text_edit.placeholder_text = "Skriv dine noter og mellemregninger her..."
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY # lange linjer brydes i stedet for at rulle sidelæns
	text_edit.add_theme_font_size_override("font_size", FONT_SIZE)

	# Gennemsigtig baggrund og sort tekst, så det ligner at man skriver direkte på papiret
	for style in ["normal", "focus", "read_only"]:
		text_edit.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	text_edit.add_theme_color_override("font_color", Color.BLACK)
	text_edit.add_theme_color_override("caret_color", Color.BLACK)
	text_edit.add_theme_color_override("font_placeholder_color", Color(0, 0, 0, 0.4))
	text_edit.add_theme_color_override("selection_color", Color(0.3, 0.5, 1.0, 0.35))

	text_edit.gui_input.connect(_on_text_gui_input)
	add_child(text_edit)

# Ligger et andet board oven på notepapiret, må et klik der ikke ende i tekstfeltet.
# Blanketternes tekst ignorerer musen, så klikket ville ellers falde igennem til os.
# Signalet gui_input kommer før TextEdit selv håndterer klikket, så accept_event() stopper det.
func _on_text_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var point := text_edit.get_global_transform() * (event as InputEventMouseButton).position
	if not _is_topmost_at(point):
		text_edit.accept_event()
