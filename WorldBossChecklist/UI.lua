local addonName, addon = ...

local FRAME_WIDTH = 400
local FRAME_MIN_HEIGHT = 60
local ROW_HEIGHT = 18
local HEADER_HEIGHT = 24
local BOSS_COLUMN_WIDTH = 35
local NAME_COLUMN_WIDTH = 150

-- Main frame
local mainFrame = nil
local contentFrame = nil
local scrollFrame = nil
local rows = {}
local contextMenu = nil

-- Create atlas icon string
local function AtlasIcon(name, size)
    size = size or 14
    return string.format("|A:%s:%d:%d|a", name, size, size)
end

-- Get class color
local function GetClassColor(class)
    if class and RAID_CLASS_COLORS[class] then
        return RAID_CLASS_COLORS[class]
    end
    return {r = 1, g = 1, b = 1}
end

-- Create the main frame
local function CreateMainFrame()
    local frame = CreateFrame("Frame", "WorldBossChecklistFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, 300)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("MEDIUM")
    frame:EnableMouse(true)

    -- Backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    frame:SetBackdropBorderColor(0, 0, 0, 1)

    -- Make draggable
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not addon.db.options.locked then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, relPoint, x, y = self:GetPoint()
        addon.db.options.framePosition = {point, relPoint, x, y}
    end)

    -- Header
    local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    header:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    frame.header = header

    -- Title
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", header, "LEFT", 8, 0)
    title:SetText("World Boss Checklist")
    title:SetTextColor(1, 0.82, 0)
    frame.title = title

    -- Close button
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
    closeBtn:GetHighlightTexture():SetVertexColor(1, 0, 0)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)
    frame.closeBtn = closeBtn

    -- Scroll frame container
    local scrollContainer = CreateFrame("Frame", nil, frame)
    scrollContainer:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    scrollContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.scrollContainer = scrollContainer

    -- Scroll frame
    local scroll = CreateFrame("ScrollFrame", "WorldBossChecklistScrollFrame", scrollContainer, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", -24, 4)
    frame.scrollFrame = scroll

    -- Content frame (inside scroll)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(FRAME_WIDTH - 28, 100)
    scroll:SetScrollChild(content)
    frame.contentFrame = content

    -- Hide scroll bar when not needed
    local scrollBar = scroll.ScrollBar or _G["WorldBossChecklistScrollFrameScrollBar"]
    if scrollBar then
        scrollBar:SetValue(0)
    end

    return frame
end

-- Create a realm header row
local function CreateRealmHeader(parent, realmName, yOffset)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)

    -- Background
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.2, 0.2, 0.2, 0.5)

    -- Expand/collapse indicator
    row.indicator = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.indicator:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.indicator:SetText("+")
    row.indicator:SetTextColor(0.7, 0.7, 0.7)

    -- Realm name
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.text:SetPoint("LEFT", row.indicator, "RIGHT", 4, 0)
    row.text:SetText(realmName)
    row.text:SetTextColor(0.6, 0.6, 0.6)

    row.realmName = realmName
    row.isRealmHeader = true

    -- Click to toggle
    row:SetScript("OnClick", function(self)
        local collapsed = addon.db.options.collapsedRealms[realmName]
        addon.db.options.collapsedRealms[realmName] = not collapsed
        addon:UpdateUI()
    end)

    -- Highlight
    row:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    end)
    row:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.2, 0.2, 0.2, 0.5)
    end)

    return row
end

-- Create a character row
local function CreateCharacterRow(parent, yOffset)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Background
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.3)

    -- Character name (with level)
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.nameText:SetPoint("LEFT", row, "LEFT", 16, 0)
    row.nameText:SetWidth(NAME_COLUMN_WIDTH)
    row.nameText:SetJustifyH("LEFT")

    -- Boss status icons (will be created dynamically)
    row.bossIcons = {}

    row.isCharacterRow = true

    -- Highlight
    row:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.2, 0.2, 0.2, 0.5)
    end)
    row:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.1, 0.1, 0.1, 0.3)
    end)

    -- Right-click menu
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" and self.charData then
            addon:ShowContextMenu(self, self.charData)
        end
    end)

    return row
end

