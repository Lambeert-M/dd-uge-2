class_name EndScreen
extends CanvasLayer

# Skærmen, der vises, når en dag (sprint) er klaret: en sort boks midt på skærmen med
# dagens penge, kvoten og det, spilleren beholder, og en "Start næste dag"-knap.
# Vises kun, når kvoten er nået (work_place.gd). Bygges i kode:
#   var screen := EndScreen.new(tjent, kvote, beholdt)
#   add_child(screen)
#   await screen.closed
# Spillet bag ved er dæmpet og står stille, mens skærmen er åben: et gennemsigtigt lag tager
# alle klik (også klokken), og Global.boards_locked får boardene til at ignorere musen.

# Udsendes, når "Start næste dag" trykkes. Skærmen frigør sig selv bagefter.
signal closed

const LAYER := 10 # over spillet og dialog-autoloads'ene
const VICTORY_SOUND := "res://Resources/Audio/SoundEffects/AnimationSoundEffects/victory.mp3"

const DIM_COLOR := Color(0, 0, 0, 0.5)
const BOX_COLOR := Color.BLACK
const BORDER_COLOR := Color(0.35, 0.35, 0.38)
const TEXT_COLOR := Color.WHITE
const KEPT_COLOR := Color("40d85a") # samme grønne som "+x kr" i work_place.gd

const TITLE_FONT_SIZE := 48
const ROW_FONT_SIZE := 28
const BUTTON_FONT_SIZE := 28
const BOX_PADDING := 32
const ROW_SEPARATION := 40 # mellem tekst og beløb

const POP_TIME := 0.35
const POP_START_SCALE := Vector2(0.6, 0.6)

var root: Control
var box: PanelContainer
var earned_label: Label
var quota_label: Label
var kept_label: Label
var next_day_button: Button


func _init(earned: float, quota: float, kept: float) -> void:
	layer = LAYER

	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Dæmper spillet og tager alle klik, så intet bag ved boksen kan trykkes
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	box = PanelContainer.new()
	box.add_theme_stylebox_override("panel", _box_style())
	# Boksen skal vokse ud fra midten, så pivot følger størrelsen
	box.resized.connect(func(): box.pivot_offset = box.size / 2.0)
	center.add_child(box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	box.add_child(vbox)

	var title := _make_label("Dagen er slut!", TITLE_FONT_SIZE, TEXT_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# To kolonner: tekst til venstre, beløb til højre, så beløbene står under hinanden
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", ROW_SEPARATION)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)
	earned_label = _add_row(grid, "Tjent i dag", earned, TEXT_COLOR)
	quota_label = _add_row(grid, "Dagens kvote", quota, TEXT_COLOR)
	kept_label = _add_row(grid, "Du beholder", kept, KEPT_COLOR)

	next_day_button = Button.new()
	next_day_button.text = "Start næste dag"
	next_day_button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	next_day_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next_day_button.pressed.connect(_on_next_day_pressed)
	vbox.add_child(next_day_button)


func _ready() -> void:
	# Kun i _ready, så lyden ikke spiller igen, når et spil på pause fortsættes (Escape → PLAY)
	AudioPlayer.play_sound_effect(VICTORY_SOUND)
	# Enter/mellemrum trykker også knappen, og notepapiret mister fokus
	next_day_button.grab_focus()

	# Bundet til skærmen (ikke get_tree().create_tween()), så den står stille under pause
	root.modulate.a = 0.0
	box.scale = POP_START_SCALE
	var tween := create_tween().set_parallel()
	tween.tween_property(root, "modulate:a", 1.0, POP_TIME * 0.6)
	tween.tween_property(box, "scale", Vector2.ONE, POP_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Skærmen er et barn af arbejdspladsen, så Escape-pausen tager den med ud af træet.
# Så er boardene ikke låst på titelskærmen, og de låses igen, når PLAY fortsætter spillet.
func _enter_tree() -> void:
	Global.boards_locked = true


func _exit_tree() -> void:
	Global.boards_locked = false


func _on_next_day_pressed() -> void:
	next_day_button.disabled = true # ingen dobbelt-tryk
	closed.emit()
	queue_free()


func _add_row(grid: GridContainer, text: String, amount: float, amount_color: Color) -> Label:
	grid.add_child(_make_label(text, ROW_FONT_SIZE, TEXT_COLOR))
	var amount_label := _make_label(TaxForm._kr(amount), ROW_FONT_SIZE, amount_color)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(amount_label)
	return amount_label


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _box_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BOX_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(BOX_PADDING)
	return style
