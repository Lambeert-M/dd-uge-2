extends Node2D

# Default pay, that can be deviated from
const MAXPAYMENT = 20
const CALCULATOR_SCENE := preload("res://Addons/Calculator/Resources/scenes/calculator.tscn")

@onready var desk := $Desk
@onready var money_label := $MoneyLabel

var current_customer: Customer
var is_serving := false
var money := 0.00
var payment_guess: float
var paper_types := Weighted_Array.new()
var current_paper: Board


func _ready() -> void:
	# Decide paper_types and probability distrubution of them
	paper_types.add(A_Indkomst, 1.0)
	spawn_calculator()
	money_label.text = TaxForm._kr(money)

func customer_arrive() -> void:
	if current_customer:
		return
	is_serving = true
	current_customer = Customer.new(Customer.get_random_customer_name())
	add_child(current_customer)
	# Loads current_customer just in front of backgroun at index 0
	move_child(current_customer, 1)
	
	############################################################################
	# Insert animation
	current_customer.position = Vector2i(get_viewport_rect().size/2)
	############################################################################
	# On anim.finished():
	current_customer.finished_speaking.connect(_on_customer_finished_speaking)
	current_customer.board_received.connect(_on_customer_board_received)
	current_customer.want_to_speak()
	return

func customer_leave() -> void:
	if not current_customer:
		return
	is_serving = false
	############################################################################
	# Insert animation
	############################################################################
	remove_customer()
	pass

func remove_customer() -> void:
	if current_customer == null:
		return
	current_customer.queue_free()
	current_customer = null
	is_serving = false

func _on_customer_finished_speaking() -> void:
	current_paper = paper_types.pick_weighted_random().new()
	desk.place_board(current_paper)

func _on_customer_board_received(_board: Board = null) -> void:
	print("Paper given")
	payment_guess = TaxForm._parse_kr(current_paper.answer_field.text)
	get_payout()
	customer_leave()

func get_payout() -> void:
	if not current_paper: return
	var actual_payment = current_paper.get_correct_total()
	var d_payment = abs(actual_payment - payment_guess)
	
	# This distributes the pay according to d_payment via. a Gauss curve
	# If d_payment == 0, it returns MAXPAY * 1
	# If d_payment == actual_payment * 0.1, it returns 0
	# If d_payment >= actual_payment * 0.1, it asymptotically returns MAXPAY * (-1)
	var payout = (2 * pow(1.0/2, pow(d_payment/(actual_payment * 0.1), 2)) - 1) * MAXPAYMENT
	if d_payment == 0: payout *= 1.25
	money += payout
	
	AudioPlayer.play_sound_effect("res://Resources/Audio/SoundEffects/AnimationSoundEffects/money.mp3")
	money_label.text = TaxForm._kr(money)

func spawn_calculator() -> void:
	var calc = CALCULATOR_SCENE.instantiate() as Board
	desk.place_board(calc)

# Test function
func _input(event: InputEvent) -> void:
	if not current_paper: return
	if event.is_action_pressed("Test"):
		get_viewport().set_input_as_handled() # Skriv ikke "å" i svarfeltet
		print("%s: korrekt %s, svar \"%s\", forskel %s" % [
			current_paper.get_form_title(),
			TaxForm._kr(current_paper.get_correct_total()),
			current_paper.answer_field.text,
			TaxForm._kr(current_paper.validate()),
		])
