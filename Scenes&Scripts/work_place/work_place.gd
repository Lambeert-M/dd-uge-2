extends Node2D

# Default pay, that can be deviated from
const MAXPAYMENT = 20
const EXACT_TOLERANCE := 0.005 # under en halv øre fra det rigtige svar tæller som præcis
const CALCULATOR_SCENE := preload("res://Addons/Calculator/Resources/scenes/calculator.tscn")
const RULEBOOK := preload("res://Scenes&Scripts/InteractiveScenes/rulebook.tscn")
const WELCOME_LETTER := "res://Resources/Letters/welcome_letter.txt"
const FIRST_SPRINT_QUOTA := 40.00
const RAMP := 1.0

@onready var desk := $Desk
@onready var quota_label := $PopupLabel
@onready var sprint_label := $SprintLabel
@onready var sprint_money_label := $SprintMoneyLabel
@onready var money_popup_label := $MoneyPopupLabel

@onready var game_over_screen := $GameOverScreen
@onready var game_over_label := $GameOverScreen/GameOverLabel
@onready var game_over_sub_label := $GameOverScreen/GameOverLabel/GameOverSubLabel
@onready var red_tint := $GameOverScreen/RedTint
@onready var retry_button := $GameOverScreen/RetryButton

# For layout setup:
@onready var left_wall := $Frame/LeftWall
@onready var right_wall := $Frame/RightWall
@onready var bg := $BackGroundSprite

var current_customer: Customer
var is_serving := false
var payment_guess: float
var paper_types := Weighted_Array.new()
var current_paper: Board

var sprint_quota := FIRST_SPRINT_QUOTA
var quotas_served := 0
var served_during_sprint := 0
var sprint_size := 3
var first_sprint_size := 3
var sprint_money := 0.00


func _ready() -> void:
	setup_paper_types()
	setup_layout()
	setup_desk()
	
	Global.game_over = false

func setup_paper_types() -> void:
	paper_types.add(A_Indkomst, 2.0)
	paper_types.add(Aktieindkomst, 1.0)
	paper_types.add(Ejendomsværdiskat, 1.0)
	spawn_calculator()

func setup_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var wall_size := Vector2(viewport_size.x * 3 / 10.0, viewport_size.y)

	for wall in [left_wall, right_wall]:
		wall.centered = false
		set_sprite_size(wall, wall_size)

	left_wall.position = Vector2.ZERO
	right_wall.position = Vector2(viewport_size.x - wall_size.x, 0)
	
	set_sprite_size(bg, get_viewport_rect().size)
	bg.position = Vector2.ZERO
	
	var desk_top := viewport_size.y * 0.72
	desk.set_rect(
		Vector2(wall_size.x, desk_top),
		Vector2(viewport_size.x - 2.0 * wall_size.x, viewport_size.y - desk_top))

	sprint_money_label.text = TaxForm._kr(sprint_money)
	sprint_money_label.position = Vector2(right_wall.position.x + 20, 20)
	sprint_label.text = "%s/%s kunder tjent. Kvote: %s" \
		% [served_during_sprint, sprint_size, sprint_quota]
	sprint_label.position = sprint_money_label.position + Vector2(0, sprint_money_label.size.y - 30)

func setup_desk() -> void:
	# spawn rulebook
	var rulebook := RULEBOOK.instantiate()
	desk.place_board(rulebook, Vector2(200, 30))

	# spawn velkomstbrevet: en konvolut på skrivebordet, en side når det trækkes væk
	desk.place_board(Letter.new(WELCOME_LETTER), Vector2(0, 30))

func customer_arrive() -> void:
	if current_customer:
		return
	is_serving = true
	current_customer = Customer.new(Customer.get_random_customer_name())
	add_child(current_customer)
	# Loads current_customer just in front of background at index 0
	move_child(current_customer, 1)
	
	# Tweens the customer in
	current_customer.position = Vector2(get_viewport_rect().size/2) - Vector2(400,0)
	var tween = get_tree().create_tween()
	tween.tween_property(current_customer, "position", Vector2(get_viewport_rect().size/2), 1).set_trans(Tween.TRANS_SINE)
	
	await tween.finished
	current_customer.finished_speaking.connect(_on_customer_finished_speaking)
	current_customer.board_received.connect(_on_customer_board_received)
	current_customer.want_to_speak()
	current_customer.can_interact = true
	return

