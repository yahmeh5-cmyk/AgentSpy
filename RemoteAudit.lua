--!strict
-- AgentSpy / RemoteAudit.lua
-- Fase 2: auditoria defensiva server-side.
-- Use em ServerScriptService. Não é um hook global: cada handler precisa ser registrado.

local Players = game:GetService("Players")

local RemoteAudit = {}
RemoteAudit.__index = RemoteAudit

export type Options = {
    Name: string?,
    MaxCallsPerWindow: number?,
    WindowSeconds: number?,
    MaxStringLength: number?,
    MaxTableKeys: number?,
    Validate: ((player: Player, ...any) -> (boolean, string?))?,
}

local function safeType(value: any): string
    local ok, result = pcall(typeof, value)
    return ok and result or "unknown"
end

local function summarize(value: any, depth: number?, seen: {[any]: boolean}?): any
    depth = depth or 0
    seen = seen or {}
    if depth > 3 then return "<depth-limit>" end

    local kind = safeType(value)
    if kind == "string" then
        return string.sub(value, 1, 160)
    elseif kind == "number" or kind == "boolean" or kind == "nil" then
        return value
    elseif kind == "Instance" then
        local instance = value :: Instance
        return {type = "Instance", className = instance.ClassName, path = instance:GetFullName()}
    elseif kind == "table" then
        if seen[value] then return "<cycle>" end
        seen[value] = true
        local output = {}
        local count = 0
        for key, item in pairs(value) do
            count += 1
            if count > 40 then
                output["<truncated>"] = true
                break
            end
            output[tostring(key)] = summarize(item, depth + 1, seen)
        end
        seen[value] = nil
        return output
    end
    return "<" .. kind .. ">"
end

function RemoteAudit.new(options: Options?): any
    local self = setmetatable({}, RemoteAudit)
    options = options or {}
    self.Name = options.Name or "Remote"
    self.MaxCallsPerWindow = options.MaxCallsPerWindow or 20
    self.WindowSeconds = options.WindowSeconds or 5
    self.MaxStringLength = options.MaxStringLength or 160
    self.MaxTableKeys = options.MaxTableKeys or 40
    self.Validate = options.Validate
    self.Calls = {}
    self.Events = {}
    return self
end

function RemoteAudit:_record(player: Player, remote: Instance, args: {any}, accepted: boolean, reason: string?)
    local userId = player.UserId
    local now = os.clock()
    local state = self.Calls[userId]
    if not state or now - state.startedAt >= self.WindowSeconds then
        state = {startedAt = now, count = 0}
        self.Calls[userId] = state
    end
    state.count += 1

    local entry = {
        timestamp = os.time(),
        player = player.Name,
        userId = userId,
        remote = remote:GetFullName(),
        accepted = accepted,
        reason = reason,
        rateCount = state.count,
        arguments = table.create(#args),
    }
    for index, value in ipairs(args) do
        entry.arguments[index] = summarize(value)
    end
    table.insert(self.Events, entry)
    if #self.Events > 500 then table.remove(self.Events, 1) end

    if state.count > self.MaxCallsPerWindow then
        return false, "rate-limit"
    end
    return true
end

function RemoteAudit:WrapEvent(remote: RemoteEvent, handler: (Player, ...any) -> ())
    assert(remote:IsA("RemoteEvent"), "WrapEvent exige RemoteEvent")
    remote.OnServerEvent:Connect(function(player: Player, ...: any)
        local args = table.pack(...)
        local allowed, rateReason = self:_record(player, remote, args, false, nil)
        if not allowed then
            self:_record(player, remote, args, false, rateReason)
            warn(string.format("[AgentSpy][Remote] rate-limit: %s -> %s", player.Name, remote:GetFullName()))
            return
        end

        if self.Validate then
            local valid, reason = self.Validate(player, table.unpack(args, 1, args.n))
            if not valid then
                self:_record(player, remote, args, false, reason or "validation-failed")
                warn(string.format("[AgentSpy][Remote] rejeitado: %s -> %s (%s)", player.Name, remote:GetFullName(), reason or "invalid"))
                return
            end
        end

        self:_record(player, remote, args, true, nil)
        local ok, err = pcall(handler, player, table.unpack(args, 1, args.n))
        if not ok then
            warn(string.format("[AgentSpy][Remote] erro no handler %s: %s", remote:GetFullName(), tostring(err)))
        end
    end)
end

function RemoteAudit:WrapFunction(remote: RemoteFunction, handler: (Player, ...any) -> ...any)
    assert(remote:IsA("RemoteFunction"), "WrapFunction exige RemoteFunction")
    remote.OnServerInvoke = function(player: Player, ...: any)
        local args = table.pack(...)
        local allowed, rateReason = self:_record(player, remote, args, false, nil)
        if not allowed then
            self:_record(player, remote, args, false, rateReason)
            warn(string.format("[AgentSpy][Remote] rate-limit: %s -> %s", player.Name, remote:GetFullName()))
            return nil
        end

        if self.Validate then
            local valid, reason = self.Validate(player, table.unpack(args, 1, args.n))
            if not valid then
                self:_record(player, remote, args, false, reason or "validation-failed")
                return nil
            end
        end

        self:_record(player, remote, args, true, nil)
        local results = table.pack(pcall(handler, player, table.unpack(args, 1, args.n)))
        if not results[1] then
            warn(string.format("[AgentSpy][Remote] erro no handler %s: %s", remote:GetFullName(), tostring(results[2])))
            return nil
        end
        return table.unpack(results, 2, results.n)
    end
end

function RemoteAudit:GetEvents()
    return table.clone(self.Events)
end

Players.PlayerRemoving:Connect(function(player)
    -- Os dados em memória são descartados para não reter referências de jogadores.
    -- O exportador da Fase 5 poderá persistir um snapshot antes disso.
end)

return RemoteAudit
