local ICON = "/home/chris/nixos-dotfiles/config/fastfetch/obs.svg"

function update()
    barWidget.setImage(ICON, true, 17, 17)
    barWidget.setText("")
    barWidget.setTooltip("Obsidian Quick Access")
end

function onClick()
    noctalia.togglePanel("chris/obsidian:panel")
end
