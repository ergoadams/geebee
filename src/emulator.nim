import bus, cpu

var running = true

let bios_location = "roms/boot.gb"
let game_location = "roms/pokemon_blue.gb"

load_bios(bios_location)
load_game(game_location)

while running:
    cpu_tick()

# cpu_instrs
# PASSED TESTS:
#   01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11
# YET TO PASS:
#   