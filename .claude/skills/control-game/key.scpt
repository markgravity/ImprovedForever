-- usage: osascript key.scpt <key code>   (53 Esc, 36 Return, 49 Space, 13 W...)
-- Focuses WoW first (a key sent while another app is in front lands there).
on run argv
  tell application "System Events" to tell process "World of Warcraft"
    set frontmost to true
    delay 0.4
    key code (item 1 of argv as integer)
  end tell
end run
