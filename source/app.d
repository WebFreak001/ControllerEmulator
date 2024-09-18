import std.stdio;

import core.thread;
import core.time;
import input;
import input_event_codes;
import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.getopt;
import std.json;
import std.string;
import std.sumtype;
import std.uni;
import uinput;

import core.stdc.string : strerror;
import core.sys.posix.sys.time : timeval;

enum InputType : ushort
{
	sync = EV_SYN,
	key = EV_KEY,
	rel = EV_REL,
	abs = EV_ABS,
	misc = EV_MSC,
	switch_ = EV_SW,
	led = EV_LED,

	pad = 0x8000,
}

InputType inputTypeOf(string s)
{
	return [
		InputType.pad,
		InputType.key,
		InputType.key,
		InputType.sync,
		InputType.rel,
		InputType.abs,
		InputType.misc,
		InputType.switch_,
		InputType.led
	][s.startsWith("PAD_", "KEY_", "BTN_", "SYN_", "REL_", "ABS_", "MSC_", "SW_", "LED_") - 1];
}

enum PAD_LEFTTHUMB = 0;
enum PAD_RIGHTTHUMB = 1;
enum PAD_DPAD = 2;

struct Input
{
	InputType type;
	uint code;
}

Input parseInput(string i)
{
	i = i.toUpper.replace(":", "_");
	switch (i)
	{
		static foreach (m; [
			"PAD_LEFTTHUMB", "PAD_RIGHTTHUMB", "PAD_DPAD",
			__traits(allMembers, input_event_codes)
		])
		{
			static if (m.startsWith("PAD_", "KEY_", "BTN_", "SYN_", "REL_", "ABS_", "MSC_", "SW_", "LED_"))
			{
	case m:
				return Input(inputTypeOf(m), mixin(m));
			}
		}
	case "KEY_HANGUEL":
		return Input(InputType.key, KEY_HANGEUL);
	case "KEY_SCREENLOCK":
		return Input(InputType.key, KEY_COFFEE);
	case "KEY_DIRECTION":
		return Input(InputType.key, KEY_ROTATE_DISPLAY);
	case "KEY_DASHBOARD":
		return Input(InputType.key, KEY_ALL_APPLICATIONS);
	case "KEY_BRIGHTNESS_ZERO":
		return Input(InputType.key, KEY_BRIGHTNESS_AUTO);
	case "KEY_WIMAX":
		return Input(InputType.key, KEY_WWAN);
	case "BTN_A":
		return Input(InputType.key, BTN_SOUTH);
	case "BTN_B":
		return Input(InputType.key, BTN_EAST);
	case "BTN_X":
		return Input(InputType.key, BTN_NORTH);
	case "BTN_Y":
		return Input(InputType.key, BTN_WEST);
	case "KEY_ZOOM":
		return Input(InputType.key, KEY_FULL_SCREEN);
	case "KEY_SCREEN":
		return Input(InputType.key, KEY_ASPECT_RATIO);
	case "KEY_BRIGHTNESS_TOGGLE":
		return Input(InputType.key, KEY_DISPLAYTOGGLE);
	case "KEY_MIN_INTERESTING":
		return Input(InputType.key, KEY_MUTE);
	case "SW_RADIO":
		return Input(InputType.switch_, SW_RFKILL_ALL);
	default:
		throw new Exception("Unparsable input '" ~ i ~ "'");
	}
}

string[] globalFilterInputs;

void main(string[] args)
{
	bool passthrough;

	// dfmt off
	auto h = args.getopt(
		"p|passthrough", "Keys that don't match any input on captured inputs will be re-emitted", &passthrough,
		"f|filter", "Filter inputs (list of file paths to `/dev/input/event*`)", &globalFilterInputs,
		config.passThrough
	);
	// dfmt on
	if (h.helpWanted || args.length < 3)
	{
		defaultGetoptPrinter("Linux libevdev/uinput Input Remapper\nUsage: " ~ args[0] ~ " [/dev/input/eventX] [json configs...]", h.options);
		return;
	}

	SimulatedDevice[] devices;
	foreach (dev; args[2 .. $]
		.map!readText
		.map!parseJSON
		.map!(j => j.type == JSONType.array ? j.array : [j])
		.joiner
		.map!parseDevice)
	{
		devices.length++;
		devices[$ - 1] = dev.move;
		writeln("Handlers: ", devices[$ - 1].handlers.keys);
	}

	Thread.sleep(100.msecs);

	GrabbedDevice grab = GrabbedDevice(args[1]);

	while (true)
	{
		auto start = MonoTime.currTime;
		auto ev = grab.pollEvent();
		// if (ev.code == KEY_ESC)
		// {
		// 	writeln("PRESSED ESCAPE BUTTON - EXITING!");
		// 	break;
		// }
		if (ev != GrabbedInputEvent.init)
		{
			broadcastEvent(ev, devices);
		}
		auto dur = MonoTime.currTime - start;
		if (dur < 1.msecs)
			Thread.sleep(1.msecs - dur);
	}

	// while (true)
	// {
	// 	Thread.sleep(1.seconds);
	// }
}

