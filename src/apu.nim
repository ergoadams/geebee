import strutils, csfml/audio

const WAVE_DUTY_TABLE = [[0, 0, 0, 0, 0, 0, 0, 1], [1, 0, 0, 0, 0, 0, 0, 1], [1, 0, 0, 0, 0, 1, 1, 1], [0, 1, 1, 1, 1, 1, 1, 0]]
const buffer_size = 1024*10

var nr52: uint8
var sound_on: bool

var ch1_sl: uint8
var ch1_wpd: uint8

var ch2_f: uint16
var ch2_sl: uint8
var ch2_wpd: uint8
var ch2_ve: uint8
var ch2_ft: uint16
var ch2_wdp: uint8
var ch2_wd_pos: uint8
var ch2_samples: array[buffer_size, int16]
var ch2_left: bool
var ch2_right: bool
var ch2_length: uint8
var ch2_use_length: bool
var ch2_sound_buffer = newSoundBuffer(ch2_samples[0].addr, buffer_size, 2, 48000)
var ch2_sound = newSound(ch2_sound_buffer)



var fs: uint32

var cycle_count: uint32

proc apu_destroy*() =
    ch2_sound.destroy()
    ch2_sound_buffer.destroy()

proc apu_store8*(address: uint16, value: uint8) =
    case address:
        of 0xFF16'u16:
            ch2_wdp = value shr 6
            ch2_length = 64 - (value and 0b111111)
        of 0xFF18'u16: ch2_f = (ch2_f and 0b11100000000) or value
        of 0xFF19'u16: 
            if (value and 0b10000000) != 0:
                ch2_ft = (2048 - ch2_f) * 4
            ch2_f = (ch2_f and 0b11111111) or uint16(value and 0b111) shl 8
            ch2_ft = (2048 - ch2_f) * 4
            ch2_use_length = (value and 0b1000000'u8) != 0
            
        of 0xFF25'u16:
            ch2_left = (value and 0b100000) != 0
            ch2_right = (value and 0b10) != 0

        of 0xFF26'u16:
            nr52 = value
            sound_on = (value and 0b10000000'u8) != 0
            if not sound_on:
                ch2_left = false
                ch2_right = false
                nr52 = 0
                ch2_f = 0
                ch2_sl = 0
                ch2_wpd = 0
                ch2_ve = 0
                ch2_ft = 0
                ch2_wdp = 0
                ch2_wd_pos = 0
                for i in 0 ..< buffer_size:
                    ch2_samples[i] = 0
                ch2_length = 0
                ch2_use_length = false
        else:
            echo "Unhandled APU store8 address ", address.toHex(), " value ", value.toHex()

proc apu_load8*(address: uint16): uint8 =
    echo "Unhandled APU load8 address ", address.toHex()


proc apu_tick*() =
    if sound_on:
        for i in 0 ..< 4:
            if (cycle_count mod 87) == 0:
                if WAVE_DUTY_TABLE[ch2_wdp][ch2_wd_pos] == 0:
                    if ch2_left:
                        ch2_samples[(cycle_count div 87)*2] = -1000'i16
                    else:
                        ch2_samples[(cycle_count div 87)*2] = 0'i16
                    if ch2_right:
                        ch2_samples[(cycle_count div 87)*2 + 1] = -1000'i16
                    else:
                        ch2_samples[(cycle_count div 87)*2 + 1] = 0'i16
                else:
                    if ch2_left:
                        ch2_samples[(cycle_count div 87)*2] = 1000'i16
                    else:
                        ch2_samples[(cycle_count div 87)*2] = 0'i16
                    if ch2_right:
                        ch2_samples[(cycle_count div 87)*2 + 1] = 1000'i16
                    else:
                        ch2_samples[(cycle_count div 87)*2 + 1] = 0'i16
                    
            if cycle_count == ((buffer_size div 2)*87 - 1):
                ch2_sound_buffer = newSoundBuffer(ch2_samples[0].addr, buffer_size, 2, 48000)
                ch2_sound.buffer = ch2_sound_buffer
                ch2_sound.play()
                #for i in 0 ..< buffer_size:
                #    ch2_samples[i] = 0'i16
                cycle_count = 0

            if (cycle_count mod 8192) == 0:
                fs += 1
                if fs mod 2 == 0:
                    if ch2_use_length:
                        ch2_length -= 1
                        if ch2_length == 0:
                            ch2_left = false
                            ch2_right = false
                            ch2_use_length = false

            cycle_count += 1


            ch2_ft -= 1
            if ch2_ft == 0:
                ch2_ft = (2048 - ch2_f) * 4
                ch2_wd_pos = (ch2_wd_pos + 1) mod 8
    