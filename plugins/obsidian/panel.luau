local ROOT = "/home/chris/Obsidian Vault"
local DRAFT = "/home/chris/.cache/noctalia-obsidian-draft.txt"

local vaults = {}
local notes = {}
local selectedVault = ROOT
local vaultName = ""
local noteTitle = ""
local noteBody = ""
local viewText = ""
local showCreate = false  -- vault name field
local newMode = false     -- new note title field
local viewMode = false    -- read the selected note instead of writing
local targetIndex = 0     -- 0 = today's daily note, 1+ = existing note
local gen = 0             -- bumped to force inputs to reset
local justOpened = false
local status = "Choose a vault or create one."
local WRITE_H = 260
local VIEW_H = 460

local function cleanName(value)
    value = (value or ""):match("^%s*(.-)%s*$")
    value = value:gsub("/", "-"):gsub("\\", "-")
    value = value:gsub("^%.+", "")
    return value
end

local function today()
    return os.date("%Y-%m-%d")
end

local function vaultLabel(path)
    return path:match("([^/]+)$") or path
end

-- draft persistence ---------------------------------------------------

local function saveDraft()
    local title = (noteTitle or ""):gsub("\n", " ")
    local data = (newMode and "new" or "append") .. "\n" .. title .. "\n" .. (noteBody or "")
    noctalia.writeFile(DRAFT, data)
end

local function loadDraft()
    if type(noctalia.readFile) ~= "function" then
        return
    end
    if not noctalia.fileExists(DRAFT) then
        return
    end

    local raw = noctalia.readFile(DRAFT)
    if not raw or raw == "" then
        return
    end

    local mode, title, body = raw:match("^([^\n]*)\n([^\n]*)\n?(.*)$")
    if mode then
        newMode = (mode == "new")
        noteTitle = title or ""
        noteBody = body or ""
        gen = gen + 1
        if noteBody ~= "" or noteTitle ~= "" then
            status = "Draft restored."
        end
    end
end

-- vaults / notes ------------------------------------------------------

local function refreshVaults()
    vaults = { ROOT }

    local entries = noctalia.listDir(ROOT) or {}

    for _, name in ipairs(entries) do
        local path = ROOT .. "/" .. name
        local info = noctalia.fileInfo(path)

        if info and info.isDir
            and noctalia.fileExists(path .. "/.obsidian") then
            table.insert(vaults, path)
        end
    end

    table.sort(vaults)
end

local function refreshNotes()
    notes = {}

    local entries = noctalia.listDir(selectedVault) or {}

    for _, name in ipairs(entries) do
        if name:match("%.md$") then
            table.insert(notes, (name:gsub("%.md$", "")))
        end
    end

    table.sort(notes, function(a, b) return a > b end)

    if targetIndex > #notes then
        targetIndex = 0
    end
end

local function vaultNames()
    local names = {}
    for _, path in ipairs(vaults) do
        table.insert(names, vaultLabel(path))
    end
    return names
end

local function selectedIndex()
    for i, path in ipairs(vaults) do
        if path == selectedVault then
            return i - 1
        end
    end
    return 0
end

local function targetOptions()
    local opts = { "Today's daily note (" .. today() .. ")" }
    for _, n in ipairs(notes) do
        table.insert(opts, n)
    end
    return opts
end

local function currentTargetName()
    if targetIndex == 0 then
        return today()
    end
    return notes[targetIndex]
end

local function loadView()
    local name = currentTargetName()
    if not name then
        viewText = "(no note selected)"
        return
    end

    local path = selectedVault .. "/" .. name .. ".md"

    if not noctalia.fileExists(path) then
        viewText = "(this note doesn't exist yet)"
        return
    end

    if type(noctalia.readFile) ~= "function" then
        viewText = "(noctalia.readFile is not available)"
        return
    end

    viewText = noctalia.readFile(path) or "(could not read this note)"
end

local render

