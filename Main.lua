--[[
    ServerScanner :: Main.lua
    Fase 1 - Loader / inicializador.

    Ordem de carregamento (loadstring cada arquivo nesta ordem):
      1) Config.lua
      2) Utils.lua
      3) UILibrary.lua
      4) (Fase 2+) modulos de scanner
      5) Main.lua  <-- ESTE, por ultimo

    Todos os arquivos se registram em _G.ServerScanner.
    Main verifica dependencias, sobe a UI e inicializa os modulos ativos.
]]

_G.ServerScanner = _G.ServerScanner or {}
local SS = _G.ServerScanner

-- Verifica dependencias minimas
local missing = {}
if not SS.Config then table.insert(missing, "Config.lua") end
if not SS.Utils  then table.insert(missing, "Utils.lua")  end
if not SS.UI     then table.insert(missing, "UILibrary.lua") end

if #missing > 0 then
    warn("[ServerScanner] Faltando carregar: " .. table.concat(missing, ", "))
    warn("[ServerScanner] Carregue os arquivos na ordem correta antes do Main.lua.")
    return
end

-- Evita rodar duas vezes
if SS._running then
    warn("[ServerScanner] Ja esta rodando. Ignorando reinicio.")
    if SS.UI and SS.UI.Notify then SS.UI.Notify("ServerScanner ja esta ativo") end
    return
end
SS._running = true

local Config = SS.Config
local Utils  = SS.Utils
local UI     = SS.UI

-- Sobe a interface
local ok, err = pcall(function()
    UI.Build()
end)

if not ok then
    warn("[ServerScanner] Falha ao montar a UI: " .. tostring(err))
    SS._running = false
    return
end

-- Registro central de modulos (preenchido nas proximas fases)
SS.Modules = SS.Modules or {}

-- Inicializa modulos que ja estejam carregados e ligados no Config
local function initModules()
    for name, enabled in pairs(Config.Modules) do
        if enabled and SS.Modules[name] and type(SS.Modules[name].Init) == "function" then
            local mok, merr = pcall(SS.Modules[name].Init)
            if mok then
                print("[ServerScanner] Modulo iniciado: " .. name)
            else
                warn("[ServerScanner] Erro no modulo " .. name .. ": " .. tostring(merr))
            end
        end
    end
end
initModules()

-- Mensagem de boas-vindas nas abas vazias (placeholder da Fase 1)
local function fillPlaceholders()
    for _, tabName in ipairs(Config.Tabs) do
        local page = UI.GetPage(tabName)
        if page then
            local scroll = UI.ScrollList(page)
            UI.Label(scroll, tabName, { Bold = true, TextSize = 16 })
            UI.Label(scroll,
                "Aba pronta. O modulo desta aba entra numa proxima fase.",
                { Color = Config.Theme.TextDim, Wrap = true,
                  Size = UDim2.new(1, 0, 0, 34) })
        end
    end
end
fillPlaceholders()

UI.Notify("ServerScanner v" .. Config.Version .. " carregado", Config.Theme.Success)
print("[ServerScanner] Fase " .. Config.BuildPhase .. " ativa. Clipboard: "
    .. (Utils.HasClipboard() and "OK" or "INDISPONIVEL (fallback no Export)"))