-- Create boss column headers
local function CreateBossHeaders(parent)
    local headers = CreateFrame("Frame", nil, parent)
    headers:SetHeight(ROW_HEIGHT)
    headers:SetPoint("TOPLEFT", parent.header, "BOTTOMLEFT", 0, 0)
    headers:SetPoint("TOPRIGHT", parent.header, "BOTTOMRIGHT", 0, 0)

    headers.bg = headers:CreateTexture(nil, "BACKGROUND")
    headers.bg:SetAllPoints()
    headers.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)

    -- "Character" label
    headers.charLabel = headers:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headers.charLabel:SetPoint("LEFT", headers, "LEFT", 16, 0)
    headers.charLabel:SetText("Character")
    headers.charLabel:SetTextColor(0.7, 0.7, 0.7)

    headers.bossLabels = {}

    return headers
end

-- Update boss column headers
local function UpdateBossHeaders(headers)
    -- Clear old labels
    for _, label in pairs(headers.bossLabels) do
        label:Hide()
    end

    local enabledBosses = addon:GetEnabledBosses()
    local xOffset = NAME_COLUMN_WIDTH + 16

    for i, boss in ipairs(enabledBosses) do
        local label = headers.bossLabels[i]
        if not label then
            label = headers:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            headers.bossLabels[i] = label
        end

        label:SetPoint("LEFT", headers, "LEFT", xOffset, 0)
        label:SetWidth(BOSS_COLUMN_WIDTH)
        label:SetText(boss.abbrev)
        label:SetTextColor(0.7, 0.7, 0.7)
        label:Show()

        -- Tooltip
        local tooltipFrame = CreateFrame("Frame", nil, headers)
        tooltipFrame:SetPoint("LEFT", headers, "LEFT", xOffset, 0)
        tooltipFrame:SetSize(BOSS_COLUMN_WIDTH, ROW_HEIGHT)
        tooltipFrame:SetScript("OnEnter", function()
            GameTooltip:SetOwner(tooltipFrame, "ANCHOR_TOP")
            GameTooltip:AddLine(boss.name, 1, 0.82, 0)
            GameTooltip:AddLine(boss.zone, 1, 1, 1)
            if boss.note then
                GameTooltip:AddLine(boss.note, 1, 0.5, 0.5)
            end
            GameTooltip:Show()
        end)
        tooltipFrame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        xOffset = xOffset + BOSS_COLUMN_WIDTH
    end

    -- Update frame width based on enabled bosses
    local totalWidth = NAME_COLUMN_WIDTH + 16 + (#enabledBosses * BOSS_COLUMN_WIDTH) + 40
    mainFrame:SetWidth(math.max(totalWidth, 300))
end

-- Update a character row with data
local function UpdateCharacterRow(row, charData, enabledBosses)
    local classColor = GetClassColor(charData.class)

    -- Format: (level) Name
    local nameStr = string.format("(%d) |cff%02x%02x%02x%s|r",
        charData.level or 0,
        classColor.r * 255,
        classColor.g * 255,
        classColor.b * 255,
        charData.name)
    row.nameText:SetText(nameStr)

    -- Store char data for context menu
    row.charData = charData

    -- Update boss icons
    local xOffset = NAME_COLUMN_WIDTH + 16

    for i, boss in ipairs(enabledBosses) do
        local icon = row.bossIcons[i]
        if not icon then
            icon = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.bossIcons[i] = icon
        end

        icon:SetPoint("LEFT", row, "LEFT", xOffset + (BOSS_COLUMN_WIDTH / 2) - 7, 0)

        local killed = charData.bosses[boss.key]
        if killed then
            icon:SetText(AtlasIcon(addon.ICON_KILLED, 14))
        else
            icon:SetText(AtlasIcon(addon.ICON_NOT_KILLED, 14))
        end
        icon:Show()

        xOffset = xOffset + BOSS_COLUMN_WIDTH
    end

    -- Hide extra icons
    for i = #enabledBosses + 1, #row.bossIcons do
        row.bossIcons[i]:Hide()
    end
end

-- Create context menu
local function CreateContextMenu()
    local menu = CreateFrame("Frame", "WorldBossChecklistContextMenu", UIParent, "UIDropDownMenuTemplate")
    return menu
end

-- Show context menu for a character
function addon:ShowContextMenu(anchor, charData)
    if not contextMenu then
        contextMenu = CreateContextMenu()
    end

    local menuList = {
        {
            text = charData.name .. "-" .. charData.realm,
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Delete Character",
            notCheckable = true,
            func = function()
                addon:DeleteCharacter(charData.fullName)
                addon:UpdateUI()
            end,
        },
        {
            text = "Ban Character",
            notCheckable = true,
            func = function()
                StaticPopup_Show("WBC_CONFIRM_BAN", charData.fullName)
            end,
        },
        {
            text = "Cancel",
            notCheckable = true,
            func = function() end,
        },
    }

    EasyMenu(menuList, contextMenu, "cursor", 0, 0, "MENU")
end

-- Static popup for ban confirmation
StaticPopupDialogs["WBC_CONFIRM_BAN"] = {
    text = "Ban %s?\n\nThis character will be removed and won't be added again when you log in.",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self, data)
        addon:BanCharacter(data)
        addon:UpdateUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Initialize the UI
function addon:InitializeUI()
    if mainFrame then return end

    mainFrame = CreateMainFrame()
    mainFrame.bossHeaders = CreateBossHeaders(mainFrame)

    -- Adjust scroll frame position to account for boss headers
    mainFrame.scrollFrame:SetPoint("TOPLEFT", mainFrame.bossHeaders, "BOTTOMLEFT", 0, -2)

    -- Restore position
    if addon.db.options.framePosition then
        local pos = addon.db.options.framePosition
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    end

    -- Apply scale
    mainFrame:SetScale(addon.db.options.frameScale or 1.0)

    -- Start hidden
    mainFrame:Hide()

    addon.mainFrame = mainFrame
end

-- Update the UI
function addon:UpdateUI()
    if not mainFrame or not mainFrame:IsShown() then return end

    local content = mainFrame.contentFrame
    local enabledBosses = self:GetEnabledBosses()

    -- Update boss headers
    UpdateBossHeaders(mainFrame.bossHeaders)

    -- Clear old rows
    for _, row in ipairs(rows) do
        row:Hide()
    end

    local allCharacters = self:GetAllCharacters()
    local yOffset = 0
    local rowIndex = 0

    for _, realmData in ipairs(allCharacters) do
        -- Realm header
        rowIndex = rowIndex + 1
        local realmRow = rows[rowIndex]
        if not realmRow or not realmRow.isRealmHeader then
            realmRow = CreateRealmHeader(content, realmData.name, yOffset)
            rows[rowIndex] = realmRow
        else
            realmRow:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
            realmRow:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, yOffset)
            realmRow.text:SetText(realmData.name)
            realmRow.realmName = realmData.name
        end

        -- Update collapse indicator
        local collapsed = addon.db.options.collapsedRealms[realmData.name]
        realmRow.indicator:SetText(collapsed and "+" or "-")
        realmRow:Show()

        yOffset = yOffset - ROW_HEIGHT

        -- Characters (if not collapsed)
        if not collapsed then
            for _, charData in ipairs(realmData.characters) do
                if self:ShouldShowCharacter(charData) then
                    rowIndex = rowIndex + 1
                    local charRow = rows[rowIndex]
                    if not charRow or not charRow.isCharacterRow then
                        charRow = CreateCharacterRow(content, yOffset)
                        rows[rowIndex] = charRow
                    else
                        charRow:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
                        charRow:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, yOffset)
                    end

                    UpdateCharacterRow(charRow, charData, enabledBosses)
                    charRow:Show()

                    yOffset = yOffset - ROW_HEIGHT
                end
            end
        end
    end

    -- Update content height
    local totalHeight = math.abs(yOffset)
    content:SetHeight(math.max(totalHeight, 50))

    -- Update frame height
    local frameHeight = HEADER_HEIGHT + ROW_HEIGHT + totalHeight + 12
    frameHeight = math.max(frameHeight, FRAME_MIN_HEIGHT)
    frameHeight = math.min(frameHeight, 500) -- Max height
    mainFrame:SetHeight(frameHeight)
end

-- Toggle main frame visibility
function addon:ToggleUI()
    if not mainFrame then
        self:InitializeUI()
    end

    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        self:UpdateUI()
    end
end

-- Show/Hide functions
function addon:ShowUI()
    if not mainFrame then
        self:InitializeUI()
    end
    mainFrame:Show()
    self:UpdateUI()
end

function addon:HideUI()
    if mainFrame then
        mainFrame:Hide()
    end
end
