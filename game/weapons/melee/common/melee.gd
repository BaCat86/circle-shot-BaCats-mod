class_name Melee
extends Weapon


@export var damage: int
@export var shoot_interval := 1.0
@export var to_aim_time := 0.15
var _shoot_timer: float = 0.0
var _post_equip_tween: Tween
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _aim: Node2D = $Aim
@onready var _attack: Attack = $Attack


func _process(_delta: float) -> void:
	_aim.hide()
	if can_shoot():
		_aim.visible = _player.player_input.showing_aim
		rotation = _calculate_aim_direction()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server() and can_shoot() \
			and _player.player_input.shooting and _shoot_timer <= 0.0:
		shoot.rpc()
	_shoot_timer -= delta


func _shoot() -> void:
	_shoot_timer = shoot_interval
	_anim.play(&"Attack")
	block_shooting()
	
	if multiplayer.is_server():
		_attack.damage_multiplier = _player.damage_multiplier
		_attack.team = _player.team
		_attack.who = _player.id
		if has_node(^"Attack/RayDetector"):
			($Attack/RayDetector as RayCast2D).clear_exceptions()
		if has_node(^"Attack/ShapeDetector"):
			($Attack/ShapeDetector as ShapeCast2D).clear_exceptions()
	
	await _anim.animation_finished
	unlock_shooting()


func _make_current() -> void:
	_attack.damage = damage
	
	block_shooting()
	_anim.play(&"Equip")
	
	var anim_name: StringName = await _anim.animation_finished
	if anim_name != &"Equip":
		unlock_shooting()
		return
	
	_anim.play(&"PostEquip")
	_post_equip_tween = create_tween()
	_post_equip_tween.tween_property(self, ^":rotation", _calculate_aim_direction(), to_aim_time)
	await _post_equip_tween.finished
	
	unlock_shooting()


func _unmake_current() -> void:
	rotation = 0.0
	_anim.play(&"RESET")
	_anim.advance(0.01)


func can_reload() -> bool:
	return false


func get_ammo_text() -> String:
	return "Не ограничено"
