extends Node

signal image_selected(image: Image)
signal media_error(message: String)

const PLUGIN_NAME := "SnapParAndroid"
var plugin: Object
var file_dialog: FileDialog

func _ready() -> void:
	if Engine.has_singleton(PLUGIN_NAME):
		plugin = Engine.get_singleton(PLUGIN_NAME)
		plugin.connect("image_selected", Callable(self, "_on_plugin_image_selected"))
		plugin.connect("media_error", Callable(self, "_on_plugin_error"))

func take_photo() -> void:
	if plugin:
		plugin.takePhoto()
		return
	image_selected.emit(create_test_image())

func pick_image() -> void:
	if plugin:
		plugin.pickImage()
		return
	_open_desktop_file_dialog()

func share_image(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if plugin:
		plugin.shareImage(absolute_path)
		return
	OS.shell_show_in_file_manager(absolute_path, true)

func _open_desktop_file_dialog() -> void:
	if file_dialog == null:
		file_dialog = FileDialog.new()
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		file_dialog.use_native_dialog = true
		file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Bilder"])
		file_dialog.file_selected.connect(_on_desktop_file_selected)
		add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.9)

func _on_desktop_file_selected(path: String) -> void:
	_load_image_path(path)

func _on_plugin_image_selected(path: String) -> void:
	_load_image_path(path)

func _load_image_path(path: String) -> void:
	var image := Image.new()
	var error := image.load(path)
	if error != OK:
		media_error.emit("Das Bild konnte nicht geladen werden")
		return
	image_selected.emit(image)

func _on_plugin_error(message: String) -> void:
	media_error.emit(message)

func create_test_image() -> Image:
	var image := Image.create(1080, 1920, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.88, 0.91, 0.95))
	for y in 1920:
		for x in 1080:
			var wave := sin(float(x) * 0.011) * 95.0 + sin(float(y) * 0.008) * 70.0
			var ground := y > 310.0 + wave and y < 1770.0 - sin(float(x) * 0.016) * 120.0
			if ground and not (x > 430 and x < 650 and y > 650 and y < 1450):
				var hue := fmod(float(x + y) * 0.00019, 1.0)
				image.set_pixel(x, y, Color.from_hsv(hue, 0.42, 0.27))
			elif x > 430 and x < 650 and y > 650 and y < 1450:
				image.set_pixel(x, y, Color.from_hsv(0.56, 0.58, 0.82))
	return image
