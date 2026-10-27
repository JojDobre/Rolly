extends RigidBody2D
## Gulička: kotúľa sa fyzikou a skáče len zo zeme.

signal landed(impact_speed: float)
signal jumped

@export var max_spin := 26.0        ## rad/s pri plnej rýchlosti
@export var spin_accel := 70.0      ## ako rýchlo sa roztočí
@export var brake := 10.0           ## brzdenie, keď hráč nič nedrží
@export var air_force := 1400.0     ## ovládanie vo vzduchu
@export var max_speed := 520.0
@export var jump_speed := 700.0     ## ~2,4 dlaždice vysoko pri gravitácii 1600
@export var coyote_time := 0.1      ## skok ešte chvíľu po zídení z hrany
@export var jump_buffer := 0.12     ## skok stlačený tesne pred dopadom
@export var push_force := 900.0     ## pomoc pri tlačení krabíc, aby sa nemusela rozbiehať

var input_enabled := true

var _grounded := false
var _since_ground := 1.0
var _since_jump_press := 1.0
var _jump_released := false
var _prev_vy := 0.0
var _teleport_to = null  # Vector2 alebo null

@onready var visual = $Visual  # ball_visual.gd


func _physics_process(delta: float) -> void:
	_since_ground += delta
	_since_jump_press += delta
	if input_enabled and Input.is_action_just_pressed("jump"):
		_since_jump_press = 0.0
	if Input.is_action_just_released("jump"):
		_jump_released = true


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _teleport_to != null:
		state.transform = Transform2D(0.0, _teleport_to)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		_teleport_to = null
		_prev_vy = 0.0
		return

	var dir := Input.get_axis("move_left", "move_right") if input_enabled else 0.0
	var was_grounded := _grounded
	_grounded = false
	for i in state.get_contact_count():
		var normal := state.get_contact_local_normal(i)
		if normal.dot(Vector2.UP) > 0.55:
			_grounded = true
		# Krabica pred guličkou v smere pohybu dostane extra postrčenie.
		elif dir != 0.0 and normal.x * dir < -0.5:
			var crate := state.get_contact_collider_object(i) as RigidBody2D
			if crate and crate.is_in_group("pushable"):
				crate.apply_central_force(Vector2(dir * push_force, 0.0))
	if _grounded:
		_since_ground = 0.0
		if not was_grounded and _prev_vy > 0.0:
			landed.emit(_prev_vy)

	var velocity := state.linear_velocity

	if dir != 0.0:
		state.angular_velocity = move_toward(state.angular_velocity, dir * max_spin, spin_accel * state.step)
		if not _grounded:
			velocity.x += dir * air_force * state.step
	elif _grounded:
		state.angular_velocity = move_toward(state.angular_velocity, 0.0, brake * state.step)

	velocity.x = clampf(velocity.x, -max_speed, max_speed)

	if _since_jump_press < jump_buffer and _since_ground < coyote_time:
		velocity.y = -jump_speed
		_since_jump_press = 1.0
		_since_ground = 1.0
		_jump_released = false
		jumped.emit()
	elif _jump_released:
		# Krátke ťuknutie = nižší skok.
		if velocity.y < 0.0:
			velocity.y *= 0.5
		_jump_released = false

	state.linear_velocity = velocity
	_prev_vy = velocity.y


## Presunie guličku na dané miesto (napr. na checkpoint) a zastaví ju.
func respawn(at: Vector2) -> void:
	_teleport_to = at
	visible = true
	input_enabled = true
	freeze = false
