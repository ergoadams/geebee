import strutils, csfml, times, os, algorithm
import irq, joypad
var vram: array[0x2000, uint8]

var lcdc: uint8
var lcd_en: bool
var window_map_area: uint8 # false=9800-9BFF, true=9C00-9FFF
var window_en: bool
var bg_data_area: bool # false=8800-97FF, true=8000-8FFF
var bg_map_area: uint8 #  0=9800-9BFF, 1=9C00-9FFF
var obj_size: bool #     false=8x8, true=8x16
var obj_en: bool
var bg_win_en: bool

var lcd_stat: uint8

var dot: uint32
var scanline: uint8
var mode*: uint8
var lyc_irq_en: bool
var mode2_irq_en: bool
var mode1_irq_en: bool
var mode0_irq_en: bool

var wy: uint8
var wx: uint8
var window_line: uint8
var lyc: uint8
var scy: uint8
var scx: uint8
var bgp: uint8
var color_index0: uint8 = 0
var color_index1: uint8 = 1
var color_index2: uint8 = 2
var color_index3: uint8 = 3
var color_index1_obp0: uint8 = 1
var color_index2_obp0: uint8 = 2
var color_index3_obp0: uint8 = 3
var color_index1_obp1: uint8 = 1
var color_index2_obp1: uint8 = 2
var color_index3_obp1: uint8 = 3
let color_palette: array[4, array[4, uint8]] = [[247'u8, 190'u8, 247'u8, 255'u8], [231'u8, 134'u8, 134'u8, 255'u8], [119'u8, 51'u8, 231'u8, 255'u8], [44'u8, 44'u8, 150'u8, 255'u8]] # Colors from lightest to darkest
var tiles: array[384, array[8, array[8, uint8]]]
var tile_maps: array[2, array[32, array[32, uint8]]]
var obp0: uint8
var obp1: uint8
var sprite_attribute: array[40, array[4, uint8]]
# CSFML init
var screenWidth: cint = 160
var screenHeight: cint = 144
let scale_factor: cint = 3
let videoMode = videoMode(screenWidth*scale_factor, screenHeight*scale_factor)
let settings = contextSettings(depth=32, antialiasing=8)
var window* = newRenderWindow(videoMode, "Geebee", settings=settings)
let bg_clear_col = color(color_palette[0][0], color_palette[0][1], color_palette[0][2])

var frametime: float = cpuTime()

window.clear bg_clear_col
window.display()

var screen_buffer: array[160*144*4, uint8]
var screen_texture = newTexture(cint(160), cint(144))
var screen_sprite = newSprite(screen_texture)
screen_sprite.scale = vec2(scale_factor, scale_factor)

proc vram_load8*(address: uint16): uint8 =
    return vram[address]

