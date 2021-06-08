import strutils

var vram: array[0x2000, uint8]

var scy: uint8

proc vram_store8*(address: uint16, value: uint8) =
    vram[address] = value

proc vram_store16*(address: uint16, value: uint16) =
    vram[address + 0] = uint8(value shr 8)
    vram[address + 1] = uint8(value and 0xFF)

proc ppu_store8*(address: uint16, value: uint8) =
    case address:
        of 0x02: scy = value
        else:
            discard
            #echo "Unhandled ppu store8 addr " & address.toHex() & " value " & value.toHex() 

proc ppu_load8*(address: uint16): uint8 =
    case address:
        of 0x02: return scy
        of 0x04: return 0x90
        else: 
            echo "Unhandled ppu load8 address " & address.toHex()
            return 0xFF