func customer_leave() -> void:
	if not current_customer:
		return
	is_serving = false
	served_during_sprint += 1
	sprint_label.text = "%s/%s customers served. Quota: %s" \
		% [served_during_sprint, sprint_size, sprint_quota]
	
	#Tween the customer out
	var tween = get_tree().create_tween()
	tween.tween_property(current_customer, "position", Vector2(get_viewport_rect().size/2 + Vector2(400,0)), 1).set_trans(Tween.TRANS_SINE)
	
	await tween.finished
	remove_customer()
	if served_during_sprint >= sprint_size: finish_sprint()

func finish_sprint() -> void:
	# If quota reached
	if sprint_money >= sprint_quota:
		complete_quota()
	# If quota not reached
	else:
		game_over()

func complete_quota() -> void:
	# Quota animation
	quota_label.text = "Quota reached!"
	quota_label.scale = Vector2.ONE
	quota_label.show()
	Tweens.wobble(quota_label)
	save_money()
	await get_tree().create_timer(2).timeout
	var tween := get_tree().create_tween()
	tween.tween_property(quota_label, "scale", Vector2.ZERO, 1.0).set_ease(Tween.EASE_IN)
	
	await tween.finished
	quota_label.hide()
	
	quotas_served += 1
	start_new_sprint()

func save_money() -> void:
	var surplus = sprint_money - sprint_quota
	Global.money += surplus
	sprint_money = 0.00
	print(Global.money)
	
	# Animation
	money_popup_label.text = "+%s til din opsparing" % surplus
	show_earned_money()

func show_earned_money() -> void:
	var start_pos = sprint_money_label.position + Vector2(0, sprint_money_label.get_line_height() - 20)
	
	money_popup_label.show()
	Tweens.wobble(money_popup_label)
	var tween = get_tree().create_tween()
	tween.tween_property(money_popup_label, "position", start_pos + Vector2(0,20), 2) \
		.from(start_pos) \
		.set_ease(Tween.EASE_OUT)
	money_popup_label.modulate.a = 1.0
	Tweens.fade(money_popup_label,2,0)
	
	await tween.finished
	money_popup_label.hide()

func get_sprint_quota(n: int) -> float:
	var n0 := float(first_sprint_size)
	var slope := MAXPAYMENT * 1.25 * RAMP 
	return FIRST_SPRINT_QUOTA + slope * (n - n0) * (1.0 - n0 / n)

func start_new_sprint() -> void:
	sprint_size += 1
	sprint_quota = snappedf(get_sprint_quota(sprint_size), 0.01)
	served_during_sprint = 0
	sprint_label.text = "%s/%s customers served. Quota: %s" \
		% [served_during_sprint, sprint_size, sprint_quota]

func game_over() -> void:
	Global.game_over = true
	quota_label.text = "You didn't reach the quota!?"
	quota_label.show()
	Tweens.wobble(quota_label)
	
	move_child(game_over_screen, -1)
	game_over_label.text = "You're fired"
	game_over_sub_label.text = "The firing squad is coming for you"
	red_tint.size = get_viewport_rect().size
	
	game_over_screen.position = Vector2(0, -get_viewport_rect().size.y)   # start off-screen, avoids a one-frame flash
	retry_button.disabled = true
	game_over_screen.show()
	await get_tree().process_frame
	
	var center := get_viewport_rect().size / 2
	game_over_label.position = center - game_over_label.size / 2
	retry_button.position = Vector2(center.x - retry_button.size.x / 2, center.y + 125)
	
	
	var fade := get_tree().create_tween()
	fade.tween_property(AudioPlayer.music_player, "volume_db", -80.0, 1)
	
	await fade.finished
	var bounce := get_tree().create_tween()
	bounce.tween_property(game_over_screen, "position", Vector2.ZERO, 1) \
		.from(Vector2(0,-648)) \
		.set_trans(Tween.TRANS_BOUNCE) \
		.set_ease(Tween.EASE_OUT)
	
	# Plays sound effect on first impact
	get_tree().create_timer(0.364).timeout.connect(
		func(): AudioPlayer.play_sound_effect("res://Resources/Audio/SoundEffects/AnimationSoundEffects/GameOverScreenFallHit.mp3"))
	
	await bounce.finished
	retry_button.disabled = false

