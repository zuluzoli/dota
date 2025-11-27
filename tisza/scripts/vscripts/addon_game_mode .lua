if GameMode == nil then
    GameMode = class({})
end

function Activate()
    print("Hello World from Tisza!")
    GameRules.GameMode = GameMode()
    GameRules.GameMode:InitGameMode()
end

function GameMode:InitGameMode()
    ListenToGameEvent("game_rules_state_change", Dynamic_Wrap(GameMode, "OnGameStateChanged"), self)
end

-- Egyedi játékosok, akik limitált hőst kapnak
local LIMITED_HEROES = {
    -- SteamAccountID : 3 hős listája
    [123456789] = {"npc_dota_hero_chen", "npc_dota_hero_puck", "npc_dota_hero_dazzle"},
}

function GameMode:OnGameStateChanged()
    local state = GameRules:State_Get()

    if state == DOTA_GAMERULES_STATE_HERO_SELECTION then
        print("[Tisza] Hero selection started")
        self:AssignHeroes()
    end
end

function GameMode:AssignHeroes()
    for playerID = 0, DOTA_MAX_TEAM_PLAYERS-1 do
        if PlayerResource:IsValidPlayerID(playerID) then

            local steamID = PlayerResource:GetSteamAccountID(playerID)
            local heroes = LIMITED_HEROES[steamID]

            if heroes == nil then
                heroes = self:GetRandomThreeHeroes()
            end

            local chosenHero = heroes[1]     -- az első lesz kiosztva
            print("[Tisza] Assigning hero to P"..playerID..": "..chosenHero)

            -- 0.5 sec késés, hogy engine készen legyen
            Timers:CreateTimer(0.5, function()
                self:ForcePick(playerID, chosenHero)
            end)
        end
    end
end

function GameMode:ForcePick(playerID, heroName)
    local player = PlayerResource:GetPlayer(playerID)
    if player then
        player:MakeRandomHeroSelection()     -- workaround hogy a slot aktiválva legyen
        PlayerResource:ReplaceHeroWith(playerID, heroName, 0, 0)
    end
end

function GameMode:GetRandomThreeHeroes()
    local allHeroes = {}

    local heroKV = LoadKeyValues("scripts/npc/npc_heroes.txt")
    for hero, data in pairs(heroKV) do
        if type(data) == "table" and data.Role then
            table.insert(allHeroes, hero)
        end
    end

    local pool = {}
    local copy = {}
    for _, h in ipairs(allHeroes) do table.insert(copy, h) end

    for i=1,3 do
        local idx = RandomInt(1, #copy)
        table.insert(pool, copy[idx])
        table.remove(copy, idx)
    end

    return pool
end
