import bus, cpu

var running = true

let bios_location = "roms/boot.gb"
let game_location = "roms/blargg/03.gb"

load_bios(bios_location)
load_game(game_location)

while running:
    cpu_tick()