-- widget.luau
-- Bar entry: small glyph, live "NN%" while a download is running, click opens the panel.

local function render()
    local downloading = noctalia.state.get("downloading") == true
    barWidget.setGlyph("cloud-download")
    if downloading then
        local progress = tonumber(noctalia.state.get("progress")) or 0
        barWidget.setText(tostring(math.floor(progress * 100 + 0.5)) .. "%")
        barWidget.setTooltip(noctalia.state.get("status_text") or "Downloading…")
    else
        barWidget.setText("")
        barWidget.clearTooltip()
    end
end

-- Re-render instantly whenever the background service publishes new state
noctalia.state.watch("downloading", function() render() end)
noctalia.state.watch("progress", function() render() end)

function update()
    noctalia.setUpdateInterval(1000)
    render()
end

function onClick()
    noctalia.togglePanel("dxryk/yt-downloader:panel")
end
