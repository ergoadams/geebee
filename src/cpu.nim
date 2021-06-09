import strutils
import bus, irq, timer

var pc: uint16
var sp: uint16
var opcode: uint8
var regs: array[8, uint8] # B, C, D, E, H, L, (HL), A
var flag_z: bool
var flag_n: bool
var flag_hc: bool
var flag_c: bool

var debug: bool
var trace = false
var trace_file: File
if trace:
    trace_file = open("trace.txt", fmWrite)

let INSTRUCTION_CYCLES = [
    #0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
    4,  12,  8,  8,  4,  4,  8,  4, 20,  8,  8,  8,  4,  4,  8,  4, #0
    4,  12,  8,  8,  4,  4,  8,  4, 12,  8,  8,  8,  4,  4,  8,  4, #1
    8,  12,  8,  8,  4,  4,  8,  4,  8,  8,  8,  8,  4,  4,  8,  4, #2
    8,  12,  8,  8, 12, 12, 12,  4,  8,  8,  8,  8,  4,  4,  8,  4, #3 
    4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4, #4
    4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4, #5
    4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4, #6
    8,  8,  8,  8,  8,  8,  4,  8,  4,  4,  4,  4,  4,  4,  8,  4, #7
    4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4, #8
    4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4, #9
    4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4, #A
    4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4, #B
    8,  12, 12, 16, 12, 16, 8, 16,  8, 16,  12,  0,  12,  24,  8, 16, #C
    8,  12, 12, 0, 12, 16, 8, 16,  8, 16,  12,  0,  12, 0,  8, 16, #D
    12, 12,  8, 0, 0, 16, 8, 16, 16,  4, 16, 0, 0, 0,  8, 16, #E
    12, 12,  8, 4, 0, 16, 8, 16, 12,  8, 16, 4, 0, 0,  8, 16  #F
]

let CB_INSTRUCTION_CYCLES = [
    #0 1 2 3 4 5  6 7 8 9 A B C D  E  F
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #0
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #1
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #2
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #3                                    
    8,8,8,8,8,8,12,8,8,8,8,8,8,8,12,8, #4
    8,8,8,8,8,8,12,8,8,8,8,8,8,8,12,8, #5
    8,8,8,8,8,8,12,8,8,8,8,8,8,8,12,8, #6
    8,8,8,8,8,8,12,8,8,8,8,8,8,8,12,8, #7                                               
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #8
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #9
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #A
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #B                                               
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #C
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #D
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8, #E
    8,8,8,8,8,8,16,8,8,8,8,8,8,8,16,8  #F
]

var remaining_cycles: int

var halted: bool

proc fetch_opcode(pc: uint16): uint8 =
    let value = load8(pc)
    if trace:
        trace_file.writeLine("PC " & pc.toHex() & " opcode " & value.toHex() & " regs " & $regs)
    if debug:
        echo "PC " & pc.toHex() & " opcode " & value.toHex() & " regs " & $regs
    return value

proc get_reg(index: uint8): uint8 =
    if index == 6:
        return load8((uint16(regs[4]) shl 8) or uint16(regs[5]))
    else:
        return regs[index]

proc get_hl(): uint16 =
    return (uint16(regs[4]) shl 8) or uint16(regs[5])

proc op_ld_r8u8() =
    let value = load8(pc)
    pc += 1
    let reg = (opcode shr 3) and 7
    if reg == 6:
        store8(get_hl(), value)
    else:
        regs[reg] = value

proc op_ld_r16u16() =
    let value = load16(pc)
    pc += 2
    case (opcode shr 4) and 3:
        of 0:
            regs[0] = uint8(value shr 8)
            regs[1] = uint8(value and 0xFF)
        of 1:
            regs[2] = uint8(value shr 8)
            regs[3] = uint8(value and 0xFF)
        of 2:
            regs[4] = uint8(value shr 8)
            regs[5] = uint8(value and 0xFF)
        else: sp = value

