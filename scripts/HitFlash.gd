class_name HitFlash

# On-hit impact blink — the shared "juice" primitive every enemy's take_hit()
# calls so a landed shot reads as an impact, not just a health-bar tick. A brief
# over-bright pop on the enemy's AnimatedSprite2D that tweens back to its resting
# modulate (WHITE, a per-enemy tint like WRAITH_TINT/IMP_TINT/BUTCHER_TINT, or
# the charm green). Procedural, no asset.
#
# Enemies that rewrite modulate every physics frame (BoneCharger WALK, Butcher
# ORBIT) would otherwise stomp the tween, so they guard that write with
# is_flashing() — during the ~90 ms pop the per-frame reset is skipped and the
# tween owns the colour; after it, the per-frame write resumes at the same value.
#
# Honors Settings.reduce_flash (softer pop) to match the windup de-strobe.

const FLASH_COLOR := Color(2.6, 2.6, 2.6)  # over-bright white pop
const SOFT_COLOR  := Color(1.6, 1.6, 1.6)  # reduce-flash: gentler
const DURATION    := 0.09
const _UNTIL_KEY  := "_hitflash_until"
const _TWEEN_KEY  := "_hitflash_tween"

# base = the sprite's resting modulate to fade back to (alpha is preserved so a
# translucent tint like the Wraith's stays translucent).
static func flash(sprite: CanvasItem, base: Color) -> void:
	if not is_instance_valid(sprite):
		return
	# Kill any in-progress flash so overlapping hits don't fight and we always
	# settle on the true resting colour. has_meta guards the lookup — get_meta
	# with a default still logs an error on a missing key in this build.
	if sprite.has_meta(_TWEEN_KEY):
		var prev = sprite.get_meta(_TWEEN_KEY)
		if prev and is_instance_valid(prev):
			prev.kill()
	var c: Color = SOFT_COLOR if Settings.reduce_flash else FLASH_COLOR
	sprite.modulate = Color(c.r, c.g, c.b, base.a)
	sprite.set_meta(_UNTIL_KEY, Time.get_ticks_msec() + int(DURATION * 1000.0))
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "modulate", base, DURATION)
	sprite.set_meta(_TWEEN_KEY, tw)

# True while a flash pop is playing — per-frame modulate writers consult this so
# they don't overwrite the pop.
static func is_flashing(sprite: CanvasItem) -> bool:
	if not is_instance_valid(sprite):
		return false
	if not sprite.has_meta(_UNTIL_KEY):
		return false
	return Time.get_ticks_msec() < int(sprite.get_meta(_UNTIL_KEY))
