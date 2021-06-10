
var joyp*: uint8
var action_mode*: bool
var direction_mode*: bool
var buttons_pressed*: seq[uint8]
proc pad_store8*(value: uint8) =
    joyp = (value and 0b11110000'u8) or (joyp and 0b1111'u8)
    if (joyp and (1'u8 shl 5)) == 0:
        action_mode = true
    else:
        action_mode = false
    if (joyp and (1'u8 shl 4)) == 0:
        direction_mode = true
    else:
        direction_mode = false

proc pad_load8*(): uint8 =
    joyp = joyp or 0b1111
    for button in buttons_pressed:
        if action_mode:
            case button:
                of 4: joyp = joyp and (not (1'u8 shl 3)) # Start
                of 5: joyp = joyp and (not (1'u8 shl 2)) # Select
                of 6: joyp = joyp and (not (1'u8 shl 1)) # A
                of 7: joyp = joyp and (not (1'u8 shl 0)) # B
                else: discard
        elif direction_mode:
            case button:
                of 0: joyp = joyp and (not (1'u8 shl 2)) # Up
                of 1: joyp = joyp and (not (1'u8 shl 1)) # Left
                of 2: joyp = joyp and (not (1'u8 shl 3)) # Down
                of 3: joyp = joyp and (not (1'u8 shl 0)) # Right
                else: discard
        else: discard
    return joyp






   