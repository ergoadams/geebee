var irq_ie*: uint8
var irq_if*: uint8
var irq_ime*: bool
var first_irq_cycle*: bool
var cause*: uint8

proc check_irq*(): bool =
    if irq_ime:
        if ((irq_ie and irq_if) and 0x1F) != 0:
            cause = (irq_ie and irq_if) and 0x1F
            return true
    else:
        return false