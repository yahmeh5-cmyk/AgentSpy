--[[
    ServerScanner :: UILibrary.lua
    Fase 1 - Framework de UI mobile-first.
    - Botao flutuante arrastavel para abrir/fechar
    - Janela principal arrastavel e minimizavel
    - Sistema de abas
    - Componentes: Label, Button, ScrollList

    Nao trava o jogo: usa apenas eventos, sem loops pesados.
    Registra em _G.ServerScanner.UI
    Carregue depois de Config.lua e Utils.lua.
]]

_G.ServerScanner = _G.ServerScanner or {}
local SS = _G.ServerScanner

local Config = SS.Config
local Utils  = SS.Utils
local Theme  = Config.Theme
local WCfg   = Config.Window

local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")

local UI = {}
UI._tabs = {}          -- nome -> {button=, page=}
UI._activeTab = nil
UI._built = false

-------------------------------------------------
-- Helpers de criacao
-------------------------------------------------
local function make(class, props, children)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then
            pcall(function() obj[k] = v end)
        end
    end
    for _, c in ipairs(children or {}) do
        c.Parent = obj
    end
    if props and props.Parent then
        obj.Parent = props.Parent
    end
    return obj
end

local function corner(parent, radius)
    make("UICorner", { CornerRadius = radius or Theme.CornerRadius, Parent = parent })
end

local function padding(parent, px)
    px = px or Theme.Padding
    make("UIPadding", {
        PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px),
        PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px),
        Parent = parent,
    })
end

-- Torna um frame arrastavel por 'handle' (funciona com toque)
local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-------------------------------------------------
-- Componentes publicos (usados pelas abas nas proximas fases)
-------------------------------------------------
function UI.Label(parent, text, opts)
    opts = opts or {}
    return make("TextLabel", {
        Parent = parent,
        BackgroundTransparency = 1,
        Size = opts.Size or UDim2.new(1, 0, 0, 20),
        Font = opts.Bold and Theme.FontBold or Theme.Font,
        Text = text or "",
        TextColor3 = opts.Color or Theme.Text,
        TextSize = opts.TextSize or 14,
        TextXAlignment = opts.Align or Enum.TextXAlignment.Left,
        TextWrapped = opts.Wrap or false,
        RichText = opts.RichText or false,
    })
end

function UI.Button(parent, text, callback, opts)
    opts = opts or {}
    local btn = make("TextButton", {
        Parent = parent,
        BackgroundColor3 = opts.Color or Theme.Accent,
        Size = opts.Size or UDim2.new(1, 0, 0, Theme.TouchMinSize),
        Font = Theme.FontBold,
        Text = text or "",
        TextColor3 = opts.TextColor or Theme.Text,
        TextSize = opts.TextSize or 14,
        AutoButtonColor = true,
    })
    corner(btn, UDim.new(0, 8))
    if callback then
        btn.MouseButton1Click:Connect(function()
            pcall(callback)
        end)
    end
    return btn
end

