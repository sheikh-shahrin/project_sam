rs = game:GetService("ReplicatedStorage")
remoteEvents = rs:WaitForChild("RemoteEvents")

remoteEvents.mode1.OnServerEvent:connect(function(plr)
	plr.tempData.mode.Value = 'bot'
end)
remoteEvents.mode2.OnServerEvent:connect(function(plr)
	plr.tempData.mode.Value = 'player'
end)