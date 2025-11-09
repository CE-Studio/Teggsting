@icon("res://textures/ico/player.svg")
extends CharacterBody3D
class_name Player


const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const GROUNDACCEL = 20.0
const AIRACCEL = 7.0
const FORCE = 50
const FALL_KILL_THRESHOLD:float = -8.5
const I_TIME:float = 1.25
const MAX_HEALTH:int = 6

static var instance:Player

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var dead:bool = false
var g_radius:GhostRadius = null
var i_time:float = 0.0
var hazard_collisions:int = 0
var die_y:float = 0.0
var health:int = MAX_HEALTH

@export var sfx_step:AudioStreamPlayer3D
@export var sfx_crack:AudioStreamPlayer3D

@onready var cam:Node3D = $SpringArm3D
@onready var ray:RayCast3D = $SpringArm3D/SpringArm3D/Node3D2/Node3D/Camera3D/RayCast3D
@onready var parent:Node3D = $"../"
@onready var grab:Node3D = $body/SpringArm3D/grabpoint
@onready var body:Node3D = $body
@onready var animtree:AnimationTree = $AnimationTree
@onready var radius:PackedScene = preload("res://parts/ghost_radius.tscn")
@onready var eggbert: Node3D = $body/Eggbert
@onready var ghost: Node3D = $body/Ghost

@onready var plane: MeshInstance3D = $body/Ghost/EggBertGhost/Plane


func _ready() -> void:
	ghost.hide()
	body.top_level = true
	instance = self


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var sen:int = ProjectSettings.get_setting("game/mouse_sensitivity")
		if Input.get_action_raw_strength("rotate") > 0.1:
			if grab.get_child_count() > 0:
				grab.get_child(0).apply_torque(Vector3(event.relative.y, event.relative.x, 0) / 10)
		else:
			rotate_y(event.relative.x / sen)
			cam.rotate_x(event.relative.y / sen)
			cam.rotation_degrees.x = clampf(cam.rotation_degrees.x, -90, 90)
	elif event.is_action_pressed("interact"):
		print("interact")
		if grab.get_child_count() > 0:
			_drop_cube()
			#print("hold")
			#var obj = grab.get_child(0)
			#var trans = Transform3D(obj.global_transform)
			#grab.remove_child(obj)
			#obj.axis_lock_linear_x = false
			#obj.axis_lock_linear_y = false
			#obj.axis_lock_linear_z = false
			#obj.collision_layer = 0b1
			#obj.collision_mask = 0b1
			#parent.add_child(obj)
			#obj.global_transform = trans
		elif ray.is_colliding():
			var obj = ray.get_collider()
			print(obj)
			if obj.is_in_group("grab") and not dead:
				obj.get_parent().remove_child(obj)
				grab.add_child(obj)
				obj.linear_velocity = Vector3.ZERO
				obj.position = Vector3.ZERO
				obj.axis_lock_linear_x = true
				obj.axis_lock_linear_y = true
				obj.axis_lock_linear_z = true
				obj.collision_layer = 0b0
				obj.collision_mask = 0b0
			elif obj.is_in_group("press"):
				if obj.has_method("press"):
					obj.press()


func _process(delta: float) -> void:
	body.global_position = global_position
	var movetrack := global_position + velocity
	if velocity and not (is_equal_approx(movetrack.x, body.global_position.x) and is_equal_approx(movetrack.z, body.global_position.z)):
		var rot := body.quaternion
		body.look_at(movetrack)
		body.quaternion = rot.slerp(body.quaternion, 8 * delta)
	else:
		body.quaternion = body.quaternion.slerp(quaternion, 8 * delta)
	var lvel := Vector3(velocity)
	lvel.y = 0
	var blend = lvel.length()
	blend = remap(clampf(blend, 0, 5), 0, 5, 0, 1)
	animtree["parameters/blend_position"] = blend

	if Input.is_action_just_pressed("restart"):
		MusicHandler.set_mus_live()
		get_tree().reload_current_scene.call_deferred()


func _physics_process(delta: float) -> void:
	var air_vel:float = 0.0

	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
		air_vel = velocity.y

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		var tv := Vector2(velocity.x, velocity.z)
		var td := Vector2(direction.x * SPEED, direction.z * SPEED)
		if is_on_floor():
			if tv != Vector2.ZERO and abs(tv.angle_to(td)) > 2.0:
				tv = Vector2.ZERO
			else:
				tv = tv.move_toward(td, delta * GROUNDACCEL)
		else:
			tv = tv.move_toward(td, delta * AIRACCEL)
		velocity.x = tv.x
		velocity.z = tv.y
	elif is_on_floor():
		var tv := Vector2(velocity.x, velocity.z)
		tv = tv.move_toward(Vector2.ZERO, delta * GROUNDACCEL)
		velocity.x = tv.x
		velocity.z = tv.y

	if grab.get_child_count() > 0:
		grab.get_child(0).position = Vector3.ZERO

	if move_and_slide():
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			var rbody := col.get_collider()
			if rbody is RigidBody3D:
				if rbody.is_in_group(&"pushable"):
					rbody.apply_force(col.get_normal() * -FORCE)

	if is_on_floor() and air_vel <= FALL_KILL_THRESHOLD:
		print("Eggbert hit the ground too hard")
		die()

	if dead and g_radius:
		var r_home:Vector3 = g_radius.position
		r_home.y = position.y
		var r_distance:float = position.distance_to(r_home)
		if r_distance > g_radius.RADIUS:
			position = position.move_toward(r_home, r_distance - g_radius.RADIUS)

		if Input.is_action_just_pressed("revive"):
			revive()

	if i_time > 0.0:
		i_time -= delta
		if i_time <= 0.0:
			visible = true
		else:
			visible = not visible
	if not dead and hazard_collisions > 0 and i_time <= 0.0:
		die()


func _play_step() -> void:
	sfx_step.play()


func _drop_cube() -> void:
	var obj = grab.get_child(0)
	var trans = Transform3D(obj.global_transform)
	grab.remove_child(obj)
	obj.axis_lock_linear_x = false
	obj.axis_lock_linear_y = false
	obj.axis_lock_linear_z = false
	obj.collision_layer = 9
	obj.collision_mask = 9
	parent.add_child(obj)
	obj.global_transform = trans


func die() -> void:
	if dead:
		return
	dead = true
	eggbert.hide()
	ghost.show()
	die_y = position.y
	sfx_crack.play()
	g_radius = radius.instantiate()
	parent.add_child(g_radius)
	g_radius.position = position
	g_radius.position.y = floori(g_radius.position.y)
	collision_mask -= 8
	collision_mask += 16
	if grab.get_child_count() > 0:
		_drop_cube()
	MusicHandler.set_mus_dead()


func revive() -> void:
	if not dead:
		return
	dead = false
	position = Vector3(
		g_radius.position.x,
		die_y,
		g_radius.position.z
	)
	g_radius.despawn()
	i_time = I_TIME
	collision_mask += 8
	collision_mask -= 16
	eggbert.show()
	ghost.hide()
	health = MAX_HEALTH
	MusicHandler.set_mus_live()


func _on_hazard_enter(_body:Node3D) -> void:
	hazard_collisions += 1


func _on_bullet_collide(_body:Node3D) -> void:
	if _body.is_in_group("bullet"):
		health -= 1
		if health <= 0:
			die()
	print(health)


func _on_hazard_exit(_body:Node3D) -> void:
	hazard_collisions -= 1
