local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Const = require(ReplicatedStorage.Modules.Constants)
local RankMod = require(ReplicatedStorage.Modules.Ranks)

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local PlayerMoveRE = remoteEvents:WaitForChild("PlayerMoveBot")
local CombatUIRE = remoteEvents:WaitForChild("CombatUI")

local ServerScriptService = game:GetService("ServerScriptService")
local ServerBindableEvents = ServerScriptService:WaitForChild('ServerBindableEvents')
local startBotBE = ServerBindableEvents:WaitForChild("StartRoundBotBE")

local TURN_TIME = Const.TURN_TIME
local turnToken = {} -- [player] = number

local cooldown = {}

local MOVE_NAME = {
	[1] = "Slash",
	[2] = "Block",
	[3] = "Thrust",
	[4] = "DHA",
}

---------------------------------------------------------------------
-- Utility
---------------------------------------------------------------------

local function ui(plr, packet)
	CombatUIRE:FireClient(plr, packet)
end

local function makeSteps()
	return {}
end

local function addStep(steps, text, who, delta)
	table.insert(steps, {
		text = text,
		who = who,
		delta = delta,
	})
end

local function applyHpDelta(td, who, delta)
	if who == "bot" then
		td.botHp.Value = math.max(0, td.botHp.Value + delta)
	elseif who == "plr" then
		td.plrHp.Value = math.max(0, td.plrHp.Value + delta)
	end
end

local function maxMoveFor(td)
	return td.plrDha_moveCount.Value and 3 or 4
end

local function cancelTurnTimer(plr)
	turnToken[plr] = (turnToken[plr] or 0) + 1
end

local function startTurnTimer(plr)
	if not (plr and plr.Parent) then return end
	local td = plr:FindFirstChild("tempData")
	if not td then return end

	cancelTurnTimer(plr)
	local token = turnToken[plr]
	
	ui(plr, { action = "TurnTimer", duration = TURN_TIME })

	task.delay(TURN_TIME, function()
		if not (plr and plr.Parent) then return end
		if turnToken[plr] ~= token then return end

		local td2 = plr:FindFirstChild("tempData")
		if not td2 then return end
		if td2.plrHp.Value <= 0 or td2.botHp.Value <= 0 then return end

		local autoMove = math.random(1, maxMoveFor(td2))
		processBotMove(plr, autoMove, true)
	end)
end

local function startBotRound(plr)
	local td = plr:FindFirstChild("tempData")
	if not td then return end

	-- mark mode + base already set by handler
	td.mode.Value = "bot"

	-- reset state (same as your resetRound values)
	td.botHp.Value = 5
	td.plrHp.Value = 5
	td.dha_moveCount.Value = false
	td.plrDha_moveCount.Value = false
	td.stun_dhaVsla.Value = false
	td.stun_thrVblk.Value = false

	ui(plr, { action = "ResetUI" })

	local maxMove = td.plrDha_moveCount.Value and 3 or 4
	ui(plr, { action = "EnableMoves", maxMove = maxMove })

	startTurnTimer(plr) -- ✅ FIRST TURN TIMER STARTS HERE
end

---------------------------------------------------------------------
-- Round Control
---------------------------------------------------------------------

local function resetRound(plr)
	local td = plr:FindFirstChild("tempData")
	if not td then return end

	td.botHp.Value = 5
	td.plrHp.Value = 5
	td.dha_moveCount.Value = false
	td.plrDha_moveCount.Value = false
	td.stun_dhaVsla.Value = false
	td.stun_thrVblk.Value = false

	ui(plr, { action = "ResetUI" })
end

local function endRound(plr, winnerText, youWin)
	ui(plr, { action = "RoundEnd", text = winnerText, resetIn = 5 })

	task.delay(5, function()
		if plr and plr.Parent then
			resetRound(plr)
			remoteEvents.EndRound:FireClient(plr)
		end
	end)

	if youWin then
		plr.leaderstats.Wins.Value += 1
		plr.leaderstats.Coins.Value += Const.EASY_WIN_COINS
		RankMod:ChangeXP(plr, true, RankMod:GetRankConfig().EASY_WIN_XP)
	else
		RankMod:ChangeXP(plr, false, RankMod:GetRankConfig().EASY_LOSE_XP)
	end

	local td = plr:FindFirstChild("tempData")
	if td then
		if td.roundBase.Value then
			td.roundBase.Value:SetAttribute("taken", false)
			td.roundBase.Value = nil
		end
		td.mode.Value = ""
	end
end

---------------------------------------------------------------------
-- DHA Followups
---------------------------------------------------------------------

