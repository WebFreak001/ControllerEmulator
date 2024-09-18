module importc_compat;

static if (void*.sizeof == 4)
	alias size_t = uint;
else
	alias size_t = ulong;

alias __u8 = ubyte;
alias __u16 = ushort;
alias __u32 = uint;
alias __u64 = ulong;
alias __s8 = byte;
alias __s16 = short;
alias __s32 = int;
alias __s64 = long;
