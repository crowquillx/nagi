--!nonstrict
-- Hyprland monitor-local workspace pills for Noctalia.
--
-- Each bar instance is bound to one output (barWidget.outputName()). This
-- widget shows only that monitor's workspaces, labels them as 1–99
-- (globalId - workspaceBase), and dispatches hyprctl focus using the real
-- global Hyprland workspace IDs.
--
-- State is polled via hyprctl JSON. Scroll and click stay monitor-local.

-- Substituted at package build time to an absolute hyprctl path.
local HYPRCTL = "@hyprctl@"

local pollInFlight = false
local lastFingerprint = ""
local cachedItems = {}
local activeGlobalId = nil

local function asNumber(value)
  return tonumber(value)
end

local function asBool(value, default)
  if value == nil then
    return default
  end
  return value and true or false
end

local function asInt(value, default)
  local n = asNumber(value)
  if n == nil then
    return default
  end
  return math.floor(n)
end

local function clamp(n, lo, hi)
  if n < lo then
    return lo
  end
  if n > hi then
    return hi
  end
  return n
end

local function colorOr(value, fallback)
  if type(value) == "string" and value ~= "" then
    return value
  end
  return fallback
end

local function workspaceBases()
  local configured = noctalia.getConfig("workspace_bases")
  local bases = {}
  if type(configured) == "table" then
    for name, raw in pairs(configured) do
      local base = asNumber(raw)
      if type(name) == "string" and base ~= nil then
        bases[name] = math.floor(base)
      end
    end
  end
  if next(bases) == nil then
    bases = {
      ["DP-3"] = 0,
      ["DP-2"] = 100,
      ["DP-1"] = 200,
    }
  end
  return bases
end

local function baseForOutput(outputName)
  if outputName == nil or outputName == "" then
    return nil
  end
  return workspaceBases()[outputName]
end

local function localLabel(globalId, base)
  return globalId - base
end

local function isSpecialName(name)
  return type(name) == "string" and string.sub(name, 1, 8) == "special:"
end

local function fillFor(item, colors)
  if item.urgent then
    return colors.urgent
  end
  if item.active then
    return colors.focused
  end
  if item.occupied then
    return colors.occupied
  end
  return colors.empty
end

local function textFor(item)
  if item.urgent then
    return "on_error"
  end
  if item.active then
    return "on_primary"
  end
  return "on_secondary"
end

local function focusWorkspace(globalId)
  if globalId == nil then
    return
  end
  noctalia.runAsync(HYPRCTL .. " dispatch workspace " .. tostring(globalId))
end

local function renderItems(items)
  local hideWhenEmpty = asBool(noctalia.getConfig("hide_when_empty"), false)
  local gap = clamp(asInt(noctalia.getConfig("gap"), 4), 0, 24)
  local colors = {
    focused = colorOr(noctalia.getConfig("focused_color"), "primary"),
    occupied = colorOr(noctalia.getConfig("occupied_color"), "secondary"),
    empty = colorOr(noctalia.getConfig("empty_color"), "secondary"),
    urgent = colorOr(noctalia.getConfig("urgent_color"), "error"),
  }

  local visible = {}
  for _, item in ipairs(items) do
    if not hideWhenEmpty or item.active or item.occupied or item.urgent then
      table.insert(visible, item)
    end
  end

  if #visible == 0 then
    barWidget.setVisible(false)
    barWidget.render(ui.row({ gap = 0, align = "center" }, {}))
    return
  end

  barWidget.setVisible(true)

  -- Installed Noctalia treats ui.box as a leaf (no children / no paddingH).
  -- Match official plugins: use a filled ui.row as the clickable pill.
  local children = {}
  for _, item in ipairs(visible) do
    local fill = fillFor(item, colors)
    local weight = item.active and "bold" or "medium"
    local paddingH = item.active and 10 or 8
    local globalId = item.globalId
    table.insert(
      children,
      ui.row({
        key = "ws-" .. tostring(globalId),
        fill = fill,
        radius = 999,
        paddingH = paddingH,
        paddingV = 2,
        align = "center",
        onClick = function()
          focusWorkspace(globalId)
        end,
      }, {
        ui.label({
          text = tostring(item.label),
          color = textFor(item),
          fontWeight = weight,
        }),
      })
    )
  end

  local container = barWidget.isVertical() and ui.column or ui.row
  barWidget.render(container({ gap = gap, align = "center" }, children))
end

local function switchRelative(delta)
  if #cachedItems == 0 or activeGlobalId == nil then
    return
  end

  local index = nil
  for i, item in ipairs(cachedItems) do
    if item.globalId == activeGlobalId then
      index = i
      break
    end
  end
  if index == nil then
    index = 1
  end

  local target = index + delta
  if target < 1 or target > #cachedItems then
    return
  end
  focusWorkspace(cachedItems[target].globalId)
end

