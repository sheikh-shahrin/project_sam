local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Const = require(ReplicatedStorage.Modules.Constants)
local RankMod = require(ReplicatedStorage.Modules.Ranks)

local ServerBindableEvents = ServerScriptService:WaitForChild("ServerBindableEvents")
local startPvpBE = ServerBindableEvents:WaitForChild("StartRoundPvpBE")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local CombatUIRE = remoteEvents:WaitForChild("CombatUI")
local PlayerMovePVPRE = remoteEvents:WaitForChild("PlayerMovePVP")

local TURN_TIME = Const.TURN_TIME
local turnToken = {} -- [base] = { [plr] = number }

local cooldown = {}        -- [plr] = true
local pendingMoves = {}    -- [base] = { [plr] = { move = number, isAuto = boolean } }
local resolving = {}       -- [base] = true/false

local MOVE_NAME = {
	[1] = "Slash",
	[2] = "Block",
	[3] = "Thrust",
	[4] = "DHA",
}

local function ui(plr, packet)
	CombatUIRE:FireClient(plr, packet)
end

-- =========
-- TempData helpers (PVP)
-- =========
-- PVP convention:
-- td.plrHp = your HP
-- td.botHp = opponent HP (mirrored so your existing UI can show "enemy hp")
local function syncOppHp(p1, p2)
	local td1 = p1:FindFirstChild("tempData")
	local td2 = p2:FindFirstChild("tempData")
	if not (td1 and td2) then return end

	td1.botHp.Value = td2.plrHp.Value
	td2.botHp.Value = td1.plrHp.Value
end

local function addHp(plr, delta)
	local td = plr:FindFirstChild("tempData")
	if not td then return end
	td.plrHp.Value = math.max(0, td.plrHp.Value + delta)
end

local function maxMoveFor(plr)
	local td = plr:FindFirstChild("tempData")
	if not td then return 4 end
	return td.plrDha_moveCount.Value and 3 or 4
end

local function resetTempDataForPVP(plr)
	local td = plr:FindFirstChild("tempData")
	if not td then return end

	td.plrHp.Value = 5
	td.botHp.Value = 5

	td.dha_moveCount.Value = false
	td.plrDha_moveCount.Value = false
	td.stun_dhaVsla.Value = false
	td.stun_thrVblk.Value = false

	td.roundBase.Value = nil
	td.mode.Value = ""
end

local function cancelTurnTimer(base, plr)
	turnToken[base] = turnToken[base] or {}
	turnToken[base][plr] = (turnToken[base][plr] or 0) + 1
end

local function startTurnTimer(base, plr)
	if not (base and plr and plr.Parent) then return end

	turnToken[base] = turnToken[base] or {}
	cancelTurnTimer(base, plr)
	local token = turnToken[base][plr]
	
	ui(plr, {
		action = "TurnTimer",
		duration = TURN_TIME
	})

	task.delay(TURN_TIME, function()
		if not (base and base.Parent) then return end
		if not (plr and plr.Parent) then return end
		if not turnToken[base] then return end
		if turnToken[base][plr] ~= token then return end

		local td = plr:FindFirstChild("tempData")
		if not td then return end
		if td.plrHp.Value <= 0 then return end

		-- round ended / base freed
		if base:GetAttribute("taken") ~= true then return end

		local maxMove = td.plrDha_moveCount.Value and 3 or 4
		local autoMove = math.random(1, maxMove)

		processPvpMove(plr, autoMove, true)
	end)
end

-- =========
-- Ending
-- =========
local function clearBase(base)
	if base and base.Parent then
		base:SetAttribute("taken", false)
		base:SetAttribute("p1UserId", 0)
		base:SetAttribute("p2UserId", 0)
	end
end

