class_name TerrainFromImage
extends RefCounted

const GRID_WIDTH := 108
const GRID_HEIGHT := 192
const DISPLAY_WIDTH := 1080
const DISPLAY_HEIGHT := 1920
const TARGET_SOLID_RATIO := 0.40
const MIN_SOLID_RATIO := 0.35
const MAX_SOLID_RATIO := 0.45
const MIN_SOLID_COMPONENT := 8
const MIN_FREE_COMPONENT_RATIO := 0.15

const AIR := 0
const ROCK := 1
const SAND := 2
const ICE := 3
const WATER := 4

const NEIGHBOURS_4: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

func generate(source_image: Image) -> Variant:
	if source_image == null or source_image.is_empty():
		return null

	var display_image := _cover_crop(source_image, Vector2i(DISPLAY_WIDTH, DISPLAY_HEIGHT))
	var sample_image := display_image.duplicate()
	sample_image.resize(GRID_WIDTH, GRID_HEIGHT, Image.INTERPOLATE_BILINEAR)
	sample_image.convert(Image.FORMAT_RGBA8)

	var luminance := _read_luminance(sample_image)
	var threshold := _find_threshold(luminance)
	var threshold_solid_ratio := _solid_ratio_for_threshold(luminance, threshold)
	var solid := _make_solid_mask(luminance, threshold)

	_remove_small_solid_components(solid)
	_fill_isolated_free_cells(solid)

	var cells := _classify_materials(sample_image, solid)
	var safe_free_component := _largest_safe_free_component(cells)
	var minimum_free_cells := int(ceil(float(GRID_WIDTH * GRID_HEIGHT) * MIN_FREE_COMPONENT_RATIO))
	if safe_free_component.size() < minimum_free_cells:
		return null

	var safe_mask := PackedByteArray()
	safe_mask.resize(GRID_WIDTH * GRID_HEIGHT)
	for index in safe_free_component:
		safe_mask[index] = 1

	var ball_index := _choose_ball_start(safe_free_component, safe_mask)
	var hole_index := _farthest_cell(ball_index, safe_mask)
	if ball_index < 0 or hole_index < 0 or ball_index == hole_index:
		return null

	return {
		"width": GRID_WIDTH,
		"height": GRID_HEIGHT,
		"cells": cells,
		"ball_cell": _index_to_cell(ball_index),
		"hole_cell": _index_to_cell(hole_index),
		"threshold": threshold,
		"threshold_solid_ratio": threshold_solid_ratio,
		"final_solid_ratio": _final_solid_ratio(solid),
		"safe_free_ratio": float(safe_free_component.size()) / float(GRID_WIDTH * GRID_HEIGHT),
		"display_image": display_image,
		"sample_image": sample_image,
	}

func _cover_crop(source: Image, target_size: Vector2i) -> Image:
	var working := source.duplicate()
	working.convert(Image.FORMAT_RGBA8)

	var source_ratio := float(working.get_width()) / float(working.get_height())
	var target_ratio := float(target_size.x) / float(target_size.y)
	var crop_rect := Rect2i(Vector2i.ZERO, working.get_size())

	if source_ratio > target_ratio:
		var crop_width := maxi(1, int(round(float(working.get_height()) * target_ratio)))
		crop_rect.position.x = (working.get_width() - crop_width) / 2
		crop_rect.size.x = crop_width
	elif source_ratio < target_ratio:
		var crop_height := maxi(1, int(round(float(working.get_width()) / target_ratio)))
		crop_rect.position.y = (working.get_height() - crop_height) / 2
		crop_rect.size.y = crop_height

	var cropped: Image = working.get_region(crop_rect)
	cropped.resize(target_size.x, target_size.y, Image.INTERPOLATE_BILINEAR)
	return cropped

func _read_luminance(image: Image) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	values.resize(GRID_WIDTH * GRID_HEIGHT)
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var colour := image.get_pixel(x, y)
			values[_cell_to_index(Vector2i(x, y))] = colour.r * 0.2126 + colour.g * 0.7152 + colour.b * 0.0722
	return values

