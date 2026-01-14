local addonName, addon = ...

local ROW_HEIGHT = 18
local HEADER_HEIGHT = 24
local BOSS_COLUMN_WIDTH = 65
local NAME_COLUMN_WIDTH = 150

-- Main frame
local mainFrame = nil
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

-- Create the main frame (no scroll, dynamic height)
local function CreateMainFrame()
    local frame = CreateFrame("Frame", "WorldBossChecklistFrame", UIParent, "BackdropTemplate")
    frame:SetSize(500, 200)
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
    frame:SetBackdropColor(0, 0, 0, 0.85)
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
    header:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
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

    -- Settings button (gear icon)
    local settingsBtn = CreateFrame("Button", nil, header)
    settingsBtn:SetSize(16, 16)
    settingsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    settingsBtn:SetNormalAtlas("Garr_Building-AddFollowerPlus")
    settingsBtn:SetHighlightAtlas("Garr_Building-AddFollowerPlus")
    settingsBtn:SetScript("OnClick", function()
        addon:ToggleSettingsPanel()
    end)
    settingsBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Settings", 1, 1, 1)
        GameTooltip:Show()
    end)
    settingsBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    frame.settingsBtn = settingsBtn

    -- Content frame (direct child, no scroll)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 4, 0)
    content:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -4, 0)
    frame.contentFrame = content

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
    headers:SetPoint("TOPLEFT", parent.header, "BOTTOMLEFT", 4, 0)
    headers:SetPoint("TOPRIGHT", parent.header, "BOTTOMRIGHT", -4, 0)

    headers.bg = headers:CreateTexture(nil, "BACKGROUND")
    headers.bg:SetAllPoints()
    headers.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)

    -- "Character" label
    headers.charLabel = headers:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headers.charLabel:SetPoint("LEFT", headers, "LEFT", 16, 0)
    headers.charLabel:SetText("Character")
    headers.charLabel:SetTextColor(0.7, 0.7, 0.7)

    headers.bossLabels = {}
    headers.tooltipFrames = {}

    return headers
end

