# stair_link.gd - one end of a staircase between two sorting bands.
# Any file may edit any other, provided the docs are kept in step.
# See INTEGRATION_SEAMS.md for what core/ exposes.
#
# The stair art is painted on a band's Stairs tilemap; this trigger is what
# makes it mean something. Put one link at each end of a painted staircase -
# the one at the top carries the upper band, the one at the bottom the lower -
# and map.gd reparents Entities when the player walks over it.
#
# The band is per-placement, not per-tile: the same stair tile is the top of
# one staircase and the bottom of another, so the tileset cannot carry this.
class_name StairLink
extends Area2D

## Band the player ends up in after crossing this link, as an index into
## map.gd's BAND_PATHS: 0 = Layer1, 1 = Layer2, 2 = Layer3.
@export var to_band: int = 0
