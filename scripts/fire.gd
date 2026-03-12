class_name Fire extends Node2D

@onready var anim = $AnimatedSprite2D

func _ready() -> void:
	anim.play("fire")
