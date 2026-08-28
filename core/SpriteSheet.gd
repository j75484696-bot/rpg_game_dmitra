# SpriteSheet.gd — turn a horizontal strip into SpriteFrames at runtime.
# Do NOT autoload this file. It is a class_name and is global automatically.
#
# Art arrives as one PNG per animation: a single row of equal cells, no padding.
# This slices it, so adding a new creature's idle is a matter of dropping the
# file in the right place — no scene editing, no hand-built AtlasTextures.
#
#     var frames := SpriteSheet.strip(tex, 64, 8, 12.0)
#     $Sprite.sprite_frames = frames
#     $Sprite.play("bidle")
class_name SpriteSheet
extends RefCounted

const ANIM := &"bidle"

# Where a creature's idle strip lives, by convention. Returns null if there is
# no art for that name yet — callers fall back to a placeholder.
#   "Frostbite Imp" -> res://assets/sprites/characters/enemy_frostbite_imp_bidle.png
static func find_idle(display_name: String, prefix: String = "enemy") -> Texture2D:
	var slug: String = display_name.to_lower().replace(" ", "_")
	var path: String = "res://assets/sprites/characters/%s_%s_bidle.png" % [prefix, slug]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

# Slice a single-row strip into a looping animation.
# cell is the square cell size; count is how many frames the row holds.
static func strip(texture: Texture2D, cell: int, count: int, fps: float = 12.0) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.clear_all()
	frames.add_animation(ANIM)
	frames.set_animation_loop(ANIM, true)
	frames.set_animation_speed(ANIM, fps)
	for i in count:
		var slice := AtlasTexture.new()
		slice.atlas = texture
		slice.region = Rect2(i * cell, 0, cell, cell)
		frames.add_frame(ANIM, slice)
	return frames

# Frame count inferred from the texture, so a strip can be re-exported with a
# different number of frames without touching code.
static func strip_auto(texture: Texture2D, cell: int = 64, fps: float = 12.0) -> SpriteFrames:
	var count: int = max(1, int(texture.get_width() / cell))
	return strip(texture, cell, count, fps)
