import strutils, csfml/audio

const WAVE_DUTY_TABLE: array[4, array[8, int16]] = [[-1'i16, -1, -1, -1, -1, -1, -1, 1], [1'i16, -1, -1, -1, -1, -1, -1, 1], [-1'i16, -1, -1, -1, -1, 1, 1, 1], [-1'i16, 1, 1, 1, 1, 1, 1, -1]]
const buffer_size = 1024*10

var nr52: uint8
var sound_on: bool

var ch2_f: uint16
var ch2_timer: uint16
var ch2_duty: uint8
var ch2_duty_index: uint8
var ch2_length: uint8

var ch2_sample_rate: uint8 = 88'u8
var ch2_samples: array[buffer_size, int16]
var ch2_sound_buffer = newSoundBuffer(ch2_samples[0].addr, buffer_size, 2, 48000)
var ch2_sound = newSound(ch2_sound_buffer)
var ch2_sample_pos: uint16
var ch2_volume: int16 = 200

var cycle_count: uint32

proc apu_destroy*() =
    ch2_sound.destroy()
    ch2_sound_buffer.destroy()

proc reload_timer(index: uint8): uint16 =
    case index:
        of 2: return uint16(2048 - ch2_f) * 4
        else: echo "Unhandled timer reload index ", index

proc apu_store8*(address: uint16, value: uint8) =
    case address:
        of 0xFF16'u16:
            ch2_duty = value shr 6
            ch2_length = 64 - (value and 0b111111)
        of 0xFF18'u16: ch2_f = (ch2_f and 0b11100000000) or value
        of 0xFF19'u16: 
            ch2_f = (ch2_f and 0b11111111) or (uint16(value and 0b111) shl 8)
            if (value and 0b10000000) != 0:
                ch2_timer = reload_timer(2)
            
        of 0xFF25'u16: discard
            #ch2_left = (value and 0b100000) != 0
            #ch2_right = (value and 0b10) != 0

        of 0xFF26'u16:
            nr52 = value
            sound_on = (value and 0b10000000'u8) != 0
        else:
            echo "Unhandled APU store8 address ", address.toHex(), " value ", value.toHex()

proc apu_load8*(address: uint16): uint8 =
    echo "Unhandled APU load8 address ", address.toHex()
    return 0xFF'u8


proc ch2_sample() =
    ch2_samples[ch2_sample_pos + 0] = WAVE_DUTY_TABLE[ch2_duty][ch2_duty_index]*ch2_volume
    ch2_samples[ch2_sample_pos + 1] = WAVE_DUTY_TABLE[ch2_duty][ch2_duty_index]*ch2_volume
    ch2_sample_pos += 2
    if ch2_sample_pos == buffer_size:
        ch2_sample_pos = 0
        ch2_sound_buffer = newSoundBuffer(ch2_samples[0].addr, buffer_size, 2, 48000)
        ch2_sound.buffer = ch2_sound_buffer
        ch2_sound.play()

proc apu_tick*() =
    if sound_on:
        ch2_timer -= 1
        if ch2_timer == 0:
           ch2_duty_index = (ch2_duty_index + 1) and 0x7'u8
           ch2_timer += reload_timer(2)

        ch2_sample_rate -= 1
        if ch2_sample_rate == 0:
            ch2_sample()
            ch2_sample_rate += 88'u8

       


    