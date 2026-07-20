--[[
    ServerScanner :: Utils.lua
    Fase 1 - Helpers seguros: serializacao, formatacao, varredura de instancias,
    protecao anti-erro e deteccao de funcoes do executor.

    Registra em _G.ServerScanner.Utils
    Carregue depois do Config.lua e antes do Main.lua.
]]

_G.ServerScanner = _G.ServerScanner or {}
local SS = _G.ServerScanner

local Config = SS.Config or {}
local Perf   = (Config.Performance or {})

local Utils = {}

-------------------------------------------------
-- Deteccao de capacidades do executor (com fallback)
-------------------------------------------------
Utils.Env = {
    setclipboard   = (typeof(setclipboard) == "function" and setclipboard)
                     or (typeof(toclipboard) == "function" and toclipboard)
                     or (typeof(setrbxclipboard) == "function" and setrbxclipboard)
                     or nil,
    getgc          = (typeof(getgc) == "function" and getgc) or nil,
    getconnections = (typeof(getconnections) == "function" and getconnections) or nil,
    hookfunction   = (typeof(hookfunction) == "function" and hookfunction) or nil,
    hookmetamethod = (typeof(hookmetamethod) == "function" and hookmetamethod) or nil,
    getnamecallmethod = (typeof(getnamecallmethod) == "function" and getnamecallmethod) or nil,
    getreg         = (typeof(getreg) == "function" and getreg) or nil,
    getgenv        = (typeof(getgenv) == "function" and getgenv) or nil,
}

function Utils.HasClipboard()
    return Utils.Env.setclipboard ~= nil
end

-------------------------------------------------
-- Protecao anti-erro
-------------------------------------------------
-- Executa fn protegido; retorna ok, resultado
function Utils.Try(fn, ...)
    return pcall(fn, ...)
end

-- Le uma propriedade de instancia sem quebrar
function Utils.SafeGet(instance, prop)
    local ok, val = pcall(function() return instance[prop] end)
    if ok then return val end
    return nil
end

-------------------------------------------------
-- Serializacao segura de valores para texto
-------------------------------------------------
local function tostr(v)
    local ok, s = pcall(tostring, v)
    if ok then return s end
    return "<?>"
end
Utils.ToStr = tostr

-- Serializa qualquer valor Luau/Roblox em string legivel
function Utils.Serialize(value, depth, seen)
    depth = depth or 0
    seen  = seen or {}
    local t = typeof(value)

    if t == "string" then
        return string.format("%q", value)
    elseif t == "number" or t == "boolean" then
        return tostr(value)
    elseif t == "nil" then
        return "nil"
    elseif t == "Instance" then
        local class = Utils.SafeGet(value, "ClassName") or "Instance"
        local name  = Utils.SafeGet(value, "Name") or "?"
        return string.format("<%s '%s'>", class, name)
    elseif t == "Vector3" then
        return string.format("Vector3(%.2f, %.2f, %.2f)", value.X, value.Y, value.Z)
    elseif t == "Vector2" then
        return string.format("Vector2(%.2f, %.2f)", value.X, value.Y)
    elseif t == "CFrame" then
        local x, y, z = value.Position.X, value.Position.Y, value.Position.Z
        return string.format("CFrame(pos %.2f, %.2f, %.2f)", x, y, z)
    elseif t == "Color3" then
        return string.format("Color3(%d, %d, %d)", value.R*255, value.G*255, value.B*255)
    elseif t == "EnumItem" then
        return tostr(value)
    elseif t == "table" then
        if seen[value] then return "<cyclic>" end
        if depth > 4 then return "<...>" end
        seen[value] = true
        local parts = {}
        local count = 0
        for k, v in pairs(value) do
            count = count + 1
            if count > 50 then
                table.insert(parts, "  ...(truncado)")
                break
            end
            local keyStr = (typeof(k) == "string") and k or ("["..tostr(k).."]")
            table.insert(parts, string.rep("  ", depth+1)
                .. keyStr .. " = " .. Utils.Serialize(v, depth+1, seen))
        end
        seen[value] = nil
        if #parts == 0 then return "{}" end
        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. string.rep("  ", depth) .. "}"
    else
        return "<" .. t .. ": " .. tostr(value) .. ">"
    end
end

-- Serializa uma lista de argumentos (varargs) em uma linha
function Utils.SerializeArgs(...)
    local n = select("#", ...)
    local parts = {}
    for i = 1, n do
        parts[i] = Utils.Serialize((select(i, ...)), 0)
    end
    return table.concat(parts, ", ")
end

-------------------------------------------------
-- Formatacao
-------------------------------------------------
function Utils.Timestamp()
    return os.date("%H:%M:%S")
end

function Utils.FullPath(instance)
    local ok, path = pcall(function()
        return instance:GetFullName()
    end)
    if ok then return path end
    return Utils.SafeGet(instance, "Name") or "?"
end

-------------------------------------------------
-- Varredura de instancias com throttle (nao trava o jogo)
-- callback(instance) chamado para cada descendente.
-- Retorna quantidade varrida.
-------------------------------------------------
function Utils.ScanDescendants(root, callback, filterClass)
    if not root then return 0 end
    local yieldEvery = Perf.ScanYieldEvery or 200
    local yieldTime  = Perf.ScanYieldTime or 0.03
    local count = 0

    local ok, descendants = pcall(function() return root:GetDescendants() end)
    if not ok or not descendants then return 0 end

    for _, inst in ipairs(descendants) do
        count = count + 1
        local pass = true
        if filterClass then
            local cn = Utils.SafeGet(inst, "ClassName")
            pass = (cn == filterClass) or (function()
                local ok2, is = pcall(function() return inst:IsA(filterClass) end)
                return ok2 and is
            end)()
        end
        if pass then
            pcall(callback, inst)
        end
        if count % yieldEvery == 0 then
            task.wait(yieldTime)
        end
    end
    return count
end

SS.Utils = Utils
return Utils
