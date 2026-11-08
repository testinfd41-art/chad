-- panel.luau
-- Pop-up UI: paste a link, hit download, watch progress. The actual yt-dlp
-- process runs in service.luau (a headless service) so it keeps going even
-- after this panel is closed — this script only reads/writes shared state.

local urlDraft = ""

local function statusColor(errorText)
    if errorText ~= "" then
        return "error"
    end
    return "on_surface_variant"
end

local function render()
    local downloading = noctalia.state.get("downloading") == true
    local progress = tonumber(noctalia.state.get("progress")) or 0
    local errorText = noctalia.state.get("error_text") or ""
    local statusText = noctalia.state.get("status_text") or ""
    local message = errorText ~= "" and errorText or statusText

    panel.render(ui.column({ gap = 12, padding = 16 }, {
        ui.row({ align = "center", justify = "space_between" }, {
            ui.label({ text = "YouTube Downloader", fontSize = 16, fontWeight = "bold", flexGrow = 1 }),
            ui.button({ glyph = "close", variant = "ghost", onClick = "onCloseClicked" }),
        }),
        ui.row({ gap = 8, align = "center" }, {
            ui.input({
                key = "url_input",
                value = urlDraft,
                placeholder = "Paste YouTube link…",
                enabled = not downloading,
                flexGrow = 1,
                onChange = "onUrlChanged",
                onSubmit = "onSubmit",
            }),
            ui.button({
                glyph = downloading and "hourglass" or "download",
                variant = "primary",
                enabled = not downloading,
                onClick = "onDownloadClicked",
            }),
        }),
        ui.progress({
            progress = progress,
            visible = downloading or progress > 0,
        }),
        ui.label({
            text = message,
            fontSize = 12,
            color = statusColor(errorText),
            maxLines = 2,
        }),
    }))
end

function onOpen(context)
    render()
end

function onUrlChanged(value)
    urlDraft = value
end

function onSubmit(value)
    urlDraft = value
    noctalia.state.set("start_download", value)
    render()
end

function onDownloadClicked()
    if urlDraft ~= "" then
        noctalia.state.set("start_download", urlDraft)
        urlDraft = ""
    end
    render()
end

function onCloseClicked()
    panel.close()
end

-- Re-render whenever the service publishes new progress/status
noctalia.state.watch("downloading", function() render() end)
noctalia.state.watch("progress", function() render() end)
noctalia.state.watch("status_text", function() render() end)
noctalia.state.watch("error_text", function() render() end)
