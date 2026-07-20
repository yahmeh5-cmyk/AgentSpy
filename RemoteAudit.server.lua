--[[
    AgentSpy :: RemoteAudit.server.lua
    Fase 2 - Auditoria defensiva para o SEU jogo.

    Coloque como Script em ServerScriptService.
    Este módulo NÃO intercepta executor, não hooka metamétodos e não explora remotes.
    Ele inventaria RemoteEvents/RemoteFunctions e permite registrar validadores
    server-side explícitos para as rotas econômicas.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Audit = {}
Audit.Remotes = {}
Audit.Findings = {}
Audit.Events = {}

local suspiciousNames = {
    give = true, add = true, setmoney = true, money = true, coins = true,
    buy = true, sell = true, trade = true, reward = true, admin = true,
}

local function now()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function addFinding(remote, severity, reason)
    local item = {
        time = now(),
        severity = severity,
        remote = remote:GetFullName(),
        class = remote.ClassName,
        reason = reason,
    }
    table.insert(Audit.Findings, item)
    warn(string.format("[AgentSpy][%s] %s: %s", severity, item.remote, reason))
end

function Audit.Scan(root)
    root = root or ReplicatedStorage
    table.clear(Audit.Remotes)

    for _, instance in ipairs(root:GetDescendants()) do
        if instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") then
            local record = {
                path = instance:GetFullName(),
                name = instance.Name,
                class = instance.ClassName,
                parent = instance.Parent and instance.Parent:GetFullName() or "",
            }
            table.insert(Audit.Remotes, record)

            local lowered = string.lower(instance.Name)
            for token in pairs(suspiciousNames) do
                if string.find(lowered, token, 1, true) then
                    addFinding(instance, "REVIEW", "nome sugere rota sensível; valide tudo no servidor")
                    break
                end
            end

            if instance:IsDescendantOf(game:GetService("Workspace")) then
                addFinding(instance, "REVIEW", "remote exposto no Workspace; prefira ReplicatedStorage")
            end
        end
    end
    return Audit.Remotes
end

-- Registre somente rotas controladas pelo seu código server-side.
-- validator(player, ...) deve retornar true ou false, motivo opcional.
function Audit.RegisterRemote(remote, validator, label)
    assert(typeof(remote) == "Instance", "remote precisa ser Instance")
    assert(remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction"), "tipo de remote invalido")
    assert(type(validator) == "function", "validator precisa ser function")

    local name = label or remote.Name
    local previous = Audit.Events[remote]
    if previous then previous:Disconnect() end

    if remote:IsA("RemoteEvent") then
        Audit.Events[remote] = remote.OnServerEvent:Connect(function(player, ...)
            local ok, valid, reason = pcall(validator, player, ...)
            if not ok or valid ~= true then
                warn(string.format("[AgentSpy][BLOCKED] %s por %s: %s", name, player.Name, tostring(reason or "falha na validacao")))
                return
            end
        end)
    end
end

function Audit.Export()
    return HttpService:JSONEncode({
        generatedAt = now(),
        remotes = Audit.Remotes,
        findings = Audit.Findings,
    })
end

_G.AgentSpy = _G.AgentSpy or {}
_G.AgentSpy.RemoteAudit = Audit
Audit.Scan()
print(string.format("[AgentSpy] RemoteAudit: %d remotes catalogados, %d achados", #Audit.Remotes, #Audit.Findings))
return Audit
