local IsPlayTeam = CSGOConfig.IsPlayTeam
local SH = CSGOSpectatorShared
local MODE_ORDER = SH.ModeOrder
local MODE_INDEX = SH.ModeIndex
local MODE_COUNT = SH.ModeCount

CSSpectator = CSSpectator or {}
local S = CSSpectator

local DEATH_CAM_TIME = 2
local INPUT_COOLDOWN = 0.15
local inputCooldown = setmetatable({}, { __mode = "k" })

function S:IsSpectating(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if not IsPlayTeam(ply:Team()) then return true end
    return not ply:Alive()
end

local function StoreState(ply, mode, target)
    local valid = IsValid(target) and target or nil
    ply.CSSpecMode = mode
    ply.CSSpecTarget = valid
    ply:SetNWInt("CSSpecMode", mode)
    ply:SetNWEntity("CSSpecTarget", valid or NULL)
end

function S:ClearState(ply)
    if not IsValid(ply) then return end
    ply.CSSpecMode = nil
    ply.CSSpecTarget = nil
    ply.CSSpecHold = 0
    ply.CSSpecButtons = 0
    ply:SetNWInt("CSSpecMode", OBS_MODE_NONE)
    ply:SetNWEntity("CSSpecTarget", NULL)
end

function S:PickTarget(ply)
    return SH.GetTargets(ply)[1]
end

function S:SetRoaming(ply)
    if not IsValid(ply) then return end

    local previous = ply.CSSpecTarget
    ply:Spectate(OBS_MODE_ROAMING)
    ply:SpectateEntity(NULL)

    if IsValid(previous) then
        ply:SetPos(previous:EyePos())
        ply:SetEyeAngles(previous:EyeAngles())
    end

    StoreState(ply, OBS_MODE_ROAMING, nil)
end

function S:Apply(ply, mode, target)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    if not MODE_INDEX[mode] then mode = OBS_MODE_CHASE end

    if mode == OBS_MODE_ROAMING then
        self:SetRoaming(ply)
        return
    end

    if not SH.CanSpectateTarget(ply, target) then
        target = self:PickTarget(ply)
    end

    if not IsValid(target) then
        self:SetRoaming(ply)
        return
    end

    ply:Spectate(mode)
    ply:SpectateEntity(target)
    StoreState(ply, mode, target)
end

function S:Start(ply, mode)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    ply:Freeze(false)
    ply:StripWeapons()

    if ply:Alive() then ply:KillSilent() end

    ply.CSSpecHold = 0
    self:Apply(ply, mode or ply.CSSpecMode or OBS_MODE_CHASE, ply.CSSpecTarget)
end

function S:StartDeathCam(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local ragdoll = ply:GetRagdollEntity()
    local serial = (ply.CSSpecDeathSerial or 0) + 1
    ply.CSSpecDeathSerial = serial

    if IsValid(ragdoll) then
        ply.CSSpecHold = CurTime() + DEATH_CAM_TIME
        ply:Spectate(OBS_MODE_CHASE)
        ply:SpectateEntity(ragdoll)
        StoreState(ply, OBS_MODE_CHASE, nil)

        timer.Simple(DEATH_CAM_TIME, function()
            if not IsValid(ply) or ply:Alive() then return end
            if ply.CSSpecDeathSerial ~= serial then return end
            ply.CSSpecHold = 0
            S:Apply(ply, OBS_MODE_CHASE, nil)
        end)
        return
    end

    ply.CSSpecHold = 0
    self:Apply(ply, OBS_MODE_CHASE, nil)
end

function S:CycleTarget(ply, direction)
    if not IsValid(ply) then return end

    ply.CSSpecHold = 0

    local targets = SH.GetTargets(ply)
    local count = #targets

    if count == 0 then
        if ply.CSSpecMode ~= OBS_MODE_ROAMING then
            ply:ChatPrint("Нет доступных игроков для наблюдения.")
            self:SetRoaming(ply)
        end
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

    local mode = ply.CSSpecMode
    if mode ~= OBS_MODE_IN_EYE then mode = OBS_MODE_CHASE end

    self:Apply(ply, mode, targets[((index - 1 + direction) % count) + 1])
end

function S:CycleMode(ply)
    if not IsValid(ply) then return end

    ply.CSSpecHold = 0

    local index = MODE_INDEX[ply.CSSpecMode] or 1
    self:Apply(ply, MODE_ORDER[(index % MODE_COUNT) + 1], ply.CSSpecTarget)
end

hook.Add("StartCommand", "CSGO.SpectatorInput", function(ply, cmd)
    local buttons = cmd:GetButtons()

    if buttons == (ply.CSSpecButtons or 0) then return end

    if not S:IsSpectating(ply) then
        ply.CSSpecButtons = buttons
        return
    end

    local pressed = bit.band(buttons, bit.bnot(ply.CSSpecButtons or 0))
    ply.CSSpecButtons = buttons

    if pressed == 0 then return end

    local now = CurTime()
    if (inputCooldown[ply] or 0) > now then return end

    if bit.band(pressed, IN_ATTACK) ~= 0 then
        inputCooldown[ply] = now + INPUT_COOLDOWN
        S:CycleTarget(ply, 1)
    elseif bit.band(pressed, IN_ATTACK2) ~= 0 then
        inputCooldown[ply] = now + INPUT_COOLDOWN
        S:CycleTarget(ply, -1)
    elseif bit.band(pressed, IN_JUMP) ~= 0 then
        inputCooldown[ply] = now + INPUT_COOLDOWN
        S:CycleMode(ply)
    end
end)

timer.Create("CSGO.SpectatorWatchdog", 0.5, 0, function()
    local now = CurTime()

    for _, ply in ipairs(player.GetAll()) do
        local mode = ply.CSSpecMode

        if mode and mode ~= OBS_MODE_ROAMING and (ply.CSSpecHold or 0) <= now and S:IsSpectating(ply) then
            if not SH.CanSpectateTarget(ply, ply.CSSpecTarget) then
                local replacement = S:PickTarget(ply)

                if IsValid(replacement) then
                    S:Apply(ply, mode, replacement)
                else
                    S:SetRoaming(ply)
                end
            end
        end
    end
end)

hook.Add("PostPlayerDeath", "CSGO.SpectatorOnDeath", function(ply)
    timer.Simple(0, function()
        if IsValid(ply) and not ply:Alive() then
            S:StartDeathCam(ply)
        end
    end)
end)

hook.Add("PlayerSpawn", "CSGO.SpectatorClearState", function(ply)
    if not IsPlayTeam(ply:Team()) then return end

    timer.Simple(0, function()
        if IsValid(ply) and ply:Alive() and ply:GetObserverMode() == OBS_MODE_NONE then
            S:ClearState(ply)
        end
    end)
end)

hook.Add("PlayerDeathThink", "CSGO.SpectatorBlockRespawn", function()
    return false
end)

hook.Add("PlayerCanHearPlayersVoice", "CSGO.SpectatorVoice", function(listener, talker)
    if S:IsSpectating(talker) and not S:IsSpectating(listener) then
        return false
    end
end)

hook.Add("PlayerDisconnected", "CSGO.SpectatorCleanup", function(ply)
    inputCooldown[ply] = nil
end)

concommand.Remove("cs_spec_mode")
concommand.Add("cs_spec_mode", function(ply)
    if S:IsSpectating(ply) then S:CycleMode(ply) end
end)
