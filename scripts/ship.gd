extends Node3D
class_name CargoShip

signal delivery_zone_entered
signal delivery_zone_exited

@onready var propeller_mesh: MeshInstance3D = $MeshRoot/Propeller
@onready var deck_crates_root: Node3D = $MeshRoot/DeckCrates
@onready var delivery_area: Area3D = $DeliveryArea

var delivered_count: int = 0
var crate_mesh_instances: Array[MeshInstance3D] = []

func _ready() -> void:
	_init_deck_crates()

func _process(delta: float) -> void:
	# Slow idle spin of propeller in water
	if propeller_mesh:
		propeller_mesh.rotate_z(delta * 0.8)

func _init_deck_crates() -> void:
	if not deck_crates_root:
		return
	for child in deck_crates_root.get_children():
		if child is MeshInstance3D:
			child.visible = false
			crate_mesh_instances.append(child)

func set_delivered_count(count: int) -> void:
	delivered_count = count
	for i in range(crate_mesh_instances.size()):
		crate_mesh_instances[i].visible = (i < delivered_count)

func reset_ship() -> void:
	delivered_count = 0
	for crate in crate_mesh_instances:
		crate.visible = false

func _on_delivery_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("drone"):
		emit_signal("delivery_zone_entered")

func _on_delivery_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("drone"):
		emit_signal("delivery_zone_exited")