local function createVault()
    local name = cleanName(vaultName)

    if name == "" or name == "." or name == ".." then
        status = "Enter a valid vault name."
        render()
        return
    end

    local path = ROOT .. "/" .. name

    if noctalia.fileExists(path) then
        status = "That folder already exists."
        render()
        return
    end

    if not noctalia.mkdirAll(path .. "/.obsidian") then
        status = "Could not create the vault."
        render()
        return
    end

    noctalia.writeFile(path .. "/Welcome.md",
        "# " .. name .. "\n\nYour new Obsidian vault is ready.\n")

    selectedVault = path
    vaultName = ""
    showCreate = false
    targetIndex = 0
    gen = gen + 1
    refreshVaults()
    refreshNotes()
    status = "Created vault: " .. name
    render()
end

local function saveNewNote()
    local title = cleanName(noteTitle)

    if title == "" or title == "." or title == ".." then
        status = "Enter a valid note title."
        render()
        return
    end

    local path = selectedVault .. "/" .. title .. ".md"

    if noctalia.fileExists(path) then
        status = "A note with that name already exists."
        render()
        return
    end

    if noctalia.writeFile(path, noteBody .. "\n") then
        status = "Saved: " .. title .. ".md"
        noteTitle = ""
        noteBody = ""
        newMode = false
        gen = gen + 1
        saveDraft()
        refreshNotes()
    else
        status = "Could not save the note."
    end

    render()
end

local function appendToNote()
    local name = currentTargetName()

    if not name then
        status = "Pick a valid target."
        render()
        return
    end

    local path = selectedVault .. "/" .. name .. ".md"
    local existing = ""

    if noctalia.fileExists(path) then
        if type(noctalia.readFile) ~= "function" then
            status = "Appending needs noctalia.readFile (not available)."
            render()
            return
        end
        existing = noctalia.readFile(path)
        if existing == nil then
            status = "Could not read " .. name .. ".md"
            render()
            return
        end
    end

    if existing ~= "" and not existing:match("\n$") then
        existing = existing .. "\n"
    end

    local sep = (existing ~= "") and "\n" or ""

    if noctalia.writeFile(path, existing .. sep .. noteBody .. "\n") then
        status = "Added to: " .. name .. ".md"
        noteBody = ""
        gen = gen + 1
        saveDraft()
        refreshNotes()
        if viewMode then
            loadView()
        end
    else
        status = "Could not write to " .. name .. ".md"
    end

    render()
end

local function save()
    if viewMode then
        status = "Switch back to writing first (pencil icon)."
        render()
        return
    end

    if noteBody == "" then
        status = "Write something before saving."
        render()
        return
    end

    if newMode then
        saveNewNote()
    else
        appendToNote()
    end
end

local function clearNote()
    noteTitle = ""
    noteBody = ""
    gen = gen + 1
    saveDraft()
    status = "Cleared."
    render()
end

