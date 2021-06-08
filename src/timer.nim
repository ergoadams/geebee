import strutils

proc timer_store8*(address: uint16, value: uint8) =
    #echo "Unhandled timer store8 addr " & address.toHex() & " value " & value.toHex()
    discard