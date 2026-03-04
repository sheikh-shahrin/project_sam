plrs = game:GetService("Players")
rs = game:GetService("ReplicatedStorage")
remoteEvents = rs:WaitForChild("RemoteEvents")

remoteEvents.plrClone.OnServerEvent:Connect(function(plr)
	local tempData = plr:WaitForChild("tempData")
	local roundBase = tempData.roundBase.Value
	
	if roundBase == nil then return end
	
	local battleground = roundBase:WaitForChild("battleground")
	local playerModel = battleground:WaitForChild("Player")
	local humanoid = playerModel:WaitForChild("Humanoid")

	local successDesc, description = pcall(function()
		return game.Players:GetHumanoidDescriptionFromUserIdAsync(plr.UserId)
	end)

	if successDesc and description then
		humanoid:ApplyDescriptionAsync(description)
	else
		warn("Failed to get HumanoidDescription for UserId: " .. plr.UserId)
	end
end)

remoteEvents.PVPClone.OnServerEvent:Connect(function(plr)
	local tempData = plr:WaitForChild("tempData")
	local roundBase = tempData.roundBase.Value

	if roundBase == nil then return end
	
	local battleground = roundBase:WaitForChild("battleground")
	local plr1Model = battleground:WaitForChild("Player")
	local plr2Model = battleground:WaitForChild("Bot")
	local humanoid1 = plr1Model:WaitForChild("Humanoid")
	local humanoid2 = plr2Model:WaitForChild("Humanoid")
	
	local plr1ID = tempData.roundBase.Value:GetAttribute("p1UserId")
	local plr1 = plrs:GetPlayerByUserId(plr1ID)
	
	local plr2ID = tempData.roundBase.Value:GetAttribute("p2UserId")
	local plr2 = plrs:GetPlayerByUserId(plr2ID)
	
	if plr1 and plr2 then
		local success1, description1 = pcall(function()
			return game.Players:GetHumanoidDescriptionFromUserIdAsync(plr1.UserId)
		end)

		if success1 and description1 then
			humanoid1:ApplyDescriptionAsync(description1)
		else
			warn("Failed to get HumanoidDescription for UserId: " .. plr1.UserId)
		end
		
		local success2, description2 = pcall(function()
			return game.Players:GetHumanoidDescriptionFromUserIdAsync(plr2.UserId)
		end)

		if success2 and description2 then
			humanoid2:ApplyDescriptionAsync(description2)
		else
			warn("Failed to get HumanoidDescription for UserId: " .. plr2.UserId)
		end
	end
end)