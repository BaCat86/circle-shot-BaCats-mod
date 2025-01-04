class_name Gun
extends Weapon

## Узел оружия класса "Пистолеты".

## Интервал между выстрелами.
@export var shoot_interval := 0.5
## Сколько боеприпасов снимается за выстрел. Если боеприпасов в магазине меньше, чем это число,
## то будет выполнена автоматическая перезарядка.
@export var ammo_per_shot: int = 1
## Время, за которое оружие поворачивается в направление прицела.
@export var to_aim_time := 0.15
## Сцена со снарядом.
@export var projectile_scene: PackedScene

@export_group("Spread", "spread_")
## Базовый разброс оружия.
@export var spread_base := 1.0
## На сколько повысится разброс оружия при ходьбе.
@export var spread_walk := 1.0
## Множитель для определения максимальной скорости, при которой разброс
## при движении не будет добавляться.
@export_range(0.0, 1.0) var spread_walk_ratio := 0.5
## Кривая разброса. Значения графика есть разброс в определённый момент времени. НЕ может
## принимать отрицательные значения.
@export var spread_curve: Curve
## Длительность кривой разброса.
@export var spread_curve_time := 2.0
## Время, через которое будет циклиться таймер разброса вне длительности кривой начнёт циклиться.
@export var spread_post_curve_time := 1.0
## Время, за которое таймер разброса будет увеличен на [member shoot_interval].
@export var spread_increasing_time := 0.2
## Время, за которое разброс возвращается до базового после прекращения стрельбы.
@export var spread_reset_time := 0.4

@export_group("Recoil", "recoil_")
## Кривая отдачи. Значения графика есть поворот оружия в определённый момент времени.
## Может принимать отрицательные значения.
@export var recoil_curve: Curve
## Длительность кривой отдачи.
@export var recoil_curve_time := 5.0
## Кривая цикличной отдачи.
@export var recoil_cycle_curve: Curve
## Длительность кривой цикличной отдачи.
@export var recoil_cycle_curve_time := 2.0
## Время, за которое таймер отдачи будет увеличен на [member shoot_interval].
@export var recoil_increasing_time := 0.2
## Время, за которое отдача сбрасывается после прекращения стрельбы.
@export var recoil_reset_time := 0.3

var _shoot_timer := 0.0
var _recoil_timer := 0.0
var _spread_timer := 0.0
var _recoil_timer_tween: Tween
var _spread_timer_tween: Tween
var _turn_tween: Tween

@onready var _shoot_point: Marker2D = $ShootPoint
@onready var _anim: AnimationPlayer = $AnimationPlayer

@onready var _aim: Line2D = $ShootPoint/Aim
@onready var _aim_spread_left: Line2D = $ShootPoint/Aim/SpreadLeft
@onready var _aim_spread_right: Line2D = $ShootPoint/Aim/SpreadRight


func _process(_delta: float) -> void:
	_aim.hide()
	
	if can_shoot():
		_aim.visible = _player.player_input.showing_aim
		rotation = _calculate_aim_angle() + deg_to_rad(_calculate_recoil())
		
		var spread: float = _calculate_spread()
		_aim_spread_left.rotation_degrees = -spread
		_aim_spread_right.rotation_degrees = spread


func _physics_process(delta: float) -> void:
	if multiplayer.is_server() and can_shoot() and _player.player_input.shooting \
			and ammo >= ammo_per_shot and _shoot_timer <= 0.0:
		shoot.rpc()
	_shoot_timer -= delta
	if _player.is_local() and can_reload() and ammo < ammo_per_shot:
		_player.try_reload_weapon()


func _initialize() -> void:
	recoil_curve.bake()
	recoil_cycle_curve.bake()
	spread_curve.bake()


func _make_current() -> void:
	block_shooting()
	_anim.play(&"Equip")
	
	var anim_name: StringName = await _anim.animation_finished
	if anim_name != &"Equip":
		unlock_shooting()
		return
	
	_anim.play(&"PostEquip")
	_turn_tween = create_tween()
	_turn_tween.tween_property(self, ^":rotation", _calculate_aim_angle(), to_aim_time)
	await _turn_tween.finished
	
	unlock_shooting()


