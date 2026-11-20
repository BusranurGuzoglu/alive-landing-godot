extends CharacterBody3D
class_name RescueDrone

signal action_feedback(message: String, is_error: bool)
signal cargo_picked_up
signal cargo_delivered
signal score_updated(points: int)

enum State {
	IDLE,
	LOADING,
	UNLOADING
}

@export var move_speed: float = 15.0
@export var acceleration: float = 30.0
@export var friction: float = 20.0
@export var fixed_altitude: float = 7.5
@export var map_boundary: float = 48.0

var current_state: State = State.IDLE
var has_cargo: bool = false
var hold_timer: float = 0.0
var hold_duration: float = 2.0

# Detection & Targets
var nearby_crates: Array[CargoCrate] = []
var closest_crate: CargoCrate = null
var is_in_ship_zone: bool = false
var ship_reference: Node3D = null

# Visual nodes
@onready var visual_root: Node3D = $VisualRoot
@onready var cargo_holder: Node3D = $VisualRoot/CargoHolder
@onready var rotor1: MeshInstance3D = $VisualRoot/Arms/Rotor1/Blades
@onready var rotor2: MeshInstance3D = $VisualRoot/Arms/Rotor2/Blades
@onready var rotor3: MeshInstance3D = $VisualRoot/Arms/Rotor3/Blades
@onready var rotor4: MeshInstance3D = $VisualRoot/Arms/Rotor4/Blades
@onready var progress_root: Node3D = $ProgressRoot
@onready var progress_label: Label3D = $ProgressRoot/ProgressLabel
@onready var progress_fill: MeshInstance3D = $ProgressRoot/ProgressFill
@onready var target_marker: Node3D = $TargetMarker
@onready var arrow_pivot: Node3D = $TargetMarker/ArrowPivot

var hover_time: float = 0.0
var target_tilt_x: float = 0.0
var target_tilt_z: float = 0.0
var can_control: bool = false

func _ready() -> void:
	global_position.y = fixed_altitude
	cargo_holder.visible = false
	progress_root.visible = false

func set_active(active: bool) -> void:
	can_control = active
	if not active:
		_cancel_hold_action()
		velocity = Vector3.ZERO
		if AudioManager:
			AudioManager.stop_propeller()
	else:
		if AudioManager:
			AudioManager.start_propeller()

func _physics_process(delta: float) -> void:
	if not can_control:
		return
		
	_handle_movement(delta)
	_handle_animation(delta)
	_find_closest_crate()
	_update_target_marker()
	_process_hold_action(delta)

func _handle_movement(delta: float) -> void:
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	if Input.is_action_pressed("move_up") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_action_pressed("move_down") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0

	input_dir = input_dir.normalized()

	# In isometric view, top-down input maps directly to X and Z
	var target_vel = Vector3(input_dir.x, 0.0, input_dir.y) * move_speed
	
	if input_dir.length_squared() > 0.01:
		velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)
		
		# If moving while attempting to hold, immediately cancel
		if current_state != State.IDLE:
			_cancel_hold_action("2 saniye boyunca hareketsiz kalmalısın!")
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	# Fixed altitude high above trees and ship
	velocity.y = 0.0
	move_and_slide()

	# Map boundary clamping (100x100 world)
	global_position.x = clampf(global_position.x, -map_boundary, map_boundary)
	global_position.z = clampf(global_position.z, -map_boundary, map_boundary)
	global_position.y = fixed_altitude + sin(hover_time * 3.5) * 0.08

func _handle_animation(delta: float) -> void:
	hover_time += delta

	# Spin rotors
	var rotor_spin = delta * 35.0
	if rotor1: rotor1.rotate_y(rotor_spin)
	if rotor2: rotor2.rotate_y(-rotor_spin)
	if rotor3: rotor3.rotate_y(rotor_spin)
	if rotor4: rotor4.rotate_y(-rotor_spin)

	# Tilt when moving
	target_tilt_x = clampf(-velocity.z * 0.025, -0.22, 0.22)
	target_tilt_z = clampf(velocity.x * 0.025, -0.22, 0.22)
	
	visual_root.rotation.x = lerp_angle(visual_root.rotation.x, target_tilt_x, delta * 8.0)
	visual_root.rotation.z = lerp_angle(visual_root.rotation.z, target_tilt_z, delta * 8.0)

	# Propeller audio pitch based on speed
	if AudioManager:
		var speed_ratio = velocity.length() / move_speed
		AudioManager.set_propeller_pitch(1.0 + speed_ratio * 0.25)

