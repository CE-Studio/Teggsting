class_name Trigger
extends Area3D


@export var count:int = 0
@export var connections:Array[Node]


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func press():
	for i in connections:
		if i.has_method("connectionOn"):
			i.connectionOn()


func unpress():
	for i in connections:
		if i.has_method("connectionOff"):
			i.connectionOff()


func _on_body_entered(body):
	if body is Player:
		if count == 0:
			press()
		count += 1


func _on_body_exited(body):
	if body is Player:
		count -= 1
		if count == 0:
			unpress()
