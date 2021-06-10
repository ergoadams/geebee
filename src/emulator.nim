import times, os
import bus, cpu, ppu


var running = true

let bios_location = "roms/boot.gb"
#let game_location = "roms/optix/fairylake.gb"
let game_location = "roms/pokemon_blue.gb"

let cycles_per_sec = 4194300'u32

load_bios(bios_location)
load_game(game_location)
var cpu_cycles: uint32
var prev_time = cpuTime()
var prev_cpu = cpuTime()
while running: # This would probably work if PPU interrupts and lines and stuff would work alright
    let cur_time = cpuTime()
    if (cpu_cycles == cycles_per_sec) and ((cur_time - prev_cpu) < 1):
        discard
    elif (cpu_cycles == cycles_per_sec) and ((cur_time - prev_cpu) >= 1):
        cpu_cycles = 0
    else:
        cpu_tick()
        ppu_tick()
        cpu_cycles += 1

    if (cur_time - prev_time) > 0.016:
        prev_time = cur_time
        parse_events()
        
        

# cpu_instrs
# PASSED TESTS:
#   01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11
# YET TO PASS:
#   