func _unhandled_input(event: InputEvent) -> void:
	if not can_control:
		return

	# Auto-repeat from a held key must never restart a 2-second hold.
	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed("interact_pickup") or (event is InputEventKey and event.pressed and event.keycode == KEY_Q):
		_trigger_pickup_request()
	elif event.is_action_pressed("interact_deliver") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		_trigger_deliver_request()

func _is_near_ship() -> bool:
	if is_in_ship_zone:
		return true
	if ship_reference and is_instance_valid(ship_reference):
		var horiz_dist = Vector2(global_position.x - ship_reference.global_position.x, global_position.z - ship_reference.global_position.z).length()
		if horiz_dist < 12.0:
			return true
	return false

func _trigger_pickup_request() -> void:
	# A second press while a hold is in progress must not reset the timer.
	if current_state != State.IDLE:
		return

	if has_cargo:
		emit_signal("action_feedback", "Dron zaten kargo taşıyor! Önce gemiye teslim et.", true)
		if AudioManager: AudioManager.play_sfx("warning_buzz")
		return

	if not closest_crate or not is_instance_valid(closest_crate) or closest_crate.is_collected:
		emit_signal("action_feedback", "Yakında kargo yok! Kargolara yaklaş ve [Q] tuşuna bas.", true)
		if AudioManager: AudioManager.play_sfx("warning_buzz")
		return

	var horiz_dist = Vector2(global_position.x - closest_crate.global_position.x, global_position.z - closest_crate.global_position.z).length()
	if horiz_dist > 4.2:
		emit_signal("action_feedback", "Kargoya biraz daha yaklaşmalısın!", true)
		if AudioManager: AudioManager.play_sfx("warning_buzz")
		return

	# Start loading process
	current_state = State.LOADING
	hold_timer = 0.0
	progress_root.visible = true
	progress_label.text = "[Q] Yükleniyor..."
	if AudioManager: AudioManager.start_charge()

func _trigger_deliver_request() -> void:
	# A second press while a hold is in progress must not reset the timer.
	if current_state != State.IDLE:
		return

	if not has_cargo:
		emit_signal("action_feedback", "Dron boş! Teslim edilecek kargo yok.", true)
		if AudioManager: AudioManager.play_sfx("warning_buzz")
		return

	if not _is_near_ship():
		emit_signal("action_feedback", "Gemiye teslim etmek için kıyıdaki gemiye yaklaşmalısın!", true)
		if AudioManager: AudioManager.play_sfx("warning_buzz")
		return

	# Start delivery process
	current_state = State.UNLOADING
	hold_timer = 0.0
	progress_root.visible = true
	progress_label.text = "[E] Gemiye Teslim Ediliyor..."
	if AudioManager: AudioManager.start_charge()

func _process_hold_action(delta: float) -> void:
	if current_state == State.IDLE:
		progress_root.visible = false
		return

	hold_timer += delta
	var progress = clampf(hold_timer / hold_duration, 0.0, 1.0)

	# The horizontal bar fills from left to right.
	if progress_fill:
		progress_fill.scale.x = maxf(progress, 0.001)
		progress_fill.position.x = -0.85 * (1.0 - progress)

	if hold_timer >= hold_duration:
		_complete_hold_action()