-- Update boss column headers
local function UpdateBossHeaders(headers)
    -- Clear old labels and tooltip frames
    for _, label in pairs(headers.bossLabels) do
        label:Hide()
    end
    for _, frame in pairs(headers.tooltipFrames) do
        frame:Hide()
    end

    local enabledBosses = addon:GetEnabledBosses()
    local xOffset = NAME_COLUMN_WIDTH + 16

    for i, boss in ipairs(enabledBosses) do
        local label = headers.bossLabels[i]
        if not label then
            label = headers:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            headers.bossLabels[i] = label
        end

        label:ClearAllPoints()
        label:SetPoint("LEFT", headers, "LEFT", xOffset, 0)
        label:SetWidth(BOSS_COLUMN_WIDTH)
        label:SetText(boss.name)  -- Full boss name
        label:SetTextColor(0.7, 0.7, 0.7)
        label:Show()

        -- Tooltip frame
        local tooltipFrame = headers.tooltipFrames[i]
        if not tooltipFrame then
            tooltipFrame = CreateFrame("Frame", nil, headers)
            headers.tooltipFrames[i] = tooltipFrame
        end
        tooltipFrame:ClearAllPoints()
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
        tooltipFrame:Show()

        xOffset = xOffset + BOSS_COLUMN_WIDTH
    end

    -- Update frame width based on enabled bosses
    local totalWidth = NAME_COLUMN_WIDTH + 20 + (#enabledBosses * BOSS_COLUMN_WIDTH) + 20
    mainFrame:SetWidth(math.max(totalWidth, 350))
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

        icon:ClearAllPoints()
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

    -- Adjust content frame position to account for boss headers
    mainFrame.contentFrame:SetPoint("TOPLEFT", mainFrame.bossHeaders, "BOTTOMLEFT", 0, -2)

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

    -- Initialize minimap button
    addon:InitializeMinimapButton()

    -- Initialize Titan Panel support
    addon:InitializeTitanPanel()
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
            realmRow:ClearAllPoints()
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
                        charRow:ClearAllPoints()
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
    content:SetHeight(math.max(totalHeight, 20))

    -- Update frame height (no max limit, grows with content)
    local frameHeight = HEADER_HEIGHT + ROW_HEIGHT + totalHeight + 10
    frameHeight = math.max(frameHeight, 80)
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

-------------------------------------------------
-- Minimap Button
-------------------------------------------------

local minimapButton = nil

function addon:InitializeMinimapButton()
    if minimapButton then return end
    if not addon.db.options.minimapButton then return end

    -- Create minimap button
    minimapButton = CreateFrame("Button", "WorldBossChecklistMinimapButton", Minimap)
    minimapButton:SetSize(31, 31)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Background/border (the ring around the icon)
    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT", 0, 0)
    minimapButton.border = border

    -- Icon background (dark circle behind icon)
    local iconBg = minimapButton:CreateTexture(nil, "BACKGROUND")
    iconBg:SetSize(25, 25)
    iconBg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    iconBg:SetPoint("CENTER", minimapButton, "CENTER", 0, 1)
    minimapButton.iconBg = iconBg

    -- Main icon - using raid target skull which exists in all WoW versions
    local icon = minimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8")  -- Skull marker
    icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 1)
    minimapButton.icon = icon

    -- Highlight texture
    local highlight = minimapButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(25, 25)
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetPoint("CENTER", minimapButton, "CENTER", 0, 1)
    minimapButton.highlight = highlight

    -- Position around minimap
    local function UpdatePosition()
        local angle = math.rad(addon.db.options.minimapButtonAngle or 225)
        local x = math.cos(angle) * 80
        local y = math.sin(angle) * 80
        minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    -- Dragging
    minimapButton:SetMovable(true)
    minimapButton:EnableMouse(true)
    minimapButton:RegisterForDrag("LeftButton")

    minimapButton:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    minimapButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Calculate angle from minimap center
        local mx, my = Minimap:GetCenter()
        local px, py = self:GetCenter()
        local angle = math.atan2(py - my, px - mx)
        addon.db.options.minimapButtonAngle = math.deg(angle)
        UpdatePosition()
    end)

    -- Click handlers
    minimapButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            addon:ToggleUI()
        elseif button == "RightButton" then
            addon:ToggleSettingsPanel()
        end
    end)

    -- Tooltip
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("World Boss Checklist", 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffffffffLeft-click:|r Toggle window", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffffffffRight-click:|r Settings", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffffffffDrag:|r Move button", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    minimapButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    UpdatePosition()
    minimapButton:Show()

    addon.minimapButton = minimapButton
end

function addon:ShowMinimapButton()
    addon.db.options.minimapButton = true
    if not minimapButton then
        self:InitializeMinimapButton()
    else
        minimapButton:Show()
    end
end

function addon:HideMinimapButton()
    addon.db.options.minimapButton = false
    if minimapButton then
        minimapButton:Hide()
    end
end

-------------------------------------------------
-- Titan Panel Support
-------------------------------------------------

function addon:InitializeTitanPanel()
    -- Check if Titan Panel is loaded
    if not TitanPanelButton_OnLoad then return end

    local TITAN_ID = "WorldBossChecklist"

    -- Create the Titan Panel button
    local titanButton = CreateFrame("Button", "TitanPanelWorldBossChecklistButton", UIParent, "TitanPanelComboTemplate")
    titanButton:SetFrameStrata("FULLSCREEN")

    -- Define the registry
    titanButton.registry = {
        id = TITAN_ID,
        category = "Information",
        version = "1.1.0",
        menuText = "World Boss Checklist",
        buttonTextFunction = "TitanPanelWorldBossChecklistButton_GetButtonText",
        tooltipTitle = "World Boss Checklist",
        tooltipTextFunction = "TitanPanelWorldBossChecklistButton_GetTooltipText",
        icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8",
        iconWidth = 16,
        savedVariables = {
            ShowIcon = 1,
            ShowLabelText = 1,
        }
    }

    -- Register with Titan Panel
    TitanPanelButton_OnLoad(titanButton)

    addon.titanButton = titanButton
end

-- Titan Panel button text function
function TitanPanelWorldBossChecklistButton_GetButtonText(id)
    local unkilled = 0
    local total = 0
    local enabledBosses = addon:GetEnabledBosses()

    -- Get current character's unkilled count
    local info = addon:GetCurrentCharacterInfo()
    if addon.db.realms[info.realm] and addon.db.realms[info.realm][info.name] then
        local charData = addon.db.realms[info.realm][info.name]
        for _, boss in ipairs(enabledBosses) do
            total = total + 1
            if not charData.bosses[boss.key] then
                unkilled = unkilled + 1
            end
        end
    else
        total = #enabledBosses
        unkilled = total
    end

    return "WBC", unkilled .. "/" .. total
end

-- Titan Panel tooltip function
function TitanPanelWorldBossChecklistButton_GetTooltipText()
    local lines = {}
    local enabledBosses = addon:GetEnabledBosses()
    local info = addon:GetCurrentCharacterInfo()

    table.insert(lines, "|cff00ff00" .. info.name .. "|r")
    table.insert(lines, " ")

    if addon.db.realms[info.realm] and addon.db.realms[info.realm][info.name] then
        local charData = addon.db.realms[info.realm][info.name]
        for _, boss in ipairs(enabledBosses) do
            local status = charData.bosses[boss.key] and "|cff00ff00Killed|r" or "|cffff0000Not Killed|r"
            table.insert(lines, boss.name .. ": " .. status)
        end
    else
        for _, boss in ipairs(enabledBosses) do
            table.insert(lines, boss.name .. ": |cffff0000Not Killed|r")
        end
    end

    table.insert(lines, " ")
    table.insert(lines, "|cffffffffLeft-click:|r Toggle window")
    table.insert(lines, "|cffffffffRight-click:|r Settings menu")

    return table.concat(lines, "\n")
end

-- Titan Panel right-click menu
function TitanPanelRightClickMenu_PrepareWorldBossChecklistMenu()
    local info = {}

    -- Title
    info.text = "World Boss Checklist"
    info.isTitle = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info)

    -- Open window
    info = {}
    info.text = "Open Window"
    info.func = function() addon:ShowUI() end
    info.notCheckable = true
    UIDropDownMenu_AddButton(info)

    -- Settings
    info = {}
    info.text = "Settings"
    info.func = function() addon:ShowSettingsPanel() end
    info.notCheckable = true
    UIDropDownMenu_AddButton(info)

    -- Separator
    TitanPanelRightClickMenu_AddSpacer()

    -- Standard Titan options
    TitanPanelRightClickMenu_AddToggleIcon("WorldBossChecklist")
    TitanPanelRightClickMenu_AddToggleLabelText("WorldBossChecklist")

    -- Hide option
    TitanPanelRightClickMenu_AddSpacer()
    TitanPanelRightClickMenu_AddCommand("Hide", "WorldBossChecklist", TITAN_PANEL_MENU_FUNC_HIDE)
