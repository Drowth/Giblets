# Run: Godot --headless --path <project> --script res://tools/build_city_tileset.gd
# Rebuilds assets/city/city_tileset.tres from assets/city/tiles/ground_*.png and
# shadowtile_*.png, and (re)creates scenes/City.tscn if it doesn't already have
# manual edits worth preserving. Re-run after adding more ground_*/shadowtile_*
# tiles to the folder.
extends SceneTree

const TILES_DIR := "res://assets/city/tiles"
const CELL_SIZE := Vector2i(128, 64)
const REGION_SIZE := Vector2i(128, 256)
const TEXTURE_ORIGIN := Vector2i(0, 192) # region is taller than the cell; shift art up so its bottom edge sits on the diamond's bottom vertex
const OUT_TILESET := "res://assets/city/city_tileset.tres"
const OUT_SCENE := "res://scenes/City.tscn"

func _init() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_size = CELL_SIZE

	var names := _list_ground_tiles()
	var source_id := 0
	for fname in names:
		var tex: Texture2D = load(TILES_DIR + "/" + fname)
		if tex == null:
			printerr("Failed to load ", fname)
			continue
		var source := TileSetAtlasSource.new()
		source.resource_name = fname.get_basename()
		source.texture = tex
		source.texture_region_size = REGION_SIZE
		source.create_tile(Vector2i.ZERO)
		var tile_data := source.get_tile_data(Vector2i.ZERO, 0)
		tile_data.texture_origin = TEXTURE_ORIGIN
		tile_set.add_source(source, source_id)
		source_id += 1

	var err := ResourceSaver.save(tile_set, OUT_TILESET)
	if err != OK:
		printerr("Failed to save tileset: ", err)
		quit(1)
		return
	print("Saved ", OUT_TILESET, " with ", source_id, " sources")

	tile_set = load(OUT_TILESET)
	_build_scene(tile_set)
	quit()

func _list_ground_tiles() -> Array:
	var names: Array = []
	var dir := DirAccess.open(TILES_DIR)
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".png"):
			if fname.begins_with("ground_") or fname.begins_with("shadowtile_"):
				names.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	names.sort()
	return names

func _build_scene(tile_set: TileSet) -> void:
	var root := Node2D.new()
	root.name = "City"

	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tile_set
	root.add_child(ground)
	ground.owner = root

	var props := Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	root.add_child(props)
	props.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, OUT_SCENE)
	if err != OK:
		printerr("Failed to save scene: ", err)
		quit(1)
		return
	print("Saved ", OUT_SCENE)
