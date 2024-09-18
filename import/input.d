module input;

import core.sys.posix.sys.time;

struct input_event
{
    timeval time;
    ushort type;
    ushort code;
    int value;
}
struct input_id
{
    ushort bustype;
    ushort vendor;
    ushort product;
    ushort version_;
}
struct input_absinfo
{
    int value;
    int minimum;
    int maximum;
    int fuzz;
    int flat;
    int resolution;
}
struct input_keymap_entry
{

    ubyte flags;
    ubyte len;
    ushort index;
    uint keycode;
    ubyte[32] scancode;
}

struct input_mask
{
    uint type;
    uint codes_size;
    ulong codes_ptr;
}
struct ff_replay
{
    ushort length;
    ushort delay;
}

struct ff_trigger
{
    ushort button;
    ushort interval;
}
struct ff_envelope
{
    ushort attack_length;
    ushort attack_level;
    ushort fade_length;
    ushort fade_level;
}

struct ff_constant_effect
{
    short level;
    ff_envelope envelope;
}

struct ff_ramp_effect
{
    short start_level;
    short end_level;
    ff_envelope envelope;
}
struct ff_condition_effect
{
    ushort right_saturation;
    ushort left_saturation;

    short right_coeff;
    short left_coeff;

    ushort deadband;
    short center;
}
struct ff_periodic_effect
{
    ushort waveform;
    ushort period;
    short magnitude;
    short offset;
    ushort phase;

    ff_envelope envelope;

    uint custom_len;
    short* custom_data;
}
struct ff_rumble_effect
{
    ushort strong_magnitude;
    ushort weak_magnitude;
}
struct ff_effect
{
    ushort type;
    short id;
    ushort direction;
    ff_trigger trigger;
    ff_replay replay;

    union
    {
        ff_constant_effect constant;
        ff_ramp_effect ramp;
        ff_periodic_effect periodic;
        ff_condition_effect[2] condition;
        ff_rumble_effect rumble;
    }
}
