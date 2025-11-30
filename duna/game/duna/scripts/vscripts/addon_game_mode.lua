-- Generated from template

if CAddonTemplateGameMode == nil then
	CAddonTemplateGameMode = class({})
end

-- Load timers library
require('timers')

-- Limited heroes for specific Steam IDs (64-bit SteamID strings)
-- Example: ["76561198000000000"] = {"npc_dota_hero_axe"}
local LIMITED_HEROES = {
	-- ["76561198000000000"] = {"npc_dota_hero_axe"},
}

-- Hardcoded small pool to bypass KV file during testing
local HARDCODED_SMALL_POOL = {
	"npc_dota_hero_axe",
	"npc_dota_hero_lina",
	"npc_dota_hero_zuus",
	"npc_dota_hero_dazzle",
	"npc_dota_hero_puck",
	"npc_dota_hero_ogre_magi",
}


function Precache( context )
	--[[
		Precache things we know we'll use.  Possible file types include (but not limited to):
			PrecacheResource( "model", "*.vmdl", context )
			PrecacheResource( "soundfile", "*.vsndevts", context )
			PrecacheResource( "particle", "*.vpcf", context )
			PrecacheResource( "particle_folder", "particles/folder", context )
	]]
end

-- Create the game mode when we activate
function Activate()
	GameRules.AddonTemplate = CAddonTemplateGameMode()
	GameRules.AddonTemplate:InitGameMode()
end

function CAddonTemplateGameMode:InitGameMode()
	print( "Template addon is loaded." )
	
	self._allowedPools = {}
	
	-- GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )
	ListenToGameEvent("game_rules_state_change", Dynamic_Wrap(CAddonTemplateGameMode, "OnGameStateChanged"), self)
	ListenToGameEvent("dota_player_pick_hero", Dynamic_Wrap(CAddonTemplateGameMode, "OnPlayerPickHero"), self)
	ListenToGameEvent("player_connect_full", Dynamic_Wrap(CAddonTemplateGameMode, "OnPlayerConnectFull"), self)
	
	-- Set hero selection filters
	-- GameRules:GetGameModeEntity():SetHeroSelectPenaltyTime(0)
	GameRules:SetHeroSelectionTime(90)
	GameRules:SetPreGameTime(5)
	GameRules:SetStrategyTime(0)  -- Skip strategy to enforce faster
	
	-- Use picking filter
	-- GameRules:GetGameModeEntity():SetExecuteOrderFilter(Dynamic_Wrap(CAddonTemplateGameMode, "FilterExecuteOrder"), self)
end

-- Evaluate the state of the game
function CAddonTemplateGameMode:OnThink()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		--print( "Template addon script is running." )
	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	end
	return 1
end

function CAddonTemplateGameMode:OnGameStateChanged()
    local state = GameRules:State_Get()

    if state == DOTA_GAMERULES_STATE_HERO_SELECTION then
        print("[Tisza] Hero selection started - setting hero pools")
        self:SetHeroPools()
        self:LockHeroSelection()
    elseif state == DOTA_GAMERULES_STATE_STRATEGY_TIME then
        print("[Tisza] Strategy time - checking hero pools NOW")
        self:EnforceHeroPoolsOnSpawn()
        -- Check again after a delay to catch late spawns
        Timers:CreateTimer(0.5, function()
            self:EnforceHeroPoolsOnSpawn()
        end)
    elseif state == DOTA_GAMERULES_STATE_PRE_GAME then
        print("[Tisza] Pre-game started - final enforcement")
        self:EnforceHeroPoolsOnSpawn()
    end
end

