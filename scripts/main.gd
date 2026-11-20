extends Node3D

@export var max_time: float = 120.0
@export var total_cargo_count: int = 10

var current_time: float = 120.0
var current_score: int = 0
var delivered_cargo: int = 0
var is_game_active: bool = false
var is_game_ended: bool = false

# Starting locations
var drone_start_pos: Vector3 = Vector3(-27.0, 7.5, 4.0)
var session_cargo_positions: Array[Vector3] = []

# Node references
@onready var drone: RescueDrone = $RescueDrone
@onready var ship: CargoShip = $CargoShip
@onready var camera: Camera3D = $Camera3D
@onready var ui: GameUI = $GameUI
@onready var crates_container: Node3D = $CratesContainer

var camera_offset: Vector3 = Vector3(0.0, 18.0, 14.5)
var cargo_scene: PackedScene = preload("res://scenes/cargo.tscn")
var spawned_crates: Array[CargoCrate] = []

func _ready() -> void:
	# Connect UI signals
	ui.start_game_pressed.connect(_on_start_game)
	ui.restart_game_pressed.connect(_on_restart_game)

	# Connect Drone signals
	drone.action_feedback.connect(_on_drone_feedback)
	drone.score_updated.connect(_on_drone_score_updated)
	drone.cargo_delivered.connect(_on_drone_cargo_delivered)

	# Connect Ship signals
	ship.delivery_zone_entered.connect(_on_ship_zone_entered)
	ship.delivery_zone_exited.connect(_on_ship_zone_exited)
	drone.ship_reference = ship

	# Generate 10 randomized but balanced session cargo positions
	_generate_session_positions()
	_spawn_crates()

	# Initial setup
	drone.reset_drone(drone_start_pos)
	drone.set_active(false)
	ui.update_hud(delivered_cargo, total_cargo_count, current_score, current_time)
	ui.show_start_modal()

func _generate_session_positions() -> void:
	session_cargo_positions.clear()
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var attempts = 0
	while session_cargo_positions.size() < total_cargo_count and attempts < 300:
		attempts += 1
		var angle = rng.randf_range(0.0, TAU)
		var dist = rng.randf_range(6.0, 24.0)
		var pos = Vector3(cos(angle) * dist, 1.05, sin(angle) * dist)

		# Avoid ship area at the western shoreline
		if pos.distance_to(Vector3(-31.0, 1.05, 0.0)) < 10.0:
			continue
		# Avoid drone starting position
		if pos.distance_to(drone_start_pos) < 4.0:
			continue

		# Check distance from existing crates
		var too_close = false
		for existing in session_cargo_positions:
			if pos.distance_to(existing) < 4.0:
				too_close = true
				break

		if not too_close:
			session_cargo_positions.append(pos)

	# Fallback if rng took too many attempts
	while session_cargo_positions.size() < total_cargo_count:
		var i = session_cargo_positions.size()
		var a = (float(i) / total_cargo_count) * TAU
		session_cargo_positions.append(Vector3(cos(a) * 16.0, 1.05, sin(a) * 16.0))

func _spawn_crates() -> void:
	for c in spawned_crates:
		if is_instance_valid(c):
			c.queue_free()
	spawned_crates.clear()

	for i in range(session_cargo_positions.size()):
		var crate = cargo_scene.instantiate() as CargoCrate
		crate.crate_id = i
		crates_container.add_child(crate)
		crate.reset_crate(session_cargo_positions[i])
		spawned_crates.append(crate)

func _process(delta: float) -> void:
	_update_camera(delta)


func _physics_process(delta: float) -> void:
	if not is_game_active or is_game_ended:
		return

	# The countdown runs before the drone's physics step, so a delivery that
	# lands on the exact final frame counts as a loss, as required by the spec.
	current_time -= delta
	if current_time <= 0.0:
		current_time = 0.0
		_trigger_defeat()
		return

	ui.update_hud(delivered_cargo, total_cargo_count, current_score, current_time)

func _update_camera(delta: float) -> void:
	if not camera or not drone:
		return
	var target_cam_pos = drone.global_position + camera_offset
	camera.global_position = camera.global_position.lerp(target_cam_pos, delta * 6.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R):
		_on_restart_game()

func _on_start_game() -> void:
	is_game_active = true
	is_game_ended = false
	current_time = max_time
	drone.set_active(true)
	ui.update_hud(delivered_cargo, total_cargo_count, current_score, current_time)

func _on_restart_game() -> void:
	is_game_ended = false
	current_time = max_time
	current_score = 0
	delivered_cargo = 0

	# Reset ship
	ship.reset_ship()

	# Reset crates to session positions
	for i in range(spawned_crates.size()):
		if i < session_cargo_positions.size():
			spawned_crates[i].reset_crate(session_cargo_positions[i])

	# Reset drone
	drone.reset_drone(drone_start_pos)

	if AudioManager:
		AudioManager.stop_all()

	# Start playing
	is_game_active = true
	drone.set_active(true)
	ui.update_hud(delivered_cargo, total_cargo_count, current_score, current_time)
	ui.hide_modals()

func _on_drone_score_updated(points: int) -> void:
	current_score += points
	ui.update_hud(delivered_cargo, total_cargo_count, current_score, current_time)

func _on_drone_cargo_delivered() -> void:
	delivered_cargo += 1
	ship.set_delivered_count(delivered_cargo)
	ui.update_hud(delivered_cargo, total_cargo_count, current_score, current_time)

	if delivered_cargo >= total_cargo_count:
		_trigger_victory()

func _trigger_victory() -> void:
	is_game_active = false
	is_game_ended = true
	drone.set_active(false)
	if AudioManager:
		AudioManager.stop_propeller()
		AudioManager.play_sfx("victory")
	ui.show_victory_modal(current_score, current_time)

func _trigger_defeat() -> void:
	is_game_active = false
	is_game_ended = true
	drone.set_active(false)
	if AudioManager:
		AudioManager.stop_propeller()
		AudioManager.play_sfx("game_over")
	ui.show_defeat_modal(delivered_cargo, total_cargo_count, current_score)

func _on_drone_feedback(message: String, is_error: bool) -> void:
	ui.show_feedback(message, is_error)

func _on_ship_zone_entered() -> void:
	drone.is_in_ship_zone = true

func _on_ship_zone_exited() -> void:
	drone.is_in_ship_zone = false
