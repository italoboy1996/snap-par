extends SceneTree

const Generator := preload("res://scripts/terrain_from_image.gd")

var failures: Array[String] = []

func _init() -> void:
	_test_noise_image()
	_test_single_black_bar()
	if failures.is_empty():
		print("Terrain tests passed: 2/2")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _test_noise_image() -> void:
	var image := Image.create(Generator.GRID_WIDTH, Generator.GRID_HEIGHT, false, Image.FORMAT_RGBA8)
	var random := RandomNumberGenerator.new()
	random.seed = 424242
	for y in range(Generator.GRID_HEIGHT):
		for x in range(Generator.GRID_WIDTH):
			var value := random.randf()
			image.set_pixel(x, y, Color(value, value, value, 1.0))

	var started_at := Time.get_ticks_msec()
	var result = Generator.new().generate(image)
	var elapsed_ms := Time.get_ticks_msec() - started_at
	_assert(elapsed_ms < 1000, "Rauschbild braucht %d ms und ueberschreitet das 1 Sekunden Ziel" % elapsed_ms)
	_assert(result != null, "Rauschbild wurde abgelehnt")
	if result == null:
		return
	_assert(result.cells.size() == Generator.GRID_WIDTH * Generator.GRID_HEIGHT, "Rauschbild hat falsche Rastergroesse")
	_assert(result.threshold_solid_ratio >= Generator.MIN_SOLID_RATIO, "Rauschbild unterschreitet 35 Prozent feste Zellen")
	_assert(result.threshold_solid_ratio <= Generator.MAX_SOLID_RATIO, "Rauschbild ueberschreitet 45 Prozent feste Zellen")
	_assert(result.ball_cell != result.hole_cell, "Rauschbild hat identische Start und Lochposition")
	_assert(_material_at(result, result.ball_cell) == Generator.AIR, "Ball startet im Rauschbild nicht in Luft")
	_assert(_material_at(result, result.hole_cell) == Generator.AIR, "Loch liegt im Rauschbild nicht in Luft")

func _test_single_black_bar() -> void:
	var image := Image.create(Generator.GRID_WIDTH, Generator.GRID_HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var bar_width := 43
	var bar_start := (Generator.GRID_WIDTH - bar_width) / 2
	for y in range(Generator.GRID_HEIGHT):
		for x in range(bar_start, bar_start + bar_width):
			image.set_pixel(x, y, Color.BLACK)

	var started_at := Time.get_ticks_msec()
	var result = Generator.new().generate(image)
	var elapsed_ms := Time.get_ticks_msec() - started_at
	_assert(elapsed_ms < 1000, "Balkenbild braucht %d ms und ueberschreitet das 1 Sekunden Ziel" % elapsed_ms)
	_assert(result != null, "Bild mit schwarzem Balken wurde abgelehnt")
	if result == null:
		return
	_assert(result.threshold_solid_ratio >= Generator.MIN_SOLID_RATIO, "Balkenbild unterschreitet 35 Prozent feste Zellen")
	_assert(result.threshold_solid_ratio <= Generator.MAX_SOLID_RATIO, "Balkenbild ueberschreitet 45 Prozent feste Zellen")
	var solid_samples := 0
	for y in range(0, Generator.GRID_HEIGHT, 16):
		var material := _material_at(result, Vector2i(bar_start + bar_width / 2, y))
		if material == Generator.ROCK or material == Generator.SAND or material == Generator.ICE:
			solid_samples += 1
	_assert(solid_samples >= 10, "Schwarzer Balken wurde nicht stabil als Terrain erkannt")
	_assert(_material_at(result, Vector2i(2, Generator.GRID_HEIGHT / 2)) == Generator.AIR, "Weisser Bereich links vom Balken ist nicht frei")
	_assert(_material_at(result, Vector2i(Generator.GRID_WIDTH - 3, Generator.GRID_HEIGHT / 2)) == Generator.AIR, "Weisser Bereich rechts vom Balken ist nicht frei")

func _material_at(result: Dictionary, cell: Vector2i) -> int:
	return result.cells[cell.y * Generator.GRID_WIDTH + cell.x]

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
