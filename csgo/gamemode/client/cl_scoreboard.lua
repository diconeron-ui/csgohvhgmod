local board
local ctList
local tList
local nextRefresh = 0

local colors = {
    border = Color(71, 79, 94, 230),
    background = Color(15, 18, 24, 250),
    surface = Color(25, 29, 37, 250),
    row = Color(34, 39, 49, 245),
    text = Color(245, 247, 250),
    muted = Color(162, 171, 187),
    ct = Color(94, 159, 232),
    t = Color(233, 115, 102),
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
        local valid = IsValid(ply)
        draw.RoundedBox(6, 0, 0, w, h, colors.row)
        draw.RoundedBox(6, 0, 0, 4, h, accent)
        draw.SimpleText(valid and ply:Nick() or "Disconnected", "CSBoardBody", 18, h * 0.5, colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(valid and ply:Frags() or 0, "CSBoardBody", w - 170, h * 0.5, colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(valid and ply:Deaths() or 0, "CSBoardBody", w - 104, h * 0.5, colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(valid and ply:Ping() or 0, "CSBoardBody", w - 38, h * 0.5, colors.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    list:AddItem(row)
end

local function RefreshList(list, teamID, accent)
    if not IsValid(list) then return end

    local canvas = list:GetCanvas()
    if IsValid(canvas) then canvas:Clear() end

    local players = team.GetPlayers(teamID)
    table.sort(players, function(a, b)
        if a:Frags() ~= b:Frags() then return a:Frags() > b:Frags() end
        return string.lower(a:Nick()) < string.lower(b:Nick())
    end)

    for _, ply in ipairs(players) do
        AddPlayerRow(list, ply, accent)
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

        local ctScore = GetGlobalInt("CSRoundScoreCT", 0)
        local tScore = GetGlobalInt("CSRoundScoreT", 0)
        local played = GetGlobalInt("CSRoundsPlayed", 0)
        local limit = GetGlobalInt("CSRoundLimit", 30)
        draw.SimpleText("MATCH SCORE", "CSBoardLabel", w * 0.5, 22, colors.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(ctScore, "CSBoardDisplay", w * 0.5 - 58, 51, colors.ct, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("—", "CSBoardTeam", w * 0.5, 51, colors.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(tScore, "CSBoardDisplay", w * 0.5 + 58, 51, colors.t, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("РАУНДЫ " .. played .. " / " .. limit, "CSBoardLabel", w * 0.5, 80, colors.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local status = "ОЖИДАНИЕ ИГРОКОВ"
        local statusColor = colors.muted
        if GetGlobalBool("CSRoundGetReady", false) then
            status = "ПРИГОТОВЬТЕСЬ"
            statusColor = colors.gold
        elseif GetGlobalBool("CSBombPlanted", false) then
            status = "БОМБА УСТАНОВЛЕНА"
            statusColor = colors.t
        elseif GetGlobalBool("CSRoundActive", false) then
            status = "РАУНД ИДЁТ"
            statusColor = colors.text
        end
        draw.SimpleText(status, "CSBoardLabel", w * 0.5, 104, statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local gap = 18
    local margin = 24
    local columnWidth = math.floor((width - margin * 2 - gap) * 0.5)
    local columnY = 130
    local columnHeight = height - columnY - 24
    ctList = CreateTeamColumn(board, margin, columnY, columnWidth, columnHeight, CSGOConfig.TeamCT, "COUNTER-TERRORISTS", colors.ct)
    tList = CreateTeamColumn(board, margin + columnWidth + gap, columnY, columnWidth, columnHeight, CSGOConfig.TeamT, "TERRORISTS", colors.t)

    board.Think = function()
        if RealTime() < nextRefresh then return end
        nextRefresh = RealTime() + 0.75
        RefreshList(ctList, CSGOConfig.TeamCT, colors.ct)
        RefreshList(tList, CSGOConfig.TeamT, colors.t)
    end

    RefreshList(ctList, CSGOConfig.TeamCT, colors.ct)
    RefreshList(tList, CSGOConfig.TeamT, colors.t)
end

hook.Add("ScoreboardShow", "CSGO.ScoreboardShow", function()
    CreateBoard()
    return true
end)

hook.Add("ScoreboardHide", "CSGO.ScoreboardHide", function()
    if IsValid(board) then board:Remove() end
    board = nil
    ctList = nil
    tList = nil
    return true
end)
