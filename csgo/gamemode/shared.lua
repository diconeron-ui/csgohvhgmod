DeriveGamemode("sandbox")

GM.Name = "CS:GO"
GM.TeamBased = true

include("sh_config.lua")
include("player_class/player_csgo.lua")

function GM:CreateTeams()
    team.SetUp(CSGOConfig.TeamCT, "CT", Color(80, 140, 255), true)
    team.SetUp(CSGOConfig.TeamT, "T", Color(255, 90, 90), true)
end

GM:CreateTeams()
