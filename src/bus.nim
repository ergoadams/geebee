import streams, strutils
import ppu, timer, irq, cart, joypad


var hram: array[0x7F, uint8]
var wram: array[0x2000, uint8]

var sb: uint8

proc load_bios*(bios_location: string) =
    var s = newFileStream(bios_location, fmRead)
    var bios_pos = 0'u32
    while not s.atEnd:
        bios[bios_pos] = uint8(s.readChar())
        bios_pos += 1

    echo "Loaded bios from " & bios_location

proc load_game*(game_location: string) =
    echo "Loading game rom from " & game_location
    rom = readFile(game_location)
    echo "Game title: " & rom[0x134 .. 0x143]
    echo "Manufacturer code: " & rom[0x13F .. 0x142]
    echo "New licensee code: " & rom[0x144 .. 0x145]
    let cart_type = uint8(rom[0x147])
    mbc_type = case cart_type:
        of 0x00, 0x08, 0x09: 0
        of 0x01, 0x02, 0x03: 1
        of 0x05, 0x06: 2
        of 0x0F, 0x10, 0x11, 0x12, 0x13: 3
        of 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E: 5
        of 0x20: 6
        of 0x22: 7
        else: 0xFF
    echo "MBC type " & $mbc_type
    if mbc_type == 0xFF:
        echo "Unhandled mbc! " & cart_type.toHex()
    echo "Cartridge type: " & $cart_type.toHex()
    let rom_size_t = uint8(rom[0x148])
    rom_size = case rom_size_t:
        of 0x00: 0x8000'u32
        of 0x01: 0x10000'u32
        of 0x02: 0x20000'u32
        of 0x03: 0x40000'u32
        of 0x04: 0x80000'u32
        of 0x05: 0x100000'u32
        of 0x06: 0x200000'u32
        of 0x07: 0x400000'u32
        of 0x08: 0x800000'u32
        else: 
            echo "Unhandled rom size " & rom_size_t.toHex()
            0x00'u32
    echo "ROM size: " & $rom_size_t.toHex()
    let ram_size_t = uint8(rom[0x149])
    ram_size = case ram_size_t:
        of 0x00: 0x00'u32
        of 0x02: 0x2000'u32
        of 0x03: 0x8000'u32
        of 0x04: 0x20000'u32
        of 0x05: 0x10000'u32
        else: 
            echo "Unhandled ram size " & ram_size_t.toHex()
            0x00'u32
    echo "RAM size: " & $ram_size_t.toHex()
    echo "Is game Japanese? " & $(uint8(rom[0x149]) == 0)

    echo ""