proc vram_store8*(address: uint16, value: uint8) =
    vram[address] = value
    if address in 0x0000'u16 ..< 0x1800'u16:
        # Tile data
        var tile_index: uint16
        tile_index = address shr 4
        var tile = tiles[tile_index]
        let tile_line_index = (address - (tile_index shl 4)) shr 1
        var tile_line = tile[tile_line_index]
        for i in 0 .. 7:
            if (address and 1) != 0:
                tile_line[i] = tile_line[i] or (((value and (1'u8 shl (7 - i))) shr (7 - i)) shl 1)
            else:
                tile_line[i] = (value and (1'u8 shl (7 - i))) shr (7 - i)
        tiles[tile_index][tile_line_index] = tile_line
    else:
        # Tile maps
        var tile_map_index = 0'u8
        if address >= 0x1C00'u16:
            tile_map_index = 1'u8
        var offset = address - 0x1800'u16
        if tile_map_index == 1:
            offset -= 0x400
        let tile_index = offset shr 5
        tile_maps[tile_map_index][tile_index][offset - (tile_index shl 5)] = value

proc vram_store16*(address: uint16, value: uint16) =
    vram[address + 0] = uint8(value shr 8)
    vram[address + 1] = uint8(value and 0xFF)

proc ppu_store8*(address: uint16, value: uint8) =
    case address:
        of 0x00: 
            lcdc = value
            lcd_en = (value and (1'u8 shl 7)) != 0
            window_map_area = (value and (1'u8 shl 6)) shr 6 
            window_en = (value and (1'u8 shl 5)) != 0
            bg_data_area = (value and (1'u8 shl 4)) != 0
            bg_map_area = (value and (1'u8 shl 3)) shr 3
            obj_size = (value and (1'u8 shl 2)) != 0 # TODO: fix pls
            obj_en = (value and (1'u8 shl 1)) != 0
            bg_win_en = (value and 1) != 0
        of 0x01:
            lcd_stat = (value and 0b1111000) or (lcd_stat and 0b111)
            lyc_irq_en = (value and (1'u8 shl 6)) != 0
            mode2_irq_en = (value and (1'u8 shl 5)) != 0
            mode1_irq_en = (value and (1'u8 shl 4)) != 0
            mode0_irq_en = (value and (1'u8 shl 3)) != 0
        of 0x02: 
            scy = value
        of 0x03:
            scx = value
        of 0x05:
            lyc = value
        of 0x07: 
            bgp = value
            color_index0 = (value and (0b11'u8 shl 0)) shr 0
            color_index1 = (value and (0b11'u8 shl 2)) shr 2
            color_index2 = (value and (0b11'u8 shl 4)) shr 4
            color_index3 = (value and (0b11'u8 shl 6)) shr 6
        of 0x08:
            obp0 = value and (not 0b11'u8)
            color_index1_obp0 = (value and (0b11'u8 shl 2)) shr 2
            color_index2_obp0 = (value and (0b11'u8 shl 4)) shr 4
            color_index3_obp0 = (value and (0b11'u8 shl 6)) shr 6
        of 0x09:
            obp1 = value and (not 0b11'u8)
            color_index1_obp1 = (value and (0b11'u8 shl 2)) shr 2
            color_index2_obp1 = (value and (0b11'u8 shl 4)) shr 4
            color_index3_obp1 = (value and (0b11'u8 shl 6)) shr 6
        of 0x0A:
            wy = value
        of 0x0B:
            wx = value
        else:
            echo "Unhandled ppu store8 addr " & address.toHex() & " value " & value.toHex() 

proc ppu_load8*(address: uint16): uint8 =
    case address:
        of 0x00: return lcdc
        of 0x01: return lcd_stat
        of 0x02: return scy
        of 0x03: return scx
        of 0x04: return scanline
        of 0x05: return lyc
        of 0x07: return bgp
        of 0x0A: return wy
        else: 
            echo "Unhandled ppu load8 address " & address.toHex()
            return 0xFF

proc oam_write*(address: uint16, value: uint8) =
    sprite_attribute[address shr 2][address - ((address shr 2) shl 2)] = value

proc oam_load*(address: uint16): uint8 =
    return sprite_attribute[address shr 2][address - ((address shr 2) shl 2)]

proc draw_scanline() =
    # Background rendering
    if bg_win_en:
        let tile_y = ((scanline + scy) and 0xFF) shr 3 # Each tile is 8 pixels high
        let tile_map_line = tile_maps[bg_map_area][tile_y]
        let y_in_tile = ((scanline + scy) and 0xFF) - (tile_y shl 3)
        var x_pos: int32 = 0 - int32(scx mod 8)
        var top_limit = 20'u32
        if scx != 0:
            top_limit = 21'u32
        for i in 0 ..< top_limit:
            let tile_index = tile_map_line[(i + (uint32(scx) shr 3)) and 0x1F]
            var tile_line: array[8, uint8]
            if bg_data_area:
                # 8000-8FFF
                tile_line = tiles[tile_index][y_in_tile]
            else:
                # 8800-97FF
                var temp_index = uint16(tile_index)
                if temp_index < 128:
                    temp_index += 256
                tile_line = tiles[temp_index][y_in_tile]
            for pixel in tile_line:
                if (x_pos >= 0) and (x_pos < 160):
                    let color = case pixel:
                        of 0: color_palette[color_index0]
                        of 1: color_palette[color_index1]
                        of 2: color_palette[color_index2]
                        else: color_palette[color_index3]
                    screen_buffer[uint32(scanline)*160*4 + uint32(x_pos)*4 + 0] = color[0]
                    screen_buffer[uint32(scanline)*160*4 + uint32(x_pos)*4 + 1] = color[1]
                    screen_buffer[uint32(scanline)*160*4 + uint32(x_pos)*4 + 2] = color[2]
                    screen_buffer[uint32(scanline)*160*4 + uint32(x_pos)*4 + 3] = 255
                x_pos += 1

    # Window rendering
    if window_en and (wy in 0'u8 .. 166'u8) and (wx in 0'u8 .. 143'u8) and (scanline >= wy):
        let window_tile_y = window_line shr 3
        let y_in_tile = window_line - (window_tile_y shl 3)
        let tile_map_line = tile_maps[window_map_area][window_tile_y]
        #echo scanline, " ", window_tile_y, " ", y_in_tile
        var x_pos = int16(wx) - 7
        for i in 0'u8 ..< 21'u8:
            let tile_index = tile_map_line[i]
            var tile_line: array[8, uint8]
            if bg_data_area:
                # 8000-8FFF
                tile_line = tiles[tile_index][y_in_tile]
            else:
                # 8800-97FF
                var temp_index = uint16(tile_index)
                if temp_index < 128:
                    temp_index += 256
                tile_line = tiles[temp_index][y_in_tile]

            for pixel in tile_line:
                if (x_pos >= 0) and (x_pos < 160):
                    let color = case pixel:
                        of 0: color_palette[color_index0]
                        of 1: color_palette[color_index1]
                        of 2: color_palette[color_index2]
                        else: color_palette[color_index3]
                    screen_buffer[uint32(scanline)*160*4 + uint32(x_pos)*4 + 0] = color[0]
                    screen_buffer[uint32(scanline)*160*4 + uint32(x_pos)*4 + 1] = color[1]
                    screen_buffer[uint32(scanline)*160*4 + uint32(x_pos)*4 + 2] = color[2]
                    screen_buffer[uint32(scanline)*160*4 + uint32(x_pos)*4 + 3] = 255
                x_pos += 1
        window_line += 1

    # Objects rendering
    if obj_en:
        var possible_sprites: seq[array[4, uint8]]
        var sprite_count: uint8
        if obj_size:
            for sprite in sprite_attribute:
                if int16(scanline) in (int16(sprite[0]) - 16) ..< (int16(sprite[0])):
                    possible_sprites.add(sprite)
                    sprite_count += 1
                    if sprite_count == 10:
                        break
        else:
            for sprite in sprite_attribute:
                if int16(scanline) in (int16(sprite[0]) - 16) ..< (int16(sprite[0]) - 8):
                    possible_sprites.add(sprite)
                    sprite_count += 1
                    if sprite_count == 10:
                        break
        
        # Reverse the possible sprites, cause earlier in OAM has priority
        possible_sprites = possible_sprites.reversed()
        for x_pos in countdown(167'u32, 1'u32):
            for sprite in possible_sprites:
                if x_pos == sprite[1]:
                    let attributes = sprite[3]
                    let priority = (attributes and (1'u8 shl 7)) == 0
                    let y_flip = (attributes and (1'u8 shl 6)) != 0
                    let x_flip = (attributes and (1'u8 shl 5)) != 0
                    let palette1 = (attributes and (1'u8 shl 4)) != 0
                    var color_1 = color_index1_obp0
                    var color_2 = color_index2_obp0
                    var color_3 = color_index3_obp0
                    if palette1:
                        color_1 = color_index1_obp1
                        color_2 = color_index2_obp1
                        color_3 = color_index3_obp1
                    let tile_y = if y_flip:
                        if obj_size:
                            15 - (scanline - (sprite[0] - 16))
                        else:
                            7 - (scanline - (sprite[0] - 16))
                        else:
                            scanline - (sprite[0] - 16)

                    let tileindex = if obj_size:
                        sprite[2] and 0xFE'u8
                        else:
                            sprite[2]
                        
                    let tile = if tile_y >= 8:
                        tiles[tileindex + 1]
                        else:
                            tiles[tileindex]
                    let tile_line = tile[tile_y and 7]
                    var line_x = int16(sprite[1]) - 8
                    for i in 0 .. 7:
                        if line_x >= 0 and line_x < 160:
                            let pixel = if x_flip:
                                tile_line[7 - i]
                                else:
                                    tile_line[i]
                            
                            if priority or ((not priority) and (screen_buffer[uint32(scanline)*160*4 + uint32(line_x)*4 + 0] == color_palette[color_index0][0])):
                                    if pixel != 0:
                                        let color = case pixel:
                                            of 1: color_palette[color_1]
                                            of 2: color_palette[color_2]
                                            else: color_palette[color_3]
                                        screen_buffer[uint32(scanline)*160*4 + uint32(line_x)*4 + 0] = color[0]
                                        screen_buffer[uint32(scanline)*160*4 + uint32(line_x)*4 + 1] = color[1]
                                        screen_buffer[uint32(scanline)*160*4 + uint32(line_x)*4 + 2] = color[2]
                                        screen_buffer[uint32(scanline)*160*4 + uint32(line_x)*4 + 3] = color[3]
                        line_x += 1

proc display_frame() =     
    updateFromPixels(screen_texture, screen_buffer[0].addr, cint(160), cint(144), cint(0), cint(0))
    window.clear bg_clear_col
    window.draw(screen_sprite)
    window.display()
    # Delay to keep constant 60FPS
    let cur_time = cpuTime()
    let difference = int((0.015 - (cur_time - frametime))*1000)
    if difference > 0:
        sleep(difference)
    frametime = cur_time

proc parse_events*() =
    var event: Event
    while window.pollEvent(event):
        case event.kind:
            of EventType.Closed:
                window.close()
                screen_texture.destroy()
                screen_sprite.destroy()
                quit()
            of EventType.KeyPressed:
                case event.key.code:
                    of KeyCode.W: buttons_pressed = buttons_pressed or (1'u8 shl 0) # Up
                    of KeyCode.A: buttons_pressed = buttons_pressed or (1'u8 shl 1) # Left
                    of KeyCode.S: buttons_pressed = buttons_pressed or (1'u8 shl 2) # Down
                    of KeyCode.D: buttons_pressed = buttons_pressed or (1'u8 shl 3) # Right
                    of KeyCode.U: buttons_pressed = buttons_pressed or (1'u8 shl 4) # Start
                    of KeyCode.I: buttons_pressed = buttons_pressed or (1'u8 shl 5) # Select
                    of KeyCode.J: buttons_pressed = buttons_pressed or (1'u8 shl 6) # A
                    of KeyCode.K: buttons_pressed = buttons_pressed or (1'u8 shl 7) # B
                    else: discard
            of EventType.KeyReleased:
                case event.key.code:
                    of KeyCode.W: buttons_pressed = buttons_pressed and (not (1'u8 shl 0)) # Up
                    of KeyCode.A: buttons_pressed = buttons_pressed and (not (1'u8 shl 1)) # Left
                    of KeyCode.S: buttons_pressed = buttons_pressed and (not (1'u8 shl 2)) # Down
                    of KeyCode.D: buttons_pressed = buttons_pressed and (not (1'u8 shl 3)) # Right
                    of KeyCode.U: buttons_pressed = buttons_pressed and (not (1'u8 shl 4)) # Start
                    of KeyCode.I: buttons_pressed = buttons_pressed and (not (1'u8 shl 5)) # Select
                    of KeyCode.J: buttons_pressed = buttons_pressed and (not (1'u8 shl 6)) # A
                    of KeyCode.K: buttons_pressed = buttons_pressed and (not (1'u8 shl 7)) # B
                    else: discard
            else: discard
    

proc trigger_stat() =
    irq_if = irq_if or 0b10'u8

proc trigger_vblank() =
    irq_if = irq_if or 0b1'u8

proc ppu_tick*() =
    if lcd_en:   
        dot += 4
        if scanline < 144:
            if dot == 4:
                mode = 2
                lcd_stat = (lcd_stat and 0b1111100) or 2
                if mode2_irq_en:
                    trigger_stat()
            elif dot == 80:
                mode = 3
                lcd_stat = (lcd_stat and 0b1111100) or 3
            elif dot == 312:
                mode = 0
                lcd_stat = (lcd_stat and 0b1111100) or 0
                draw_scanline()
                if mode0_irq_en:
                    trigger_stat()
            elif dot >= 460:
                dot = 0
                scanline += 1
        else:
            if (scanline == 144) and (dot == 4):
                mode = 1
                lcd_stat = (lcd_stat and 0b1111100) or 1
                trigger_vblank()
                display_frame()
                if mode1_irq_en:
                    trigger_stat()

            if dot == 456:
                dot = 0
                scanline += 1
                if scanline == 154:
                    scanline = 0
                    window_line = 0
        if lyc == scanline:
            lcd_stat = lcd_stat or 0b100
            if lyc_irq_en and (dot == 4):
                trigger_stat()
        else:
            lcd_stat = lcd_stat and (not 0b100'u8)

    else:
        dot = 0
        scanline = 0
        window_line = 0
        mode = 0
        lcd_stat = (lcd_stat and 0b1111100) or 0

        