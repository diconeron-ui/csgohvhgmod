local IsPlayTeam = CSGOConfig.IsPlayTeam
local C4_CLASS = CSGOConfig.C4Class

local function ResolvePlayerAttacker(attacker)
    if not IsValid(attacker) then return nil end
    if attacker:IsPlayer() then return attacker end

    local owner = attacker.GetOwner and attacker:GetOwner()

    if IsValid(owner) and owner:IsPlayer() then
        return owner
    end
end

local function ApplyMovementConVars()
    RunConsoleCommand("sv_gravity", tostring(CSGOConfig.Gravity))
    RunConsoleCommand("sv_accelerate", tostring(CSGOConfig.Accelerate))
    RunConsoleCommand("sv_airaccelerate", tostring(CSGOConfig.AirAccelerate))
    RunConsoleCommand("sv_friction", tostring(CSGOConfig.Friction))
    RunConsoleCommand("sv_stopspeed", tostring(CSGOConfig.StopSpeed))
    RunConsoleCommand("sv_maxvelocity", tostring(CSGOConfig.MaxVelocity))
    RunConsoleCommand("sv_sticktoground", "0")
end

ApplyMovementConVars()
hook.Add("InitPostEntity", "CSGO.MovementConVars", ApplyMovementConVars)

function CSGOGiveLoadout(ply, strip)
    if not IsValid(ply) or not ply:IsPlayer() or not IsPlayTeam(ply:Team()) then return false end

    ply.CSGOGivingLoadout = true

    if strip then ply:StripWeapons() end

    local success = true

    for i = 1, #CSGOConfig.Loadout do
        local className = CSGOConfig.Loadout[i]

        if not ply:HasWeapon(className) and not IsValid(ply:Give(className)) then
            success = false
            ErrorNoHalt("[CSGO] Failed to give " .. className .. " to " .. ply:Nick() .. "\n")
        end
    end

    ply.CSGOGivingLoadout = nil

    return success
end

function GM:PlayerLoadout(ply)
    CSGOGiveLoadout(ply, true)
    return true
end

hook.Add("PlayerShouldTakeDamage", "CSGO.DisableFriendlyFire", function(victim, attacker)
    if not IsValid(victim) or not victim:IsPlayer() then return end
    if CSRounds and CSRounds:IsGetReady() then return false end

    local attackingPlayer = ResolvePlayerAttacker(attacker)
    if not IsValid(attackingPlayer) or attackingPlayer == victim then return end

    local victimTeam = victim:Team()

    if IsPlayTeam(victimTeam) and attackingPlayer:Team() == victimTeam then
        return false
    end
end)

hook.Add("PostEntityTakeDamage", "CSGO.DamageSlowdown", function(target, damageInfo, wasDamageTaken)
    if not wasDamageTaken or not IsValid(target) or not target:IsPlayer() or not target:Alive() then return end
    CSGOApplyDamageSlowdown(target, damageInfo:GetDamage())
end)

hook.Add("GetFallDamage", "CSGO.FallDamage", function(ply, speed)
    if speed <= CSGOConfig.FallDamageThreshold then return 0 end
    return (speed - CSGOConfig.FallDamageThreshold) * CSGOConfig.FallDamagePerUnit
end)

hook.Add("PlayerCanPickupWeapon", "CSGO.PickupRules", function(ply, weapon)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if ply.CSGOGivingLoadout then return true end
    if not IsPlayTeam(ply:Team()) or not ply:Alive() then return false end

    if IsValid(weapon) and weapon:GetClass() == C4_CLASS then
        if ply:Team() ~= CSGOConfig.TeamT then return false end
        if CSRounds and not CSRounds:IsParticipant(ply) then return false end
    end

    return true
end)

local function IsExemptSuperAdmin(ply)
    return IsValid(ply) and ply:IsPlayer() and ply:IsSuperAdmin()
end

local blockedHooks = {
    "PlayerSpawnProp",
    "PlayerSpawnRagdoll",
    "PlayerSpawnEffect",
    "PlayerSpawnNPC",
    "PlayerSpawnSENT",
    "PlayerSpawnSWEP",
    "PlayerGiveSWEP",
    "PlayerSpawnVehicle",
    "CanTool",
    "CanProperty",
    "CanDrive"
}

for _, hookName in ipairs(blockedHooks) do
    hook.Add(hookName, "CSGO.Block." .. hookName, function(ply)
        if IsExemptSuperAdmin(ply) then return end
        return false
    end)
end

local cleanupHooks = {
    "PlayerSpawnedProp",
    "PlayerSpawnedRagdoll",
    "PlayerSpawnedEffect",
    "PlayerSpawnedNPC",
    "PlayerSpawnedSENT",
    "PlayerSpawnedSWEP",
    "PlayerSpawnedVehicle"
}

for _, hookName in ipairs(cleanupHooks) do
    hook.Add(hookName, "CSGO.Cleanup." .. hookName, function(ply, first, second)
        if IsExemptSuperAdmin(ply) then return end

        local entity = IsValid(second) and second or IsValid(first) and first

        if IsValid(entity) and entity:GetClass() ~= CSGOConfig.PlantedC4Class then
            SafeRemoveEntity(entity)
        end
    end)
end

hook.Add("CanPlayerEnterVehicle", "CSGO.BlockVehicles", function(ply)
    if IsExemptSuperAdmin(ply) then return end
    return false
end)

hook.Add("PlayerNoClip", "CSGO.DisableNoclip", function(ply)
    return IsExemptSuperAdmin(ply)
end)
