# Test pad: a fake controller for testing in game

An ESP32-C3 (WEMOS/LOLIN C3 Mini) that the Mac sees as a real Bluetooth Xbox One S
controller. A script on the Mac sends it presses over USB serial, so a controller-only path of
the addon (L2 + Select, the crossbar, the wheels) can be tested without a hand on a pad.

It is real hardware to the Mac, not a virtual device: macOS ignores virtual HID pads
(GameController) and a virtual pad needs an Apple-restricted entitlement.

## Status
Drafted, not built or flashed yet: none of this has run on a board. The first things to
check are in "First run".

## Set up
1. `tools/pad/setup.sh` (arduino-cli, the ESP32 core, NimBLE-Arduino 2.1.2, Callback and
   ESP32-BLE-CompositeHID).
2. Plug the board in with a data cable. If `/dev/cu.usbmodem*` doesn't show, hold BOOT while
   plugging in.
3. `tools/pad/flash.sh`.
4. System Settings > Bluetooth > pair "Improved Forever Test Pad" (it shows as an Xbox
   controller). It reconnects by itself after that. The game needs Options > Gamepad (Alpha)
   > Enable Gamepad UI on.

## Use
    tools/pad/pad.py status
    tools/pad/pad.py press A
    tools/pad/pad.py press LT+SELECT 150
    tools/pad/pad.py "stick L 0 1; wait 800; stick L 0 0"

Items: buttons `A B X Y LB RB L3 R3 SELECT START HOME SHARE`, triggers `LT RT`, d-pad
`UP DOWN LEFT RIGHT`, PlayStation aliases (`CROSS CIRCLE SQUARE TRIANGLE L1 R1 L2 R2 CREATE
OPTIONS`). Full list in the header of `firmware/firmware.ino`.

## First run: what to check
- `status` says `connected=1` once the Mac has it paired.
- A press shows in the game (the crossbar pages, a window moves).
- Stick Y: the firmware passes y = 1 as "up"; if the character walks backwards, flip the
  sign in `firmware.ino`.
- Select and Start reach the game (Select is the pad's View, Start its Menu).
- If macOS pairs it but WoW ignores it: try `XboxSeriesXControllerDeviceConfiguration`
  (change one line in `setup()`), or the library's DualSense device.
- The port is opened without toggling DTR/RTS on purpose: on the C3's USB serial those
  toggles can reset the chip.
