local addonName, addon = ...

-- Create main addon frame for events
local frame = CreateFrame("Frame")
addon.frame = frame

-- Migrate from old WorldBossChecklistDB to WeekliesTrackerDB
local function MigrateDB()
    if WorldBossChecklistDB and not WeekliesTrackerDB then
        -- Copy old data to new DB
        WeekliesTrackerDB = {}
        for key, value in pairs(WorldBossChecklistDB) do
            if type(value) == "table" then
                WeekliesTrackerDB[key] = {}
                for k, v in pairs(value) do
                    if type(v) == "table" then
                        WeekliesTrackerDB[key][k] = {}
                        for k2, v2 in pairs(v) do
                            WeekliesTrackerDB[key][k][k2] = v2
                        end
                    else
                        WeekliesTrackerDB[key][k] = v
                    end
                end
            else
                WeekliesTrackerDB[key] = value
            end
        end
        -- Mark as migrated
        WeekliesTrackerDB.migratedFrom = "WorldBossChecklistDB"
        WeekliesTrackerDB.migratedAt = GetServerTime()
    end
end

-- Reset bad valor data from previous versions
local function ResetBadValorData(db)
    -- Use version-specific flag so we can run new migrations
    if db.valorDataResetV206 then return end  -- Already done

    -- Reset all characters' valor data to start fresh
    if db.realms then
        for realmName, characters in pairs(db.realms) do
            for charName, charData in pairs(characters) do
                -- Reset valor to clean state
                -- weekStartTotal = nil means TrackValorChange will set it on first call
                charData.valor = {
                    current = 0,
                    earnedThisWeek = 0,
                    weeklyMax = addon.VALOR_WEEKLY_CAP,
                    weekStartTotal = nil,  -- Will be set on first CURRENCY_DISPLAY_UPDATE
                }
            end
        end
    end

    db.valorDataResetV206 = true
end

-- Initialize database
local function InitializeDB()
    -- Migrate from old DB if needed
    MigrateDB()

    if not WeekliesTrackerDB then
        WeekliesTrackerDB = {}
    end

    local db = WeekliesTrackerDB

    -- Initialize realms table
    if not db.realms then
        db.realms = {}
    end

    -- Initialize banned table
    if not db.banned then
        db.banned = {}
    end

    -- Reset bad valor data from earlier versions
    ResetBadValorData(db)

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

-- Get valor point information from the currency API
function addon:GetValorInfo()
    local current = 0
    local earnedThisWeek = 0
    local weeklyMax = 0
    local totalMax = 3000

    -- Try C_CurrencyInfo API (MoP Classic uses this)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(addon.VALOR_CURRENCY_ID)
        if info then
            current = info.quantity or 0
            -- In MoP Classic, weekly tracking fields may vary
            -- Try different possible field names
            earnedThisWeek = info.quantityEarnedThisWeek or info.totalEarnedThisWeek or 0
            weeklyMax = info.maxWeeklyQuantity or info.weeklyMax or 0
            totalMax = info.maxQuantity or info.totalMax or 3000
        end
    end

    -- Fallback to older GetCurrencyInfo API if C_CurrencyInfo didn't work
    if current == 0 and GetCurrencyInfo then
        local name, amount, texture, week, wmax, tmax, isDiscovered = GetCurrencyInfo(addon.VALOR_CURRENCY_ID)
        if name and amount then
            current = amount
            earnedThisWeek = week or 0
            weeklyMax = wmax or 0
            totalMax = tmax or 3000
        end
    end

    -- Always use fallback cap if API returns 0
    if weeklyMax == 0 or weeklyMax == nil then
        weeklyMax = addon.VALOR_WEEKLY_CAP
    end

    -- If earnedThisWeek seems unreasonably high (>weekly cap), it's probably wrong data
    -- In this case, we'll need to track it ourselves
    if earnedThisWeek > weeklyMax then
        -- The API might be returning lifetime earned or something else
        -- Use stored value if we have one, otherwise start fresh
        earnedThisWeek = self:GetStoredWeeklyValor() or 0
    end

    return {
        current = current,
        earnedThisWeek = earnedThisWeek,
        weeklyMax = weeklyMax,
        totalMax = totalMax,
    }
end

-- Get stored weekly valor for current character (for manual tracking)
function addon:GetStoredWeeklyValor()
    local info = self:GetCurrentCharacterInfo()
    if self.db.realms[info.realm] and self.db.realms[info.realm][info.name] then
        local charData = self.db.realms[info.realm][info.name]
        if charData.valor then
            return charData.valor.earnedThisWeek
        end
    end
    return nil
end

-- Track valor using totalEarned (lifetime earned, never decreases)
-- This is much simpler than tracking deltas!
function addon:TrackValorChange()
    local info = self:GetCurrentCharacterInfo()
    if self:IsCharacterBanned(info.fullName) then return end
    if not self.db.realms[info.realm] then return end
    if not self.db.realms[info.realm][info.name] then return end

    local charData = self.db.realms[info.realm][info.name]

    -- Ensure valor table exists
    if not charData.valor then
        charData.valor = {
            current = 0,
            earnedThisWeek = 0,
            weeklyMax = addon.VALOR_WEEKLY_CAP,
        }
    end

    -- Get totalEarned from API (lifetime earned, never decreases even when spent)
    local totalEarned = 0
    local currentValor = 0
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local currInfo = C_CurrencyInfo.GetCurrencyInfo(addon.VALOR_CURRENCY_ID)
        if currInfo then
            totalEarned = currInfo.totalEarned or 0
            currentValor = currInfo.quantity or 0
        end
    end

    -- Update display value (current balance)
    charData.valor.current = currentValor
    charData.valor.weeklyMax = addon.VALOR_WEEKLY_CAP

    -- weekStartTotal = totalEarned at the start of the week
    -- If not set, this is first time seeing this character this week
    if not charData.valor.weekStartTotal then
        charData.valor.weekStartTotal = totalEarned
    end

    -- earnedThisWeek = how much totalEarned increased since week start
    local earned = totalEarned - charData.valor.weekStartTotal
    if earned < 0 then earned = 0 end
    charData.valor.earnedThisWeek = earned
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
        self:ResetAllValor()
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

