extends RefCounted
class_name Layers

## Physics layers, as a contract between the player, the bugs and the camera.
##
## The split exists for one reason, and it is the camera: it must collide with
## the WORLD and nothing else. On a single shared layer a bug walking behind
## you shoves the view into the back of your own head at exactly the moment
## you need to see it, and a broken shell lying on the grass does the same.
##
## Getting these wrong fails quietly — a blade whose mask no longer includes
## CHARACTER simply stops hitting things — so they live in one place rather
## than as bare numbers in three files.

const WORLD     := 1    ## static geometry: ground, ramps, stairs, walls, trees, rocks
const CHARACTER := 2    ## the player, and anything that fights
const DEBRIS     := 4   ## broken shells, and anything else that only clatters

## Everything solid. What a body on the ground should walk into.
const SOLID := WORLD | CHARACTER | DEBRIS
