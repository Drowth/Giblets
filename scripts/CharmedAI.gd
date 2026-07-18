class_name CharmedAI

# Shared behavior for enemies under the Reaper's Puppet Master charm.
# They hunt the nearest non-charmed enemy and deal reduced contact damage.

const CHARMED_ATTACK_RANGE := 25.0
const CHARMED_DAMAGE_PCT := 0.5

static func process_charmed(enemy: CharacterBody2D, delta: float) -> bool:
	if not enemy._charmed:
		return false

	enemy._charm_timer = maxf(0.0, enemy._charm_timer - delta)
	if enemy._charm_timer <= 0.0:
		enemy._charmed = false
		if enemy.has_method("_die"):
			enemy._die()
		return true

	var target := _find_target(enemy)
	var moving := false

	if target:
		var to_target := target.global_position - enemy.global_position
		var dist := to_target.length()
		var last_dir: Vector2 = enemy.get("_last_dir") if enemy.get("_last_dir") is Vector2 else Vector2.DOWN
		var dir: Vector2 = to_target.normalized() if dist > 0.01 else last_dir

		if "_last_dir" in enemy:
			enemy._last_dir = dir
		enemy._facing = enemy._dir_to_compass(dir)
		enemy.velocity = dir * enemy.move_speed
		enemy.move_and_slide()
		moving = true

		enemy._contact_timer = maxf(0.0, enemy._contact_timer - delta)
		if dist < CHARMED_ATTACK_RANGE and enemy._contact_timer <= 0.0:
			enemy._contact_timer = enemy.contact_cooldown
			var dmg := int(enemy.damage * CHARMED_DAMAGE_PCT)
			if target.has_method("take_hit"):
				target.take_hit(dmg)
	else:
		enemy.velocity = Vector2.ZERO

	# Keep the charmed enemy visually moving
	if enemy.has_method("_play_anim"):
		enemy._play_anim("run" if moving else "idle")

	return true

static func _find_target(enemy: CharacterBody2D) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for e: Node2D in enemy.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e == enemy:
			continue
		# Only attack living, non-charmed enemies
		if e._dead or e._charmed:
			continue
		var d := enemy.global_position.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest
