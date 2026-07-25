CSGOConfig = CSGOConfig or {}

CSGOConfig.TeamCT = 1
CSGOConfig.TeamT = 2
CSGOConfig.RoundLimit = 30
CSGOConfig.SideSwitchRound = 15
CSGOConfig.RoundTime = 150
CSGOConfig.IntermissionTime = 5
CSGOConfig.ReadyTime = 3
CSGOConfig.BombSiteRadius = 175
CSGOConfig.C4Class = "weapon_swcs_c4"
CSGOConfig.PlantedC4Class = "swcs_planted_c4"
CSGOConfig.MoveSpeed = 250
CSGOConfig.Accelerate = 5.5
CSGOConfig.AirAccelerate = 12
CSGOConfig.AirMaxSpeed = 400
CSGOConfig.AirSpeedGainMultiplier = 1
CSGOConfig.Friction = 5.2
CSGOConfig.CrouchAccelerate = 8
CSGOConfig.WalkSpeedMultiplier = 0.52
CSGOConfig.CrouchedSpeedMultiplier = 0.34
CSGOConfig.JumpPower = 301.993377
CSGOConfig.Gravity = 700
CSGOConfig.StepSize = 18
CSGOConfig.DuckSpeed = 0.4
CSGOConfig.UnDuckSpeed = 0.25
CSGOConfig.EyeHeight = 64
CSGOConfig.EyeHeightDucked = 46
CSGOConfig.FallDamageThreshold = 526
CSGOConfig.FallDamagePerUnit = 0.2225
CSGOConfig.DamageSlowPercentPerPoint = 0.005
CSGOConfig.DamageSlowMinimum = 0.15
CSGOConfig.DamageSlowRecovery = 0.4
CSGOConfig.LandPenaltyMultiplier = 0.9
CSGOConfig.LandPenaltyDuration = 0.2
CSGOConfig.LandPenaltyMinSpeed = 300

CSGOConfig.SpawnPositions = {
    [CSGOConfig.TeamT] = Vector(1235.20, -137.76, -103.70),
    [CSGOConfig.TeamCT] = Vector(-1744.98, -1868.44, -205.26)
}

CSGOConfig.BombSites = {
    A = Vector(-443.32, -2140.11, -115.97),
    B = Vector(-2040.83, 264.53, -95.97)
}

CSGOConfig.TeamModels = {
    [CSGOConfig.TeamCT] = {
        "models/player/riot.mdl"
    },
    [CSGOConfig.TeamT] = {
        "models/player/leet.mdl"
    }
}

CSGOConfig.Loadout = {
    "weapon_swcs_taser",
    "weapon_swcs_ssg08",
    "weapon_swcs_bayonet"
}

function CSGOConfig.IsPlayTeam(teamID)
    return teamID == CSGOConfig.TeamCT or teamID == CSGOConfig.TeamT
end

function CSGOConfig.OtherTeam(teamID)
    return teamID == CSGOConfig.TeamCT and CSGOConfig.TeamT or CSGOConfig.TeamCT
end
