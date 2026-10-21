-- ~/.config/tts/mpv-jump.lua: type a clip number to jump to it (used by bin/tts-compare).
--
-- Digits are collected for a short moment, then the playlist jumps to that
-- 1-based position: "6" -> clip 6, "1" "2" -> clip 12. Loaded only by
-- tts-compare via --script, so digits keep their normal meaning in any other mpv.

local digits = ""
local timer = nil

local function commit()
  local n = tonumber(digits)
  digits = ""
  local count = mp.get_property_number("playlist-count", 0)
  if n and n >= 1 and n <= count then
    mp.set_property_number("playlist-pos", n - 1)
  else
    mp.osd_message(string.format("no clip %s (1-%d)", tostring(n), count), 1.5)
  end
end

local function press(d)
  return function()
    digits = digits .. d
    mp.osd_message("go to clip " .. digits, 1)
    if timer then timer:kill() end
    timer = mp.add_timeout(0.8, commit)
  end
end

for d = 0, 9 do
  mp.add_forced_key_binding(tostring(d), "tts-jump-" .. d, press(tostring(d)))
end
