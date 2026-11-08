-- Timer bar widget.
-- Shows the remaining time next to the clock icon (a pause icon while paused).
-- Left click opens the panel; right click pauses/resumes.
-- The "time is up" notification and sound are handled by service.luau.

local lastTooltip = nil

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

local function setTooltip(text)
    if text ~= lastTooltip then
        lastTooltip = text
        barWidget.setTooltip(text)
    end
end

function update()
    noctalia.setUpdateInterval(500)

    local t = getTimer()
    local remaining = remainingMs(t)

    if t.running == true then
        barWidget.setGlyph("stopwatch")
        barWidget.setText(formatRemaining(remaining))
        setTooltip("Timer running. Right click to pause.")
    elseif remaining > 0 then
        barWidget.setGlyph("player-pause")
        barWidget.setText(formatRemaining(remaining))
        setTooltip("Timer paused. Right click to resume.")
    else
        barWidget.setGlyph("stopwatch")
        barWidget.setText("")
        setTooltip("Timer. Click to open.")
    end
end

function onClick()
    noctalia.togglePanel("chris/timer:panel")
end

function onRightClick()
    local t = getTimer()
    local now = noctalia.nowMs()

    if t.running == true then
        noctalia.state.set("timer", {
            running = false,
            endMs = 0,
            remainingMs = math.max(0, (t.endMs or 0) - now),
            totalMs = t.totalMs or 0,
        })
    elseif (t.remainingMs or 0) > 0 then
        noctalia.state.set("timer", {
            running = true,
            endMs = now + t.remainingMs,
            remainingMs = 0,
            totalMs = t.totalMs or 0,
        })
    end

    update()
end
