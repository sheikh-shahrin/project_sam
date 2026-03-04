local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local plr = Players.LocalPlayer
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

local CombatUIRE = remoteEvents:WaitForChild("CombatUI")

-- IMPORTANT: support BOTH remotes
local PlayerMoveBotRE = remoteEvents:FindFirstChild("PlayerMoveBot")
local PlayerMovePVPRE = remoteEvents:FindFirstChild("PlayerMovePVP")

local td = plr:WaitForChild("tempData")

local plrGui = plr:WaitForChild("PlayerGui")
local gui = plrGui:WaitForChild("ScreenGui")


local roundGui = gui:WaitForChild("round")
local roundEnd = gui:WaitForChild("roundEnd")
local timerLabel = roundGui:WaitForChild("timer")

local textLabel = roundGui:WaitForChild("text")

timerLabel.Visible = false

local currentTimerThread = nil
local pulseTweenIn
local pulseTweenOut
local pulsing = false

local moves = {}
for i = 1, 4 do
	moves[i] = roundGui:WaitForChild("move" .. i)
end

local locked = false -- prevents double clicks while waiting/messages

local function setMovesVisible(isVisible, maxMove)
	maxMove = maxMove or 4
	for i = 1, 4 do
		moves[i].Visible = isVisible and (i <= maxMove)
	end
end

local function showStatus(text)
	roundGui.Visible = true
	roundEnd.Visible = false
	textLabel.Text = text or ""
	setMovesVisible(false)
end

local function enableMoves(maxMove)
	locked = false
	roundGui.Visible = true
	roundEnd.Visible = false
	textLabel.Text = "Choose your move"
	setMovesVisible(true, maxMove or 4)
end

local function disableMoves()
	setMovesVisible(false)
end

local function playMessages(msgs)
	locked = true
	disableMoves()

	for _, msg in ipairs(msgs) do
		textLabel.Text = msg
		task.wait(2)
	end

	-- DON'T auto set "Choose your move" here.
	-- Server will send EnableMoves or Status next.
end

local function fireMove(moveIndex)
	-- Pick correct RemoteEvent based on mode
	local mode = td.mode.Value

	if mode == "bot" then
		if PlayerMoveBotRE then
			PlayerMoveBotRE:FireServer(moveIndex)
		end
	elseif mode == "player" then
		if PlayerMovePVPRE then
			PlayerMovePVPRE:FireServer(moveIndex)
		end
	end
end

local function startPulse(label)
	if pulsing then return end
	pulsing = true

	label.TextColor3 = Color3.fromRGB(255, 60, 60)

	pulseTweenIn = TweenService:Create(
		label,
		TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0.9, 0, 0.1, 0) }
	)

	pulseTweenOut = TweenService:Create(
		label,
		TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0.9, 0, 0.06, 0) }
	)

	task.spawn(function()
		while pulsing do
			pulseTweenIn:Play()
			pulseTweenIn.Completed:Wait()

			if not pulsing then break end

			pulseTweenOut:Play()
			pulseTweenOut.Completed:Wait()
		end
	end)
end

local function stopPulse(label)
	pulsing = false

	if pulseTweenIn then pulseTweenIn:Cancel() end
	if pulseTweenOut then pulseTweenOut:Cancel() end

	label.Size = UDim2.new(0.9, 0, 0.06, 0)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
end

for i = 1, 4 do
	moves[i].MouseButton1Click:Connect(function()
		if locked then return end
		locked = true
		fireMove(i)
	end)
end

CombatUIRE.OnClientEvent:Connect(function(packet)
	if typeof(packet) ~= "table" then return end

	if packet.action == "Status" then
		-- Used by PVP server for "Waiting for X" and "You are stunned!"
		-- (and you wanted these to show while buttons are hidden)
		showStatus(packet.text)

	elseif packet.action == "Messages" then
		if packet.messages then
			playMessages(packet.messages)
		end

	elseif packet.action == "DisableMoves" then
		locked = true
		disableMoves()

	elseif packet.action == "EnableMoves" then
		enableMoves(packet.maxMove or 4)

	elseif packet.action == "RoundEnd" then
		locked = true
		disableMoves()

		roundGui.Visible = false
		roundEnd.Visible = true
		if roundEnd:FindFirstChild("text") then
			roundEnd:WaitForChild("text").Text = packet.text or "Round ended!"
		end
	elseif packet.action == "ResetUI" then
		locked = false
		roundGui.Visible = false
		roundEnd.Visible = false
		textLabel.Text = "Choose your move"
		setMovesVisible(true, 4)
	elseif packet.action == "TurnTimer" then
		local duration = packet.duration
		timerLabel.Visible = true
		timerLabel.Size = UDim2.new(0.9, 0, 0.06, 0)
		stopPulse(timerLabel)

		if currentTimerThread then
			task.cancel(currentTimerThread)
		end

		currentTimerThread = task.spawn(function()
			for i = duration, 0, -1 do
				timerLabel.Text = tostring(i)

				if i == 3 then
					startPulse(timerLabel)
				end

				task.wait(1)
				
				SoundService.Tick:Play()
			end

			stopPulse(timerLabel)
			timerLabel.Visible = false
		end)
	elseif packet.action == "HideTimer" then
		timerLabel.Visible = false

		stopPulse(timerLabel)

		if currentTimerThread then
			task.cancel(currentTimerThread)
		end
	else
		-- unknown action: safest is lock + hide
		locked = true
		disableMoves()
	end
end)

-- Initial state
roundGui.Visible = false
roundEnd.Visible = false
textLabel.Text = "Choose your move"
setMovesVisible(true, 4)
locked = false