end

-------------------------------------------------
-- Settings Panel (Tabbed)
-------------------------------------------------

local settingsPanel = nil
local TAB_GENERAL = 1
local TAB_BOSSES = 2
local TAB_CHARACTERS = 3

local function CreateCheckbox(parent, label, tooltip, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb.Text:SetText(label)
    cb.tooltipText = tooltip
    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        if onClick then onClick(checked) end
    end)
    return cb
end

local function CreateSlider(parent, label, minVal, maxVal, step, onValueChanged)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(200)
    slider.Low:SetText(minVal)
    slider.High:SetText(maxVal)
    slider.Text:SetText(label)

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        self.valueText:SetText(string.format("%.1f", value))
        if onValueChanged then onValueChanged(value) end
    end)

    slider.valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slider.valueText:SetPoint("TOP", slider, "BOTTOM", 0, -2)

    return slider
end

local function CreateTab(parent, id, text, onClick)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(100, 28)
    tab.id = id

    -- Background
    tab.bg = tab:CreateTexture(nil, "BACKGROUND")
    tab.bg:SetAllPoints()
    tab.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

    -- Text
    tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.text:SetPoint("CENTER")
    tab.text:SetText(text)

    -- Selected indicator
    tab.selected = tab:CreateTexture(nil, "BORDER")
    tab.selected:SetPoint("BOTTOMLEFT", 0, 0)
    tab.selected:SetPoint("BOTTOMRIGHT", 0, 0)
    tab.selected:SetHeight(2)
    tab.selected:SetColorTexture(1, 0.82, 0, 1)
    tab.selected:Hide()

    tab:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        if onClick then onClick(self.id) end
    end)

    tab:SetScript("OnEnter", function(self)
        if not self.isSelected then
            self.bg:SetColorTexture(0.3, 0.3, 0.3, 0.8)
        end
    end)

    tab:SetScript("OnLeave", function(self)
        if not self.isSelected then
            self.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
        end
    end)

    return tab
end

local function SetTabSelected(tab, selected)
    tab.isSelected = selected
    if selected then
        tab.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
        tab.selected:Show()
        tab.text:SetTextColor(1, 0.82, 0)
    else
        tab.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
        tab.selected:Hide()
        tab.text:SetTextColor(0.8, 0.8, 0.8)
    end
