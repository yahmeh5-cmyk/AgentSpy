--[[
    ============================================================================
    ROBLOX MONITOR - CORE
    ============================================================================
    Arquivo: monitor_core.lua
    Função : Núcleo do monitoramento. Faz hook em RemoteEvent, RemoteFunction,
             BindableEvent e BindableFunction, capturando nome, argumentos,
             stack trace e timestamp de cada chamada.
    Autor  : Projeto colaborativo
    ============================================================================

    COMO USAR:
        local Monitor = loadfile("monitor_core.lua")()
        Monitor.Config.OnEvent = function(data)
            -- data = { type, name, source, args, timestamp, stack }
            print("Capturado:", data.name)
        end
        Monitor.Start()

    DEPENDÊNCIAS:
        - Executor com suporte a hookmetamethod / hookfunction
        - Biblioteca de HTTP (syn.request / http_request / fluxus.request)
--]]

local Monitor = {}

-- ===== CONFIGURAÇÕES =====
Monitor.Config = {
    -- Lista de instâncias/Jogos para ignorar (por PlaceId ou nome)
    Blacklist = {
        Places = {},
        Remotes = { "CharacterSoundEvent" } -- Remotes muito spammy
    },

    -- Limite de caracteres ao serializar argumentos (evita lag com tabelas gigantes)
    MaxArgLength = 500,

    -- Quantos calls manter no buffer circular
    BufferSize = 200,

    -- Capturar stack trace? (pode causar lag, desligue se preciso)
    CaptureStack = true,

    -- Hook também Bindables?
    HookBindables = true,

    -- Callback chamado a cada evento capturado
    OnEvent = nil,

    -- Callback chamado em caso de erro interno
    OnError = nil,
}

-- ===== ESTADO INTERNO =====
Monitor.State = {
    Started = false,
    Hooks = {},
    Buffer = {},
    Stats = {
        RemoteEventCalls = 0,
        RemoteFunctionCalls = 0,
        BindableEventCalls = 0,
        BindableFunctionCalls = 0,
    }
}

-- ===== UTILITÁRIOS =====

