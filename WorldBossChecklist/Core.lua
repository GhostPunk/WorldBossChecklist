local addonName, addon = ...

-- Create main addon frame for events
local frame = CreateFrame("Frame")
addon.frame = frame

-- Initialize database
local function InitializeDB()
    if not WorldBossChecklistDB then
        WorldBossChecklistDB = {}
    end

    local db = WorldBossChecklistDB

    -- Initialize realms table
    if not db.realms then
        db.realms = {}
    end

    -- Initialize banned table
    if not db.banned then
        db.banned = {}
    end

    -- Initialize options with defaults
    if not db.options then
        db.options = {}
    end

    for key, value in pairs(addon.DEFAULT_OPTIONS) do
        if db.options[key] == nil then
            if type(value) == "table" then
                db.options[key] = {}
                for k, v in pairs(value) do
                    db.options[key][k] = v
                end
            else
                db.options[key] = value
            end
        end
    end

    -- Ensure trackBosses has all bosses
    for _, boss in ipairs(addon.WORLD_BOSSES) do
        if db.options.trackBosses[boss.key] == nil then
            db.options.trackBosses[boss.key] = true
        end
    end

    addon.db = db
end

-- Check if a quest is completed (boss killed this week)
function addon:IsQuestDone(questID)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(questID) == true
    elseif IsQuestFlaggedCompleted then
        return IsQuestFlaggedCompleted(questID) == true
    end
    return false
end

-- Get the next weekly reset time
function addon:GetWeeklyResetTime()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local secs = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if type(secs) == "number" and secs > 0 then
            return GetServerTime() + secs
        end
    end
    -- Fallback: estimate next Tuesday 7am (varies by region)
    return nil
end

-- Check and handle weekly reset
function addon:CheckWeeklyReset()
    local now = GetServerTime()
    local nextReset = self:GetWeeklyResetTime()

    -- First time setup
    if not self.db.nextResetTime then
        self.db.nextResetTime = nextReset
        return
    end

    -- Check if we've passed the reset time
    if now >= self.db.nextResetTime then
        self:ResetAllBossKills()
        self.db.nextResetTime = nextReset or (now + 7 * 24 * 60 * 60)
    end
end

-- Reset all boss kills for all characters
function addon:ResetAllBossKills()
    for realmName, characters in pairs(self.db.realms) do
        for charName, charData in pairs(characters) do
            if charData.bosses then
                for bossKey in pairs(charData.bosses) do
                    charData.bosses[bossKey] = false
                end
            end
        end
    end
end

-- Get current character info
function addon:GetCurrentCharacterInfo()
    local name = UnitName("player")
    local realm = GetRealmName()
    local _, class = UnitClass("player")
    local level = UnitLevel("player")

    return {
        name = name,
        realm = realm,
        class = class,
        level = level,
        fullName = name .. "-" .. realm,
    }
end

-- Check if character is banned
function addon:IsCharacterBanned(fullName)
    return self.db.banned[fullName] == true
end

-- Ban a character
function addon:BanCharacter(fullName)
    self.db.banned[fullName] = true
    -- Also remove from realms data
    local name, realm = strsplit("-", fullName)
    if self.db.realms[realm] and self.db.realms[realm][name] then
        self.db.realms[realm][name] = nil
        -- Clean up empty realm
        if next(self.db.realms[realm]) == nil then
            self.db.realms[realm] = nil
        end
    end
end

-- Unban a character
function addon:UnbanCharacter(fullName)
    self.db.banned[fullName] = nil
end

-- Delete a character (without banning)
function addon:DeleteCharacter(fullName)
    local name, realm = strsplit("-", fullName)
    if self.db.realms[realm] and self.db.realms[realm][name] then
        self.db.realms[realm][name] = nil
        -- Clean up empty realm
        if next(self.db.realms[realm]) == nil then
            self.db.realms[realm] = nil
        end
    end
end

-- Update current character's data
function addon:UpdateCurrentCharacter()
    local info = self:GetCurrentCharacterInfo()

    -- Check if banned
    if self:IsCharacterBanned(info.fullName) then
        return
    end

    -- Ensure realm exists
    if not self.db.realms[info.realm] then
        self.db.realms[info.realm] = {}
    end

    -- Ensure character exists
    if not self.db.realms[info.realm][info.name] then
        self.db.realms[info.realm][info.name] = {
            name = info.name,
            class = info.class,
            level = info.level,
            bosses = {},
        }
    end

    local charData = self.db.realms[info.realm][info.name]

    -- Update basic info
    charData.class = info.class
    charData.level = info.level
    charData.lastSeen = GetServerTime()

    -- Update boss kill status
    for _, boss in ipairs(addon.WORLD_BOSSES) do
        charData.bosses[boss.key] = self:IsQuestDone(boss.questID)
    end
end

-- Get all characters sorted by realm
function addon:GetAllCharacters()
    local result = {}

    for realmName, characters in pairs(self.db.realms) do
        local realmData = {
            name = realmName,
            characters = {},
        }

        for charName, charData in pairs(characters) do
            table.insert(realmData.characters, {
                name = charName,
                realm = realmName,
                fullName = charName .. "-" .. realmName,
                class = charData.class,
                level = charData.level,
                lastSeen = charData.lastSeen,
                bosses = charData.bosses or {},
            })
        end

        -- Sort characters by name
        table.sort(realmData.characters, function(a, b)
            return a.name < b.name
        end)

        if #realmData.characters > 0 then
            table.insert(result, realmData)
        end
    end

    -- Sort realms by name
    table.sort(result, function(a, b)
        return a.name < b.name
    end)

    return result
end

-- Check if character should be shown based on filters
function addon:ShouldShowCharacter(charData)
    local opts = self.db.options

    -- Check level requirement
    if opts.levelRequirement and opts.levelRequirement > 0 then
        if (charData.level or 0) < opts.levelRequirement then
            return false
        end
    end

    -- Check "show unkilled only" option
    if opts.showUnkilledOnly then
        local allKilled = true
        for _, boss in ipairs(addon.WORLD_BOSSES) do
            if opts.trackBosses[boss.key] then
                if not charData.bosses[boss.key] then
                    allKilled = false
                    break
                end
            end
        end
        if allKilled then
            return false
        end
    end

    return true
end

-- Get enabled bosses
function addon:GetEnabledBosses()
    local result = {}
    for _, boss in ipairs(addon.WORLD_BOSSES) do
        if self.db.options.trackBosses[boss.key] then
            table.insert(result, boss)
        end
    end
    return result
end

-- Event handler
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            InitializeDB()
            addon:CheckWeeklyReset()
            addon:UpdateCurrentCharacter()

            -- Initialize UI after a short delay to ensure everything is loaded
            C_Timer.After(0.5, function()
                if addon.InitializeUI then
                    addon:InitializeUI()
                end
                if addon.RegisterSlashCommands then
                    addon:RegisterSlashCommands()
                end
            end)

            self:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        addon:CheckWeeklyReset()
        addon:UpdateCurrentCharacter()
        if addon.UpdateUI then
            addon:UpdateUI()
        end

    elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_TURNED_IN" then
        -- Quest status may have changed (boss kill)
        addon:UpdateCurrentCharacter()
        if addon.UpdateUI then
            addon:UpdateUI()
        end
    end
end)

-- Register events
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("QUEST_TURNED_IN")
