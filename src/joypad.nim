
var joyp: uint8

proc pad_store8*(value: uint8) =
    joyp = value

proc pad_load8*(): uint8 =
    return 0xFF'u8
   