-- Serializa qualquer valor Lua em string (para envio via JSON)
local function Serialize(value, depth, seen)
    depth = depth or 0
    seen = seen or {}

    if depth > 10 then return "<...>" end

    local t = type(value)

    if t == "nil" then return "nil"
    elseif t == "boolean" then return tostring(value)
    elseif t == "number" then return tostring(value)
    elseif t == "string" then
        if #value > Monitor.Config.MaxArgLength then
            return '"' .. value:sub(1, Monitor.Config.MaxArgLength) .. '..."(' .. #value .. ')'
        end
        return '"' .. value:gsub('"', '\\"') .. '"'
    elseif t == "userdata" then
        if typeof(value) == "Instance" then
            local path = value.FullName or value.Name
            return "<Instance:" .. path .. ">"
        elseif typeof(value) == "Vector3" then
            return "<Vector3:" .. tostring(value) .. ">"
        elseif typeof(value) == "CFrame" then
            return "<CFrame>"
        elseif typeof(value) == "Color3" then
            return "<Color3:" .. tostring(value) .. ">"
        end
        return "<" .. typeof(value) .. ">"
    elseif t == "table" then
        if seen[value] then return "<circular>" end
        seen[value] = true

        local parts = {}
        local count = 0
        for k, v in pairs(value) do
            count = count + 1
            if count > 30 then
                parts[#parts + 1] = "..."
                break
            end
            local kStr = type(k) == "string" and k or "[" .. Serialize(k, depth + 1, seen) .. "]"
            parts[#parts + 1] = kStr .. "=" .. Serialize(v, depth + 1, seen)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif t == "function" then
        return "<function>"
    end

    return "<unknown:" .. t .. ">"
end
Monitor.Serialize = Serialize

-- Gera um stack trace simples
local function GetStack()
    if not Monitor.Config.CaptureStack then return nil end
    local ok, trace = pcall(debug.traceback, "", 2)
    return ok and trace or nil
end

-- Verifica se um remote está na blacklist
local function IsBlacklisted(name)
    for _, bad in ipairs(Monitor.Config.Blacklist.Remotes) do
        if name == bad then return true end
    end
    return false
end

-- Adiciona evento ao buffer circular e dispara callback
local function Dispatch(data)
    -- Atualiza stats
    if data.type == "RemoteEvent" then
        Monitor.State.Stats.RemoteEventCalls = Monitor.State.Stats.RemoteEventCalls + 1
    elseif data.type == "RemoteFunction" then
        Monitor.State.Stats.RemoteFunctionCalls = Monitor.State.Stats.RemoteFunctionCalls + 1
    elseif data.type == "BindableEvent" then
        Monitor.State.Stats.BindableEventCalls = Monitor.State.Stats.BindableEventCalls + 1
    elseif data.type == "BindableFunction" then
        Monitor.State.Stats.BindableFunctionCalls = Monitor.State.Stats.BindableFunctionCalls + 1
    end

    -- Buffer circular
    table.insert(Monitor.State.Buffer, data)
    if #Monitor.State.Buffer > Monitor.Config.BufferSize then
        table.remove(Monitor.State.Buffer, 1)
    end

    -- Callback do usuário
    if Monitor.Config.OnEvent then
        local ok, err = pcall(Monitor.Config.OnEvent, data)
        if not ok and Monitor.Config.OnError then
            Monitor.Config.OnError("OnEvent callback: " .. tostring(err))
        end
    end
end

-- ===== HOOKS =====

-- Constrói o payload de cada chamada
local function BuildPayload(remoteType, remote, args)
    local name = remote.Name or "<unknown>"
    local fullName = remote.FullName or name

    local serializedArgs = {}
    for i, arg in ipairs(args) do
        serializedArgs[i] = Serialize(arg)
    end

    return {
        type = remoteType,
        name = name,
        fullName = fullName,
        instanceClass = remote.ClassName,
        source = fullName,
        args = serializedArgs,
        argCount = #args,
        timestamp = os.time(),
        timestampMs = tick() * 1000,
        stack = GetStack(),
    }
end

-- Hook de RemoteEvent:FireServer
local function HookRemoteEvent(remote)
    if not remote or not remote:IsA("RemoteEvent") then return end
    if IsBlacklisted(remote.Name) then return end

    local original = remote.FireServer
    if not original then return end

    local hook = function(self, ...)
        local args = { ... }
        local ok, payload = pcall(BuildPayload, "RemoteEvent", remote, args)
        if ok then Dispatch(payload) end
        return original(self, ...)
    end

    -- Tentar hookfunction (executor dependente)
    local ok = pcall(function()
        remote.FireServer = hook
    end)
    if not ok then
        -- Fallback: hookmetamethod global
        pcall(function()
            local mt = getrawmetatable(remote)
            local oldIndex = mt.__index
            setreadonly(mt, false)
            mt.__index = newcclosure and newcclosure(function(t, k)
                if k == "FireServer" and t == remote then return hook end
                return oldIndex(t, k)
            end) or oldIndex
            setreadonly(mt, true)
        end)
    end

    Monitor.State.Hooks[#Monitor.State.Hooks + 1] = remote
end

-- Hook de RemoteFunction:InvokeServer
local function HookRemoteFunction(remote)
    if not remote or not remote:IsA("RemoteFunction") then return end
    if IsBlacklisted(remote.Name) then return end

    local original = remote.InvokeServer
    if not original then return end

    local hook = function(self, ...)
        local args = { ... }
        local ok, payload = pcall(BuildPayload, "RemoteFunction", remote, args)
        if ok then Dispatch(payload) end
        return original(self, ...)
    end

    pcall(function() remote.InvokeServer = hook end)
    Monitor.State.Hooks[#Monitor.State.Hooks + 1] = remote
end

-- Hook de BindableEvent:Fire
local function HookBindableEvent(b)
    if not b or not b:IsA("BindableEvent") then return end
    if IsBlacklisted(b.Name) then return end

    local original = b.Fire
    if not original then return end

    local hook = function(self, ...)
        local args = { ... }
        local ok, payload = pcall(BuildPayload, "BindableEvent", b, args)
        if ok then Dispatch(payload) end
        return original(self, ...)
    end

    pcall(function() b.Fire = hook end)
    Monitor.State.Hooks[#Monitor.State.Hooks + 1] = b
end

-- Hook de BindableFunction:Invoke
local function HookBindableFunction(b)
    if not b or not b:IsA("BindableFunction") then return end
    if IsBlacklisted(b.Name) then return end

    local original = b.Invoke
    if not original then return end

    local hook = function(self, ...)
        local args = { ... }
        local ok, payload = pcall(BuildPayload, "BindableFunction", b, args)
        if ok then Dispatch(payload) end
        return original(self, ...)
    end

    pcall(function() b.Invoke = hook end)
    Monitor.State.Hooks[#Monitor.State.Hooks + 1] = b
end

-- ===== DESCRIÇÃO DE INSTÂNCIAS =====

-- Percorre o Workspace/ReplicatedStorage buscando remotes existentes
local function ScanForRemotes(parent, results, depth)
    results = results or {}
    depth = depth or 0
    if depth > 15 then return results end

    for _, child in ipairs(parent:GetChildren()) do
        pcall(function()
            if child:IsA("RemoteEvent") then
                results[#results + 1] = { type = "RemoteEvent", instance = child, name = child.FullName }
                HookRemoteEvent(child)
            elseif child:IsA("RemoteFunction") then
                results[#results + 1] = { type = "RemoteFunction", instance = child, name = child.FullName }
                HookRemoteFunction(child)
            elseif Monitor.Config.HookBindables and child:IsA("BindableEvent") then
                results[#results + 1] = { type = "BindableEvent", instance = child, name = child.FullName }
                HookBindableEvent(child)
            elseif Monitor.Config.HookBindables and child:IsA("BindableFunction") then
                results[#results + 1] = { type = "BindableFunction", instance = child, name = child.FullName }
                HookBindableFunction(child)
            end
        end)

        if #child:GetChildren() > 0 then
            ScanForRemotes(child, results, depth + 1)
        end
    end
    return results
end
Monitor.ScanForRemotes = ScanForRemotes

-- ===== API PRINCIPAL =====

-- Inicia o monitor (escaneia containers e adiciona ChildAdded listeners)
function Monitor.Start()
    if Monitor.State.Started then return end
    Monitor.State.Started = true

    local containers = {
        { name = "Workspace",        instance = workspace },
        { name = "ReplicatedStorage", instance = game:GetService("ReplicatedStorage") },
        { name = "ReplicatedFirst",  instance = game:GetService("ReplicatedFirst") },
        { name = "StarterGui",       instance = game:GetService("StarterGui") },
        { name = "StarterPlayer",    instance = game:GetService("StarterPlayer") },
    }

    for _, c in ipairs(containers) do
        pcall(function()
            ScanForRemotes(c.instance)

            c.instance.ChildAdded:Connect(function(child)
                pcall(function()
                    if child:IsA("RemoteEvent") then
                        HookRemoteEvent(child)
                    elseif child:IsA("RemoteFunction") then
                        HookRemoteFunction(child)
                    elseif Monitor.Config.HookBindables and child:IsA("BindableEvent") then
                        HookBindableEvent(child)
                    elseif Monitor.Config.HookBindables and child:IsA("BindableFunction") then
                        HookBindableFunction(child)
                    end
                end)
            end)

            -- Listener recursivo para ChildrenAdded em níveis profundos
            c.instance.DescendantAdded:Connect(function(desc)
                pcall(function()
                    if desc:IsA("RemoteEvent") then
                        HookRemoteEvent(desc)
                    elseif desc:IsA("RemoteFunction") then
                        HookRemoteFunction(desc)
                    elseif Monitor.Config.HookBindables and desc:IsA("BindableEvent") then
                        HookBindableEvent(desc)
                    elseif Monitor.Config.HookBindables and desc:IsA("BindableFunction") then
                        HookBindableFunction(desc)
                    end
                end)
            end)
        end)
    end
end

-- Para o monitor (não restaura os hooks - por segurança do executor)
function Monitor.Stop()
    Monitor.State.Started = false
end

-- Limpa o buffer
function Monitor.Clear()
    Monitor.State.Buffer = {}
    Monitor.State.Stats = {
        RemoteEventCalls = 0,
        RemoteFunctionCalls = 0,
        BindableEventCalls = 0,
        BindableFunctionCalls = 0,
    }
end

-- Retorna snapshot das estatísticas
function Monitor.GetStats()
    return Monitor.State.Stats
end

-- Retorna os últimos N eventos do buffer
function Monitor.GetRecent(n)
    n = n or 50
    local out = {}
    local start = math.max(1, #Monitor.State.Buffer - n + 1)
    for i = start, #Monitor.State.Buffer do
        out[#out + 1] = Monitor.State.Buffer[i]
    end
    return out
end

-- ===== RETORNO =====
return Monitor
