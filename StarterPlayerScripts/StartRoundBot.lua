plr = game.Players.LocalPlayer
rs = game:GetService("ReplicatedStorage")
remoteEvents = rs:WaitForChild("RemoteEvents")
plrGui = plr:WaitForChild("PlayerGui")
local cam = game.Workspace.CurrentCamera

local function cutsceneStart(part)
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = part.CFrame
end

-- Define the NPC and the tool to equip
local tool = rs.WeaponClone:WaitForChild("sword1")

-- Function to equip the tool for an NPC
local function equipTool(npc)
	-- Check if the NPC and tool exist
	if npc and tool then
		-- Clone the tool from ServerStorage to the NPC's character model
		local toolClone = tool:Clone()
		toolClone.Parent = npc

		-- You can also set the tool's handle to be the NPC's right hand for example
		local humanoid = npc:FindFirstChild("Humanoid")
		if humanoid then
			local rightHand = humanoid.Parent:FindFirstChild("Right Hand")
			if rightHand then
				toolClone.Handle:SetJointProperties(rightHand, CFrame.new(), CFrame.new())
			end
		end
	else
		warn("NPC or Tool not found!")
	end
end

remoteEvents.StartRoundBot.OnClientEvent:Connect(function()
	local char = plr.Character or plr.CharacterAdded:Wait()
	
	local tempData = plr:WaitForChild("tempData")
	local roundBase = tempData.roundBase.Value
	local npcPlr = roundBase:WaitForChild('battleground').Player
	local npcBot = roundBase:WaitForChild('battleground').Bot
	
	remoteEvents.mode1:FireServer()
	plrGui.ScreenGui.round.Visible = true

	cutsceneStart(roundBase.PartA)
	remoteEvents.plrClone:FireServer()

	-- Equip the tool for the NPCs
	equipTool(npcBot)
	equipTool(npcPlr)
	
	local hum : Humanoid = char:FindFirstChild("Humanoid")
	if hum then
		hum.WalkSpeed = 0
		hum:MoveTo(roundBase.RoundStepper.hb.Position)
		hum.MoveToFinished:Wait()
	end
end)

