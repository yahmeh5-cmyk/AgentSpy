--[[
    AgentSpy :: SnapshotBridge.server.lua
    Fase 4 - Ponte segura entre servidor e interface autorizada.

    Coloque como Script em ServerScriptService.
    Troque os UserIds em AUTHORIZED_USER_IDS pelos administradores do seu jogo.
    Nunca confie no cliente para decidir quem pode exportar dados.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local AUTHORIZED_USER_IDS = {
    -- [123456789] = true,
}

local RATE_LIMIT_SECONDS = 3
local lastRequest = {}

local folder = ReplicatedStorage:FindFirstChild("AgentSpy") or Instance.new("Folder")
folder.Name = "AgentSpy"
folder.Parent = ReplicatedStorage

local request = folder:FindFirstChild("RequestSnapshot") or Instance.new("RemoteFunction")
request.Name = "RequestSnapshot"
request.Parent = folder

local function authorized(player)
    return AUTHORIZED_USER_IDS[player.UserId] == true
end

local function safeExport(moduleName)
    local module = _G.AgentSpy and _G.AgentSpy[moduleName]
    if type(module) ~= "table" or type(module.Export) ~= "function" then
        return nil
    end
    local ok, value = pcall(module.Export)
    if ok and type(value) == "string" then return value end
    return nil
end

request.OnServerInvoke = function(player)
    if not authorized(player) then
        return { ok = false, error = "unauthorized" }
    end

    local now = os.clock()
    if lastRequest[player.UserId] and now - lastRequest[player.UserId] < RATE_LIMIT_SECONDS then
        return { ok = false, error = "rate_limited" }
    end
    lastRequest[player.UserId] = now

    local remoteAudit = _G.AgentSpy and _G.AgentSpy.RemoteAudit
    local workspaceAudit = _G.AgentSpy and _G.AgentSpy.WorkspaceAudit
    local economyAudit = _G.AgentSpy and _G.AgentSpy.EconomyAudit
    local auditLog = _G.AgentSpy and _G.AgentSpy.AuditLog

    return {
        ok = true,
        generatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        remotes = remoteAudit and remoteAudit.Remotes or {},
        findings = remoteAudit and remoteAudit.Findings or {},
        objects = workspaceAudit and workspaceAudit.Objects or {},
        objectCounts = workspaceAudit and workspaceAudit.Counts or {},
        economyFindings = economyAudit and economyAudit.Findings or {},
        transactions = economyAudit and economyAudit.Transactions or {},
        logs = auditLog and auditLog.Entries or {},
        exports = {
            remotes = safeExport("RemoteAudit"),
            workspace = safeExport("WorkspaceAudit"),
            economy = safeExport("EconomyAudit"),
            logs = safeExport("AuditLog"),
        },
    }
end

Players.PlayerRemoving:Connect(function(player)
    lastRequest[player.UserId] = nil
end)

print("[AgentSpy] SnapshotBridge iniciado; configure AUTHORIZED_USER_IDS")
