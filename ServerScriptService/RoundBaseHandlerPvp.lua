local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

local RoundBase = {}
RoundBase.__index = RoundBase

local INITIAL_COOLDOWN = 5
local NORMAL_COOLDOWN = 10

local BUFFER_TIME = .5

local COLORS = {
	Idle = Color3.fromRGB(255,255,255),
	Full = Color3.fromRGB(255,255,0),
	Cooldown = Color3.fromRGB(255,0,0),
}

local function isCharacterStillTouching(character, part)
	for _, p in ipairs(part:GetTouchingParts()) do
		if p:IsDescendantOf(character) then
			return true
		end
	end
	return false
end

function RoundBase.new(baseModel)
	local self = setmetatable({}, RoundBase)

	self.Base = baseModel.Parent
	self.Stepper = baseModel
	self.Hitbox = baseModel:WaitForChild("hb")
	self.DisplayText = baseModel:WaitForChild("hb"):WaitForChild("BillboardGui"):WaitForChild("TextLabel")
	self.CountdownActive = false
	self.CountdownP1 = nil
	self.CountdownP2 = nil
	
	self.PlayerLeftHealthConnection = nil
	self.PlayerRightHealthConnection = nil
	self.PlayerLeftHealth = baseModel.Parent:WaitForChild("battleground"):WaitForChild("PlayerHealthUI")
	self.PlayerRightHealth = baseModel.Parent:WaitForChild("battleground"):WaitForChild("BotHealthUI")

	self.Base:SetAttribute("taken", false)
	self.Base:SetAttribute("onCooldown", false)
	self.Base:SetAttribute("p1UserId", 0)
	self.Base:SetAttribute("p2UserId", 0)
	self.PlayersInside = {} -- [player] = true
	self.TouchTimers = {}

	self:Connect()
	self:Update(true, false)
	self:SetCharacterVisible(false)

	return self
end

function RoundBase:HealthDisconnect()
	if self.PlayerLeftHealthConnection then
		self.PlayerLeftHealthConnection:Disconnect()
		self.PlayerLeftHealthConnection = nil
	end
	
	if self.PlayerRightHealthConnection then
		self.PlayerRightHealthConnection:Disconnect()
		self.PlayerRightHealthConnection = nil
	end
end

function RoundBase:DestroyHealthUI()
	if self.PlayerLeftHealth and self.PlayerRightHealth then
		local healthUI = {self.PlayerLeftHealth, self.PlayerRightHealth}
		
		for _, healthFocus in pairs(healthUI) do
			local healthUI = healthFocus:WaitForChild("SurfaceGui")
			local frame = healthUI:WaitForChild("Frame")
			
			for i, v in pairs(frame:GetChildren()) do
				if v:IsA("Frame") then
					v:Destroy()
				end
			end
		end
	end
end

function RoundBase:UpdateHealthUI(left, health)
	local function updateHealthUI(frame, folder, health)
		for i, v in pairs(frame:GetChildren()) do
			if v:IsA("Frame") then
				v:Destroy()
			end
		end
		
		for i = 1, health do
			local clone = folder:WaitForChild("hpBlock"):Clone()
			clone.Parent = frame
			clone.Visible = true
		end
	end
	
	local healthFocus = left and self.PlayerLeftHealth or self.PlayerRightHealth
	
	local healthUI = healthFocus:WaitForChild("SurfaceGui")
	local frame = healthUI:WaitForChild("Frame")
	local cloneFolder = healthUI:WaitForChild("Folder")

	updateHealthUI(frame, cloneFolder, health)
end

function RoundBase:HealthConnect()
	self:HealthDisconnect()
	
	task.wait(1)
	
	local plr1 
	local plr2
	
	for i, v in pairs(game.Players:GetPlayers()) do
		if plr1 and plr2 then break end
		
		if v.UserId == self.Base:GetAttribute("p1UserId") then
			plr1 = v
		elseif v.UserId == self.Base:GetAttribute("p2UserId") then
			plr2 = v
		end
	end
	
	if not plr1 or not plr2 then return end
	
	local td1 = plr1:FindFirstChild("tempData")
	local td2 = plr2:FindFirstChild("tempData")
	
	if not td1 or not td2 then return end

	if (td1.roundBase.Value and td1.roundBase.Value == self.Base) and (td2.roundBase.Value and td2.roundBase.Value == self.Base) then
		self:UpdateHealthUI(true, td1.plrHp.Value)
		self:UpdateHealthUI(false, td2.plrHp.Value)

		local plrHealth = td1:WaitForChild("plrHp")
		local botHealth = td2:WaitForChild("plrHp")

		if plrHealth and botHealth then
			self.PlayerLeftHealthConnection = plrHealth:GetPropertyChangedSignal("Value"):Connect(function()
				self:UpdateHealthUI(true, td1.plrHp.Value)
			end)

			self.PlayerRightHealthConnection = botHealth:GetPropertyChangedSignal("Value"):Connect(function()
				self:UpdateHealthUI(false, td2.plrHp.Value)
			end)
		end
	end