interface EventHandler
{
	Input[] consumedInputs();
	Input[] emittedInputs();
	void process(ref SimulatedDevice device, GrabbedInputEvent e);
}

class ValueRemapEventHandler : EventHandler
{
	Input from, remapTo;
	this(Input from, Input remapTo)
	{
		this.from = from;
		this.remapTo = remapTo;
	}

	Input[] consumedInputs()
	{
		return [from];
	}

	Input[] emittedInputs()
	{
		return [remapTo];
	}

	void process(ref SimulatedDevice device, GrabbedInputEvent e)
	{
		device.emitEvent(cast(int) remapTo.type, remapTo.code, e.value);
	}
}

class FourWayPad : EventHandler
{
	int xAxis, yAxis;
	bool normalize;
	Input[4] dirs;
	bool[4] pressed;

	this(int pad, bool normalize, Input up, Input left, Input down, Input right)
	{
		switch (pad)
		{
		case PAD_LEFTTHUMB:
			xAxis = ABS_X;
			yAxis = ABS_Y;
			break;
		case PAD_RIGHTTHUMB:
			xAxis = ABS_RX;
			yAxis = ABS_RY;
			break;
		case PAD_DPAD:
			xAxis = ABS_RUDDER;
			yAxis = ABS_THROTTLE;
			break;
		default:
			throw new Exception("Unimplemented pad");
		}
		this.normalize = normalize;
		dirs = [up, left, down, right];
	}

	Input[] consumedInputs()
	{
		return dirs[];
	}

	Input[] emittedInputs()
	{
		return [Input(InputType.abs, xAxis), Input(InputType.abs, yAxis)];
	}

	void process(ref SimulatedDevice device, GrabbedInputEvent e)
	{
		static foreach (i; 0 .. dirs.length)
		{
			if (e.code == dirs[i].code)
			{
				pressed[i] = e.value != 0;
			}
		}
		int x = (-32767 * (pressed[2] ? 1 : 0)) + (32767 * (pressed[0] ? 1 : 0));
		int y = (-32767 * (pressed[3] ? 1 : 0)) + (32767 * (pressed[1] ? 1 : 0));

		if (normalize)
		{
			if (x != 0 && y != 0)
			{
				x = cast(short) (cast(long)x * 23170 / 32767);
				y = cast(short) (cast(long)y * 23170 / 32767);
			}
		}

		device.emitEvent!false(EV_ABS, xAxis, -x);
		device.emitEvent!true(EV_ABS, yAxis, -y);
	}
}

struct SimulatedDevice
{
	@disable this(this);

	~this()
	{
		libevdev_uinput_destroy(uidev);
		libevdev_free(dev);
	}

	libevdev* dev;
	libevdev_uinput* uidev;
	EventHandler[Input] handlers;

	void emitEvent(bool report = true)(int type, int code, int value) const
	{
		libevdev_uinput_write_event(cast(libevdev_uinput*) uidev, type, code, value);
		static if (report)
			libevdev_uinput_write_event(cast(libevdev_uinput*) uidev, EV_SYN, SYN_REPORT, 0);
	}
}

struct GrabbedInputEvent
{
	timeval time;
	InputType type;
	ushort code;
	int value;
}