end

function addon:CreateSettingsPanel()
    if settingsPanel then return settingsPanel end

    local panel = CreateFrame("Frame", "WorldBossChecklistSettingsPanel", UIParent, "BackdropTemplate")
    panel:SetSize(400, 450)
    panel:SetPoint("CENTER")
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)

    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    panel:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Make draggable
    panel:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then self:StartMoving() end
    end)
    panel:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)

    -- Header
    local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOP", panel, "TOP", 0, -10)
    header:SetText("World Boss Checklist Settings")
    header:SetTextColor(1, 0.82, 0)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -2)

    -- Tab buttons
    panel.tabs = {}
    local tabContainer = CreateFrame("Frame", nil, panel)
    tabContainer:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -35)
    tabContainer:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -35)
    tabContainer:SetHeight(28)

    local function SwitchTab(tabId)
        panel.currentTab = tabId
        for _, t in pairs(panel.tabs) do
            SetTabSelected(t, t.id == tabId)
        end
        -- Show/hide content
        panel.generalContent:SetShown(tabId == TAB_GENERAL)
        panel.bossesContent:SetShown(tabId == TAB_BOSSES)
        panel.charactersContent:SetShown(tabId == TAB_CHARACTERS)

        if tabId == TAB_CHARACTERS then
            addon:UpdateCharacterList()
        end
    end

    local tab1 = CreateTab(tabContainer, TAB_GENERAL, "General", SwitchTab)
    tab1:SetPoint("LEFT", tabContainer, "LEFT", 0, 0)
    panel.tabs[TAB_GENERAL] = tab1

    local tab2 = CreateTab(tabContainer, TAB_BOSSES, "Bosses", SwitchTab)
    tab2:SetPoint("LEFT", tab1, "RIGHT", 5, 0)
    panel.tabs[TAB_BOSSES] = tab2

    local tab3 = CreateTab(tabContainer, TAB_CHARACTERS, "Characters", SwitchTab)
    tab3:SetPoint("LEFT", tab2, "RIGHT", 5, 0)
    panel.tabs[TAB_CHARACTERS] = tab3

    -- Content area
    local contentArea = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    contentArea:SetPoint("TOPLEFT", tabContainer, "BOTTOMLEFT", 0, -5)
    contentArea:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 10)
    contentArea:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    contentArea:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    contentArea:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    panel.contentArea = contentArea

    -------------------------------------------------
    -- General Tab Content
    -------------------------------------------------
    local generalContent = CreateFrame("Frame", nil, contentArea)
    generalContent:SetAllPoints()
    panel.generalContent = generalContent

    local yPos = -20

    -- Show Unkilled Only
    local cbUnkilled = CreateCheckbox(generalContent, "Show Unkilled Only",
        "Only show characters that haven't killed all tracked bosses",
        function(checked)
            addon.db.options.showUnkilledOnly = checked
            addon:UpdateUI()
        end)
    cbUnkilled:SetPoint("TOPLEFT", generalContent, "TOPLEFT", 20, yPos)
    panel.cbUnkilled = cbUnkilled
    yPos = yPos - 30

    -- Show Minimap Button
    local cbMinimap = CreateCheckbox(generalContent, "Show Minimap Button",
        "Show or hide the minimap button",
        function(checked)
            if checked then
                addon:ShowMinimapButton()
            else
                addon:HideMinimapButton()
            end
        end)
    cbMinimap:SetPoint("TOPLEFT", generalContent, "TOPLEFT", 20, yPos)
    panel.cbMinimap = cbMinimap
    yPos = yPos - 30

    -- Lock Frame
    local cbLocked = CreateCheckbox(generalContent, "Lock Frame Position",
        "Prevent the main window from being moved",
        function(checked)
            addon.db.options.locked = checked
        end)
    cbLocked:SetPoint("TOPLEFT", generalContent, "TOPLEFT", 20, yPos)
    panel.cbLocked = cbLocked
    yPos = yPos - 50

    -- Level Requirement Slider
    local sliderLevel = CreateSlider(generalContent, "Minimum Level Filter", 0, 90, 5, function(value)
        addon.db.options.levelRequirement = value
        addon:UpdateUI()
    end)
    sliderLevel:SetPoint("TOPLEFT", generalContent, "TOPLEFT", 30, yPos)
    panel.sliderLevel = sliderLevel
    yPos = yPos - 60

    -- UI Scale Slider
    local sliderScale = CreateSlider(generalContent, "UI Scale", 0.5, 2.0, 0.1, function(value)
        addon.db.options.frameScale = value
        if mainFrame then
            mainFrame:SetScale(value)
        end
    end)
    sliderScale:SetPoint("TOPLEFT", generalContent, "TOPLEFT", 30, yPos)
    panel.sliderScale = sliderScale

    -------------------------------------------------
    -- Bosses Tab Content
    -------------------------------------------------
    local bossesContent = CreateFrame("Frame", nil, contentArea)
    bossesContent:SetAllPoints()
    bossesContent:Hide()
    panel.bossesContent = bossesContent

    local bossHeader = bossesContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bossHeader:SetPoint("TOPLEFT", bossesContent, "TOPLEFT", 20, -15)
    bossHeader:SetText("Select which bosses to track:")
    bossHeader:SetTextColor(0.9, 0.9, 0.9)

    yPos = -45
    panel.bossCheckboxes = {}
    for i, boss in ipairs(addon.WORLD_BOSSES) do
        local cb = CreateCheckbox(bossesContent, boss.name,
            boss.zone .. (boss.note and (" - " .. boss.note) or ""),
            function(checked)
                addon.db.options.trackBosses[boss.key] = checked
                addon:UpdateUI()
            end)
        cb:SetPoint("TOPLEFT", bossesContent, "TOPLEFT", 20, yPos)
        panel.bossCheckboxes[boss.key] = cb

        -- Add zone info
        local zoneText = bossesContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        zoneText:SetPoint("LEFT", cb.Text, "RIGHT", 10, 0)
        zoneText:SetText("|cff888888(" .. boss.zone .. ")|r")
        cb.zoneText = zoneText

        yPos = yPos - 28
    end

    -------------------------------------------------
    -- Characters Tab Content
    -------------------------------------------------
    local charactersContent = CreateFrame("Frame", nil, contentArea)
    charactersContent:SetAllPoints()
    charactersContent:Hide()
    panel.charactersContent = charactersContent

    local charHeader = charactersContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    charHeader:SetPoint("TOPLEFT", charactersContent, "TOPLEFT", 20, -15)
    charHeader:SetText("Manage your characters:")
    charHeader:SetTextColor(0.9, 0.9, 0.9)

    -- Scroll frame for character list
    local scrollFrame = CreateFrame("ScrollFrame", nil, charactersContent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", charactersContent, "TOPLEFT", 10, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", charactersContent, "BOTTOMRIGHT", -30, 50)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(340, 1)
    scrollFrame:SetScrollChild(scrollChild)
    panel.charScrollChild = scrollChild
    panel.charRows = {}

    -- Banned characters section
    local bannedLabel = charactersContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bannedLabel:SetPoint("BOTTOMLEFT", charactersContent, "BOTTOMLEFT", 15, 25)
    bannedLabel:SetTextColor(0.7, 0.7, 0.7)
    panel.bannedLabel = bannedLabel

    local unbanAllBtn = CreateFrame("Button", nil, charactersContent, "UIPanelButtonTemplate")
    unbanAllBtn:SetSize(100, 22)
    unbanAllBtn:SetPoint("BOTTOMRIGHT", charactersContent, "BOTTOMRIGHT", -15, 15)
    unbanAllBtn:SetText("Unban All")
    unbanAllBtn:SetScript("OnClick", function()
        StaticPopup_Show("WBC_CONFIRM_UNBAN_ALL")
    end)
    panel.unbanAllBtn = unbanAllBtn

    -- Start with general tab
    panel.currentTab = TAB_GENERAL
    SetTabSelected(tab1, true)

    panel:Hide()
    settingsPanel = panel
    return panel
