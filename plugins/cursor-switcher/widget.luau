function update()
    barWidget.setGlyph("mouse-2")
    barWidget.setTooltip("Cursor Themes")
end

function onClick()
    noctalia.togglePanel("chris/cursor-switcher:panel")
end
