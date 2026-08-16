extends Node2D

@export var enabled: bool = false:
	set(value):
		enabled = value
		if value == true:
			part1.show()
			part2.show()
			anim_sprite1.show()
			anim_sprite2.show()
		if value == false:
			part1.hide()
			part2.hide()
			anim_sprite1.hide()
			anim_sprite2.hide()
		part1.emitting = value
		part2.emitting = value
		if value == true and not anim_sprite1.is_playing() and not anim_sprite2.is_playing():
			anim_sprite1.play("slide")
			anim_sprite2.play("slide")
		else:
			anim_sprite1.stop()
			anim_sprite2.stop()

@onready var part1: CPUParticles2D = $CPUParticles2D
@onready var part2: CPUParticles2D = $CPUParticles2D2
@onready var anim_sprite1: AnimatedSprite2D = $AnimatedSprite2D2
@onready var anim_sprite2: AnimatedSprite2D = $AnimatedSprite2D3
