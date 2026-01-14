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

    -- Main icon - using a world boss themed icon (Sha of Anger - looks like a menacing face)
    local icon = minimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(21, 21)
    icon:SetTexture("Interface\\Icons\\achievement_boss_shadanger")
    icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 1)
    -- Apply circular mask using tex coords
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
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
-- Settings Panel
-------------------------------------------------

local settingsPanel = nil

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
    slider.Low:SetText(minVal)
    slider.High:SetText(maxVal)
    slider.Text:SetText(label)

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        self.valueText:SetText(string.format("%.1f", value))
        if onValueChanged then onValueChanged(value) end
    end)

    slider.valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slider.valueText:SetPoint("TOP", slider, "BOTTOM", 0, 0)

    return slider
end

function addon:CreateSettingsPanel()
    if settingsPanel then return settingsPanel end

    local panel = CreateFrame("Frame", "WorldBossChecklistSettingsPanel", UIParent, "BackdropTemplate")
    panel:SetSize(350, 400)
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

    local yPos = -40

    -- Show Unkilled Only
    local cbUnkilled = CreateCheckbox(panel, "Show Unkilled Only",
        "Only show characters that haven't killed all tracked bosses",
        function(checked)
            addon.db.options.showUnkilledOnly = checked
            addon:UpdateUI()
        end)
    cbUnkilled:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, yPos)
    panel.cbUnkilled = cbUnkilled
    yPos = yPos - 30

    -- Show Minimap Button
    local cbMinimap = CreateCheckbox(panel, "Show Minimap Button",
        "Show or hide the minimap button",
        function(checked)
            if checked then
                addon:ShowMinimapButton()
            else
                addon:HideMinimapButton()
            end
        end)
    cbMinimap:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, yPos)
    panel.cbMinimap = cbMinimap
    yPos = yPos - 30

    -- Lock Frame
    local cbLocked = CreateCheckbox(panel, "Lock Frame Position",
        "Prevent the main window from being moved",
        function(checked)
            addon.db.options.locked = checked
        end)
    cbLocked:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, yPos)
    panel.cbLocked = cbLocked
    yPos = yPos - 40

    -- Level Requirement Slider
    local sliderLevel = CreateSlider(panel, "Minimum Level", 0, 90, 5, function(value)
        addon.db.options.levelRequirement = value
        addon:UpdateUI()
    end)
    sliderLevel:SetPoint("TOPLEFT", panel, "TOPLEFT", 30, yPos)
    sliderLevel:SetWidth(150)
    panel.sliderLevel = sliderLevel
    yPos = yPos - 50

    -- UI Scale Slider
    local sliderScale = CreateSlider(panel, "UI Scale", 0.5, 2.0, 0.1, function(value)
        addon.db.options.frameScale = value
        if mainFrame then
            mainFrame:SetScale(value)
        end
    end)
    sliderScale:SetPoint("TOPLEFT", panel, "TOPLEFT", 30, yPos)
    sliderScale:SetWidth(150)
    panel.sliderScale = sliderScale
    yPos = yPos - 50

    -- Boss Tracking Section
    local bossHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bossHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, yPos)
    bossHeader:SetText("Track Bosses:")
    bossHeader:SetTextColor(1, 0.82, 0)
    yPos = yPos - 25

    panel.bossCheckboxes = {}
    for i, boss in ipairs(addon.WORLD_BOSSES) do
        local cb = CreateCheckbox(panel, boss.name,
            boss.zone .. (boss.note and (" - " .. boss.note) or ""),
            function(checked)
                addon.db.options.trackBosses[boss.key] = checked
                addon:UpdateUI()
            end)
        cb:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, yPos)
        panel.bossCheckboxes[boss.key] = cb
        yPos = yPos - 25
    end

    panel:Hide()
    settingsPanel = panel
    return panel
end

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
