extends Weapon


@export var projectile_scene: PackedScene
@export var throw_time: float = 1.0
@export var equip_time: float = 1.0
var _can_throw := true
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _throw_point: Marker2D = $ThrowPoint
@onready var _aim: Node2D = $Aim


func _process(_delta: float) -> void:
	_aim.visible = _player.player_input.aiming
	if _aim.visible:
		var aim_direction: Vector2 = _player.player_input.aim_direction
		aim_direction.x = absf(aim_direction.x) 
		_aim.rotation = aim_direction.angle()
	if multiplayer.multiplayer_peer:
		if multiplayer.is_server():
			if ammo > 0 and _can_throw and _player.player_input.shooting:
				shoot.rpc()


func _make_current() -> void:
	if ammo > 0 and _can_throw and process_mode != PROCESS_MODE_DISABLED:
		show()
		_anim.play("Equip")
	else:
		hide()


func _shoot() -> void:
	ammo -= 1
	_can_throw = false
	($ThrowTimer as Timer).start()
	_anim.play("Throw")
	var throw_direction: Vector2 = _player.player_input.aim_direction
	await _anim.animation_finished
	var projectile: Node2D = projectile_scene.instantiate()
	projectile.global_position = _throw_point.global_position
	projectile.rotation = throw_direction.angle()
	for i: Attack in projectile.get_node(^"Explosion/Attacks").get_children():
		i.who = _player.id
		i.damage = roundi(i.damage * _player.damage_multiplier)
	projectile.name += str(randi())
	_projectiles_parent.add_child(projectile)


func get_ammo_text() -> String:
	return "Осталось: %d" % ammo


func _on_throw_timer_timeout() -> void:
	_can_throw = true
	_make_current()
