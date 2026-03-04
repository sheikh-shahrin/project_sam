local schema = {
	leaderstats = {},
	rank = {}
}

local DatabaseSchema = {}

function DatabaseSchema:GetSchema()
	return table.clone(schema)
end

function DatabaseSchema:InsertStat(dataFolder: Folder, statFolder: {any})
	if dataFolder.Name == "leaderstats" then
		local statsTb = {
			{ClassName = "NumberValue", Name = "Coins", Value = 0},
			{ClassName = "IntValue", Name = "Wins", Value = 0},
		}

		for i, v in pairs(statsTb) do
			local stat = Instance.new(v.ClassName, dataFolder)
			stat.Name = v.Name

			local value = v.Value

			if next(statFolder.leaderstats) and statFolder.leaderstats[v.Name] ~= nil then
				value = statFolder.leaderstats[v.Name]
			end

			stat.Value = value
		end
	elseif dataFolder.Name == "rank" then
		local statsTb = {
			{ClassName = "IntValue", Name = "Season", Value = 0},
			{ClassName = "NumberValue", Name = "XP", Value = 0},
		}
		
		for i, v in pairs(statsTb) do
			local stat = Instance.new(v.ClassName, dataFolder)
			stat.Name = v.Name

			local value = v.Value

			if next(statFolder.rank) and statFolder.rank[v.Name] ~= nil then
				value = statFolder.rank[v.Name]
			end

			stat.Value = value
		end
	end
end

function DatabaseSchema:SaveStat(plr: Player, statName: string, dataStats: {any})
	local statFolder = plr:FindFirstChild(statName)
	if not statFolder then return end

	if statName == "leaderstats" then
		for i, v in pairs(statFolder:GetChildren()) do
			dataStats.leaderstats[v.Name] = v.Value
		end
	elseif statName == "rank" then
		for i, v in pairs(statFolder:GetChildren()) do
			dataStats.rank[v.Name] = v.Value
		end
	end
end

function DatabaseSchema:InsertData(plr: Player, dataStats: {any})
	local inSchema = self:GetSchema()
	
	for i, v in pairs(inSchema) do
		local folder = Instance.new("Folder", plr)
		folder.Name = i
		
		self:InsertStat(folder, dataStats)
	end
end

function DatabaseSchema:SaveData(plr: Player, dataStats: {any})
	local inSchema = self:GetSchema()
	
	for i, v in pairs(inSchema) do
		self:SaveStat(plr, i, dataStats)
	end
end

return DatabaseSchema