local function endRoundNoWinner(base, p1, p2, text, plrLeft)
	turnToken[base] = nil

	local tempPlrs = {}

	if p1 then
		table.insert(tempPlrs, p1)
		ui(p1, { action = "RoundEnd", text = text or "Round cancelled.", resetIn = 5 })

		local td1 = p1:FindFirstChild("tempData")
		if td1 then
			if td1.roundBase.Value then
				td1.roundBase.Value = nil
			end
			td1.mode.Value = ""
		end
	end

	if p2 then
		table.insert(tempPlrs, p2)
		ui(p2, { action = "RoundEnd", text = text or "Round cancelled.", resetIn = 5 })

		local td2 = p2:FindFirstChild("tempData")
		if td2 then
			if td2.roundBase.Value then
				td2.roundBase.Value = nil
			end
			td2.mode.Value = ""
		end
	end

	task.delay(5, function()
		clearBase(base)

		for _, plr in ipairs(tempPlrs) do
			if plr and plr.Parent and plr ~= plrLeft then
				resetTempDataForPVP(plr)
				remoteEvents.EndRound:FireClient(plr)
				ui(plr, { action = "ResetUI" })
			end
		end

		pendingMoves[base] = nil
		resolving[base] = nil
	end)
end

local function endRoundWinner(base, p1, p2, winner)
	turnToken[base] = nil

	local text
	if not winner then
		text = "Draw!"
	else
		text = winner.Name .. " wins!"
	end

	if p1 and p1.Parent then
		ui(p1, { action = "RoundEnd", text = text, resetIn = 5 })

		local td1 = p1:FindFirstChild("tempData")
		if td1 then
			if td1.roundBase.Value then
				td1.roundBase.Value = nil
			end
			td1.mode.Value = ""
		end
	end

	if p2 and p2.Parent then
		ui(p2, { action = "RoundEnd", text = text, resetIn = 5 })

		local td2 = p2:FindFirstChild("tempData")
		if td2 then
			if td2.roundBase.Value then
				td2.roundBase.Value = nil
			end
			td2.mode.Value = ""
		end
	end
	
	local loser = (winner == p1) and p2 or p1 

	if winner and winner:FindFirstChild("leaderstats") and winner.leaderstats:FindFirstChild("Wins") then
		winner.leaderstats.Wins.Value += 1
		winner.leaderstats.Coins.Value += Const.HARD_WIN_COINS
		RankMod:ChangeXP(winner, true, RankMod:GetRankConfig().HARD_WIN_XP)
		RankMod:ChangeXP(loser, false, RankMod:GetRankConfig().HARD_LOSE_XP)
	end

	task.delay(5, function()
		clearBase(base)

		for _, plr in ipairs({ p1, p2 }) do
			if plr and plr.Parent then
				resetTempDataForPVP(plr)
				if remoteEvents:FindFirstChild("EndRound") then
					remoteEvents.EndRound:FireClient(plr)
				end
				ui(plr, { action = "ResetUI" })
			end
		end

		pendingMoves[base] = nil
		resolving[base] = nil
	end)
end

-- =========
-- Step system (HP changes aligned to messages)
-- =========
local function makeSteps()
	return {}
end

local function addStep(steps, text, who, delta)
	table.insert(steps, {
		text = text,
		who = who,     -- "p1" or "p2" or nil
		delta = delta, -- number or nil
	})
end

local function applyDelta(p1, p2, who, delta)
	if who == "p1" then
		addHp(p1, delta)
	elseif who == "p2" then
		addHp(p2, delta)
	end
	syncOppHp(p1, p2)
end

local function stepsToTexts(steps)
	local out = {}
	for i, s in ipairs(steps) do
		out[i] = s.text
	end
	return out
end

local function sendStatusWait(pWaiting, otherName)
	ui(pWaiting, { action = "Status", text = "Waiting for " .. otherName })
end

-- =========
-- Turn logic (BOT rules, symmetric)
-- =========

-- Determine who can act now (stun flags live on the stunned player)
local function computeNeed(p1, p2)
	local td1 = p1.tempData
	local td2 = p2.tempData

	local p1Stunned = td1.stun_thrVblk.Value or td1.stun_dhaVsla.Value
	local p2Stunned = td2.stun_thrVblk.Value or td2.stun_dhaVsla.Value

	-- If both somehow stunned, clear both and allow both
	if p1Stunned and p2Stunned then
		td1.stun_thrVblk.Value = false
		td1.stun_dhaVsla.Value = false
		td2.stun_thrVblk.Value = false
		td2.stun_dhaVsla.Value = false
		return true, true
	end

	if p1Stunned then return false, true end
	if p2Stunned then return true, false end
	return true, true
