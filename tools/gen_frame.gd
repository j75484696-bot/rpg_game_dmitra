# gen_frame.gd — regenerates the 32x32 beveled panel frame.
#
# A faithful port of the Piskel console script the art came as, so the source
# of truth is here rather than in a browser tab. Run it to re-emit the PNG:
#
#     godot --headless --path . --script tools/gen_frame.gd
#
# 9-slice margins are 6,6,6,6. Every edge strip is uniform along its stretch
# axis and the centre is one flat colour, so it scales to any panel size with
# no artifacts. Mitre seams and rivets stay strictly inside the 6x6 corners.
extends SceneTree

const SIZE := 32
const MARGIN := 6
const OUT := "res://assets/ui/ui_panel.png"

# ring index -> [light side, dark side, corner mid]
const RINGS := {
	0: ["#2B1B00", "#2B1B00", "#2B1B00"],  # outer outline
	1: ["#FFF3B0", "#A87708", "#F5C518"],  # outer bevel
	2: ["#FFDE59", "#8F6606", "#D9A410"],
	3: ["#F5C518", "#7A5605", "#C08F0C"],  # frame face
	4: ["#5A3D04", "#FFDE59", "#C08F0C"],  # inner bevel, inverted = recessed
	5: ["#2B1B00", "#2B1B00", "#2B1B00"],  # inner outline
}
const CENTER := "#E8B923"   # the one flat colour in the middle

func _initialize() -> void:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)

	for y in SIZE:
		for x in SIZE:
			var r: int = min(min(x, y), min(SIZE - 1 - x, SIZE - 1 - y))
			var hex: String
			if r >= MARGIN:
				hex = CENTER
			else:
				var top: bool = y == r
				var left: bool = x == r
				var bottom: bool = y == SIZE - 1 - r
				var right: bool = x == SIZE - 1 - r
				var ring: Array = RINGS[r]
				if (top or left) and not (bottom or right):
					hex = ring[0]
				elif (bottom or right) and not (top or left):
					hex = ring[1]
				elif top and left:
					hex = ring[0]
				elif bottom and right:
					hex = ring[1]
				else:
					hex = ring[2]

				# Mitre seams, clamped inside the 6x6 corner boxes so nothing
				# pokes into a stretched region.
				var in_corner: bool = (x < MARGIN or x >= SIZE - MARGIN) \
					and (y < MARGIN or y >= SIZE - MARGIN)
				if in_corner and r >= 1 and r <= 4 and (x == y or x + y == SIZE - 1):
					hex = _shade(hex, 0.72)

			img.set_pixel(x, y, Color.html(hex))

	for p in [Vector2i(2, 2), Vector2i(28, 2), Vector2i(2, 28), Vector2i(28, 28)]:
		_rivet(img, p.x, p.y)

	var err := img.save_png(ProjectSettings.globalize_path(OUT))
	print("saved %s -> %s" % [OUT, "ok" if err == OK else "FAILED %d" % err])
	quit()

func _shade(hex: String, f: float) -> String:
	var c := Color.html(hex)
	return "#%02X%02X%02X" % [
		int(min(255.0, round(c.r * 255.0 * f))),
		int(min(255.0, round(c.g * 255.0 * f))),
		int(min(255.0, round(c.b * 255.0 * f))),
	]

func _rivet(img: Image, cx: int, cy: int) -> void:
	img.set_pixel(cx, cy, Color.html("#FFF3B0"))
	img.set_pixel(cx + 1, cy, Color.html("#F5C518"))
	img.set_pixel(cx, cy + 1, Color.html("#F5C518"))
	img.set_pixel(cx + 1, cy + 1, Color.html("#5A3D04"))
