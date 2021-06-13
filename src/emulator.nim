import times
import bus, cpu, ppu


var running = true

let bios_location = "roms/boot.gb"
#let game_location = "roms/blargg/interrupt_time.gb"
#let game_location = "roms/optix/bully.gb"
#let game_location = "roms/other/dmg-acid2.gb"
#let game_location = "roms/mbc1/ram_256kb.gb"
let game_location = "roms/sml.gb"

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