proc op_ld_r8r8() =
    let dest = (opcode shr 3) and 7
    let source = opcode and 7
    if dest == 6:
        store8(get_hl(), get_reg(source))
    else:
        regs[dest] = get_reg(source)

proc op_ld_ffc_a() =
    let address = 0xFF00'u16 + regs[1]
    store8(address, regs[7])

proc op_ld_ffu8_a() =
    let address = 0xFF00'u16 + uint16(load8(pc))
    pc += 1
    store8(address, regs[7])

proc op_ld_addr_a() =
    var address: uint16
    case (opcode shr 4) and 3:
        of 0: 
            address = (uint16(regs[0]) shl 8) or uint16(regs[1])
        of 1: 
            address = (uint16(regs[2]) shl 8) or uint16(regs[3])
        of 2: 
            var temp = (uint16(regs[4]) shl 8) or uint16(regs[5])
            address = temp
            temp += 1
            regs[4] = uint8(temp shr 8)
            regs[5] = uint8(temp and 0xFF)
        else: 
            var temp = (uint16(regs[4]) shl 8) or uint16(regs[5])
            address = temp
            temp -= 1
            regs[4] = uint8(temp shr 8)
            regs[5] = uint8(temp and 0xFF)
    store8(address, regs[7])

proc op_ld_a_addr() =
    var address: uint16
    case (opcode shr 4) and 3:
        of 0: 
            address = (uint16(regs[0]) shl 8) or uint16(regs[1])
        of 1: 
            address = (uint16(regs[2]) shl 8) or uint16(regs[3])
        of 2: 
            var temp = (uint16(regs[4]) shl 8) or uint16(regs[5])
            address = temp
            temp += 1
            regs[4] = uint8(temp shr 8)
            regs[5] = uint8(temp and 0xFF)
        else: 
            var temp = (uint16(regs[4]) shl 8) or uint16(regs[5])
            address = temp
            temp -= 1
            regs[4] = uint8(temp shr 8)
            regs[5] = uint8(temp and 0xFF)
    regs[7] = load8(address)

proc op_xor_a_r8() =
    let reg = get_reg(opcode and 7)
    let value = regs[7] xor reg
    flag_n = false
    flag_hc = false
    flag_c = false
    flag_z = value == 0
    regs[7] = value

proc op_and_a_r8() =
    let reg = get_reg(opcode and 7)
    let value = regs[7] and reg
    flag_n = false
    flag_hc = true
    flag_c = false
    flag_z = value == 0
    regs[7] = value