function CAddonTemplateGameMode:EnforceHeroPoolsOnSpawn()
    -- Check all spawned heroes and replace if not allowed
    for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(playerID) and PlayerResource:HasSelectedHero(playerID) then
            local selectedHeroName = PlayerResource:GetSelectedHeroName(playerID)
            local pool = self._allowedPools[playerID]
            
            print("[Tisza] Checking selected hero for player " .. playerID .. ": " .. tostring(selectedHeroName))
            
            if pool and #pool > 0 and selectedHeroName then
                local allowed = self:IsHeroAllowedForPlayer(playerID, selectedHeroName)
                if not allowed then
                    local replacement = pool[1]
                    print("[Tisza] WRONG HERO SELECTED: " .. selectedHeroName .. " -> spawning " .. replacement .. " instead")
                    
                    -- Get the player entity
                    local player = PlayerResource:GetPlayer(playerID)
                    if player then
                        -- Force spawn the correct hero
                        local hero = PlayerResource:GetSelectedHeroEntity(playerID)
                        if hero and hero:IsAlive() then
                            -- Hero already spawned, kill it and respawn correct one
                            print("[Tisza] Removing wrong hero entity")
                            hero:ForceKill(false)
                        end
                        
                        -- Spawn correct hero
                        print("[Tisza] Creating correct hero: " .. replacement)
                        PrecacheUnitByNameAsync(replacement, function()
                            local newHero = CreateHeroForPlayer(replacement, player)
                            if newHero then
                                newHero:RespawnHero(false, false)
                                print("[Tisza] Successfully spawned " .. replacement)
                            end
                        end)
                    end
                else
                    print("[Tisza] Hero " .. selectedHeroName .. " is ALLOWED for player " .. playerID)
                end
            end
        end
    end
end

function CAddonTemplateGameMode:LockHeroSelection()
	-- Lock hero selection per player using the API
	for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(playerID) then
			local pool = self._allowedPools[playerID]
			if pool and #pool > 0 then
				print("[Tisza] Player " .. playerID .. " locked to pool: " .. table.concat(pool, ", "))
				
				-- Try to set custom hero list for this player (if API exists)
				if PlayerResource.SetCustomHeroList then
					PlayerResource:SetCustomHeroList(playerID, pool)
					print("[Tisza] Set custom hero list for player " .. playerID)
				end
			end
		end
	end
end


function CAddonTemplateGameMode:SetHeroPools()
	for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(playerID) then
			-- Use 64-bit SteamID string for matching
			local steamID64 = PlayerResource:GetSteamID(playerID)
			local assignedHeroes = LIMITED_HEROES[steamID64]

			if assignedHeroes == nil then
				assignedHeroes = self:GetRandomHeroes()
			end

			-- Ensure at least one hero
			if #assignedHeroes == 0 then
				assignedHeroes = {"npc_dota_hero_axe"}  -- Default fallback
			end

			-- Set the pool in net table for Panorama
			CustomNetTables:SetTableValue("hero_pools", tostring(playerID), {heroes = assignedHeroes})
			-- Track for server-side enforcement
			self._allowedPools[playerID] = assignedHeroes

			print("[Tisza] Player " .. tostring(playerID) .. " SteamID64=" .. tostring(steamID64))
			print("[Tisza] Set pool for player " .. playerID .. ": " .. table.concat(assignedHeroes, ", "))
		end
	end
end

function CAddonTemplateGameMode:IsHeroAllowedForPlayer(playerID, heroName)
	local pool = self._allowedPools[playerID]
	if not pool or #pool == 0 then return true end
	for _, h in ipairs(pool) do
		if h == heroName then return true end
	end
	return false
end

