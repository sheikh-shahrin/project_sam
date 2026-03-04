game.Players.PlayerAdded:Connect(function(plr)
	local folder = Instance.new("Folder", plr)
	folder.Name = "tempData"

	local StatsFolder = {
		{ClassName = "NumberValue", Name = "botHp", Value = 5},
		{ClassName = "NumberValue", Name = "plrHp", Value = 5},
		{ClassName = "BoolValue", Name = "dha_moveCount", Value = false},
		{ClassName = "BoolValue", Name = "plrDha_moveCount", Value = false},
		{ClassName = "StringValue", Name = "mode", Value = ""},
		{ClassName = "BoolValue", Name = "stun_dhaVsla", Value = false},
		{ClassName = "BoolValue", Name = "stun_thrVblk", Value = false},
		{ClassName = "ObjectValue", Name = "roundBase", Value = nil},
	}

	for i, v in pairs(StatsFolder) do
		local stat = Instance.new(v.ClassName, folder)
		stat.Name = v.Name
		stat.Value = v.Value
	end
end)