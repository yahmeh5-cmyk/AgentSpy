--!strict
-- AgentSpy / ObjectSearch.lua
-- Fase 3: busca global em serviços autorizados pelo jogo.
-- Por padrão, evita CoreGui e outros ambientes de cliente.

local ObjectSearch = {}
ObjectSearch.__index = ObjectSearch

function ObjectSearch.new(services: {Instance}?): any
    local self = setmetatable({}, ObjectSearch)
    self.Services = services or {
        game:GetService("Workspace"),
        game:GetService("ReplicatedStorage"),
        game:GetService("ServerStorage"),
        game:GetService("ServerScriptService"),
        game:GetService("Players"),
    }
    self.Results = {}
    return self
end

function ObjectSearch:Find(query: string, className: string?): {Instance}
    table.clear(self.Results)
    local needle = string.lower(query)
    for _, service in ipairs(self.Services) do
        if service then
            for _, instance in ipairs(service:GetDescendants()) do
                local nameMatch = string.find(string.lower(instance.Name), needle, 1, true) ~= nil
                local classMatch = not className or instance:IsA(className)
                if nameMatch and classMatch then
                    table.insert(self.Results, instance)
                end
            end
        end
    end
    return table.clone(self.Results)
end

function ObjectSearch:FindByAttribute(attributeName: string, expectedValue: any?): {Instance}
    table.clear(self.Results)
    for _, service in ipairs(self.Services) do
        for _, instance in ipairs(service:GetDescendants()) do
            local value = instance:GetAttribute(attributeName)
            if value ~= nil and (expectedValue == nil or value == expectedValue) then
                table.insert(self.Results, instance)
            end
        end
    end
    return table.clone(self.Results)
end

function ObjectSearch:GetResults(): {Instance}
    return table.clone(self.Results)
end

return ObjectSearch
