local TEAM_CS_CT = CSGOConfig.TeamCT
local TEAM_CS_T = CSGOConfig.TeamT
local frame

local colors = {
    border = Color(71, 79, 94, 230),
    background = Color(15, 18, 24, 250),
    row = Color(34, 39, 49, 245),
    rowHover = Color(43, 50, 63, 250),
    text = Color(245, 247, 250),
    muted = Color(162, 171, 187),
    ct = Color(94, 159, 232),
    t = Color(233, 115, 102)
}

surface.CreateFont("CSTeamMenuTitle", { font = "Arial", size = 30, weight = 900, extended = true })
surface.CreateFont("CSTeamMenuTeam", { font = "Arial", size = 20, weight = 900, extended = true })
surface.CreateFont("CSTeamMenuBody", { font = "Arial", size = 16, weight = 650, extended = true })
surface.CreateFont("CSTeamMenuLabel", { font = "Arial", size = 12, weight = 800, extended = true })

local function ChooseTeam(teamID)
    net.Start("CSTeam_Choose")
    net.WriteUInt(teamID, 16)
    net.SendToServer()
    if IsValid(frame) then frame:Remove() end
end

local function CreateTeamButton(parent, teamID, x, width, title, accent)
    local button = vgui.Create("DButton", parent)
    button:SetPos(x, 100)
    button:SetSize(width, 150)
    button:SetText("")
    button.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, self:IsHovered() and colors.rowHover or colors.row)
        draw.RoundedBox(8, 0, 0, 5, h, accent)
        draw.SimpleText(title, "CSTeamMenuTeam", 20, 36, accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(team.NumPlayers(teamID) .. " ИГРОКОВ", "CSTeamMenuLabel", 20, 64, colors.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("ВЫБРАТЬ", "CSTeamMenuBody", w * 0.5, h - 36, self:IsHovered() and colors.text or colors.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    button.DoClick = function() ChooseTeam(teamID) end
end

local function OpenTeamMenu()
    if IsValid(frame) then
        frame:MakePopup()
        return
    end

    local width, height, margin, gap = math.min(680, ScrW() - 48), 290, 22, 16
    local buttonWidth = math.floor((width - margin * 2 - gap) * 0.5)

    frame = vgui.Create("DFrame")
    frame:SetSize(width, height)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame.Paint = function(_, w, h)
        draw.RoundedBox(11, 0, 0, w, h, colors.border)
        draw.RoundedBox(10, 1, 1, w - 2, h - 2, colors.background)
        draw.SimpleText("ВЫБОР КОМАНДЫ", "CSTeamMenuTitle", w * 0.5, 38, colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("ВЫБЕРИТЕ СТОРОНУ ДЛЯ СЛЕДУЮЩЕГО РАУНДА", "CSTeamMenuLabel", w * 0.5, 70, colors.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    CreateTeamButton(frame, TEAM_CS_CT, margin, buttonWidth, "COUNTER-TERRORISTS", colors.ct)
    CreateTeamButton(frame, TEAM_CS_T, margin + buttonWidth + gap, buttonWidth, "TERRORISTS", colors.t)
    frame:MakePopup()
end

net.Receive("CSTeam_Open", OpenTeamMenu)
