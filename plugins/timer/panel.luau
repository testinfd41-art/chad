-- Timer control panel.
-- Presets + custom duration. Display is always total minutes:seconds.
-- The "time is up" notification and sound are handled by service.luau.
--
-- Layout notes: controls use the compact "sm" height (32px) and everything sits
-- in a ui.scroll, so if the panel is ever shorter than its content (small
-- screen, high UI scale) the bottom controls scroll into view instead of
-- being cut off.

local MAX_SECONDS = 99 * 3600

-- Spacing options (in px). Change these numbers to adjust the space between things.
local PANEL_PADDING = 14   -- space around the edge of the whole panel
local SECTION_GAP = 10     -- space between sections: title, time, progress bar, presets, input, buttons
local PRESET_GAP = 6       -- space between the preset buttons (side by side and row to row)
local ACTION_GAP = 8       -- space between Start/Pause and Reset
local TITLE_GAP = 8        -- space between the icon, the title and the status text at the top

-- What the input box says. Presets start immediately and never touch this,
-- so the box always shows what the user typed themselves.
local pendingText = "5m"

local function getTimer()
    local t = noctalia.state.get("timer")
    if type(t) ~= "table" then
        return { running = false, endMs = 0, remainingMs = 0, totalMs = 0 }
    end
    return t
end

local function remainingMs(t)
    if t.running == true then
        return math.max(0, (t.endMs or 0) - noctalia.nowMs())
    end
    return t.remainingMs or 0
end

-- Always total minutes:seconds, rounded up so "0:01" shows until the very end.
local function formatRemaining(ms)
    local totalSeconds = math.ceil(math.max(0, ms) / 1000)
    return string.format("%d:%02d", math.floor(totalSeconds / 60), totalSeconds % 60)
end

-- Accepts: 25 (minutes), 90s, 15m, 2h, 1h30m, 1:30 (m:ss). Returns seconds or nil.
local function parseDuration(text)
    local cleaned = string.gsub(text or "", "%s+", "")
    cleaned = string.lower(cleaned)

    if cleaned == "" then
        return nil
    end

    local total = nil

    local mm, ss = string.match(cleaned, "^(%d+):(%d%d?)$")
    local bare = string.match(cleaned, "^(%d+)$")

    if mm then
        total = tonumber(mm) * 60 + tonumber(ss)
    elseif bare then
        total = tonumber(bare) * 60
    else
        local leftover = string.gsub(cleaned, "%d+[hms]", "")
        if leftover ~= "" then
            return nil
        end

        total = 0
        for num, unit in string.gmatch(cleaned, "(%d+)([hms])") do
            local n = tonumber(num)
            if unit == "h" then
                total = total + n * 3600
            elseif unit == "m" then
                total = total + n * 60
            else
                total = total + n
            end
        end
    end

    if not total or total <= 0 or total > MAX_SECONDS then
        return nil
    end

    return total
end

local render

local function startSeconds(seconds)
    if not seconds or seconds <= 0 then
        return
    end

    local ms = seconds * 1000
    noctalia.state.set("timer", {
        running = true,
        endMs = noctalia.nowMs() + ms,
        remainingMs = 0,
        totalMs = ms,
    })
    render()
end

local function toggle()
    local t = getTimer()
    local now = noctalia.nowMs()

    if t.running == true then
        -- Pause.
        noctalia.state.set("timer", {
            running = false,
            endMs = 0,
            remainingMs = math.max(0, (t.endMs or 0) - now),
            totalMs = t.totalMs or 0,
        })
    elseif (t.remainingMs or 0) > 0 then
        -- Resume.
        noctalia.state.set("timer", {
            running = true,
            endMs = now + t.remainingMs,
            remainingMs = 0,
            totalMs = t.totalMs or 0,
        })
    else
        -- Start from whatever is typed in the box.
        local seconds = parseDuration(pendingText)

        if not seconds then
            noctalia.notifyError(
                "Timer",
                "Couldn't understand \"" .. tostring(pendingText) .. "\". Try 25, 90s, 15m or 1h30m."
            )
            return
        end

        startSeconds(seconds)
        return
    end

    render()
end

local function reset()
    noctalia.state.set("timer", {
        running = false,
        endMs = 0,
        remainingMs = 0,
        totalMs = 0,
    })
    render()
end

local function presetButton(minutes, enabled)
    return ui.button({
        key = "preset-" .. minutes,
        text = minutes .. " min",
        controlSize = "lg",
        flexGrow = 1,
        enabled = enabled,
        onClick = function()
            startSeconds(minutes * 60)
        end,
    })
end

render = function()
    local t = getTimer()
    local running = t.running == true
    local remaining = remainingMs(t)
    local paused = (not running) and remaining > 0
    local idle = (not running) and (not paused)

    local headline
    local status
    local progress = 0

    if running or paused then
        headline = formatRemaining(remaining)
        status = running and "Running" or "Paused"

        if (t.totalMs or 0) > 0 then
            progress = math.min(1, math.max(0, 1 - remaining / t.totalMs))
        end
    else
        -- Idle: preview the duration currently typed in the box.
        local pending = parseDuration(pendingText)
        headline = pending and formatRemaining(pending * 1000) or "0:00"
        status = (t.done == true) and "Time's up!" or "Ready"
    end

    local mainLabel = "Start"
    if running then
        mainLabel = "Pause"
    elseif paused then
        mainLabel = "Resume"
    end

    panel.render(ui.scroll({ gap = SECTION_GAP, padding = PANEL_PADDING }, {
        ui.row({ gap = TITLE_GAP, align = "center" }, {
            ui.glyph({ name = "stopwatch", size = 18, color = "primary" }),
            ui.label({ text = "Timer", fontSize = 15, fontWeight = "bold", flexGrow = 1 }),
            ui.label({ text = status, fontSize = 12, color = "on_surface/0.65" }),
        }),

        ui.row({ justify = "center" }, {
            ui.label({ text = headline, fontSize = 40, fontWeight = "bold" }),
        }),

        ui.progress({ progress = progress, height = 6 }),

        ui.column({ gap = PRESET_GAP }, {
            ui.row({ gap = PRESET_GAP }, {
                presetButton(5, idle),
                presetButton(25, idle),
            }),
            ui.row({ gap = PRESET_GAP }, {
                presetButton(50, idle),
                presetButton(90, idle),
            }),
        }),

        ui.input({
            key = "duration-input",
            value = pendingText,
            placeholder = "Custom: 90s, 15m, 1h30m",
            controlSize = "sm",
            enabled = idle,
            onChange = function(value)
                pendingText = value
            end,
            onSubmit = function(value)
                pendingText = value
                toggle()
            end,
        }),

        ui.row({ gap = ACTION_GAP }, {
            ui.button({
                key = "toggle",
                text = mainLabel,
                variant = "primary",
                flexGrow = 1,
                onClick = function()
                    toggle()
                end,
            }),
            ui.button({
                key = "reset",
                text = "Reset",
                variant = "outline",
                flexGrow = 1,
                enabled = (not idle) or t.done == true,
                onClick = function()
                    reset()
                end,
            }),
        }),
    }))
end

function update()
    noctalia.setUpdateInterval(500)
    render()
end

function onOpen(context)
    render()
end
