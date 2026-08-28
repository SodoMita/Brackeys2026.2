class_name UILayers
## Single source of truth for CanvasLayer ordering.
##
## CanvasLayer input is delivered top-down, so whoever has the highest layer
## wins the touch/click. Never hardcode layer numbers anywhere else — add a
## constant here instead, so the stack stays readable in one place.
##
##   RESULT  > PAUSE   : a victory / game-over card wins over a stale pause menu
##   PAUSE   > DIALOG  : pause works over a running dialogue
##   DIALOG  > TOUCH   : dialogue box is never covered by the virtual stick
##   TOUCH   > HUD     : buttons draw over passive HUD labels

const HUD := 1      # scenes/hud.tscn (passive labels, no input)
const TOUCH := 20   # scripts/ui/touch_controls.gd (gameplay-only)
const DIALOG := 30  # Dialogic layout node (raised on timeline start)
const PAUSE := 40   # scripts/ui/pause_menu.gd (modal, blocks everything)
const RESULT := 50  # scripts/ui/result_screen.gd (victory / game over)
