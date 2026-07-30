local SH = CSGOSpectatorShared
local IsPlayTeam = CSGOConfig.IsPlayTeam

CSSpectator = CSSpectator or {}

local S = CSSpectator

local INPUT_COOLDOWN = 0.12
local NET_FLOOD_WINDOW = 0.05
local NET_SUPPRESS_TIME = 10

local ACTION_NEXT = 1
local ACTION_PREVIOUS = 2
local ACTION_MODE = 3

util.AddNetworkString("CSSpec_Input")

local inputCooldown = setmetatable({}, { __mode = "k" })
local netCooldown = setmetatable({}, { __mode = "k" })

local function StoreState(ply, mode, target)
    ply:SetNWInt("CSSpecMode", mode)
    ply:SetNWEntity("CSSpecTarget", IsValid(target) and target or NULL)
end

function S:IsSpectating(ply)
    return IsValid(ply) and ply:IsPlayer() and ply:GetObserverMode() ~= OBS_MODE_NONE
end

function S:ClearState(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    ply.CSSpecMode = nil
    ply.CSSpecTarget = nil
    ply.CSSpecHold = nil
    ply.CSSpecButtons = nil
    ply.CSSpecDeathSerial = nil
    inputCooldown[ply] = nil

    ply:SetNWInt("CSSpecMode", OBS_MODE_NONE)
    ply:SetNWEntity("CSSpecTarget", NULL)
end

local function ApplyObserver(ply, mode, target)
    if mode == OBS_MODE_ROAMING or not IsValid(target) then
        ply:SetObserverMode(OBS_MODE_ROAMING)
        ply:SpectateEntity(NULL)
        ply.CSSpecMode = OBS_MODE_ROAMING
        ply.CSSpecTarget = nil
        StoreState(ply, OBS_MODE_ROAMING, nil)
        return
    end

    ply:SetObserverMode(mode)
    ply:SpectateEntity(target)
    ply.CSSpecMode = mode
    ply.CSSpecTarget = target
    StoreState(ply, mode, target)
end

function S:Start(ply, mode)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    if ply:Alive() then
        local deaths = ply:Deaths()
        ply:KillSilent()
        ply:SetDeaths(deaths)
    end

    ply:StripWeapons()
    ply:Spectate(OBS_MODE_ROAMING)
    CSGOResetMovementState(ply)

    local target = SH.GetFirstTarget(ply)
    local wantedMode = mode or OBS_MODE_CHASE

    if IsValid(target) and wantedMode ~= OBS_MODE_ROAMING then
        ApplyObserver(ply, wantedMode, target)
    else
        ApplyObserver(ply, OBS_MODE_ROAMING, nil)
    end
end

function S:StartDeathCam(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local serial = (ply.CSSpecDeathSerial or 0) + 1
    ply.CSSpecDeathSerial = serial

    local ragdoll = ply:GetRagdollEntity()

    ply:Spectate(OBS_MODE_CHASE)

    if IsValid(ragdoll) then
        ply:SpectateEntity(ragdoll)
    end

    ply.CSSpecMode = OBS_MODE_CHASE
    ply.CSSpecTarget = nil
    StoreState(ply, OBS_MODE_CHASE, nil)

    timer.Simple(2, function()
        if not IsValid(ply) or ply.CSSpecDeathSerial ~= serial then return end
        if ply:Alive() or ply:GetObserverMode() == OBS_MODE_NONE then return end
        S:PickTarget(ply)
    end)
end

function S:PickTarget(ply)
    if not self:IsSpectating(ply) then return end

    local mode = ply.CSSpecMode or OBS_MODE_CHASE

    if mode == OBS_MODE_ROAMING then
        ApplyObserver(ply, OBS_MODE_ROAMING, nil)
        return
    end

    ApplyObserver(ply, mode, SH.GetFirstTarget(ply))
end

function S:CycleTarget(ply, direction)
    if not self:IsSpectating(ply) then return end

    local mode = ply.CSSpecMode or OBS_MODE_CHASE
    if mode == OBS_MODE_ROAMING then return end

    local targets = SH.GetTargets(ply)
    local count = #targets

    if count == 0 then
        ApplyObserver(ply, OBS_MODE_ROAMING, nil)
        return
    end

    local current = ply.CSSpecTarget
    local index = 0

    for i = 1, count do
        if targets[i] == current then
            index = i
            break
        end
    end

    local nextIndex

    if index == 0 then
        nextIndex = 1
    else
        nextIndex = ((index - 1 + direction) % count) + 1
    end

    ApplyObserver(ply, mode, targets[nextIndex])
end

function S:CycleMode(ply)
    if not self:IsSpectating(ply) then return end

    local currentIndex = SH.ModeIndex[ply.CSSpecMode or OBS_MODE_CHASE] or 1
    local nextMode = SH.ModeOrder[(currentIndex % SH.ModeCount) + 1]

    if nextMode == OBS_MODE_ROAMING then
        ApplyObserver(ply, OBS_MODE_ROAMING, nil)
        return
    end

    local target = ply.CSSpecTarget

    if not SH.CanSpectateTarget(ply, target) then
        target = SH.GetFirstTarget(ply)
    end

    ApplyObserver(ply, nextMode, target)
end

local function HandleAction(ply, action)
    if not S:IsSpectating(ply) then return end

    local now = CurTime()
    if (inputCooldown[ply] or 0) > now then return end
    inputCooldown[ply] = now + INPUT_COOLDOWN

    if action == ACTION_NEXT then
        S:CycleTarget(ply, 1)
    elseif action == ACTION_PREVIOUS then
        S:CycleTarget(ply, -1)
    elseif action == ACTION_MODE then
        S:CycleMode(ply)
    end
end

net.Receive("CSSpec_Input", function(length, ply)
    if not IsValid(ply) or not ply:IsPlayer() or length ~= 2 then return end

    local now = CurTime()
    if (netCooldown[ply] or 0) > now then return end
    netCooldown[ply] = now + NET_FLOOD_WINDOW

    ply.CSSpecNetInput = now
    HandleAction(ply, net.ReadUInt(2))
end)

concommand.Add("cs_spec_mode", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    ply.CSSpecNetInput = CurTime()
    HandleAction(ply, ACTION_MODE)
end)

hook.Add("StartCommand", "CSGO.SpectatorButtons", function(ply, cmd)
    if not S:IsSpectating(ply) then
        if ply.CSSpecButtons then ply.CSSpecButtons = nil end
        return
    end

    local buttons = cmd:GetButtons()
    local previous = ply.CSSpecButtons or 0
    ply.CSSpecButtons = buttons

    if (ply.CSSpecNetInput or 0) + NET_SUPPRESS_TIME > CurTime() then return end

    if bit.band(buttons, IN_ATTACK) ~= 0 and bit.band(previous, IN_ATTACK) == 0 then
        HandleAction(ply, ACTION_NEXT)
    elseif bit.band(buttons, IN_ATTACK2) ~= 0 and bit.band(previous, IN_ATTACK2) == 0 then
        HandleAction(ply, ACTION_PREVIOUS)
    elseif bit.band(buttons, IN_JUMP) ~= 0 and bit.band(previous, IN_JUMP) == 0 then
        HandleAction(ply, ACTION_MODE)
    end
end)

hook.Add("PlayerDeath", "CSGO.SpectatorDeathCam", function(ply)
    timer.Simple(0, function()
        if not IsValid(ply) or ply:Alive() then return end
        S:StartDeathCam(ply)
    end)
end)

hook.Add("PlayerSpawn", "CSGO.SpectatorClearState", function(ply)
    timer.Simple(0, function()
        if not IsValid(ply) or not ply:Alive() then return end
        if not IsPlayTeam(ply:Team()) then return end
        S:ClearState(ply)
    end)
end)

hook.Add("PlayerDisconnected", "CSGO.SpectatorCleanup", function(ply)
    inputCooldown[ply] = nil
    netCooldown[ply] = nil
end)

timer.Create("CSGO.SpectatorWatchdog", 0.5, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if S:IsSpectating(ply) and (ply.CSSpecMode or OBS_MODE_CHASE) ~= OBS_MODE_ROAMING then
            if not SH.CanSpectateTarget(ply, ply.CSSpecTarget) then
                S:PickTarget(ply)
            end
        end
    end
end)
