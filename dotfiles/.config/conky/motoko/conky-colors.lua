-- conky-colors.lua: color threshold helpers for conky-left-*.conf
--
-- WHY dedicated functions instead of a generic conky_threshold_color(val, warn, crit):
--   ${lua_parse} splits its argument list on spaces, so any conky variable
--   that contains spaces (e.g. ${hwmon 6 temp 1} or ${fs_used_perc /mnt/c})
--   gets fragmented into multiple args before Lua sees them, making tonumber()
--   return nil and thresholds never trigger. The fix: each function calls
--   conky_parse() internally, so only simple space-free args are passed.
--
-- Returns ${color red}, ${color orange}, or ${color} (reset to default).
--
-- Usage in conky config text:
--   CPU:   ${lua_parse conky_color_cpu_tctl 85 95}${hwmon 6 temp 1}°C${color}
--   RAM:   ${lua_parse conky_color_memperc 80 90}$memperc%${color}
--   SWAP:  ${lua_parse conky_color_swapperc 50 80}$swapperc%${color}
--   Disk:  ${lua_parse conky_color_disk /mnt/c 80 95}${fs_used_perc /mnt/c}%${color}

local function threshold_color(val, warn, crit)
    if val >= (crit or 95) then
        return "${color red}"
    elseif val >= (warn or 80) then
        return "${color orange}"
    else
        return "${color}"
    end
end

-- CPU temperature: K10temp Tctl (hwmon 6 temp 1)
function conky_color_cpu_tctl(warn, crit)
    return threshold_color(tonumber(conky_parse("${hwmon 6 temp 1}")) or 0,
                           tonumber(warn), tonumber(crit))
end

-- CPU temperature: K10temp Tccd1 (hwmon 6 temp 3)
function conky_color_cpu_tccd1(warn, crit)
    return threshold_color(tonumber(conky_parse("${hwmon 6 temp 3}")) or 0,
                           tonumber(warn), tonumber(crit))
end

-- RAM usage percentage
function conky_color_memperc(warn, crit)
    return threshold_color(tonumber(conky_parse("${memperc}")) or 0,
                           tonumber(warn), tonumber(crit))
end

-- Swap usage percentage
function conky_color_swapperc(warn, crit)
    return threshold_color(tonumber(conky_parse("${swapperc}")) or 0,
                           tonumber(warn), tonumber(crit))
end

-- Filesystem usage: mount path is the first arg (e.g. /, /mnt/c, /srv/saito/data)
-- Mount paths have no spaces so they pass cleanly as a single lua_parse argument.
function conky_color_disk(mount, warn, crit)
    return threshold_color(
        tonumber(conky_parse("${fs_used_perc " .. mount .. "}")) or 0,
        tonumber(warn), tonumber(crit))
end
