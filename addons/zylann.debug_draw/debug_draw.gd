## @brief Single-file autoload for debug drawing and printing.
## Draw and print on screen from anywhere in a single line of code.
## Find it quickly by naming it "DDD".

# TODO Thread-safety
# TODO 2D functions

extends CanvasLayer
class_name DebugDraw

## @brief How many frames HUD text lines remain shown after being invoked.
const TEXT_LINGER_FRAMES = 5
## @brief How many frames lines remain shown after being drawn.
const LINES_LINGER_FRAMES = 1
## @brief Color of the text drawn as HUD
const TEXT_COLOR = Color.WHITE
## @brief Background color of the text drawn as HUD
const TEXT_BG_COLOR = Color(0.3, 0.3, 0.3, 0.8)

static var singleton : DebugDraw

# 2D

var _canvas_item : CanvasItem = null
static var _texts := {}
static var _font : Font = null

static var _lines_2d := []
static var _line_2d_pool := []

# 3D

static var _boxes := []
static var _box_pool := []
static var _box_mesh : Mesh = null
static var _line_material_pool := []

static var _lines_3d := []
static var _line_immediate_geometry : ImmediateMesh

func _init():		
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	# Get default font
	# Meh
	var c := Control.new()
	add_child(c)
	_font = c.get_theme_default_font()
	c.queue_free()
	
	_line_immediate_geometry = ImmediateMesh.new()
	
	var _mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _line_immediate_geometry
	_mesh_instance.material_override = DebugDraw._get_line_material()
	add_child(_mesh_instance)

	_canvas_item = DebugDraw._create_canvas_item()
	_canvas_item.draw.connect(_on_CanvasItem_draw)
	add_child(_canvas_item)

func _process(_delta: float):
	DebugDraw._process_boxes()
	DebugDraw._process_lines_3d()
	DebugDraw._process_lines_2d()
	_process_canvas()


static func _check_singleton_created_or_create():
	if singleton == null:
		singleton = _create_singleton()
static func _create_singleton():
	var debug_draw = DebugDraw.new()
	var root_node = Engine.get_main_loop().current_scene.get_parent()
	root_node.add_child.call_deferred(debug_draw)
	return debug_draw
static func _create_canvas_item():
	var canvas = Node2D.new()
	canvas.position = Vector2(8, 8)
	return canvas

## @brief Draws the unshaded outline of a 3D cube.
## @param position: world-space position of the center of the cube
## @param size: size of the cube in world units
## @param color
## @param linger_frames: optionally makes the box remain drawn for longer
static func draw_cube(position: Vector3, size: float, color: Color = Color.WHITE, linger := 0):
	if singleton == null:
		singleton = _create_singleton()
	draw_box(position, Vector3(size, size, size), color, linger)


## @brief Draws the unshaded outline of a 3D box.
## @param position: world-space position of the center of the box
## @param size: size of the box in world units
## @param color
## @param linger_frames: optionally makes the box remain drawn for longer
static func draw_box(position: Vector3, size: Vector3, color: Color = Color.WHITE, linger_frames = 0):
	if singleton == null:
		singleton = _create_singleton()
	var mi := _get_box()
	var mat := _get_line_material()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = position
	mi.scale = size
	_boxes.append({
		"node": mi,
		"frame": Engine.get_frames_drawn() + LINES_LINGER_FRAMES + linger_frames
	})


## @brief Draws the unshaded outline of a 3D transform3Ded cube.
## @param trans: transform of the cube. The basis defines its size.
## @param color
static func draw_transformed_cube(trans: Transform3D, color: Color = Color.WHITE):
	if singleton == null:
		singleton = _create_singleton()
	var mi := _get_box()
	var mat := _get_line_material()
	mat.albedo_color = color
	mi.material_override = mat
	mi.transform = Transform3D(trans.basis, trans.origin - trans.basis * Vector3(0.5,0.5,0.5))
	_boxes.append({
		"node": mi,
		"frame": Engine.get_frames_drawn() + LINES_LINGER_FRAMES
	})


## @brief Draws the basis of the given transform using 3 lines
##        of color red for X, green for Y, and blue for Z.
## @param transform
## @param scale: extra scale applied on top of the transform
static func draw_axes(_transform: Transform3D, _scale = 1.0):
	if singleton == null:
		singleton = _create_singleton()
	draw_ray_3d(_transform.origin, _transform.basis.x, _scale, Color(1,0,0))
	draw_ray_3d(_transform.origin, _transform.basis.y, _scale, Color(0,1,0))
	draw_ray_3d(_transform.origin, _transform.basis.z, _scale, Color(0,0,1))


## @brief Draws the unshaded outline of a 3D box.
## @param aabb: world-space box to draw as an AABB
## @param color
## @param linger_frames: optionally makes the box remain drawn for longer
static func draw_box_aabb(aabb: AABB, color = Color.WHITE, linger_frames = 0):
	if singleton == null:
		singleton = _create_singleton()
	var mi := _get_box()
	var mat := _get_line_material()
	mat.albedo_color = color
	mi.material_override = mat
	mi.translation = aabb.position
	mi.scale = aabb.size
	_boxes.append({
		"node": mi,
		"frame": Engine.get_frames_drawn() + LINES_LINGER_FRAMES + linger_frames
	})