end

local function enableForTurn(p1, p2)
	local need1, need2 = computeNeed(p1, p2)
	local base = p1.tempData.roundBase.Value or p2.tempData.roundBase.Value

	if need1 then
		ui(p1, { action = "Status", text = "Choose your move" }) -- ✅ ADD THIS
		ui(p1, { action = "EnableMoves", maxMove = maxMoveFor(p1) })
		startTurnTimer(base, p1)
	else
		sendStatusWait(p1, p2.Name)
		ui(p1, { action = "DisableMoves" })
	end

	if need2 then
		ui(p2, { action = "Status", text = "Choose your move" }) -- ✅ ADD THIS
		ui(p2, { action = "EnableMoves", maxMove = maxMoveFor(p2) })
		startTurnTimer(base, p2)
	else
		sendStatusWait(p2, p1.Name)
		ui(p2, { action = "DisableMoves" })
	end
end

-- Resolve when BOTH act (main 1v1 interaction):
local function resolveBoth(p1, p2, m1, m2, auto1, auto2)
	local td1 = p1.tempData
	local td2 = p2.tempData

	local steps1 = makeSteps()
	local steps2 = makeSteps()

	-- ✅ Auto-pick messages (only for the player that timed out)
	if auto1 then
		addStep(steps1, "⏳ Time’s up! A move was chosen for you.")
	end
	if auto2 then
		addStep(steps2, "⏳ Time’s up! A move was chosen for you.")
	end
	
	addStep(steps1, ("You used %s!"):format(MOVE_NAME[m1]))
	addStep(steps2, ("You used %s!"):format(MOVE_NAME[m2]))
	
	addStep(steps1, p2.Name .. " used " .. MOVE_NAME[m2] .. "!")
	addStep(steps2, p1.Name .. " used " .. MOVE_NAME[m1] .. "!")

	-- DHA cooldown ends when you use a normal move
	if m1 ~= 4 and td1.plrDha_moveCount.Value then td1.plrDha_moveCount.Value = false end
	if m2 ~= 4 and td2.plrDha_moveCount.Value then td2.plrDha_moveCount.Value = false end

	local d1 = 0 -- delta to p1
	local d2 = 0 -- delta to p2

	local stunP1_Normal = false
	local stunP2_Normal = false
	local stunP1_DHA = false
	local stunP2_DHA = false

	local function slashVsBlock(attackerIsP1)
		if attackerIsP1 then
			d2 += 1
		else
			d1 += 1
		end
	end

	-- P1 move effects
	if m1 == 1 then
		if m2 == 2 then
			slashVsBlock(true)
		elseif m2 == 3 then
			d2 -= 1
		end
	elseif m1 == 2 then
		if m2 == 3 then
			stunP1_Normal = true
		end
	elseif m1 == 3 then
		if m2 == 2 then
			stunP2_Normal = true
		end
	else
		td1.plrDha_moveCount.Value = true
		if m2 == 1 then
			d1 -= 1
			stunP2_DHA = true
		elseif m2 == 2 then
			d2 -= 2
		elseif m2 == 3 then
			d1 -= 1
			stunP2_DHA = true
		end
	end

	-- P2 move effects (mirror)
	if m2 == 1 then
		if m1 == 2 then
			slashVsBlock(false)
		elseif m1 == 3 then
			d1 -= 1
		end
	elseif m2 == 2 then
		if m1 == 3 then
			stunP2_Normal = true
		end
	elseif m2 == 3 then
		if m1 == 2 then
			stunP1_Normal = true
		end
	else
		td2.plrDha_moveCount.Value = true
		if m1 == 1 then
			d2 -= 1
			stunP1_DHA = true
		elseif m1 == 2 then
			d1 -= 2
		elseif m1 == 3 then
			d2 -= 1
			stunP1_DHA = true
		end
	end

	local function addEffectText(viewerSteps, selfPlr, oppPlr, selfDelta, oppDelta, selfKey, oppKey)
		local any = false

		if oppDelta ~= 0 then
			any = true
			local txt = (oppDelta < 0)
				and (("%d HP to %s!"):format(oppDelta, oppPlr.Name))
				or (("+%d HP to %s!"):format(oppDelta, oppPlr.Name))
			addStep(viewerSteps, txt, oppKey, oppDelta)
		end

		if selfDelta ~= 0 then
			any = true
			local txt = (selfDelta < 0)
				and (("%d HP to %s!"):format(selfDelta, selfPlr.Name))
				or (("+%d HP to %s!"):format(selfDelta, selfPlr.Name))
			addStep(viewerSteps, txt, selfKey, selfDelta)
		end

		if not any then
			addStep(viewerSteps, "No effect!")
		end
	end

	addEffectText(steps1, p1, p2, d1, d2, "p1", "p2")
	addEffectText(steps2, p2, p1, d2, d1, "p2", "p1")

	local p1After = td1.plrHp.Value + d1
	local p2After = td2.plrHp.Value + d2
	local canStun = (p1After > 0) and (p2After > 0)

	local p1StunnedNormal = canStun and stunP1_Normal
	local p2StunnedNormal = canStun and stunP2_Normal
	local p1StunnedDha    = canStun and stunP1_DHA
	local p2StunnedDha    = canStun and stunP2_DHA

	if p1StunnedNormal then td1.stun_thrVblk.Value = true end
	if p2StunnedNormal then td2.stun_thrVblk.Value = true end

	if p1StunnedDha then td1.stun_dhaVsla.Value = true end
	if p2StunnedDha then td2.stun_dhaVsla.Value = true end

	if p2StunnedNormal or p2StunnedDha then
		addStep(steps1, p2.Name .. " is stunned!")
		addStep(steps2, "You are stunned!")
	end

	if p1StunnedNormal or p1StunnedDha then
		addStep(steps2, p1.Name .. " is stunned!")
		addStep(steps1, "You are stunned!")
	end

	return steps1, steps2
