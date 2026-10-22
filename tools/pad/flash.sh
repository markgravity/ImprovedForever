#!/bin/bash
# Build the firmware and flash it to the ESP32-C3 on USB. If no port shows up, hold BOOT
# while plugging the board in (download mode), then run this again.
set -euo pipefail
cd "$(dirname "$0")"

# (WEMOS/LOLIN C3 Mini; USB-CDC on boot so the native USB port is the serial port)
FQBN="esp32:esp32:lolin_c3_mini:CDCOnBoot=cdc"
PORT="${PAD_PORT:-$(ls /dev/cu.usbmodem* 2>/dev/null | head -1)}"
[ -n "$PORT" ] || { echo "no /dev/cu.usbmodem*: plug the ESP32-C3 in (data cable)" >&2; exit 1; }

arduino-cli compile --fqbn "$FQBN" --build-path build firmware
arduino-cli upload --fqbn "$FQBN" --port "$PORT" --input-dir build firmware
echo "flashed. Pair 'Improved Forever Test Pad' in System Settings > Bluetooth, then:"
echo "  tools/pad/pad.py status"
