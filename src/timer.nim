import strutils
import irq

var timer_div: uint8
var timer_tima: uint8
var timer_mod: uint8
var timer_tac: uint8

var timer_en: bool

var ticks_div: uint16

var diver: uint16
var prev_edge: bool

proc timer_store8*(address: uint16, value: uint8) =
    case address:
        of 0: timer_div = 0
        of 1: timer_tima = value
        of 2: timer_mod = value
        of 3: 
            timer_en = (value and 0b100) != 0
            diver = case value and 3:
                of 0: 1'u16 shl 9
                of 1: 1'u16 shl 3
                of 2: 1'u16 shl 5
                else: 1'u16 shl 7
            timer_tac = value
        else:
            echo "Unhandled timer store8 addr " & address.toHex() & " value " & value.toHex()

proc timer_tick*() =
    ticks_div += 1

    let div_bool = ((ticks_div and diver) != 0) and timer_en
    if prev_edge and (not div_bool):
        if timer_tima == 0xFF:
            timer_tima = timer_mod
            irq_if = irq_if or 0b00100
        timer_tima += 1       
    prev_edge = div_bool 
            
            

        