local TEAM_CS_CT = CSGOConfig.TeamCT
local TEAM_CS_T = CSGOConfig.TeamT
local ROUND_LIMIT = CSGOConfig.RoundLimit
local SIDE_SWITCH_ROUND = CSGOConfig.SideSwitchRound
local ROUND_TIME = CSGOConfig.RoundTime
local INTERMISSION_TIME = CSGOConfig.IntermissionTime
local READY_TIME = CSGOConfig.ReadyTime
local C4_CLASS = CSGOConfig.C4Class
local PLANTED_C4_CLASS = CSGOConfig.PlantedC4Class
local BOMB_SITE_RADIUS_SQR = CSGOConfig.BombSiteRadius * CSGOConfig.BombSiteRadius
local BOMB_SITES = CSGOConfig.BombSites
local IsPlayTeam = CSGOConfig.IsPlayTeam
local OtherTeam = CSGOConfig.OtherTeam

CSRounds = CSRounds or {}
local R = CSRounds

util.AddNetworkString("CSTeam_Open")
util.AddNetworkString("CSRounds.BombPlantedNotice")

local roundTimer = "CSRounds.RoundTimer"
local nextTimer = "CSRounds.NextRound"
local waitTimer = "CSRounds.WaitForTeams"
local eliminationTimer = "CSRounds.EliminationCheck"
local readyTimer = "CSRounds.GetReady"

local function ClearRoundTimers()
    timer.Remove(roundTimer)
    timer.Remove(nextTimer)
    timer.Remove(eliminationTimer)
    timer.Remove(readyTimer)
end

local isReload = R.Initialized == true

if not isReload then
    ClearRoundTimers()
    timer.Remove(waitTimer)

    R.Active = false
    R.Transition = false
    R.Round = 0
    R.EndTime = 0
    R.Scores = {
        [TEAM_CS_CT] = 0,
        [TEAM_CS_T] = 0
    }
    R.Participants = {}
    R.History = {}
    R.MatchWinner = 0
    R.BombPlanted = false
    R.BombEntity = nil
    R.BombSite = ""
    R.GetReady = false
    R.ReadyEndTime = 0
    R.MatchSerial = 1
    R.MatchFinished = false
    R.Initialized = true
end

