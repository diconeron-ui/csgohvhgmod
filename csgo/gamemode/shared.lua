DeriveGamemode("sandbox")

GM.Name = "CS:GO"
GM.TeamBased = true
GM.AllowAutoTeam = false

include("sh_config.lua")
include("sh_spectator.lua")
include("player_class/player_csgo.lua")

local teamsCreated = false

function GM:CreateTeams()
    if teamsCreated then return end
    teamsCreated = true

    for _, teamID in ipairs(CSGOConfig.TeamOrder) do
        team.SetUp(teamID, CSGOConfig.TeamNames[teamID], CSGOConfig.TeamColors[teamID], true)
    end
end

GM:CreateTeams()
