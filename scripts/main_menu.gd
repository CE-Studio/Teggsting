extends Control


func _ready() -> void:
	$ButtonLayer/PanelContainer.visible = OS.has_feature("web")


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/levels/level_1.tscn")