end

function RoundBase:SetCharacterVisible(visible)
	local t = visible and 3 or .1
	
	task.delay(t, function()
		local transparency = visible and 0 or 1

		local battleground = self.Base:FindFirstChild("battleground")
		if not battleground then return end

		local botM = battleground:FindFirstChild("Bot")
		local plrM = battleground:FindFirstChild("Player")
		if not botM or not plrM then return end

		for _, obj in ipairs(botM:GetDescendants()) do
			if obj.Name ~= "HumanoidRootPart" then
				if obj:IsA("BasePart") or obj:IsA("Part") or obj:IsA("MeshPart") or obj:IsA("Decal") then
					obj.Transparency = transparency
				end
			end
		end

		for _, obj in ipairs(plrM:GetDescendants()) do
			if obj.Name ~= "HumanoidRootPart" then
				if obj:IsA("BasePart") or obj:IsA("Part") or obj:IsA("MeshPart") or obj:IsA("Decal") then
					obj.Transparency = transparency
				end
			end
		end
	end)
end

function RoundBase:UpdateBrickColor(color)
	for _, part in ipairs(self.Stepper:GetChildren()) do
		if part:IsA("Part") and part.Name ~= "hb" then
			part.Color = color
		end
	end
end

function RoundBase:StartCooldown(duration)
	self.Base:SetAttribute("onCooldown", true)
	self:UpdateBrickColor(COLORS.Cooldown)

	for i = duration, 1, -1 do
		self.DisplayText.Text = tostring(i)
		task.wait(1)
	end

	self.Base:SetAttribute("onCooldown", false)
	self:UpdateBrickColor(COLORS.Idle)
end

function RoundBase:StartCountdown(p1plr, p2plr)
	if self.CountdownActive then return end

	self.CountdownActive = true
	self.CountdownP1 = p1plr
	self.CountdownP2 = p2plr

	self:UpdateBrickColor(COLORS.Full)

	local initialTime = tick()
	local duration = 5

	while tick() - initialTime < duration do
		if not self.CountdownActive then
			self.DisplayText.Text = "1 / 2"
			self:UpdateBrickColor(COLORS.Full)
			return
		end

		if not self.PlayersInside[p1plr] or not self.PlayersInside[p2plr] then
			self.CountdownActive = false
			self.DisplayText.Text = "1 / 2"
			self:UpdateBrickColor(COLORS.Full)
			return
		end

		local timeLeft = math.ceil(duration - (tick() - initialTime))
		self.DisplayText.Text = "Round starting in " .. timeLeft

		task.wait()
	end

	-- ✅ ROUND ACTUALLY STARTS HERE
	self.Base:SetAttribute("taken", true)

	remoteEvents.StartRoundPVP:FireClient(p1plr)
	remoteEvents.StartRoundPVP:FireClient(p2plr)

	local ServerScriptService = game:GetService("ServerScriptService")
	local ServerBindableEvents = ServerScriptService:WaitForChild("ServerBindableEvents")
	local startPvpBE = ServerBindableEvents:WaitForChild("StartRoundPvpBE")

	startPvpBE:Fire(self.Base, p1plr, p2plr)

	self:SetCharacterVisible(true)
	self.CountdownActive = false
	
	self:Update(false, true)
end

function RoundBase:Update(isInit, noCooldown)
	local cd = isInit and INITIAL_COOLDOWN or NORMAL_COOLDOWN

	if self.Base:GetAttribute("taken") then
		self:UpdateBrickColor(COLORS.Cooldown)
		self.DisplayText.Text = "Round in progress"
		self:HealthConnect()
		return
	end
	
	task.delay(5, function()
		self:SetCharacterVisible(false)
	end)
	
	self:HealthDisconnect()
	self:DestroyHealthUI()

	local p1 = self.Base:GetAttribute("p1UserId")
	local p2 = self.Base:GetAttribute("p2UserId")

	if p1 ~= 0 and p2 == 0 then
		self:UpdateBrickColor(COLORS.Full)
		self.DisplayText.Text = "1 / 2"
		return
	end
	
	if noCooldown == false then
		self:StartCooldown(cd)
	elseif noCooldown == true then
		self:UpdateBrickColor(COLORS.Idle)
	elseif noCooldown == nil then
		return 
	end
	
	self.DisplayText.Text = "0 / 2"
