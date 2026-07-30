CSGOTheme = CSGOTheme or {}

local T = CSGOTheme

T.Colors = {
    Background = Color(16, 18, 22, 230),
    Panel = Color(26, 29, 35, 240),
    Row = Color(32, 36, 44, 220),
    RowAlt = Color(38, 43, 52, 220),
    Text = Color(235, 238, 244),
    TextDim = Color(150, 158, 172),
    Accent = Color(222, 155, 53),
    Danger = Color(214, 74, 74),
    Success = Color(93, 186, 106),
    CT = Color(80, 140, 255),
    T = Color(255, 90, 90),
    Spectator = Color(150, 158, 172)
}

function T.TeamColor(teamID)
    if teamID == CSGOConfig.TeamCT then return T.Colors.CT end
    if teamID == CSGOConfig.TeamT then return T.Colors.T end
    return T.Colors.Spectator
 end

local fontSizes = {
    ["CSGO.Small"] = 15,
    ["CSGO.Medium"] = 19,
    ["CSGO.Large"] = 26,
    ["CSGO.Huge"] = 44,
    ["CSGO.Killfeed"] = 18
}

for name, size in pairs(fontSizes) do
    surface.CreateFont(name, {
        font = "Roboto",
        size = size,
        weight = 600,
        antialias = true,
        extended = true
    })
end

function T.FormatTime(seconds)
    seconds = math.max(0, math.ceil(seconds))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end
