import strutils

var mbc_type*: uint8
var rom*: TaintedString
var rom_bank: uint8 = 1
var ram_bank: uint8
var rom_size*: uint32
var ram_size*: uint32
var ram: array[0x20000, uint8] # who cares about different ram sizes when you can just make it the biggest :)
var banking_mode: uint8
var ram_enabled: bool
var bios*: array[256, uint8]
var bios_mapped*: bool = true

proc cart_load8*(address: uint16): uint8 =
    case mbc_type:
        of 0:
            if address in 0x0000'u16 .. 0x0100'u16:
                if bios_mapped:
                    return bios[address]
                else:
                    return uint8(rom[address])
            elif address in 0x0101'u16 ..< 0x4000'u16:
                return uint8(rom[address])
            elif address in 0x4000'u16 ..< 0x8000'u16:
                if rom_bank == 0:
                    rom_bank += 1
                return uint8(rom[address + 0x4000*(rom_bank - 1)])
            else:
                echo "Unhandled mbc0 cart read address " & address.toHex()
        of 1:
            if address in 0x0000'u16 .. 0x0100'u16:
                if bios_mapped:
                    return bios[address]
                else:
                    if banking_mode == 1:
                        return uint8(rom[(uint32(address) + 0x4000'u32*uint32(rom_bank and 0b1100000)) and (rom_size - 1)])
                    else:
                        return uint8(rom[address])
            elif address in 0x0101'u16 ..< 0x4000'u16:
                
                if banking_mode == 1:
                    return uint8(rom[(uint32(address) + 0x4000'u32*uint32(rom_bank and 0b1100000)) and (rom_size - 1)])
                else:
                    return uint8(rom[address])
            elif address in 0x4000'u16 ..< 0x8000'u16:
                let offset = (uint32(address - 0x4000'u16) + uint32(rom_bank)*0x4000'u32) and (rom_size - 1)
                return uint8(rom[offset])
            elif address in 0xA000'u16 ..< 0xC000'u16:
                let offset = address - 0xA000'u16
                if ram_enabled:
                    return ram[offset + 0x2000*(ram_bank)]
                else:
                    return 0xFF'u8
            else:
                echo "Unhandled mbc1 cart read address " & address.toHex()
        of 3:
            if address in 0x4000'u16 ..< 0x8000'u16:
                return uint8(rom[address + 0x4000*(rom_bank - 1)])
            else:
                echo "Unhandled mbc3 cart read address " & address.toHex()
        else:
            echo "Unhandled cart read8 addr " & address.toHex()
            echo "Unhandled cart type " & $mbc_type
            return 0xFF'u8

proc cart_store8*(address: uint16, value: uint8) =
    case mbc_type:
        of 0:
            if address in 0x2000'u16 ..< 0x4000'u16:
                rom_bank = value and 0b11111
            else:
                echo "Unhandled mbc0 store8 addr " & address.toHex() & " value " & value.toHex()
        of 1:
            if address in 0x0000'u16 ..< 0x2000'u16:
                if (value and 0b1111) == 0x0A:
                    ram_enabled = true
                else:
                    ram_enabled = false
            elif address in 0x2000'u16 ..< 0x4000'u16:
                rom_bank = value and 0b11111
                
                if rom_bank == 0:
                    rom_bank = 1
            elif address in 0x4000'u16 ..< 0x6000'u16:
                if rom_size >= 0x100000'u32:
                    rom_bank = (rom_bank and 0b11111) or ((value and 0b11) shl 5)
                else:
                    ram_bank = value and 0b11
            elif address in 0x6000'u16 ..< 0x8000'u16:
                banking_mode = value and 1
            elif address in 0xA000'u16 ..< 0xC000'u16:
                let offset = address - 0xA000'u16
                if ram_enabled:
                    if ram_size >= 0x8000'u32:
                        if banking_mode == 1:
                            ram[offset + 0x2000*(ram_bank)] = value
                        else:
                            ram[offset] = value     
                    else:
                        ram[offset] = value            
            else:
                echo "Unhandled mbc1 store8 addr " & address.toHex() & " value " & value.toHex()
        of 3:
            if address in 0x0000'u16 ..< 0x2000'u16:
                if value == 0x0A'u8:
                    ram_enabled = true
                elif value == 0x00'u8:
                    ram_enabled = false
                else:
                    echo "Weird RAM/RTC enable value " & value.toHex()
            elif address in 0x2000'u16 ..< 0x4000'u16:
                rom_bank = value
                if value == 0:
                    rom_bank = 1
            else:
                echo "Unhandled mbc3 store8 addr " & address.toHex() & " value " & value.toHex()
        else:
            echo "Unhandled cart store8 addr " & address.toHex() & " value " & value.toHex()
            echo "Unhandled cart type " & $mbc_type