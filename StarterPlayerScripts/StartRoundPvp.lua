local plr = game.Players.LocalPlayer
local rs = game:GetService("ReplicatedStorage")
local remoteEvents = rs:WaitForChild("RemoteEvents")

local plrGui = plr:WaitForChild("PlayerGui")
local cam = workspace.CurrentCamera

local function cutsceneStart(part)
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = part.CFrame
end

remoteEvents.StartRoundPVP.OnClientEvent:Connect(function()
	local char = plr.Character or plr.CharacterAdded:Wait()
	local td = plr:WaitForChild("tempData")

	local roundBase = td.roundBase.Value
	if not roundBase then return end

	remoteEvents.mode2:FireServer()

	plrGui.ScreenGui.round.Visible = true
	cutsceneStart(roundBase.PartA)
	remoteEvents.PVPClone:FireServer()

	local hum = char:FindFirstChild("Humanoid")
	if hum then
		hum.WalkSpeed = 0
		hum:MoveTo(roundBase.RoundStepper.hb.Position)
		hum.MoveToFinished:Wait()
	end
end)