local ADDON_NAME = "EnemyNameplateColors"
local ENC = _G[ADDON_NAME]

local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "EnemyNameplateColorsOptionsPanel", UIParent)
    panel.name = "Enemy Nameplate Colors"
    panel.default = function() ENC:ResetToDefaults() end
    
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Enemy Nameplate Colors")
    
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Customize nameplate and castbar colors based on unit type, threat level, and cast type.")
    
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    desc:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -12)
    desc:SetJustifyH("LEFT")
    desc:SetWidth(580)
    desc:SetText("Nameplate colors are applied based on priority:\n" ..
                 "|cffffffffOut of Combat:|r All enemies use Unit Type colors\n" ..
                 "|cffffffffTanks in Combat:|r Threat on Another Tank > No Threat > Losing Threat > Unit Type\n" ..
                 "|cffffffffDPS/Healers in Combat:|r Has Threat > Gaining Threat > Unit Type")
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    scrollFrame:SetPoint("BOTTOMRIGHT", -32, 16)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(550, 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    local yOffset = 0
    
    local function CreateHeader(text, offsetY)
        local header = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, offsetY)
        header:SetText(text)
        return offsetY - 30
    end
    
    local function CreateDivider(offsetY)
        local line = scrollChild:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("LEFT", scrollChild, "TOPLEFT", 0, offsetY)
        line:SetPoint("RIGHT", scrollChild, "TOPRIGHT", -20, offsetY)
        line:SetColorTexture(0.5, 0.5, 0.5, 0.5)
        return offsetY - 20
    end
    
    local function CreateColorRow(colorTable, label, offsetY)
        local swatch = ENC:CreateColorSwatch(scrollChild, colorTable, label)
        swatch:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 20, offsetY)
        return swatch, offsetY - 35
    end
    
    local function CreateCheckbox(dbKey, label, offsetY, parent)
        local checkbox = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 20, offsetY)
        checkbox:SetSize(24, 24)
        checkbox:SetChecked(parent[dbKey])
        
        local text = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
        text:SetText(label)
        
        checkbox:SetScript("OnClick", function(self)
            parent[dbKey] = self:GetChecked()
            ENC:UpdateAllNameplates()
        end)
        
        return checkbox, offsetY - 40
    end
    
    -- Enabled Zones
    yOffset = CreateHeader("Enabled Zones", yOffset)
    
    local zonesDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    zonesDesc:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
    zonesDesc:SetText("Choose where the addon applies custom colors.")
    yOffset = yOffset - 30
    
    local zoneCheckboxes = {}
    local zoneOrder = {
        { key = "dungeons",        label = "Dungeons" },
        { key = "raids",           label = "Raids" },
        { key = "delvesScenarios", label = "Delves / Scenarios" },
        { key = "openWorld",       label = "Open World" },
    }
    
    for _, zone in ipairs(zoneOrder) do
        local cb = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 20, yOffset)
        cb:SetSize(24, 24)
        cb:SetChecked(ENC.db.enabledZones[zone.key])
        
        local text = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        text:SetText(zone.label)
        
        cb:SetScript("OnClick", function(self)
            ENC.db.enabledZones[zone.key] = self:GetChecked()
            ENC:UpdateInstanceStatus()
            ENC:UpdateAllNameplates()
        end)
        
        zoneCheckboxes[zone.key] = cb
        yOffset = yOffset - 28
    end
    yOffset = yOffset - 10
    
    yOffset = CreateDivider(yOffset)
    
    -- Focus Target
    yOffset = CreateHeader("Focus Target", yOffset)
    
    -- Create both checkboxes manually for mutual exclusivity
    local focusTargetCheckbox = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
    focusTargetCheckbox:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 20, yOffset)
    focusTargetCheckbox:SetSize(24, 24)
    focusTargetCheckbox:SetChecked(ENC.db.focusTarget.enabled)
    
    local focusColorLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    focusColorLabel:SetPoint("LEFT", focusTargetCheckbox, "RIGHT", 5, 0)
    focusColorLabel:SetText("Color focus target nameplate")
    
    -- Place texture checkbox on the same row, to the right
    local focusTextureCheckbox = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
    focusTextureCheckbox:SetPoint("LEFT", focusColorLabel, "RIGHT", 20, 0)
    focusTextureCheckbox:SetSize(24, 24)
    focusTextureCheckbox:SetChecked(ENC.db.focusTarget.useTexture)
    
    local focusTextureLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    focusTextureLabel:SetPoint("LEFT", focusTextureCheckbox, "RIGHT", 5, 0)
    focusTextureLabel:SetText("Use focus target texture")
    
    local focusTargetColor
    
    -- Mutual exclusivity: only one can be checked at a time
    focusTargetCheckbox:SetScript("OnClick", function(self)
        if self:GetChecked() then
            ENC.db.focusTarget.enabled = true
            ENC.db.focusTarget.useTexture = false
            ENC.db.focusTarget.color.a = 1.0
            focusTextureCheckbox:SetChecked(false)
        else
            ENC.db.focusTarget.enabled = false
        end
        local c = ENC.db.focusTarget.color
        focusTargetColor.texture:SetColorTexture(c.r, c.g, c.b, c.a)
        ENC:UpdateAllNameplates()
    end)
    
    focusTextureCheckbox:SetScript("OnClick", function(self)
        if self:GetChecked() then
            ENC.db.focusTarget.useTexture = true
            ENC.db.focusTarget.enabled = false
            ENC.db.focusTarget.color.a = 0.75
            focusTargetCheckbox:SetChecked(false)
        else
            ENC.db.focusTarget.useTexture = false
        end
        local c = ENC.db.focusTarget.color
        focusTargetColor.texture:SetColorTexture(c.r, c.g, c.b, c.a)
        ENC:UpdateAllNameplates()
    end)
    
    yOffset = yOffset - 40
    
    focusTargetColor, yOffset = CreateColorRow(ENC.db.focusTarget.color, "Focus Target Color", yOffset)
    yOffset = yOffset - 10
    
    yOffset = CreateDivider(yOffset)
    
    -- Unit Type Colors
    yOffset = CreateHeader("Unit Type Colors", yOffset)
    
    local unitTypeDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    unitTypeDesc:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
    unitTypeDesc:SetText("Default colors for enemy units when out of combat or when no threat overrides apply.")
    yOffset = yOffset - 35
    
    local bossColor, miniBossColor, casterColor, standardColor
    bossColor, yOffset = CreateColorRow(ENC.db.unitType.boss, "Boss", yOffset)
    miniBossColor, yOffset = CreateColorRow(ENC.db.unitType.miniBoss, "Mini-Boss", yOffset)
    casterColor, yOffset = CreateColorRow(ENC.db.unitType.caster, "Caster", yOffset)
    standardColor, yOffset = CreateColorRow(ENC.db.unitType.standard, "Standard", yOffset)
    yOffset = yOffset - 15
    
    yOffset = CreateDivider(yOffset)
    
    -- Tank Threat Colors
    yOffset = CreateHeader("Tank Threat Colors", yOffset)
    
    local tankDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    tankDesc:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
    tankDesc:SetText("Colors used when your role is Tank.")
    yOffset = yOffset - 35
    
    local onOtherTankColor, noThreatColor, losingThreatColor
    onOtherTankColor, yOffset = CreateColorRow(ENC.db.tank.onOtherTank, "Threat on Another Tank", yOffset)
    noThreatColor, yOffset = CreateColorRow(ENC.db.tank.noThreat, "No Threat", yOffset)
    losingThreatColor, yOffset = CreateColorRow(ENC.db.tank.losingThreat, "Losing Threat", yOffset)
    yOffset = yOffset - 15
    
    yOffset = CreateDivider(yOffset)
    
    -- DPS/Healer Threat Colors
    yOffset = CreateHeader("DPS/Healer Threat Colors", yOffset)
    
    local dpsDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    dpsDesc:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
    dpsDesc:SetText("Colors used when your role is DPS or Healer.")
    yOffset = yOffset - 35
    
    local hasThreatColor, gainingThreatColor
    hasThreatColor, yOffset = CreateColorRow(ENC.db.dpsHealer.hasThreat, "Has Threat", yOffset)
    gainingThreatColor, yOffset = CreateColorRow(ENC.db.dpsHealer.gainingThreat, "Gaining Threat", yOffset)
    yOffset = yOffset - 15
    
    yOffset = CreateDivider(yOffset)
    
    -- Cast Bar Colors
    yOffset = CreateHeader("Cast Bar Colors", yOffset)
    
    local castBarDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    castBarDesc:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
    castBarDesc:SetText("Colors for enemy cast bars. Priority: Uninterruptible > Important > Channel > Standard")
    yOffset = yOffset - 35
    
    local enableInterruptReadyCheckbox
    enableInterruptReadyCheckbox, yOffset = CreateCheckbox("interruptReadyEnabled", "Enable Interrupt Ready Border", yOffset, ENC.db.castBar)
    
    local interruptReadyColor
    interruptReadyColor, yOffset = CreateColorRow(ENC.db.castBar.interruptReady, "Border Color", yOffset)
    yOffset = yOffset + 5
    
    local enableCastBarCheckbox
    enableCastBarCheckbox, yOffset = CreateCheckbox("enabled", "Enable Cast Bar Coloring", yOffset, ENC.db.castBar)
    
    local uninterruptibleColor, importantColor, channelColor, standardCastColor
    uninterruptibleColor, yOffset = CreateColorRow(ENC.db.castBar.uninterruptible, "Uninterruptible", yOffset)
    importantColor, yOffset = CreateColorRow(ENC.db.castBar.important, "Important Spell", yOffset)
    channelColor, yOffset = CreateColorRow(ENC.db.castBar.channel, "Channeled Spell", yOffset)
    standardCastColor, yOffset = CreateColorRow(ENC.db.castBar.standard, "Standard Cast", yOffset)
    
    scrollChild:SetHeight(math.abs(yOffset) + 50)
    
    -- Reset button
    local buttonFrame = CreateFrame("Frame", nil, panel)
    buttonFrame:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 16)
    buttonFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 16)
    buttonFrame:SetHeight(30)
    
    local resetButton = CreateFrame("Button", nil, buttonFrame, "UIPanelButtonTemplate")
    resetButton:SetSize(150, 25)
    resetButton:SetPoint("LEFT")
    resetButton:SetText("Reset to Defaults")
    resetButton:SetScript("OnClick", function() StaticPopup_Show("ENC_RESET_CONFIRM") end)
    
    function panel:RefreshColors()
        local swatches = {
            {focusTargetColor, ENC.db.focusTarget.color},
            {bossColor, ENC.db.unitType.boss},
            {miniBossColor, ENC.db.unitType.miniBoss},
            {casterColor, ENC.db.unitType.caster},
            {standardColor, ENC.db.unitType.standard},
            {onOtherTankColor, ENC.db.tank.onOtherTank},
            {noThreatColor, ENC.db.tank.noThreat},
            {losingThreatColor, ENC.db.tank.losingThreat},
            {hasThreatColor, ENC.db.dpsHealer.hasThreat},
            {gainingThreatColor, ENC.db.dpsHealer.gainingThreat},
            {interruptReadyColor, ENC.db.castBar.interruptReady},
            {importantColor, ENC.db.castBar.important},
            {uninterruptibleColor, ENC.db.castBar.uninterruptible},
            {channelColor, ENC.db.castBar.channel},
            {standardCastColor, ENC.db.castBar.standard},
        }
        
        for _, swatch in ipairs(swatches) do
            local button, color = swatch[1], swatch[2]
            if button and button.texture and color then
                button.texture:SetColorTexture(color.r, color.g, color.b, color.a or 1)
            end
        end
        
        enableCastBarCheckbox:SetChecked(ENC.db.castBar.enabled)
        enableInterruptReadyCheckbox:SetChecked(ENC.db.castBar.interruptReadyEnabled)
        focusTargetCheckbox:SetChecked(ENC.db.focusTarget.enabled)
        focusTextureCheckbox:SetChecked(ENC.db.focusTarget.useTexture)
        
        for key, cb in pairs(zoneCheckboxes) do
            cb:SetChecked(ENC.db.enabledZones[key])
        end
    end
    
    ENC.OptionsPanel = panel
    return panel
end

StaticPopupDialogs["ENC_RESET_CONFIRM"] = {
    text = "Are you sure you want to reset all colors to their default values?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function() ENC:ResetToDefaults() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function InitOptions()
    local panel = CreateOptionsPanel()
    
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        ENC.OpenOptions = function() Settings.OpenToCategory(category:GetID()) end
    else
        InterfaceOptions_AddCategory(panel)
        ENC.OpenOptions = function()
            InterfaceOptionsFrame_OpenToCategory(panel)
            InterfaceOptionsFrame_OpenToCategory(panel)
        end
    end
end

local optionsFrame = CreateFrame("Frame")
optionsFrame:RegisterEvent("ADDON_LOADED")
optionsFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == ADDON_NAME then
        InitOptions()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)