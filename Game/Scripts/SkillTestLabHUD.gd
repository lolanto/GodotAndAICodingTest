extends CanvasLayer

@onready var ge_bar:        ProgressBar = $HUDContainer/GEBar
@onready var ce_bar:        ProgressBar = $HUDContainer/CEBar
@onready var time_scale_lbl:Label       = $HUDContainer/TimeScaleLabel
@onready var gravity_lbl:   Label       = $HUDContainer/GravityLabel
@onready var rewind_overlay:ColorRect   = $RewindOverlay
@onready var debug_panel:   Label       = $DebugPanel

func _process(_delta: float) -> void:
	ge_bar.max_value = GravityManager.ge_max
	ge_bar.value     = GravityManager.ge

	ce_bar.max_value = TimeManager.ce_max
	ce_bar.value     = TimeManager.ce

	time_scale_lbl.text = "×%.1f" % TimeManager.time_scale

	var dir  := GravityManager.direction
	var dir_sym: String
	if dir.is_equal_approx(Vector2.DOWN):  dir_sym = "↓"
	elif dir.is_equal_approx(Vector2.UP):  dir_sym = "↑"
	elif dir.is_equal_approx(Vector2.LEFT): dir_sym = "←"
	else:                                   dir_sym = "→"
	gravity_lbl.text = "%s ×%.2f" % [dir_sym, GravityManager.magnitude]

	# 回溯蓝色滤镜
	rewind_overlay.visible = TimeManager.is_rewinding
	rewind_overlay.modulate = Color(0.3, 0.5, 1.0, 0.25)

	# 调试面板
	debug_panel.text = (
		"GE: %.1f / %.0f\n" % [GravityManager.ge, GravityManager.ge_max] +
		"CE: %.1f / %.0f\n" % [TimeManager.ce, TimeManager.ce_max] +
		"time_scale: %.3f\n" % TimeManager.time_scale +
		"direction: (%.2f, %.2f)\n" % [GravityManager.direction.x, GravityManager.direction.y] +
		"magnitude: %.3f\n" % GravityManager.magnitude +
		"is_rewinding: %s\n" % str(TimeManager.is_rewinding) +
		"rewind_free_zone: %s\n" % str(TimeManager.in_rewind_free_zone) +
		"ring_buffer: %d / %d" % [TimeManager._valid_frame_count, TimeManager.MAX_FRAMES]
	)
