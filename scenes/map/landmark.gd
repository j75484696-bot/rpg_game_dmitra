# landmark.gd - somewhere on the overworld worth walking to.
# Any file may edit any other, provided the docs are kept in step.
# See INTEGRATION_SEAMS.md for what core/ exposes.
#
# A landmark is a spot the player stands on, not a thing they walk into: the
# shop's door is in a wall with no gap, so the trigger sits in the street
# outside it. map.gd tracks whichever one the player is standing on.
#
# `opens` is the seam COMBAT_DATA.md describes for the shop - "an overworld
# location ... opens as a full-screen screen pushed from map.gd". A landmark
# with no scene is scenery you can name.
class_name Landmark
extends Area2D

## What people call this place. Shown to the player, so write it as a name.
@export var label: String = ""

## Scene this landmark pushes when the player acts on it, or "" for none.
@export var opens: String = ""
