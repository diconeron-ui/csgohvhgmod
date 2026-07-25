local TEAM_CS_CT = CSGOConfig.TeamCT
local TEAM_CS_T = CSGOConfig.TeamT
local IsPlayTeam = CSGOConfig.IsPlayTeam
local GetOtherTeam = CSGOConfig.OtherTeam

local ROUND_LIMIT = CSGOConfig.RoundLimit
local SIDE_SWITCH = CSGOConfig.SideSwitchRound
local ROUND_TIME = CSGOConfig.RoundTime
local INTERMISSION = CSGOConfig.IntermissionTime
local READY_TIME = CSGOConfig.ReadyTime
local ABORT_DELAY = CSGOConfig.AbortDelay
local BOMB_RADIUS_SQR = CSGOConfig.BombSiteRadius * CSGOConfig.BombSiteRadius
local C4_CLASS = CSGOConfig.C4Class
local PLANTED_C4_CLASS = CSGOConfig.PlantedC4Class

CSRounds = CSRounds or {}

local R = CSRounds

util.AddNetworkString("CSRounds.BombPlantedNotice")

R.Round = R.Round or 0
R.RoundsPlayed = R.RoundsPlayed or 0
R.Scores = R.Scores or { [TEAM_CS_CT] = 0, [TEAM_CS_T] = 0 }
R.History = R.History or {}
R.Active = false
R.GetReady = false
R.MatchFinished = R.MatchFinished or false
R.MatchSerial = R.MatchSerial or 0
R.Participants = R.Participants or {}
R.Queue = R.Queue or {}
R.BombPlanted = false
R.BombSite = ""

local function ClearTimers()
    timer.Remove("CSRounds.RoundTimer")
    timer.Remove("CSRounds.NextRound")
    timer.Remove("CSRounds.WaitForTeams")
    timer.Remove("CSRounds.EliminationCheck")
    timer.Remove("CSRounds.GetReady")
end

local function PublishHistory()
    SetGlobalInt("CSRoundsPlayed", R.RoundsPlayed)
    SetGlobalString("CSRoundHistory", util.TableToJSON(R.History))
end

local function Publish()
    SetGlobalBool("CSRoundActive", R.Active)
    SetGlobalBool("CSRoundGetReady", R.GetReady)
    SetGlobalInt("CSRoundNumber", R.Round)
    SetGlobalInt("CSRoundLimit", ROUND_LIMIT)
    SetGlobalInt("CSRoundScoreCT", R.Scores[TEAM_CS_CT])
    SetGlobalInt("CSRoundScoreT", R.Scores[TEAM_CS_T])
    SetGlobalInt("CSMatchWinner", R.MatchWinner or 0)
    SetGlobalBool("CSBombPlanted", R.BombPlanted)
    SetGlobalString("CSBombSite", R.BombSite)
end

local function PublishEndTime(endTime)
    SetGlobalFloat("CSRoundEndTime", endTime or 0)
end

local function PublishReadyEnd(endTime)
    SetGlobalFloat("CSRoundReadyEnd", endTime or 0)
end

function R:IsRoundLocked()
    return self.Active or self.GetReady or timer.Exists("CSRounds.NextRound")
end

function R:IsGetReady()
    return self.GetReady
end

function R:IsParticipant(ply)
    return IsValid(ply) and self.Participants[ply] == true
end

function R:CountTeam(teamID)
    local count = 0

    for ply in pairs(self.Participants) do
        if IsValid(ply) and ply:Team() == teamID then
            count = count + 1
        end
    end

    return count
end

function R:CountAlive(teamID)
    local count = 0

    for ply in pairs(self.Participants) do
        if IsValid(ply) and ply:Alive() and ply:Team() == teamID
            and ply:GetObserverMode() == OBS_MODE_NONE then
            count = count + 1
        end
    end

    return count
end

function R:RemoveParticipant(ply)
    if self.Participants[ply] then
        self.Participants[ply] = nil
    end

    self.Queue[ply] = nil
end

