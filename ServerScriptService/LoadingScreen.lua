local tweenService = game:GetService("TweenService")

local rs = game:GetService("ReplicatedStorage")
local constMod = require(rs.Modules.Constants)

game.Players.PlayerAdded:Connect(function(plr)
	local loadingScreen = plr.PlayerGui:WaitForChild("LoadingScreen")
	local frame = loadingScreen.Frame
	local loadingFrame = frame.LoadingFrame
	local progressBar = loadingFrame.ProgressBar
	local playBtn = frame.PlayBtn
	
	for i, v in pairs(plr.PlayerGui:GetChildren()) do
		if v.Name ~= "LoadingScreen" and v:IsA("ScreenGui") then
			v.Enabled = false
		end
	end
	
	frame.Visible = true
	loadingFrame.Visible = true
	progressBar.Visible = true
	
	local function updateProgress()
		local targetSize = UDim2.new(1, 0, 1, 0)

		local tweenInfo = TweenInfo.new(
			constMod.LOADING_TIME - 1, -- Duration in seconds
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.Out
		)

		local tween = tweenService:Create(progressBar, tweenInfo, {Size = targetSize})
		tween:Play()
	end
	
	local function loadingText()
		for i = 1, constMod.LOADING_TIME do
			loadingFrame.TextLabel.Text = "Loading"
			task.wait(.25)
			loadingFrame.TextLabel.Text = "Loading."
			task.wait(.25)
			loadingFrame.TextLabel.Text = "Loading.."
			task.wait(.25)
			loadingFrame.TextLabel.Text = "Loading..."
			task.wait(.25)
		end
	end
	
	local function disappearLoadingFrame()
		local tweenInfo = TweenInfo.new(
			.5, -- Duration in seconds
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.Out
		)

		tweenService:Create(loadingFrame, tweenInfo, {BackgroundTransparency = 1}):Play()
		tweenService:Create(loadingFrame.UIStroke, tweenInfo, {Transparency = 1}):Play()
		tweenService:Create(progressBar, tweenInfo, {BackgroundTransparency = 1}):Play()
		loadingFrame.TextLabel.Visible = false
	end
	
	local function loadPlayBtn()
		local tweenInfo = TweenInfo.new(
			.5, -- Duration in seconds
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.Out
		)
		
		playBtn.Visible = true
		playBtn.Active = true
		tweenService:Create(playBtn, tweenInfo, {BackgroundTransparency = 0}):Play()
		tweenService:Create(playBtn.TextLabel, tweenInfo, {TextTransparency = 0}):Play()
		tweenService:Create(playBtn.UIStroke, tweenInfo, {Transparency = 0}):Play()
		tweenService:Create(playBtn.TextLabel.UIStroke, tweenInfo, {Transparency = 0}):Play()
	end
	
	task.spawn(function()
		updateProgress()
		loadingText()
	end)
	
	task.wait(constMod.LOADING_TIME)
	
	disappearLoadingFrame()
	
	task.wait(1)
	
	playBtn.Visible = true
	playBtn.hover.Enabled = true
	
	loadPlayBtn()
end)