-- Player stunned by BOT DHA
local function resolvePlayerStunned_DHA(td)
	local steps = makeSteps()

	local follow = math.random(1, 3)
	addStep(steps, ("Bot used %s!"):format(MOVE_NAME[follow]))

	if follow == 1 or follow == 3 then
		addStep(steps, "-2 HP to self!", "plr", -2)
	else
		addStep(steps, "No effect!")
	end

	return steps
end

-- Bot stunned by PLAYER DHA
local function resolveBotStunned_DHA(plrMove, isAuto)
	local steps = makeSteps()
	
	if isAuto then
		addStep(steps, "⏳ Time’s up! A move was chosen for you.")
		addStep(steps, ("You used %s!"):format(MOVE_NAME[plrMove]))
	end

	if plrMove == 1 or plrMove == 3 then
		addStep(steps, "-2 HP to Bot!", "bot", -2)
	else
		addStep(steps, "No effect!")
	end

	return steps
end

-- Normal stun (Thrust vs Block)
local function resolveBotStunned_Normal(plr, plrMove, isAuto)
	local steps = makeSteps()
	local td = plr:FindFirstChild("tempData")
	
	if isAuto then
		addStep(steps, "⏳ Time’s up! A move was chosen for you.")
		addStep(steps, ("You used %s!"):format(MOVE_NAME[plrMove]))
	end

	if plrMove == 1 or plrMove == 3 then
		addStep(steps, "-1 HP to Bot!", "bot", -1)
	elseif plrMove == 4 then
		td.plrDha_moveCount.Value = true
		addStep(steps, "-2 HP to Bot!", "bot", -2)
	else
		addStep(steps, "No effect!")
	end

	return steps
end

---------------------------------------------------------------------
-- Combat Core
---------------------------------------------------------------------

local function resolveTurn(plr, plrMove, isAuto)
	local td = plr:FindFirstChild("tempData")
	if not td then return nil end

	local steps = makeSteps()
	
	if isAuto then
		addStep(steps, "⏳ Time’s up! A move was chosen for you.")
		addStep(steps, ("You used %s!"):format(MOVE_NAME[plrMove]))
	end

	-----------------------------------------------------------------
	-- Handle stunned state
	-----------------------------------------------------------------

	if td.stun_dhaVsla.Value then
		td.stun_dhaVsla.Value = false
		td.plrDha_moveCount.Value = false
		return resolveBotStunned_DHA(plrMove, isAuto)
	end

	if td.stun_thrVblk.Value then
		td.stun_thrVblk.Value = false
		td.plrDha_moveCount.Value = false
		return resolveBotStunned_Normal(plr, plrMove, isAuto)
	end

	-----------------------------------------------------------------
	-- Normal turn
	-----------------------------------------------------------------

	if plrMove ~= 4 then
		td.plrDha_moveCount.Value = false
	end

	local botMove = td.dha_moveCount.Value and math.random(1,3) or math.random(1,4)
	addStep(steps, ("Bot used %s!"):format(MOVE_NAME[botMove]))

	if botMove ~= 4 then
		td.dha_moveCount.Value = false
	end

	-----------------------------------------------------------------
	-- PLAYER MOVES
	-----------------------------------------------------------------

	if plrMove == 1 then -- Slash

		if botMove == 2 then
			addStep(steps, "+1 HP to Bot!", "bot", 1)

		elseif botMove == 3 then
			addStep(steps, "-1 HP to Bot!", "bot", -1)

		elseif botMove == 4 then
			td.dha_moveCount.Value = true
			addStep(steps, "-1 HP to Bot!", "bot", -1)

			if td.botHp.Value - 1 > 0 then
				addStep(steps, "You are stunned!")
				addStep(steps, "Bot choosing move...")

				local followSteps = resolvePlayerStunned_DHA(td)
				for _, s in ipairs(followSteps) do
					table.insert(steps, s)
				end
			end
		else
			addStep(steps, "No effect!")
		end

	elseif plrMove == 2 then -- Block

		if botMove == 1 then
			addStep(steps, "+1 HP to self!", "plr", 1)

		elseif botMove == 3 then
			addStep(steps, "You are stunned!")
			addStep(steps, "Bot choosing move...")
			
			local maxMove = td.dha_moveCount.Value and 3 or 4

			local follow = math.random(1, maxMove)
			addStep(steps, ("Bot used %s!"):format(MOVE_NAME[follow]))

			if follow == 1 or follow == 3 then
				addStep(steps, "-1 HP to self!", "plr", -1)
			elseif follow == 2 then
				addStep(steps, "No effect!")
			else
				td.dha_moveCount.Value = true
				addStep(steps, "-2 HP to self!", "plr", -2)
			end

		elseif botMove == 4 then
			td.dha_moveCount.Value = true
			addStep(steps, "-2 HP to self!", "plr", -2)

		else
			addStep(steps, "No effect!")
		end

	elseif plrMove == 3 then -- Thrust

		if botMove == 1 then
			addStep(steps, "-1 HP to self!", "plr", -1)

		elseif botMove == 2 then
			addStep(steps, "Bot is stunned!")
			td.stun_thrVblk.Value = true

		elseif botMove == 4 then
			td.dha_moveCount.Value = true
			addStep(steps, "-1 HP to Bot!", "bot", -1)

			if td.botHp.Value - 1 > 0 then
				addStep(steps, "You are stunned!")
				addStep(steps, "Bot choosing move...")

				local followSteps = resolvePlayerStunned_DHA(td)
				for _, s in ipairs(followSteps) do
					table.insert(steps, s)
				end
			end
		else
			addStep(steps, "No effect!")
		end

	else -- PLAYER DHA

		td.plrDha_moveCount.Value = true

		if botMove == 1 or botMove == 3 then
			addStep(steps, "-1 HP to self!", "plr", -1)

			if td.plrHp.Value - 1 > 0 then
				addStep(steps, "Bot is stunned!")
				td.stun_dhaVsla.Value = true
			end

		elseif botMove == 2 then
			addStep(steps, "-2 HP to Bot!", "bot", -2)

		else
			td.dha_moveCount.Value = true
			addStep(steps, "No effect!")
		end
	end

	return steps
