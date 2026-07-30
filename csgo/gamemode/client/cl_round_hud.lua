local ctColor = Color(94, 159, 232)
local tColor = Color(233, 115, 102)
local textColor = Color(245, 247, 250)
local mutedColor = Color(171, 179, 192)
local goldColor = Color(234, 194, 107)
local panelColor = Color(15, 18, 24, 238)
local ctPanelColor = Color(33, 54, 79, 245)
local tPanelColor = Color(75, 35, 37, 245)

surface.CreateFont("CSRoundHUDScore", {
    font = "Arial",
    size = 28,
    weight = 900,
    extended = true
})

surface.CreateFont("CSRoundHUDMain", {
    font = "Arial",
    size = 18,
    weight = 800,
    extended = true
})

surface.CreateFont("CSRoundHUDMeta", {
    font = "Arial",
    size = 12,
    weight = 700,
    extended = true
})

hook.Add("HUDPaint", "CSGO.RoundHUD", function()
    local width = 470
    local height = 66
    local x = (ScrW() - width) * 0.5
    local y = 18
    local scoreCT = GetGlobalInt("CSRoundScoreCT", 0)
    local scoreT = GetGlobalInt("CSRoundScoreT", 0)
    local round = GetGlobalInt("CSRoundNumber", 0)
    local limit = GetGlobalInt("CSRoundLimit", 30)

    draw.RoundedBox(9, x, y, width, height, panelColor)
    draw.RoundedBoxEx(9, x, y, 116, height, ctPanelColor, true, false, true, false)
    draw.RoundedBoxEx(9, x + width - 116, y, 116, height, tPanelColor, false, true, false, true)

    draw.SimpleText("CT", "CSRoundHUDMeta", x + 18, y + 14, ctColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(scoreCT, "CSRoundHUDScore", x + 92, y + 34, textColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    draw.SimpleText("T", "CSRoundHUDMeta", x + width - 18, y + 14, tColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    draw.SimpleText(scoreT, "CSRoundHUDScore", x + width - 92, y + 34, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local status = "ОЖИДАНИЕ"
    local statusColor = mutedColor

    if GetGlobalBool("CSRoundGetReady", false) then
        local remaining = math.max(1, math.ceil(GetGlobalFloat("CSRoundReadyEnd", 0) - CurTime()))
        status = "ПРИГОТОВЬТЕСЬ  " .. remaining
        statusColor = goldColor
    elseif GetGlobalBool("CSBombPlanted", false) then
        status = "БОМБА · " .. GetGlobalString("CSBombSite", "")
        statusColor = tColor
    elseif GetGlobalBool("CSRoundActive", false) then
        local remaining = math.max(0, math.ceil(GetGlobalFloat("CSRoundEndTime", 0) - CurTime()))
        status = string.format("%02d:%02d", math.floor(remaining / 60), remaining % 60)
        statusColor = textColor
    end

    draw.SimpleText(status, "CSRoundHUDMain", x + width * 0.5, y + 27, statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("РАУНД " .. round .. " / " .. limit, "CSRoundHUDMeta", x + width * 0.5, y + 50, mutedColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
