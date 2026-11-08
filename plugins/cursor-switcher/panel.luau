--!strict

local CONFIG = "~/.config/niri/config.kdl"

local themes = {}
local currentTheme = "Unknown"
local cursorSize = 24
local loading = true
local themesLoaded = false


local function render()
    local themeRows = {}

    if loading then
        table.insert(themeRows, ui.label({
            text = "Discovering cursor themes...",
            color = "secondary"
        }))
    elseif #themes == 0 then
        table.insert(themeRows, ui.label({
            text = "No cursor themes found.",
            color = "secondary"
        }))
    else
        for i = 1, #themes, 2 do
            local rowButtons = {}

            for j = i, math.min(i + 1, #themes) do
                local theme = themes[j]
                local selected = theme == currentTheme

                table.insert(rowButtons, ui.button({
                    key = theme,
                    text = (selected and "✓  " or "") .. theme,
                    variant = selected and "primary" or "outline",
                    contentAlign = "center",
                    flexGrow = 1,
                    onClick = function()
                        selectTheme(theme)
                    end
                }))
            end

            table.insert(themeRows, ui.row({
                gap = 8,
                align = "center"
            }, rowButtons))
        end
    end

    panel.render(ui.column({ gap = 12, padding = 16 }, {
        ui.row({ align = "center", justify = "space_between" }, {
            ui.label({
                text = "Cursor Switcher",
                fontSize = 18,
                fontWeight = "bold",
                color = "primary",
                flexGrow = 1
            }),
            ui.button({
                glyph = "refresh",
                variant = "ghost",
                tooltip = "Rescan themes",
                onClick = function()
                    refreshThemes()
                end
            })
        }),

        ui.label({
            text = "Installed themes",
            fontWeight = "bold"
        }),

        ui.scroll({ flexGrow = 1 }, themeRows),

        ui.label({
            text = "Cursor size",
            fontWeight = "bold"
        }),

        ui.row({ align = "center", justify = "space_between" }, {
            ui.label({ text = "Size" }),
            ui.label({
                text = tostring(cursorSize) .. " px",
                color = "primary",
                fontWeight = "bold"
            })
        }),

        ui.slider({
            min = 8,
            max = 64,
            step = 1,
            value = cursorSize,
            onChange = function(value)
                local size = math.clamp(math.floor(tonumber(value) or 24), 8, 64)
                if size ~= cursorSize then
                    cursorSize = size
                    saveSettings(nil, size)
                    render()
                end
            end
        }),

        ui.label({
            text = "Current: " .. currentTheme,
            color = "secondary"
        })
    }))
end

local function readCurrentSettings()
    local content = noctalia.readFile(CONFIG)

    if not content then
        noctalia.notifyError("Cursor Switcher", "Cannot read Niri config.")
        return
    end

    local block = content:match("cursor%s*(%b{})")

    if not block then
        noctalia.notifyError("Cursor Switcher", "Could not find the Niri cursor block.")
        return
    end

    currentTheme = block:match('xcursor%-theme%s+"([^"]+)"') or "Unknown"
    cursorSize = tonumber(block:match("xcursor%-size%s+(%d+)")) or 24
end

local function replaceSetting(block, key, value, quoted)
    local pattern

    if quoted then
        pattern = "([ \t]*" .. key .. '%s+")([^"]*)(")'
        local count
        block, count = block:gsub(pattern, function(prefix, _, suffix)
            return prefix .. value .. suffix
        end, 1)

        if count == 0 then
            block = block:gsub("([ \t]*)}$",
                "\n    " .. key:gsub("%%%-", "-") .. ' "' .. value .. '"\n%1}', 1)
        end
    else
        pattern = "([ \t]*" .. key .. "%s+)%d+"
        local count
        block, count = block:gsub(pattern, function(prefix)
            return prefix .. value
        end, 1)

        if count == 0 then
            block = block:gsub("([ \t]*)}$",
                "\n    " .. key:gsub("%%%-", "-") .. " " .. value .. "\n%1}", 1)
        end
    end

    return block
end

function saveSettings(theme, size)
    local content = noctalia.readFile(CONFIG)

    if not content then
        noctalia.notifyError("Cursor Switcher", "Cannot read Niri config.")
        return
    end

    local first, last = content:find("cursor%s*%b{}")

    if not first then
        noctalia.notifyError("Cursor Switcher", "Niri cursor block not found.")
        return
    end

    local block = content:sub(first, last)

    if theme then
        local escaped = theme:gsub("\\", "\\\\"):gsub('"', '\\"')
        block = replaceSetting(block, "xcursor%-theme", escaped, true)
    end

    if size then
        block = replaceSetting(block, "xcursor%-size", tostring(size), false)
    end

    local updated = content:sub(1, first - 1)
        .. block
        .. content:sub(last + 1)

    local ok, err = noctalia.writeFile(CONFIG, updated)

    if not ok then
        noctalia.notifyError("Cursor Switcher", tostring(err or "Could not write Niri config."))
        return
    end

    if theme then
        currentTheme = theme
        noctalia.notify("Cursor Switcher", "Cursor changed to " .. theme)
    end

    if size then
        cursorSize = size
    end

    render()
end

function selectTheme(theme)
    saveSettings(theme, nil)
end

function refreshThemes()
    loading = true
    render()

    local paths = {
        noctalia.expandPath("~/.local/share/icons"),
        noctalia.expandPath("~/.icons"),
        noctalia.expandPath("~/.nix-profile/share/icons"),
        "/run/current-system/sw/share/icons",
        "/usr/share/icons"
    }

    local extra = noctalia.getenv("XCURSOR_PATH")

    if extra then
        for path in string.gmatch(extra, "[^:]+") do
            table.insert(paths, noctalia.expandPath(path))
        end
    end

    local uniquePaths = {}
    local args = { "find", "-L" }

    for _, path in ipairs(paths) do
        if not uniquePaths[path] then
            uniquePaths[path] = true
            table.insert(args, path)
        end
    end

    table.insert(args, "-type")
    table.insert(args, "d")
    table.insert(args, "-name")
    table.insert(args, "cursors")
    table.insert(args, "-print")

    local started = noctalia.runAsync(args, function(result)
        themes = {}
        local seen = {}

        for line in string.gmatch(result.stdout or "", "[^\r\n]+") do
            local name = line:match("([^/]+)/cursors/?$")

            if name and not seen[name] then
                seen[name] = true
                table.insert(themes, name)
            end
        end

        table.sort(themes)
        loading = false
        themesLoaded = true

        if result.exitCode ~= 0 and #themes == 0 then
            noctalia.log("Cursor discovery: " .. tostring(result.stderr))
        end

        render()
    end)

    if not started then
        loading = false
        noctalia.notifyError("Cursor Switcher", "Could not start theme discovery.")
        render()
    end
end

function onOpen()
    readCurrentSettings()

    if not themesLoaded then
        refreshThemes()
    else
        render()
    end
end
