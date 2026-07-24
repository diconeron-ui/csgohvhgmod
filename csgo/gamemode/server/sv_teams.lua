local TEAM_CS_CT = CSGOConfig.TeamCT
local TEAM_CS_T = CSGOConfig.TeamT
local IsPlayTeam = CSGOConfig.IsPlayTeam
local GetOtherTeam = CSGOConfig.OtherTeam

CSTeamSystem = CSTeamSystem or {}
local TS = CSTeamSystem

util.AddNetworkString("CSTeam_Open")
util.AddNetworkString("CSTeam_Choose")

for _, models in pairs(CSGOConfig.TeamModels) do
    for _, modelPath in ipairs(models) do
        util.PrecacheModel(modelPath)
    end
end

local netCooldown = setmetatable({}, { __mode = "k" })
local choiceCooldown = setmetatable({}, { __mode = "k" })
local menuCooldown = setmetatable({}, { __mode = "k" })

local function CanJoinTeam(ply, teamID)
    if not IsPlayTeam(teamID) then return false end

    local otherTeam = GetOtherTeam(teamID)
    local targetCount = team.NumPlayers(teamID)
    local otherCount = team.NumPlayers(otherTeam)

    if IsValid(ply) and ply:IsPlayer() and ply:Team() == otherTeam then
        otherCount = math.max(0, otherCount - 1)
    end

    return targetCount <= otherCount
end

local function OpenMenu(ply, force)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local now = CurTime()
    if not force and (menuCooldown[ply] or 0) > now then return end
    menuCooldown[ply] = now + 1

    net.Start("CSTeam_Open")
    net.Send(ply)
end

function TS:OpenMenu(ply, force)
    OpenMenu(ply, force)
end

function GM:ShowTeam(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    OpenMenu(ply, true)
end

function TS:ResetPlayer(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    choiceCooldown[ply] = 0
    netCooldown[ply] = 0
    menuCooldown[ply] = 0
    CSGOResetMovementState(ply)
    ply:StripWeapons()
    ply:UnSpectate()
    ply:SetTeam(TEAM_UNASSIGNED)

    if ply:Alive() then
        ply:KillSilent()
    end

    ply:Spectate(OBS_MODE_ROAMING)

    timer.Simple(0.1, function()
        if not IsValid(ply) then return end
        ply:SetTeam(TEAM_UNASSIGNED)
        ply:Spectate(OBS_MODE_ROAMING)
        OpenMenu(ply, true)
    end)
end

function TS:ResetMatchCooldowns()
    for _, ply in ipairs(player.GetAll()) do
        choiceCooldown[ply] = 0
        netCooldown[ply] = 0
        menuCooldown[ply] = 0
        CSGOResetMovementState(ply)
    end
end

function TS:MakeSpectator(ply, openMenu)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    ply:Freeze(false)
    ply:StripWeapons()
    if ply:Alive() then
        ply:KillSilent()
    end
    ply:Spectate(OBS_MODE_ROAMING)

    if openMenu then
        timer.Simple(0, function()
            if IsValid(ply) and ply:Team() == TEAM_UNASSIGNED then
                OpenMenu(ply, true)
            end
        end)
    end
end

local function ApplyTeamModel(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local teamID = ply:Team()
    if not IsPlayTeam(teamID) then return end

    local models = CSGOConfig.TeamModels[teamID]
    if not istable(models) or #models == 0 then return end

    local model = models[math.random(#models)]
    if not isstring(model) or model == "" then return end

    ply:SetModel(model)
    ply:SetupHands()
end

local function EnterSpectator(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if IsPlayTeam(ply:Team()) then return end
    TS:MakeSpectator(ply, true)
end

local function TrySetTeam(ply, teamID)
    if not IsValid(ply) or not ply:IsPlayer() or not IsPlayTeam(teamID) then return end

    local now = CurTime()
    if (choiceCooldown[ply] or 0) > now then return end
    choiceCooldown[ply] = now + 0.75

    local sameTeam = ply:Team() == teamID
    local activelyPlaying = ply:GetObserverMode() == OBS_MODE_NONE and ply:Alive()

    if sameTeam and activelyPlaying then return end

    local roundLocked = CSRounds and CSRounds.IsRoundLocked and CSRounds:IsRoundLocked()

    if roundLocked and IsPlayTeam(ply:Team()) then
        if sameTeam then
            CSRounds:QueuePlayer(ply)
        else
            ply:ChatPrint("Сменить команду можно после окончания матча.")
        end
        return
    end

    if not sameTeam and not CanJoinTeam(ply, teamID) then
        ply:ChatPrint("В этой команде больше игроков.")
        OpenMenu(ply, true)
        return
    end

    if not sameTeam then
        ply:SetTeam(teamID)
    end

    if roundLocked then
        CSRounds:QueuePlayer(ply)
    else
        ply:UnSpectate()
        ply:Spawn()
    end
end

net.Receive("CSTeam_Choose", function(length, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local now = CurTime()
    if (netCooldown[ply] or 0) > now then return end
    netCooldown[ply] = now + 0.2

    if length ~= 16 then return end

    local teamID = net.ReadUInt(16)
    if not IsPlayTeam(teamID) then return end

    TrySetTeam(ply, teamID)
end)

function GM:PlayerInitialSpawn(ply)
    player_manager.SetPlayerClass(ply, "player_csgo")
    ply:SetTeam(TEAM_UNASSIGNED)
    timer.Simple(0, function()
        if IsValid(ply) and ply:Team() == TEAM_UNASSIGNED then
            TS:MakeSpectator(ply, true)
        end
    end)
end

function GM:PlayerSetModel(ply)
    ApplyTeamModel(ply)
end

hook.Add("PlayerSpawn", "CSGO.TeamSpawn", function(ply)
    player_manager.SetPlayerClass(ply, "player_csgo")

    local teamID = ply:Team()
    if not IsPlayTeam(teamID) then
        timer.Simple(0, function()
            EnterSpectator(ply)
        end)
        return
    end

    local position = CSGOConfig.SpawnPositions[teamID]

    timer.Simple(0, function()
        if not IsValid(ply) or ply:Team() ~= teamID or not ply:Alive() then return end

        ApplyTeamModel(ply)
        ply:SetArmor(100)

        if position then
            ply:SetPos(position)
            ply:SetLocalVelocity(vector_origin)
        end
    end)
end)

local chatCommands = {
    ["!ct"] = function(ply) TrySetTeam(ply, TEAM_CS_CT) end,
    ["/ct"] = function(ply) TrySetTeam(ply, TEAM_CS_CT) end,
    ["!t"] = function(ply) TrySetTeam(ply, TEAM_CS_T) end,
    ["/t"] = function(ply) TrySetTeam(ply, TEAM_CS_T) end,
    ["!team"] = function(ply) OpenMenu(ply) end,
    ["/team"] = function(ply) OpenMenu(ply) end
}

hook.Add("PlayerSay", "CSGO.TeamCommands", function(ply, text)
    local command = chatCommands[string.lower(string.Trim(text))]
    if not command then return end
    command(ply)
    return ""
end)