end

---------------------------------------------------------------------
-- Remote Handling
---------------------------------------------------------------------

function processBotMove(plr, plrMove, isAuto)
	cancelTurnTimer(plr)
	ui(plr, { action = "HideTimer" })
	
	if typeof(plrMove) ~= "number" then return end
	if plrMove < 1 or plrMove > 4 then return end

	local td = plr:FindFirstChild("tempData")
	if not td or td.mode.Value ~= "bot" then return end

	if plrMove == 4 and td.plrDha_moveCount.Value then
		ui(plr, { action = "DisableMoves" })
		ui(plr, { action = "Messages", messages = { "DHA is on cooldown!" } })

		task.delay(2, function()
			if plr and plr.Parent then
				ui(plr, { action = "EnableMoves", maxMove = 3 })
			end
		end)
		return
	end

	if not isAuto then
		if cooldown[plr] then return end
		cooldown[plr] = true
		task.delay(0.6, function() cooldown[plr] = nil end)
	end

	if td.plrHp.Value <= 0 then
		endRound(plr, "Bot wins!", false)
		return
	end

	if td.botHp.Value <= 0 then
		endRound(plr, plr.Name .. " wins!", true)
		return
	end

	ui(plr, { action = "DisableMoves" })

	local steps = resolveTurn(plr, plrMove, isAuto)
	if not steps then return end

	local texts = {}
	
	for i, s in ipairs(steps) do
		texts[i] = s.text		
	end

	ui(plr, { action = "Messages", messages = texts })

	for i, s in ipairs(steps) do
		if s.who and s.delta and s.delta ~= 0 then
			task.delay((i - 1) * 2, function()
				if plr and plr.Parent then
					local td2 = plr:FindFirstChild("tempData")
					if td2 then
						applyHpDelta(td2, s.who, s.delta)
					end
				end
			end)
		end
	end

	task.delay(#steps * 2, function()
		if not (plr and plr.Parent) then return end
		local td2 = plr:FindFirstChild("tempData")
		if not td2 then return end

		if td2.botHp.Value <= 0 then
			endRound(plr, plr.Name .. " wins!", true)
			return
		end

		if td2.plrHp.Value <= 0 then
			endRound(plr, "Bot wins!", false)
			return
		end

		local maxMove = td2.plrDha_moveCount.Value and 3 or 4
		ui(plr, { action = "EnableMoves", maxMove = maxMove })

		startTurnTimer(plr)
	end)
end

PlayerMoveRE.OnServerEvent:Connect(function(plr, plrMove)
	processBotMove(plr, plrMove, false)
end)

Players.PlayerRemoving:Connect(function(plr)
	cooldown[plr] = nil
	
	local td = plr:FindFirstChild("tempData")
	if td then
		if td.roundBase.Value then
			td.roundBase.Value:SetAttribute("taken", false)
		end
	end
end)

startBotBE.Event:Connect(function(plr)
	if plr and plr.Parent then
		startBotRound(plr)
	end
end)