func _find_threshold(luminance: PackedFloat32Array) -> float:
	var low := 0.0
	var high := 1.0
	var threshold := 0.5
	for _iteration in range(18):
		threshold = (low + high) * 0.5
		var ratio := _solid_ratio_for_threshold(luminance, threshold)
		if ratio < MIN_SOLID_RATIO:
			low = threshold
		elif ratio > MAX_SOLID_RATIO:
			high = threshold
		else:
			break
	return threshold

func _solid_ratio_for_threshold(luminance: PackedFloat32Array, threshold: float) -> float:
	var solid_count := 0
	for value in luminance:
		if value < threshold:
			solid_count += 1
	return float(solid_count) / float(luminance.size())

func _make_solid_mask(luminance: PackedFloat32Array, threshold: float) -> PackedByteArray:
	var solid := PackedByteArray()
	solid.resize(luminance.size())
	for index in range(luminance.size()):
		solid[index] = 1 if luminance[index] < threshold else 0
	return solid

func _remove_small_solid_components(solid: PackedByteArray) -> void:
	var visited := PackedByteArray()
	visited.resize(solid.size())
	for start_index in range(solid.size()):
		if solid[start_index] == 0 or visited[start_index] == 1:
			continue
		var component := _flood_component(start_index, solid, 1, visited)
		if component.size() < MIN_SOLID_COMPONENT:
			for index in component:
				solid[index] = 0

func _fill_isolated_free_cells(solid: PackedByteArray) -> void:
	var to_fill := PackedInt32Array()
	for y in range(1, GRID_HEIGHT - 1):
		for x in range(1, GRID_WIDTH - 1):
			var index := _cell_to_index(Vector2i(x, y))
			if solid[index] == 1:
				continue
			var completely_surrounded := true
			for offset_y in range(-1, 2):
				for offset_x in range(-1, 2):
					if offset_x == 0 and offset_y == 0:
						continue
					var neighbour_index := _cell_to_index(Vector2i(x + offset_x, y + offset_y))
					if solid[neighbour_index] == 0:
						completely_surrounded = false
						break
				if not completely_surrounded:
					break
			if completely_surrounded:
				to_fill.append(index)
	for index in to_fill:
		solid[index] = 1

func _classify_materials(image: Image, solid: PackedByteArray) -> PackedInt32Array:
	var cells := PackedInt32Array()
	cells.resize(GRID_WIDTH * GRID_HEIGHT)
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var index := _cell_to_index(Vector2i(x, y))
			var colour := image.get_pixel(x, y)
			var hue_degrees := colour.h * 360.0
			if solid[index] == 1:
				if hue_degrees >= 20.0 and hue_degrees <= 60.0 and colour.s > 0.30:
					cells[index] = SAND
				elif colour.s < 0.15 and colour.v > 0.75:
					cells[index] = ICE
				else:
					cells[index] = ROCK
			else:
				if hue_degrees >= 180.0 and hue_degrees <= 260.0 and colour.s > 0.25:
					cells[index] = WATER
				else:
					cells[index] = AIR
	return cells

func _largest_safe_free_component(cells: PackedInt32Array) -> PackedInt32Array:
	var visited := PackedByteArray()
	visited.resize(cells.size())
	var largest := PackedInt32Array()
	for start_index in range(cells.size()):
		if cells[start_index] != AIR or visited[start_index] == 1:
			continue
		var component := PackedInt32Array()
		var queue := PackedInt32Array([start_index])
		visited[start_index] = 1
		var cursor := 0
		while cursor < queue.size():
			var index := queue[cursor]
			cursor += 1
			component.append(index)
			var cell := _index_to_cell(index)
			for offset in NEIGHBOURS_4:
				var neighbour := cell + offset
				if not _inside(neighbour):
					continue
				var neighbour_index := _cell_to_index(neighbour)
				if visited[neighbour_index] == 0 and cells[neighbour_index] == AIR:
					visited[neighbour_index] = 1
					queue.append(neighbour_index)
		if component.size() > largest.size():
			largest = component
	return largest

