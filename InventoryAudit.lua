--!strict
-- AgentSpy / InventoryAudit.lua
-- Fase 3: leitura autorizada dos inventários de jogadores no servidor.

local Players = game:GetService("Players")

local InventoryAudit = {}
InventoryAudit.__index = InventoryAudit

local function itemSnapshot(instance: Instance)
    return {
        name = instance.Name,
        className = instance.ClassName,
        path = instance:GetFullName(),
        attributes = instance:GetAttributes(),
    }
end

function InventoryAudit.new(): any
    local self = setmetatable({}, InventoryAudit)
    self.Results = {}
    return self
end

function InventoryAudit:ScanPlayer(player: Player): {[string]: any}
    local result = {player = player.Name, userId = player.UserId, containers = {}}
    local containers = {
        player:FindFirstChildOfClass("Backpack"),
        player:FindFirstChild("StarterGear"),
        player.Character,
    }
    for _, container in ipairs(containers) do
        if container then
            local data = {name = container.Name, path = container:GetFullName(), items = {}}
            for _, item in ipairs(container:GetChildren()) do
                table.insert(data.items, itemSnapshot(item))
            end
            table.insert(result.containers, data)
        end
    end
    self.Results[player.UserId] = result
    return result
end

function InventoryAudit:ScanAll(): {[number]: any}
    table.clear(self.Results)
    for _, player in ipairs(Players:GetPlayers()) do
        self:ScanPlayer(player)
    end
    return table.clone(self.Results)
end

function InventoryAudit:GetResults(): {[number]: any}
    return table.clone(self.Results)
end

return InventoryAudit
