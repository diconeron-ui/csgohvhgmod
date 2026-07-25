local PLAYER = {}

PLAYER.DisplayName = "CS:GO Player"
PLAYER.WalkSpeed = CSGOConfig.MoveSpeed
PLAYER.RunSpeed = CSGOConfig.MoveSpeed
PLAYER.CrouchedWalkSpeed = 1
PLAYER.DuckSpeed = CSGOConfig.DuckSpeed
PLAYER.UnDuckSpeed = CSGOConfig.UnDuckSpeed
PLAYER.JumpPower = CSGOConfig.JumpPower
PLAYER.MaxHealth = 100
PLAYER.StartHealth = 100
PLAYER.StartArmor = CSGOConfig.StartArmor
PLAYER.DropWeaponOnDie = false
PLAYER.TeammateNoCollide = false
PLAYER.AvoidPlayers = false
PLAYER.UseVMHands = true

local MOVE_SPEED = CSGOConfig.MoveSpeed
local WALK_MULT = CSGOConfig.WalkSpeedMultiplier
local DUCK_MULT = CSGOConfig.CrouchedSpeedMultiplier
local LAND_PENALTY_MULT = CSGOConfig.LandPenaltyMultiplier
local LAND_PENALTY_DURATION = CSGOConfig.LandPenaltyDuration
local LAND_PENALTY_MIN_SPEED_SQR = CSGOConfig.LandPenaltyMinSpeed * CSGOConfig.LandPenaltyMinSpeed
local AIR_MAX_SPEED = CSGOConfig.AirMaxSpeed
local AIR_GAIN = CSGOConfig.AirSpeedGainMultiplier
local RECOVERY = CSGOConfig.DamageSlowRecovery
local SLOW_PER_POINT = CSGOConfig.DamageSlowPercentPerPoint
local SLOW_MINIMUM = CSGOConfig.DamageSlowMinimum
local IsPlayTeam = CSGOConfig.IsPlayTeam

local standView = Vector(0, 0, CSGOConfig.EyeHeight)
local duckView = Vector(0, 0, CSGOConfig.EyeHeightDucked)

local function IsPlaying(ply)
    return IsValid(ply) and ply:IsPlayer() and ply:Alive()
        and ply:GetObserverMode() == OBS_MODE_NONE and IsPlayTeam(ply:Team())
end

local function VelocityModifier(ply)
    local hitTime = ply:GetNW2Float("CSGOVelocityHitTime", 0)
    if hitTime <= 0 then return 1 end

    local start = math.Clamp(ply:GetNW2Float("CSGOVelocityModifier", 1), 0, 1)
    return math.Clamp(start + (CurTime() - hitTime) * RECOVERY, start, 1)
end

local function ClearLandPenalty(ply)
    ply.CSGOLandPenaltyEnd = nil
    ply.CSGOLandPenaltyStartSpeed = nil
end

local function LandPenaltyFactor(ply)
    local endTime = ply.CSGOLandPenaltyEnd
    if not endTime or LAND_PENALTY_DURATION <= 0 then return 1 end

    local remaining = endTime - CurTime()
    if remaining <= 0 then return 1 end

    return Lerp(math.Clamp(1 - remaining / LAND_PENALTY_DURATION, 0, 1), LAND_PENALTY_MULT, 1)
end

local function ClampHorizontalVelocity(velocity, maximumSpeed)
    local horizontalSqr = velocity.x * velocity.x + velocity.y * velocity.y
    if horizontalSqr <= maximumSpeed * maximumSpeed then return false end

    local scale = maximumSpeed / math.sqrt(horizontalSqr)
    velocity.x = velocity.x * scale
    velocity.y = velocity.y * scale
    return true
end

