extends RefCounted
class_name Palette

## Earthy, upbeat, deliberately not pastel. Every colour in the world comes
## from here so the whole place can be re-graded by editing one file.
##
## Note these are authored as sRGB hex. Godot treats StandardMaterial3D
## albedo as sRGB and converts internally, so what you type is what you see.

const GRASS        := Color("6f9c46")
const GRASS_WORN   := Color("87a355")
const DIRT         := Color("b08356")
const DIRT_DARK    := Color("8f6942")
const STONE        := Color("9a958a")
const STONE_LIGHT  := Color("b7b2a6")
const WOOD         := Color("8a5c3a")
const LEAF         := Color("5f9440")
const LEAF_LIGHT   := Color("7cae4c")
const ACCENT       := Color("e0a63c")   ## marigold — used for signage and markers
const HIT_FLASH    := Color("fff3dc")   ## the blink on a struck enemy. Warm rather
                                        ## than pure white, so it reads as sunlight
                                        ## catching it rather than as a UI effect
const HILL         := Color("6b8f4a")

const SKY_TOP      := Color("4f9fd8")
const SKY_HORIZON  := Color("d3e8ef")
const GND_HORIZON  := Color("a9b28c")
const GND_BOTTOM   := Color("6d7355")
const SUNLIGHT     := Color("fff2d6")
const FOG          := Color("bcd8e0")

## The dark behind readable text — Label3D outlines and the hull readout. A
## near-black with the world's green in it rather than a pure black, so text
## sits in the scene instead of on top of it.
const INK          := Color(0.06, 0.09, 0.07)


## A plain surface. Rough by default — a low roughness on an untextured
## primitive is most of what reads as "cheap plastic", so the default here
## is deliberately matte.
static func solid(c: Color, rough: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	# A little specular even on matte surfaces keeps edges from going dead flat.
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return m


## Same, but lit on both sides — for thin things like signage backing.
static func unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
