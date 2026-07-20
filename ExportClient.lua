--[[
    AgentSpy :: ExportClient.lua
    Fase 4 - Exportação mobile do snapshot autorizado.

    Carregue após Main.lua e Phase2Client.lua.
    O servidor decide se o jogador pode solicitar dados.
]]

_G.ServerScanner = _G.ServerScanner or {}
local SS = _G.ServerScanner
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local remoteFolder = ReplicatedStorage:WaitForChild("AgentSpy", 10)
local request = remoteFolder and remoteFolder:WaitForChild("RequestSnapshot", 10)
local page = SS.UI and SS.UI.GetPage and SS.UI.GetPage("Export")

if not request or not page then
    warn("[AgentSpy] ExportClient: ponte ou aba Export indisponível")
    return
end

for _, child in ipairs(page:GetChildren()) do
    if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then child:Destroy() end
end

local scroll = SS.UI.ScrollList(page)
SS.UI.Label(scroll, "Exportação autorizada", { Bold = true, TextSize = 16 })
SS.UI.Label(scroll, "Solicite um snapshot do servidor e copie o JSON no celular.", {
    Color = SS.Config.Theme.TextDim, Wrap = true, Size = UDim2.new(1, 0, 0, 34)
})

local output = ""
local status = SS.UI.Label(scroll, "Pronto para exportar.", { Color = SS.Config.Theme.TextDim, Wrap = true })

local textBox = Instance.new("TextBox")
textBox.Parent = scroll
textBox.BackgroundColor3 = SS.Config.Theme.Surface
textBox.TextColor3 = SS.Config.Theme.Text
textBox.PlaceholderText = "O JSON aparecerá aqui..."
textBox.PlaceholderColor3 = SS.Config.Theme.TextDim
textBox.Text = ""
textBox.ClearTextOnFocus = false
textBox.MultiLine = true
textBox.TextWrapped = false
textBox.TextXAlignment = Enum.TextXAlignment.Left
textBox.TextYAlignment = Enum.TextYAlignment.Top
textBox.Font = SS.Config.Theme.Font
textBox.TextSize = 12
textBox.Size = UDim2.new(1, 0, 0, 180)
textBox.AutomaticSize = Enum.AutomaticSize.None
Instance.new("UICorner", textBox).CornerRadius = UDim.new(0, 8)

local function putClipboard(text)
    local env = SS.Utils and SS.Utils.Env
    if env and env.setclipboard then
        local ok = pcall(env.setclipboard, text)
        if ok then return true end
    end
    return false
end

local function prettyJson(value)
    local ok, encoded = pcall(function() return HttpService:JSONEncode(value) end)
    return ok and encoded or tostring(value)
end

SS.UI.Button(scroll, "Coletar snapshot", function()
    status.Text = "Coletando..."
    local ok, result = pcall(function() return request:InvokeServer() end)
    if not ok or type(result) ~= "table" or result.ok ~= true then
        status.Text = "Falha: " .. tostring((result and result.error) or "servidor indisponível")
        status.TextColor3 = SS.Config.Theme.Critical
        return
    end
    output = prettyJson(result)
    local copied = putClipboard(output)
    status.Text = copied and "Snapshot copiado para o clipboard." or "Snapshot pronto. Clipboard indisponível, use o campo abaixo."
    status.TextColor3 = SS.Config.Theme.Success
    textBox.Text = output
end)

SS.UI.Label(scroll, "Se o clipboard não funcionar no iPhone, toque no campo, selecione tudo e copie.", {
    Color = SS.Config.Theme.TextDim, Wrap = true, Size = UDim2.new(1, 0, 0, 34)
})

print("[AgentSpy] ExportClient pronto para " .. player.Name)
