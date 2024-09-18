# ControllerEmulator

This will grab an entire keyboard device, preventing all inputs from being processed by all other applications (including the window manager / desktop itself), and translating its inputs into a virtual gamepad/controller. This is great if you want to play with your friends via Steam Remote Play Together, where you can otherwise only play using a controller, or also just for when you want to play a local splitscreen multiplayer game that only supports multiple players with controllers.

You don't even have to only grab keyboards, you could grab events from other controllers to split into multiple controllers or simulate keyboards using a controller. Any arbitrary remapping of inputs is possible.

Building: `dub`

Usage:

```
sudo ./remap-input /dev/input/event21 puyopuyo.json
```

where `/dev/input/event21` is your device that you want to grab and inhibit from being processed by other applications. Since we want to grab an entire input device, which could be used by key logger software as well, you need to run this as root. You could probably put your user in a group to avoid the `sudo`, however you don't want to do this to not enable malicious apps from grabbing your inputs.

You can list all devices as well as test them using `sudo evtest`.

and `puyopuyo.json` is the JSON configuration of your output gamepads/devices.

**WARNING**: If you only have a single keyboard connected and grab it, you won't be able to use the keyboard anymore until you close the app! (e.g. using the mouse or a secondary keyboard) - If both keyboard and mouse share the same uinput device, both will be inhibited.

If you defined joystick keys/buttons such as `BTN_*` or `PAD_*`, a joystick device like `/dev/input/js0` will appear once you start the app. You can test the output using `jstest --normal /dev/input/js0`.

## Config Syntax

Multiple JSON files can be passed to emulate multiple devices, each JSON object corresponds to one emulated device. Additionally it's possible to define multiple JSON objects inside a single `.json` file by just putting them into an array.

In the JSON object you can assign inputs that will be emitted on the virtual device to inputs that are captured from the passed in device:

```json
"<emulated button input>": "<grabbed input>"
```

This only works for simple buttons that can be pressed or not pressed.

Samples:

```json
"BTN_A": "KEY_KP1",
"BTN_B": "KEY_KP2",
"BTN_X": "KEY_KP4",
"BTN_Y": "KEY_KP5",
```

this would simulate the controller buttons A, B, X, Y using the numpad keys 1, 2, 4, 5 respectively.

You can find the list of inputs inside [`import/input_event_codes.i`](import/input_event_codes.i).

Additionally to these inputs there are some special ones:

- `PAD_LEFTTHUMB`, `PAD_RIGHTTHUMB`, `PAD_DPAD`: see next section

### Thumbsticks / DPAD

If you want to simulate thumb sticks or the DPAD (which is an analog input on Steam games / XBox controller inputs), you can use the special special `PAD_` inputs. This only works on the left side, for emulation on the virtual device, since it's just mapping a 4-directional input to 2 optionally normalized absolute axis.

- The input `PAD_LEFTTHUMB` maps to `ABS_X, ABS_Y`.
- The input `PAD_RIGHTTHUMB` maps to `ABS_RX, ABS_RY`.
- The input `PAD_DPAD` maps to `ABS_RUDDER, ABS_THROTTLE`.

The names here are quite stupid, but map to the actual XBox inputs used by Steam games using Proton.

When using a PAD input, you have to specify a set of inputs that will be wathed for the 4 directions:

```json
"pad:LeftThumb": {
	"normalize": true,
	"up": "key:W",
	"left": "key:A",
	"down": "key:S",
	"right": "key:D"
}
```

The `normalize` field is optional and defaults to `false`.
