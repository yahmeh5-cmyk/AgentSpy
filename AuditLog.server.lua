--[[
    AgentSpy :: AuditLog.server.lua
    Fase 2 - Logs estruturados do SEU servidor.

    Coloque como Script em ServerScriptService.
    Use _G.AgentSpy.AuditLog.Log("categoria", "mensagem", dados)
    nos pontos de compra, venda, recompensa, troca e alteração de inventário.
]]

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")

local AuditLog = {}
AuditLog.Entries = {}
AuditLog.MaxEntries = 1000

local function timestamp()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function push(entry)
    table.insert(AuditLog.Entries, entry)
    while #AuditLog.Entries > AuditLog.MaxEntries do
        table.remove(AuditLog.Entries, 1)
    end
end

function AuditLog.Log(category, message, data)
    local entry = {
        time = timestamp(),
        category = tostring(category or "general"),
        message = tostring(message or ""),
        data = data,
    }
    push(entry)
    return entry
end

function AuditLog.Get(category)
    if not category then return table.clone(AuditLog.Entries) end
    local result = {}
    for _, entry in ipairs(AuditLog.Entries) do
        if entry.category == category then table.insert(result, entry) end
    end
    return result
end

function AuditLog.Export()
    return HttpService:JSONEncode({
        generatedAt = timestamp(),
        entries = AuditLog.Entries,
    })
end

-- Captura erros e avisos do servidor para diagnóstico, sem coletar dados privados.
local connection = LogService.MessageOut:Connect(function(message, messageType)
    if messageType == Enum.MessageType.MessageError
    or messageType == Enum.MessageType.MessageWarning then
        AuditLog.Log("server-log", message, { messageType = tostring(messageType) })
    end
end)

_G.AgentSpy = _G.AgentSpy or {}
_G.AgentSpy.AuditLog = AuditLog
_G.AgentSpy.AuditLogConnection = connection

AuditLog.Log("system", "AuditLog iniciado")
print("[AgentSpy] AuditLog iniciado")
return AuditLog
