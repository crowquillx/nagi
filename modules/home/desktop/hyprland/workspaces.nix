{
  lib,
  vars,
  quote,
  ...
}:
let
  outputs = lib.attrByPath [ "desktop" "hyprland" "outputs" ] { } vars;
  workspaceOutputs = lib.filterAttrs (_: output: (output.workspaceBase or null) != null) outputs;
  mkWorkspaceRules =
    name: output:
    let
      first = output.workspaceBase + 1;
      last = output.workspaceBase + 99;
    in
    ''
      hl.workspace_rule({ workspace = ${quote "r[${toString first}-${toString last}]"}, monitor = ${quote name} })
      hl.workspace_rule({ workspace = ${quote (toString first)}, monitor = ${quote name}, default = true })
    '';
  workspaceRules = lib.concatStringsSep "\n" (lib.mapAttrsToList mkWorkspaceRules workspaceOutputs);
  workspaceMap = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: output:
      "  [${quote name}] = { base = ${toString output.workspaceBase}, last = ${
          toString (output.workspaceBase + 99)
        }, temporary = ${toString (1000 + output.workspaceBase)} },"
    ) workspaceOutputs
  );
in
''
  ${workspaceRules}

  local localWorkspaces = {
  ${workspaceMap}
  }

  local function activeLocalWorkspace()
    local monitor = hl.get_active_monitor()
    if monitor == nil then return nil, nil end

    local config = localWorkspaces[monitor.name]
    if config == nil then return nil, nil end

    return config, hl.get_active_workspace(monitor)
  end

  local function localWorkspaceId(slot)
    local config = activeLocalWorkspace()
    if config == nil then return nil end
    return config.base + slot
  end

  local function focusLocalWorkspace(slot)
    local id = localWorkspaceId(slot)
    if id ~= nil then hl.dispatch(hl.dsp.focus({ workspace = id })) end
  end

  local function moveWindowToLocalWorkspace(slot)
    local id = localWorkspaceId(slot)
    if id ~= nil then hl.dispatch(hl.dsp.window.move({ workspace = id })) end
  end

  local function relativeLocalWorkspaceId(delta)
    local config, workspace = activeLocalWorkspace()
    if config == nil or workspace == nil then return nil end

    local current = workspace.id
    if current <= config.base or current > config.last then current = config.base + 1 end

    local target = current + delta
    if target <= config.base then target = config.base + 1 end
    if target > config.last then target = config.last end
    return target
  end

  local function focusRelativeLocalWorkspace(delta)
    local id = relativeLocalWorkspaceId(delta)
    if id ~= nil then hl.dispatch(hl.dsp.focus({ workspace = id })) end
  end

  local function moveWindowToRelativeLocalWorkspace(delta)
    local id = relativeLocalWorkspaceId(delta)
    if id ~= nil then hl.dispatch(hl.dsp.window.move({ workspace = id })) end
  end

  local function moveActiveWorkspaceRelative(delta)
    local config, workspace = activeLocalWorkspace()
    if config == nil or workspace == nil then return end

    local current = workspace.id
    local target = current + delta
    if current <= config.base or current > config.last or target <= config.base or target > config.last then return end

    local targetWorkspace = hl.get_workspace(target)
    if targetWorkspace == nil then
      hl.dispatch(hl.dsp.workspace.change_id({ workspace = current, id = target }))
      return
    end

    local temporary = config.temporary
    while hl.get_workspace(temporary) ~= nil do temporary = temporary + 1 end

    hl.dispatch(hl.dsp.workspace.change_id({ workspace = current, id = temporary }))
    hl.dispatch(hl.dsp.workspace.change_id({ workspace = target, id = current }))
    hl.dispatch(hl.dsp.workspace.change_id({ workspace = temporary, id = target }))
  end
''