proc load8*(address: uint16): uint8 =
    timer_tick()
    if address in 0x0000'u16 ..< 0x8000'u16:
        return cart_load8(address)
    elif address in 0x8000'u16 ..< 0xA000'u16:
        let offset = address - 0x8000'u16
        return vram_load8(offset)
    elif address in 0xA000'u16 ..< 0xC000'u16:
        return cart_load8(address)
    elif address in 0xC000'u16 ..< 0xE000'u16:
        let offset = address - 0xC000'u16
        return wram[offset]
    elif address in 0xFE00'u16 ..< 0xFEA0'u16:
        return oam_load(address - 0xFE00'u16)
    elif address == 0xFF00'u16:
        return pad_load8()
    elif address in 0xFF04'u16 ..< 0xFF08'u16:
        let offset = address - 0xFF04'u16
        return timer_load8(offset)
    elif address == 0xFF0F'u16:
        return irq_if
    elif address in 0xFF10'u16 .. 0xFF26'u16: # sound
        return 0xFF'u8
    elif address in 0xFF30'u16 ..< 0xFF40'u16: #sound
        return 0xFF'u8
    elif address in 0xFF40'u16 .. 0xFF4B'u16:
        let offset = address - 0xFF40'u16
        return ppu_load8(offset)
    elif address == 0xFF4D'u16:
        return 0xFF'u8
    elif address in 0xFF80'u16 .. 0xFFFE'u16:
        let offset = address - 0xFF80'u16
        return hram[offset]
    elif address == 0xFFFF'u16:
        return irq_ie
    else:
        quit("Unhandled load8 from " & address.toHex(), QuitSuccess)

proc load16*(address: uint16): uint16 =
    timer_tick()
    timer_tick()
    if address in 0x0000'u16 .. 0x0100'u16:
        if bios_mapped:
            var value: uint16
            value = value or (uint16(bios[address + 0]) shl 0)
            value = value or (uint16(bios[address + 1]) shl 8)
            return value
        else:
            var value: uint16
            value = value or (uint16(rom[address + 0]) shl 0)
            value = value or (uint16(rom[address + 1]) shl 8)
            return value
    elif address in 0x0100'u16 ..< 0x4000'u16:
        var value: uint16
        value = value or (uint16(rom[address + 0]) shl 0)
        value = value or (uint16(rom[address + 1]) shl 8)
        return value
    elif address in 0x4000'u16 ..< 0x8000'u16:
        # should check bank
        var value: uint16
        value = value or (uint16(cart_load8(address + 0)) shl 0)
        value = value or (uint16(cart_load8(address + 1)) shl 8)
        return value
    elif address in 0xC000'u16 ..< 0xE000'u16:
        let offset = address - 0xC000'u16
        var value: uint16
        value = value or (uint16(wram[offset + 0]) shl 0)
        value = value or (uint16(wram[offset + 1]) shl 8)
        return value
    else:
        quit("Unhandled load16 from " & address.toHex(), QuitSuccess)

proc store8*(address: uint16, value: uint8) =
    timer_tick()
    if address in 0x0000'u16 ..< 0x8000'u16:
        cart_store8(address, value)
    elif address in 0x8000'u16 .. 0x9FFF'u16:
        let offset = address - 0x8000
        vram_store8(offset, value)
    elif address in 0xA000'u16 ..< 0xC000'u16:
        cart_store8(address, value)
    elif address in 0xC000'u16 ..< 0xE000'u16:
        let offset = address - 0xC000'u16
        wram[offset] = value
    elif address in 0xFE00'u16 ..< 0xFEA0'u16:
        oam_write(address - 0xFE00'u16, value)
    elif address in 0xFEA0'u16 .. 0xFEFF'u16:
        discard
    elif address == 0xFF00:
        pad_store8(value)
    elif address == 0xFF01: 
        sb = value
    elif address == 0xFF02:
        if value == 0x81:
            write(stdout, char(sb))
        else:
            discard
            #echo "Unhandled SC value " & value.toHex()
    elif address in 0xFF04'u16 ..< 0xFF08'u16:
        let offset = address - 0xFF04'u16
        timer_store8(offset, value)
    elif address == 0xFF0F'u16:
        #echo "set irq if to ", int64(value).toBin(8)
        irq_if = value and 0b11111'u8
    elif address in 0xFF10'u16 .. 0xFF26'u16:
        #sound
        discard
    elif address in 0xFF30'u16 ..< 0xFF40'u16: #sound
        discard
    elif address in 0xFF40'u16 .. 0xFF4B'u16:
        let offset = address - 0xFF40'u16
        if offset == 6:
            var source = uint16(value) shl 8
            var destination = 0xFE00'u16
            for i in 0x00'u16 ..< 0xA0'u16:
                store8(destination + i, load8(source + i)) 
        else:
            ppu_store8(offset, value)
    elif address == 0xFF4D'u16:
        echo "write to gbc reg?"
    elif address == 0xFF50:
        bios_mapped = false
    elif address == 0xFF68'u16:
        discard
    elif address == 0xFF69'u16:
        discard
    elif address == 0xFF7F'u16:
        discard
    elif address in 0xFF80'u16 .. 0xFFFE'u16:
        let offset = address - 0xFF80'u16
        hram[offset] = value
    elif address == 0xFFFF'u16:
        #echo "set irq ie to ", int64(value).toBin(8)
        irq_ie = value and 0b11111'u8
    else:
        quit("Unhandled store8 address " & address.toHex() & " value " & value.toHex(), QuitSuccess)

proc store16*(address: uint16, value: uint16) =
    if address in 0x8000'u16 .. 0x9FFF'u16:
        let offset = address - 0x8000
        vram_store16(offset, value)
    elif address in 0xC000'u16 ..< 0xE000'u16:
        let offset = address - 0xC000'u16
        wram[offset + 0] = uint8(value shr 8) 
        wram[offset + 1] = uint8(value and 0xFF)  
    elif address in 0xFF80'u16 .. 0xFFFE'u16:
        let offset = address - 0xFF80'u16
        hram[offset + 0] = uint8(value shr 8)
        hram[offset + 1] = uint8(value and 0xFF)
    else:
        quit("Unhandled store16 address " & address.toHex() & " value " & value.toHex(), QuitSuccess)

