extends CanvasLayer
class_name GameUI

signal start_game_pressed
signal restart_game_pressed

@onready var hud_panel: Control = $HUD
@onready var cargo_label: Label = $HUD/TopPill/HBox/CargoContainer/CargoLabel
@onready var score_label: Label = $HUD/TopPill/HBox/ScoreContainer/ScoreLabel
@onready var time_label: Label = $HUD/TopPill/HBox/TimeContainer/TimeLabel

@onready var sound_button: Button = $HUD/TopRight/SoundButton
@onready var restart_button: Button = $HUD/TopRight/RestartButton

@onready var toast_panel: PanelContainer = $HUD/ToastPanel
@onready var toast_label: Label = $HUD/ToastPanel/ToastLabel

@onready var modals_root: Control = $Modals
@onready var start_modal: Control = $Modals/StartModal
@onready var start_button: Button = $Modals/StartModal/Card/VBox/StartButton

@onready var victory_modal: Control = $Modals/VictoryModal
@onready var victory_score_label: Label = $Modals/VictoryModal/Card/VBox/ScoreLabel
@onready var victory_time_label: Label = $Modals/VictoryModal/Card/VBox/TimeLabel
@onready var victory_restart_button: Button = $Modals/VictoryModal/Card/VBox/VictoryRestartButton

@onready var defeat_modal: Control = $Modals/DefeatModal
@onready var defeat_cargo_label: Label = $Modals/DefeatModal/Card/VBox/CargoLabel
@onready var defeat_score_label: Label = $Modals/DefeatModal/Card/VBox/ScoreLabel
@onready var defeat_restart_button: Button = $Modals/DefeatModal/Card/VBox/DefeatRestartButton

var toast_tween: Tween

func _ready() -> void:
	toast_panel.modulate.a = 0.0
	victory_modal.visible = false
	defeat_modal.visible = false
	modals_root.visible = true
	start_modal.visible = true

	start_button.pressed.connect(_on_start_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	sound_button.pressed.connect(_on_sound_toggle_pressed)
	victory_restart_button.pressed.connect(_on_restart_pressed)
	defeat_restart_button.pressed.connect(_on_restart_pressed)

func update_hud(cargo_count: int, max_cargo: int, score: int, time_left: float) -> void:
	cargo_label.text = "Kargo: %d/%d" % [cargo_count, max_cargo]
	score_label.text = "Puan: %d" % score
	var seconds = max(0, int(ceil(time_left)))
	time_label.text = "Süre: %d sn" % seconds

func show_feedback(message: String, is_error: bool) -> void:
	toast_label.text = message
	var current_style = toast_panel.get_theme_stylebox("panel")
	var bg_style: StyleBoxFlat
	if current_style is StyleBoxFlat:
		bg_style = current_style.duplicate()
	else:
		bg_style = StyleBoxFlat.new()
		bg_style.corner_radius_top_left = 16
		bg_style.corner_radius_top_right = 16
		bg_style.corner_radius_bottom_right = 16
		bg_style.corner_radius_bottom_left = 16

	if is_error:
		bg_style.bg_color = Color(0.85, 0.22, 0.22, 0.95)
	else:
		bg_style.bg_color = Color(0.18, 0.65, 0.32, 0.95)
	toast_panel.add_theme_stylebox_override("panel", bg_style)

	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()

	toast_panel.modulate.a = 0.0
	toast_panel.position.y = 80.0
	toast_tween = create_tween()
	toast_tween.tween_property(toast_panel, "modulate:a", 1.0, 0.2)
	toast_tween.parallel().tween_property(toast_panel, "position:y", 90.0, 0.2)
	toast_tween.tween_interval(2.2)
	toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.3)

func show_start_modal() -> void:
	modals_root.visible = true
	start_modal.visible = true
	victory_modal.visible = false
	defeat_modal.visible = false

func hide_start_modal() -> void:
	start_modal.visible = false
	if not victory_modal.visible and not defeat_modal.visible:
		modals_root.visible = false

func show_victory_modal(final_score: int, time_remaining: float) -> void:
	victory_score_label.text = "Toplam Puan: %d" % final_score
	victory_time_label.text = "Kalan Süre: %d saniye" % int(time_remaining)
	modals_root.visible = true
	victory_modal.visible = true
	defeat_modal.visible = false
	start_modal.visible = false

func show_defeat_modal(cargo_count: int, max_cargo: int, final_score: int) -> void:
	defeat_cargo_label.text = "Kurtarılan Kargo: %d / %d" % [cargo_count, max_cargo]
	defeat_score_label.text = "Toplam Puan: %d" % final_score
	modals_root.visible = true
	defeat_modal.visible = true
	victory_modal.visible = false
	start_modal.visible = false

func hide_modals() -> void:
	modals_root.visible = false
	start_modal.visible = false
	victory_modal.visible = false
	defeat_modal.visible = false

func _on_start_pressed() -> void:
	if AudioManager: AudioManager.play_sfx("click")
	hide_modals()
	emit_signal("start_game_pressed")

func _on_restart_pressed() -> void:
	if AudioManager: AudioManager.play_sfx("click")
	hide_modals()
	emit_signal("restart_game_pressed")

func _on_sound_toggle_pressed() -> void:
	if AudioManager:
		AudioManager.play_sfx("click")
		var muted = AudioManager.toggle_mute()
		sound_button.text = "🔇" if muted else "🔊"
