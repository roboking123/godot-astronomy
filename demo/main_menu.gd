extends Control
## Demo 啟動選單 — 選擇要看哪個展示場景


func _on_day_night_pressed() -> void:
	get_tree().change_scene_to_file("res://demo/day_night_demo.tscn")


func _on_solar_system_pressed() -> void:
	get_tree().change_scene_to_file("res://demo/solar_system_view.tscn")


