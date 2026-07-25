local entries = {}
local LIFETIME = 6
local MAX_ENTRIES = 6
local ctColor = Color(94, 159, 232)
local tColor = Color(233, 115, 102)
local neutralColor = Color(210, 215, 224)

surface.CreateFont("CSKillfeedName", {
    font = "Arial",
    size = 17,
    weight = 700,
    extended = true
})

surface.CreateFont("CSKillfeedMeta", {
    font = "Arial",
    size = 12,
    weight = 800,
    extended = true
})

local function TeamColor(teamID)
    if teamID == CSGOConfig.TeamCT then return ctColor end
    if teamID == CSGOConfig.TeamT then return tColor end
    return neutralColor
end

local function WeaponLabel(className)
    local label = string.gsub(className or "world", "^weapon_swcs_", "")
    label = string.gsub(label, "^weapon_", "")
    label = string.gsub(label, "_", " ")
    return string.upper(label)
end

net.Receive("CSGO.Killfeed", function()
    entries[#entries + 1] = {
        attacker = net.ReadString(),
        attackerTeam = net.ReadUInt(3),
        victim = net.ReadString(),
        victimTeam = net.ReadUInt(3),
        weapon = WeaponLabel(net.ReadString()),
        headshot = net.ReadBool(),
        created = RealTime()
    }

    while #entries > MAX_ENTRIES do
        table.remove(entries, 1)
    end
end)

hook.Add("HUDShouldDraw", "CSGO.HideDefaultKillfeed", function(name)
    if name == "CHudDeathNotice" then return false end
end)

hook.Add("HUDPaint", "CSGO.Killfeed", function()
    if #entries == 0 then return end

    local now = RealTime()
    local y = 28

    for index = #entries, 1, -1 do
        local entry = entries[index]
        local age = now - entry.created

        if age >= LIFETIME then
            table.remove(entries, index)
        else
            local alpha = math.Clamp((LIFETIME - age) * 2, 0, 1) * 235
            surface.SetFont("CSKillfeedName")
            local attackerWidth = surface.GetTextSize(entry.attacker)
            local victimWidth = surface.GetTextSize(entry.victim)
            surface.SetFont("CSKillfeedMeta")
            local weaponWidth = surface.GetTextSize(entry.weapon)
            local headshotWidth = entry.headshot and surface.GetTextSize("HEADSHOT") + 12 or 0
            local width = math.max(310, attackerWidth + weaponWidth + headshotWidth + victimWidth + 72)
            local x = ScrW() - width - 24
            local height = 38
            local victimX = x + width - 16
            local headshotX = victimX - victimWidth - 8
            local weaponX = headshotX - headshotWidth - weaponWidth * 0.5 - 8

            draw.RoundedBox(7, x, y, width, height, Color(18, 21, 27, alpha))
            draw.RoundedBox(7, x, y, 4, height, Color(94, 159, 232, alpha))
            draw.SimpleText(entry.attacker, "CSKillfeedName", x + 16, y + 19, ColorAlpha(TeamColor(entry.attackerTeam), alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(entry.victim, "CSKillfeedName", victimX, y + 19, ColorAlpha(TeamColor(entry.victimTeam), alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

            draw.SimpleText(entry.weapon, "CSKillfeedMeta", weaponX, y + 13, Color(225, 229, 236, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("→", "CSKillfeedMeta", weaponX, y + 27, Color(145, 153, 168, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            if entry.headshot then
                draw.SimpleText("HEADSHOT", "CSKillfeedMeta", headshotX, y + 19, Color(234, 194, 107, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end

            y = y + height + 7
        end
    end
end)