proc op_bit() =
    let bit = (opcode shr 3) and 7
    let reg = get_reg(opcode and 7)
    flag_n = false
    flag_hc = true
    flag_z = (reg and (1'u8 shl bit)) == 0

proc op_jr_cond() =
    let offset = cast[uint16](cast[int8](load8(pc)))
    pc += 1
    var cond_ok: bool
    case (opcode shr 3) and 3:
        of 0: cond_ok = not flag_z
        of 1: cond_ok = flag_z
        of 2: cond_ok = not flag_c
        else: cond_ok = flag_c
    if cond_ok:
        pc += offset

proc op_inc_r8() =
    let reg = (opcode shr 3) and 7
    var value = get_reg(reg)
    flag_hc = (value and 0b1111) == 0b1111
    value += 1
    if reg == 6:
        store8(get_hl(), value)
    else:
        regs[reg] = value
    flag_n = false
    flag_z = value == 0

proc op_call_u16() =
    let address = load16(pc)
    pc += 2
    sp -= 1
    store8(sp, uint8(pc shr 8)) 
    sp -= 1
    store8(sp, uint8(pc and 0xFF))
    pc = address

proc op_push_r16() =
    let reg = (opcode shr 4) and 3
    case reg:
        of 0:
            sp -= 1
            store8(sp, regs[0])
            sp -= 1
            store8(sp, regs[1])           
        of 1:
            sp -= 1
            store8(sp, regs[2])
            sp -= 1
            store8(sp, regs[3])        
        of 2:
            sp -= 1
            store8(sp, regs[4])
            sp -= 1
            store8(sp, regs[5])   
        else:          
            sp -= 1
            store8(sp, regs[7])
            sp -= 1
            var val = 0'u8
            if flag_z:
                val = val or (1 shl 7)
            if flag_n:
                val = val or (1 shl 6)
            if flag_hc:
                val = val or (1 shl 5)
            if flag_c:
                val = val or (1 shl 4)
            store8(sp, val)
            
proc op_rl() =
    var prev_c = 0'u8
    if flag_c:
        prev_c = 1'u8
    var reg = get_reg(opcode and 7)
    flag_c = (reg and 0x80) != 0
    let value = (reg shl 1) or prev_c
    if (opcode and 7) == 6:
        store8(get_hl(), value)
    else:
        regs[opcode and 7] = value
    flag_z = value == 0
    flag_n = false
    flag_hc = false

proc op_rla() =
    var prev_c = 0'u8
    if flag_c:
        prev_c = 1'u8
    flag_c = (regs[7] and 0x80) != 0
    let value = (regs[7] shl 1) or prev_c
    regs[7] = value
    flag_z = false
    flag_n = false
    flag_hc = false

proc op_pop() =
    let reg = (opcode shr 4) and 3
    case reg:
        of 0:
            regs[1] = load8(sp)
            sp += 1
            regs[0] = load8(sp)
            sp += 1
        of 1:
            regs[3] = load8(sp)
            sp += 1
            regs[2] = load8(sp)
            sp += 1
        of 2:
            regs[5] = load8(sp)
            sp += 1
            regs[4] = load8(sp)
            sp += 1
        else:
            var val = load8(sp)
            flag_z = (val and (1 shl 7)) != 0
            flag_n = (val and (1 shl 6)) != 0
            flag_hc = (val and (1 shl 5)) != 0
            flag_c = (val and (1 shl 4)) != 0   
            sp += 1
            regs[7] = load8(sp)
            sp += 1

proc op_dec_r8() =
    let reg = opcode shr 3
    var temp = get_reg(reg)
    flag_n = true
    flag_hc = (temp and 0xF) == 0
    temp -= 1
    if reg == 6:
        store8(get_hl(), temp)
    else:
        regs[reg] = temp
    flag_z = temp == 0

proc op_inc_r16() =
    var temp: uint16
    let reg = opcode shr 4
    case reg:
        of 0:
            temp = (uint16(regs[0]) shl 8) or uint16(regs[1])
            temp += 1
            regs[0] = uint8(temp shr 8)
            regs[1] = uint8(temp and 0xFF)
        of 1:
            temp = (uint16(regs[2]) shl 8) or uint16(regs[3])
            temp += 1
            regs[2] = uint8(temp shr 8)
            regs[3] = uint8(temp and 0xFF)
        of 2:
            temp = (uint16(regs[4]) shl 8) or uint16(regs[5])
            temp += 1
            regs[4] = uint8(temp shr 8)
            regs[5] = uint8(temp and 0xFF)
        else: sp += 1

proc op_dec_r16() =
    var temp: uint16
    let reg = opcode shr 4
    case reg:
        of 0:
            temp = (uint16(regs[0]) shl 8) or uint16(regs[1])
            temp -= 1
            regs[0] = uint8(temp shr 8)
            regs[1] = uint8(temp and 0xFF)
        of 1:
            temp = (uint16(regs[2]) shl 8) or uint16(regs[3])
            temp -= 1
            regs[2] = uint8(temp shr 8)
            regs[3] = uint8(temp and 0xFF)
        of 2:
            temp = (uint16(regs[4]) shl 8) or uint16(regs[5])
            temp -= 1
            regs[4] = uint8(temp shr 8)
            regs[5] = uint8(temp and 0xFF)
        else: sp -= 1

proc op_ret() =
    pc = 0
    pc = uint16(load8(sp))
    sp += 1
    pc = pc or (uint16(load8(sp)) shl 8)
    sp += 1

proc op_reti() =
    pc = 0
    pc = uint16(load8(sp))
    sp += 1
    pc = pc or (uint16(load8(sp)) shl 8)
    sp += 1
    irq_ime = true
    echo "enabled interrupts on reti"

proc op_cp_a_u8() =
    let comp = load8(pc)
    pc += 1
    let value = regs[7] - comp
    flag_z = value == 0
    flag_n = true
    flag_hc = (regs[7] and 0xF) < (comp and 0xF)
    flag_c = comp > regs[7]

proc op_ld_addru16_a() =
    let address = load16(pc)
    pc += 2
    store8(address, regs[7])

proc op_jr() =
    let offset = cast[uint16](cast[int8](load8(pc)))
    pc += 1
    pc += offset

proc op_ld_a_ffu8() =
    let offset = load8(pc)
    pc += 1
    regs[7] = load8(0xFF00'u16 + offset)

proc op_sub_a_r8() =
    let reg = opcode and 7
    let temp = get_reg(reg)
    let value = regs[7] - temp
    flag_n = true
    flag_hc = (regs[7] and 0xF) < (temp and 0xF)
    flag_z = value == 0
    flag_c = temp > regs[7]
    regs[7] = value

proc op_sbc_a_r8() =
    let value = get_reg(opcode and 7)
    var c = 0'u8
    if flag_c:
        c = 1'u8
    let final = regs[7] - value - c
    pc += 1
    flag_z = final == 0
    flag_n = true
    flag_c = (uint16(value) + c) > regs[7]
    flag_hc = (regs[7] and 0xF) < ((value and 0xF) + c)
    regs[7] = final

proc op_cp_a_r8() =
    let comp = get_reg(opcode and 7)
    let value = regs[7] - comp
    flag_z = value == 0
    flag_n = true
    flag_hc = (regs[7] and 0xF) < (comp and 0xF)
    flag_c = comp > regs[7]

proc op_add_a_r8() =
    let val1 = get_reg(opcode and 7)
    let value = regs[7] + val1
    flag_n = false
    flag_hc = ((regs[7] and 0xF) + (val1 and 0xF)) > 0xF
    flag_c = value < regs[7]
    flag_z = value == 0
    regs[7] = value

proc op_adc_a_r8() =
    let value = get_reg(opcode and 7)
    var c = 0'u8
    if flag_c:
        c = 1'u8
    var final = value + regs[7] + c
    flag_z = final == 0
    flag_n = false
    flag_c = (uint16(value) + uint16(regs[7]) + uint16(c)) > 0xFF
    flag_hc = ((regs[7] and 0xF) + (value and 0xF) + c) > 0xF
    regs[7] = final

proc op_nop() =
    discard

proc op_jp_u16() =
    let offset = load16(pc)
    pc = offset

proc op_jp_cond() =
    let offset = load16(pc)
    pc += 2
    var cond_ok: bool
    case (opcode shr 3) and 3:
        of 0: cond_ok = not flag_z
        of 1: cond_ok = flag_z
        of 2: cond_ok = not flag_c
        else: cond_ok = flag_c
    if cond_ok:
        pc = offset

proc op_di() =
    irq_ime = false

proc op_ei() =
    irq_ime = true

proc op_set() =
    let reg = opcode and 7
    let bit = (opcode shr 3) and 7
    var val = get_reg(reg) or (1'u8 shl bit)
    if reg == 6:
        store8(get_hl(), val)
    else:
        regs[reg] = val

proc op_ret_cond() =
    var cond_ok: bool
    case (opcode shr 3) and 3:
        of 0: cond_ok = not flag_z
        of 1: cond_ok = flag_z
        of 2: cond_ok = not flag_c
        else: cond_ok = flag_c
    if cond_ok:
        pc = 0
        pc = uint16(load8(sp))
        sp += 1
        pc = pc or (uint16(load8(sp)) shl 8)
        sp += 1
    
proc op_or_a_r8() =
    let reg = get_reg(opcode and 7)
    let value = regs[7] or reg
    flag_n = false
    flag_hc = false
    flag_c = false
    flag_z = value == 0
    regs[7] = value

proc op_ld_a_u16() =
    let address = load16(pc)
    pc += 2
    regs[7] = load8(address)

proc op_and_u8() =
    let reg = load8(pc)
    pc += 1
    let value = regs[7] and reg
    flag_n = false
    flag_hc = true
    flag_c = false
    flag_z = value == 0
    regs[7] = value

proc op_call_cond() =
    var cond_ok: bool
    case (opcode shr 3) and 3:
        of 0: cond_ok = not flag_z
        of 1: cond_ok = flag_z
        of 2: cond_ok = not flag_c
        else: cond_ok = flag_c
    let address = load16(pc)
    pc += 2
    if cond_ok: 
        sp -= 1
        store8(sp, uint8(pc shr 8))
        sp -= 1
        store8(sp, uint8(pc and 0xFF))
        pc = address

proc op_jp_hl() =
    pc = get_hl()

proc op_add_u8() =
    let value = load8(pc)
    let final = value + regs[7]
    pc += 1
    flag_z = final == 0
    flag_n = false
    flag_c = final < regs[7]
    flag_hc = ((regs[7] and 0xF) + (value and 0xF)) > 0xF
    regs[7] = final

proc op_adc_u8() =
    let value = load8(pc)
    pc += 1
    var c = 0'u8
    if flag_c:
        c = 1'u8
    var final = value + regs[7] + c
    flag_z = final == 0
    flag_n = false
    flag_c = (uint16(value) + uint16(regs[7]) + uint16(c)) > 0xFF
    flag_hc = ((regs[7] and 0xF) + (value and 0xF) + c) > 0xF
    regs[7] = final

proc op_sub_u8() =
    let value = load8(pc)
    let final = regs[7] - value
    pc += 1
    flag_z = final == 0
    flag_n = true
    flag_c = value > regs[7]
    flag_hc = (regs[7] and 0xF) < (value and 0xF)
    regs[7] = final

proc op_sbc_u8() =
    let value = load8(pc)
    var c = 0'u8
    if flag_c:
        c = 1'u8
    let final = regs[7] - value - c
    pc += 1
    flag_z = final == 0
    flag_n = true
    flag_c = (uint16(value) + c) > regs[7]
    flag_hc = (regs[7] and 0xF) < ((value and 0xF) + c)
    regs[7] = final

proc op_srl() =
    let reg = opcode and 7
    var value = get_reg(reg)
    flag_c = (value and 1) != 0
    value = value shr 1
    flag_z = value == 0
    flag_n = false
    flag_hc = false
    if reg == 6:
        store8(get_hl(), value)
    else:
        regs[reg] = value

proc op_rr() =
    var prev_c = 0'u8
    if flag_c:
        prev_c = 1'u8
    var reg = get_reg(opcode and 7)
    flag_c = (reg and 1) != 0
    let value = (reg shr 1) or (prev_c shl 7)
    if (opcode and 7) == 6:
        store8(get_hl(), value)
    else:
        regs[opcode and 7] = value
    flag_z = value == 0
    flag_n = false
    flag_hc = false

proc op_rra() =
    var prev_c = 0'u8
    if flag_c:
        prev_c = 1'u8
    flag_c = (regs[7] and 1) != 0
    let value = (regs[7] shr 1) or (prev_c shl 7)
    regs[7] = value
    flag_z = false
    flag_n = false
    flag_hc = false

proc op_xor_u8() =
    let reg = load8(pc)
    pc += 1
    let value = regs[7] xor reg
    flag_n = false
    flag_hc = false
    flag_c = false
    flag_z = value == 0
    regs[7] = value

proc op_or_u8() =
    let reg = load8(pc)
    pc += 1
    let value = regs[7] or reg
    flag_n = false
    flag_hc = false
    flag_c = false
    flag_z = value == 0
    regs[7] = value

proc op_rst() =
    let exp = opcode and 0b00111000
    sp -= 1
    store8(sp, uint8(pc shr 8))
    sp -= 1
    store8(sp, uint8(pc and 0xFF))
    pc = exp

proc op_add_hl_r16() =
    let initial = get_hl()
    
    let added = case (opcode shr 4) and 3:
        of 0: (uint16(regs[0]) shl 8) or uint16(regs[1])
        of 1: (uint16(regs[2]) shl 8) or uint16(regs[3])
        of 2: (uint16(regs[4]) shl 8) or uint16(regs[5])
        else: sp
    let final = initial + added
    flag_n = false
    flag_hc = ((initial and 0xfff) + (added and 0xfff)) > 0xfff
    flag_c = (uint32(initial) + uint32(added)) > 0xFFFF
    regs[4] = uint8(final shr 8)
    regs[5] = uint8(final and 0xFF)
    
proc op_swap() =
    let reg = opcode and 7
    var value = get_reg(reg)
    value = ((value and 0b1111) shl 4) or (value shr 4)
    flag_z = value == 0
    flag_n = false
    flag_hc = false
    flag_c = false
    if reg == 6:
        store8(get_hl(), value)
    else:
        regs[reg] = value
    
proc op_ld_u16_sp() =
    let address = load16(pc)
    pc += 2
    store8(address, uint8(sp and 0xFF))
    store8(address + 1, uint8(sp shr 8))

proc op_ld_sp_hl() =
    sp = get_hl()

proc op_cpl() =
    flag_n = true
    flag_hc = true
    regs[7] = not regs[7]

proc op_scf() =
    flag_n = false
    flag_hc = false
    flag_c = true

proc op_ccf() =
    flag_n = false
    flag_hc = false
    flag_c = not flag_c

proc op_rlca() =
    flag_c = (regs[7] and (1'u8 shl 7)) != 0
    regs[7] = regs[7] shl 1
    if flag_c:
        regs[7] = regs[7] or 1
    flag_z = false
    flag_n = false
    flag_hc = false

proc op_rrca() =
    flag_c = (regs[7] and 1) != 0
    regs[7] = regs[7] shr 1
    if flag_c:
        regs[7] = regs[7] or (1'u8 shl 7)
    flag_z = false
    flag_n = false
    flag_hc = false

proc op_rlc() =
    var reg = get_reg(opcode and 7)
    flag_c = (reg and (1'u8 shl 7)) != 0
    reg = reg shl 1
    if flag_c:
        reg = reg or 1
    flag_z = reg == 0
    flag_n = false
    flag_hc = false
    if (opcode and 7) == 6:
        store8(get_hl(), reg)
    else:
        regs[opcode and 7] = reg

proc op_rrc() =
    var reg = get_reg(opcode and 7)
    flag_c = (reg and 1) != 0
    reg = reg shr 1
    if flag_c:
        reg = reg or (1'u8 shl 7)
    flag_z = reg == 0
    flag_n = false
    flag_hc = false
    if (opcode and 7) == 6:
        store8(get_hl(), reg)
    else:
        regs[opcode and 7] = reg

proc op_sla() =
    var reg = get_reg(opcode and 7)
    flag_c = (reg and (1'u8 shl 7)) != 0
    reg = reg shl 1
    flag_z = reg == 0
    flag_n = false
    flag_hc = false
    if (opcode and 7) == 6:
        store8(get_hl(), reg)
    else:
        regs[opcode and 7] = reg

proc op_sra() =
    var reg = get_reg(opcode and 7)
    flag_c = (reg and 1) != 0
    let temp = reg and (1'u8 shl 7)
    reg = reg shr 1
    if temp != 0:
        reg = reg or (1'u8 shl 7)
    flag_z = reg == 0
    flag_n = false
    flag_hc = false
    if (opcode and 7) == 6:
        store8(get_hl(), reg)
    else:
        regs[opcode and 7] = reg

proc op_res() =
    let bit = (opcode shr 3) and 7
    var reg = get_reg(opcode and 7)
    reg = reg and (not (1'u8 shl bit))
    if (opcode and 7) == 6:
        store8(get_hl(), reg)
    else:
        regs[opcode and 7] = reg

proc op_daa() =
    var a = regs[7]
    if not flag_n:
        if flag_c or (a > 0x99):
            a += 0x60
            flag_c = true
        if flag_hc or ((a and 0x0F) > 0x09):
            a += 0x06
    else:
        if flag_c:
            a -= 0x60
        if flag_hc:
            a -= 0x06
    flag_z = a == 0
    flag_hc = false
    regs[7] = a

proc op_add_sp_i8() =
    let value = cast[uint16](cast[int8](load8(pc)))
    pc += 1
    let final = sp + value
    flag_c = ((sp and 0xFF) + (value and 0xFF)) > 0xFF
    flag_z = false
    flag_n = false
    flag_hc = ((sp and 0xF) + (value and 0xF)) > 0xF
    sp = final

proc op_ld_hl_spi8() =
    let value = cast[uint16](cast[int8](load8(pc)))
    pc += 1
    var hl = get_hl()
    hl = sp + value
    flag_z = false
    flag_n = false
    flag_c = ((sp and 0xFF) + (value and 0xFF)) > 0xFF
    flag_hc = ((sp and 0xF) + (value and 0xF)) > 0xF
    regs[4] = uint8(hl shr 8)
    regs[5] = uint8(hl and 0xFF)

proc op_ld_a_ffc() =
    let offset = 0xFF00'u16 + regs[1]
    regs[7] = load8(offset)

proc op_halt() =
    halted = true


proc execute_opcode() =
    if opcode == 0xCB:
        let opcode2 = fetch_opcode(pc)
        opcode = opcode2
        remaining_cycles = CB_INSTRUCTION_CYCLES[opcode]
        pc += 1
        case (opcode2 and 0b11000000) shr 6:
            of 0:
                # shift/rotate
                case (opcode2 shr 3) and 7:
                    of 0: op_rlc()
                    of 1: op_rrc()
                    of 2: op_rl()
                    of 3: op_rr()
                    of 4: op_sla()
                    of 5: op_sra()
                    of 6: op_swap()
                    of 7: op_srl()
                    else:
                        quit("Unhandled shift rotate " & $((opcode2 shr 3) and 7), QuitSuccess)
            of 1: op_bit()
            of 2: op_res()
            of 3: op_set()
            else:
                quit("Unhandled opcode prefix 0xCB " & (opcode2 and 0b11000000).toHex(), QuitSuccess)
    else:
        remaining_cycles = INSTRUCTION_CYCLES[opcode]
        if opcode == 0x00: op_nop()
        elif opcode == 0b00001000: op_ld_u16_sp()
        elif opcode == 0b00010000:
            echo "STOP"
            quit("", QuitSuccess)
        elif opcode == 0b00011000: op_jr()
        elif opcode == 0b01110110: op_halt()
        elif opcode == 0b11100000: op_ld_ffu8_a()
        elif opcode == 0b11101000: op_add_sp_i8()
        elif opcode == 0b11110000: op_ld_a_ffu8()
        elif opcode == 0b11111000: op_ld_hl_spi8()
        elif opcode == 0b11100010: op_ld_ffc_a()
        elif opcode == 0b11101010: op_ld_addru16_a()
        elif opcode == 0b11110010: op_ld_a_ffc()
        elif opcode == 0b11111010: op_ld_a_u16()
        elif opcode == 0b11001101: op_call_u16()
        else:
            # instructions with variables at bits 5-4
            case (opcode and 0b11001111):
                of 0x01: op_ld_r16u16()
                of 0x02: op_ld_addr_a()
                of 0x03: op_inc_r16()
                of 0x09: op_add_hl_r16()
                of 0x0A: op_ld_a_addr()
                of 0x0B: op_dec_r16()
                of 0xC1: op_pop()
                of 0xC5: op_push_r16()
                of 0xC9:
                    case (opcode shr 4) and 3:
                        of 0: op_ret()
                        of 1: op_reti()
                        of 2: op_jp_hl()
                        else: op_ld_sp_hl()
                else:
                    # instructions with variables at bits 4-3
                    case (opcode and 0b11100111):
                        of 0x20: op_jr_cond()
                        of 0xC0: op_ret_cond()
                        of 0xC2: op_jp_cond()
                        of 0xC4: op_call_cond()
                        else:
                            # instructions with variables at bits 5-3
                            case (opcode and 0b11000111):
                                of 0x04: op_inc_r8()
                                of 0x05: op_dec_r8()
                                of 0x06: op_ld_r8u8()
                                of 0x07:
                                    # accumulator/flag
                                    case opcode shr 3:
                                        of 0: op_rlca()
                                        of 1: op_rrca()
                                        of 2: op_rla()
                                        of 3: op_rra()
                                        of 4: op_daa()
                                        of 5: op_cpl()
                                        of 6: op_scf()
                                        of 7: op_ccf()
                                        else:
                                            quit("Unhandled group 1 " & $(opcode shr 3), QuitSuccess)
                                of 0xC3:
                                    case (opcode shr 3) and 7:
                                        of 0: op_jp_u16()
                                        of 6: op_di()
                                        of 7: op_ei()
                                        else:
                                            quit("Illegal opcode in 0xC3 " & opcode.toHex(), QuitSuccess)
                                of 0xC6:
                                    case (opcode shr 3) and 7:
                                        of 0: op_add_u8()
                                        of 1: op_adc_u8()
                                        of 2: op_sub_u8()
                                        of 3: op_sbc_u8()
                                        of 4: op_and_u8()
                                        of 5: op_xor_u8()
                                        of 6: op_or_u8()
                                        else: op_cp_a_u8()
                                of 0xC7: op_rst()
                                else:
                                    # instructions with variables at bits 5-0
                                    case opcode shr 6:
                                        of 1: op_ld_r8r8()
                                        of 2:
                                            case (opcode shr 3) and 7:
                                                of 0: op_add_a_r8()
                                                of 1: op_adc_a_r8()
                                                of 2: op_sub_a_r8()
                                                of 3: op_sbc_a_r8()
                                                of 4: op_and_a_r8()
                                                of 5: op_xor_a_r8()
                                                of 6: op_or_a_r8()
                                                else: op_cp_a_r8()
                                        else:
                                            quit("Unhandled opcode " & opcode.toHex(), QuitSuccess)

proc trigger_irq() =
    sp -= 1
    store8(sp, uint8(pc shr 8)) 
    sp -= 1
    store8(sp, uint8(pc and 0xFF))
    pc = case cause:
        of 0b00001: 0x0040'u16
        of 0b00010: 0x0048'u16
        of 0b00100: 0x0050'u16
        of 0b01000: 0x0058'u16
        of 0b10000: 0x0060'u16
        else: 
            echo "multiple irqs?"
            pc
    irq_ime = false

proc cpu_tick*() =
    if not halted:
        if remaining_cycles == 0:
            opcode = fetch_opcode(pc)
            pc += 1
            execute_opcode()
        remaining_cycles -= 1
    else:
        if not irq_ime:
            if (irq_if and irq_ie) != 0:
                halted = false
        else:
            echo "haltbug?"
    timer_tick()
    if check_irq():
        halted = false
        trigger_irq()