end

function RoundBase:ClearPlayers()
	self.Base:SetAttribute("p1UserId", 0)
	self.Base:SetAttribute("p2UserId", 0)
	self.PlayersInside = {}
end

function RoundBase:HandleTouch(hit)
	if self.Base:GetAttribute("taken") then return end
	if self.Base:GetAttribute("onCooldown") then return end

	local character = hit.Parent
	if not character then return end
	if not character:FindFirstChild("Humanoid") then return end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end
	
	if self.TouchTimers[player] then
		self.TouchTimers[player] = nil
	end
	
	self.PlayersInside[player] = true

	local td = player:FindFirstChild("tempData")
	if not td then return end
	if td.mode.Value ~= "" then return end

	local p1 = self.Base:GetAttribute("p1UserId")
	local p2 = self.Base:GetAttribute("p2UserId")
	
	if p1 == 0 then
		self.Base:SetAttribute("p1UserId", player.UserId)
		td.roundBase.Value = self.Base
		td.mode.Value = "pvp_wait"
		self:Update(false, true)
		return
	end

	if p1 == player.UserId then
		return
	end

	if p2 == 0 then
		self.Base:SetAttribute("p2UserId", player.UserId)
		td.roundBase.Value = self.Base
		td.mode.Value = "player"

		local p1plr = Players:GetPlayerByUserId(p1)
		if not p1plr then
			self:ClearPlayers()
			self:Update(false, true)
			return
		end

		p1plr.tempData.roundBase.Value = self.Base
		p1plr.tempData.mode.Value = "player"
		
		local ServerScriptService = game:GetService("ServerScriptService")
		local ServerBindableEvents = ServerScriptService:WaitForChild("ServerBindableEvents")
		local startPvpBE = ServerBindableEvents:WaitForChild("StartRoundPvpBE")

		task.spawn(function()
			self:StartCountdown(p1plr, player)
		end)
	end
end

function RoundBase:HandleTouchEnded(hit)
	if self.Base:GetAttribute("taken") then return end

	local character = hit.Parent
	if not character then return end
	if not character:FindFirstChild("Humanoid") then return end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end
		
	self.TouchTimers[player] = true
	
	task.delay(BUFFER_TIME, function()
		if isCharacterStillTouching(character, self.Hitbox) then return end

		if self.TouchTimers[player] then
			self.TouchTimers[player] = nil
		end
		
		if not self.PlayersInside[player] then return end
		self.PlayersInside[player] = nil
		
		if self.CountdownActive then
			if player == self.CountdownP1 or player == self.CountdownP2 then
				self.CountdownActive = false
				self.CountdownP1 = nil
				self.CountdownP2 = nil
			end
		end
		
		local p1 = self.Base:GetAttribute("p1UserId")
		local p2 = self.Base:GetAttribute("p2UserId")
		
		if p1 == 0 and p2 == 0 then return end

		if p1 == player.UserId then
			self.Base:SetAttribute("p1UserId", 0)
		elseif p2 == player.UserId then
			self.Base:SetAttribute("p2UserId", 0)
		end

		local td = player:FindFirstChild("tempData")
		if td then
			td.roundBase.Value = nil
			td.mode.Value = ""
		end
		
		self:Update(false, true)
	end)
end

function RoundBase:Connect()
	self.Hitbox.Touched:Connect(function(hit)
		self:HandleTouch(hit)
	end)

	self.Hitbox.TouchEnded:Connect(function(hit)
		self:HandleTouchEnded(hit)
	end)

	self.Base:GetAttributeChangedSignal("taken"):Connect(function()
		self:Update(false, false)
		
		if not self.Base:GetAttribute("taken") then
			self:HealthDisconnect()
			self:DestroyHealthUI()
		end
	end)

	self.Base:GetAttributeChangedSignal("p1UserId"):Connect(function()
		self:Update(false)
		
		if self.Base:GetAttribute("p1UserId") == nil then
			self:HealthDisconnect()
			self:DestroyHealthUI()
		end
	end)

	self.Base:GetAttributeChangedSignal("p2UserId"):Connect(function()
		self:Update(false)
		
		if self.Base:GetAttribute("p2UserId") == nil then
			self:HealthDisconnect()
			self:DestroyHealthUI()
		end
	end)
end

return RoundBase