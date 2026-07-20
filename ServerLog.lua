--!strict
-- AgentSpy / ServerLog.lua
-- Fase 2: captura de logs do servidor para auditoria do próprio jogo.
-- Use em ServerScriptService; não captura console de outros jogos.

local LogService = game:GetService("LogService")

local ServerLog = {}
ServerLog.__index = ServerLog

export type Entry = {
    timestamp: number,
    message: string,
    messageType: string,
}

function ServerLog.new(maxEntries: number?): any
    local self = setmetatable({}, ServerLog)
    self.MaxEntries = maxEntries or 500
    self.Entries = {}
    self.Started = false
    self.Connection = nil
    return self
end

function ServerLog:Start()
    if self.Started then return end
    self.Started = true
    self.Connection = LogService.MessageOut:Connect(function(message: string, messageType: Enum.MessageType)
        local entry: Entry = {
            timestamp = os.time(),
            message = string.sub(message, 1, 2000),
            messageType = tostring(messageType),
        }
        table.insert(self.Entries, entry)
        if #self.Entries > self.MaxEntries then
            table.remove(self.Entries, 1)
        end
    end)
end

function ServerLog:Stop()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    self.Started = false
end

function ServerLog:GetEntries()
    return table.clone(self.Entries)
end

function ServerLog:Clear()
    table.clear(self.Entries)
end

function ServerLog:Destroy()
    self:Stop()
    table.clear(self.Entries)
end

return ServerLog
