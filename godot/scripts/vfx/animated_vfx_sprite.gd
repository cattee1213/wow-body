class_name AnimatedVfxSprite
extends Sprite2D
## Frame animator for spell VFX. Scales so the longer side ≈ target_px.

var frames: Array = [] # Texture2D
var fps: float = 12.0
var loop: bool = true
var playing: bool = true
var target_px: float = 96.0
var _t: float = 0.0
var _index: int = 0
var finished: bool = false

signal anim_finished


func setup(p_frames: Array, p_fps: float = 12.0, p_loop: bool = true, p_target_px: float = 96.0) -> void:
	frames = p_frames
	fps = maxf(p_fps, 1.0)
	loop = p_loop
	target_px = maxf(p_target_px, 8.0)
	_t = 0.0
	_index = 0
	finished = false
	playing = frames.size() > 0
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if frames.size() > 0:
		texture = frames[0]
		_apply_scale_for(texture)


func _apply_scale_for(tex: Texture2D) -> void:
	if tex == null:
		return
	var sz := tex.get_size()
	var longest := maxf(sz.x, sz.y)
	var s := target_px / maxf(longest, 1.0)
	scale = Vector2(s, s)


func _process(delta: float) -> void:
	if not playing or frames.size() <= 1:
		return
	_t += delta
	var step := 1.0 / fps
	while _t >= step:
		_t -= step
		_index += 1
		if _index >= frames.size():
			if loop:
				_index = 0
			else:
				_index = frames.size() - 1
				playing = false
				finished = true
				anim_finished.emit()
				break
		texture = frames[_index]
		_apply_scale_for(texture)


func set_frame_index(i: int) -> void:
	if frames.is_empty():
		return
	_index = posmod(i, frames.size())
	texture = frames[_index]
	_apply_scale_for(texture)