end

-- =========
-- Disconnect handling: end round no winner
-- =========
local function cancelRoundIfInOne(plr, plrName)
	for _, base in ipairs(workspace:GetDescendants()) do
		if base:IsA("Model") and base:GetAttribute("taken") then
			local p1Id = base:GetAttribute("p1UserId")
			local p2Id = base:GetAttribute("p2UserId")

			if p1Id == plr.UserId or p2Id == plr.UserId then
				local p1 = Players:GetPlayerByUserId(p1Id)
				local p2 = Players:GetPlayerByUserId(p2Id)

				endRoundNoWinner(base, p1, p2, plrName .. " left.", plr)
				return
			end
		end
	end
end

-- =========
-- Round start from handler (server→server via BindableEvent)
-- =========
local function startPvpRound(base, p1, p2)
	if not (base and p1 and p2) then return end
	if not (p1.Parent and p2.Parent) then return end

	p1.tempData.roundBase.Value = base
	p2.tempData.roundBase.Value = base
	p1.tempData.mode.Value = "player"
	p2.tempData.mode.Value = "player"

	for _, plr in ipairs({ p1, p2 }) do
		local td = plr:FindFirstChild("tempData")
		if td then
			td.plrHp.Value = 5
			td.botHp.Value = 5
			td.dha_moveCount.Value = false
			td.plrDha_moveCount.Value = false
			td.stun_dhaVsla.Value = false
			td.stun_thrVblk.Value = false
		end
	end

	ui(p1, { action = "ResetUI" })
	ui(p2, { action = "ResetUI" })

	enableForTurn(p1, p2)
end

