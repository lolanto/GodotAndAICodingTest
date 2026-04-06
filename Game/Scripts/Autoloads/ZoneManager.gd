extends Node

const MAX_REWIND_DURATION: float = 20.0

var _loaded_zones: Dictionary  = {}
var _zone_exit_timestamps: Dictionary = {}

func _ready() -> void:
	print("[ZoneManager] Initialized.")

func _physics_process(_delta: float) -> void:
	_check_safe_to_unload()

func player_entered_zone(zone_id: String) -> void:
	_zone_exit_timestamps.erase(zone_id)
	_preload_adjacent_zones(zone_id)

func player_exited_zone(zone_id: String) -> void:
	_zone_exit_timestamps[zone_id] = Time.get_ticks_msec() / 1000.0

func _load_zone(zone_id: String) -> void:
	if zone_id in _loaded_zones:
		return
	var path: String = "res://Scenes/Zones/%s.tscn" % zone_id
	if not ResourceLoader.exists(path):
		push_warning("[ZoneManager] Zone scene not found: %s" % path)
		return
	var zone = load(path).instantiate()
	get_tree().root.get_node("Main").add_child(zone)
	_loaded_zones[zone_id] = zone

func _unload_zone(zone_id: String) -> void:
	if not zone_id in _loaded_zones:
		return
	_zone_exit_timestamps.erase(zone_id)
	_loaded_zones[zone_id].queue_free()
	_loaded_zones.erase(zone_id)

func _check_safe_to_unload() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	for zone_id in _zone_exit_timestamps.keys():
		if now - _zone_exit_timestamps[zone_id] > MAX_REWIND_DURATION:
			_unload_zone(zone_id)

func _preload_adjacent_zones(_zone_id: String) -> void:
	# MVP: 无邻接数据，留空
	pass
