local addonName, addon = ...

-- Print helper
local function Print(msg)
    print("|cff00ff00[WBC]|r " .. msg)
end

-- Print usage help
local function PrintHelp()
    Print("World Boss Checklist Commands:")
    print("  |cffffcc00/wbc|r - Toggle the checklist window")
    print("  |cffffcc00/wbc show|r - Show the window")
    print("  |cffffcc00/wbc hide|r - Hide the window")
    print("  |cffffcc00/wbc config|r - Show current settings")
    print("  |cffffcc00/wbc reset|r - Reset window position")
    print("  |cffffcc00/wbc scale <number>|r - Set UI scale (0.5-2.0)")
    print("  |cffffcc00/wbc lock|r - Toggle frame lock")
    print("  |cffffcc00/wbc unkilled|r - Toggle 'show unkilled only'")
    print("  |cffffcc00/wbc level <number>|r - Set minimum level filter (0 to disable)")
    print("  |cffffcc00/wbc boss <name>|r - Toggle tracking for a boss")
    print("  |cffffcc00/wbc bosses|r - List all bosses and their status")
    print("  |cffffcc00/wbc banned|r - List banned characters")
    print("  |cffffcc00/wbc unban <name-realm>|r - Unban a character")
    print("  |cffffcc00/wbc clear|r - Clear all character data")
end