## @brief Draws an unshaded 2D line.
## @param a: begin position in world units
## @param b: end position in world units
## @param color
static func draw_line_2d(a: Vector2, b: Vector2, color: Color, parent: Node2D, linger_frames = 0):
	# parent as a param is a temporary solution since creating my own node2d seems to cause positioning of the line to be very incorrect
	if singleton == null:
		singleton = _create_singleton()
	var mi := _get_line_2d(parent)
	mi.clear_points()
	mi.add_point(a)
	mi.add_point(b)
	mi.default_color = color
	_lines_2d.append({
		"node": mi,
		"frame": Engine.get_frames_drawn() + LINES_LINGER_FRAMES + linger_frames
	})
## @brief Draws an unshaded 2D line defined as a ray.
## @param origin: begin position in world units
## @param direction
## @param length: length of the line in world units
## @param color
static func draw_ray_2d(origin: Vector2, direction: Vector2, length: float, color: Color, parent: Node2D, linger_frames = 0):
	draw_line_2d(origin, origin + direction * length, color, parent, linger_frames)
## @brief Draws the unshaded outline of a 2D box.
## @param position: world-space position of the center of the box
## @param size: size of the box in world units
## @param color
## @param parent
## @param linger_frames: optionally makes the box remain drawn for longer
static func draw_box_2d(position: Vector2, size: Vector2, color: Color, parent: Node2D, linger_frames = 0):
	var up = Vector2.UP * size.y / 2
	var down = Vector2.DOWN * size.y / 2
	var left = Vector2.LEFT * size.x / 2
	var right = Vector2.RIGHT * size.x / 2
	# top line
	draw_line_2d(position + up + left, position + up + right, color, parent, linger_frames)
	# right line
	draw_line_2d(position + up + right, position + down + right, color, parent, linger_frames)
	# bottom line
	draw_line_2d(position + down + right, position + down + left, color, parent, linger_frames)
	# left line
	draw_line_2d(position + down + left, position + up + left, color, parent, linger_frames)

## @brief Draws an unshaded 3D line.
## @param a: begin position in world units
## @param b: end position in world units
## @param color
static func draw_line_3d(a: Vector3, b: Vector3, color: Color, linger_frames = 0):
	if singleton == null:
		singleton = _create_singleton()
	_lines_3d.append([
		a, b, color,
		Engine.get_frames_drawn() + LINES_LINGER_FRAMES + linger_frames,
	])

## @brief Draws an unshaded 3D line defined as a ray.
## @param origin: begin position in world units
## @param direction
## @param length: length of the line in world units
## @param color
static func draw_ray_3d(origin: Vector3, direction: Vector3, length: float, color: Color, linger_frames = 0):
	draw_line_3d(origin, origin + direction * length, color, linger_frames)


## @brief Adds a text monitoring line to the HUD, from the provided value.
## It will be shown as such: - {key}: {text}
## Multiple calls with the same `key` will override previous text.
## @param key: identifier of the line
## @param text: text to show next to the key
static func set_text(key: String, value):
	if singleton == null:
		singleton = _create_singleton()
	_texts[key] = {
		"text": value if typeof(value) == TYPE_STRING else str(value),
		"frame": Engine.get_frames_drawn() + TEXT_LINGER_FRAMES
	}

static func _get_box() -> MeshInstance3D:
	var mi : MeshInstance3D
	if len(_box_pool) == 0:
		mi = MeshInstance3D.new()
		if _box_mesh == null:
			_box_mesh = _create_wirecube_mesh(Color.WHITE)
		mi.mesh = _box_mesh
		singleton.add_child(mi)
	else:
		mi = _box_pool[-1]
		_box_pool.pop_back()
	return mi

static func _recycle_box(mi: MeshInstance3D):
	mi.hide()
	_box_pool.append(mi)

static func _get_line_2d(parent: Node2D) -> Line2D:
	var mi : Line2D
	if len(_line_2d_pool) == 0:
		mi = Line2D.new()
		mi.width = 0.1
		mi.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
		parent.add_child(mi)
	else:
		mi = _line_2d_pool[-1]
		_line_2d_pool.pop_back()
	return mi
static func _recycle_line_2d(mi: Line2D):
	mi.hide()
	_line_2d_pool.append(mi)


static func _get_line_material() -> StandardMaterial3D:
	var mat : StandardMaterial3D
	if len(_line_material_pool) == 0:
		mat = StandardMaterial3D.new()
		mat.flags_unshaded = true
		mat.vertex_color_use_as_albedo = true
	else:
		mat = _line_material_pool[-1]
		_line_material_pool.pop_back()
	return mat


static func _recycle_line_material(mat: StandardMaterial3D):
	_line_material_pool.append(mat)


