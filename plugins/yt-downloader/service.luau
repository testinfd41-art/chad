-- service.luau
-- Headless background entry. Watches for a URL published to "start_download"
-- (by the panel or, in principle, any other entry), runs yt-dlp via
-- noctalia.runStream, and publishes progress/status back through
-- noctalia.state so the widget and panel can render it live.
--
-- NOTE on completion detection: the documented runStream() API delivers
-- stdout lines but has no separate "process exited" callback, so this
-- script infers completion from yt-dlp's own output (a final 100% download
-- line with no merge step, or a completed merge). This is a best-effort
-- heuristic, not a guaranteed exit signal — if a future Noctalia release
-- adds a completion/exit callback to runStream, switch to that instead.

local progressPattern = "%[download%]%s+([%d%.]+)%%"
local destPattern = "Destination:%s*(.+)$"

local function shellQuote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function trim(s)
    return (tostring(s):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function formatSelector(audioOnly, maxHeight)
    if audioOnly then
        return "bestaudio/best"
    elseif maxHeight and maxHeight > 0 then
        return "bestvideo*[height<=" .. maxHeight .. "]+bestaudio/best"
    else
        return "bestvideo*+bestaudio/best"
    end
end

local function resetState()
    noctalia.state.set("downloading", false)
    noctalia.state.set("progress", 0)
    noctalia.state.set("status_text", "")
    noctalia.state.set("error_text", "")
    noctalia.state.set("last_file", "")
end

resetState()

local function finish(ok, message)
    noctalia.state.set("downloading", false)
    if ok then
        noctalia.state.set("progress", 1)
        noctalia.state.set("status_text", message or "Done")
        noctalia.notify("YouTube Downloader", message or "Download complete")
    else
        noctalia.state.set("error_text", message or "Download failed")
        noctalia.notifyError("YouTube Downloader", message or "Download failed")
    end
end

local function startDownload(url)
    if noctalia.state.get("downloading") == true then
        return -- one download at a time
    end

    url = trim(url or "")
    if url == "" then
        return
    end

    if not noctalia.commandExists("yt-dlp") then
        finish(false, "yt-dlp not found on PATH — install it first")
        return
    end

    local outputDir = noctalia.expandPath(noctalia.getConfig("output_dir") or "~/Downloads/YtDlp")
    local maxHeight = tonumber(noctalia.getConfig("max_height")) or 0
    local audioOnly = noctalia.getConfig("audio_only") == true

    noctalia.mkdirAll(outputDir)

    noctalia.state.set("downloading", true)
    noctalia.state.set("progress", 0)
    noctalia.state.set("status_text", "Starting…")
    noctalia.state.set("error_text", "")
    noctalia.state.set("last_file", "")

    local mergeArgs = audioOnly and "" or "--merge-output-format mp4 "
    local outTemplate = outputDir .. "/%(title)s.%(ext)s"

    local cmd = "yt-dlp -f " .. shellQuote(formatSelector(audioOnly, maxHeight)) ..
        " " .. mergeArgs ..
        "--newline --no-playlist -o " .. shellQuote(outTemplate) ..
        " " .. shellQuote(url)

    local mergeSeen = false

    local accepted = noctalia.runStream(cmd, function(line)
        line = trim(tostring(line))
        if line == "" then
            return
        end

        local pct = line:match(progressPattern)
        if pct then
            noctalia.state.set("progress", tonumber(pct) / 100)
            noctalia.state.set("status_text", line)
            return
        end

        local dest = line:match(destPattern)
        if dest then
            noctalia.state.set("last_file", dest)
            noctalia.state.set("status_text", "Downloading: " .. dest)
            return
        end

        if line:find("Merging formats") or line:find("%[Merger%]") then
            mergeSeen = true
            noctalia.state.set("status_text", "Merging audio + video…")
            return
        end

        if line:find("has already been downloaded") then
            finish(true, "Already downloaded")
            return
        end

        -- Heuristic completion: once a merge has started, the next
        -- "Deleting original file" line is yt-dlp's last real step.
        if mergeSeen and line:find("Deleting original file") then
            local lastFile = noctalia.state.get("last_file") or ""
            finish(true, lastFile ~= "" and ("Done: " .. lastFile) or "Done")
            return
        end
    end)

    if not accepted then
        finish(false, "Could not start yt-dlp")
    elseif audioOnly then
        -- No merge step for audio-only — fall back to marking done shortly
        -- after the last 100% line if nothing else fires. Left as a manual
        -- "still downloading?" indicator rather than a hard timeout, since
        -- there is no exit callback to rely on.
    end
end

noctalia.state.watch("start_download", function(url)
    startDownload(url)
end)
