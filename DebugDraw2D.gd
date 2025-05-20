extends CanvasLayer

static func draw_line_2d(from: Vector2, to: Vector2, color: Color, duration: float = 1.0):
	var canvas = CanvasItem.new()
	get_tree().root.add_child(canvas)
	
	canvas.draw_line(from, to, color, 2.0)
	
	if duration > 0:
		var timer = Timer.new()
		timer.wait_time = duration
		timer.one_shot = true
		timer.connect("timeout", canvas.queue_free)
		canvas.add_child(timer)
		timer.start()