func _unmake_current() -> void:
	if is_instance_valid(_spread_timer_tween):
		_spread_timer_tween.kill()
	if is_instance_valid(_recoil_timer_tween):
		_recoil_timer_tween.kill()
	if is_instance_valid(_turn_tween):
		_turn_tween.finished.emit()
		_turn_tween.kill()
	
	_spread_timer = 0.0
	_recoil_timer = 0.0
	_shoot_timer = 0.0
	
	rotation = 0.0
	_anim.play(&"RESET")
	_anim.advance(0.01)


func _shoot() -> void:
	_shoot_timer = shoot_interval
	
	ammo -= ammo_per_shot
	_anim.play(&"Shoot")
	_anim.seek(0.0, true)
	if multiplayer.is_server():
		_create_projectile()
	
	if is_instance_valid(_spread_timer_tween):
		_spread_timer_tween.kill()
	if is_instance_valid(_recoil_timer_tween):
		_recoil_timer_tween.kill()
	
	_spread_timer_tween = create_tween()
	_spread_timer_tween.tween_property(self, ^":_spread_timer",
			_spread_timer + shoot_interval, spread_increasing_time)
	_spread_timer_tween.tween_property(self, ^":_spread_timer", 0.0, spread_reset_time).from(
			(fposmod(_spread_timer + shoot_interval - spread_curve_time, spread_post_curve_time)
			+ spread_curve_time)
			if _spread_timer + shoot_interval > spread_curve_time + spread_post_curve_time else
			(_spread_timer + shoot_interval)
	)
	
	_recoil_timer_tween = create_tween()
	_recoil_timer_tween.tween_property(self, ^":_recoil_timer",
			_recoil_timer + shoot_interval, recoil_increasing_time)
	_recoil_timer_tween.tween_property(self, ^":_recoil_timer", 0.0, recoil_reset_time).from(
			(fposmod(_recoil_timer + shoot_interval - recoil_curve_time, recoil_cycle_curve_time)
			+ recoil_curve_time)
			if _recoil_timer + shoot_interval > recoil_curve_time + recoil_cycle_curve_time else
			(_recoil_timer + shoot_interval)
	)


func _can_reload() -> bool:
	return _shoot_timer <= 0.0


func reload() -> void:
	_turn_tween = create_tween()
	_turn_tween.tween_property(self, ^":rotation", 0.0, to_aim_time)
	_anim.play(&"Reload")
	block_shooting()
	
	var anim_name: StringName = await _anim.animation_finished
	if anim_name != &"Reload":
		unlock_shooting()
		return
	
	_anim.play(&"PostReload")
	_turn_tween = create_tween()
	_turn_tween.tween_property(self, ^":rotation", _calculate_aim_angle(), to_aim_time)
	
	var difference: int = min(ammo_per_load - ammo, ammo_in_stock)
	ammo += difference
	ammo_in_stock -= difference
	_player.ammo_text_updated.emit(get_ammo_text())
	
	await _turn_tween.finished
	unlock_shooting()


func _calculate_recoil() -> float:
	if _recoil_timer > recoil_curve_time:
		return recoil_cycle_curve.sample_baked(fposmod(_recoil_timer - recoil_curve_time,
				recoil_cycle_curve_time) / recoil_cycle_curve_time)
	if _recoil_timer > 0.01:
		return recoil_curve.sample_baked(minf(_recoil_timer / recoil_curve_time, 1.0))
	return 0.0


func _calculate_shoot_spread() -> float:
	if _spread_timer > 0.01:
		return spread_curve.sample_baked(minf(_spread_timer / spread_curve_time, 1.0))
	return 0.0


func _calculate_walk_spread() -> float:
	return spread_walk * clampf((_player.entity_input.direction.length() - spread_walk_ratio)
			/ (1.0 - spread_walk_ratio), 0.0, 1.0)


func _calculate_spread() -> float:
	return _calculate_walk_spread() + _calculate_shoot_spread() + spread_base


func _create_projectile() -> void:
	var projectile: Projectile = projectile_scene.instantiate()
	projectile.position = _shoot_point.global_position
	projectile.damage_multiplier = _player.damage_multiplier
	var spread: float = _calculate_spread()
	projectile.rotation = _player.player_input.aim_direction.angle() \
			+ deg_to_rad(randf_range(-spread, spread)) \
			+ deg_to_rad(_calculate_recoil()) * signf(_player.player_input.aim_direction.x)
	projectile.team = _player.team
	projectile.who = _player.id
	projectile.name += str(randi())
	_projectiles_parent.add_child(projectile)