function processPvpMove(plr, move, isAuto)
	local td = plr:FindFirstChild("tempData")
	if not td then return end

	local base = td.roundBase.Value
	if not base then return end

	-- ✅ stop the timer for this player (manual or auto)
	ui(plr, { action = "HideTimer" })
	cancelTurnTimer(base, plr)

	if typeof(move) ~= "number" or move < 1 or move > 4 then return end
	if td.mode.Value ~= "player" then return end
	if not base:GetAttribute("taken") then return end

	local p1 = Players:GetPlayerByUserId(base:GetAttribute("p1UserId"))
	local p2 = Players:GetPlayerByUserId(base:GetAttribute("p2UserId"))
	if not (p1 and p2 and p1.Parent and p2.Parent) then
		endRoundNoWinner(base, p1, p2, "Round cancelled.")
		return
	end

	-- Anti-spam (do NOT block server auto-picks)
	if not isAuto then
		if cooldown[plr] then return end
		cooldown[plr] = true
		task.delay(0.25, function() cooldown[plr] = nil end)
	end

	-- Determine who is allowed to act
	local need1, need2 = computeNeed(p1, p2)
	if (plr == p1 and not need1) or (plr == p2 and not need2) then
		local other = (plr == p1) and p2 or p1
		sendStatusWait(plr, other.Name)
		return
	end

	-- DHA cooldown: cannot use DHA if plrDha_moveCount true
	if move == 4 and td.plrDha_moveCount.Value then
		ui(plr, { action = "DisableMoves" })
		ui(plr, { action = "Messages", messages = { "DHA is on cooldown!" } })
		task.delay(2, function()
			if plr and plr.Parent then
				ui(plr, { action = "EnableMoves", maxMove = 3 })
				startTurnTimer(base, plr)
			end
		end)
		return
	end

	-- Save move (+ auto flag)
	if not pendingMoves[base] then pendingMoves[base] = {} end
	pendingMoves[base][plr] = { move = move, isAuto = isAuto }

	ui(plr, { action = "DisableMoves" })

	-- Waiting messages (only when both need to act)
	if need1 and need2 then
		local other = (plr == p1) and p2 or p1
		sendStatusWait(plr, other.Name)
	end

	-- =========
	-- Case A: BOTH act this turn
	-- =========
	if need1 and need2 then
		local p1Entry = pendingMoves[base][p1]
		local p2Entry = pendingMoves[base][p2]

		if not (p1Entry and p2Entry) then
			if p1Entry and not p2Entry then
				sendStatusWait(p1, p2.Name)
			elseif p2Entry and not p1Entry then
				sendStatusWait(p2, p1.Name)
			end
			return
		end

		if resolving[base] then return end
		resolving[base] = true
		pendingMoves[base] = nil

		local m1, m2 = p1Entry.move, p2Entry.move
		local a1, a2 = p1Entry.isAuto, p2Entry.isAuto

		local steps1, steps2 = resolveBoth(p1, p2, m1, m2, a1, a2)

		ui(p1, { action = "Messages", messages = stepsToTexts(steps1) })
		ui(p2, { action = "Messages", messages = stepsToTexts(steps2) })

		for i, s in ipairs(steps1) do
			if s.who and s.delta and s.delta ~= 0 then
				task.delay((i - 1) * 2, function()
					if p1 and p2 and p1.Parent and p2.Parent then
						applyDelta(p1, p2, s.who, s.delta)
					end
				end)
			end
		end

		local duration = math.max(#steps1, #steps2) * 2
		task.delay(duration, function()
			resolving[base] = nil
			if not (p1 and p2 and p1.Parent and p2.Parent) then
				endRoundNoWinner(base, p1, p2, "Round cancelled.")
				return
			end

			syncOppHp(p1, p2)

			local hp1 = p1.tempData.plrHp.Value
			local hp2 = p2.tempData.plrHp.Value

			if hp1 <= 0 and hp2 <= 0 then
				endRoundWinner(base, p1, p2, nil)
				return
			elseif hp1 <= 0 then
				endRoundWinner(base, p1, p2, p2)
				return
			elseif hp2 <= 0 then
				endRoundWinner(base, p1, p2, p1)
				return
			end

			enableForTurn(p1, p2)
		end)

		return
	end

	-- =========
	-- Case B: ONLY ONE acts (other is stunned)
	-- =========
	if resolving[base] then return end
	resolving[base] = true
	pendingMoves[base] = nil

	local attacker = need1 and p1 or p2
	local stunned = need1 and p2 or p1
	local tdA = attacker.tempData
	local tdS = stunned.tempData

	local attackerMove = move
	local stepsA = makeSteps()
	
	local delayTime = 0

	-- ✅ Auto-pick messages for attacker (post-stun single action)
	if isAuto then
		addStep(stepsA, "⏳ Time’s up! A move was chosen for you.")
		delayTime = 1
	end

	addStep(stepsA, "You used " .. MOVE_NAME[attackerMove] .. "!")

	local stepsS = makeSteps()
	addStep(stepsS, "You are stunned!")
	
	local isDHAStun = tdS.stun_dhaVsla.Value
	local isNormalStun = tdS.stun_thrVblk.Value

	if attackerMove ~= 4 and tdA.plrDha_moveCount.Value then
		tdA.plrDha_moveCount.Value = false
	end

	local targetKey = (stunned == p1) and "p1" or "p2"

	if isDHAStun then
		if attackerMove == 1 or attackerMove == 3 then
			addStep(stepsA, "-2 HP to " .. stunned.Name .. "!", targetKey, -2)
		elseif attackerMove == 2 then
			addStep(stepsA, "No effect!")
		else
			addStep(stepsA, "DHA is on cooldown!")
		end
	elseif isNormalStun then
		if attackerMove == 1 then
			addStep(stepsA, "-1 HP to " .. stunned.Name .. "!", targetKey, -1)
		elseif attackerMove == 2 then
			addStep(stepsA, "No effect!")
		elseif attackerMove == 3 then
			addStep(stepsA, "-1 HP to " .. stunned.Name .. "!", targetKey, -1)
		else
			tdA.plrDha_moveCount.Value = true
			addStep(stepsA, "-2 HP to " .. stunned.Name .. "!", targetKey, -2)
		end
	else
		addStep(stepsA, "No effect!")
	end

	ui(attacker, { action = "Messages", messages = stepsToTexts(stepsA) })

	local stunnedMsgs = {  }
	for _, s in ipairs(stepsA) do
		if not string.find(s.text, "Time’s up") then
			if string.find(s.text, "You used") then
				table.insert(stunnedMsgs, attacker.Name .. " used " .. MOVE_NAME[attackerMove] .. "!")
			else
				table.insert(stunnedMsgs, s.text)
			end
		end
	end
	ui(stunned, { action = "Messages", messages = stunnedMsgs })

	for i, s in ipairs(stepsA) do
		if s.who and s.delta and s.delta ~= 0 then
			task.delay((i - 1) * 2 - delayTime, function()
				if p1 and p2 and p1.Parent and p2.Parent then
					applyDelta(p1, p2, s.who, s.delta)
				end
			end)
		end
	end

	task.delay(#stepsA * 2, function()
		resolving[base] = nil
		if not (p1 and p2 and p1.Parent and p2.Parent) then
			endRoundNoWinner(base, p1, p2, "Round cancelled.")
			return
		end

		syncOppHp(p1, p2)

		local hp1 = p1.tempData.plrHp.Value
		local hp2 = p2.tempData.plrHp.Value

		if hp1 <= 0 and hp2 <= 0 then
			endRoundWinner(base, p1, p2, nil)
			return
		elseif hp1 <= 0 then
			endRoundWinner(base, p1, p2, p2)
			return
		elseif hp2 <= 0 then
			endRoundWinner(base, p1, p2, p1)
			return
		end
		
		tdS.stun_dhaVsla.Value = false
		tdS.stun_thrVblk.Value = false

		enableForTurn(p1, p2)
	end)
end

startPvpBE.Event:Connect(function(base, p1, p2)
	startPvpRound(base, p1, p2)
end)

PlayerMovePVPRE.OnServerEvent:Connect(function(plr, move)
	processPvpMove(plr, move, false)
end)

Players.PlayerRemoving:Connect(function(plr)
	cooldown[plr] = nil
	cancelRoundIfInOne(plr, plr.Name)
end)