-- Lista rolavel; retorna o ScrollingFrame para as abas popularem
function UI.ScrollList(parent)
    local scroll = make("ScrollingFrame", {
        Parent = parent,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.Accent,
        BorderSizePixel = 0,
    })
    make("UIListLayout", {
        Parent = scroll,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    padding(scroll, 4)
    return scroll
end

-------------------------------------------------
-- Construcao da janela principal
-------------------------------------------------
function UI.Build()
    if UI._built then return end
    UI._built = true

    -- ScreenGui protegido (nao trava jogo, ResetOnSpawn false pra persistir)
    local playerGui
    local ok = pcall(function()
        playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    end)
    if not ok or not playerGui then
        playerGui = game:GetService("CoreGui")
    end

    local gui = make("ScreenGui", {
        Name = "ServerScannerUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        Parent = playerGui,
    })
    UI.Gui = gui

    -- Botao flutuante
    local fbSize = WCfg.FloatButtonSize
    local floatBtn = make("TextButton", {
        Name = "FloatButton",
        Parent = gui,
        BackgroundColor3 = Theme.Accent,
        Size = UDim2.new(0, fbSize, 0, fbSize),
        Position = UDim2.new(0, 12, 0.4, 0),
        Text = "SS",
        Font = Theme.FontBold,
        TextColor3 = Theme.Text,
        TextSize = 18,
        AutoButtonColor = true,
    })
    make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = floatBtn })
    makeDraggable(floatBtn)
    UI.FloatButton = floatBtn

    -- Janela principal
    local size = WCfg.DefaultSize
    local win = make("Frame", {
        Name = "Window",
        Parent = gui,
        BackgroundColor3 = Theme.Background,
        Size = UDim2.new(0, size.X, 0, size.Y),
        Position = UDim2.new(0.5, -size.X/2, 0.5, -size.Y/2),
        Visible = not WCfg.StartMinimized,
        ClipsDescendants = true,
    })
    corner(win)
    make("UIStroke", { Color = Theme.Divider, Thickness = 1, Parent = win })
    UI.Window = win

    -- Barra de titulo (handle do drag)
    local title = make("Frame", {
        Name = "TitleBar",
        Parent = win,
        BackgroundColor3 = Theme.Surface,
        Size = UDim2.new(1, 0, 0, 36),
    })
    corner(title, UDim.new(0, 10))
    makeDraggable(win, title)

    local titleLbl = UI.Label(title, "  " .. Config.Name .. "  v" .. Config.Version, {
        Bold = true, Size = UDim2.new(1, -80, 1, 0), TextSize = 15,
    })
    titleLbl.Position = UDim2.new(0, 8, 0, 0)

    -- Botao minimizar
    local minBtn = make("TextButton", {
        Parent = title,
        BackgroundColor3 = Theme.SurfaceAlt,
        Size = UDim2.new(0, 30, 0, 26),
        Position = UDim2.new(1, -68, 0.5, -13),
        Text = "_",
        Font = Theme.FontBold,
        TextColor3 = Theme.Text,
        TextSize = 16,
    })
    corner(minBtn, UDim.new(0, 6))

    -- Botao fechar (esconde, nao destroi)
    local closeBtn = make("TextButton", {
        Parent = title,
        BackgroundColor3 = Theme.Critical,
        Size = UDim2.new(0, 30, 0, 26),
        Position = UDim2.new(1, -34, 0.5, -13),
        Text = "X",
        Font = Theme.FontBold,
        TextColor3 = Theme.Text,
        TextSize = 14,
    })
    corner(closeBtn, UDim.new(0, 6))

    -- Barra de abas (rolavel horizontal)
    local tabBar = make("ScrollingFrame", {
        Name = "TabBar",
        Parent = win,
        BackgroundColor3 = Theme.Surface,
        Size = UDim2.new(1, 0, 0, 34),
        Position = UDim2.new(0, 0, 0, 40),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        ScrollBarThickness = 2,
        ScrollingDirection = Enum.ScrollingDirection.X,
        BorderSizePixel = 0,
    })
    make("UIListLayout", {
        Parent = tabBar,
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
    })
    padding(tabBar, 4)
    UI.TabBar = tabBar

    -- Container de paginas
    local body = make("Frame", {
        Name = "Body",
        Parent = win,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -8, 1, -84),
        Position = UDim2.new(0, 4, 0, 78),
    })
    UI.Body = body

    -- Cria uma aba
    function UI.AddTab(name)
        if UI._tabs[name] then return UI._tabs[name] end

        local btn = make("TextButton", {
            Parent = tabBar,
            BackgroundColor3 = Theme.SurfaceAlt,
            Size = UDim2.new(0, 0, 1, -6),
            AutomaticSize = Enum.AutomaticSize.X,
            Text = "  " .. name .. "  ",
            Font = Theme.Font,
            TextColor3 = Theme.TextDim,
            TextSize = 13,
        })
        corner(btn, UDim.new(0, 6))

        local page = make("Frame", {
            Parent = body,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Visible = false,
        })

        UI._tabs[name] = { button = btn, page = page }

        btn.MouseButton1Click:Connect(function()
            UI.SelectTab(name)
        end)

        -- Primeira aba fica ativa
        if not UI._activeTab then
            UI.SelectTab(name)
        end
        return UI._tabs[name]
    end

    function UI.SelectTab(name)
        for tabName, t in pairs(UI._tabs) do
            local active = (tabName == name)
            t.page.Visible = active
            t.button.BackgroundColor3 = active and Theme.Accent or Theme.SurfaceAlt
            t.button.TextColor3 = active and Theme.Text or Theme.TextDim
        end
        UI._activeTab = name
    end

    -- Retorna a pagina (frame) de uma aba pra outros modulos popularem
    function UI.GetPage(name)
        local t = UI._tabs[name]
        return t and t.page or nil
    end

    -- Comportamento dos botoes
    local function toggleWindow()
        win.Visible = not win.Visible
    end
    floatBtn.MouseButton1Click:Connect(toggleWindow)
    closeBtn.MouseButton1Click:Connect(function() win.Visible = false end)
    minBtn.MouseButton1Click:Connect(function() win.Visible = false end)

    -- Tecla de toggle (pra quem tiver teclado)
    UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == WCfg.ToggleKey then
            toggleWindow()
        end
    end)

    -- Cria as abas definidas no Config
    for _, tabName in ipairs(Config.Tabs) do
        UI.AddTab(tabName)
    end
end

-- Notificacao simples (toast)
function UI.Notify(text, color, duration)
    if not UI.Gui then return end
    duration = duration or 2.5
    local toast = make("TextLabel", {
        Parent = UI.Gui,
        BackgroundColor3 = color or Theme.Surface,
        Size = UDim2.new(0, 260, 0, 40),
        Position = UDim2.new(0.5, -130, 0, 20),
        Text = text or "",
        Font = Theme.Font,
        TextColor3 = Theme.Text,
        TextSize = 14,
        TextWrapped = true,
    })
    corner(toast, UDim.new(0, 8))
    task.delay(duration, function()
        pcall(function() toast:Destroy() end)
    end)
end

SS.UI = UI
return UI