render = function()
    local children = {
        -- header: title, save, clear, refresh
        ui.row({ gap = 8, align = "center" }, {
            ui.glyph({ name = "notes", size = 22, color = "primary" }),
            ui.label({
                text = "Obsidian",
                fontSize = 18,
                fontWeight = "bold",
                flexGrow = 1
            }),
            ui.button({
                text = newMode and "Save" or "Add",
                variant = "primary",
                onClick = save
            }),
            ui.button({
                glyph = "trash",
                variant = "ghost",
                onClick = clearNote
            }),
            ui.button({
                glyph = "refresh",
                variant = "ghost",
                onClick = function()
                    refreshVaults()
                    refreshNotes()
                    if viewMode then
                        loadView()
                        gen = gen + 1
                    end
                    status = "Refreshed."
                    render()
                end
            })
        }),

        ui.separator({}),

        -- vault picker + create-vault icon
        ui.row({ gap = 8, align = "center" }, {
            ui.select({
                options = vaultNames(),
                selectedIndex = selectedIndex(),
                flexGrow = 1,
                onChange = function(index, text)
                    local i = tonumber(index)
                    if i then
                        selectedVault = vaults[i + 1]
                        targetIndex = 0
                        refreshNotes()
                        if viewMode then
                            loadView()
                            gen = gen + 1
                        end
                        status = "Selected: " .. text
                        render()
                    end
                end
            }),
            ui.button({
                glyph = showCreate and "x" or "folder-plus",
                variant = "secondary",
                onClick = function()
                    showCreate = not showCreate
                    vaultName = ""
                    gen = gen + 1
                    render()
                end
            })
        }),
    }

    if showCreate then
        table.insert(children, ui.row({ gap = 8, align = "center" }, {
            ui.input({
                key = "vault-name-" .. gen,
                value = vaultName,
                placeholder = "New vault name",
                flexGrow = 1,
                onChange = function(value)
                    vaultName = value
                end
            }),
            ui.button({
                glyph = "check",
                variant = "primary",
                onClick = createVault
            })
        }))
    end

    -- target: existing file / daily  OR  new note title
    if newMode then
        table.insert(children, ui.row({ gap = 8, align = "center" }, {
            ui.input({
                key = "note-title-" .. gen,
                value = noteTitle,
                placeholder = "New note title",
                flexGrow = 1,
                onChange = function(value)
                    noteTitle = value
                    saveDraft()
                end
            }),
            ui.button({
                glyph = "x",
                variant = "secondary",
                onClick = function()
                    newMode = false
                    noteTitle = ""
                    gen = gen + 1
                    saveDraft()
                    status = "Back to existing notes."
                    render()
                end
            })
        }))
    else
        table.insert(children, ui.row({ gap = 8, align = "center" }, {
            ui.select({
                options = targetOptions(),
                selectedIndex = targetIndex,
                flexGrow = 1,
                onChange = function(index, text)
                    local i = tonumber(index)
                    if i then
                        targetIndex = i
                        if viewMode then
                            loadView()
                            gen = gen + 1
                        end
                        status = "Selected: " .. text
                        render()
                    end
                end
            }),
            ui.button({
                glyph = viewMode and "pencil" or "eye",
                variant = viewMode and "primary" or "secondary",
                onClick = function()
                    viewMode = not viewMode
                    if viewMode then
                        loadView()
                        status = "Viewing note."
                    else
                        status = "Writing."
                    end
                    gen = gen + 1
                    render()
                end
            }),
            ui.button({
                glyph = "file-plus",
                variant = "secondary",
                onClick = function()
                    newMode = true
                    viewMode = false
                    noteTitle = ""
                    gen = gen + 1
                    saveDraft()
                    status = "Creating a new note."
                    render()
                end
            })
        }))
    end

    if viewMode and not newMode then
        table.insert(children, ui.input({
            key = "note-view-" .. gen,
            value = viewText,
            multiline = true,
            height = VIEW_H,
            onChange = function(value)
                -- read-only: ignore edits
            end
        }))
    else
        table.insert(children, ui.input({
            key = "note-body-" .. gen,
            value = noteBody,
            placeholder = "Write your note here...",
            multiline = true,
            height = WRITE_H,
            onChange = function(value)
                if justOpened and value == "" and noteBody ~= "" then
                    justOpened = false
                    return
                end
                justOpened = false
                noteBody = value
                saveDraft()
            end
        }))
    end

    table.insert(children, ui.separator({}))

    table.insert(children, ui.row({ gap = 6, align = "center" }, {
        ui.glyph({ name = "info", size = 13, color = "secondary" }),
        ui.label({
            text = status,
            color = "secondary",
            fontSize = 12
        })
    }))

    panel.render(ui.column({ gap = 8, padding = 16, fill = true }, children))
end

function onOpen()
    noctalia.mkdirAll("/home/chris/.cache")
    refreshVaults()
    refreshNotes()
    loadDraft()
    render()

    -- second pass: rebuild inputs so restored text actually shows
    gen = gen + 1
    render()
    justOpened = true
end