function CSGOResetMovementState(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    ClearLandPenalty(ply)

    if not SERVER then return end

    ply:SetNW2Float("CSGOVelocityModifier", 1)
    ply:SetNW2Float("CSGOVelocityHitTime", 0)
end

function CSGOApplyDamageSlowdown(ply, damage)
    if not SERVER or not IsPlaying(ply) then return end

    local modifier = math.Clamp(1 - math.max(damage, 0) * SLOW_PER_POINT, SLOW_MINIMUM, 1)
    ply:SetNW2Float("CSGOVelocityModifier", math.min(VelocityModifier(ply), modifier))
    ply:SetNW2Float("CSGOVelocityHitTime", CurTime())
end

local GM = GM or GAMEMODE

function GM:SetupMove(ply, mv, cmd)
    self.BaseClass.SetupMove(self, ply, mv, cmd)

    if not IsPlaying(ply) or ply:GetMoveType() ~= MOVETYPE_WALK then return end

    if GetGlobalBool("CSRoundGetReady", false) then
        mv:SetForwardSpeed(0)
        mv:SetSideSpeed(0)
        mv:SetUpSpeed(0)
        mv:SetMaxSpeed(0)
        mv:SetMaxClientSpeed(0)
        return
    end

    local landPenalty = LandPenaltyFactor(ply)

    if not ply:OnGround() or mv:KeyDown(IN_JUMP) then
        local airSpeed = AIR_MAX_SPEED * landPenalty
        mv:SetMaxSpeed(airSpeed)
        mv:SetMaxClientSpeed(airSpeed)
        return
    end

    local speed = MOVE_SPEED

    if mv:KeyDown(IN_DUCK) or ply:Crouching() then
        speed = speed * DUCK_MULT
    elseif mv:KeyDown(IN_SPEED) then
        speed = speed * WALK_MULT
    end

    speed = speed * VelocityModifier(ply) * landPenalty

    mv:SetMaxSpeed(speed)
    mv:SetMaxClientSpeed(speed)
end

function GM:FinishMove(ply, mv)
    self.BaseClass.FinishMove(self, ply, mv)

    if not IsPlaying(ply) or ply:GetMoveType() ~= MOVETYPE_WALK then return end

    local velocity = mv:GetVelocity()
    local airborne = not ply:OnGround()
    local changed = false

    if airborne and AIR_GAIN > 0 then
        local forward = mv:GetForwardSpeed()
        local side = mv:GetSideSpeed()

        if forward ~= 0 or side ~= 0 then
            local yaw = Angle(0, mv:GetMoveAngles().y, 0)
            local wishDirection = yaw:Forward() * forward + yaw:Right() * side
            wishDirection.z = 0

            if wishDirection:LengthSqr() > 0 then
                wishDirection:Normalize()

                local currentSpeed = velocity.x * wishDirection.x + velocity.y * wishDirection.y
                local gain = math.min(MOVE_SPEED * AIR_GAIN * engine.TickInterval(), AIR_MAX_SPEED - currentSpeed)

                if gain > 0 then
                    velocity.x = velocity.x + wishDirection.x * gain
                    velocity.y = velocity.y + wishDirection.y * gain
                    changed = true
                end
            end
        end
    end

    local penaltyFactor = LandPenaltyFactor(ply)
    local maximumSpeed = AIR_MAX_SPEED

    if penaltyFactor >= 1 then
        ClearLandPenalty(ply)
    elseif not airborne and ply.CSGOLandPenaltyStartSpeed then
        maximumSpeed = math.min(maximumSpeed, ply.CSGOLandPenaltyStartSpeed * penaltyFactor)
    end

    if ClampHorizontalVelocity(velocity, maximumSpeed) then
        changed = true
    end

    if changed then
        mv:SetVelocity(velocity)
    end
end

hook.Add("OnPlayerHitGround", "CSGO.LandPenalty", function(ply, inWater)
    if inWater or not IsPlaying(ply) then return end

    if LAND_PENALTY_DURATION <= 0 or LAND_PENALTY_MULT >= 1 then
        ClearLandPenalty(ply)
        return
    end

    local velocity = ply:GetVelocity()
    local horizontalSpeedSqr = velocity.x * velocity.x + velocity.y * velocity.y

    if horizontalSpeedSqr < LAND_PENALTY_MIN_SPEED_SQR then
        ClearLandPenalty(ply)
        return
    end

    ply.CSGOLandPenaltyStartSpeed = math.sqrt(horizontalSpeedSqr)
    ply.CSGOLandPenaltyEnd = CurTime() + LAND_PENALTY_DURATION
end)

function PLAYER:SetModel()
    local ply = self.Player
    if not IsValid(ply) then return end

    local models = CSGOConfig.TeamModels[ply:Team()]
    if not istable(models) or #models == 0 then return end

    local model = models[math.random(#models)]

    if isstring(model) and model ~= "" then
        ply:SetModel(model)
    end
end

function PLAYER:Spawn()
    local ply = self.Player
    if not IsValid(ply) then return end

    ply:SetWalkSpeed(MOVE_SPEED)
    ply:SetRunSpeed(MOVE_SPEED)
    ply:SetCrouchedWalkSpeed(1)
    ply:SetDuckSpeed(self.DuckSpeed)
    ply:SetUnDuckSpeed(self.UnDuckSpeed)
    ply:SetJumpPower(self.JumpPower)
    ply:SetStepSize(CSGOConfig.StepSize)
    ply:SetGravity(1)
    ply:SetMaxHealth(self.MaxHealth)
    ply:SetHealth(self.StartHealth)
    ply:SetArmor(self.StartArmor)
    ply:SetViewOffset(standView)
    ply:SetViewOffsetDucked(duckView)
    ply:SetCanZoom(false)
    ply:ShouldDropWeapon(false)
    ply:SetBloodColor(BLOOD_COLOR_RED)
    ply:SetLocalVelocity(vector_origin)
    CSGOResetMovementState(ply)
end

function PLAYER:Death()
    local ply = self.Player

    if IsValid(ply) and not IsValid(ply:GetRagdollEntity()) then
        ply:CreateRagdoll()
    end
end

function PLAYER:GetHandsModel()
    local ply = self.Player
    if not IsValid(ply) then return end

    local modelName = player_manager.TranslateToPlayerModelName(ply:GetModel())
    if not modelName then return end

    return player_manager.TranslatePlayerHands(modelName)
end

player_manager.RegisterClass("player_csgo", PLAYER, "player_default")
