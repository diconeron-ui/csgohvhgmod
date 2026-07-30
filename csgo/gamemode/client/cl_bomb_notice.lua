local noticeEndTime = 0
local NOTICE_TEXT = "БОМБА УСТАНОВЛЕНА"
local boxColor = Color(20, 23, 29, 235)
local innerColor = Color(105, 28, 28, 235)
local textColor = Color(255, 238, 238)

surface.CreateFont("CSBombPlantedNotice", {
    font = "Arial",
    size = 32,
    weight = 900,
    extended = true
})

net.Receive("CSRounds.BombPlantedNotice", function()
    noticeEndTime = RealTime() + 2
end)

hook.Add("HUDPaint", "CSRounds.BombPlantedNotice", function()
    if RealTime() >= noticeEndTime then return end

    surface.SetFont("CSBombPlantedNotice")
    local textWidth, textHeight = surface.GetTextSize(NOTICE_TEXT)
    local width = textWidth + 48
    local height = textHeight + 24
    local x = (ScrW() - width) * 0.5
    local y = math.max(100, ScrH() * 0.1)

    draw.RoundedBox(8, x, y, width, height, boxColor)
    draw.RoundedBox(6, x + 2, y + 2, width - 4, height - 4, innerColor)
    draw.SimpleText(NOTICE_TEXT, "CSBombPlantedNotice", ScrW() * 0.5, y + height * 0.5, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