-- Reset all valor earnedThisWeek for all characters (on weekly reset)
function addon:ResetAllValor()
    for realmName, characters in pairs(self.db.realms) do
        for charName, charData in pairs(characters) do
            if charData.valor then
                charData.valor.earnedThisWeek = 0
                charData.valor.weekStartTotal = nil  -- Will be set on next CURRENCY_DISPLAY_UPDATE
            end
        end
    end
end

-- Get the next daily reset time
function addon:GetDailyResetTime()
    local secs = GetQuestResetTime()
    if type(secs) == "number" and secs > 0 then
        return GetServerTime() + secs
    end
    return nil
end

-- Check and handle daily reset
function addon:CheckDailyReset()
    local now = GetServerTime()
    local nextReset = self:GetDailyResetTime()

    -- First time setup
    if not self.db.nextDailyResetTime then
        self.db.nextDailyResetTime = nextReset
        return
    end

    -- Check if we've passed the reset time
    if now >= self.db.nextDailyResetTime then
        self:ResetAllDailies()
        self.db.nextDailyResetTime = nextReset or (now + 24 * 60 * 60)
    end
end

-- Reset all daily dungeon completions for all characters
function addon:ResetAllDailies()
    for realmName, characters in pairs(self.db.realms) do
        for charName, charData in pairs(characters) do
            if charData.dailies then
                charData.dailies = {}
            end
        end
    end
end

-- Update current character's daily dungeon status
function addon:UpdateCurrentCharacterDailies()
    local info = self:GetCurrentCharacterInfo()

    if self:IsCharacterBanned(info.fullName) then return end
    if not self.db.realms[info.realm] then return end
    if not self.db.realms[info.realm][info.name] then return end

    local charData = self.db.realms[info.realm][info.name]

    if not charData.dailies then
        charData.dailies = {}
    end

    -- Check each daily dungeon quest (first random of the day)
    for _, dungeon in ipairs(addon.DAILY_DUNGEONS) do
        charData.dailies[dungeon.key] = self:IsQuestDone(dungeon.questID)
    end
end

-- Get max valor earnable this week (account-wide)
function addon:GetMaxValorThisWeek()
    local currInfo = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(addon.VALOR_CURRENCY_ID)
    if not currInfo then return 0 end

    local maxQuantity = currInfo.maxQuantity or 0  -- Total cap (increases weekly)
    local totalEarned = currInfo.totalEarned or 0
    local quantity = currInfo.quantity or 0

    -- How much more you can earn + current balance
    return (maxQuantity - totalEarned) + quantity
end

-- Get seconds until daily reset (for display)
function addon:GetSecondsUntilDailyReset()
    local secs = GetQuestResetTime()
    if type(secs) == "number" and secs > 0 then
        return secs
    end
    return 0
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

-- Update current character's valor data
-- This just ensures the valor table exists - actual tracking is done by TrackValorChange()
function addon:UpdateCurrentCharacterValor()
    local info = self:GetCurrentCharacterInfo()

    -- Check if banned
    if self:IsCharacterBanned(info.fullName) then
        return
    end

    -- Ensure realm and character exist
    if not self.db.realms[info.realm] then return end
    if not self.db.realms[info.realm][info.name] then return end

    local charData = self.db.realms[info.realm][info.name]

    -- Initialize valor table if it doesn't exist
    if not charData.valor then
        charData.valor = {
            current = 0,
            earnedThisWeek = 0,
            weeklyMax = addon.VALOR_WEEKLY_CAP,
            weekStartTotal = nil,  -- Will be set by TrackValorChange()
        }
    end

    -- Ensure weeklyMax is set (for UI display)
    charData.valor.weeklyMax = addon.VALOR_WEEKLY_CAP
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
            valor = {
                current = 0,
                earnedThisWeek = 0,
                weeklyMax = addon.VALOR_WEEKLY_CAP,
                weekStartTotal = nil,  -- Will be set by TrackValorChange()
            },
            dailies = {},
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

    -- Update valor info
    self:UpdateCurrentCharacterValor()

    -- Update daily dungeon status
    self:UpdateCurrentCharacterDailies()
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
                valor = charData.valor or {},
                dailies = charData.dailies or {},
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

-- Check if character should be shown based on filters (for bosses tab)
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

-- Check if character should be shown in valor tab based on filters
function addon:ShouldShowCharacterValor(charData)
    local opts = self.db.options

    -- Check level requirement (valor typically requires level 90)
    if opts.levelRequirement and opts.levelRequirement > 0 then
        if (charData.level or 0) < opts.levelRequirement then
            return false
        end
    end

    -- Check "show not capped only" option
    if opts.showNotCappedOnly then
        local valor = charData.valor or {}
        local earned = valor.earnedThisWeek or 0
        local max = (valor.weeklyMax and valor.weeklyMax > 0) and valor.weeklyMax or addon.VALOR_WEEKLY_CAP
        if earned >= max then
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
            addon:CheckDailyReset()
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
        addon:CheckDailyReset()
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

    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        -- Valor points may have changed - use manual tracking
        addon:TrackValorChange()
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
frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