func remove_customer() -> void:
	if current_customer == null:
		return
	current_customer.queue_free()
	current_customer = null
	is_serving = false

# Fjern blanketten, når kunden har fået den tilbage
func remove_paper() -> void:
	if current_paper == null:
		return
	current_paper.set_enabled(false) # skjul, fjern clips og tag den ud af "boards"
	current_paper.queue_free()
	current_paper = null

func _on_customer_finished_speaking() -> void:
	current_paper = paper_types.pick_weighted_random().new()
	desk.place_board(current_paper)

func _on_customer_board_received(_board: Board = null) -> void:
	payment_guess = TaxForm._parse_kr(current_paper.answer_field.text)
	get_payout()
	remove_paper()
	customer_leave()

func get_payout() -> void:
	if not current_paper: return
	var actual_payment: float = current_paper.get_correct_total()
	var d_payment := absf(actual_payment - payment_guess)

	var payout: float
	# Præcis rigtigt giver bonus. Sammenlign med en tolerance, ikke == 0: et korrekt
	# indtastet svar kan afvige med fx 0.00000000006 pga. afrunding af kommatal.
	# Tjekkes først, så formlen nedenfor aldrig regner 0 / 0 (= NaN), når svaret er 0 kr.
	if d_payment < EXACT_TOLERANCE:
		payout = MAXPAYMENT * 1.25
	# Der skulle ikke betales noget, men spilleren skrev et beløb
	elif actual_payment == 0.0:
		payout = -MAXPAYMENT
	else:
		# This distributes the pay according to d_payment via. a Gauss curve
		# If d_payment == 0, it returns MAXPAY * 1
		# If d_payment == actual_payment * 0.1, it returns 0
		# If d_payment >= actual_payment * 0.1, it asymptotically returns MAXPAY * (-1)
		payout = (2 * pow(1.0/2, pow(d_payment/(actual_payment * 0.1), 2)) - 1) * MAXPAYMENT
	sprint_money += payout
	
	AudioPlayer.play_sound_effect("res://Resources/Audio/SoundEffects/AnimationSoundEffects/money.mp3")
	sprint_money_label.text = TaxForm._kr(sprint_money)
	Tweens.wobble(sprint_money_label)
	
	if payout >= 0:
		money_popup_label.text = "+%s kr" % payout
		set("theme_override_colors/font_color", Color.hex(0x40d85a))
	else:
		money_popup_label.text = "%s kr" % payout
		set("theme_override_colors/font_color", Color.hex(0xfe0023))
	show_earned_money()

func spawn_calculator() -> void:
	var calc = CALCULATOR_SCENE.instantiate() as Board
	desk.place_board(calc, Vector2(-200, -50))

# For setup
func set_sprite_size(sprite: Sprite2D, target_size: Vector2) -> void:
	if not sprite.texture:
		return
		
	var texture_size: Vector2 = sprite.texture.get_size()
	
	# Calculate the ratio needed to reach the target pixel dimensions
	sprite.scale = target_size / texture_size

# Test function
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Test"):
		save_money()
		if not current_paper: return
		get_viewport().set_input_as_handled() # Skriv ikke "å" i svarfeltet
		print("%s: korrekt %s, svar \"%s\", forskel %s" % [
			current_paper.get_form_title(),
			TaxForm._kr(current_paper.get_correct_total()),
			current_paper.answer_field.text,
			TaxForm._kr(current_paper.validate()),
		])
