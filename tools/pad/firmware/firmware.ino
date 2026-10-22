// Improved Forever test pad: an ESP32-C3 that shows up to the Mac as a real Bluetooth
// Xbox One S controller (so WoW's SDL and the Mac's GameController both take it for a
// pad), and presses what it is told over its USB serial port.
//
// One command per line, answer "ok" or "err <why>":
//   press <items> [ms]   hold the items for ms (default 100), then let go
//   down  <items>        hold them until `up`
//   up    <items>        let go of them
//   stick L|R <x> <y>    stick position, -1.0 .. 1.0 (y: 1 = up)
//   trig  L|R <v>        trigger, 0.0 .. 1.0
//   reset                everything released and centred
//   status               "connected=1" when the Mac has the pad
// <items> are joined with +, e.g. LT+SELECT or A or UP+RIGHT:
//   buttons  A B X Y LB RB L3 R3 SELECT START HOME SHARE
//   triggers LT RT (as a full press)
//   d-pad    UP DOWN LEFT RIGHT
//   aliases  PlayStation names (CROSS CIRCLE SQUARE TRIANGLE L1 R1 L2 R2 CREATE OPTIONS),
//            VIEW = SELECT, MENU = START, BACK = SELECT
//
// Build and flash with tools/pad/flash.sh.

#include <Arduino.h>
#include <BleCompositeHID.h>
#include <XboxGamepadDevice.h>

static XboxGamepadDevice *pad;
static BleCompositeHID hid("Improved Forever Test Pad", "Improved Forever", 100);

struct Name { const char *name; uint16_t mask; };
static const Name BUTTONS[] = {
    {"A", XBOX_BUTTON_A}, {"CROSS", XBOX_BUTTON_A},
    {"B", XBOX_BUTTON_B}, {"CIRCLE", XBOX_BUTTON_B},
    {"X", XBOX_BUTTON_X}, {"SQUARE", XBOX_BUTTON_X},
    {"Y", XBOX_BUTTON_Y}, {"TRIANGLE", XBOX_BUTTON_Y},
    {"LB", XBOX_BUTTON_LB}, {"L1", XBOX_BUTTON_LB},
    {"RB", XBOX_BUTTON_RB}, {"R1", XBOX_BUTTON_RB},
    {"L3", XBOX_BUTTON_LS}, {"R3", XBOX_BUTTON_RS},
    {"SELECT", XBOX_BUTTON_SELECT}, {"VIEW", XBOX_BUTTON_SELECT}, {"BACK", XBOX_BUTTON_SELECT},
    {"CREATE", XBOX_BUTTON_SELECT},
    {"START", XBOX_BUTTON_START}, {"MENU", XBOX_BUTTON_START}, {"OPTIONS", XBOX_BUTTON_START},
    {"HOME", XBOX_BUTTON_HOME},
};
static const Name DPAD[] = {
    {"UP", NORTH}, {"RIGHT", EAST}, {"DOWN", SOUTH}, {"LEFT", WEST},
};

static uint8_t dpadFlags = 0;

static void sendPad() { pad->sendGamepadReport(); }

// One item of a + list; false when the name is not known
static bool apply(String item, bool down) {
    item.toUpperCase();
    for (const Name &n : BUTTONS) {
        if (item == n.name) {
            if (down) pad->press(n.mask); else pad->release(n.mask);
            return true;
        }
    }
    for (const Name &n : DPAD) {
        if (item == n.name) {
            if (down) dpadFlags |= n.mask; else dpadFlags &= ~n.mask;
            if (dpadFlags) pad->pressDPadDirectionFlag((XboxDpadFlags)dpadFlags);
            else pad->releaseDPad();
            return true;
        }
    }
    if (item == "SHARE") {
        if (down) pad->pressShare(); else pad->releaseShare();
        return true;
    }
    if (item == "LT" || item == "L2") { pad->setLeftTrigger(down ? XBOX_TRIGGER_MAX : 0); return true; }
    if (item == "RT" || item == "R2") { pad->setRightTrigger(down ? XBOX_TRIGGER_MAX : 0); return true; }
    return false;
}

// "A+B+LT": all of them, or none (an unknown name leaves the pad as it was)
static bool applyList(const String &list, bool down) {
    int from = 0;
    while (from <= (int)list.length()) {
        int plus = list.indexOf('+', from);
        if (plus < 0) plus = list.length();
        String item = list.substring(from, plus);
        if (item.length() && !apply(item, down)) return false;
        from = plus + 1;
    }
    sendPad();
    return true;
}

static int16_t axis(float v) {
    if (v > 1) v = 1;
    if (v < -1) v = -1;
    return (int16_t)(v * 32767);
}

static void resetPad() {
    dpadFlags = 0;
    pad->resetInputs();
    sendPad();
}

static String field(const String &line, int index) {
    int start = 0;
    for (int i = 0; i < index; i++) {
        start = line.indexOf(' ', start);
        if (start < 0) return "";
        start++;
    }
    int end = line.indexOf(' ', start);
    return end < 0 ? line.substring(start) : line.substring(start, end);
}

static void handle(String line) {
    line.trim();
    if (!line.length()) return;
    String cmd = field(line, 0);
    cmd.toLowerCase();

    if (cmd == "status") {
        Serial.println(String("connected=") + (hid.isConnected() ? 1 : 0));
        return;
    }
    if (!hid.isConnected()) { Serial.println("err not connected"); return; }

    if (cmd == "press") {
        String items = field(line, 1);
        String ms = field(line, 2);
        if (!applyList(items, true)) { Serial.println("err unknown item"); return; }
        delay(ms.length() ? ms.toInt() : 100);
        applyList(items, false);
        Serial.println("ok");
    } else if (cmd == "down" || cmd == "up") {
        Serial.println(applyList(field(line, 1), cmd == "down") ? "ok" : "err unknown item");
    } else if (cmd == "stick") {
        String side = field(line, 1);
        int16_t x = axis(field(line, 2).toFloat()), y = axis(field(line, 3).toFloat());
        if (side == "L" || side == "l") pad->setLeftThumb(x, y);
        else if (side == "R" || side == "r") pad->setRightThumb(x, y);
        else { Serial.println("err side L or R"); return; }
        sendPad();
        Serial.println("ok");
    } else if (cmd == "trig") {
        String side = field(line, 1);
        float v = field(line, 2).toFloat();
        if (v < 0) v = 0;
        if (v > 1) v = 1;
        uint16_t t = (uint16_t)(v * XBOX_TRIGGER_MAX);
        if (side == "L" || side == "l") pad->setLeftTrigger(t);
        else if (side == "R" || side == "r") pad->setRightTrigger(t);
        else { Serial.println("err side L or R"); return; }
        sendPad();
        Serial.println("ok");
    } else if (cmd == "reset") {
        resetPad();
        Serial.println("ok");
    } else {
        Serial.println("err unknown command");
    }
}

void setup() {
    Serial.begin(115200);
    XboxOneSControllerDeviceConfiguration *config = new XboxOneSControllerDeviceConfiguration();
    BLEHostConfiguration hostConfig = config->getIdealHostConfiguration();
    pad = new XboxGamepadDevice(config);
    hid.addDevice(pad);
    hid.begin(hostConfig);
}

void loop() {
    static String line;
    while (Serial.available()) {
        char c = (char)Serial.read();
        if (c == '\n' || c == '\r') {
            handle(line);
            line = "";
        } else if (line.length() < 120) {
            line += c;
        }
    }
    delay(1);
}