end

-- Static popup for unban all
StaticPopupDialogs["WBC_CONFIRM_UNBAN_ALL"] = {
    text = "Unban all characters?\n\nThis will allow all previously banned characters to be tracked again.",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        addon.db.banned = {}
        addon:UpdateCharacterList()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Create a character row for the settings panel
local function CreateCharacterSettingsRow(parent, index)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(24)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * 26)
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    row:SetBackdropColor(0.15, 0.15, 0.15, 0.5)

    -- Name
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.nameText:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.nameText:SetWidth(180)
    row.nameText:SetJustifyH("LEFT")

    -- Realm
    row.realmText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.realmText:SetPoint("LEFT", row.nameText, "RIGHT", 5, 0)
    row.realmText:SetWidth(80)
    row.realmText:SetJustifyH("LEFT")
    row.realmText:SetTextColor(0.6, 0.6, 0.6)

    -- Delete button
    row.deleteBtn = CreateFrame("Button", nil, row)
    row.deleteBtn:SetSize(16, 16)
    row.deleteBtn:SetPoint("RIGHT", row, "RIGHT", -30, 0)
    row.deleteBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    row.deleteBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
    row.deleteBtn:GetHighlightTexture():SetVertexColor(1, 0.5, 0.5)
    row.deleteBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Delete", 1, 1, 1)
        GameTooltip:Show()
    end)
    row.deleteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Ban button
    row.banBtn = CreateFrame("Button", nil, row)
    row.banBtn:SetSize(16, 16)
    row.banBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.banBtn:SetNormalTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
    row.banBtn:SetHighlightTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
    row.banBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Ban", 1, 1, 1)
        GameTooltip:Show()
    end)
    row.banBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return row