SimulatedDevice parseDevice(JSONValue j)
{
	SimulatedDevice d;
	foreach (k, v; j.object)
	{
		auto wanted = parseInput(k);
		EventHandler handler;
		switch (wanted.type)
		{
		case InputType.pad:
			handler = makePadHandler(wanted.code, v);
			break;
		default:
			if (v.type == JSONType.string)
			{
				handler = new ValueRemapEventHandler(parseInput(v.str), wanted);
				break;
			}
			else
			{
				throw new Exception("Can't emulate " ~ wanted.type.to!string
						~ " with a non-input string");
			}
		}

		foreach (i; handler.consumedInputs)
			d.handlers[i] = handler;
	}

	d.dev = libevdev_new();
	libevdev_set_name(d.dev, "ControllerEmulator device");

	bool[int] enabled;
	bool[Input] inputSet;
	foreach (v; d.handlers.byValue)
		foreach (key; v.emittedInputs)
			inputSet[key] = true;

	input.input_absinfo absinfo;
	absinfo.minimum = short.min;
	absinfo.maximum = short.max;
	absinfo.fuzz = 2;

	foreach (key; inputSet.byKey)
	{
		auto type = cast(int) key.type;
		if (type !in enabled)
		{
			writefln!"libevdev_enable_event_type(%s, %s)"(d.dev, type);
			libevdev_enable_event_type(d.dev, type);
			enabled[type] = true;
		}
		writefln!"libevdev_enable_event_code(%s, %s, %s, null)"(d.dev, type, key
				.code);
		void* data = null;
		if (type == EV_ABS)
			data = cast(void*) &absinfo;
		libevdev_enable_event_code(d.dev, type, key.code, data);
	}

	auto err = libevdev_uinput_create_from_device(d.dev,
		LIBEVDEV_UINPUT_OPEN_MANAGED,
		&d.uidev);

	if (err != 0)
		throw new Exception("libevdev_uinput_create_from_device failed");

	return d;
}

EventHandler makePadHandler(uint pad, JSONValue object)
{
	auto o = object.object;
	return new FourWayPad(
		pad,
		"normalize" in o && o["normalize"].boolean,
		o["up"].str.parseInput,
		o["left"].str.parseInput,
		o["down"].str.parseInput,
		o["right"].str.parseInput
	);
}

struct GrabbedDevice
{
	@disable this(this);

	this(string file)
	{
		import core.sys.posix.fcntl;
		import core.sys.posix.unistd;

		fd = open(file.toStringz, O_RDONLY | O_NONBLOCK);
		if (fd < 0)
			throw new Exception("Cannot open device");

		scope (failure)
			close(fd);

		auto rc = libevdev_new_from_fd(fd, &dev);
		if (rc < 0)
			throw new Exception("Failed to init libevdev (" ~ strerror(-rc)
					.fromStringz.idup ~ ")");

		scope (failure)
			libevdev_free(dev);

		rc = libevdev_grab(dev, LIBEVDEV_GRAB);
		if (rc < 0)
			throw new Exception("Failed to grab the device (" ~ strerror(-rc)
					.fromStringz.idup ~ ")");

		scope (failure)
			libevdev_grab(dev, LIBEVDEV_UNGRAB);
	}

	~this()
	{
		import core.sys.posix.unistd : close;

		libevdev_grab(dev, LIBEVDEV_UNGRAB);
		libevdev_free(dev);
		close(fd);
	}

	libevdev* dev;
	int fd;

	GrabbedInputEvent pollEvent()
	{
		import core.stdc.errno : EAGAIN;

		input.input_event ev;
		auto rc = libevdev_next_event_compat(dev, LIBEVDEV_READ_FLAG_NORMAL, &ev);
		if (rc == 0)
		{
			return GrabbedInputEvent(ev.time, cast(InputType) ev.type, ev.code, ev
					.value);
		}
		else if (rc == 1 || rc == -EAGAIN)
		{
			return GrabbedInputEvent.init;
		}
		else
		{
			throw new Exception(
				"Failed reading next libevdev event: " ~ strerror(
					-rc)
					.fromStringz.idup);
		}
	}
}

extern (C) nothrow @nogc @system
pragma(mangle, "libevdev_next_event")
int libevdev_next_event_compat(libevdev* dev, uint flags, input.input_event* ev);

void broadcastEvent(GrabbedInputEvent ev, scope SimulatedDevice[] devices)
{
	auto input = Input(ev.type, ev.code);
	bool handled;
	foreach (ref device; devices)
	{
		if (auto handler = input in device.handlers)
		{
			handler.process(device, ev);
			handled = true;
		}
	}

	if (!handled)
	{
		writefln!"Unhandled input: %s (0x%x)"(input, input.code);
	}
}