-- Print current config
local function PrintConfig()
    local opts = addon.db.options
    Print("Current Settings:")
    print("  Show Unkilled Only: " .. (opts.showUnkilledOnly and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    print("  Level Requirement: " .. (opts.levelRequirement > 0 and opts.levelRequirement or "|cff888888Disabled|r"))
    print("  Frame Scale: " .. string.format("%.1f", opts.frameScale))
    print("  Frame Locked: " .. (opts.locked and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    print("  Tracked Bosses:")
    for _, boss in ipairs(addon.WORLD_BOSSES) do
        local status = opts.trackBosses[boss.key] and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"
        print("    " .. boss.name .. ": " .. status)
    end
end

-- List bosses
local function PrintBosses()
    Print("World Bosses:")
    local opts = addon.db.options
    for _, boss in ipairs(addon.WORLD_BOSSES) do
        local status = opts.trackBosses[boss.key] and "|cff00ff00[ON]|r" or "|cffff0000[OFF]|r"
        local note = boss.note and (" |cff888888(" .. boss.note .. ")|r") or ""
        print("  " .. status .. " " .. boss.name .. " - " .. boss.zone .. note)
    end
    print("Use |cffffcc00/wbc boss <name>|r to toggle (e.g., /wbc boss sha)")
end

-- List banned characters
local function PrintBanned()
    local count = 0
    Print("Banned Characters:")
    for fullName, _ in pairs(addon.db.banned) do
        print("  - " .. fullName)
        count = count + 1
    end
    if count == 0 then
        print("  |cff888888No banned characters|r")
    else
        print("Use |cffffcc00/wbc unban <name-realm>|r to unban")
    end
end

-- Toggle boss tracking
local function ToggleBoss(bossName)
    if not bossName or bossName == "" then
        PrintBosses()
        return
    end

    bossName = bossName:lower()

    for _, boss in ipairs(addon.WORLD_BOSSES) do
        if boss.key:lower() == bossName or boss.name:lower():find(bossName) then
            addon.db.options.trackBosses[boss.key] = not addon.db.options.trackBosses[boss.key]
            local status = addon.db.options.trackBosses[boss.key] and "|cff00ff00enabled|r" or "|cffff0000disabled|r"
            Print(boss.name .. " tracking " .. status)
            addon:UpdateUI()
            return
        end
    end

    Print("Unknown boss: " .. bossName)
    PrintBosses()
end

-- Unban a character
local function UnbanCharacter(fullName)
    if not fullName or fullName == "" then
        PrintBanned()
        return
    end

    -- Try exact match first
    if addon.db.banned[fullName] then
        addon:UnbanCharacter(fullName)
        Print("Unbanned: " .. fullName)
        return
    end

    -- Try partial match
    local found = nil
    for bannedName, _ in pairs(addon.db.banned) do
        if bannedName:lower():find(fullName:lower()) then
            if found then
                Print("Multiple matches found. Please be more specific.")
                return
            end
            found = bannedName
        end
    end

    if found then
        addon:UnbanCharacter(found)
        Print("Unbanned: " .. found)
    else
        Print("Character not found in ban list: " .. fullName)
        PrintBanned()
    end
end

-- Clear all data confirmation
StaticPopupDialogs["WBC_CONFIRM_CLEAR"] = {
    text = "Clear ALL character data?\n\nThis cannot be undone!",
    button1 = "Yes, Clear All",
    button2 = "Cancel",
    OnAccept = function()
        addon.db.realms = {}
        addon.db.banned = {}
        addon:UpdateUI()
        Print("All character data cleared.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Slash command handler
local function SlashHandler(msg)
    local args = {}
    for word in msg:gmatch("%S+") do
        table.insert(args, word)
    end

    local cmd = args[1] and args[1]:lower() or ""
    local arg1 = args[2]
    local arg2 = args[3]

    if cmd == "" or cmd == "toggle" then
        addon:ToggleUI()

    elseif cmd == "show" then
        addon:ShowUI()

    elseif cmd == "hide" then
        addon:HideUI()

    elseif cmd == "help" or cmd == "?" then
        PrintHelp()

    elseif cmd == "config" or cmd == "settings" or cmd == "options" then
        PrintConfig()

    elseif cmd == "reset" then
        addon.db.options.framePosition = nil
        if addon.mainFrame then
            addon.mainFrame:ClearAllPoints()
            addon.mainFrame:SetPoint("CENTER")
        end
        Print("Window position reset.")

    elseif cmd == "scale" then
        local scale = tonumber(arg1)
        if scale and scale >= 0.5 and scale <= 2.0 then
            addon.db.options.frameScale = scale
            if addon.mainFrame then
                addon.mainFrame:SetScale(scale)
            end
            Print("Scale set to " .. string.format("%.1f", scale))
        else
            Print("Usage: /wbc scale <0.5-2.0>")
            Print("Current scale: " .. string.format("%.1f", addon.db.options.frameScale))
        end

    elseif cmd == "lock" then
        addon.db.options.locked = not addon.db.options.locked
        Print("Frame " .. (addon.db.options.locked and "locked" or "unlocked"))

    elseif cmd == "unkilled" then
        addon.db.options.showUnkilledOnly = not addon.db.options.showUnkilledOnly
        Print("Show unkilled only: " .. (addon.db.options.showUnkilledOnly and "enabled" or "disabled"))
        addon:UpdateUI()

    elseif cmd == "level" then
        local level = tonumber(arg1)
        if level and level >= 0 and level <= 100 then
            addon.db.options.levelRequirement = level
            if level > 0 then
                Print("Level requirement set to " .. level)
            else
                Print("Level requirement disabled")
            end
            addon:UpdateUI()
        else
            Print("Usage: /wbc level <0-100> (0 to disable)")
            Print("Current: " .. addon.db.options.levelRequirement)
        end

    elseif cmd == "boss" then
        ToggleBoss(arg1)

    elseif cmd == "bosses" then
        PrintBosses()

    elseif cmd == "banned" or cmd == "banlist" then
        PrintBanned()

    elseif cmd == "unban" then
        -- Join remaining args for name-realm
        local fullName = table.concat(args, " ", 2)
        UnbanCharacter(fullName)

    elseif cmd == "clear" then
        StaticPopup_Show("WBC_CONFIRM_CLEAR")

    else
        Print("Unknown command: " .. cmd)
        PrintHelp()
    end
end

-- Register slash commands
function addon:RegisterSlashCommands()
    SLASH_WORLDBOSSCHECKLIST1 = "/wbc"
    SLASH_WORLDBOSSCHECKLIST2 = "/worldboss"
    SLASH_WORLDBOSSCHECKLIST3 = "/worldbosschecklist"
    SlashCmdList["WORLDBOSSCHECKLIST"] = SlashHandler

    Print("Loaded! Type |cffffcc00/wbc|r to toggle the window.")
end