function R:QueuePlayer(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not IsPlayTeam(ply:Team()) then return end
    if self.Participants[ply] then return end

    self.Queue[ply] = true
    CSSpectator:Start(ply, OBS_MODE_CHASE)
    ply:ChatPrint("Вы вступите в игру со следующего раунда.")
end

local FinishMatch
local SwitchSides
local AbortRound
local WaitForTeams
local ResetToSelection
local StartGetReady

local function CleanupBomb()
    for _, entity in ipairs(ents.FindByClass(PLANTED_C4_CLASS)) do
        SafeRemoveEntity(entity)
    end

    for _, entity in ipairs(ents.FindByClass(C4_CLASS)) do
        local owner = entity.GetOwner and entity:GetOwner()

        if not IsValid(owner) or not owner:IsPlayer() then
            SafeRemoveEntity(entity)
        end
    end
end

local function CleanupWorld()
    CleanupBomb()

    for _, entity in ipairs(ents.FindByClass("prop_ragdoll")) do
        SafeRemoveEntity(entity)
    end

    for _, entity in ipairs(ents.FindByClass("class C_BaseFlex")) do
        SafeRemoveEntity(entity)
    end
end

function R:DropC4(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local weapon = ply:GetWeapon(C4_CLASS)

    if IsValid(weapon) then
        ply:StripWeapon(C4_CLASS)
    end
end

local function GiveBomb()
    local candidates, count = {}, 0

    for ply in pairs(R.Participants) do
        if IsValid(ply) and ply:Alive() and ply:Team() == TEAM_CS_T then
            count = count + 1
            candidates[count] = ply
        end
    end

    if count == 0 then return end

    local carrier = candidates[math.random(count)]

    carrier.CSGOGivingLoadout = true
    carrier:Give(C4_CLASS)
    carrier.CSGOGivingLoadout = nil
end

local function BuildParticipants()
    local participants = {}
    local counts = { [TEAM_CS_CT] = 0, [TEAM_CS_T] = 0 }

    for _, ply in ipairs(player.GetAll()) do
        local teamID = ply:Team()

        if IsPlayTeam(teamID) then
            participants[ply] = true
            counts[teamID] = counts[teamID] + 1
        end
    end

    return participants, counts
end

local function RespawnParticipants()
    for ply in pairs(R.Participants) do
        if IsValid(ply) then
            CSSpectator:ClearState(ply)
            ply:UnSpectate()
            ply:Spawn()
        end
    end
end

function R:OnTeamChanged(ply)
    if not IsValid(ply) then return end

    if not IsPlayTeam(ply:Team()) then
        self:RemoveParticipant(ply)
    end

    if self.Active then
        self:RequestEliminationCheck()
    end
end

hook.Add("OnPlayerChangedTeam", "CSRounds.TeamChanged", function(ply)
    R:OnTeamChanged(ply)
end)

hook.Add("PlayerDisconnected", "CSRounds.Cleanup", function(ply)
    R:RemoveParticipant(ply)

    if R.Active then
        R:RequestEliminationCheck()
    end
end)

local function StartRound()
    R.GetReady = false
    R.Active = true
    R.BombPlanted = false
    R.BombSite = ""

    PublishReadyEnd(0)
    PublishEndTime(CurTime() + ROUND_TIME)
    Publish()

    timer.Create("CSRounds.RoundTimer", ROUND_TIME, 1, function()
        if not R.Active then return end
        R:EndRound(TEAM_CS_CT, "time")
    end)
end

StartGetReady = function()
    local participants, counts = BuildParticipants()

    if counts[TEAM_CS_CT] == 0 or counts[TEAM_CS_T] == 0 then
        WaitForTeams()
        return
    end

    ClearTimers()
    CleanupWorld()

    R.Participants = participants
    R.Queue = {}
    R.Round = R.Round + 1
    R.GetReady = true
    R.Active = false
    R.BombPlanted = false
    R.BombSite = ""

    RespawnParticipants()
    GiveBomb()

    local readyEnd = CurTime() + READY_TIME

    PublishReadyEnd(readyEnd)
    PublishEndTime(readyEnd + ROUND_TIME)
    Publish()

    timer.Create("CSRounds.GetReady", READY_TIME, 1, StartRound)
end

WaitForTeams = function()
    ClearTimers()

    R.Active = false
    R.GetReady = false
    PublishReadyEnd(0)
    PublishEndTime(0)
    Publish()

    timer.Create("CSRounds.WaitForTeams", 1, 0, function()
        if R.MatchFinished then
            timer.Remove("CSRounds.WaitForTeams")
            return
        end

        local _, counts = BuildParticipants()

        if counts[TEAM_CS_CT] > 0 and counts[TEAM_CS_T] > 0 then
            timer.Remove("CSRounds.WaitForTeams")
            StartGetReady()
        end
    end)
end

AbortRound = function()
    ClearTimers()

    R.Active = false
    R.GetReady = false
    R.BombPlanted = false
    R.BombSite = ""

    PublishReadyEnd(0)
    PublishEndTime(0)
    Publish()

    if R.Round > 0 then
        R.Round = R.Round - 1
    end

    CleanupWorld()

    for _, ply in ipairs(player.GetAll()) do
        ply:ChatPrint("Раунд отменён: недостаточно игроков.")
    end

    timer.Create("CSRounds.NextRound", ABORT_DELAY, 1, WaitForTeams)
end

SwitchSides = function()
    local swapped = {}

    for _, ply in ipairs(player.GetAll()) do
        local teamID = ply:Team()

        if IsPlayTeam(teamID) then
            swapped[ply] = GetOtherTeam(teamID)
        end
    end

    for ply, teamID in pairs(swapped) do
        if IsValid(ply) then
            ply:SetTeam(teamID)
        end
    end

    local ctScore = R.Scores[TEAM_CS_CT]
    R.Scores[TEAM_CS_CT] = R.Scores[TEAM_CS_T]
    R.Scores[TEAM_CS_T] = ctScore

    for i = 1, #R.History do
        local entry = R.History[i]

        if entry.winner == TEAM_CS_CT then
            entry.winner = TEAM_CS_T
        elseif entry.winner == TEAM_CS_T then
            entry.winner = TEAM_CS_CT
        end
    end

    PublishHistory()
    Publish()
end

ResetToSelection = function(fromMatchEnd, matchSerial)
    if matchSerial and matchSerial ~= R.MatchSerial then return end

    ClearTimers()
    CleanupWorld()

    R.Round = 0
    R.RoundsPlayed = 0
    R.Scores[TEAM_CS_CT] = 0
    R.Scores[TEAM_CS_T] = 0
    R.History = {}
    R.Participants = {}
    R.Queue = {}
    R.Active = false
    R.GetReady = false
    R.BombPlanted = false
    R.BombSite = ""
    R.MatchFinished = false
    R.MatchWinner = nil
    R.MatchSerial = R.MatchSerial + 1

    PublishReadyEnd(0)
    PublishEndTime(0)
    PublishHistory()
    Publish()

    CSTeamSystem:ResetMatchCooldowns()

    for _, ply in ipairs(player.GetAll()) do
        CSTeamSystem:ResetPlayer(ply)

        if fromMatchEnd then
            ply:SetFrags(0)
            ply:SetDeaths(0)
        end
    end

    WaitForTeams()
end

function R:ResetMatch(fromMatchEnd)
    ResetToSelection(fromMatchEnd)
end

FinishMatch = function()
    ClearTimers()

    R.Active = false
    R.GetReady = false
    R.MatchFinished = true

    local ctScore = R.Scores[TEAM_CS_CT]
    local tScore = R.Scores[TEAM_CS_T]

    if ctScore > tScore then
        R.MatchWinner = TEAM_CS_CT
    elseif tScore > ctScore then
        R.MatchWinner = TEAM_CS_T
    else
        R.MatchWinner = 0
    end

    PublishReadyEnd(0)
    PublishEndTime(0)
    Publish()

    local serial = R.MatchSerial

    timer.Create("CSRounds.NextRound", 10, 1, function()
        ResetToSelection(true, serial)
    end)
end

function R:EndRound(winner, reason)
    if not self.Active then return end

    ClearTimers()

    self.Active = false
    self.GetReady = false

    if IsPlayTeam(winner) then
        self.Scores[winner] = self.Scores[winner] + 1
    end

    self.RoundsPlayed = self.RoundsPlayed + 1
    self.History[#self.History + 1] = {
        round = self.Round,
        winner = IsPlayTeam(winner) and winner or 0,
        reason = reason or ""
    }

    PublishEndTime(0)
    PublishReadyEnd(0)
    PublishHistory()
    Publish()

    for ply in pairs(self.Participants) do
        if IsValid(ply) then
            self:DropC4(ply)
        end
    end

    if self.Round >= ROUND_LIMIT then
        timer.Create("CSRounds.NextRound", INTERMISSION, 1, FinishMatch)
        return
    end

    timer.Create("CSRounds.NextRound", INTERMISSION, 1, function()
        if R.Round == SIDE_SWITCH then
            SwitchSides()
        end

        StartGetReady()
    end)
end

function R:CheckElimination()
    if not self.Active then return end

    local ctAlive = self:CountAlive(TEAM_CS_CT)
    local tAlive = self:CountAlive(TEAM_CS_T)

    if self:CountTeam(TEAM_CS_CT) == 0 or self:CountTeam(TEAM_CS_T) == 0 then
        AbortRound()
        return
    end

    if tAlive == 0 and not self.BombPlanted then
        self:EndRound(TEAM_CS_CT, "elimination")
        return
    end

    if ctAlive == 0 then
        self:EndRound(TEAM_CS_T, "elimination")
    end
end

function R:RequestEliminationCheck()
    if not self.Active then return end
    if timer.Exists("CSRounds.EliminationCheck") then return end

    timer.Create("CSRounds.EliminationCheck", 0.1, 1, function()
        R:CheckElimination()
    end)
end

hook.Add("PostPlayerDeath", "CSRounds.Elimination", function()
    R:RequestEliminationCheck()
end)

hook.Add("PlayerDeath", "CSRounds.DeathHandling", function(victim, inflictor, attacker)
    if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
        if IsPlayTeam(attacker:Team()) and attacker:Team() ~= victim:Team() then
            attacker:AddFrags(1)
        end
    end

    R:RequestEliminationCheck()
end)

function GM:PlayerDeathThink(ply)
    if R:IsRoundLocked() then return false end
    if not IsPlayTeam(ply:Team()) then return false end
    return false
end

local function NearestSite(position)
    local bestName, bestDistance

    for name, sitePosition in pairs(CSGOConfig.BombSites) do
        local distance = position:DistToSqr(sitePosition)

        if bestDistance == nil or distance < bestDistance then
            bestName = name
            bestDistance = distance
        end
    end

    if bestDistance and bestDistance <= BOMB_RADIUS_SQR then
        return bestName
    end
end

hook.Add("SWCSInBombZone", "CSRounds.BombZone", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if not R.Active or ply:Team() ~= TEAM_CS_T then return false end
    return NearestSite(ply:GetPos()) ~= nil
end)

hook.Add("SWCSPlantedC4", "CSRounds.BombPlanted", function(ply, bomb)
    if not R.Active then return end

    R.BombPlanted = true
    R.BombSite = NearestSite(IsValid(bomb) and bomb:GetPos() or ply:GetPos()) or ""

    timer.Remove("CSRounds.RoundTimer")
    PublishEndTime(0)
    Publish()

    net.Start("CSRounds.BombPlantedNotice")
        net.WriteString(R.BombSite)
    net.Broadcast()
end)

hook.Add("SWCSCanDisarmC4", "CSRounds.CanDefuse", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if not R.Active or not R.BombPlanted then return false end
    return ply:Team() == TEAM_CS_CT and ply:Alive()
end)

hook.Add("SWCSC4Detonated", "CSRounds.BombDetonated", function()
    if not R.Active then return end
    R.BombPlanted = false
    R:EndRound(TEAM_CS_T, "bomb")
end)

hook.Add("SWCSC4Defused", "CSRounds.BombDefused", function()
    if not R.Active then return end
    R.BombPlanted = false
    R:EndRound(TEAM_CS_CT, "defuse")
end)

local restartCooldown = 0

concommand.Add("cs_match_restart", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end

    local now = CurTime()
    if restartCooldown > now then return end
    restartCooldown = now + 5

    ResetToSelection(true)

    for _, target in ipairs(player.GetAll()) do
        target:ChatPrint("Матч перезапущен.")
    end
end)

timer.Create("CSRounds.Integrity", 2, 0, function()
    if not R.Active then return end

    for ply in pairs(R.Participants) do
        if not IsValid(ply) then
            R.Participants[ply] = nil
        end
    end

    R:CheckElimination()
end)

hook.Add("InitPostEntity", "CSRounds.Boot", function()
    PublishHistory()
    Publish()
    WaitForTeams()
end)

PublishHistory()
Publish()
WaitForTeams()
