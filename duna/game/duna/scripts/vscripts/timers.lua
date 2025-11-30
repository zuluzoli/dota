-- Timers library for Dota 2 custom games
if Timers == nil then
	_G.Timers = class({})
end

function Timers:start()
	Timers = self
	self.timers = {}
	
	local ent = SpawnEntityFromTableSynchronous("info_target", {targetname = "timers_lua_thinker"})
	ent:SetThink("Think", self, "timers", 0.01)
end

function Timers:Think()
	if Timers.timers == nil then return end

	local now = GameRules:GetGameTime()
	for k,v in pairs(Timers.timers) do
		local bUseGameTime = v.useGameTime and GameRules:IsGamePaused() == false
		local bUseRealTime = v.useRealTime

		if (bUseGameTime and now >= v.endTime) or (bUseRealTime and Time() >= v.endTime) then
			-- Remove from timers list
			Timers.timers[k] = nil
			
			-- Run the callback
			local status, nextCall
			if v.context then
				status, nextCall = pcall(v.callback, v.context, v)
			else
				status, nextCall = pcall(v.callback, v)
			end

			-- Make sure it worked
			if status then
				-- Check if it needs to loop
				if nextCall then
					-- Change its end time
					if bUseGameTime then
						v.endTime = now + nextCall
					else
						v.endTime = Time() + nextCall
					end
					Timers.timers[k] = v
				end
			else
				-- Handle the error
				print("[TIMERS] Error in timer " .. k .. ": " .. nextCall)
			end
		end
	end

	return 0.01
end

function Timers:CreateTimer(name, args)
	if type(name) == "function" then
		args = {callback = name}
		name = DoUniqueString("timer")
	elseif type(name) == "number" then
		args = {callback = args, endTime = name}
		name = DoUniqueString("timer")
	elseif type(name) == "string" then
		if type(args) == "function" then
			args = {callback = args}
		end
	else
		print("[TIMERS] Invalid timer created: " .. tostring(name))
		return
	end

	local now
	if args.useRealTime then
		now = Time()
	else
		now = GameRules:GetGameTime()
	end

	if args.endTime == nil then
		args.endTime = now
	elseif args.useGameTime then
		args.endTime = now + args.endTime
	elseif args.useRealTime then
		args.endTime = Time() + args.endTime
	end

	Timers.timers[name] = args

	return name
end

function Timers:RemoveTimer(name)
	Timers.timers[name] = nil
end

function Timers:RemoveTimers(killAll)
	local timers = {}

	if not killAll then
		for k,v in pairs(Timers.timers) do
			if v.persist then
				timers[k] = v
			end
		end
	end

	Timers.timers = timers
end

-- Auto-start timers
if Timers.timers == nil then
	Timers:start()
end