func _choose_ball_start(component: PackedInt32Array, safe_mask: PackedByteArray) -> int:
	if component.is_empty():
		return -1
	var minimum_y := GRID_HEIGHT
	var maximum_y := 0
	for index in component:
		var y := int(index / GRID_WIDTH)
		minimum_y = mini(minimum_y, y)
		maximum_y = maxi(maximum_y, y)
	var upper_limit := minimum_y + maxi(2, int(ceil(float(maximum_y - minimum_y + 1) * 0.25)))
	var best_index := -1
	var best_score := -INF
	for index in component:
		var cell := _index_to_cell(index)
		if cell.y > upper_limit:
			continue
		var clearance := _local_clearance(cell, safe_mask, 4)
		var centre_bias := -absf(float(cell.x) - float(GRID_WIDTH - 1) * 0.5) * 0.1
		var score := float(clearance) * 100.0 - float(cell.y) + centre_bias
		if score > best_score:
			best_score = score
			best_index = index
	return best_index

func _local_clearance(cell: Vector2i, safe_mask: PackedByteArray, radius: int) -> int:
	var score := 0
	for offset_y in range(-radius, radius + 1):
		for offset_x in range(-radius, radius + 1):
			if offset_x * offset_x + offset_y * offset_y > radius * radius:
				continue
			var neighbour := cell + Vector2i(offset_x, offset_y)
			if _inside(neighbour) and safe_mask[_cell_to_index(neighbour)] == 1:
				score += 1
	return score

func _farthest_cell(start_index: int, allowed_mask: PackedByteArray) -> int:
	var distance := PackedInt32Array()
	distance.resize(allowed_mask.size())
	for index in range(distance.size()):
		distance[index] = -1
	var queue := PackedInt32Array([start_index])
	distance[start_index] = 0
	var farthest_index := start_index
	var cursor := 0
	while cursor < queue.size():
		var index := queue[cursor]
		cursor += 1
		if distance[index] > distance[farthest_index]:
			farthest_index = index
		var cell := _index_to_cell(index)
		for offset in NEIGHBOURS_4:
			var neighbour := cell + offset
			if not _inside(neighbour):
				continue
			var neighbour_index := _cell_to_index(neighbour)
			if allowed_mask[neighbour_index] == 1 and distance[neighbour_index] == -1:
				distance[neighbour_index] = distance[index] + 1
				queue.append(neighbour_index)
	return farthest_index

func _flood_component(start_index: int, mask: PackedByteArray, target_value: int, visited: PackedByteArray) -> PackedInt32Array:
	var component := PackedInt32Array()
	var queue := PackedInt32Array([start_index])
	visited[start_index] = 1
	var cursor := 0
	while cursor < queue.size():
		var index := queue[cursor]
		cursor += 1
		component.append(index)
		var cell := _index_to_cell(index)
		for offset in NEIGHBOURS_4:
			var neighbour := cell + offset
			if not _inside(neighbour):
				continue
			var neighbour_index := _cell_to_index(neighbour)
			if visited[neighbour_index] == 0 and mask[neighbour_index] == target_value:
				visited[neighbour_index] = 1
				queue.append(neighbour_index)
	return component

func _final_solid_ratio(solid: PackedByteArray) -> float:
	var solid_count := 0
	for value in solid:
		if value == 1:
			solid_count += 1
	return float(solid_count) / float(solid.size())

func _cell_to_index(cell: Vector2i) -> int:
	return cell.y * GRID_WIDTH + cell.x

func _index_to_cell(index: int) -> Vector2i:
	return Vector2i(index % GRID_WIDTH, int(index / GRID_WIDTH))

func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT
