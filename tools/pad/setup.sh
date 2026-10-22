#!/bin/bash
# One-time environment for the test pad: arduino-cli, the ESP32 board package and the
# libraries the firmware needs. Installs into the user's folders (Homebrew, ~/Library/Arduino15,
# ~/Documents/Arduino); nothing system-wide. Safe to run again.
set -euo pipefail

command -v arduino-cli >/dev/null || brew install arduino-cli

arduino-cli config init --overwrite >/dev/null
arduino-cli config set library.enable_unsafe_install true   # (for the git library below)
arduino-cli core update-index \
    --additional-urls https://espressif.github.io/arduino-esp32/package_esp32_index.json
arduino-cli core install esp32:esp32 \
    --additional-urls https://espressif.github.io/arduino-esp32/package_esp32_index.json

# (the library's README: it supports NimBLE-Arduino 2.1.2)
arduino-cli lib install "NimBLE-Arduino@2.1.2" "Callback"
arduino-cli lib install --git-url https://github.com/Mystfit/ESP32-BLE-CompositeHID.git

echo "ready: plug the board in, then tools/pad/flash.sh"
