local plrs = game:GetService("Players")
local dataStoreService = game:GetService("DataStoreService")
local serverScriptService = game:GetService("ServerScriptService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local constMod = require(replicatedStorage.Modules.Constants)
local schemaMod = require(serverScriptService.DatabaseSchema)

local samDb = dataStoreService:GetDataStore("sam_db")

local function saveStats(plr)
	local key = tostring(plr.UserId)
	local dataStats = schemaMod:GetSchema()
	
	samDb:UpdateAsync(key, function(existingStats)	
		if existingStats then
			for i, v in pairs(existingStats) do
				dataStats[i] = v
			end
		end
		
		schemaMod:SaveData(plr, dataStats)
		
		return dataStats
	end)
end

plrs.PlayerAdded:Connect(function(plr)
	local key = tostring(plr.UserId)
	local dataStats = schemaMod:GetSchema()
	
	local success, data = pcall(function()
		return samDb:GetAsync(key)
	end)
	
	if success and data then
		for i, v in pairs(dataStats) do
			dataStats[i] = data[i] or v
		end
	end
	
	schemaMod:InsertData(plr, dataStats)
end)

plrs.PlayerRemoving:Connect(saveStats)

game:BindToClose(function()
	for _, plr in pairs(game.Players:GetPlayers()) do
		saveStats(plr)
	end
end)