function CAddonTemplateGameMode:GetRandomHeroes()
	local allHeroes = {}
	-- Use hardcoded list instead of KV file for this test
	for _, h in ipairs(HARDCODED_SMALL_POOL) do
		table.insert(allHeroes, h)
	end

    -- Pick 3 random unique heroes
    local selected = {}
    local available = {}
    for _, h in ipairs(allHeroes) do
        table.insert(available, h)
    end

    for i = 1, 3 do
        if #available == 0 then break end
        local idx = RandomInt(1, #available)
        table.insert(selected, available[idx])
        table.remove(available, idx)
    end

    return selected
end

function CAddonTemplateGameMode:OnPlayerConnectFull(event)
	local playerID = event.index - 1
	print("[Tisza] Player " .. tostring(playerID) .. " connected, enforcing hero lock")
end

function CAddonTemplateGameMode:FilterExecuteOrder(context, order)
	local playerID = order.issuer_player_id_const
	local orderType = order.order_type
	local abilityIndex = order.entindex_ability
	
	-- Check if this is a hero selection order
	if orderType == DOTA_UNIT_ORDER_CAST_NO_TARGET or orderType == DOTA_UNIT_ORDER_TRAIN_ABILITY then
		if abilityIndex then
			local abilityEntity = EntIndexToHScript(abilityIndex)
			if abilityEntity and abilityEntity:GetAbilityName() then
				local abilityName = abilityEntity:GetAbilityName()
				-- Hero selection abilities are named like the hero
				if string.find(abilityName, "npc_dota_hero_") then
					local heroName = abilityName
					print("[Tisza] FilterExecuteOrder: Player " .. playerID .. " trying to pick " .. heroName)
					
					local pool = self._allowedPools[playerID]
					if pool and #pool > 0 then
						local allowed = self:IsHeroAllowedForPlayer(playerID, heroName)
						if not allowed then
							print("[Tisza] BLOCKED: " .. heroName .. " not in pool for player " .. playerID)
							return false  -- Block the order
						end
					end
				end
			end
		end
	end
	
	return true  -- Allow the order
end

function CAddonTemplateGameMode:OnPlayerPickHero(event)
	-- The event.player might be 1-indexed or might be the wrong mapping
	-- Let's find the actual playerID by checking who picked this hero
	local heroName = event.hero
	
	print("[Tisza] OnPlayerPickHero EVENT - event.player: " .. tostring(event.player) .. " Hero: " .. tostring(heroName))
	
	if heroName == nil then 
		print("[Tisza] Missing heroName")
		return 
	end
	
	-- Find which player actually picked this hero
	local actualPlayerID = nil
	for pid = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(pid) then
			local selectedHero = PlayerResource:GetSelectedHeroName(pid)
			print("[Tisza] Checking player " .. pid .. " selected hero: " .. tostring(selectedHero))
			if selectedHero == heroName then
				actualPlayerID = pid
				break
			end
		end
	end
	
	if actualPlayerID == nil then
		print("[Tisza] Could not find player who picked " .. heroName)
		return
	end
	
	print("[Tisza] Found actual playerID: " .. actualPlayerID .. " for hero: " .. heroName)

	local pool = self._allowedPools[actualPlayerID]
	if not pool or #pool == 0 then 
		print("[Tisza] No pool found for player " .. tostring(actualPlayerID))
		return 
	end

	local allowed = self:IsHeroAllowedForPlayer(actualPlayerID, heroName)
	print("[Tisza] Hero " .. tostring(heroName) .. " is " .. (allowed and "ALLOWED" or "BLOCKED") .. " for player " .. tostring(actualPlayerID))

	if not allowed then
		-- Immediate replacement
		local replacement = pool[1]
		print("[Tisza] ENFORCING IMMEDIATELY: Replacing " .. tostring(heroName) .. " with " .. tostring(replacement))
		PlayerResource:ReplaceHeroWith(actualPlayerID, replacement, 0, 0)
	end
end

function CAddonTemplateGameMode:OnHeroPoolSelect(data)
	local playerID = data.PlayerID
	local heroName = data.hero
	if playerID == nil or heroName == nil then return end
	if not self:IsHeroAllowedForPlayer(playerID, heroName) then return end

	local player = PlayerResource:GetPlayer(playerID)
	if not player then return end
	local current = player:GetAssignedHero()
	if not current then return end

	print("[Tisza] Player " .. tostring(playerID) .. " selected " .. tostring(heroName) .. " from pool")
	local newHero = PlayerResource:ReplaceHeroWith(playerID, heroName, current:GetGold(), current:GetXP())
	if newHero then
		UTIL_Remove(current)
	end
end