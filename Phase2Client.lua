--[[
    AgentSpy :: Phase2Client.lua
    Fase 2 - Conector cliente para exibir resultados enviados pelo seu servidor.

    Este arquivo não faz descoberta de remotes por executor e não lê dados de
    jogos de terceiros. Ele apenas prepara as abas da interface para receber
    snapshots autorizados publicados pelo servidor.

    Carregue depois de Config.lua, Utils.lua, UILibrary.lua e Main.lua.
]]

_G.ServerScanner = _G.ServerScanner or {}
local SS = _G.ServerScanner
local UI = SS.UI

if not UI or not UI.GetPage then
    warn("[AgentSpy] Phase2Client: carregue a interface antes")
    return
end

local function clearPage(page)
    for _, child in ipairs(page:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
end

local function render(title, lines, color)
    local page = UI.GetPage(title)
    if not page then return end
    clearPage(page)
    local scroll = UI.ScrollList(page)
    UI.Label(scroll, title .. " | auditoria autorizada", { Bold = true, TextSize = 16 })
    if #lines == 0 then
        UI.Label(scroll, "Nenhum dado recebido do servidor ainda.", { Color = SS.Config.Theme.TextDim, Wrap = true })
        return
    end
    for _, line in ipairs(lines) do
        UI.Label(scroll, tostring(line), { Color = color or SS.Config.Theme.Text, Wrap = true, Size = UDim2.new(1, 0, 0, 34) })
    end
end

function SS.RenderPhase2(snapshot)
    snapshot = snapshot or {}
    local remoteLines = {}
    for _, remote in ipairs(snapshot.remotes or {}) do
        table.insert(remoteLines, string.format("%s | %s", remote.class or "?", remote.path or "?"))
    end
    local findingLines = {}
    for _, finding in ipairs(snapshot.findings or {}) do
        table.insert(findingLines, string.format("[%s] %s: %s", finding.severity or "REVIEW", finding.remote or "?", finding.reason or ""))
    end
    local logLines = {}
    for _, entry in ipairs(snapshot.logs or {}) do
        table.insert(logLines, string.format("[%s] %s", entry.category or "log", entry.message or ""))
    end
    render("Remotes", remoteLines, SS.Config.Theme.Text)
    render("Logs", logLines, SS.Config.Theme.TextDim)
    render("Economia", findingLines, SS.Config.Theme.Warn)
end

print("[AgentSpy] Phase2Client pronto: aguardando snapshot autorizado")
return SS.RenderPhase2
