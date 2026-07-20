--[[
    ServerScanner :: Config.lua
    Fase 1 - Configuracoes globais, tema e flags de performance.

    Uso: loadstring deste arquivo. Ele registra em _G.ServerScanner.Config
    Carregue este arquivo ANTES do Main.lua.
]]

-- Garante a tabela global compartilhada
_G.ServerScanner = _G.ServerScanner or {}
local SS = _G.ServerScanner

local Config = {}

-- Identidade
Config.Name        = "ServerScanner"
Config.Version     = "0.1.0"     -- Fase 1
Config.BuildPhase  = 1

-- Performance / anti-lag
Config.Performance = {
    ScanYieldEvery   = 200,   -- da um task.wait() a cada N instancias varridas
    ScanYieldTime    = 0.03,  -- tempo do wait entre lotes
    MaxLogEntries    = 500,   -- limite de logs guardados em memoria
    RenderVisibleOnly= true,  -- so renderiza a aba visivel
    ThrottleUIUpdates= 0.1,   -- intervalo minimo entre updates de UI (s)
}

-- Tema (mobile-first, toque grande, alto contraste)
Config.Theme = {
    Font          = Enum.Font.Gotham,
    FontBold      = Enum.Font.GothamBold,

    Background    = Color3.fromRGB(18, 18, 24),
    Surface       = Color3.fromRGB(28, 28, 38),
    SurfaceAlt    = Color3.fromRGB(38, 38, 50),
    Accent        = Color3.fromRGB(88, 130, 255),
    AccentDim     = Color3.fromRGB(60, 90, 190),
    Text          = Color3.fromRGB(235, 235, 245),
    TextDim       = Color3.fromRGB(150, 150, 165),
    Success       = Color3.fromRGB(80, 210, 130),
    Warn          = Color3.fromRGB(255, 190, 70),
    Critical      = Color3.fromRGB(255, 90, 90),
    Divider       = Color3.fromRGB(50, 50, 64),

    CornerRadius  = UDim.new(0, 10),
    Padding       = 8,
    TouchMinSize  = 40,   -- alvo minimo de toque em px
}

-- Janela / UI
Config.Window = {
    DefaultSize   = Vector2.new(340, 460),  -- cabe em tela de celular
    MinSize       = Vector2.new(280, 320),
    ToggleKey     = Enum.KeyCode.RightShift, -- pra quem tiver teclado
    StartMinimized= false,
    FloatButtonSize = 52,
}

-- Abas que a ferramenta tera (preenchidas nas proximas fases)
Config.Tabs = {
    "Remotes",
    "Workspace",
    "Inventario",
    "Objetos",
    "Logs",
    "Economia",
    "Export",
}

-- Toggles por modulo (ligados conforme forem implementados)
Config.Modules = {
    RemoteScanner    = false, -- Fase 2
    LogScanner       = false, -- Fase 2
    WorkspaceScanner = false, -- Fase 3
    InventoryScanner = false, -- Fase 3
    ObjectScanner    = false, -- Fase 3
    EconomyAuditor   = false, -- Fase 4
    ExportModule     = false, -- Fase 5
}

SS.Config = Config
return Config
