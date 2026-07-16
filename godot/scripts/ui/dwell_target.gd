class_name DwellTarget
extends RefCounted
## Hover-to-activate: keep palm / pointer over a Control for `duration_sec`.

var control: Control
var duration_sec: float = 3.0
var padding: float = 28.0
var id: StringName = &""
var enabled: bool = true

var progress: float = 0.0
var completed: bool = false


func _init(p_control: Control = null, p_duration: float = 3.0, p_id: StringName = &"") -> void:
	control = p_control
	duration_sec = maxf(0.05, p_duration)
	id = p_id


func reset() -> void:
	progress = 0.0
	completed = false


func is_hovering(palm_px: Vector2) -> bool:
	if not enabled or control == null or not is_instance_valid(control):
		return false
	if not control.is_visible_in_tree() or control is BaseButton and (control as BaseButton).disabled:
		return false
	var rect := control.get_global_rect().grow(padding)
	return rect.has_point(palm_px)


## Returns true once when dwell completes (edge).
func update(dt: float, hovering: bool) -> bool:
	if completed or not enabled:
		return false
	if hovering:
		progress = minf(1.0, progress + dt / duration_sec)
		if progress >= 1.0:
			completed = true
			return true
	else:
		# Fast decay so kids can re-aim without frustration
		progress = maxf(0.0, progress - dt * 1.6)
	return false


func remaining_sec() -> float:
	return maxf(0.0, duration_sec * (1.0 - progress))
