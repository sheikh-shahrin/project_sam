plr = game.Players.LocalPlayer
rs = game:GetService("ReplicatedStorage")
remoteEvents = rs:WaitForChild("RemoteEvents")
plrGui = plr:WaitForChild("PlayerGui")

local function cutsceneEnd() 
	local cam = game.Workspace.CurrentCamera 
	local char : Model = plr.Character or plr.CharacterAdded:Wait() 
	local hum = char:FindFirstChild("Humanoid") 
	if hum then 
		hum.WalkSpeed = 16 
		cam.CameraType = Enum.CameraType.Custom 
		cam.CameraSubject = hum 
	end 
end

remoteEvents.EndRound.OnClientEvent:Connect(function()
	cutsceneEnd()
	
	local char = plr.Character or plr.CharacterAdded:Wait()
	
	local hum : Humanoid = char:FindFirstChild("Humanoid")
	if hum then
		hum.WalkSpeed = 16
	end
end)