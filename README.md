Debug drawing utility
==========================

This is a small debug drawing script. It lets you print text on the screen, draw boxes or lines from anywhere in your code. It is mostly geared towards 3D at the moment.


Usage
-------

Clone the repository anywhere inside your project then use it from any other script.

Example usage:

```gdscript
func _process(delta):
	# Some test variables, usually you'd get them from game logic
	var time = OS.get_ticks_msec() / 1000.0
	var box_pos = Vector3(0, sin(time * 4.0), 0)
	var line_begin = Vector3(-1, sin(time * 4.0), 0)
	var line_end = Vector3(1, cos(time * 4.0), 0)

	DebugDraw.draw_box(box_pos, Vector3(1, 2, 1), Color(0, 1, 0))
	DebugDraw.draw_line_3d(line_begin, line_end, Color(1, 1, 0))
	DebugDraw.set_text("Time", time)
	DebugDraw.set_text("Frames drawn", Engine.get_frames_drawn())
	DebugDraw.set_text("FPS", Engine.get_frames_per_second())
	DebugDraw.set_text("delta", delta)
```

![image](https://user-images.githubusercontent.com/1311555/83977160-3f8f5280-a8f6-11ea-8dbb-696f794fcd6a.png)
