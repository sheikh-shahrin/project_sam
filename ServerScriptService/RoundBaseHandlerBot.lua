local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

local RoundBase = {}
RoundBase.__index = RoundBase

-- CONFIG
local MAX_PLAYERS = 1
local INITIAL_COOLDOWN = 5
local NORMAL_COOLDOWN = 10

local COLORS = {
	Idle = Color3.fromRGB(255,255,255),
	Full = Color3.fromRGB(255,255,0),
	Cooldown = Color3.fromRGB(255,0,0),
}

local BUFFER_TIME = .5

local function isCharacterStillTouching(character, part)
	for _, p in ipairs(part:GetTouchingParts()) do
		if p:IsDescendantOf(character) then
			return true
		end
	end
	return false
end

-- Constructor
function RoundBase.new(baseModel)
	local self = setmetatable({}, RoundBase)

	self.Base = baseModel.Parent
	self.Stepper = baseModel
	self.Hitbox = baseModel:WaitForChild("hb")
	self.DisplayText = baseModel:WaitForChild("hb"):WaitForChild("BillboardGui"):WaitForChild("TextLabel")
	self.PlayerLeftHealthConnection = nil
	self.PlayerRightHealthConnection = nil
	self.PlayerLeftHealth = baseModel.Parent:WaitForChild("battleground"):WaitForChild("PlayerHealthUI")
	self.PlayerRightHealth = baseModel.Parent:WaitForChild("battleground"):WaitForChild("BotHealthUI")
	self.PlayersInside = {}
	self.TouchTimers = {}
	self.CountdownActive = false
	self.CountdownPlayer = nil

	self.Base:SetAttribute("taken", false)
	self.Base:SetAttribute("onCooldown", false)

	self:Connect()
	self:Update(true)
	self:SetCharacterVisible(false)

	return self
end

-------------------------------------------------
-- Internal Helpers
-------------------------------------------------

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
	
	for i, plr in pairs(game.Players:GetPlayers()) do
		local td = plr:FindFirstChild("tempData")
		if not td then continue end
		
		if td.roundBase.Value and td.roundBase.Value == self.Base then
			self:UpdateHealthUI(true, td.plrHp.Value)
			self:UpdateHealthUI(false, td.botHp.Value)
			
			local plrHealth = td:WaitForChild("plrHp")
			local botHealth = td:WaitForChild("botHp")

			if plrHealth and botHealth then
				self.PlayerLeftHealthConnection = plrHealth:GetPropertyChangedSignal("Value"):Connect(function()
					self:UpdateHealthUI(true, td.plrHp.Value)
				end)

				self.PlayerRightHealthConnection = botHealth:GetPropertyChangedSignal("Value"):Connect(function()
					self:UpdateHealthUI(false, td.botHp.Value)
				end)
			end
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

function RoundBase:GetPlayerCount()
	return self.Base:GetAttribute("taken") and 1 or 0
end

-------------------------------------------------
-- Joining Logic
-------------------------------------------------

function RoundBase:StartCountdown(player)
	if self.CountdownActive then return end

	self.CountdownActive = true
	self.CountdownPlayer = player
	
	self:UpdateBrickColor(COLORS.Full)
	
	local initialTime = tick()
	local duration = 5

	while tick() - initialTime < duration do
		if not self.CountdownActive then
			self.DisplayText.Text = "0 / 1"
			self:UpdateBrickColor(COLORS.Idle)
			return
		end

		if not self.PlayersInside[player] then
			self.CountdownActive = false
			self.DisplayText.Text = "0 / 1"
			self:UpdateBrickColor(COLORS.Idle)
			return
		end

		local timeLeft = math.ceil(duration - (tick() - initialTime))
		self.DisplayText.Text = "Round starting in " .. timeLeft

		task.wait()
	end

	-- ✅ ROUND STARTS HERE
	self.Base:SetAttribute("taken", true)

	local ServerScriptService = game:GetService("ServerScriptService")
	local ServerBindableEvents = ServerScriptService:WaitForChild("ServerBindableEvents")
	local startBotBE = ServerBindableEvents:WaitForChild("StartRoundBotBE")

	startBotBE:Fire(player)
	remoteEvents.StartRoundBot:FireClient(player)

	self:SetCharacterVisible(true)
	self.CountdownActive = false
end

function RoundBase:HandleTouch(hit)
	if self.Base:GetAttribute("taken") then return end
	if self.Base:GetAttribute("onCooldown") then return end

	local character = hit.Parent
	if not character then return end
	if not character:FindFirstChild("Humanoid") then return end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	self.PlayersInside[player] = true

	local tempData = player:FindFirstChild("tempData")
	if not tempData then return end
	if tempData.mode.Value == "bot" then return end

	tempData.roundBase.Value = self.Base

	task.spawn(function()
		self:StartCountdown(player)
	end)
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

		-- Cancel countdown if this player was counting down
		if self.CountdownActive and player == self.CountdownPlayer then
			self.CountdownActive = false
			self.CountdownPlayer = nil
		end

		local td = player:FindFirstChild("tempData")
		if td then
			td.roundBase.Value = nil
		end

		self.DisplayText.Text = "0 / 1"
	end)
end

-------------------------------------------------
-- Visual + Cooldown Logic
-------------------------------------------------

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

function RoundBase:Update(isInit)
	local cooldownTime = isInit and INITIAL_COOLDOWN or NORMAL_COOLDOWN

	local taken = self.Base:GetAttribute("taken")
	local count = self:GetPlayerCount()

	if taken then
		self:UpdateBrickColor(COLORS.Cooldown)
		self.DisplayText.Text = "Round in progress"
		self:HealthConnect()
	else
		task.delay(5, function()
			self:SetCharacterVisible(false)
		end)
		self:HealthDisconnect()
		self:DestroyHealthUI()
		self:StartCooldown(cooldownTime)
		self.DisplayText.Text = count .. " / " .. MAX_PLAYERS
	end
end

-------------------------------------------------
-- Connections
-------------------------------------------------

function RoundBase:Connect()
	self.Hitbox.Touched:Connect(function(hit)
		self:HandleTouch(hit)
	end)
	
	self.Hitbox.TouchEnded:Connect(function(hit)
		self:HandleTouchEnded(hit)
	end)

	self.Base:GetAttributeChangedSignal("taken"):Connect(function()
		self:Update(false)
	end)
end

return RoundBase