local SH = CSGOSpectatorShared
local TEAM_CS_CT = CSGOConfig.TeamCT
local TEAM_CS_T = CSGOConfig.TeamT

local colors = {
    panel = Color(15, 18, 24, 225),
    border = Color(71, 79, 94, 230),
    text = Color(245, 247, 250),
    muted = Color(162, 171, 187),
    hint = Color(210, 216, 226),
    outline = Color(0, 0, 0, 245),
    ct = Color(94, 159, 232),
    t = Color(233, 115, 102),
    health = Color(120, 200, 130)
}

surface.CreateFont("CSSpecTitle", { font = "Arial", size = 26, weight = 900, extended = true })
surface.CreateFont("CSSpecBody", { font = "Arial", size = 17, weight = 700, extended = true })
surface.CreateFont("CSSpecLabel", { font = "Arial", size = 13, weight = 800, extended = true })

local hiddenElements = {
    CHudHealth = true,
    CHudBattery = true,
    CHudAmmo = true,
    CHudSecondaryAmmo = true,
    CHudCrosshair = true,
    CHudWeaponSelection = true
}

local HINT = "ЛКМ — СЛЕДУЮЩИЙ    ПКМ — ПРЕДЫДУЩИЙ    ПРОБЕЛ — РЕЖИМ КАМЕРЫ    !team — СМЕНА КОМАНДЫ"

local function TeamColor(teamID)
    if teamID == TEAM_CS_CT then return colors.ct end
    if teamID == TEAM_CS_T then return colors.t end
    return colors.muted
end

hook.Add("HUDShouldDraw", "CSGO.SpectatorHideHUD", function(name)
    if not hiddenElements[name] then return end

    local ply = LocalPlayer()
    if IsValid(ply) and ply:GetObserverMode() ~= OBS_MODE_NONE then return false end
end)

hook.Add("HUDPaint", "CSGO.SpectatorHUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local mode = ply:GetObserverMode()
    if mode == OBS_MODE_NONE then return end

    local target = ply:GetObserverTarget()
    local width, height = 460, 92
    local x = ScrW() * 0.5 - width * 0.5
    local y = ScrH() - height - 46
    local center = x + width * 0.5

    draw.RoundedBox(9, x - 1, y - 1, width + 2, height + 2, colors.border)
    draw.RoundedBox(8, x, y, width, height, colors.panel)

    draw.SimpleTextOutlined("РЕЖИМ НАБЛЮДАТЕЛЯ", "CSSpecLabel", center, y + 16, colors.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, colors.outline)

    if mode ~= OBS_MODE_ROAMING and IsValid(target) and target:IsPlayer() then
        local weapon = target:GetActiveWeapon()
        local weaponName = IsValid(weapon) and (weapon.PrintName or weapon:GetClass()) or "—"

        draw.SimpleTextOutlined(target:Nick(), "CSSpecTitle", center, y + 42, TeamColor(target:Team()), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, colors.outline)
        draw.SimpleTextOutlined("HP " .. math.max(0, target:Health()), "CSSpecBody", x + 20, y + 70, colors.health, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, colors.outline)
        draw.SimpleTextOutlined(SH.GetModeName(mode), "CSSpecLabel", center, y + 70, colors.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, colors.outline)
        draw.SimpleTextOutlined(string.upper(weaponName), "CSSpecLabel", x + width - 20, y + 70, colors.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, 1, colors.outline)
    else
        draw.SimpleTextOutlined(SH.GetModeName(mode), "CSSpecTitle", center, y + 48, colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, colors.outline)
        draw.SimpleTextOutlined("НЕТ ЦЕЛИ ДЛЯ НАБЛЮДЕНИЯ", "CSSpecLabel", center, y + 72, colors.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, colors.outline)
    end

    draw.SimpleTextOutlined(HINT, "CSSpecLabel", ScrW() * 0.5, y + height + 18, colors.hint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1.5, colors.outline)
end)
