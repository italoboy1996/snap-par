extends Node

const CONFIG_PATH := "user://scores.cfg"
const SCORE_SECTION := "scores"
const BEST_KEY := "best_total"
const TUTORIAL_KEY := "tutorial_seen"
const HOLES_PER_ROUND := 3

var hole_images: Array[Image] = []
var hole_captures: Array[Image] = []
var hole_strokes: Array[int] = []
var hole_pars: Array[int] = []
var best_total := -1
var tutorial_seen := false

func _ready() -> void:
	_load_local_data()

func begin_round() -> void:
	hole_images.clear()
	hole_captures.clear()
	hole_strokes.clear()
	hole_pars.clear()

func record_hole(source_image: Image, capture: Image, strokes: int, par: int) -> void:
	hole_images.append(source_image.duplicate())
	hole_captures.append(capture.duplicate())
	hole_strokes.append(strokes)
	hole_pars.append(par)

func current_hole_number() -> int:
	return hole_strokes.size() + 1

func round_complete() -> bool:
	return hole_strokes.size() >= HOLES_PER_ROUND

func total_strokes() -> int:
	var total := 0
	for value in hole_strokes:
		total += value
	return total

func total_par() -> int:
	var total := 0
	for value in hole_pars:
		total += value
	return total

func finish_round() -> bool:
	var total := total_strokes()
	var is_new_best := best_total < 0 or total < best_total
	if is_new_best:
		best_total = total
		_save_local_data()
	return is_new_best

func mark_tutorial_seen() -> void:
	if tutorial_seen:
		return
	tutorial_seen = true
	_save_local_data()

func best_round_text() -> String:
	if best_total < 0:
		return "Beste Runde: noch keine"
	return "Beste Runde: %d Schlaege" % best_total

func _load_local_data() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	best_total = int(config.get_value(SCORE_SECTION, BEST_KEY, -1))
	tutorial_seen = bool(config.get_value(SCORE_SECTION, TUTORIAL_KEY, false))

func _save_local_data() -> void:
	var config := ConfigFile.new()
	config.set_value(SCORE_SECTION, BEST_KEY, best_total)
	config.set_value(SCORE_SECTION, TUTORIAL_KEY, tutorial_seen)
	config.save(CONFIG_PATH)
