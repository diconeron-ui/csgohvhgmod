util.AddNetworkString("CSGO.Killfeed")

local IsPlayTeam = CSGOConfig.IsPlayTeam

local function TeamID(entity)
    if not IsValid(entity) or not entity:IsPlayer() then return 0 end
    local teamID = entity:Team()
    return IsPlayTeam(teamID) and teamID or 0
end

hook.Add("PlayerDeath", "CSGO.Killfeed", function(victim, inflictor, attacker)
    local attackerName = "WORLD"
    local attackerTeam = 0

    if IsValid(attacker) and attacker:IsPlayer() then
        attackerName = attacker:Nick()
        attackerTeam = TeamID(attacker)
    end

    local weaponClass = "world"
    if IsValid(inflictor) then
        weaponClass = inflictor:GetClass()
    elseif IsValid(attacker) and attacker:IsPlayer() then
        local weapon = attacker:GetActiveWeapon()
        if IsValid(weapon) then
            weaponClass = weapon:GetClass()
        end
    end

    local headshot = IsValid(victim) and victim:LastHitGroup() == HITGROUP_HEAD

    net.Start("CSGO.Killfeed")
    net.WriteString(attackerName)
    net.WriteUInt(attackerTeam, 3)
    net.WriteString(IsValid(victim) and victim:Nick() or "PLAYER")
    net.WriteUInt(TeamID(victim), 3)
    net.WriteString(weaponClass)
    net.WriteBool(headshot)
    net.Broadcast()
end)
