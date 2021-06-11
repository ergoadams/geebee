import times, os
import bus, cpu, ppu


var running = true

let bios_location = "roms/boot.gb"
#let game_location = "roms/blargg/instr_timing.gb"
#let game_location = "roms/optix/fairylake.gb"
let game_location = "roms/other/dmg-acid2.gb"
#let game_location = "roms/zelda.gb"

load_bios(bios_location)
load_game(game_location)
var prev_time = cpuTime()
while running: 
    
    cpu_tick()

    let cur_time = cpuTime()
    if (cur_time - prev_time) > 0.016:
        prev_time = cur_time
        parse_events()
        
        

# TODO:
#   Emulate haltbug
#   Interrupt timing
#   instruction timing off by 2