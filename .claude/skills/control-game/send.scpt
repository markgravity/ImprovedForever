-- usage: osascript send.scpt '<chat text>'  (e.g. '/run print(1)' or '/reload')
-- Focuses WoW, opens chat with Return, types the text, sends it.
-- The text goes in as an argument so quotes inside it need no escaping.
on run argv
  tell application "System Events" to tell process "World of Warcraft"
    set frontmost to true
    delay 0.4
    key code 36
    delay 0.4
    keystroke (item 1 of argv)
    delay 0.3
    key code 36
  end tell
end run
