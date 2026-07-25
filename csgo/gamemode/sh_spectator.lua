CSGOConfig = CSGOConfig or {}
CSGOConfig.TeamSpectator = CSGOConfig.TeamSpectator or TEAM_SPECTATOR

team.SetUp(CSGOConfig.TeamSpectator, "Spectators", Color(150, 158, 172), true)

local TEAM_CS_SPEC = CSGOConfig.TeamSpectator

function CSGOConfig.IsSpectatorTeam(teamID)
    return teamID == TEAM_CS_SPEC
end

function CSGOConfig.IsIdleTeam(teamID)
    return teamID == TEAM_CS_SPEC or teamID == TEAM_UNASSIGNED
end

CSGOSpectatorShared = CSGOSpectatorShared or {}
local SH = CSGOSpectatorShared

SH.ModeOrder = { OBS_MODE_CHASE, OBS_MODE_IN_EYE, OBS_MODE_ROAMING }
SH.ModeCount = #SH.ModeOrder
SH.ModeIndex = {}

for index = 1, SH.ModeCount do
    SH.ModeIndex[SH.ModeOrder[index]] = index
end

SH.ModeNames = {
    [OBS_MODE_CHASE] = "ОТ ТРЕТЬЕГО ЛИЦА",
    [OBS_MODE_IN_EYE] = "ОТ ПЕРВОГО ЛИЦА",
    [OBS_MODE_ROAMING] = "СВОБОДНАЯ КАМЕРА"
}

function SH.GetModeName(mode)
    return SH.ModeNames[mode] or "КАМЕРА"
end

function SH.IsLivePlayer(ply)
    return IsValid(ply) and ply:IsPlayer() and ply:Alive()
        and CSGOConfig.IsPlayTeam(ply:Team()) and ply:GetObserverMode() == OBS_MODE_NONE
end

function SH.CanSpectateTarget(viewer, target)
    if target == viewer or not SH.IsLivePlayer(target) then return false end
    if IsValid(viewer) and CSGOConfig.IsPlayTeam(viewer:Team()) then
        return target:Team() == viewer:Team()
    end
    return true
end

local function SortTargets(a, b)
    if a:Team() ~= b:Team() then return a:Team() < b:Team() end
    return a:EntIndex() < b:EntIndex()
end

function SH.GetTargets(viewer)
    local targets, count = {}, 0
    for _, ply in ipairs(player.GetAll()) do
        if SH.CanSpectateTarget(viewer, ply) then
            count = count + 1
            targets[count] = ply
        end
    end
    table.sort(targets, SortTargets)
    return targets
end

local function SortNames(a, b)
    return string.lower(a:Nick()) < string.lower(b:Nick())
end

function SH.GetSpectators()
    local list, count = {}, 0
    for _, ply in ipairs(player.GetAll()) do
        if CSGOConfig.IsIdleTeam(ply:Team()) then
            count = count + 1
            list[count] = ply
        end
    end
    table.sort(list, SortNames)
    return list
end
