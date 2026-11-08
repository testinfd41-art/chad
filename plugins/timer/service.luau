-- Timer engine (background service).
--
-- Owns "time is up": it watches the shared timer state, then shows the
-- notification and plays the completion sound. It runs whenever the plugin is
-- enabled, so the alarm works even if the bar widget is hidden and the panel
-- is closed. widget.luau and panel.luau only display and control the timer.
--
-- Shared state (noctalia.state key "timer"), always written as one whole table:
--   running      bool    counting down right now
--   endMs        number  wall-clock ms when it reaches zero (while running)
--   remainingMs  number  ms left (while paused)
--   totalMs      number  length of the current run, for the progress bar
--   done         bool    the last run has just finished

local SOUND_PATH = "/home/chris/nixos-dotfiles/config/niri/beep.mp3"
local LOAD_TIMEOUT_MS = 10000

local soundName = nil          -- set once the file has been decoded
local soundLoading = false
local loadStartedMs = 0
local waiting = {}             -- callbacks queued until the load settles
local attempt = 0              -- gives every load request a fresh sound name
local lastFinishedEnd = 0      -- guards against finishing the same run twice
local warnedSoundsOff = false

local function settleLoading(ok)
    soundLoading = false

    local callbacks = waiting
    waiting = {}
    for _, callback in ipairs(callbacks) do
        callback(ok)
    end
end

-- Calls onDone(true) once the sound is decoded, or onDone(false) if it can't be.
local function ensureSound(onDone)
    if soundName ~= nil then
        if onDone then
            onDone(true)
        end
        return
    end

    if onDone then
        table.insert(waiting, onDone)
    end

    -- A load is already in flight; don't start another unless it looks stuck.
    if soundLoading and (noctalia.nowMs() - loadStartedMs) < LOAD_TIMEOUT_MS then
        return
    end

    if not noctalia.fileExists(SOUND_PATH) then
        noctalia.log("Timer: sound file not found: " .. SOUND_PATH)
        noctalia.notifyError("Timer sound", "Sound file not found: " .. SOUND_PATH)
        settleLoading(false)
        return
    end

    soundLoading = true
    loadStartedMs = noctalia.nowMs()

    attempt = attempt + 1
    local name = "timer-complete-" .. tostring(attempt)

    local accepted = noctalia.sound.load(name, SOUND_PATH, function(ok, err)
        if ok then
            soundName = name
            settleLoading(true)
        else
            noctalia.log("Timer: failed to decode sound '" .. SOUND_PATH .. "': " .. tostring(err))
            noctalia.notifyError("Timer sound", tostring(err or "Could not load the sound file."))
            settleLoading(false)
        end
    end)

    if not accepted then
        noctalia.log("Timer: sound.load() rejected the request for " .. SOUND_PATH)
        noctalia.notifyError("Timer sound", "Noctalia rejected the sound load request.")
        settleLoading(false)
    end
end

-- Playback also honours Noctalia's global [audio] settings, so a silent alarm
-- can simply mean sounds are switched off there. Flag it once instead of failing quietly.
local function soundsOffInShell()
    if noctalia.getSetting == nil then
        return false
    end

    local ok, value = pcall(noctalia.getSetting, "audio.enable_sounds")
    return ok and value == false
end

local function playCompletionSound()
    if noctalia.getConfig("play_sound") == false then
        return
    end

    if soundsOffInShell() and not warnedSoundsOff then
        warnedSoundsOff = true
        noctalia.log("Timer: [audio] enable_sounds is false in the shell config, so the completion sound is muted.")
        noctalia.notifyError("Timer sound", "Sounds are turned off in Noctalia's audio settings (enable_sounds).")
    end

    ensureSound(function(ok)
        if ok then
            noctalia.sound.play(soundName)
        end
    end)
end

local function finish(t)
    lastFinishedEnd = t.endMs or 0

    noctalia.state.set("timer", {
        running = false,
        endMs = 0,
        remainingMs = 0,
        totalMs = 0,
        done = true,
    })

    noctalia.notify("Timer", "Time's up!")
    playCompletionSound()
end

function update()
    noctalia.setUpdateInterval(500)

    local t = noctalia.state.get("timer")
    if type(t) ~= "table" or t.running ~= true then
        return
    end

    local endMs = t.endMs or 0
    if endMs ~= lastFinishedEnd and noctalia.nowMs() >= endMs then
        finish(t)
    end
end

function onConfigChanged()
    -- The play_sound setting may have changed; start decoding if it was just turned on.
    warnedSoundsOff = false

    if noctalia.getConfig("play_sound") ~= false then
        ensureSound()
    end
end

-- Decode the sound up front so the alarm can play the instant time is up.
if noctalia.getConfig("play_sound") ~= false then
    ensureSound()
end
