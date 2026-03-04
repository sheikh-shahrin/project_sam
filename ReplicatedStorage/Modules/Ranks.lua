local RankConfig = {
	TOTAL_STAGES = 3,
	EASY_WIN_XP = 2,
	EASY_LOSE_XP = 1,
	HARD_WIN_XP = 10,
	HARD_LOSE_XP = 5,
}

local RankSeasons = {
	[1] = {
		StartDate = DateTime.fromUniversalTime(2026, 3, 1),
		Active = true
	},
}

local RankTable = {
	{
		Name = "Novice",
		StageCompletion = 10,
		Image = nil,
		Gradient = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 180)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 200, 255))
		}
	},
	{
		Name = "Bronze",
		StageCompletion = 50,
		Image = nil,
		Gradient = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(205, 120, 60)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 160, 90))
		}
	},
	{
		Name = "Silver",
		StageCompletion = 50,
		Image = nil,
		Gradient = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 220, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 240, 255))
		}
	},
	{
		Name = "Gold",
		StageCompletion = 100,
		Image = nil,
		Gradient = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 0))
		}
	},
	{
		Name = "Diamond",
		StageCompletion = 100,
		Image = nil,
		Gradient = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 170, 255))
		}
	},
	{
		Name = "Emerald",
		StageCompletion = 150,
		Image = nil,
		Gradient = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 200, 90))
		}
	},
	{
		Name = "Platinum",
		StageCompletion = 150,
		Image = nil,
		Gradient = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 200, 255))
		}
	},
	{
		Name = "Master",
		StageCompletion = 200,
		Image = nil,
		Gradient = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 200)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 0, 255))
		}
	},
	{
		Name = "Overlord",
		StageCompletion = 200,
		Image = nil,
		Gradient = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 0))
		}
	},
}

local Ranks = {}

function Ranks:GetRankTable() 
	return table.clone(RankTable)
end

function Ranks:GetRankConfig()
	return RankConfig
end

function Ranks:GetRank(rankName)	
	for _, rank in ipairs(self:GetRankTable()) do
		if rank.Name == rankName then
			return rank
		end
	end
	return nil
end

function Ranks:GetCurrentSeason()
	local currentSeason = 1
	local tempHS = 0
	
	for i, v in pairs(RankSeasons) do
		if os.time() >= v.StartDate.UnixTimestamp and tempHS >= v.StartDate.UnixTimestamp and v.Active then
			tempHS = v.StartDate
			currentSeason = i
		end
	end
	
	return currentSeason
end

function Ranks:GetPlrRank(plr)
	local plrRank = plr:FindFirstChild("rank")
	if not plrRank then return nil end

	local xp = plrRank:FindFirstChild("XP")
	if not xp then return nil end

	local totalXP = xp.Value
	local counter = 0

	local result = {
		Rank = nil,
		Stage = 1,
		RankProgress = 0
	}

	for _, rank in ipairs(self:GetRankTable()) do
		for stage = 1, RankConfig.TOTAL_STAGES do
			local stageMin = counter
			local stageMax = counter + rank.StageCompletion

			if totalXP >= stageMin and totalXP < stageMax then
				result.Rank = rank
				result.Stage = stage
				result.RankProgress = totalXP - stageMin
				return result
			end

			counter = stageMax
		end
	end

	-- If XP exceeds all defined ranks → max rank
	local lastRank = self:GetRankTable()[#RankTable]
	result.Rank = lastRank
	result.Stage = RankConfig.TOTAL_STAGES
	result.RankProgress = lastRank.StageCompletion
	return result
end

function Ranks:ChangeXP(plr, gain, amt)
	local plrRank = plr:FindFirstChild("rank")
	
	if not plrRank then return end
	
	local xp = plrRank:FindFirstChild("XP")
	
	if not xp then return end
	
	if gain then
		xp.Value += amt
	else
		if xp.Value - amt < 0 then
			xp.Value = 0
		else
			xp.Value -= amt
		end
	end
end

return Ranks