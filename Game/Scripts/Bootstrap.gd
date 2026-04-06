extends Node
## Bootstrap — Autoload singleton, initializes first before any scene.
## Responsibility: startup logging only. Holds no game state.


func _ready() -> void:
	print("[Bootstrap] Hello GravityRush - Engine started successfully")
