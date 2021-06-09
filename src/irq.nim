import strutils
var irq_ie*: uint8
var irq_if*: uint8
var irq_ime*: bool
var cause*: uint8

proc check_irq*(): bool =
    if irq_ime:
        if (irq_ie and irq_if) != 0:
            cause = irq_ie and irq_if
            irq_if = irq_if and (not (irq_ie and irq_if))
            return true
    else:
        return false