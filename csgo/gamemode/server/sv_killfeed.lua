util.AddNetworkString("CSGO.Killfeed")

local IsPlayTeam = CSGOConfig.IsPlayTeam
local MAX_NAME = CSGOConfig.MaxNameLength

local function TeamID(entity)
    if not IsValid(entity) or not entity:IsPlayer() then return 0 end
    local teamID = entity:Team()
    return IsPlayTeam(teamID) and teamID or 0
end

local function WeaponClass(inflictor, attacker)
    if IsValid(attacker) and attacker:IsPlayer() then
        if IsValid(inflictor) and inflictor ~= attacker and inflictor:IsWeapon() then
            return inflictor:GetClass()
        end

        local weapon = attacker:GetActiveWeapon()
        if IsValid(weapon) then return weapon:GetClass() end
    end

    if IsValid(inflictor) and not inflictor:IsPlayer() then
        return inflictor:GetClass()
    end

    return "world"
end

hook.Add("PlayerDeath", "CSGO.Killfeed", function(victim, inflictor, attacker)
    if not IsValid(victim) or not victim:IsPlayer() then return end

    local attackerName = "WORLD"
    local attackerTeam = 0

    if IsValid(attacker) and attacker:IsPlayer() then
        attackerName = string.sub(attacker:Nick(), 1, MAX_NAME)
        attackerTeam = TeamID(attacker)
    end

    net.Start("CSGO.Killfeed")
    net.WriteString(attackerName)
    net.WriteUInt(attackerTeam, 3)
    net.WriteString(string.sub(victim:Nick(), 1, MAX_NAME))
    net.WriteUInt(TeamID(victim), 3)
    net.WriteString(string.sub(WeaponClass(inflictor, attacker), 1, 64))
    net.WriteBool(victim:LastHitGroup() == HITGROUP_HEAD)
    net.Broadcast()
end)