local function PublishState()
    SetGlobalBool("CSRoundActive", R.Active)
    SetGlobalInt("CSRoundNumber", R.Round)
    SetGlobalInt("CSRoundLimit", ROUND_LIMIT)
    SetGlobalInt("CSRoundScoreCT", R.Scores[TEAM_CS_CT])
    SetGlobalInt("CSRoundScoreT", R.Scores[TEAM_CS_T])
    SetGlobalFloat("CSRoundEndTime", R.EndTime)
    SetGlobalInt("CSRoundsPlayed", #R.History)
    SetGlobalInt("CSMatchWinner", R.MatchWinner)
    SetGlobalString("CSRoundHistory", util.TableToJSON(R.History, false) or "[]")
    SetGlobalBool("CSBombPlanted", R.BombPlanted)
    SetGlobalString("CSBombSite", R.BombSite or "")
    SetGlobalBool("CSRoundGetReady", R.GetReady)
    SetGlobalFloat("CSRoundReadyEnd", R.ReadyEndTime)
end

local function Broadcast(text)
    for _, ply in ipairs(player.GetAll()) do
        ply:ChatPrint(text)
    end
end

local function HasBothTeams()
    return team.NumPlayers(TEAM_CS_CT) > 0 and team.NumPlayers(TEAM_CS_T) > 0
end

local function RemoveC4Entities()
    for _, className in ipairs({ C4_CLASS, PLANTED_C4_CLASS }) do
        for _, ent in ipairs(ents.FindByClass(className)) do
            SafeRemoveEntity(ent)
        end
    end
end

local function FindBombSite(position)
    for siteName, sitePosition in pairs(BOMB_SITES) do
        if position:DistToSqr(sitePosition) <= BOMB_SITE_RADIUS_SQR then
            return siteName
        end
    end
end

local function GiveC4ToRandomTerrorist()
    local terrorists = {}

    for ply in pairs(R.Participants) do
        if IsValid(ply) and ply:IsPlayer() and ply:Team() == TEAM_CS_T and ply:Alive() then
            terrorists[#terrorists + 1] = ply
        end
    end

    if #terrorists == 0 then return end

    local carrier = terrorists[math.random(1, #terrorists)]
    local weapon = carrier:Give(C4_CLASS)

    if IsValid(weapon) then
        carrier:ChatPrint("Вы получили C4.")
    else
        ErrorNoHalt("[CSRounds] Failed to give " .. C4_CLASS .. " to " .. carrier:Nick() .. "\n")
    end
end

local function AliveCount(teamID)
    local count = 0
    for ply in pairs(R.Participants) do
        if IsValid(ply) and ply:IsPlayer() and ply:Team() == teamID and ply:Alive() then
            count = count + 1
        end
    end
    return count
end

function R:IsRoundActive()
    return self.Active
end

function R:IsRoundLocked()
    return self.Active or self.Transition
end

function R:IsGetReady()
    return self.GetReady
end

function R:QueuePlayer(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    self.Participants[ply] = nil

    if CSSpectator then
        CSSpectator:Start(ply, OBS_MODE_CHASE)
    else
        ply:StripWeapons()
        if ply:Alive() then
            ply:KillSilent()
        end
        ply:Spectate(OBS_MODE_ROAMING)
    end

    ply:ChatPrint("Вы войдёте в игру в следующем раунде.")
end

local StartRound
local FinishRound

local function ResetToSelection(fromMatchEnd, matchSerial)
    if fromMatchEnd and (not R.MatchFinished or matchSerial ~= R.MatchSerial) then return end

    R.MatchSerial = R.MatchSerial + 1
    R.MatchFinished = false
    R.Active = false
    R.Transition = false
    R.Round = 0
    R.EndTime = 0
    R.Scores[TEAM_CS_CT] = 0
    R.Scores[TEAM_CS_T] = 0
    table.Empty(R.Participants)
    table.Empty(R.History)
    R.MatchWinner = 0
    R.BombPlanted = false
    R.BombEntity = nil
    R.BombSite = ""
    R.GetReady = false
    R.ReadyEndTime = 0
    ClearRoundTimers()
    RemoveC4Entities()

    if CSTeamSystem and CSTeamSystem.ResetMatchCooldowns then
        CSTeamSystem:ResetMatchCooldowns()
    end

    for _, ply in ipairs(player.GetAll()) do
        ply:Freeze(false)
        if CSTeamSystem and CSTeamSystem.ResetPlayer then
            CSTeamSystem:ResetPlayer(ply)
        else
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
                net.Start("CSTeam_Open")
                net.Send(ply)
            end)
        end
    end

    PublishState()
    Broadcast("Матч перезапущен. Выберите команду.")
end

local function FinishMatch(winner)
    if R.MatchFinished then return end

    R.MatchFinished = true
    R.Active = false
    R.Transition = true
    R.EndTime = 0
    R.MatchWinner = IsPlayTeam(winner) and winner or 0
    timer.Remove(roundTimer)
    timer.Remove(eliminationTimer)
    PublishState()

    if IsPlayTeam(winner) then
        Broadcast("Матч окончен. Победила команда " .. team.GetName(winner) .. ".")
    else
        Broadcast("Матч окончен вничью.")
    end

    local matchSerial = R.MatchSerial
    timer.Create(nextTimer, INTERMISSION_TIME, 1, function()
        ResetToSelection(true, matchSerial)
    end)
end

local function SwitchSides()
    local swaps = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsPlayTeam(ply:Team()) then
            swaps[ply] = OtherTeam(ply:Team())
        end
    end

    for ply, teamID in pairs(swaps) do
        if IsValid(ply) then
            ply:SetTeam(teamID)
        end
    end

    R.Scores[TEAM_CS_CT], R.Scores[TEAM_CS_T] = R.Scores[TEAM_CS_T], R.Scores[TEAM_CS_CT]
    PublishState()
    Broadcast("Команды поменялись сторонами.")
end

FinishRound = function(winner)
    if not R.Active then return end

    R.Active = false
    R.Transition = true
    R.EndTime = 0
    R.BombPlanted = false
    R.BombEntity = nil
    R.BombSite = ""
    R.GetReady = false
    R.ReadyEndTime = 0
    timer.Remove(roundTimer)
    timer.Remove(eliminationTimer)
    timer.Remove(readyTimer)
    timer.Simple(0, RemoveC4Entities)

    if IsPlayTeam(winner) then
        R.Scores[winner] = R.Scores[winner] + 1
        R.History[#R.History + 1] = winner
        Broadcast("Раунд выиграла команда " .. team.GetName(winner) .. ".")
    else
        R.History[#R.History + 1] = 0
        Broadcast("Раунд завершился вничью.")
    end

    PublishState()

    if R.Round >= ROUND_LIMIT then
        local winnerTeam
        if R.Scores[TEAM_CS_CT] > R.Scores[TEAM_CS_T] then
            winnerTeam = TEAM_CS_CT
        elseif R.Scores[TEAM_CS_T] > R.Scores[TEAM_CS_CT] then
            winnerTeam = TEAM_CS_T
        end
        FinishMatch(winnerTeam)
        return
    end

    if R.Round == SIDE_SWITCH_ROUND then
        SwitchSides()
    end

    timer.Create(nextTimer, INTERMISSION_TIME, 1, function()
        R.Transition = false
        if HasBothTeams() then
            StartRound()
        else
            PublishState()
            Broadcast("Ожидание игроков в обеих командах.")
        end
    end)
end

local function CheckElimination()
    if not R.Active then return end

    local ctAlive = AliveCount(TEAM_CS_CT)
    local tAlive = AliveCount(TEAM_CS_T)

    if R.BombPlanted then
        if ctAlive == 0 then
            FinishRound(TEAM_CS_T)
        end
        return
    end

    if ctAlive == 0 and tAlive == 0 then
        FinishRound(nil)
    elseif ctAlive == 0 then
        FinishRound(TEAM_CS_T)
    elseif tAlive == 0 then
        FinishRound(TEAM_CS_CT)
    end
end

hook.Add("SWCSInBombZone", "CSRounds.BombZone", function(ply)
    if not R.Active or not IsValid(ply) or not ply:IsPlayer() then return false end
    if ply:Team() ~= TEAM_CS_T or not R.Participants[ply] or not ply:Alive() then return false end
    return FindBombSite(ply:GetPos()) ~= nil
end)

hook.Add("SWCSPlantedC4", "CSRounds.BombPlanted", function(_, ply, bomb)
    if not R.Active or R.BombPlanted then return end
    if not IsValid(ply) or not IsValid(bomb) or ply:Team() ~= TEAM_CS_T or not R.Participants[ply] then return end

    local siteName = FindBombSite(bomb:GetPos()) or FindBombSite(ply:GetPos())
    if not siteName then
        SafeRemoveEntity(bomb)
        return
    end

    R.BombPlanted = true
    R.BombEntity = bomb
    R.BombSite = siteName
    R.EndTime = 0
    timer.Remove(roundTimer)
    PublishState()

    net.Start("CSRounds.BombPlantedNotice")
    net.Broadcast()
end)

hook.Add("SWCSCanDisarmC4", "CSRounds.RestrictDefuse", function(ply, bomb)
    if not R.Active or not R.BombPlanted then return false end
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end
    if ply:Team() ~= TEAM_CS_CT or not R.Participants[ply] then return false end
    if IsValid(R.BombEntity) and bomb ~= R.BombEntity then return false end
    return true
end)

hook.Add("SWCSC4Detonated", "CSRounds.BombDetonated", function(bomb)
    if not R.Active or not R.BombPlanted then return end
    if IsValid(R.BombEntity) and bomb ~= R.BombEntity then return end
    FinishRound(TEAM_CS_T)
end)

hook.Add("SWCSC4Defused", "CSRounds.BombDefused", function(_, bomb)
    if not R.Active or not R.BombPlanted then return end
    if IsValid(R.BombEntity) and bomb ~= R.BombEntity then return end
    FinishRound(TEAM_CS_CT)
end)

hook.Add("EntityRemoved", "CSRounds.BombRemoved", function(entity)
    if not R.Active or not R.BombPlanted or entity ~= R.BombEntity then return end

    timer.Simple(0, function()
        if R.Active and R.BombPlanted and not IsValid(R.BombEntity) then
            FinishRound(TEAM_CS_CT)
        end
    end)
end)

StartRound = function()
    if R.MatchFinished or R.Round >= ROUND_LIMIT or R.Active or R.Transition or not HasBothTeams() then return end

    timer.Remove(nextTimer)
    timer.Remove(readyTimer)
    RemoveC4Entities()
    R.Active = false
    R.Transition = true
    R.GetReady = true
    R.ReadyEndTime = CurTime() + READY_TIME
    R.EndTime = 0
    R.BombPlanted = false
    R.BombEntity = nil
    R.BombSite = ""
    R.Round = R.Round + 1
    table.Empty(R.Participants)

    for _, ply in ipairs(player.GetAll()) do
        if IsPlayTeam(ply:Team()) then
            ply:UnSpectate()
            ply:Spawn()
            if IsValid(ply) and ply:Alive() and IsPlayTeam(ply:Team()) then
                R.Participants[ply] = true
                ply:SetArmor(100)
                ply:Freeze(true)
                timer.Simple(0.1, function()
                    if not IsValid(ply) or not R.Participants[ply] or not ply:Alive() then return end
                    ply:SetArmor(100)
                end)
            end
        end
    end

    GiveC4ToRandomTerrorist()
    PublishState()

    timer.Create(readyTimer, READY_TIME, 1, function()
        R.GetReady = false
        R.ReadyEndTime = 0
        R.Transition = false
        R.Active = true
        R.EndTime = CurTime() + ROUND_TIME

        for ply in pairs(R.Participants) do
            if IsValid(ply) then
                ply:Freeze(false)
            end
        end

        PublishState()
        Broadcast("Раунд " .. R.Round .. " из " .. ROUND_LIMIT .. " начался.")

        timer.Create(roundTimer, ROUND_TIME, 1, function()
            if R.Active and not R.BombPlanted then
                FinishRound(TEAM_CS_CT)
            end
        end)

        timer.Create(eliminationTimer, 0.1, 1, CheckElimination)
    end)
end

local function ScheduleEliminationCheck()
    if not R.Active or timer.Exists(eliminationTimer) then return end
    timer.Create(eliminationTimer, 0.1, 1, CheckElimination)
end

hook.Add("PlayerDeath", "CSRounds.PlayerDeath", function(ply)
    if not CSSpectator then
        timer.Simple(0, function()
            if IsValid(ply) and ply:IsPlayer() and not ply:Alive() and IsPlayTeam(ply:Team()) then
                ply:Spectate(OBS_MODE_ROAMING)
            end
        end)
    end

    ScheduleEliminationCheck()
end)

hook.Add("PlayerDisconnected", "CSRounds.PlayerDisconnected", function(ply)
    R.Participants[ply] = nil
    ScheduleEliminationCheck()
end)

hook.Add("OnPlayerChangedTeam", "CSRounds.TeamChanged", ScheduleEliminationCheck)

hook.Add("PlayerSpawn", "CSRounds.BlockMidRoundSpawn", function(ply)
    if (R.Active or (R.Transition and not R.GetReady)) and IsPlayTeam(ply:Team()) then
        timer.Simple(0, function()
            if IsValid(ply) and (R.Active or (R.Transition and not R.GetReady)) and IsPlayTeam(ply:Team()) then
                R:QueuePlayer(ply)
            end
        end)
    end
end)

if not timer.Exists(waitTimer) then
    timer.Create(waitTimer, 1, 0, function()
        if not R.Active and not R.Transition and not R.MatchFinished and R.Round < ROUND_LIMIT and HasBothTeams() then
            StartRound()
        end
    end)
end

concommand.Remove("cs_match_restart")
concommand.Add("cs_match_restart", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    ResetToSelection(false)
end)

PublishState()