static func _process_3d_boxes_delayed_free(items: Array):
	var i := 0
	while i < len(items):
		var d = items[i]
		if d.frame <= Engine.get_frames_drawn():
			_recycle_line_material(d.node.material_override)
			d.node.queue_free()
			items[i] = items[len(items) - 1]
			items.pop_back()
		else:
			i += 1


static func _process_boxes():
	_process_3d_boxes_delayed_free(_boxes)

	# Progressively delete boxes in pool
	if len(_box_pool) > 0:
		var last = _box_pool[-1]
		_box_pool.pop_back()
		last.queue_free()


static func _process_lines_2d_delayed_free(items: Array):
	var i := 0
	while i < len(items):
		var d = items[i]
		if d.frame <= Engine.get_frames_drawn():
			_recycle_line_material(d.node.material)
			d.node.queue_free()
			items[i] = items[len(items) - 1]
			items.pop_back()
		else:
			i += 1

static func _process_lines_2d():
	_process_lines_2d_delayed_free(_lines_2d)

	# Progressively delete boxes in pool
	if len(_line_2d_pool) > 0:
		var last = _line_2d_pool[-1]
		_line_2d_pool.pop_back()
		last.queue_free()

	# for line in _lines_2d:
	# 	if line.size() < 5:
	# 		var geometry: Line2D = Line2D.new()
	# 		geometry.add_point(line[0])
	# 		geometry.add_point(line[1])
	# 		geometry.default_color = line[2]
	# 		line.append(geometry)
	# 		singleton._canvas_item.add_child(geometry)

	# # Delayed removal
	# var i := 0
	# while i < len(_lines_2d):
	# 	var item = _lines_2d[i]
	# 	var frame = item[3]
	# 	if frame <= Engine.get_frames_drawn():
	# 		_lines_2d[i] = _lines_2d[len(_lines_2d) - 1]
	# 		var line = _lines_2d.pop_back()
	# 		singleton._canvas_item.remove_child(line[4])
	# 		line[4].queue_free()
	# 	else:
	# 		i += 1

static func _process_lines_3d():
	_line_immediate_geometry.clear_surfaces()
	if _lines_3d.size() > 0:
		_line_immediate_geometry.surface_begin(Mesh.PRIMITIVE_LINES)
		
		for line in _lines_3d:
			var p1 : Vector3 = line[0]
			var p2 : Vector3 = line[1]
			var color : Color = line[2]
			
			_line_immediate_geometry.surface_set_color(color)
			_line_immediate_geometry.surface_add_vertex(p1)
			_line_immediate_geometry.surface_add_vertex(p2)
		
		_line_immediate_geometry.surface_end()
		
	# Delayed removal
	var i := 0
	while i < len(_lines_3d):
		var item = _lines_3d[i]
		var frame = item[3]
		if frame <= Engine.get_frames_drawn():
			_lines_3d[i] = _lines_3d[len(_lines_3d) - 1]
			_lines_3d.pop_back()
		else:
			i += 1


func _process_canvas():	
	# Remove text lines after some time
	for key in _texts.keys():
		var t = _texts[key]
		if t.frame <= Engine.get_frames_drawn():
			_texts.erase(key)

	# Update canvas
	_canvas_item.queue_redraw()

func _on_CanvasItem_draw():
	var ci := _canvas_item

	var ascent := Vector2(0, _font.get_ascent())
	var pos := Vector2()
	var xpad := 2
	var ypad := 1
	var font_offset := ascent + Vector2(xpad, ypad)
	var line_height := _font.get_height() + 2 * ypad

	for key in _texts.keys():
		var t = _texts[key]
		var text := str(key, ": ", t.text, "\n")
		var ss := _font.get_string_size(text)
		ci.draw_rect(Rect2(pos, Vector2(ss.x + xpad * 2, line_height)), TEXT_BG_COLOR)
		ci.draw_string(_font, pos + font_offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT_COLOR)
		pos.y += line_height


static func _create_wirecube_mesh(color := Color.WHITE) -> ArrayMesh:
	var positions := PackedVector3Array([
		Vector3(-0.5, -0.5, -0.5), # bottom left back
		Vector3(0.5, -0.5, -0.5), # right bottom back
		Vector3(0.5, -0.5, 0.5), # right bottom forward
		Vector3(-0.5, -0.5, 0.5), # left bottom forward
		Vector3(-0.5, 0.5, -0.5), # left top back
		Vector3(0.5, 0.5, -0.5), # right top back
		Vector3(0.5, 0.5, 0.5), # right top forward
		Vector3(-0.5, 0.5, 0.5)  # left top forward
	])
	var colors := PackedColorArray([
		color, color, color, color,
		color, color, color, color,
	])
	var indices := PackedInt32Array([
		0, 1,
		1, 2,
		2, 3,
		3, 0,

		4, 5,
		5, 6,
		6, 7,
		7, 4,

		0, 4,
		1, 5,
		2, 6,
		3, 7
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh
