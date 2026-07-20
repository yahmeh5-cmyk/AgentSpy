--!strict
-- AgentSpy / WorkspaceAudit.lua
-- Fase 3: inventário estrutural do Workspace no servidor.

local WorkspaceAudit = {}
WorkspaceAudit.__index = WorkspaceAudit

local function snapshot(instance: Instance)
    local item = {
        name = instance.Name,
        className = instance.ClassName,
        path = instance:GetFullName(),
        attributes = {},
    }
    for name, value in pairs(instance:GetAttributes()) do
        item.attributes[name] = value
    end
    return item
end

function WorkspaceAudit.new(maxItems: number?): any
    local self = setmetatable({}, WorkspaceAudit)
    self.MaxItems = maxItems or 10000
    self.Results = {}
    return self
end

function WorkspaceAudit:Scan(root: Instance?): {any}
    root = root or workspace
    table.clear(self.Results)
    local count = 0
    for _, instance in ipairs(root:GetDescendants()) do
        count += 1
        if count > self.MaxItems then break end
        table.insert(self.Results, snapshot(instance))
        if count % 250 == 0 then task.wait() end
    end
    return table.clone(self.Results)
end

function WorkspaceAudit:GetResults(): {any}
    return table.clone(self.Results)
end

return WorkspaceAudit
