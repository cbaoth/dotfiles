-- Advance to the next playlist entry, or quit if already at the last one.
-- Usage: script-message next-or-quit
mp.register_script_message("next-or-quit", function()
  local pos   = mp.get_property_number("playlist-pos")   -- 0-based
  local count = mp.get_property_number("playlist-count")
  if pos ~= nil and count ~= nil and pos < count - 1 then
    mp.command("playlist-next")
  else
    mp.command("quit")
  end
end)
