--[[
    AgentSpy :: WorkspaceAudit.server.lua
    Fase 3 - Inventario seguro de objetos do seu próprio jogo.

    Coloque como Script em ServerScriptService.
    Não acessa jogos externos, executores ou dados privados.
    O resultado fica disponível em _G.AgentSpy.WorkspaceAudit.
]]

local HttpService = game:GetService("HttpService")

local Audit = {
    Objects = {},
    Counts = {},
    MaxObjects = 5000,
}

local function addObject(instance)
    if #Audit.Objects >= Audit.MaxObjects then return end
    local className = instance.ClassName
    Audit.Counts[className] = (Audit.Counts[className] or 0) + 1
    table.insert(Audit.Objects, {
        name = instance.Name,
        class = className,
        path = instance:GetFullName(),
        archivable = instance.Archivable,
    })
end

function Audit.Scan(root)
    root = root or workspace
    table.clear(Audit.Objects)
    table.clear(Audit.Counts)
    for _, instance in ipairs(root:GetDescendants()) do
        addObject(instance)
        if #Audit.Objects >= Audit.MaxObjects then break end
    end
    return Audit.Objects
end

function Audit.FindByName(query, root)
    query = string.lower(tostring(query or ""))
    local results = {}
    root = root or workspace
    for _, instance in ipairs(root:GetDescendants()) do
        if string.find(string.lower(instance.Name), query, 1, true) then
            table.insert(results, {
                name = instance.Name,
                class = instance.ClassName,
                path = instance:GetFullName(),
            })
        end
    end
    return results
end

function Audit.Export()
    return HttpService:JSONEncode({
        generatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        counts = Audit.Counts,
        objects = Audit.Objects,
    })
end

_G.AgentSpy = _G.AgentSpy or {}
_G.AgentSpy.WorkspaceAudit = Audit
Audit.Scan(workspace)
print(string.format("[AgentSpy] WorkspaceAudit: %d objetos catalogados", #Audit.Objects))
return Audit
