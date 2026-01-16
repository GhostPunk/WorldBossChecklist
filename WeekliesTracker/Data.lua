local addonName, addon = ...

-- Valor Points Currency
addon.VALOR_CURRENCY_ID = 396
addon.VALOR_WEEKLY_CAP = 1600  -- Fallback if API fails

-- World Boss definitions for Mists of Pandaria
addon.WORLD_BOSSES = {
    {
        key = "Sha",
        name = "Sha of Anger",
        questID = 32099,
        zone = "Kun-Lai Summit",
        minLevel = 85,
        abbrev = "Sha",
    },
    {
        key = "Galleon",
        name = "Galleon",
        questID = 32098,
        zone = "Valley of the Four Winds",
        minLevel = 85,
        abbrev = "Gal",
    },
    {
        key = "Nalak",
        name = "Nalak",
        questID = 32518,
        zone = "Isle of Thunder",
        minLevel = 90,
        abbrev = "Nal",
    },
    {
        key = "Oondasta",
        name = "Oondasta",
        questID = 32519,
        zone = "Isle of Giants",
        minLevel = 90,
        abbrev = "Oon",
    },
    {
        key = "Celestials",
        name = "Celestials",
        questID = 33117,
        zone = "Timeless Isle",
        minLevel = 90,
        abbrev = "Cel",
    },
    {
        key = "Ordos",
        name = "Ordos",
        questID = 33118,
        zone = "Timeless Isle",
        minLevel = 90,
        abbrev = "Ord",
        note = "Requires Legendary Cloak",
    },
}

-- Create a lookup table by key for quick access
addon.BOSS_BY_KEY = {}
for _, boss in ipairs(addon.WORLD_BOSSES) do
    addon.BOSS_BY_KEY[boss.key] = boss
end

-- Default options
addon.DEFAULT_OPTIONS = {
    showUnkilledOnly = false,
    levelRequirement = 0,
    minimapButton = true,
    frameScale = 1.0,
    locked = false,
    trackBosses = {
        Sha = true,
        Galleon = true,
        Nalak = true,
        Oondasta = true,
        Celestials = true,
        Ordos = true,
    },
    collapsedRealms = {},
    framePosition = nil,
    -- Valor tracking options
    trackValor = true,
    showNotCappedOnly = false,
    mainWindowTab = 1,  -- 1 = Bosses, 2 = Valor
}

-- Atlas icons for kill status
addon.ICON_KILLED = "common-icon-checkmark-yellow"
addon.ICON_NOT_KILLED = "common-icon-redx"

-- Colors
addon.COLORS = {
    HEADER = {1, 0.82, 0},           -- Gold
    REALM = {0.5, 0.5, 0.5},         -- Gray
    KILLED = {0, 1, 0},              -- Green
    NOT_KILLED = {1, 0, 0},          -- Red
    VALOR_CAPPED = {0, 1, 0},        -- Green (capped)
    VALOR_HIGH = {1, 1, 0},          -- Yellow (>=50%)
    VALOR_LOW = {1, 0.5, 0},         -- Orange (<50%)
}
