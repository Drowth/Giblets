class_name Pickup
extends Node2D

# Field consumable pickup — a rare, rescue-not-sustain drop the player must path
# to (no auto-magnet). Follows the manual distance-check pattern of XPOrb /
# BombPickup (NOT an Area2D signal — sidesteps collision-layer mismatches). The
# `kind` field keeps future pickup types pure data; two ship today:
#   "heal"   — restores GameState.PICKUP_HEAL_AMOUNT.
#   "magnet" — vacuums every XP orb on the field (reuses the boss-death vacuum).
# No scene file: constructed in code via Pickup.maybe_drop(), like BoneSentry.

const PICKUP_SOUND  := "res://assets/sfx/game/coin.wav"
const PICKUP_RADIUS := 12.0
const LIFETIME      := 18.0

var kind: String = "heal"

var _player: Node2D = null
var _time:   float  = 0.0
var _life:   float  = LIFETIME

# --- Spawn API ------------------------------------------------------------
# Called from every enemy's _die(). Non-boss drops are cooldown-gated in
# GameState; bosses always drop a heal.
static func maybe_drop(pos: Vector2, is_boss: bool) -> void:
	var k := ""
	if is_boss:
		k = "heal"
	elif GameState.try_reserve_pickup_drop():
		k = "heal" if randf() < 0.5 else "magnet"
	if k == "":
		return
	var tree := Engine.get_main_loop() as SceneTree
	if not tree or not is_instance_valid(tree.current_scene):
		return
	var p := Pickup.new()
	p.kind = k
	tree.current_scene.add_child(p)
	p.global_position = pos + Vector2(randf_range(-10, 10), randf_range(-10, 10))

# --- Instance -------------------------------------------------------------
func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	modulate.a = clampf(_life / 3.0, 0.0, 1.0)  # fade out in the last 3 s
	queue_redraw()
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	if global_position.distance_to(_player.global_position) < PICKUP_RADIUS + 10.0:
		_collect()

func _collect() -> void:
	match kind:
		"heal":
			GameState.heal(GameState.PICKUP_HEAL_AMOUNT)
		"magnet":
			var container := get_tree().get_first_node_in_group("xp_orbs_container")
			if container:
				for orb in container.get_children():
					orb._attracted = true
					orb._attract_speed = 80.0
	Sfx.play(PICKUP_SOUND, -2.0, 0.12)
	queue_free()

func _draw() -> void:
	var bob   := sin(_time * 3.0) * 3.0
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	var c     := Vector2(0.0, bob)
	if kind == "heal":
		# Soft green glow + a white health cross.
		draw_circle(c, PICKUP_RADIUS + pulse * 3.0, Color(0.2, 0.9, 0.3, 0.20 + pulse * 0.12))
		draw_circle(c, PICKUP_RADIUS, Color(0.10, 0.65, 0.20, 0.95))
		draw_circle(c, PICKUP_RADIUS * 0.66, Color(0.5, 1.0, 0.6))
		draw_rect(Rect2(c + Vector2(-2.5, -6.0), Vector2(5.0, 12.0)), Color.WHITE)
		draw_rect(Rect2(c + Vector2(-6.0, -2.5), Vector2(12.0, 5.0)), Color.WHITE)
	else:
		# Cyan glow + a magnet horseshoe (two prongs joined by an arc).
		draw_circle(c, PICKUP_RADIUS + pulse * 3.0, Color(0.2, 0.7, 1.0, 0.20 + pulse * 0.12))
		draw_circle(c, PICKUP_RADIUS, Color(0.06, 0.28, 0.75, 0.95))
		draw_arc(c, PICKUP_RADIUS * 0.62, PI, TAU, 20, Color(0.7, 0.9, 1.0), 3.5)
		draw_line(c + Vector2(-PICKUP_RADIUS * 0.62, 0.0), c + Vector2(-PICKUP_RADIUS * 0.62, 5.0), Color(0.7, 0.9, 1.0), 3.5)
		draw_line(c + Vector2( PICKUP_RADIUS * 0.62, 0.0), c + Vector2( PICKUP_RADIUS * 0.62, 5.0), Color(0.7, 0.9, 1.0), 3.5)
