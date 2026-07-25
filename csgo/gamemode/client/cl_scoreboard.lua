local SH = CSGOSpectatorShared
local TEAM_CS_CT = CSGOConfig.TeamCT
local TEAM_CS_T = CSGOConfig.TeamT

local board, ctList, tList
local nextRefresh = 0
local specText, specCount, nextSpecUpdate = "", 0, 0

local colors = {
    border = Color(71, 79, 94, 230),
    background = Color(15, 18, 24, 250),
    surface = Color(25, 29, 37, 250),
    row = Color(34, 39, 49, 245),
    text = Color(245, 247, 250),
    muted = Color(162, 171, 187),
    ct = Color(94, 159, 232),
    t = Color(233, 115, 102),
    spec = Color(150, 158, 172),
    gold = Color(234, 194, 107)
}

surface.CreateFont("CSBoardDisplay", { font = "Arial", size = 30, weight = 900, extended = true })
surface.CreateFont("CSBoardTeam", { font = "Arial", size = 20, weight = 900, extended = true })
surface.CreateFont("CSBoardBody", { font = "Arial", size = 16, weight = 650, extended = true })
surface.CreateFont("CSBoardLabel", { font = "Arial", size = 12, weight = 800, extended = true })

local function AddPlayerRow(list, ply, accent)
    local row = vgui.Create("DPanel")
    row:SetTall(44)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 6)
    row.Paint = function(_, w, h)
        if not IsValid(ply) then
            draw.RoundedBox(6, 0, 0, w, h, colors.row)
            draw.SimpleText("Disconnected", "CSBoardBody", 18, h * 0.5, colors.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            return
        end

        local dead = not ply:Alive()
        local nameColor = dead and colors.muted or colors.text

        draw.RoundedBox(6, 0, 0, w, h, colors.row)
        draw.RoundedBox(6, 0, 0, 4, h, accent)
        draw.SimpleText(ply:Nick(), "CSBoardBody", 18, h * 0.5, nameColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        if dead then
            draw.SimpleText("†", "CSBoardBody", w - 212, h * 0.5, colors.t, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        draw.SimpleText(ply:Frags(), "CSBoardBody", w - 170, h * 0.5, nameColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(ply:Deaths(), "CSBoardBody", w - 104, h * 0.5, nameColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(ply:Ping(), "CSBoardBody", w - 38, h * 0.5, colors.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    list:AddItem(row)
end

local function SortPlayers(a, b)
    if a:Frags() ~= b:Frags() then return a:Frags() > b:Frags() end
    return string.lower(a:Nick()) < string.lower(b:Nick())
end

local function RefreshList(list, teamID, accent)
    if not IsValid(list) then return end

    local canvas = list:GetCanvas()
    if IsValid(canvas) then canvas:Clear() end

    local players = team.GetPlayers(teamID)
    table.sort(players, SortPlayers)

    for i = 1, #players do
        AddPlayerRow(list, players[i], accent)
    end
end

local function CreateTeamColumn(parent, x, y, width, height, teamID, title, accent)
    local panel = vgui.Create("DPanel", parent)
    panel:SetPos(x, y)
    panel:SetSize(width, height)
    panel.Paint = function(_, w)
        draw.RoundedBox(8, 0, 0, w, 72, colors.surface)
        draw.RoundedBox(8, 0, 0, 5, 72, accent)
        draw.SimpleText(title, "CSBoardTeam", 20, 24, accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(team.NumPlayers(teamID) .. " ИГРОКОВ", "CSBoardLabel", 20, 50, colors.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("K", "CSBoardLabel", w - 170, 50, colors.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("D", "CSBoardLabel", w - 104, 50, colors.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("PING", "CSBoardLabel", w - 38, 50, colors.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local list = vgui.Create("DScrollPanel", panel)
    list:SetPos(0, 80)
    list:SetSize(width, height - 80)
    return list
end

local function UpdateSpectatorText(maxWidth)
    local now = RealTime()
    if now < nextSpecUpdate then return end
    nextSpecUpdate = now + 0.5

    local spectators = SH.GetSpectators()
    specCount = #spectators

    if specCount == 0 then
        specText = "НЕТ НАБЛЮДАТЕЛЕЙ"
        return
    end

    local names = {}
    for i = 1, specCount do
        names[i] = spectators[i]:Nick() .. " (" .. spectators[i]:Ping() .. ")"
    end

    surface.SetFont("CSBoardBody")

    local text = table.concat(names, "   •   ")
    local shown = specCount

    while shown > 1 and surface.GetTextSize(text) > maxWidth do
        shown = shown - 1
        text = table.concat(names, "   •   ", 1, shown) .. "   •   +" .. (specCount - shown)
    end

    specText = text
end

local function CreateSpectatorPanel(parent, x, y, width, height)
    local panel = vgui.Create("DPanel", parent)
    panel:SetPos(x, y)
    panel:SetSize(width, height)
    panel.Paint = function(_, w, h)
        UpdateSpectatorText(w - 40)
        draw.RoundedBox(8, 0, 0, w, h, colors.surface)
        draw.RoundedBox(8, 0, 0, 5, h, colors.spec)
        draw.SimpleText("НАБЛЮДАТЕЛИ (" .. specCount .. ")", "CSBoardLabel", 20, 20, colors.spec, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(specText, "CSBoardBody", 20, 44, specCount == 0 and colors.muted or colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return panel
end

local function CreateBoard()
    if IsValid(board) then board:Remove() end

    local width = math.min(1120, ScrW() - 64)
    local height = math.min(760, ScrH() - 64)

    board = vgui.Create("DFrame")
    board:SetSize(width, height)
    board:Center()
    board:SetTitle("")
    board:ShowCloseButton(false)
    board:SetDraggable(false)
    board:SetKeyboardInputEnabled(false)
    board:SetMouseInputEnabled(false)
    board.Paint = function(_, w, h)
        draw.RoundedBox(11, 0, 0, w, h, colors.border)
        draw.RoundedBox(10, 1, 1, w - 2, h - 2, colors.background)

        local center = w * 0.5
        draw.SimpleText("MATCH SCORE", "CSBoardLabel", center, 22, colors.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(GetGlobalInt("CSRoundScoreCT", 0), "CSBoardDisplay", center - 58, 51, colors.ct, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("—", "CSBoardTeam", center, 51, colors.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(GetGlobalInt("CSRoundScoreT", 0), "CSBoardDisplay", center + 58, 51, colors.t, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("РАУНДЫ " .. GetGlobalInt("CSRoundsPlayed", 0) .. " / " .. GetGlobalInt("CSRoundLimit", 30), "CSBoardLabel", center, 80, colors.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local status, statusColor = "ОЖИДАНИЕ ИГРОКОВ", colors.muted

        if GetGlobalBool("CSRoundGetReady", false) then
            status, statusColor = "ПРИГОТОВЬТЕСЬ", colors.gold
        elseif GetGlobalBool("CSBombPlanted", false) then
            status, statusColor = "БОМБА УСТАНОВЛЕНА", colors.t
        elseif GetGlobalBool("CSRoundActive", false) then
            status, statusColor = "РАУНД ИДЁТ", colors.text
        end

        draw.SimpleText(status, "CSBoardLabel", center, 104, statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local margin, gap, specHeight, columnY = 24, 18, 70, 130
    local columnWidth = math.floor((width - margin * 2 - gap) * 0.5)
    local columnHeight = height - columnY - 24 - specHeight - gap

    ctList = CreateTeamColumn(board, margin, columnY, columnWidth, columnHeight, TEAM_CS_CT, "COUNTER-TERRORISTS", colors.ct)
    tList = CreateTeamColumn(board, margin + columnWidth + gap, columnY, columnWidth, columnHeight, TEAM_CS_T, "TERRORISTS", colors.t)
    CreateSpectatorPanel(board, margin, columnY + columnHeight + gap, width - margin * 2, specHeight)

    board.Think = function()
        local now = RealTime()
        if now < nextRefresh then return end
        nextRefresh = now + 0.75
        RefreshList(ctList, TEAM_CS_CT, colors.ct)
        RefreshList(tList, TEAM_CS_T, colors.t)
    end

    RefreshList(ctList, TEAM_CS_CT, colors.ct)
    RefreshList(tList, TEAM_CS_T, colors.t)
end

hook.Add("ScoreboardShow", "CSGO.ScoreboardShow", function()
    nextSpecUpdate = 0
    CreateBoard()
    return true
end)

hook.Add("ScoreboardHide", "CSGO.ScoreboardHide", function()
    if IsValid(board) then board:Remove() end
    board, ctList, tList = nil, nil, nil
    return true
end)
