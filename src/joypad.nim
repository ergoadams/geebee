
var joyp*: uint8
var action_mode*: bool
var direction_mode*: bool
var buttons_pressed*: uint8
proc pad_store8*(value: uint8) =
    joyp = (value and 0b11110000'u8) or (joyp and 0b1111'u8)
    action_mode = (joyp and (1'u8 shl 5)) == 0
    direction_mode = (joyp and (1'u8 shl 4)) == 0

proc pad_load8*(): uint8 =
    joyp = joyp or 0b1111
    if direction_mode:
        if (buttons_pressed and (1'u8 shl 0)) != 0: joyp = joyp and (not (1'u8 shl 2)) # Up
        if (buttons_pressed and (1'u8 shl 1)) != 0: joyp = joyp and (not (1'u8 shl 1)) # Left
        if (buttons_pressed and (1'u8 shl 2)) != 0: joyp = joyp and (not (1'u8 shl 3)) # Down
        if (buttons_pressed and (1'u8 shl 3)) != 0: joyp = joyp and (not (1'u8 shl 0)) # Right
    elif action_mode:
        if (buttons_pressed and (1'u8 shl 4)) != 0: joyp = joyp and (not (1'u8 shl 3)) # Start
        if (buttons_pressed and (1'u8 shl 5)) != 0: joyp = joyp and (not (1'u8 shl 2)) # Select
        if (buttons_pressed and (1'u8 shl 6)) != 0: joyp = joyp and (not (1'u8 shl 1)) # A
        if (buttons_pressed and (1'u8 shl 7)) != 0: joyp = joyp and (not (1'u8 shl 0)) # B
    return joyp






   