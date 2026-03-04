local rs = game:GetService("ReplicatedStorage")
local const = require(rs.Modules.Constants)

game.Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild('Humanoid')
		while task.wait() do
			if humanoid.Health > 0 then
				humanoid.Health = plr.tempData.plrHp.Value
			end
			if plr.tempData.plrHp.Value > const.MAX_HEALTH then
				humanoid.MaxHealth = plr.tempData.plrHp.Value
			else
				humanoid.MaxHealth = const.MAX_HEALTH
			end
		end
	end)
end)