local function buildItems(workspacesJson, monitorsJson, clientsJson, outputName, base)
  local workspaces, wsErr = noctalia.json.decode(workspacesJson)
  local monitors, monErr = noctalia.json.decode(monitorsJson)
  local clients = noctalia.json.decode(clientsJson)

  if wsErr ~= nil or monErr ~= nil or type(workspaces) ~= "table" or type(monitors) ~= "table" then
    return {}, nil, "decode-failed"
  end

  local activeId = nil
  for _, monitor in ipairs(monitors) do
    if type(monitor) == "table" and monitor.name == outputName then
      local aw = monitor.activeWorkspace
      if type(aw) == "table" then
        activeId = asNumber(aw.id)
      end
      break
    end
  end

  local occupiedFromClients = {}
  local urgentFromClients = {}
  if type(clients) == "table" then
    for _, client in ipairs(clients) do
      if type(client) == "table" and type(client.workspace) == "table" then
        local wid = asNumber(client.workspace.id)
        if wid ~= nil and wid > 0 then
          occupiedFromClients[wid] = true
          if client.urgent == true then
            urgentFromClients[wid] = true
          end
        end
      end
    end
  end

  local items = {}
  for _, ws in ipairs(workspaces) do
    if type(ws) == "table" then
      local id = asNumber(ws.id)
      local name = ws.name
      local monitor = ws.monitor
      if id ~= nil and id > 0 and not isSpecialName(name) and monitor == outputName then
        local label = localLabel(id, base)
        if label >= 1 and label <= 99 then
          local windows = asNumber(ws.windows) or 0
          local isOccupied = windows > 0 or occupiedFromClients[id] == true
          local isActive = activeId ~= nil and id == activeId
          local isUrgent = urgentFromClients[id] == true
          table.insert(items, {
            globalId = id,
            label = label,
            active = isActive,
            occupied = isOccupied,
            urgent = isUrgent,
          })
        end
      end
    end
  end

  table.sort(items, function(a, b)
    return a.globalId < b.globalId
  end)

  local fingerprintParts = {
    outputName,
    tostring(base),
    tostring(activeId or -1),
  }
  for _, item in ipairs(items) do
    table.insert(
      fingerprintParts,
      string.format(
        "%d:%d:%d%d%d",
        item.globalId,
        item.label,
        item.active and 1 or 0,
        item.occupied and 1 or 0,
        item.urgent and 1 or 0
      )
    )
  end

  return items, activeId, table.concat(fingerprintParts, "|")
end

local function applyState(items, activeId, fingerprint)
  activeGlobalId = activeId
  cachedItems = items
  if fingerprint == lastFingerprint then
    return
  end
  lastFingerprint = fingerprint
  renderItems(items)
end

local function pollWorkspaces()
  if pollInFlight then
    return
  end

  local outputName = barWidget.outputName()
  if outputName == nil or outputName == "" then
    barWidget.setVisible(false)
    return
  end

  local base = baseForOutput(outputName)
  if base == nil then
    -- Unknown monitor for this mapping: hide rather than show wrong labels.
    barWidget.setVisible(false)
    return
  end

  pollInFlight = true

  -- One shell round-trip; split on a sentinel so we stay under the per-call budget.
  local cmd = string.format(
    "%s -j workspaces; printf '\\n__NAGI_SPLIT__\\n'; %s -j monitors; printf '\\n__NAGI_SPLIT__\\n'; %s -j clients",
    HYPRCTL,
    HYPRCTL,
    HYPRCTL
  )

  noctalia.runAsync(cmd, function(result)
    pollInFlight = false
    if not result or result.exitCode ~= 0 then
      return
    end

    local stdout = result.stdout or ""
    local parts = {}
    local rest = stdout
    while true do
      local before, after = string.match(rest, "^(.-)\n__NAGI_SPLIT__\n(.*)$")
      if before == nil then
        table.insert(parts, rest)
        break
      end
      table.insert(parts, before)
      rest = after
    end

    local workspacesJson = parts[1] or ""
    local monitorsJson = parts[2] or ""
    local clientsJson = parts[3] or "[]"

    local items, activeId, fingerprint = buildItems(workspacesJson, monitorsJson, clientsJson, outputName, base)
    if fingerprint == "decode-failed" then
      noctalia.log("hyprland-local-workspaces: failed to decode hyprctl JSON")
      return
    end
    applyState(items, activeId, fingerprint)
  end, 2000)
end

function update()
  local pollMs = clamp(asInt(noctalia.getConfig("poll_ms"), 250), 50, 2000)
  noctalia.setUpdateInterval(pollMs)
  pollWorkspaces()
end

function onScroll(axis, steps)
  if axis ~= "vertical" and axis ~= "horizontal" then
    return
  end
  local n = asNumber(steps) or 0
  if n == 0 then
    return
  end
  -- Negative steps = up/left → previous workspace (matches built-in workspaces).
  if n < 0 then
    switchRelative(-1)
  else
    switchRelative(1)
  end
end
