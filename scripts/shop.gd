extends Node

	## shop/merchant, thematically neutral object, a middleman between the player and upgrades
	##
	##
@export var area: Area2D
#@export var
#
#
var player_in_range: bool = false

func _ready():
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _process(delta):
	if Input.is_action_pressed("interact"):
		if player_in_range:
			DialogueManager.show_dialogue("shop")

func _on_body_entered(body):
	if body is Player:
		player_in_range = true

func _on_body_exited(body):
	if body is Player:
		player_in_range = false


func _exit_tree():
	area.body_entered.disconnect(_on_body_entered)
	area.body_exited.disconnect(_on_body_exited)
