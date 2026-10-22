// usage: osascript -l JavaScript hold.js <key code> <seconds>
// Holds a key down (walk: W 13, turn: A 0 / D 2). Focus the game first (shot.sh).
ObjC.import('ApplicationServices');
function run(argv) {
  var code = parseInt(argv[0]), secs = parseFloat(argv[1]);
  $.CGEventPost($.kCGHIDEventTap, $.CGEventCreateKeyboardEvent($(), code, true));
  delay(secs);
  $.CGEventPost($.kCGHIDEventTap, $.CGEventCreateKeyboardEvent($(), code, false));
}