func _complete_hold_action() -> void:
	if current_state == State.LOADING:
		if closest_crate and is_instance_valid(closest_crate) and not closest_crate.is_collected:
			closest_crate.collect()
			has_cargo = true
			cargo_holder.visible = true
			emit_signal("score_updated", 5)
			emit_signal("cargo_picked_up")
			emit_signal("action_feedback", "+5 Puan! Kargo drona yüklendi.", false)
			if AudioManager:
				AudioManager.stop_charge()
				AudioManager.play_sfx("success_ding")

	elif current_state == State.UNLOADING:
		if _is_near_ship() and has_cargo:
			has_cargo = false
			cargo_holder.visible = false
			emit_signal("score_updated", 5)
			emit_signal("cargo_delivered")
			emit_signal("action_feedback", "+5 Puan! Kargo gemiye teslim edildi.", false)
			if AudioManager:
				AudioManager.stop_charge()
				AudioManager.play_sfx("success_ding")

	current_state = State.IDLE
	hold_timer = 0.0
	progress_root.visible = false

func _cancel_hold_action(reason: String = "") -> void:
	if current_state != State.IDLE:
		current_state = State.IDLE
		hold_timer = 0.0
		progress_root.visible = false
		if AudioManager:
			AudioManager.stop_charge()
			AudioManager.play_sfx("warning_buzz")
		if reason != "":
			emit_signal("action_feedback", reason, true)

func _update_target_marker() -> void:
	if not target_marker or not arrow_pivot:
		return

	# Empty: point at the nearest crate. Carrying: point at the ship.
	var target_pos: Vector3
	if has_cargo:
		if not ship_reference or not is_instance_valid(ship_reference):
			target_marker.visible = false
			return
		target_pos = ship_reference.global_position
	else:
		if not closest_crate or not is_instance_valid(closest_crate) or closest_crate.is_collected:
			target_marker.visible = false
			return
		target_pos = closest_crate.global_position

	var dir = Vector2(target_pos.x - global_position.x, target_pos.z - global_position.z)
	if dir.length_squared() < 0.04:
		target_marker.visible = false
		return

	dir = dir.normalized()
	target_marker.visible = true
	# The arrow mesh points along local +X; rotate the pivot toward the target.
	arrow_pivot.rotation.y = atan2(-dir.y, dir.x)


func _find_closest_crate() -> void:
	# Clean up nearby crates
	for i in range(nearby_crates.size() - 1, -1, -1):
		var c = nearby_crates[i]
		if not is_instance_valid(c) or c.is_collected:
			nearby_crates.remove_at(i)

	var min_dist = 99999.0
	var nearest: CargoCrate = null
	var tree = get_tree()
	if tree:
		var all_cargo = tree.get_nodes_in_group("cargo")
		for node in all_cargo:
			if node is CargoCrate and not node.is_collected:
				var horiz_d = Vector2(global_position.x - node.global_position.x, global_position.z - node.global_position.z).length()
				if horiz_d < min_dist:
					min_dist = horiz_d
					nearest = node

	if closest_crate != nearest:
		if closest_crate and is_instance_valid(closest_crate):
			closest_crate.set_highlight(false)
		closest_crate = nearest

	# Only highlight crate on ground when drone is directly overhead
	if closest_crate and is_instance_valid(closest_crate):
		var horiz_d = Vector2(global_position.x - closest_crate.global_position.x, global_position.z - closest_crate.global_position.z).length()
		closest_crate.set_highlight(horiz_d <= 4.2)

func _on_detection_area_area_entered(area: Area3D) -> void:
	var parent = area.get_parent()
	if parent is CargoCrate and not parent.is_collected:
		if not nearby_crates.has(parent):
			nearby_crates.append(parent)

func _on_detection_area_area_exited(area: Area3D) -> void:
	var parent = area.get_parent()
	if parent is CargoCrate:
		if parent == closest_crate:
			parent.set_highlight(false)
		nearby_crates.erase(parent)

func reset_drone(start_pos: Vector3) -> void:
	_cancel_hold_action()
	global_position = start_pos
	global_position.y = fixed_altitude
	velocity = Vector3.ZERO
	has_cargo = false
	cargo_holder.visible = false
	nearby_crates.clear()
	closest_crate = null
	is_in_ship_zone = false
