# geebee

## Description
geebee (name by Mary) is a wannabe cycle accurate Gameboy emulator. 
This emulator was made in the course of a week as a "cycle accurate Gameboy emulator in a week" challenge. 

As of now the CPU is mostly M-cycle accurate with the exception of interrupt timings (not sure). PPU timings are mostly okay, but that does not take sprite count into account. 

You do need to provide the bootrom and game ROM. Locations/names are hardcoded into emulator.nim.

This emulator can play ROM only and MBC1/MBC3 games, adding additional MBCs should not be that hard. Post an issue and I'll probably do it. 

Joypad uses W/A/S/D for UP/LEFT/DOWN/RIGHT and U/I/J/K for START/SELECT/A/B

All pull requests and issues are welcome!