end

function addon:UpdateCharacterList()
    if not settingsPanel or not settingsPanel.charScrollChild then return end

    local scrollChild = settingsPanel.charScrollChild
    local allCharacters = self:GetAllCharacters()

    -- Hide all existing rows
    for _, row in ipairs(settingsPanel.charRows) do
        row:Hide()
    end

    local rowIndex = 0
    for _, realmData in ipairs(allCharacters) do
        for _, charData in ipairs(realmData.characters) do
            rowIndex = rowIndex + 1

            local row = settingsPanel.charRows[rowIndex]
            if not row then
                row = CreateCharacterSettingsRow(scrollChild, rowIndex)
                settingsPanel.charRows[rowIndex] = row
            end

            local classColor = GetClassColor(charData.class)
            row.nameText:SetText(string.format("|cff%02x%02x%02x(%d) %s|r",
                classColor.r * 255,
                classColor.g * 255,
                classColor.b * 255,
                charData.level or 0,
                charData.name))
            row.realmText:SetText(charData.realm)

            -- Store data for callbacks
            row.charData = charData

            row.deleteBtn:SetScript("OnClick", function()
                addon:DeleteCharacter(charData.fullName)
                addon:UpdateCharacterList()
                addon:UpdateUI()
            end)

            row.banBtn:SetScript("OnClick", function()
                StaticPopup_Show("WBC_CONFIRM_BAN_SETTINGS", charData.fullName)
            end)

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(rowIndex - 1) * 26)
            row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
            row:Show()
        end
    end

    scrollChild:SetHeight(math.max(rowIndex * 26, 10))

    -- Update banned count
    local bannedCount = 0
    for _ in pairs(self.db.banned) do
        bannedCount = bannedCount + 1
    end
    settingsPanel.bannedLabel:SetText("Banned characters: " .. bannedCount)
    settingsPanel.unbanAllBtn:SetEnabled(bannedCount > 0)
end

-- Static popup for ban from settings
StaticPopupDialogs["WBC_CONFIRM_BAN_SETTINGS"] = {
    text = "Ban %s?\n\nThis character will be removed and won't be added again when you log in.",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self, data)
        addon:BanCharacter(data)
        addon:UpdateCharacterList()
        addon:UpdateUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function addon:UpdateSettingsPanel()
    if not settingsPanel then return end

    local opts = addon.db.options

    settingsPanel.cbUnkilled:SetChecked(opts.showUnkilledOnly)
    settingsPanel.cbMinimap:SetChecked(opts.minimapButton)
    settingsPanel.cbLocked:SetChecked(opts.locked)
    settingsPanel.sliderLevel:SetValue(opts.levelRequirement or 0)
    settingsPanel.sliderScale:SetValue(opts.frameScale or 1.0)

    for key, cb in pairs(settingsPanel.bossCheckboxes) do
        cb:SetChecked(opts.trackBosses[key])
    end
end

function addon:ToggleSettingsPanel()
    if not settingsPanel then
        self:CreateSettingsPanel()
    end

    if settingsPanel:IsShown() then
        settingsPanel:Hide()
    else
        self:UpdateSettingsPanel()
        settingsPanel:Show()
    end
end

function addon:ShowSettingsPanel()
    if not settingsPanel then
        self:CreateSettingsPanel()
    end
    self:UpdateSettingsPanel()
    settingsPanel:Show()
end

function addon:HideSettingsPanel()
    if settingsPanel then
        settingsPanel:Hide()
    end
end
