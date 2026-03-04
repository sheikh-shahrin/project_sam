local rs = game:GetService("ReplicatedStorage")
local rankMod = require(rs.Modules.Ranks)

local plrs = game:GetService("Players")

plrs.PlayerAdded:Connect(function(plr)	
	local rank = plr:WaitForChild("rank")
	
	local currentSeason = rankMod:GetCurrentSeason()
	
	local plrSeason = rank:WaitForChild("Season")
	local plrXP = rank:WaitForChild("XP")
	
	if plrSeason.Value < currentSeason then
		plrSeason.Value = currentSeason
		plrXP.Value = 0
	end
end)