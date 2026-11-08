local apps = {}      -- window id -> app_id
local focused = nil
local last = nil

local EMPTY_TEXT = "Desktop"   -- change to whatever you want

local function show()
  local id = focused and apps[focused] or ""
  local name = id:match("[^.]+$") or id      -- org.mozilla.firefox -> firefox
  if name == "" then
    name = EMPTY_TEXT
  else
    name = (name:gsub("^%l", string.upper))
  end
  if name == last then return end            -- skip tab-title churn
  last = name
  barWidget.setVisible(true)
  barWidget.setText(name)
end

show()  -- show EMPTY_TEXT immediately on load

noctalia.runStream("niri msg -j event-stream", function(line)
  if line:find("WindowFocusChanged", 1, true) then
    focused = tonumber(line:match('"id":(%d+)'))
  elseif line:find("WindowOpenedOrChanged", 1, true) then
    local id = tonumber(line:match('"window":{"id":(%d+)'))
    if id then apps[id] = line:match('"app_id":"([^"]*)"') or "" end
  elseif line:find("WindowClosed", 1, true) then
    local id = tonumber(line:match('"id":(%d+)'))
    if id then apps[id] = nil end
  elseif line:find("WindowsChanged", 1, true) then
    for id, app in line:gmatch('"id":(%d+),"title":".-","app_id":"([^"]*)"') do
      apps[tonumber(id)] = app
    end
  else
    return
  end
  show()
end)
